--[[
╔══════════════════════════════════════════════════════════════╗
║           Gather Loop — Interactive Resource Farmer           ║
║                                                              ║
║  Opens its own window when you run it. Check the nodes you   ║
║  want, hit Start, and it farms them by pointer.              ║
╚══════════════════════════════════════════════════════════════╝
]]


local function find_and_ensure_path(module)
    local mod_path = module:gsub("%.", "/") .. ".lua"
    for path in package.path:gmatch("[^;]+") do
        local candidate = path:gsub("%?", module:gsub("%.", "/"))
        local f = io.open(candidate, "r")
        if f then
            f:close()
            return -- already findable, we're good
        end
    end
    -- Not found in current path, try to locate it relative to cwd
    local search_dirs = {"dist/scripts/", "scripts/", "lua/", ""}
    for _, dir in ipairs(search_dirs) do
        local f = io.open(dir .. mod_path, "r")
        if f then
            f:close()
            package.path = dir .. "?.lua;" .. dir .. "?/init.lua;" .. package.path
            return
        end
    end
end

find_and_ensure_path("common/ethy_sdk")
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
    humanize    = true,
}

local POLL_RATE     = 0.5
local POLL_JITTER   = 0.15
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

-- #region agent log
local DEBUG_LOG_PATH = "C:/Users/mrjam/OneDrive/Desktop/EthyrialInjector/debug-cbd804.log"
local _dbg_run = 0
local function _esc(s) if type(s)~="string" then return tostring(s) end return s:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n'):gsub('\r','') end
local function _dlog(hyp, loc, msg, kvs)
    pcall(function()
        local f = io.open(DEBUG_LOG_PATH, "a")
        if not f then return end
        local d = ""
        if kvs then
            local parts = {}
            for k,v in pairs(kvs) do
                if type(v) == "string" then parts[#parts+1] = '"'..k..'":"'.._esc(v)..'"'
                elseif type(v) == "number" then parts[#parts+1] = '"'..k..'":'..v
                elseif type(v) == "boolean" then parts[#parts+1] = '"'..k..'":'..(v and "true" or "false")
                else parts[#parts+1] = '"'..k..'":"'.._esc(tostring(v))..'"' end
            end
            d = table.concat(parts, ",")
        end
        f:write('{"sessionId":"cbd804","runId":"run'.._dbg_run..'","hypothesisId":"'..hyp..'","location":"'.._esc(loc)..'","message":"'.._esc(msg)..'","data":{'..d..'},"timestamp":'..math.floor(ethy.now()*1000)..'}\n')
        f:close()
    end)
end
-- #endregion

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
    local poll = POLL_RATE + (math.random() - 0.5) * POLL_JITTER * 2
    if now - last_tick < poll then return end
    last_tick = now

    if not CFG.running then
        if STATE ~= "idle" then STATE = "idle" end
        status_msg = "Stopped"
        return
    end

    if CFG.humanize then
        local action, duration = ethy.human.session.check()
        if action == "long_break" then
            status_msg = string.format("Taking a break (%.0fs)", duration)
            _ethy_sleep(math.min(duration, 5.0))
            return
        elseif action == "micro_pause" then
            status_msg = "Brief pause..."
            _ethy_sleep(math.min(duration, 5.0))
            return
        end
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
        -- #region agent log
        local _sc = 0; for _ in pairs(skip_list) do _sc = _sc + 1 end
        _dlog("H1C", "gather_tick:idle", "selected_node", {
            name=node.name or "?", dist=node.dist or -1, uid=node.uid or 0,
            ptr=node.ptr or "nil", usable=node.usable or -1, hidden=node.hidden or -1,
            total_matched=#nodes, skip_list_size=_sc
        })
        -- #endregion
        stats.attempts = stats.attempts + 1
        status_msg = string.format("Using %s (%.0fm)", node.name or "?", node.dist or 0)

        local r = ""
        if node.ptr then
            r = core.send_command("GATHER_PTR_" .. node.ptr) or ""
        else
            r = core.send_command("USE_ENTITY_" .. (node.name or "")) or ""
        end

        -- #region agent log
        _dlog("H1A", "gather_tick:use", "gather_response", {response=r:sub(1,200), ptr=node.ptr or "nil", name=node.name or "?"})
        -- #endregion
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
            -- #region agent log
            local _sk = skip_key(current_node.uid, current_node.ptr)
            _dlog("H1C", "gather_tick:done", "gathered_and_skipped", {
                name=current_node.name or "?", skip_key=_sk or "nil",
                skip_expires=skip_list[_sk] or 0, now=ethy.now(),
                uid=current_node.uid or 0, ptr=current_node.ptr or "nil"
            })
            -- #endregion
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
        -- #region agent log
        ui.text_colored(0.5, 1.0, 0.5, "── Debug Session cbd804 ──")
        if ui.button("Test Targeting") then
            _dbg_run = _dbg_run + 1
            local cmds = {"SCAN_ENEMIES", "TARGET_NEAREST", "TARGET_INFO", "HAS_TARGET", "TARGET_NAME", "SCAN_NEARBY"}
            for _, c in ipairs(cmds) do
                local r = core.send_command(c) or "nil"
                _dlog("H2ALL", "test_targeting", c, {response=r:sub(1, 500), len=#r})
                log("  %s => %s", c, r:sub(1, 200))
            end
            log("Targeting diagnostics logged to debug file (run %d)", _dbg_run)
        end
        ui.same_line()
        if ui.button("Test Nodes") then
            _dbg_run = _dbg_run + 1
            local raw = core.send_command("NODE_SCAN") or "NONE"
            local all = parse_lines(raw)
            _dlog("H1ALL", "test_nodes", "manual_scan", {total=#all, raw_len=#raw})
            for i, n in ipairs(all) do
                if i <= 20 then
                    _dlog("H1ALL", "test_nodes", "node_detail", {
                        idx=i, name=n.name or "?", usable=n.usable or -1, hidden=n.hidden or -1,
                        dist=n.dist or -1, uid=n.uid or 0, ptr=n.ptr or "nil", class=n.class or "?"
                    })
                end
            end
            log("Logged %d nodes to debug file (run %d)", #all, _dbg_run)
        end
        -- #endregion
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
