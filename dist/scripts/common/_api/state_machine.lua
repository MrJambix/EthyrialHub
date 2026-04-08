--[[
╔══════════════════════════════════════════════════════════════╗
║          StateMachine — FSM Framework for Game Bots          ║
║                                                              ║
║  Define states with enter/update/exit callbacks and          ║
║  automatic transitions based on conditions.                  ║
║                                                              ║
║  Usage:                                                      ║
║    local SM = require("common/_api/state_machine")           ║
║    local bot = SM.new({                                      ║
║      idle = {                                                ║
║        enter  = function() print("Idling") end,             ║
║        update = function() find_target() end,                ║
║        transitions = {                                       ║
║          { to = "pull", when = function() return has_t end } ║
║        }                                                     ║
║      },                                                      ║
║    }, "idle")                                                ║
║    bot:tick()  -- call every frame                           ║
╚══════════════════════════════════════════════════════════════╝
]]

local SM = {}
SM.__index = SM

--- Create a new state machine.
--- @param states table  { state_name = { enter, update, exit, transitions } }
--- @param initial string  Starting state name
--- @param name string  Optional name for logging
function SM.new(states, initial, name)
    local self = setmetatable({}, SM)
    self.states = states
    self.current = initial
    self.previous = nil
    self.name = name or "FSM"
    self.state_time = 0          -- time spent in current state (seconds)
    self.state_enter_time = core and core.time() or os.clock()
    self.total_ticks = 0
    self.transition_count = 0
    self._paused = false
    self._hooks = {}  -- { on_enter = {}, on_exit = {}, on_transition = {} }

    -- Call enter on initial state
    local st = states[initial]
    if st and st.enter then
        st.enter()
    end

    return self
end

--- Tick the state machine (call every frame).
function SM:tick()
    if self._paused then return end

    self.total_ticks = self.total_ticks + 1
    local now = core and core.time() or os.clock()
    self.state_time = now - self.state_enter_time

    local st = self.states[self.current]
    if not st then return end

    -- Check transitions first
    if st.transitions then
        for _, tr in ipairs(st.transitions) do
            local condition = tr.when or tr[2]  -- support both {to, when} and named
            local target = tr.to or tr[1]

            if condition and condition() then
                self:go(target)
                return
            end
        end
    end

    -- Run update
    if st.update then
        st.update(self.state_time)
    end
end

--- Force transition to a specific state.
function SM:go(new_state)
    if not self.states[new_state] then
        if core and core.log_error then
            core.log_error("[" .. self.name .. "] Unknown state: " .. tostring(new_state))
        end
        return
    end

    local old = self.current
    local old_st = self.states[old]

    -- Exit old state
    if old_st and old_st.exit then
        old_st.exit()
    end

    -- Fire hooks
    self:_fire_hook("on_exit", old, new_state)
    self:_fire_hook("on_transition", old, new_state)

    -- Update state
    self.previous = old
    self.current = new_state
    self.state_enter_time = core and core.time() or os.clock()
    self.state_time = 0
    self.transition_count = self.transition_count + 1

    -- Enter new state
    local new_st = self.states[new_state]
    if new_st and new_st.enter then
        new_st.enter()
    end

    self:_fire_hook("on_enter", new_state, old)
end

--- Pause the state machine.
function SM:pause()
    self._paused = true
end

--- Resume the state machine.
function SM:resume()
    self._paused = false
end

--- Check if in a specific state.
function SM:is(state_name)
    return self.current == state_name
end

--- Get how long we've been in the current state.
function SM:time_in_state()
    return self.state_time
end

--- Register a hook: "on_enter", "on_exit", "on_transition"
function SM:hook(event, fn)
    if not self._hooks[event] then
        self._hooks[event] = {}
    end
    self._hooks[event][#self._hooks[event] + 1] = fn
end

function SM:_fire_hook(event, ...)
    local hooks = self._hooks[event]
    if hooks then
        for _, fn in ipairs(hooks) do
            fn(...)
        end
    end
end

--- Get a debug summary string.
function SM:debug()
    return string.format("[%s] state=%s prev=%s time=%.1fs ticks=%d transitions=%d",
        self.name, self.current, tostring(self.previous),
        self.state_time, self.total_ticks, self.transition_count)
end

return SM
