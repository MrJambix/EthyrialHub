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

return ethy
