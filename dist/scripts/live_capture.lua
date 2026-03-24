--[[
╔══════════════════════════════════════════════════════════════╗
║          Live Capture — Real-Time Interaction Tracer          ║
║                                                              ║
║  Records everything you do in-game with full detail:         ║
║    • IL2CPP method addresses (UseEntity, Target, MoveTo)     ║
║    • Entity pointers, classes, and field offsets              ║
║    • All IPC commands and responses                          ║
║    • State transitions (combat, movement, targeting)         ║
║    • Gathering interactions & node details                   ║
║                                                              ║
║  Output:                                                     ║
║    C++ trace → ethytool_trace.log (method-level detail)      ║
║    Lua  log  → live_capture_log.txt (state + events)         ║
║                                                              ║
║  Just play normally — everything gets recorded.              ║
╚══════════════════════════════════════════════════════════════╝
]]

local cmd = conn.send_command

-- ═══════════════════════════════════════════════════════════════
-- Configuration
-- ═══════════════════════════════════════════════════════════════

local TICK_SEC          = 0.15
local POS_THRESHOLD     = 0.3
local ENEMY_SCAN_TICKS  = 20    -- ~3 sec at 0.15s tick
local NODE_SCAN_TICKS   = 33    -- ~5 sec
local MOUSE_CHECK_TICKS = 3     -- ~0.5 sec

-- ═══════════════════════════════════════════════════════════════
-- File setup — resolve script directory for output
-- ═══════════════════════════════════════════════════════════════

local script_dir = "."
do
    local info = debug.getinfo(1, "S")
    if info and info.source then
        local src = info.source:gsub("^@", "")
        script_dir = src:match("^(.*)[/\\]") or "."
    end
end

local trace_path = script_dir .. "/ethytool_trace.log"
local log_path   = script_dir .. "/live_capture_log.txt"

local file = io.open(log_path, "w")
if not file then
    log_path = "live_capture_log.txt"
    file = io.open(log_path, "w")
end
if not file then
    print("[ERROR] Cannot open log file for writing.")
    return
end

local line_count = 0

local function W(text)
    file:write(text .. "\n")
    line_count = line_count + 1
    if line_count % 20 == 0 then file:flush() end
end

local function ts()
    return os.date("%H:%M:%S")
end

local function log_event(category, msg, detail)
    local line = string.format("[%s] [%-10s] %s", ts(), category, msg)
    if detail then line = line .. " | " .. detail end
    W(line)
    print(line)
end

