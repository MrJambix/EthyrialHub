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

-- Re-export enums for convenience
ethy.enums = enums

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

return ethy
