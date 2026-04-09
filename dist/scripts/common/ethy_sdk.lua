--[[
╔══════════════════════════════════════════════════════════════╗
║                    EthySDK — High Level Wrapper              ║
║                                                              ║
║  EthySDK — High-level scripting API for EthyrialHub.         ║
║  Provides a clean, easy-to-use API on top of the core C++    ║
║  bindings. Import once, use everywhere.                      ║
║                                                              ║
║  Usage:                                                      ║
║    local ethy = require("common/ethy_sdk")                   ║
║    local player = ethy.get_player()                          ║
║    ethy.print("Hello from EthySDK!")                         ║
╚══════════════════════════════════════════════════════════════╝
]]

---@type ethy_sdk_api
local ethy = {}

-- Re-export enums and Vec3 for convenience
ethy.enums = enums
ethy.Vec3  = require("common/_api/vec3")

-- ══════════════════════════════════════════════════════════════
-- Framework Modules (lazy-loaded, available via ethy.*)
-- ══════════════════════════════════════════════════════════════

ethy.events      = require("common/_api/event_bus")
ethy.scheduler   = require("common/_api/scheduler")
ethy.fsm         = require("common/_api/state_machine")
ethy.waypoints   = require("common/_api/waypoints")
ethy.buffs       = require("common/_api/buff_tracker")
ethy.items       = require("common/_api/item_rules")
ethy.combat_stats = require("common/_api/combat_stats")
ethy.signals     = require("common/_api/signals")
ethy.spell_queue = require("common/_api/spell_queue")
ethy.zone        = require("common/_api/zone")

-- ══════════════════════════════════════════════════════════════
-- Logging
-- ══════════════════════════════════════════════════════════════