local function kv_string(t)
    if not t then return "" end
    local parts = {}
    for k, v in pairs(t) do
        parts[#parts + 1] = k .. "=" .. tostring(v)
    end
    return table.concat(parts, " | ")
end

-- ═══════════════════════════════════════════════════════════════
-- Start C++ trace engine (captures method ptrs, offsets, invokes)
-- ═══════════════════════════════════════════════════════════════

print("╔══════════════════════════════════════════════════════════╗")
print("║          Live Capture — Starting Trace Engine            ║")
print("╚══════════════════════════════════════════════════════════╝")

local trace_result = cmd("TRACE_START " .. trace_path)
if trace_result == "TRACE_OK" then
    log_event("SYSTEM", "C++ trace engine started", "file=" .. trace_path)
else
    log_event("SYSTEM", "C++ trace engine failed: " .. tostring(trace_result))
    log_event("SYSTEM", "Continuing with Lua-only capture")
end

-- ═══════════════════════════════════════════════════════════════
-- Dump IL2CPP method addresses + offsets at startup
-- ═══════════════════════════════════════════════════════════════

log_event("SYSTEM", "Lua capture started", "file=" .. log_path)

W("")
W("═══════════════════════════════════════════════════════════════")
W("  IL2CPP METHOD ADDRESSES")
W("═══════════════════════════════════════════════════════════════")

local methods_raw = cmd("METHOD_DUMP")
if methods_raw and methods_raw ~= "IL2CPP_NOT_AVAILABLE" and methods_raw ~= "UNKNOWN_CMD" then
    for pair in methods_raw:gmatch("[^|]+") do
        W("  " .. pair)
    end
    log_event("METHODS", "IL2CPP methods resolved", methods_raw:sub(1, 200))
else
    W("  (not available — rebuild DLL for METHOD_DUMP support)")
    log_event("METHODS", "METHOD_DUMP not available (" .. tostring(methods_raw) .. ")")
end

W("")
W("═══════════════════════════════════════════════════════════════")
W("  FIELD OFFSETS (Entity classes)")
W("═══════════════════════════════════════════════════════════════")

local offsets_raw = cmd("OFFSET_DUMP")
if offsets_raw and offsets_raw ~= "" and offsets_raw:sub(1,3) ~= "IL2" then
    for line in offsets_raw:gmatch("[^\n]+") do
        W("  " .. line)
    end
    log_event("OFFSETS", "Entity field offsets dumped")
end

W("")
W("═══════════════════════════════════════════════════════════════")
W("  KEY CLASS LAYOUTS")
W("═══════════════════════════════════════════════════════════════")

local key_classes = {
    "Entity", "LivingEntity", "LocalPlayerEntity",
    "LocalPlayerInput", "Doodad", "GrowingDoodad",
    "MonsterEntity", "EntityManager"
}
for _, cls in ipairs(key_classes) do
    local dump = cmd("DUMP_CLASS_FULL " .. cls)
    if dump and dump ~= "NOT_FOUND" and dump ~= "" then
        W("  ─── " .. cls .. " ───")
        for part in dump:gmatch("[^|]+") do
            if #part < 200 then W("    " .. part) end
        end
    end
end

W("")
W("═══════════════════════════════════════════════════════════════")
W("  LIVE EVENT LOG — " .. os.date("%Y-%m-%d %H:%M:%S"))
W("═══════════════════════════════════════════════════════════════")
W("")

-- ═══════════════════════════════════════════════════════════════
-- Initial player snapshot
-- ═══════════════════════════════════════════════════════════════

local function safe_num(v) return tonumber(v) or 0 end
local function safe_bool(v) return v == "1" or v == true end

local function get_pos()
    local raw = cmd("PLAYER_POS")
    if not raw or raw == "" then return nil end
    local x, y, z = raw:match("([^,]+),([^,]+),([^,]+)")
    if x then return { x = tonumber(x), y = tonumber(y), z = tonumber(z) } end
    return nil
end

local function parse_kv(raw)
    if not raw or raw == "" or raw == "NONE" or raw == "NO_TARGET" then return nil end
    local t = {}
    for k, v in raw:gmatch("([%w_]+)=([^|]+)") do
        if k == "ptr" then
            t[k] = v
        else
            local num = tonumber(v)
            t[k] = (num ~= nil) and num or v
        end
    end
    return next(t) and t or nil
end

local function parse_lines(raw)
    if not raw or raw == "" or raw == "NONE" then return {} end
    local results = {}
    for entry in raw:gmatch("[^#]+") do
        entry = entry:match("^%s*(.-)%s*$")
        if entry ~= "" and not entry:match("^count=") and not entry:match("^fallback=") then
            local t = parse_kv(entry)
            if t then results[#results + 1] = t end
        end
    end
    return results
end

-- Combat state decoder (matches enums.combat_state)
local COMBAT_STATES = {
    [0] = "IDLE", [1] = "IN_COMBAT", [2] = "DEAD", [3] = "FROZEN",
    [4] = "RESTING", [5] = "GATHERING", [6] = "CASTING",
    [7] = "CHANNELING", [8] = "MOUNTED",
}

local function decode_condition_mask(mask)
    local active = {}
    for bit = 0, 8 do
        if mask & (1 << bit) ~= 0 then
            active[#active + 1] = COMBAT_STATES[bit] or ("BIT_" .. bit)
        end
    end
    if #active == 0 then return "NONE" end
    return table.concat(active, "+")
end

-- State tracking
local state = {
    pos       = get_pos() or { x = 0, y = 0, z = 0 },
    hp        = safe_num(cmd("PLAYER_HP")),
    mp        = safe_num(cmd("PLAYER_MP")),
    combat    = safe_bool(cmd("PLAYER_COMBAT")),
    moving    = safe_bool(cmd("PLAYER_MOVING")),
    has_target = safe_bool(cmd("HAS_TARGET")),
    target_name = "",
    target_uid  = 0,
    mouse_entity = "",
    tick = 0,

    -- Animation & progress tracking
    anim_state      = -1,
    anim_last_state = -1,
    anim_count      = 0,
    condition_mask  = 0,
    condition_str   = "NONE",
    prog_vis        = 0.0,
    loot_windows    = 0,
    move_state      = 0,
}

log_event("SNAPSHOT", "Initial player state",
    string.format("pos=%.1f,%.1f,%.1f hp=%.0f%% mp=%.0f%% combat=%s moving=%s",
        state.pos.x, state.pos.y, state.pos.z,
        state.hp, state.mp,
        tostring(state.combat), tostring(state.moving)))

-- ═══════════════════════════════════════════════════════════════
-- Command interception — log USE/GATHER/TARGET interactions
-- ═══════════════════════════════════════════════════════════════

local function log_cmd_if_interesting(command, response)
    if command:match("^USE_") or command:match("^GATHER_") or command:match("^TARGET_")
        or command:match("^SCAN_") or command:match("^NODE_SCAN")
        or command:match("^SCENE_SCAN") or command:match("^MOVE_TO")
        or command:match("^CAST_") or command:match("^SPELL_")
        or command:match("^EQUIP_") or command:match("^UNEQUIP_") then

        local resp_short = response and response:sub(1, 300) or "(nil)"
        log_event("IPC", command, "response=" .. resp_short)
    end
end

local real_cmd = cmd
cmd = function(command)
    local response = real_cmd(command)
    log_cmd_if_interesting(command, response)
    return response
end

-- ═══════════════════════════════════════════════════════════════
-- Main capture loop
-- ═══════════════════════════════════════════════════════════════

print("[Live Capture] Running — play the game normally.")
print("[Live Capture] All interactions are being recorded.")
print("[Live Capture] Press Stop to end the capture session.")
print("")

local ticks_since_enemy_scan = 999
local ticks_since_node_scan  = 999
local ticks_since_mouse_check = 999

-- ── Diagnostic: raw field snapshot for detecting gathering state ──
local last_snapshot = ""
local function take_snapshot()
    local parts = {}
    parts[#parts+1] = "moving=" .. tostring(real_cmd("PLAYER_MOVING"))
    parts[#parts+1] = "combat=" .. tostring(real_cmd("PLAYER_COMBAT"))
    parts[#parts+1] = "frozen=" .. tostring(real_cmd("PLAYER_FROZEN"))
    parts[#parts+1] = "cmask=" .. tostring(real_cmd("PLAYER_CONDITION_MASK"))

    local anim = real_cmd("PLAYER_ANIMATION") or ""
    parts[#parts+1] = "anim={" .. anim .. "}"

    local ibar = real_cmd("PLAYER_INFOBAR") or ""
    parts[#parts+1] = "ibar={" .. ibar .. "}"

    local mvmt = real_cmd("PLAYER_MOVEMENT") or ""
    local ms = mvmt:match("move_state=(%d+)") or "?"
    parts[#parts+1] = "move_state=" .. ms

    local pall = real_cmd("PLAYER_ALL") or ""
    local cm2 = pall:match("condition_mask=([%dx%dA-Fa-f]+)") or "?"
    local cs = pall:match("combat_state=(%d+)")
    if cs then parts[#parts+1] = "combat_state=" .. cs end
    parts[#parts+1] = "all_cmask=" .. cm2

    return table.concat(parts, " | ")
end

while not is_stopped() do
    state.tick = state.tick + 1
    ticks_since_enemy_scan = ticks_since_enemy_scan + 1
    ticks_since_node_scan  = ticks_since_node_scan + 1
    ticks_since_mouse_check = ticks_since_mouse_check + 1

    -- ── Diagnostic: log raw snapshot when ANY field changes ──
    local snap = take_snapshot()
    if snap ~= last_snapshot then
        log_event("SNAPSHOT", "STATE DELTA")
        W("    " .. snap)
        last_snapshot = snap
    end

    -- ── Position tracking ──
    local new_pos = get_pos()
    if new_pos then
        local dx = new_pos.x - state.pos.x
        local dy = new_pos.y - state.pos.y
        local dz = new_pos.z - state.pos.z
        local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
        if dist > POS_THRESHOLD then
            log_event("MOVE", string.format("%.1f,%.1f,%.1f -> %.1f,%.1f,%.1f (dist=%.2f)",
                state.pos.x, state.pos.y, state.pos.z,
                new_pos.x, new_pos.y, new_pos.z, dist))
            state.pos = new_pos
        end
    end

    -- ── Combat state ──
    local new_combat = safe_bool(real_cmd("PLAYER_COMBAT"))
    if new_combat ~= state.combat then
        log_event("STATE", new_combat and "ENTERED COMBAT" or "LEFT COMBAT")
        state.combat = new_combat
    end

    -- ── Movement state ──
    local new_moving = safe_bool(real_cmd("PLAYER_MOVING"))
    if new_moving ~= state.moving then
        log_event("STATE", new_moving and "STARTED MOVING" or "STOPPED MOVING",
            new_pos and string.format("pos=%.1f,%.1f,%.1f", new_pos.x, new_pos.y, new_pos.z) or nil)
        state.moving = new_moving
    end

    -- ── HP/MP changes ──
    local new_hp = safe_num(real_cmd("PLAYER_HP"))
    local new_mp = safe_num(real_cmd("PLAYER_MP"))
    if math.abs(new_hp - state.hp) > 1 then
        log_event("VITALS", string.format("HP: %.0f%% -> %.0f%%", state.hp, new_hp))
        state.hp = new_hp
    end
    if math.abs(new_mp - state.mp) > 2 then
        log_event("VITALS", string.format("MP: %.0f%% -> %.0f%%", state.mp, new_mp))
        state.mp = new_mp
    end

    -- ── Animation state tracking ──
    local anim_raw = real_cmd("PLAYER_ANIMATION")
    if anim_raw and anim_raw ~= "NO_PLAYER" then
        local anim = parse_kv(anim_raw)
        if anim then
            local new_anim_state = anim.state or -1
            local new_anim_last  = anim.last_state or -1
            local new_anim_count = anim.active_anim_count or 0

            if new_anim_state ~= state.anim_state then
                log_event("ANIM", string.format("STATE CHANGE: %d -> %d",
                    state.anim_state, new_anim_state),
                    string.format("last=%d active_count=%d interrupting=%s",
                        new_anim_last, new_anim_count,
                        tostring(anim.interrupting)))
                state.anim_state = new_anim_state
                state.anim_last_state = new_anim_last
            end
            if new_anim_count ~= state.anim_count then
                log_event("ANIM", string.format("ACTIVE ANIM COUNT: %d -> %d",
                    state.anim_count, new_anim_count))
                state.anim_count = new_anim_count
            end
        end
    end

    -- ── Condition mask (GATHERING / CASTING / CHANNELING detection) ──
    local mask_raw = real_cmd("PLAYER_CONDITION_MASK")
    local new_mask = safe_num(mask_raw)
    if new_mask ~= state.condition_mask then
        local old_str = decode_condition_mask(state.condition_mask)
        local new_str = decode_condition_mask(new_mask)
        log_event("CONDITION", string.format("%s -> %s (mask: 0x%X -> 0x%X)",
            old_str, new_str, state.condition_mask, new_mask))
        state.condition_mask = new_mask
        state.condition_str = new_str
    end

    -- ── Progress bar visibility (gathering/crafting progress) ──
    local infobar_raw = real_cmd("PLAYER_INFOBAR")
    if infobar_raw and infobar_raw ~= "NO_PLAYER" then
        local ibar = parse_kv(infobar_raw)
        if ibar then
            local new_prog = ibar.prog_vis or 0
            if math.abs(new_prog - state.prog_vis) > 0.01 then
                if new_prog > 0 and state.prog_vis == 0 then
                    log_event("PROGRESS", "PROGRESS BAR APPEARED",
                        string.format("prog_vis=%.3f entity_type=%s",
                            new_prog, tostring(ibar.entity_type)))
                elseif new_prog == 0 and state.prog_vis > 0 then
                    log_event("PROGRESS", "PROGRESS BAR GONE")
                else
                    log_event("PROGRESS", string.format("prog_vis: %.3f -> %.3f",
                        state.prog_vis, new_prog))
                end
                state.prog_vis = new_prog
            end
        end
    end

    -- ── Loot windows (opened / closed) ──
    local loot_raw = real_cmd("LOOT_WINDOW_COUNT")
    local new_loot = safe_num(loot_raw)
    if new_loot ~= state.loot_windows then
        if new_loot > state.loot_windows then
            log_event("LOOT", string.format("LOOT WINDOW OPENED (count: %d -> %d)",
                state.loot_windows, new_loot))
        else
            log_event("LOOT", string.format("LOOT WINDOW CLOSED (count: %d -> %d)",
                state.loot_windows, new_loot))
        end
        state.loot_windows = new_loot
    end

    -- ── Target tracking ──
    local new_has_target = safe_bool(real_cmd("HAS_TARGET"))
    if new_has_target then
        local tname = real_cmd("TARGET_NAME") or ""
        local tinfo_raw = real_cmd("TARGET_INFO_V2")
        local tinfo = parse_kv(tinfo_raw)

        if tname ~= state.target_name then
            log_event("TARGET", "NEW TARGET: " .. tname,
                tinfo and kv_string(tinfo) or nil)
            state.target_name = tname
            state.target_uid = tinfo and tinfo.uid or 0
        end
    elseif state.has_target then
        log_event("TARGET", "TARGET LOST (was: " .. state.target_name .. ")")
        state.target_name = ""
        state.target_uid = 0
    end
    state.has_target = new_has_target

    -- ── Entity under mouse (periodic) ──
    if ticks_since_mouse_check >= MOUSE_CHECK_TICKS then
        ticks_since_mouse_check = 0
        local eum = real_cmd("ENTITY_UNDER_MOUSE")
        if eum and eum ~= "NONE" and eum ~= state.mouse_entity then
            local parsed = parse_kv(eum)
            if parsed then
                log_event("MOUSE", "ENTITY UNDER CURSOR",
                    string.format("ptr=%s class=%s name=%s uid=%s",
                        tostring(parsed.ptr), tostring(parsed.class),
                        tostring(parsed.name), tostring(parsed.uid)))
            end
            state.mouse_entity = eum
        elseif eum == "NONE" and state.mouse_entity ~= "" then
            state.mouse_entity = ""
        end
    end

    -- ── Enemy scan (periodic) ──
    if ticks_since_enemy_scan >= ENEMY_SCAN_TICKS then
        ticks_since_enemy_scan = 0
        local enemies_raw = real_cmd("SCAN_ENEMIES")
        local enemies = parse_lines(enemies_raw)
        if #enemies > 0 then
            log_event("SCAN", string.format("ENEMIES IN RANGE: %d", #enemies))
            for i = 1, math.min(#enemies, 5) do
                local e = enemies[i]
                W(string.format("    [%d] ptr=%s name=%s uid=%s dist=%.1f hp=%.2f boss=%s elite=%s",
                    i, tostring(e.ptr), tostring(e.name), tostring(e.uid),
                    e.dist or 0, e.hp or 0,
                    tostring(e.boss), tostring(e.elite)))
            end
        end
    end

    -- ── Node scan (periodic) ──
    if ticks_since_node_scan >= NODE_SCAN_TICKS then
        ticks_since_node_scan = 0
        local nodes_raw = real_cmd("NODE_SCAN")
        local nodes = parse_lines(nodes_raw)
        if #nodes > 0 then
            log_event("SCAN", string.format("GATHER NODES: %d", #nodes))
            for i = 1, math.min(#nodes, 5) do
                local n = nodes[i]
                W(string.format("    [%d] ptr=%s class=%s name=%s type=%s usable=%s dist=%.1f",
                    i, tostring(n.ptr), tostring(n.class), tostring(n.name),
                    tostring(n.type), tostring(n.usable), n.dist or 0))
            end
        end
    end

    _ethy_sleep(TICK_SEC)
end

-- ═══════════════════════════════════════════════════════════════
-- Cleanup
-- ═══════════════════════════════════════════════════════════════

W("")
W("═══════════════════════════════════════════════════════════════")
W("  CAPTURE SESSION ENDED — " .. os.date("%Y-%m-%d %H:%M:%S"))
W("  Total events logged: " .. line_count)
W("═══════════════════════════════════════════════════════════════")

file:flush()
file:close()

real_cmd("TRACE_STOP")

print("")
print("╔══════════════════════════════════════════════════════════╗")
print("║          Live Capture — Session Complete                 ║")
print("╠══════════════════════════════════════════════════════════╣")
print("║  Lua log:   " .. log_path)
print("║  C++ trace: " .. trace_path)
print("║  Events:    " .. line_count)
print("╚══════════════════════════════════════════════════════════╝")
