--[[
╔══════════════════════════════════════════════════════════════╗
║              EventBus — Reactive Event System                ║
║                                                              ║
║  Subscribe to game events with callbacks instead of polling. ║
║  Supports conditional triggers (hp_below, buff_gained, etc). ║
║                                                              ║
║  Usage:                                                      ║
║    local events = require("common/_api/event_bus")           ║
║    events.on("combat_start", function() ... end)             ║
║    events.on("hp_below", 30, function() ... end)             ║
╚══════════════════════════════════════════════════════════════╝
]]

local events = {}

-- Internal storage
local _listeners = {}       -- { event_name = { {fn, ...}, ... } }
local _once_listeners = {}  -- same but auto-removed after fire
local _conditionals = {}    -- polled conditions: { check_fn, callback, id, fired }
local _next_id = 1

-- Previous-frame state for edge detection
local _prev = {
    in_combat = false,
    has_target = false,
    target_uid = 0,
    is_dead = false,
    hp = 100,
    mp = 100,
    is_moving = false,
    buffs = {},  -- set of active buff names
}

-- ══════════════════════════════════════════════════════════════
-- Core API
-- ══════════════════════════════════════════════════════════════

--- Subscribe to an event. Returns a handle for unsubscribe.
--- events.on("combat_start", fn)
--- events.on("hp_below", 30, fn)    -- conditional with threshold
function events.on(event_name, ...)
    local args = {...}
    local fn, extra

    if type(args[#args]) == "function" then
        fn = table.remove(args)
        extra = args
    else
        error("events.on: last argument must be a function")
    end

    local id = _next_id
    _next_id = _next_id + 1

    if not _listeners[event_name] then
        _listeners[event_name] = {}
    end

    _listeners[event_name][#_listeners[event_name] + 1] = {
        fn = fn,
        args = extra,
        id = id,
    }

    return id
end

--- Subscribe once — auto-removes after first fire.
function events.once(event_name, ...)
    local args = {...}
    local fn = table.remove(args)

    if not _once_listeners[event_name] then
        _once_listeners[event_name] = {}
    end

    local id = _next_id
    _next_id = _next_id + 1

    _once_listeners[event_name][#_once_listeners[event_name] + 1] = {
        fn = fn,
        args = args,
        id = id,
    }

    return id
end

--- Unsubscribe by handle ID.
function events.off(handle_id)
    for name, list in pairs(_listeners) do
        for i = #list, 1, -1 do
            if list[i].id == handle_id then
                table.remove(list, i)
                return true
            end
        end
    end
    for name, list in pairs(_once_listeners) do
        for i = #list, 1, -1 do
            if list[i].id == handle_id then
                table.remove(list, i)
                return true
            end
        end
    end
    return false
end

--- Manually emit an event (for custom events).
function events.emit(event_name, ...)
    local fired = false

    local list = _listeners[event_name]
    if list then
        for _, entry in ipairs(list) do
            entry.fn(...)
            fired = true
        end
    end

    local once = _once_listeners[event_name]
    if once then
        _once_listeners[event_name] = nil
        for _, entry in ipairs(once) do
            entry.fn(...)
            fired = true
        end
    end

    return fired
end

--- Remove all listeners for an event (or all events if nil).
function events.clear(event_name)
    if event_name then
        _listeners[event_name] = nil
        _once_listeners[event_name] = nil
    else
        _listeners = {}
        _once_listeners = {}
        _conditionals = {}
    end
end

--- Register a conditional trigger that fires when check_fn() returns true.
--- Fires once, then rearms when check_fn returns false again.
function events.when(check_fn, callback)
    local id = _next_id
    _next_id = _next_id + 1
    _conditionals[#_conditionals + 1] = {
        check = check_fn,
        fn = callback,
        id = id,
        fired = false,
    }
    return id
end

-- ══════════════════════════════════════════════════════════════
-- Tick — call this every frame/update to drive edge detection
-- ══════════════════════════════════════════════════════════════

function events.tick(state)
    -- state = { hp, mp, in_combat, has_target, target_uid, target_name,
    --           is_dead, is_moving, buffs = {name=true, ...} }

    local p = _prev

    -- Combat edges
    if state.in_combat and not p.in_combat then
        events.emit("combat_start")
    end
    if not state.in_combat and p.in_combat then
        events.emit("combat_end")
    end

    -- Death edges
    if state.is_dead and not p.is_dead then
        events.emit("player_died")
    end
    if not state.is_dead and p.is_dead then
        events.emit("player_revived")
    end

    -- Target edges
    if state.has_target and not p.has_target then
        events.emit("target_acquired", state.target_name, state.target_uid)
    end
    if not state.has_target and p.has_target then
        events.emit("target_lost")
    end
    if state.has_target and p.has_target and state.target_uid ~= p.target_uid then
        events.emit("target_changed", state.target_name, state.target_uid)
    end

    -- Movement edges
    if state.is_moving and not p.is_moving then
        events.emit("movement_start")
    end
    if not state.is_moving and p.is_moving then
        events.emit("movement_stop")
    end

    -- HP/MP threshold crossing (check listeners for thresholds)
    local function check_threshold(event_prefix, current, previous)
        local list = _listeners[event_prefix]
        if list then
            for _, entry in ipairs(list) do
                local threshold = entry.args[1] or 30
                if current <= threshold and previous > threshold then
                    entry.fn(current, threshold)
                end
            end
        end
        local once = _once_listeners[event_prefix]
        if once then
            local remaining = {}
            for _, entry in ipairs(once) do
                local threshold = entry.args[1] or 30
                if current <= threshold and previous > threshold then
                    entry.fn(current, threshold)
                else
                    remaining[#remaining + 1] = entry
                end
            end
            _once_listeners[event_prefix] = #remaining > 0 and remaining or nil
        end
    end

    check_threshold("hp_below", state.hp, p.hp)
    check_threshold("mp_below", state.mp, p.mp)

    -- HP/MP recovery threshold (crossed upward)
    local function check_above(event_prefix, current, previous)
        local list = _listeners[event_prefix]
        if list then
            for _, entry in ipairs(list) do
                local threshold = entry.args[1] or 90
                if current >= threshold and previous < threshold then
                    entry.fn(current, threshold)
                end
            end
        end
    end

    check_above("hp_above", state.hp, p.hp)
    check_above("mp_above", state.mp, p.mp)

    -- Buff edges
    if state.buffs then
        for name, _ in pairs(state.buffs) do
            if not p.buffs[name] then
                events.emit("buff_gained", name)
            end
        end
        for name, _ in pairs(p.buffs) do
            if not state.buffs[name] then
                events.emit("buff_lost", name)
            end
        end
    end

    -- Target died
    if state.target_dead and not p.target_dead then
        events.emit("target_died", state.target_name, state.target_uid)
    end

    -- Conditional triggers
    for _, cond in ipairs(_conditionals) do
        local result = cond.check()
        if result and not cond.fired then
            cond.fn()
            cond.fired = true
        elseif not result and cond.fired then
            cond.fired = false  -- rearm
        end
    end

    -- Update previous state
    _prev = {
        in_combat = state.in_combat or false,
        has_target = state.has_target or false,
        target_uid = state.target_uid or 0,
        target_name = state.target_name,
        is_dead = state.is_dead or false,
        is_moving = state.is_moving or false,
        hp = state.hp or 100,
        mp = state.mp or 100,
        buffs = state.buffs or {},
        target_dead = state.target_dead or false,
    }
end

--- Get count of active listeners.
function events.count()
    local n = 0
    for _, list in pairs(_listeners) do n = n + #list end
    for _, list in pairs(_once_listeners) do n = n + #list end
    n = n + #_conditionals
    return n
end

return events
