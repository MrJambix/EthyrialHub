--[[
╔══════════════════════════════════════════════════════════════╗
║         Gather Loop — Interactive Resource Farmer            ║
║                                                              ║
║  Compact floating window.  Check the nodes you want,         ║
║  press Start, and it farms them by pointer.                  ║
║                                                              ║
║  v2 — optimised for large maps (Irumensa):                   ║
║    • Single merged SCENE_SCAN per tick (not 7 IPC calls)     ║
║    • PLAYER_JOB polling for gather completion                ║
║    • Distance pre-filter in C++ (skips far entities)         ║
║    • Compact collapsible UI                                  ║
╚══════════════════════════════════════════════════════════════╝
]]

local ethy = require("common/ethy_sdk")
local ui = core.imgui

ethy.print("=== Gather Loop v2 loaded ===")

-- ═══════════════════════════════════════════════════════════════
-- Node database — each gets a checkbox in the window
-- ═══════════════════════════════════════════════════════════════

local NODES = {
    { name = "Copper Vein",       on = false, cat = "Ore"  },
    { name = "Iron Ore",          on = false, cat = "Ore"  },
    { name = "Iron Vein",         on = false, cat = "Ore"  },
    { name = "Coal Vein",         on = false, cat = "Ore"  },
    { name = "Silver Vein",       on = false, cat = "Ore"  },
    { name = "Gold Vein",         on = false, cat = "Ore"  },
    { name = "Ethyrite",          on = false, cat = "Ore"  },
    { name = "Platinum",          on = false, cat = "Ore"  },
    { name = "Palladium Vein",    on = true,  cat = "Ore"  },
    { name = "Azurium Vein",      on = true,  cat = "Ore"  },
    { name = "Mystril",           on = false, cat = "Ore"  },
    { name = "Rough Gem",         on = false, cat = "Ore"  },
    { name = "Regular Gem",       on = false, cat = "Ore"  },
    { name = "Brilliant Gem",     on = false, cat = "Ore"  },

    { name = "Dead Tree",         on = false, cat = "Tree" },
    { name = "Pine",              on = false, cat = "Tree" },
    { name = "Birch",             on = false, cat = "Tree" },
    { name = "Fir",               on = false, cat = "Tree" },
    { name = "Oak",               on = false, cat = "Tree" },
    { name = "Acacia",            on = false, cat = "Tree" },
    { name = "Apple Tree",        on = false, cat = "Tree" },
    { name = "Wispwood",          on = false, cat = "Tree" },
    { name = "Spiritwood",        on = false, cat = "Tree" },
    { name = "Staroak",           on = false, cat = "Tree" },
    { name = "Moonwillow",        on = false, cat = "Tree" },
    { name = "Aetherbark",        on = false, cat = "Tree" },
    { name = "Mana Ash",          on = false, cat = "Tree" },
    { name = "Elystram",          on = false, cat = "Tree" },
    { name = "Shadewood",         on = false, cat = "Tree" },
    { name = "Duskroot",          on = false, cat = "Tree" },
    { name = "Primordial",        on = false, cat = "Tree" },

    { name = "Hemp Bush",         on = false, cat = "Herb" },
    { name = "Redban Flower",     on = false, cat = "Herb" },
    { name = "Rinthistle",        on = false, cat = "Herb" },
    { name = "Flax Flower",       on = false, cat = "Herb" },
    { name = "Cotton Plant",      on = false, cat = "Herb" },
    { name = "Slitherstrand",     on = false, cat = "Herb" },
    { name = "Champignon",        on = false, cat = "Herb" },
    { name = "Lurker Fungus",     on = false, cat = "Herb" },
    { name = "Wispbloom",         on = false, cat = "Herb" },
    { name = "Sunthistle",        on = false, cat = "Herb" },
    { name = "Duskthorn",         on = false, cat = "Herb" },
    { name = "Forest Canna",      on = false, cat = "Herb" },
    { name = "Ginshade",          on = false, cat = "Herb" },
    { name = "Frost Flower",      on = false, cat = "Herb" },
    { name = "Glowshroom",        on = false, cat = "Herb" },
    { name = "Dark Dragon Plant", on = false, cat = "Herb" },
}

-- ═══════════════════════════════════════════════════════════════
-- Config & state
-- ═══════════════════════════════════════════════════════════════

local CFG = {
    running     = false,
    max_range   = 40,
    gather_wait = 20,      -- hard timeout (PLAYER_JOB usually detects completion sooner)
    rest_hp     = 50,
    humanize    = true,
}

local POLL_RATE     = 0.6      -- scan interval (raised from 0.5 — one scan is cheaper now)
local POLL_JITTER   = 0.15
local MOVE_HISTORY  = 4
local MOVE_TIMEOUT  = 15
local SKIP_DURATION = 30
local COOLDOWN      = 1.5
local JOB_POLL      = 0.35     -- how often to check PLAYER_JOB during gather
local DEAD_TIMEOUT  = 120
local RESPAWN_DELAY = 3.0

