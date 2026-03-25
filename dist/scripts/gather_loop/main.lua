--[[
╔══════════════════════════════════════════════════════════════╗
║           Gather Loop — Interactive Resource Farmer           ║
║                                                              ║
║  Opens its own window when you run it. Check the nodes you   ║
║  want, hit Start, and it farms them by pointer.              ║
╚══════════════════════════════════════════════════════════════╝
]]

local ethy = require("common/ethy_sdk")
local ui = core.imgui

ethy.print("=== Gather Loop loaded ===")
ethy.print("  ImGui window mode — own floating window")

-- ═══════════════════════════════════════════════════════════════
-- Node database — each gets a checkbox in the window
-- ═══════════════════════════════════════════════════════════════

local NODES = {
    { name = "Copper Vein",     on = false, cat = "Ore"  },
    { name = "Iron Ore",        on = false, cat = "Ore"  },
    { name = "Iron Vein",       on = false, cat = "Ore"  },
    { name = "Coal Vein",       on = false, cat = "Ore"  },
    { name = "Silver Vein",     on = false, cat = "Ore"  },
    { name = "Gold Vein",       on = false, cat = "Ore"  },
    { name = "Ethyrite",        on = false, cat = "Ore"  },
    { name = "Platinum",        on = false, cat = "Ore"  },
    { name = "Palladium Vein",  on = true,  cat = "Ore"  },
    { name = "Azurium Vein",    on = true,  cat = "Ore"  },
    { name = "Mystril",         on = false, cat = "Ore"  },
    { name = "Rough Gem",       on = false, cat = "Ore"  },
    { name = "Regular Gem",     on = false, cat = "Ore"  },
    { name = "Brilliant Gem",   on = false, cat = "Ore"  },

    { name = "Dead Tree",       on = false, cat = "Tree" },
    { name = "Pine Tree",       on = false, cat = "Tree" },
    { name = "Birch Tree",      on = false, cat = "Tree" },
    { name = "Aging Birch",     on = false, cat = "Tree" },
    { name = "Fir Tree",        on = false, cat = "Tree" },
    { name = "Oak Tree",        on = false, cat = "Tree" },
    { name = "Acacia Tree",     on = false, cat = "Tree" },
    { name = "Aging Acacia",    on = false, cat = "Tree" },
    { name = "Verdant Acacia",  on = false, cat = "Tree" },
    { name = "Wispwood Tree",   on = false, cat = "Tree" },
    { name = "Spiritwood Tree", on = false, cat = "Tree" },
    { name = "Staroak Tree",    on = false, cat = "Tree" },
    { name = "Moonwillow Tree", on = false, cat = "Tree" },
    { name = "Aetherbark Tree", on = false, cat = "Tree" },
    { name = "Mana Ash Tree",   on = false, cat = "Tree" },
    { name = "Elystram Tree",   on = false, cat = "Tree" },
    { name = "Shadewood Tree",  on = false, cat = "Tree" },
    { name = "Duskroot Tree",   on = false, cat = "Tree" },
    { name = "Primordial Tree", on = false, cat = "Tree" },

    { name = "Hemp Bush",       on = false, cat = "Herb" },
    { name = "Redban Flower",   on = false, cat = "Herb" },
    { name = "Rinthistle",      on = false, cat = "Herb" },
    { name = "Flax Flower",     on = false, cat = "Herb" },
    { name = "Cotton Plant",    on = false, cat = "Herb" },
    { name = "Slitherstrand",   on = false, cat = "Herb" },
    { name = "Champignon",      on = false, cat = "Herb" },
    { name = "Lurker Fungus",   on = false, cat = "Herb" },
    { name = "Wispbloom",       on = false, cat = "Herb" },
    { name = "Sunthistle",      on = false, cat = "Herb" },
    { name = "Duskthorn",       on = false, cat = "Herb" },
}

-- ═══════════════════════════════════════════════════════════════
-- Config & state
-- ═══════════════════════════════════════════════════════════════

local CFG = {
    running     = false,
    max_range   = 40,
    gather_wait = 12,
    rest_hp     = 50,
}

local POLL_RATE     = 0.5
local MOVE_HISTORY  = 4
local MOVE_TIMEOUT  = 15
local SKIP_DURATION = 30
local COOLDOWN      = 1.5

local STATE       = "idle"
local status_msg  = "Configure nodes and press Start"
local pos_history = {}
local gather_start = 0
local walk_start   = 0
local cooldown_start = 0
local current_node = nil
local last_tick    = 0
local show_window  = true

