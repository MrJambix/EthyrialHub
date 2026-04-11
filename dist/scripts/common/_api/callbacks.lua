-- ═══════════════════════════════════════════════════════════════
--  callbacks — Callback Registration & Update Loop
--  Sets core.register_on_* and global _ethy_run_loop directly.
-- ═══════════════════════════════════════════════════════════════

local _update_fns = {}

core.register_on_update_callback         = function(fn) _update_fns[#_update_fns + 1] = fn end
core.register_on_render_callback         = function(fn) end
core.register_on_render_menu_callback    = function(fn) end
core.register_on_spell_cast_callback     = function(fn) end
core.register_on_combat_enter_callback   = function(fn) end
core.register_on_combat_leave_callback   = function(fn) end
core.register_on_buff_applied_callback   = function(fn) end
core.register_on_buff_removed_callback   = function(fn) end
core.register_on_target_changed_callback = function(fn) end

function _ethy_run_loop()
    while not is_stopped() do
        for _, fn in ipairs(_update_fns) do
            local ok, err = pcall(fn)
            if not ok then core.log("[ERR] " .. tostring(err)) end
        end
        _ethy_sleep(0.3)
    end
end

return true