-- Pick ONE scan command per category (SCENE_SCAN is faster than NODE_SCAN + merge)
local CAT_SCAN_CMD = {
    Ore  = "SCENE_SCAN_ORES",
    Tree = "SCENE_SCAN_TREES",
    Herb = "SCENE_SCAN_HERBS",
}

local STATE        = "idle"
local status_msg   = "Configure nodes and press Start"
local pos_history  = {}
local gather_start = 0
local walk_start   = 0
local cooldown_start = 0
local dead_start   = 0
local current_node = nil
local last_tick    = 0
local last_job_check = 0
local show_window  = true

local stats     = { gathered = 0, skipped = 0, attempts = 0, deaths = 0, session_start = nil }
local skip_list = {}

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
    if key then skip_list[key] = ethy.now() + SKIP_DURATION end
end

local function norm_ptr(p)
    if not p then return nil end
    local s = tostring(p):upper():gsub("^0X", "")
    return (s ~= "") and s or nil
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
                else t[k] = tonumber(v) or v end
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

local function get_enabled_categories()
    local cats = {}
    for _, n in ipairs(NODES) do
        if n.on then cats[n.cat] = true end
    end
    return cats
end

local function is_safe()
    local hp = core.player.hp()
    if not hp or hp < 0 then return false, "Waiting for player data" end
    if hp == 0 then return false, string.format("Dead (hp=%.0f)", hp) end
    if core.player.combat() then return false, "In combat" end
    if core.player.frozen() then return false, "Frozen" end
    if hp < CFG.rest_hp then return false, string.format("Low HP (%.0f%%)", hp) end
    return true, nil
end

--- Check if player is currently in a gathering job (progress bar active).
local function is_gathering_job()
    local raw = core.send_command("PLAYER_JOB")
    if not raw or raw == "" or raw == "NONE" or raw == "none" then return false end
    return true
end

--- Scan once per tick — only the categories that have enabled nodes.
--- Returns a filtered, distance-sorted list of matching nodes.
local function scan_matching()
    local enabled = get_enabled_names()
    if #enabled == 0 then return {}, 0 end

    local cats = get_enabled_categories()
    local by_ptr = {}
    local scan_errors = 0

    for cat, _ in pairs(cats) do
        local cmd = CAT_SCAN_CMD[cat]
        if cmd then
            local raw = core.send_command(cmd)
            if not raw or raw == "" then
                -- skip
            elseif raw:find("^SEH_EXCEPTION") or raw:find("^CPP_EXCEPTION")
                or raw:find("^MAIN_THREAD_TIMEOUT") or raw:find("^IL2CPP_NOT_AVAILABLE")
                or raw:find("^NO_PLAYER") or raw:find("^NO_ENTITY_MANAGER") then
                scan_errors = scan_errors + 1
                log("Scan error (%s): %s", cmd, raw:sub(1, 80))
            else
                for _, node in ipairs(parse_lines(raw)) do
                    local pk = norm_ptr(node.ptr)
                    if pk and not by_ptr[pk] then
                        by_ptr[pk] = node
                    end
                end
            end
        end
    end

    -- Filter: name match, range, skip list
    local matched = {}
    for _, node in pairs(by_ptr) do
        local hidden = (node.hidden == nil) and 0 or node.hidden
        if hidden == 0
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
    return matched, scan_errors
end