local stats = { gathered = 0, skipped = 0, attempts = 0 }
local skip_list = {}
local debug_cache = nil

-- ═══════════════════════════════════════════════════════════════
-- Helpers
-- ═══════════════════════════════════════════════════════════════

local function log(msg, ...)
    ethy.printf("[GatherLoop] " .. msg, ...)
end

local function skip_key(uid, ptr)
    if uid then return "uid:" .. tostring(uid) end
    if ptr then return "ptr:" .. tostring(ptr) end
    return nil
end

local function is_skipped(uid, ptr)
    local key = skip_key(uid, ptr)
    if not key then return false end
    local exp = skip_list[key]
    if not exp then return false end
    if ethy.now() > exp then skip_list[key] = nil; return false end
    return true
end

local function skip_node(uid, ptr)
    local key = skip_key(uid, ptr)
    if key then
        skip_list[key] = ethy.now() + SKIP_DURATION
    end
end

local function get_pos()
    local raw = core.send_command("PLAYER_POS")
    if not raw or raw == "" then return nil, nil end
    local x, y = raw:match("([^,]+),([^,]+)")
    return tonumber(x), tonumber(y)
end

local function positions_settled(hist)
    if #hist < MOVE_HISTORY then return false end
    local ax, ay = hist[1][1], hist[1][2]
    for i = 2, #hist do
        if hist[i][1] ~= ax or hist[i][2] ~= ay then return false end
    end
    return true
end

local function name_matches(node_name, want)
    if not node_name then return false end
    local nl = node_name:lower()
    local wl = want:lower()
    if nl:find(wl, 1, true) then return true end
    local keyword = wl:match("^(%S+)")
    if keyword and #keyword >= 3 and nl:find(keyword, 1, true) then return true end
    return false
end