function ethy.print(...)
    local args = {...}
    local parts = {}
    for _, v in ipairs(args) do
        parts[#parts + 1] = tostring(v)
    end
    core.log(table.concat(parts, " "))
end

function ethy.printf(fmt, ...)
    core.log(string.format(fmt, ...))
end

function ethy.log(filename, ...)
    local args = {...}
    local parts = {}
    for _, v in ipairs(args) do
        parts[#parts + 1] = tostring(v)
    end
    local msg = table.concat(parts, " ")
    core.log("[" .. filename .. "] " .. msg)
end

function ethy.logf(filename, fmt, ...)
    core.log("[" .. filename .. "] " .. string.format(fmt, ...))
end

function ethy.log_warning(msg)
    core.log_warning(msg)
end

function ethy.log_error(msg)
    core.log_error(msg)
end

-- ══════════════════════════════════════════════════════════════
-- Time
-- ══════════════════════════════════════════════════════════════

function ethy.now()
    return core.time()
end

function ethy.now_ms()
    return core.time_ms()
end

function ethy.time_since(past_time)
    return ethy.now() - past_time
end

function ethy.time_since_ms(past_time_ms)
    return ethy.now_ms() - past_time_ms
end

function ethy.time_until(future_time)
    local remaining = future_time - ethy.now()
    return remaining > 0 and remaining or 0
end

-- Scheduled callbacks
local _scheduled = {}

function ethy.after(delay_seconds, callback)
    _scheduled[#_scheduled + 1] = {
        fire_at = ethy.now() + delay_seconds,
        fn = callback,
    }
end

-- Call from on_update to process scheduled callbacks
function ethy._process_scheduled()
    local now = ethy.now()
    local remaining = {}
    for _, entry in ipairs(_scheduled) do
        if now >= entry.fire_at then
            entry.fn()
        else
            remaining[#remaining + 1] = entry
        end
    end
    _scheduled = remaining
end

-- ══════════════════════════════════════════════════════════════
-- Player / Target helpers
-- ══════════════════════════════════════════════════════════════

function ethy.get_player()
    return core.object_manager.get_local_player()
end

function ethy.target()
    local player = ethy.get_player()
    if player and player:has_target() then
        return player:get_target_info()
    end
    return nil
end

function ethy.me()
    return ethy.get_player()
end

-- ══════════════════════════════════════════════════════════════
-- Buff helpers
-- ══════════════════════════════════════════════════════════════

ethy.buff_manager = {}

function ethy.buff_manager.get_buff_data(name)
    return core.buff_manager.get_buff_data(name)
end

function ethy.buff_manager.has_buff(name)
    return core.buff_manager.has_buff(name)
end

function ethy.buff_manager.get_stacks(name)
    return core.buff_manager.get_stacks(name)
end

function ethy.buff_manager.get_all_buffs()
    return core.buff_manager.get_all_buffs()
end

-- ══════════════════════════════════════════════════════════════
-- Spell helpers
-- ══════════════════════════════════════════════════════════════

ethy.spell_book = {}

function ethy.spell_book.is_ready(name)
    return core.spell_book.is_spell_ready(name)
end

function ethy.spell_book.cast(name)
    return core.spell_book.cast_spell(name)
end

function ethy.spell_book.get_cooldown(name)
    return core.spell_book.get_cooldown(name)
end

function ethy.spell_book.get_all()
    return core.spell_book.get_all_spells()
end

function ethy.spell_book.dump_all()
    return core.spells.dump_all()
end

-- ══════════════════════════════════════════════════════════════
-- Callback registration shortcuts
-- ══════════════════════════════════════════════════════════════

function ethy.on_update(fn)
    core.register_on_update_callback(function()
        ethy._process_scheduled()
        fn()
    end)
end

function ethy.on_render(fn)
    core.register_on_render_callback(fn)
end

function ethy.on_render_menu(fn)
    core.register_on_render_menu_callback(fn)
end

function ethy.on_spell_cast(fn)
    core.register_on_spell_cast_callback(fn)
end

function ethy.on_combat_enter(fn)
    core.register_on_combat_enter_callback(fn)
end

function ethy.on_combat_leave(fn)
    core.register_on_combat_leave_callback(fn)
end

function ethy.on_buff_applied(fn)
    core.register_on_buff_applied_callback(fn)
end

function ethy.on_buff_removed(fn)
    core.register_on_buff_removed_callback(fn)
end

function ethy.on_target_changed(fn)
    core.register_on_target_changed_callback(fn)
end

-- ══════════════════════════════════════════════════════════════
-- Menu helpers
-- ══════════════════════════════════════════════════════════════

ethy.menu = {}

function ethy.menu.checkbox(id, label, default)
    return core.menu.checkbox(id, label, default or false)
end

function ethy.menu.slider_int(id, label, default, min, max)
    return core.menu.slider_int(id, label, default or 0, min or 0, max or 100)
end

function ethy.menu.slider_float(id, label, default, min, max)
    return core.menu.slider_float(id, label, default or 0.0, min or 0.0, max or 1.0)
end

function ethy.menu.combobox(id, label, options, default_idx)
    return core.menu.combobox(id, label, options, default_idx or 0)
end

function ethy.menu.tree_node(id, label)
    return core.menu.tree_node(id, label)
end

function ethy.menu.button(id, label)
    return core.menu.button(id, label)
end

-- ══════════════════════════════════════════════════════════════
-- Loot Rolling (Need / Greed / Pass)
-- ══════════════════════════════════════════════════════════════

ethy.loot_roll = {}

-- Detect whether the native core.loot_roll bindings exist (requires rebuilt C++).
-- Falls back to core.send_command() if not available yet.
local _has_native_lr = (type(core.loot_roll) == "table")

local function _lr_send(cmd)
    return core.send_command(cmd)
end

--- Scan for pending NeedGreed roll windows.
--- Returns raw IPC string. "NONE" if nothing pending.
function ethy.loot_roll.scan_raw()
    if _has_native_lr then return core.loot_roll.scan() end
    return _lr_send("NEED_GREED_SCAN")
end

--- Parse scan results into a Lua table.
--- Each entry: { item, timer, remaining, ptr, qptr }
function ethy.loot_roll.scan()
    local raw = ethy.loot_roll.scan_raw()
    if not raw or raw == "NONE" or raw:find("^NO_") then return {} end
    local results = {}
    for entry in raw:gmatch("[^#]+") do
        entry = entry:match("^%s*(.-)%s*$")
        if entry ~= "" and not entry:match("^count=") then
            local t = {}
            for k, v in entry:gmatch("([%w_]+)=([^|]+)") do
                t[k] = tonumber(v) or v
            end
            if t.item then results[#results + 1] = t end
        end
    end
    return results
end

--- Send a choice (NEED, GREED, or PASS) for a specific roll window.
--- ptr: the hex pointer string from scan results.
function ethy.loot_roll.choose(ptr, choice)
    if _has_native_lr then return core.loot_roll.choose(tostring(ptr), tostring(choice)) end
    return _lr_send("NEED_GREED_CHOOSE " .. tostring(ptr) .. " " .. tostring(choice))
end

--- Convenience: greed on all pending rolls.
function ethy.loot_roll.greed_all()
    if _has_native_lr then return core.loot_roll.greed_all() end
    return _lr_send("NEED_GREED_GREED_ALL")
end

-- ══════════════════════════════════════════════════════════════
-- Humanization — makes bot behavior look natural to server-side
-- detection. All timing functions return seconds.
-- ══════════════════════════════════════════════════════════════

ethy.human = {}

math.randomseed(os.time() + (os.clock() * 1000))

local function box_muller()
    local u1 = math.random()
    local u2 = math.random()
    if u1 < 1e-10 then u1 = 1e-10 end
    return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
end

function ethy.human.gaussian_delay(mean_ms, std_ms)
    local d = mean_ms + box_muller() * std_ms
    d = math.max(30, math.min(d, mean_ms * 4))
    return d / 1000
end

function ethy.human.reaction_delay()
    return ethy.human.gaussian_delay(250, 55)
end

function ethy.human.cast_delay()
    return ethy.human.gaussian_delay(180, 40)
end

function ethy.human.jittered_sleep(base_seconds)
    local jitter = base_seconds * (0.7 + math.random() * 0.6)
    _ethy_sleep(jitter)
end

function ethy.human.should_misplay(chance)
    chance = chance or 0.03
    return math.random() < chance
end

function ethy.human.random_pause(min_s, max_s)
    min_s = min_s or 0.5
    max_s = max_s or 3.0
    _ethy_sleep(min_s + math.random() * (max_s - min_s))
end

-- Session manager: tracks play time, triggers periodic micro-breaks
-- and longer breaks to mimic human session patterns.

ethy.human.session = {
    _start_time = nil,
    _last_break = nil,
    _micro_interval = nil,
    _break_interval = nil,
}

function ethy.human.session.start()
    local s = ethy.human.session
    s._start_time = ethy.now()
    s._last_break = ethy.now()
    s._micro_interval = 300 + math.random() * 600     -- 5-15 min between micro-pauses
    s._break_interval = 2700 + math.random() * 2700   -- 45-90 min between real breaks
end

function ethy.human.session.check()
    local s = ethy.human.session
    if not s._start_time then s.start() end

    local now = ethy.now()
    local since_break = now - s._last_break

    if since_break >= s._break_interval then
        local break_len = 180 + math.random() * 420   -- 3-10 min break
        s._last_break = now + break_len
        s._break_interval = 2700 + math.random() * 2700
        s._micro_interval = 300 + math.random() * 600
        return "long_break", break_len
    end

    if since_break >= s._micro_interval then
        local pause_len = 3 + math.random() * 15      -- 3-18 sec micro-pause
        s._last_break = now
        s._micro_interval = 300 + math.random() * 600
        return "micro_pause", pause_len
    end

    return "ok", 0
end

function ethy.human.session.elapsed()
    if not ethy.human.session._start_time then return 0 end
    return ethy.now() - ethy.human.session._start_time
end

-- ══════════════════════════════════════════════════════════════
-- Drawing API helpers
-- ══════════════════════════════════════════════════════════════

-- Ground telegraph shapes (filled mesh on ground plane):
--   core.draw.ground_circle(slot, cx,cy,cz, radius, r,g,b,a, segments)
--   core.draw.ground_cone(slot, cx,cy,cz, radius, yaw, angle, r,g,b,a, segments)
--   core.draw.ground_line(slot, x1,y1,z1, x2,y2,z2, width, r,g,b,a)
--   core.draw.ground_donut(slot, cx,cy,cz, innerR, outerR, r,g,b,a, segments)
--   core.draw.ground_hide(slot)
--   core.draw.ground_clear()
--
-- Telegraph scan (returns table of entries with extended data):
--   core.telegraphs.scan() -> { { uid, name, x,y,z, dir, spell, duration, elapsed, remaining,
--       ptype, radius, mid_radius, inner_radius, htype, off_x, off_z,
--       rank, spell_range, cast_time, channel_time, target_type,
--       target_x, target_y, target_z, move_speed, move_dir }, ... }
--
-- Rank values: 0=Normal, 1=Rare, 2=Elite, 3=Boss
-- Target types: 0=Self, 1=GroundSelf, 2=FriendlyTarget, 3=HostileTarget, 4=Ground

-- ══════════════════════════════════════════════════════════════
-- Teleport API
-- ══════════════════════════════════════════════════════════════

--- Teleport to position (full sync: stops movement, writes position, snaps transform, updates tiles).
--- Returns parsed result table: {ok, from, to, snap, set_pos, tile, stop}
function ethy.teleport(x, y, z)
    local raw = core.send_command(string.format("TELEPORT %.2f %.2f %.2f", x, y, z or 0))
    if not raw or raw:sub(1,3) ~= "OK|" then return raw end
    -- Parse the OK|from=x,y,z|to=x,y,z|snap=N|... response
    local result = { ok = true, raw = raw }
    for kv in raw:gmatch("[^|]+") do
        local k, v = kv:match("^(.-)=(.+)$")
        if k then
            local num = tonumber(v)
            if num then result[k] = num else result[k] = v end
        end
    end
    return result
end

--- Snap to position (calls Entity.SnapToPosition only, lighter than full teleport).
function ethy.snap_to(x, y, z)
    return core.send_command(string.format("SNAP_TO %.2f,%.2f,%.2f", x, y, z or 0))
end

--- Freeze player at a position (written every frame, suppresses server corrections).
--- Call ethy.teleport_release() to stop holding.
function ethy.teleport_hold(x, y, z)
    return core.send_command(string.format("TELEPORT_HOLD %.2f %.2f %.2f", x, y, z or 0))
end

--- Stop freezing position (release the hold).
function ethy.teleport_release()
    return core.send_command("TELEPORT_RELEASE")
end

--- Check if position hold is active.
--- Returns "HOLDING|pos=x,y,z" or "RELEASED"
function ethy.teleport_status()
    return core.send_command("TELEPORT_STATUS")
end

--- Teleport and hold — teleports then freezes at the destination.
--- This is the strongest teleport: writes position every frame to prevent rubber-banding.
--- MUST call ethy.teleport_release() when done.
function ethy.teleport_lock(x, y, z)
    local result = ethy.teleport(x, y, z)
    ethy.teleport_hold(x, y, z or 0)
    return result
end

--- Get teleport debug info (position fields, pointers, waypoints).
function ethy.teleport_debug()
    return core.send_command("TELEPORT_DEBUG")
end

-- ══════════════════════════════════════════════════════════════
-- Weight Lock API — bypass overweight movement restriction
-- ══════════════════════════════════════════════════════════════

--- Lock MaxWeight to 99999 (or custom value) so overweight debuff never applies.
--- @param max_weight number|nil  Custom max weight value (default 99999)
function ethy.weight_lock(max_weight)
    if max_weight then
        return core.send_command(string.format("WEIGHT_LOCK %.0f", max_weight))
    end
    return core.send_command("WEIGHT_LOCK")
end

--- Remove the weight lock, restoring normal weight checking.
function ethy.weight_unlock()
    return core.send_command("WEIGHT_UNLOCK")
end

--- Get weight status: locked state, current weight, max weight, overweight flag.
function ethy.weight_status()
    return core.send_command("WEIGHT_STATUS")
end

-- ══════════════════════════════════════════════════════════════
-- Network / Protocol API
-- ══════════════════════════════════════════════════════════════

function ethy.dump_server_state()
    return core.send_command("DUMP_SERVER_STATE")
end

function ethy.dump_protocol()
    return core.send_command("DUMP_PROTOCOL")
end

function ethy.dump_net_classes()
    return core.send_command("DUMP_NET_CLASSES")
end

-- ══════════════════════════════════════════════════════════════
-- Structured Server / Network Queries
-- ══════════════════════════════════════════════════════════════

ethy.server = {}

function ethy.server.info()
    local raw = core.send_command("SERVER_INFO")
    if not raw or raw:sub(1,3) == "ERR" then return nil end
    local t = {}
    for kv in raw:gmatch("[^|]+") do
        local k, v = kv:match("^(.-)=(.+)$")
        if k then
            local num = tonumber(v)
            if num then t[k] = num else t[k] = v end
        end
    end
    return t
end

function ethy.server.ip()
    return core.send_command("SERVER_IP")
end

function ethy.server.port()
    local r = core.send_command("SERVER_PORT")
    return tonumber(r) or 0
end

function ethy.server.latency()
    local r = core.send_command("SERVER_LATENCY")
    return tonumber(r) or 0
end

function ethy.server.rtt()
    local r = core.send_command("SERVER_RTT")
    return tonumber(r) or 0
end

function ethy.server.status()
    return core.send_command("SERVER_STATUS")
end

function ethy.server.stats()
    local raw = core.send_command("SERVER_STATS")
    if not raw or raw:sub(1,3) == "ERR" then return nil end
    local t = {}
    for kv in raw:gmatch("[^|]+") do
        local k, v = kv:match("^(.-)=(.+)$")
        if k then
            local num = tonumber(v)
            if num then t[k] = num else t[k] = v end
        end
    end
    return t
end

function ethy.server.net_peer_status()
    return core.send_command("NET_PEER_STATUS")
end

function ethy.server.player_uid()
    local r = core.send_command("PLAYER_UID")
    return tonumber(r) or 0
end

function ethy.server.account_id()
    return core.send_command("ACCOUNT_ID")
end

-- ══════════════════════════════════════════════════════════════
-- Protocol Enum Lookups
-- ══════════════════════════════════════════════════════════════

ethy.protocol = {}

function ethy.protocol.msg_type(id)
    return core.send_command("MSG_TYPE " .. tostring(id))
end

function ethy.protocol.msg_type_name(name)
    return core.send_command("MSG_TYPE_NAME " .. name)
end

function ethy.protocol.msg_type_all()
    return core.send_command("MSG_TYPE_ALL")
end

function ethy.protocol.admin_msg_type(id)
    return core.send_command("ADMIN_MSG_TYPE " .. tostring(id))
end

function ethy.protocol.admin_msg_type_all()
    return core.send_command("ADMIN_MSG_TYPE_ALL")
end

function ethy.protocol.editor_msg_type(id)
    return core.send_command("EDITOR_MSG_TYPE " .. tostring(id))
end

function ethy.protocol.editor_msg_type_all()
    return core.send_command("EDITOR_MSG_TYPE_ALL")
end

-- ══════════════════════════════════════════════════════════════
-- Reflection — Method Addresses, Field Offsets
-- ══════════════════════════════════════════════════════════════

ethy.reflect = {}

function ethy.reflect.method_addr(class_name, method_name, arg_count)
    arg_count = arg_count or 0
    return core.send_command(string.format("METHOD_ADDR %s %s %d", class_name, method_name, arg_count))
end

function ethy.reflect.method_list(class_name)
    return core.send_command("METHOD_LIST " .. class_name)
end

function ethy.reflect.field_offset(class_name, field_name)
    return core.send_command("FIELD_OFFSET " .. class_name .. " " .. field_name)
end

function ethy.reflect.field_list(class_name)
    return core.send_command("FIELD_LIST " .. class_name)
end

-- ══════════════════════════════════════════════════════════════
-- Module PE Queries
-- ══════════════════════════════════════════════════════════════

ethy.modules = {}

function ethy.modules.base(module_name)
    return core.send_command("MODULE_BASE " .. module_name)
end

function ethy.modules.section(module_name, section_name)
    return core.send_command("MODULE_SECTION " .. module_name .. " " .. section_name)
end

function ethy.modules.dump()
    return core.send_command("DUMP_MODULES")
end

-- ══════════════════════════════════════════════════════════════
-- Scene / Zone
-- ══════════════════════════════════════════════════════════════

function ethy.scene_name()
    return core.send_command("SCENE_NAME")
end

-- ══════════════════════════════════════════════════════════════
-- Memory Tools API
-- ══════════════════════════════════════════════════════════════

ethy.memory = {}

function ethy.memory.dump_modules()
    return core.send_command("DUMP_MODULES")
end

function ethy.memory.read_bytes(addr, count)
    return core.send_command(string.format("READ_BYTES %s %d", addr, count))
end

function ethy.memory.patch_bytes(addr, hex_bytes)
    return core.send_command("PATCH_BYTES " .. addr .. " " .. hex_bytes)
end

function ethy.memory.nop(addr, count)
    return core.send_command(string.format("NOP_BYTES %s %d", addr, count))
end

function ethy.memory.restore(addr, original_hex)
    return core.send_command("RESTORE_BYTES " .. addr .. " " .. original_hex)
end

function ethy.memory.scan_aob(module_name, pattern)
    return core.send_command("SCAN_AOB " .. module_name .. " " .. pattern)
end

function ethy.memory.watch(addr, mode)
    mode = mode or "access"
    return core.send_command("WATCH_ADDR " .. addr .. " " .. mode)
end

function ethy.memory.watch_clear(dr_index)
    return core.send_command("WATCH_CLEAR " .. tostring(dr_index))
end

function ethy.memory.watch_clear_all()
    return core.send_command("WATCH_CLEAR_ALL")
end

function ethy.memory.watch_status()
    return core.send_command("WATCH_STATUS")
end

function ethy.memory.watch_hits()
    return core.send_command("WATCH_HITS")
end

function ethy.memory.alloc_exec(size)
    return core.send_command("ALLOC_EXEC " .. tostring(size))
end

function ethy.memory.free_exec(addr, size)
    return core.send_command(string.format("FREE_EXEC %s %d", addr, size))
end

function ethy.memory.write_exec(addr, hex_bytes)
    return core.send_command("WRITE_EXEC " .. addr .. " " .. hex_bytes)
end

-- ══════════════════════════════════════════════════════════════
-- Player State (comprehensive)
-- ══════════════════════════════════════════════════════════════

function ethy.player_state()
    local raw = core.send_command("PLAYER_STATE")
    if not raw or raw == "NO_RESPONSE" then return nil end
    local state = {}
    for kv in raw:gmatch("[^|]+") do
        local k, v = kv:match("^(.-)=(.+)$")
        if k then
            local num = tonumber(v)
            if num then state[k] = num
            elseif v == "true" then state[k] = true
            elseif v == "false" then state[k] = false
            else state[k] = v end
        end
    end
    return state
end

-- ══════════════════════════════════════════════════════════════
-- Convenience: async / wait (delegates to scheduler)
-- ══════════════════════════════════════════════════════════════

function ethy.async(fn, name)
    return ethy.scheduler.async(fn, name)
end

function ethy.wait(seconds)
    return ethy.scheduler.wait(seconds)
end

function ethy.wait_until(fn, timeout)
    return ethy.scheduler.wait_until(fn, timeout)
end

-- ══════════════════════════════════════════════════════════════
-- Convenience: quick state queries
-- ══════════════════════════════════════════════════════════════

function ethy.hp()
    if conn and conn.get_hp then return conn.get_hp() end
    return 100
end

function ethy.mp()
    if conn and conn.get_mp then return conn.get_mp() end
    return 100
end

function ethy.in_combat()
    if conn and conn.in_combat then return conn.in_combat() end
    return false
end

function ethy.is_dead()
    if conn and conn.is_dead then return conn.is_dead() end
    return false
end

function ethy.has_target()
    if conn and conn.has_target then return conn.has_target() end
    return false
end

function ethy.is_moving()
    if conn and conn.is_moving then return conn.is_moving() end
    return false
end

-- ══════════════════════════════════════════════════════════════
-- Unified Tick — drives all framework subsystems
-- Call ethy.tick() in your main loop or on_update callback
-- to power events, scheduler, waypoints, items, zone, etc.
-- ══════════════════════════════════════════════════════════════

function ethy.tick()
    -- 1. Build current game state snapshot for event bus
    local state = {
        hp = ethy.hp(),
        mp = ethy.mp(),
        in_combat = ethy.in_combat(),
        is_dead = ethy.is_dead(),
        has_target = ethy.has_target(),
        is_moving = ethy.is_moving(),
        target_uid = 0,
        target_name = nil,
        target_dead = false,
        buffs = ethy.buffs.active_set(),
    }

    -- Fill target info if available
    if state.has_target and conn then
        if conn.get_target_uid then state.target_uid = conn.get_target_uid() or 0 end
        if conn.get_target_name then
            local n = conn.get_target_name()
            if n and n ~= "" and n ~= "NO_TARGET" then state.target_name = n end
        end
        if conn.is_target_dead then state.target_dead = conn.is_target_dead() end
    end

    -- 2. Drive all subsystems
    ethy.events.tick(state)
    ethy.scheduler.tick()
    ethy.waypoints.tick()
    ethy.items.tick()
    ethy.zone.tick()

    -- 3. Process scheduled callbacks
    ethy._process_scheduled()

    -- 4. Track combat stats if session is active
    if ethy.combat_stats.elapsed() > 0 then
        local target_hp = nil
        if state.has_target and conn and conn.get_target_hp then
            target_hp = conn.get_target_hp()
        end
        ethy.combat_stats.tick(state.in_combat, target_hp)
    end
end

-- ══════════════════════════════════════════════════════════════
-- State Machine helper — creates FSM with ethy integration
-- ══════════════════════════════════════════════════════════════

function ethy.state_machine(states, initial, name)
    return ethy.fsm.new(states, initial, name)
end

-- ══════════════════════════════════════════════════════════════
-- Terrain & Walkability — tile data, walk grids, blocking ents
-- ══════════════════════════════════════════════════════════════

ethy.terrain = {}

--- Raw terrain dump around (cx, cy) with hex bytes + parsed fields per tile.
---@param cx number Tile X center
---@param cy number Tile Y center
---@param floor? number Floor layer (default 0)
---@param radius? number Scan radius in tiles (default 5, max 50)
---@return string|nil raw Raw IPC response or nil on error
function ethy.terrain.dump(cx, cy, floor, radius)
    floor = floor or 0; radius = radius or 5
    local raw = core.terrain and core.terrain.dump
        and core.terrain.dump(cx, cy, floor, radius)
        or core.send_command(string.format("TERRAIN_DUMP %d %d %d %d", cx, cy, floor, radius))
    if not raw or raw:sub(1, 3) == "ERR" then return nil end
    return raw
end

--- Walkability grid + blocking entities around (cx, cy).
---@param cx number Tile X center
---@param cy number Tile Y center
---@param floor? number Floor layer (default 0)
---@param radius? number Scan radius in tiles (default 5, max 50)
---@return string|nil raw Raw IPC response or nil on error
function ethy.terrain.walkability(cx, cy, floor, radius)
    floor = floor or 0; radius = radius or 5
    local raw = core.terrain and core.terrain.walkability
        and core.terrain.walkability(cx, cy, floor, radius)
        or core.send_command(string.format("WALKABILITY_GRID %d %d %d %d", cx, cy, floor, radius))
    if not raw or raw:sub(1, 3) == "ERR" then return nil end
    return raw
end

--- Parse a WALKABILITY_GRID response into a 2D boolean grid + blocking list.
---@param raw string Raw IPC response from walkability()
---@return table grid  { [y] = { [x] = true/false } }
---@return table blockers  { {class=, name=, x=, y=, z=, tile_x=, tile_y=} ... }
function ethy.terrain.parse_walkability(raw)
    local grid = {}
    local blockers = {}
    if not raw then return grid, blockers end

    for line in raw:gmatch("[^\n]+") do
        -- ROW|y|11100111...
        local ry, bits = line:match("^ROW|(%d+)|(%d+)$")
        if not ry then ry, bits = line:match("^ROW|%-?(%d+)|([01]+)$") end
        if ry and bits then
            local y = tonumber(ry)
            grid[y] = grid[y] or {}
            -- we need the center x to map column index → tile x
            -- just store raw bits; caller maps with known cx/radius
            grid[y]._bits = bits
        end

        -- BLOCK|class=X|name=Y|pos=1.0,2.0,3.0|tile=5,6|collider=1|static=0
        if line:sub(1, 6) == "BLOCK|" then
            local b = {}
            b.class   = line:match("class=([^|]+)")
            b.name    = line:match("name=([^|]+)")
            local px, py, pz = line:match("pos=([%d%.%-]+),([%d%.%-]+),([%d%.%-]+)")
            b.x = tonumber(px); b.y = tonumber(py); b.z = tonumber(pz)
            local tx, ty = line:match("tile=([%d%-]+),([%d%-]+)")
            b.tile_x = tonumber(tx); b.tile_y = tonumber(ty)
            b.collider = line:match("collider=1") and true or false
            b.is_static = line:match("static=1") and true or false
            blockers[#blockers + 1] = b
        end
    end
    return grid, blockers
end

-- ═══════════════════════════════════════════════════════════════════════
-- Pathfinding (delegates to common/pathfinder module)
-- ═══════════════════════════════════════════════════════════════════════

ethy.pathfinder = require("common/pathfinder")

return ethy