-- ═══════════════════════════════════════════════════════════════
-- Gather state machine
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

    if not stats.session_start then stats.session_start = now end

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

    -- Dead state
    if STATE == "dead" then
        local hp = core.player.hp()
        local elapsed = now - dead_start
        if hp and hp > 0 then
            log("Respawned after %.0fs. Resuming...", elapsed)
            status_msg = "Respawned — resuming..."
            _ethy_sleep(RESPAWN_DELAY)
            STATE = "idle"
        elseif elapsed > DEAD_TIMEOUT then
            log("Respawn timeout. Stopping.")
            status_msg = "Respawn timeout — stopped"
            CFG.running = false
            STATE = "idle"
        else
            status_msg = string.format("Dead — waiting (%.0fs)", elapsed)
        end
        return
    end

    local safe, reason = is_safe()
    if not safe then
        if reason:find("^Waiting") then
            status_msg = reason
            return
        end
        if reason:find("^Dead") then
            stats.deaths = stats.deaths + 1
            dead_start = now
            STATE = "dead"
            status_msg = "Dead — waiting for respawn"
            return
        end
        status_msg = reason .. " — paused"
        STATE = "idle"
        return
    end

    -- ── IDLE: scan for nodes ──
    if STATE == "idle" then
        local nodes, errs = scan_matching()
        if #nodes == 0 then
            status_msg = errs > 0
                and string.format("Scan errors (%d) — retrying...", errs)
                or  string.format("Scanning... (0/%d types)", #enabled)
            return
        end
        local node = nodes[1]
        stats.attempts = stats.attempts + 1
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

    -- ── WALKING: monitor position convergence ──
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
                    log("Unreachable: %s (%.1fm), skipping", current_node.name or "?", arrive_dist)
                    skip_node(current_node.uid, current_node.ptr)
                    stats.skipped = stats.skipped + 1
                    STATE = "idle"
                    return
                end
                log("Arrived at %s", current_node.name or "?")
                gather_start = now
                last_job_check = 0
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

    -- ── GATHERING: use PLAYER_JOB to detect completion, hard timeout as safety ──
    if STATE == "gathering" then
        local elapsed = now - gather_start

        -- Poll PLAYER_JOB at JOB_POLL interval (not every tick)
        if now - last_job_check >= JOB_POLL then
            last_job_check = now
            if elapsed > 2.0 and not is_gathering_job() then
                -- Job cleared = gather complete (or interrupted)
                log("Done (job cleared): %s @ %.1fs", current_node.name or "?", elapsed)
                stats.gathered = stats.gathered + 1
                skip_node(current_node.uid, current_node.ptr)
                cooldown_start = now
                STATE = "cooldown"
                return
            end
        end

        -- Hard timeout safety net
        local left = CFG.gather_wait - elapsed
        status_msg = string.format("Gathering %s (%.0fs)", current_node.name or "?", math.max(0, left))
        if elapsed >= CFG.gather_wait then
            log("Done (timeout): %s", current_node.name or "?")
            stats.gathered = stats.gathered + 1
            skip_node(current_node.uid, current_node.ptr)
            cooldown_start = now
            STATE = "cooldown"
        end
        return
    end

    -- ── COOLDOWN: brief pause between gathers ──
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
-- Compact ImGui window
-- ═══════════════════════════════════════════════════════════════

local show_nodes    = true   -- collapsible node list
local show_debug    = false  -- collapsible debug section

local function render_window()
    if not show_window then return end

    ui.set_next_window_size(280, 380)
    ui.set_next_window_pos(10, 80)
    local visible, open = ui.begin_window("Gather Loop")

    if not open then
        show_window = false
        CFG.running = false
        ui.end_window()
        return
    end

    if not visible then ui.end_window(); return end

    -- ── Status line ──
    if CFG.running then
        ui.text_colored(0.3, 1.0, 0.3, "RUN")
    else
        ui.text_colored(0.6, 0.6, 0.6, "OFF")
    end
    ui.same_line()
    ui.text(status_msg)

    -- ── Controls row ──
    if CFG.running then
        if ui.button("Stop##gl") then CFG.running = false; STATE = "idle"; log("Stopped") end
    else
        if ui.button("Start##gl") then CFG.running = true; log("Started") end
    end
    ui.same_line()
    local elapsed = stats.session_start and (ethy.now() - stats.session_start) or 0
    ui.text(string.format("G:%d  S:%d  D:%d  %.0fs",
        stats.gathered, stats.skipped, stats.deaths, elapsed))
    ui.separator()

    -- ── Settings (always visible, compact) ──
    CFG.max_range   = ui.slider_int("Range##gl",  CFG.max_range,   5, 80)
    CFG.gather_wait = ui.slider_int("Timeout##gl", CFG.gather_wait, 5, 30)
    CFG.rest_hp     = ui.slider_int("Rest HP##gl", CFG.rest_hp,    10, 90)
    ui.separator()

    -- ── Node checkboxes (toggle section) ──
    show_nodes = ui.checkbox("Show Nodes##gl", show_nodes)
    ui.same_line()
    ui.text(string.format("(%d selected)", #get_enabled_names()))
    if show_nodes then
        local last_cat = ""
        for _, n in ipairs(NODES) do
            if n.cat ~= last_cat then
                ui.text_colored(1.0, 0.8, 0.2, n.cat)
                last_cat = n.cat
            end
            n.on = ui.checkbox(n.name .. "##gl", n.on)
        end
    end
    ui.separator()

    -- ── Debug ──
    ui.text(string.format("State: %s", STATE))
    if ui.button("Scan Now##gl") then
        local cats = get_enabled_categories()
        local total = 0
        for cat, _ in pairs(cats) do
            local cmd = CAT_SCAN_CMD[cat]
            if cmd then
                local raw = core.send_command(cmd) or "NONE"
                local nodes = parse_lines(raw)
                log("[%s] %d nodes (raw %d bytes)", cmd, #nodes, #raw)
                total = total + #nodes
            end
        end
        log("Total: %d nodes across enabled categories", total)
    end
    ui.same_line()
    if ui.button("Clear Skips##gl") then
        skip_list = {}
        log("Skip list cleared")
    end

    ui.end_window()
end

-- ═══════════════════════════════════════════════════════════════
-- Callbacks
-- ═══════════════════════════════════════════════════════════════

ethy.on_update(function() gather_tick() end)
ethy.on_render(function() render_window() end)

-- Menu toggle to re-open window
ethy.on_render_menu(function()
    show_window = core.menu.checkbox("gl_show", "Gather Loop", show_window)
end)

ethy.print("Gather Loop v2 ready.")