local function parse_lines(raw)
    if not raw or raw == "" or raw == "NONE" then return {} end
    local results = {}
    for entry in raw:gmatch("[^#]+") do
        entry = entry:match("^%s*(.-)%s*$")
        if entry ~= "" and not entry:match("^count=") then
            local t = {}
            for k, v in entry:gmatch("([%w_]+)=([^|]+)") do
                if k == "ptr" then t[k] = v
                else
                    local num = tonumber(v)
                    t[k] = num ~= nil and num or v
                end
            end
            if next(t) then results[#results + 1] = t end
        end
    end
    return results
end

local function get_enabled_names()
    local names = {}
    for _, n in ipairs(NODES) do
        if n.on then names[#names + 1] = n.name end
    end
    return names
end

local function is_safe()
    local hp = core.player.hp()
    if not hp or hp <= 0 then return false, string.format("Dead (hp=%s)", tostring(hp)) end
    if core.player.combat() then return false, "In combat" end
    if core.player.frozen() then return false, "Frozen" end
    if hp < CFG.rest_hp then return false, string.format("Low HP (%.0f%%)", hp) end
    return true, nil
end

local function scan_matching()
    local enabled = get_enabled_names()
    if #enabled == 0 then return {} end
    local raw = core.send_command("NODE_SCAN")
    local all = parse_lines(raw)
    local matched = {}
    for _, node in ipairs(all) do
        local available = (node.usable == 1) and (node.hidden == 0)
        if available
            and (node.dist or 999) <= CFG.max_range
            and not is_skipped(node.uid, node.ptr) then
            for _, want in ipairs(enabled) do
                if name_matches(node.name, want) then
                    matched[#matched + 1] = node
                    break
                end
            end
        end
    end
    table.sort(matched, function(a, b) return (a.dist or 999) < (b.dist or 999) end)
    return matched
end

-- ═══════════════════════════════════════════════════════════════
-- Gather state machine (runs in on_update)
-- ═══════════════════════════════════════════════════════════════

local function gather_tick()
    local now = ethy.now()
    if now - last_tick < POLL_RATE then return end
    last_tick = now

    if not CFG.running then
        if STATE ~= "idle" then STATE = "idle" end
        status_msg = "Stopped"
        return
    end

    local enabled = get_enabled_names()
    if #enabled == 0 then
        status_msg = "No nodes selected"
        return
    end

    local safe, reason = is_safe()
    if not safe then
        status_msg = reason .. " — paused"
        STATE = "idle"
        return
    end

    if STATE == "idle" then
        local nodes = scan_matching()
        if #nodes == 0 then
            status_msg = string.format("Scanning... (0/%d types)", #enabled)
            return
        end
        local node = nodes[1]
        stats.attempts = stats.attempts + 1
        -- #region agent log
        log("-> %s ptr=%s dist=%.1f usable=%s hidden=%s", node.name or "?", tostring(node.ptr), node.dist or 0, tostring(node.usable), tostring(node.hidden))
        -- #endregion
        status_msg = string.format("Using %s (%.0fm)", node.name or "?", node.dist or 0)

        local r = ""
        if node.ptr then
            r = core.send_command("GATHER_PTR_" .. node.ptr) or ""
        else
            r = core.send_command("USE_ENTITY_" .. (node.name or "")) or ""
        end

        if r:find("OK") or r:find("USED") or r:find("GATHER") then
            current_node = node
            pos_history = {}
            walk_start = now
            STATE = "walking"
        elseif r == "NONE" or r == "NOT_FOUND" or r == "STALE_PTR" then
            skip_node(node.uid, node.ptr)
            stats.skipped = stats.skipped + 1
        end
        return
    end

    if STATE == "walking" then
        local x, y = get_pos()
        if x then
            pos_history[#pos_history + 1] = { x, y }
            if #pos_history > MOVE_HISTORY then table.remove(pos_history, 1) end
            if #pos_history == MOVE_HISTORY and positions_settled(pos_history) then
                local nx, ny = current_node.x or x, current_node.y or y
                local dx, dy = x - nx, y - ny
                local arrive_dist = math.sqrt(dx * dx + dy * dy)
                -- #region agent log
                log("Settled at (%.1f,%.1f) node at (%.1f,%.1f) arrive_dist=%.1f for %s",
                    x, y, nx, ny, arrive_dist, current_node.name or "?")
                -- #endregion
                if arrive_dist > 6 then
                    log("Unreachable: %s (%.1fm away), skipping", current_node.name or "?", arrive_dist)
                    skip_node(current_node.uid, current_node.ptr)
                    stats.skipped = stats.skipped + 1
                    STATE = "idle"
                    return
                end
                log("Arrived at %s (%.1f, %.1f)", current_node.name or "?", x, y)
                gather_start = now
                STATE = "gathering"
                return
            end
        end
        local elapsed = now - walk_start
        status_msg = string.format("Walking to %s (%.0fs)", current_node.name or "?", elapsed)
        if elapsed > MOVE_TIMEOUT then
            skip_node(current_node.uid, current_node.ptr)
            stats.skipped = stats.skipped + 1
            STATE = "idle"
        end
        return
    end

    if STATE == "gathering" then
        local elapsed = now - gather_start
        local left = CFG.gather_wait - elapsed
        status_msg = string.format("Gathering %s (%.0fs)", current_node.name or "?", math.max(0, left))
        if elapsed >= CFG.gather_wait then
            log("Done: %s", current_node.name or "?")
            stats.gathered = stats.gathered + 1
            skip_node(current_node.uid, current_node.ptr)
            cooldown_start = now
            STATE = "cooldown"
        end
        return
    end

    if STATE == "cooldown" then
        if now - cooldown_start >= COOLDOWN then
            STATE = "idle"
        else
            status_msg = "Cooldown..."
        end
        return
    end
end

-- ═══════════════════════════════════════════════════════════════
-- Render: ImGui floating window
-- ═══════════════════════════════════════════════════════════════

local function render_imgui_window()
    if not show_window then return end

    ui.set_next_window_size(320, 520)
    ui.set_next_window_pos(20, 100)
    local visible, open = ui.begin_window("Gather Loop")

    if not open then
        show_window = false
        CFG.running = false
        ui.end_window()
        return
    end

    if visible then
        if CFG.running then
            ui.text_colored(0.3, 1.0, 0.3, "● RUNNING")
        else
            ui.text_colored(0.6, 0.6, 0.6, "○ STOPPED")
        end
        ui.same_line()
        ui.text("  " .. status_msg)
        ui.separator()

        if CFG.running then
            if ui.button("■  Stop") then
                CFG.running = false
                STATE = "idle"
                log("Stopped")
            end
        else
            if ui.button("▶  Start") then
                CFG.running = true
                log("Started")
            end
        end
        ui.same_line()
        ui.text(string.format("  Gathered: %d  Skipped: %d", stats.gathered, stats.skipped))
        ui.separator()

        CFG.max_range   = ui.slider_int("Range (m)",       CFG.max_range,   5, 80)
        CFG.gather_wait = ui.slider_int("Gather Wait (s)", CFG.gather_wait, 5, 25)
        CFG.rest_hp     = ui.slider_int("Rest HP %",       CFG.rest_hp,    10, 90)

        if ui.button("Scan Nodes") then
            local raw = core.send_command("NODE_SCAN") or "NONE"
            local all = parse_lines(raw)
            log("=== NODE SCAN: %d nodes ===", #all)
            for _, n in ipairs(all) do
                log("  [%s] class=%s dist=%.1f usable=%s ptr=%s",
                    tostring(n.name or "?"), tostring(n.class or "?"),
                    n.dist or 0, tostring(n.usable), tostring(n.ptr or "?"))
            end
        end
        ui.same_line()
        if ui.button("Dump Raw") then
            local raw = core.send_command("NODE_SCAN") or "NONE"
            log("=== RAW NODE_SCAN (len=%d) ===", #raw)
            local chunk_size = 200
            for i = 1, #raw, chunk_size do
                log("  [%d] %s", i, raw:sub(i, i + chunk_size - 1))
            end
        end
        ui.same_line()
        -- #region agent log
        if ui.button("Diagnose Ores") then
            local raw = core.send_command("NODE_SCAN") or "NONE"
            local all = parse_lines(raw)

            local herb_ptr, ore_ptr, ore_hidden_ptr = nil, nil, nil
            local herb_name, ore_name, ore_hidden_name = nil, nil, nil
            local herb_info, ore_info, ore_hidden_info = nil, nil, nil

            for _, n in ipairs(all) do
                if not herb_ptr and n.usable == 1 and (n.hidden == 0 or n.hidden == nil) and n.ptr then
                    local tp = n.type or ""
                    if tp == "herb" then herb_ptr = n.ptr; herb_name = n.name; herb_info = n end
                end
                if not ore_hidden_ptr and n.type == "ore" and n.hidden == 0 and n.ptr then
                    ore_hidden_ptr = n.ptr; ore_hidden_name = n.name; ore_hidden_info = n
                end
                if not ore_ptr and n.type == "ore" and n.ptr then
                    ore_ptr = n.ptr; ore_name = n.name; ore_info = n
                end
                if herb_ptr and ore_hidden_ptr and ore_ptr then break end
            end

            log("=== ORE DIAGNOSIS (session aed47f) ===")
            log("  Herb sample:           %s ptr=%s usable=%s hidden=%s",
                tostring(herb_name), tostring(herb_ptr),
                tostring(herb_info and herb_info.usable), tostring(herb_info and herb_info.hidden))
            log("  Ore sample (hidden=0): %s ptr=%s usable=%s hidden=%s",
                tostring(ore_hidden_name), tostring(ore_hidden_ptr),
                tostring(ore_hidden_info and ore_hidden_info.usable), tostring(ore_hidden_info and ore_hidden_info.hidden))
            log("  Ore sample (any):      %s ptr=%s usable=%s hidden=%s",
                tostring(ore_name), tostring(ore_ptr),
                tostring(ore_info and ore_info.usable), tostring(ore_info and ore_info.hidden))

            local function probe(ptr, label)
                if not ptr then log("  [%s] NO PTR AVAILABLE", label); return end
                local r_hidden = core.send_command(string.format("READ_AT %s 0x158 bool", ptr)) or "?"
                local r_usable = core.send_command(string.format("READ_AT %s 0x196 bool", ptr)) or "?"
                local r_batch = core.send_command(string.format(
                    "BATCH_READ %s 0x190:int8 0x191:int8 0x192:int8 0x193:int8 0x194:int8 0x195:int8 0x196:int8 0x197:int8 0x198:int8 0x199:int8 0x19A:int8 0x19B:int8 0x19C:int8 0x19D:int8 0x19E:int8 0x19F:int8",
                    ptr)) or "?"
                log("  [%s] READ_AT 0x158 bool = %s", label, r_hidden)
                log("  [%s] READ_AT 0x196 bool = %s", label, r_usable)
                log("  [%s] BATCH 0x190-0x19F = %s", label, r_batch)
            end

            probe(herb_ptr, "HERB_USABLE")
            probe(ore_hidden_ptr, "ORE_VISIBLE")
            if ore_ptr ~= ore_hidden_ptr then probe(ore_ptr, "ORE_ANY") end

            local logpath = [[C:\Users\mrjam\OneDrive\Desktop\EthyrialInjector\debug-aed47f.log]]
            local ts = tostring(os.time() or 0)
            local ok, f = pcall(io.open, logpath, "a")
            if ok and f then
                local function wlog(msg, data)
                    f:write(string.format(
                        '{"sessionId":"aed47f","hypothesisId":"A","location":"gather_loop:diagnose","message":"%s","data":%s,"timestamp":%s}\n',
                        msg, data, ts))
                end
                wlog("herb_sample", string.format('{"ptr":"%s","name":"%s","usable":%s,"hidden":%s}',
                    tostring(herb_ptr), tostring(herb_name),
                    tostring(herb_info and herb_info.usable or "nil"),
                    tostring(herb_info and herb_info.hidden or "nil")))
                wlog("ore_visible_sample", string.format('{"ptr":"%s","name":"%s","usable":%s,"hidden":%s}',
                    tostring(ore_hidden_ptr), tostring(ore_hidden_name),
                    tostring(ore_hidden_info and ore_hidden_info.usable or "nil"),
                    tostring(ore_hidden_info and ore_hidden_info.hidden or "nil")))
                f:close()
                log("  Debug log written: %s", logpath)
            else
                log("  Could not write debug log (io.open not available in sandbox)")
            end
            log("=== END ORE DIAGNOSIS ===")
        end
        ui.same_line()
        -- #endregion
        if ui.button("Discover Names") then
            local raw = core.send_command("NODE_SCAN") or "NONE"
            local all = parse_lines(raw)
            local known_lower = {}
            for _, n in ipairs(NODES) do
                known_lower[n.name:lower()] = true
            end
            log("=== DISCOVER: %d nodes nearby ===", #all)
            local seen = {}
            for _, n in ipairs(all) do
                local nm = n.name or "?"
                local disp = n.disp or nm
                local key = nm:lower()
                if not seen[key] then
                    seen[key] = true
                    local matched = false
                    for _, entry in ipairs(NODES) do
                        if name_matches(nm, entry.name) then
                            matched = true
                            break
                        end
                    end
                    local tag = matched and "[OK]" or "[NEW]"
                    log("  %s  name=\"%s\"  disp=\"%s\"  dist=%.0f  usable=%s  class=%s",
                        tag, nm, disp, n.dist or 0, tostring(n.usable), tostring(n.class or n.cls or "?"))
                end
            end
            log("=== Walk near trees/ores/herbs and press again to discover more ===")
        end
        ui.separator()

        -- Debug panel (cached, only updates on button click to avoid pipe spam)
        ui.text_colored(0.5, 0.8, 1.0, "── Debug ──")
        ui.text(string.format("  State: %s  Enabled: %d", STATE, #get_enabled_names()))
        if debug_cache then
            ui.text(string.format("  HP: %s  MP: %s  MaxHP: %s", debug_cache.hp, debug_cache.mp, debug_cache.maxhp))
            ui.text(string.format("  Combat: %s  Frozen: %s", debug_cache.combat, debug_cache.frozen))
            ui.text(string.format("  Pos: %s", debug_cache.pos))
            ui.text(string.format("  PLAYER_ALL: %s", (debug_cache.all or ""):sub(1, 120)))
        end

        if ui.button("Debug Dump") then
            log("=== DEBUG DUMP ===")
            local cmds = {
                {"PLAYER_HP",     "hp"},
                {"PLAYER_MP",     "mp"},
                {"PLAYER_MAX_HP", "maxhp"},
                {"PLAYER_COMBAT", "combat"},
                {"PLAYER_FROZEN", "frozen"},
                {"PLAYER_POS",    "pos"},
                {"PLAYER_ALL",    "all"},
            }
            debug_cache = {}
            for _, c in ipairs(cmds) do
                local r = core.send_command(c[1]) or "nil"
                debug_cache[c[2]] = r
                log("  %s = \"%s\"", c[1], r:sub(1, 200))
            end
            log("  core.player.hp()      = %s", tostring(core.player.hp()))
            log("  core.player.combat()  = %s", tostring(core.player.combat()))
            log("  core.player.frozen()  = %s", tostring(core.player.frozen()))
            local safe, reason = is_safe()
            log("  is_safe() = %s  reason = %s", tostring(safe), tostring(reason))
            log("  STATE = %s  running = %s", STATE, tostring(CFG.running))
            log("  Enabled nodes: %d", #get_enabled_names())
        end
        ui.separator()

        local last_cat = ""
        for _, n in ipairs(NODES) do
            if n.cat ~= last_cat then
                ui.spacing()
                ui.text_colored(1.0, 0.8, 0.2, "── " .. n.cat .. " ──")
                last_cat = n.cat
            end
            n.on = ui.checkbox(n.name, n.on)
        end
    end

    ui.end_window()
end

-- ═══════════════════════════════════════════════════════════════
-- Callbacks
-- ═══════════════════════════════════════════════════════════════

ethy.on_update(function()
    gather_tick()
end)

ethy.on_render(function()
    render_imgui_window()
end)

ethy.print("Gather Loop ready.")
ethy.print("  Window should be visible on screen.")
