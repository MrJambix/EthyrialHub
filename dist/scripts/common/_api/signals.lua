--[[
╔══════════════════════════════════════════════════════════════╗
║        Signals — Script-to-Script Communication              ║
║                                                              ║
║  Shared variable store and signal system for coordinating    ║
║  between multiple scripts (e.g. combat + gather + healer).  ║
║                                                              ║
║  Usage:                                                      ║
║    local sig = require("common/_api/signals")                ║
║    sig.set("mode", "combat")                                 ║
║    sig.signal("pull_ready")                                  ║
║    sig.wait_signal("pull_ready")                             ║
╚══════════════════════════════════════════════════════════════╝
]]

local signals = {}

-- Shared state — persists across requires since Lua caches modules
local _store = {}         -- { key = { value, updated_at } }
local _signals = {}       -- { name = { fired_at, data } }
local _waiters = {}       -- { { signal_name, callback, once } }

-- ══════════════════════════════════════════════════════════════
-- Shared Variable Store
-- ══════════════════════════════════════════════════════════════

--- Set a shared variable.
function signals.set(key, value)
    local now = core and core.time() or os.clock()
    _store[key] = { value = value, updated_at = now }
end

--- Get a shared variable (returns value, or default if not set).
function signals.get(key, default)
    local entry = _store[key]
    if entry then return entry.value end
    return default
end

--- Check if a key exists.
function signals.has(key)
    return _store[key] ~= nil
end

--- Remove a shared variable.
function signals.remove(key)
    _store[key] = nil
end

--- Get when a variable was last updated.
function signals.updated_at(key)
    local entry = _store[key]
    if entry then return entry.updated_at end
    return 0
end

--- Increment a numeric variable.
function signals.increment(key, amount)
    amount = amount or 1
    local current = signals.get(key, 0)
    signals.set(key, current + amount)
    return current + amount
end

--- Get all keys.
function signals.keys()
    local result = {}
    for k, _ in pairs(_store) do
        result[#result + 1] = k
    end
    return result
end

--- Get entire store as a table.
function signals.dump()
    local result = {}
    for k, v in pairs(_store) do
        result[k] = v.value
    end
    return result
end

-- ══════════════════════════════════════════════════════════════
-- Signal System
-- ══════════════════════════════════════════════════════════════

--- Fire a signal with optional data payload.
function signals.signal(name, data)
    local now = core and core.time() or os.clock()
    _signals[name] = { fired_at = now, data = data }

    -- Process waiters
    local remaining = {}
    for _, waiter in ipairs(_waiters) do
        if waiter.signal_name == name then
            waiter.callback(data)
            if not waiter.once then
                remaining[#remaining + 1] = waiter
            end
        else
            remaining[#remaining + 1] = waiter
        end
    end
    _waiters = remaining
end

--- Check if a signal has been fired (optionally within last N seconds).
function signals.check(name, max_age)
    local sig = _signals[name]
    if not sig then return false end
    if max_age then
        local now = core and core.time() or os.clock()
        if now - sig.fired_at > max_age then return false end
    end
    return true, sig.data
end

--- Clear a signal.
function signals.clear(name)
    _signals[name] = nil
end

--- Clear all signals.
function signals.clear_all()
    _signals = {}
end

--- Register a callback for when a signal fires.
--- @param name string      Signal name to wait for
--- @param callback function  Called with (data) when signal fires
--- @param once boolean      If true, auto-removes after first fire (default true)
function signals.on_signal(name, callback, once)
    if once == nil then once = true end
    _waiters[#_waiters + 1] = {
        signal_name = name,
        callback = callback,
        once = once,
    }
end

--- Blocking wait for a signal (for use in coroutine/scheduler).
--- Returns the signal data.
function signals.wait_signal(name, timeout)
    local sched = package.loaded["common/_api/scheduler"]
    if sched then
        sched.wait_until(function()
            return signals.check(name)
        end, timeout)
        local ok, data = signals.check(name)
        signals.clear(name)
        return data
    end
    return nil
end

-- ══════════════════════════════════════════════════════════════
-- Channel — named message queues for producer/consumer patterns
-- ══════════════════════════════════════════════════════════════

local _channels = {}

--- Push a message to a channel.
function signals.push(channel, message)
    if not _channels[channel] then _channels[channel] = {} end
    _channels[channel][#_channels[channel] + 1] = message
end

--- Pop a message from a channel (FIFO). Returns nil if empty.
function signals.pop(channel)
    local ch = _channels[channel]
    if not ch or #ch == 0 then return nil end
    return table.remove(ch, 1)
end

--- Peek at next message without removing it.
function signals.peek(channel)
    local ch = _channels[channel]
    if not ch or #ch == 0 then return nil end
    return ch[1]
end

--- Get channel queue length.
function signals.queue_size(channel)
    local ch = _channels[channel]
    return ch and #ch or 0
end

--- Clear a channel.
function signals.clear_channel(channel)
    _channels[channel] = nil
end

return signals
