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
    { name = "Oak Tree",        on = false, cat = "Tree" },
    { name = "Acacia Tree",     on = false, cat = "Tree" },

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

-- ═══════════════════════════════════════════════════════════════
-- Helpers
-- ═══════════════════════════════════════════════════════════════

local function log(msg, ...)
    ethy.printf("[GatherLoop] " .. msg, ...)
end

local function is_skipped(uid)
    if not uid then return false end
    local exp = skip_list[tostring(uid)]
    if not exp then return false end
    if ethy.now() > exp then skip_list[tostring(uid)] = nil; return false end
    return true
end

local function skip_node(uid, name)
    if uid then
        skip_list[tostring(uid)] = ethy.now() + SKIP_DURATION
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
    return node_name:lower():find(want:lower(), 1, true) ~= nil
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
    if hp <= 0 then return false, "Dead" end
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
        if node.usable == 1
            and (node.dist or 999) <= CFG.max_range
            and not is_skipped(node.uid) then
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
        log("-> %s ptr=%s dist=%.1f", node.name or "?", tostring(node.ptr), node.dist or 0)
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
            skip_node(node.uid, node.name)
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
                log("Arrived at %s (%.1f, %.1f)", current_node.name or "?", x, y)
                gather_start = now
                STATE = "gathering"
                return
            end
        end
        local elapsed = now - walk_start
        status_msg = string.format("Walking to %s (%.0fs)", current_node.name or "?", elapsed)
        if elapsed > MOVE_TIMEOUT then
            skip_node(current_node.uid, current_node.name)
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
