--[[
╔══════════════════════════════════════════════════════════════╗
║              Fishing Loop — Water / spot automation          ║
║                                                              ║
║  Scans NODE_SCAN_*fish*, optional *Vein* (ores), and real    ║
║  FISHING_SPOTS rows only (skips fallback=1 world dumps).     ║
║  Merges by pointer, walks in,                                ║
║  then interacts via GATHER_PTR_ / USE_ENTITY_.               ║
╚══════════════════════════════════════════════════════════════╝
]]

local ethy = require("common/ethy_sdk")
local ui = core.imgui

ethy.print("=== Fishing Loop loaded ===")

-- name_filter: optional substring match on entity name/class (edit here; no ImGui text field in runtime)
local CFG = {
    running            = false,
    max_range          = 45,
    activity_wait      = 18,
    rest_hp            = 40,
    humanize           = true,
    name_filter        = "",
    -- If non-empty: walk to the spot first, then core.inventory.use_item(uid) on the first
    -- bag item whose name contains this substring (case-insensitive). Example: "Fishing Stick".
    -- Leave "" to keep the default gather / USE_ENTITY behavior at pick time.
    fishing_item_substring = "",
    skip_bobber        = true,
    include_vein_nodes = true,
    use_fishing_spots  = true,
}

local POLL_RATE    = 0.55
local POLL_JITTER  = 0.18
local MOVE_HISTORY = 4
local MOVE_TIMEOUT = 18
local SKIP_DURATION = 35
local COOLDOWN     = 2.0

local STATE         = "idle"
local status_msg    = "Press Start near water / fishing nodes"
local pos_history   = {}
local activity_start = 0
local walk_start    = 0
local cooldown_start = 0
local current_spot  = nil
local last_tick     = 0
local show_window   = true
-- When set, we skipped gather at pick time; use this inventory uid after walk settles.
local pending_item_uid = nil

local stats = { used = 0, skipped = 0, attempts = 0 }
local skip_list = {}

local function log(msg, ...)
    ethy.printf("[FishingLoop] " .. msg, ...)
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

local function skip_spot(uid, ptr)
    local key = skip_key(uid, ptr)
    if key then skip_list[key] = ethy.now() + SKIP_DURATION end
end

local function norm_ptr(p)
    if not p then return nil end
    local s = tostring(p):upper():gsub("^0X", "")
    return (s ~= "") and s or nil
end

local function player_pos_3()
    local raw = core.send_command("PLAYER_POS")
    if not raw or raw == "" then return nil, nil, nil end
    local x, y, z = raw:match("([^,]+),([^,]+),([^,]+)")
    return tonumber(x), tonumber(y), tonumber(z)
end

local function parse_scan(raw)
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

-- LuaRuntime exposes fishing_spots() but not script_engine's get_fishing(); parse pipe here.
-- FISHING_SPOTS uses ### segments; first chunk may be fallback=1|count=N without ptr=.
local function parse_fishing_spots_raw(raw)
    if not raw or raw == "" or raw == "NONE" then return {} end
    local results = {}
    for entry in raw:gmatch("[^#]+") do
        entry = entry:match("^%s*(.-)%s*$") or ""
        if entry ~= "" and entry:find("ptr=", 1, true) and not entry:match("^count=") then
            local t = {}
            for k, v in entry:gmatch("([%w_]+)=([^|]+)") do
                if k == "ptr" then t[k] = v
                else
                    local num = tonumber(v)
                    t[k] = num ~= nil and num or v
                end
            end
            if t.ptr then results[#results + 1] = t end
        end
    end
    return results
end

local function positions_settled(hist)
    if #hist < MOVE_HISTORY then return false end
    local ax, ay = hist[1][1], hist[1][2]
    for i = 2, #hist do
        if hist[i][1] ~= ax or hist[i][2] ~= ay then return false end
    end
    return true
end

local function get_pos_xy()
    local x, y, z = player_pos_3()
    return x, y
end

local function dist3(ax, ay, az, bx, by, bz)
    if not ax or not bx then return nil end
    local dx, dy, dz = ax - bx, ay - by, (az or 0) - (bz or 0)
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function name_excluded(name, class)
    if not CFG.skip_bobber then return false end
    local blob = ((name or "") .. " " .. (class or "")):lower()
    return blob:find("bobber", 1, true) or blob:find("hook", 1, true)
        or blob:find("lure", 1, true) or blob:find("bait", 1, true)
end

local function name_allowed(name, class)
    local f = CFG.name_filter
    if not f or f == "" then return true end
    local fl = f:lower()
    local n = (name or ""):lower()
    local c = (class or ""):lower()
    return n:find(fl, 1, true) or c:find(fl, 1, true)
end

-- Ambient / level props that often appear in FISHING_SPOTS fallback dumps
local function junk_ambient_entity(name, class)
    local n = (name or ""):lower()
    local c = (class or ""):lower()
    if c:find("wallentity", 1, true) or c:find("monsterentity", 1, true) then return true end
    if n:find("sound ocean", 1, true) or n:find("sound stream", 1, true) then return true end
    if n:find("ocean doodad", 1, true) or n:find("stream doodad", 1, true) then return true end
    return false
end

local function merge_usable_nodes(raw, source, merge_fn)
    for _, n in ipairs(parse_scan(raw or "")) do
        local available = (n.usable == 1) and ((n.hidden or 0) == 0)
        if available then merge_fn(n, source) end
    end
end

local function collect_candidates()
    local by_ptr = {}
    local px, py, pz = player_pos_3()

    local function merge(node, source)
        if junk_ambient_entity(node.name, node.class) then return end
        if name_excluded(node.name, node.class) then return end
        if not name_allowed(node.name, node.class) then return end
        local pk = norm_ptr(node.ptr)
        if not pk then return end
        if is_skipped(node.uid, node.ptr) then return end

        local dist = node.dist
        if dist == nil and px and node.x and node.y then
            dist = dist3(px, py, pz, node.x, node.y, node.z)
        end
        dist = dist or 999
        if dist > CFG.max_range then return end

        local usable = node.usable
        if usable == nil then usable = 1 end

        local ex = by_ptr[pk]
        if ex then
            if dist < (ex.dist or 999) then ex.dist = dist end
            if usable == 1 then ex.usable = 1 end
            ex.source = ex.source .. "+" .. source
            return
        end

        by_ptr[pk] = {
            ptr    = node.ptr,
            uid    = node.uid,
            name   = node.name or node.disp or "?",
            class  = node.class or node.cls,
            x      = node.x,
            y      = node.y,
            z      = node.z,
            dist   = dist,
            usable = usable,
            source = source,
        }
    end

    local raw_fish = core.send_command("NODE_SCAN_USABLE_fish") or ""
    if raw_fish == "" or #parse_scan(raw_fish) == 0 then
        raw_fish = core.send_command("NODE_SCAN_fish") or ""
    end
    merge_usable_nodes(raw_fish, "fish", merge)

    if CFG.include_vein_nodes then
        merge_usable_nodes(core.send_command("NODE_SCAN_USABLE_Vein") or "", "vein", merge)
    end

    if CFG.use_fishing_spots then
        local fish_raw = (core.gathering.fishing_spots and core.gathering.fishing_spots())
            or core.send_command("FISHING_SPOTS") or ""
        if fish_raw ~= "" and fish_raw ~= "NONE" and not fish_raw:match("^fallback=1") then
            local fish_list
            if core.gathering.get_fishing then
                fish_list = core.gathering.get_fishing()
            else
                fish_list = parse_fishing_spots_raw(fish_raw)
            end
            for _, e in ipairs(fish_list) do
                if (e.hidden or 0) == 0 then
                    merge(e, "spot")
                end
            end
        end
    end

    local list = {}
    for _, v in pairs(by_ptr) do
        if (v.usable == 1 or v.usable == nil) and not is_skipped(v.uid, v.ptr) then
            list[#list + 1] = v
        end
    end
    table.sort(list, function(a, b) return (a.dist or 999) < (b.dist or 999) end)
    return list
end

local function is_safe()
    local hp = core.player.hp()
    if not hp or hp <= 0 then return false, string.format("Dead (hp=%s)", tostring(hp)) end
    if core.player.combat() then return false, "In combat" end
    if core.player.frozen() then return false, "Frozen" end
    if hp < CFG.rest_hp then return false, string.format("Low HP (%.0f%%)", hp) end
    return true, nil
end

local function ptr_to_gather_cmd(p)
    if not p then return nil end
    local s = tostring(p):gsub("^0[xX]", ""):upper()
    if s == "" then return nil end
    return "GATHER_PTR_" .. s
end

local function try_use(spot)
    if spot.ptr then
        if core.gathering.gather_by_ptr then
            return core.gathering.gather_by_ptr(spot.ptr) or ""
        end
        local cmd = ptr_to_gather_cmd(spot.ptr)
        if cmd then return core.send_command(cmd) or "" end
        return ""
    end
    if spot.name and spot.name ~= "?" then
        return core.gathering.use_entity(spot.name) or ""
    end
    return ""
end

local function find_inventory_item_by_substring(sub)
    if not sub or sub == "" then return nil end
    local ok, inv = pcall(core.inventory.get_items)
    if not ok or not inv then return nil end
    local needle = sub:lower()
    for _, item in ipairs(inv) do
        local n = item.name and item.name:lower() or ""
        if n:find(needle, 1, true) then return item end
    end
    return nil
end

local function fishing_tick()
    local now = ethy.now()
    local poll = POLL_RATE + (math.random() - 0.5) * POLL_JITTER * 2
    if now - last_tick < poll then return end
    last_tick = now

    if not CFG.running then
        if STATE ~= "idle" then STATE = "idle" end
        pending_item_uid = nil
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

    local safe, reason = is_safe()
    if not safe then
        status_msg = reason .. " — paused"
        STATE = "idle"
        return
    end

    if STATE == "idle" then
        local spots = collect_candidates()
        if #spots == 0 then
            status_msg = string.format("No spots within %dm", CFG.max_range)
            return
        end
        local spot = spots[1]
        stats.attempts = stats.attempts + 1
        status_msg = string.format("Using %s (%.0fm)", spot.name or "?", spot.dist or 0)

        local r
        pending_item_uid = nil
        local sub = CFG.fishing_item_substring
        if sub and sub ~= "" then
            local it = find_inventory_item_by_substring(sub)
            if it and it.uid then
                pending_item_uid = it.uid
                r = "OK"
                status_msg = string.format("Walk → %s (%.0fm), then item %s",
                    spot.name or "?", spot.dist or 0, it.name or sub)
            else
                log("No inventory item matching %q — falling back to gather", sub)
                r = try_use(spot)
            end
        else
            r = try_use(spot)
        end
        if r:find("OK") or r:find("USED") or r:find("GATHER") then
            current_spot = spot
            pos_history = {}
            walk_start = now
            STATE = "walking"
        elseif r == "NONE" or r == "NOT_FOUND" or r == "STALE_PTR" then
            skip_spot(spot.uid, spot.ptr)
            stats.skipped = stats.skipped + 1
        end
        return
    end

    if STATE == "walking" then
        local x, y = get_pos_xy()
        if x then
            pos_history[#pos_history + 1] = { x, y }
            if #pos_history > MOVE_HISTORY then table.remove(pos_history, 1) end
            if #pos_history == MOVE_HISTORY and positions_settled(pos_history) then
                local nx, ny = current_spot.x or x, current_spot.y or y
                local dx, dy = x - nx, y - ny
                local arrive_dist = math.sqrt(dx * dx + dy * dy)
                if arrive_dist > 8 then
                    log("Unreachable: %s (%.1fm), skip", current_spot.name or "?", arrive_dist)
                    pending_item_uid = nil
                    skip_spot(current_spot.uid, current_spot.ptr)
                    stats.skipped = stats.skipped + 1
                    STATE = "idle"
                    return
                end
                activity_start = now
                if pending_item_uid then
                    local uid = pending_item_uid
                    pending_item_uid = nil
                    local ur = (core.inventory.use_item and core.inventory.use_item(uid)) or ""
                    log("USE_ITEM uid=%s → %s", tostring(uid), tostring(ur))
                    if not (tostring(ur):find("OK", 1, true)) then
                        status_msg = string.format("Item use failed: %s", tostring(ur))
                    end
                end
                STATE = "fishing"
                return
            end
        end
        local elapsed = now - walk_start
        status_msg = string.format("Walking (%.0fs)", elapsed)
        if elapsed > MOVE_TIMEOUT then
            pending_item_uid = nil
            skip_spot(current_spot.uid, current_spot.ptr)
            stats.skipped = stats.skipped + 1
            STATE = "idle"
        end
        return
    end

    if STATE == "fishing" then
        local elapsed = now - activity_start
        local left = CFG.activity_wait - elapsed
        status_msg = string.format("Fishing %s (%.0fs left)", current_spot.name or "?", math.max(0, left))
        if elapsed >= CFG.activity_wait then
            stats.used = stats.used + 1
            skip_spot(current_spot.uid, current_spot.ptr)
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

local function render_window()
    if not show_window then return end

    ui.set_next_window_size(340, 420)
    ui.set_next_window_pos(24, 120)
    local visible, open = ui.begin_window("Fishing Loop")

    if not open then
        show_window = false
        CFG.running = false
        ui.end_window()
        return
    end

    -- pcall: pipe/API errors during buttons must not skip End() or ImGui asserts "Missing End()"
    local draw_ok, draw_err = pcall(function()
        if not visible then return end
        if CFG.running then
            ui.text_colored(0.3, 1.0, 0.85, "RUNNING")
        else
            ui.text_colored(0.6, 0.6, 0.6, "STOPPED")
        end
        ui.same_line()
        ui.text("  " .. status_msg)
        ui.separator()

        if CFG.running then
            if ui.button("Stop##fish") then
                CFG.running = false
                STATE = "idle"
                pending_item_uid = nil
                log("Stopped")
            end
        else
            if ui.button("Start##fish") then
                CFG.running = true
                ethy.human.session.start()
                log("Started")
            end
        end
        ui.same_line()
        ui.text(string.format("  OK: %d  Skip: %d", stats.used, stats.skipped))
        ui.separator()

        CFG.max_range     = ui.slider_int("Range (m)", CFG.max_range, 8, 80)
        CFG.activity_wait = ui.slider_int("Wait after arrive (s)", CFG.activity_wait, 6, 45)
        CFG.rest_hp       = ui.slider_int("Pause if HP below %", CFG.rest_hp, 10, 90)
        CFG.humanize      = ui.checkbox("Humanize (breaks)", CFG.humanize)
        CFG.skip_bobber   = ui.checkbox("Skip bobber/hook/bait names", CFG.skip_bobber)
        CFG.include_vein_nodes = ui.checkbox("Include ore veins (Copper Vein, …)", CFG.include_vein_nodes)
        CFG.use_fishing_spots  = ui.checkbox("Use FISHING_SPOTS (real matches only)", CFG.use_fishing_spots)
        ui.text("Note: DLL fallback=1 (all props) is ignored. Vein scan = Copper Vein etc. near water.")
        ui.text("Item fishing: set CFG.fishing_item_substring (top of main.lua), e.g. \"Fishing Stick\".")
        ui.text("Then: walk to spot → USE_ITEM on first matching bag name (no gather at pick).")

        ui.separator()
        if ui.button("Scan now##fish") then
            local spots = collect_candidates()
            log("Candidates: %d", #spots)
            for i = 1, math.min(8, #spots) do
                local s = spots[i]
                log("  #%d  %s  dist=%.1f  %s  ptr=%s",
                    i, s.name or "?", s.dist or 0, s.source or "?", tostring(s.ptr or "?"))
            end
        end
        ui.same_line()
        if ui.button("Dump FISHING_SPOTS##fish") then
            local raw = core.gathering.fishing_spots() or ""
            log("RAW len=%d", #raw)
            local chunk = 220
            for i = 1, #raw, chunk do
                log("  %s", raw:sub(i, i + chunk - 1))
            end
        end
    end)

    ui.end_window()

    if not draw_ok then
        log("Window UI error: %s", tostring(draw_err))
    end
end

ethy.on_update(function()
    fishing_tick()
end)

ethy.on_render(function()
    render_window()
end)

ethy.print("Fishing Loop ready.")
