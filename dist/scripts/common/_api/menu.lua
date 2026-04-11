-- ═══════════════════════════════════════════════════════════════
--  core.menu — Menu Stubs (stateful defaults, no ImGui)
--  Overridden by C++ MenuSystem bindings when available.
-- ═══════════════════════════════════════════════════════════════

local menu = {}
local _menu_state = {}

function menu.checkbox(id, label, def)
    if _menu_state[id] == nil then _menu_state[id] = def end
    return _menu_state[id]
end

function menu.slider_int(id, label, def, mn, mx)
    if _menu_state[id] == nil then _menu_state[id] = def end
    return _menu_state[id]
end

function menu.slider_float(id, label, def, mn, mx)
    if _menu_state[id] == nil then _menu_state[id] = def end
    return _menu_state[id]
end

function menu.combobox(id, label, opts, def)
    if _menu_state[id] == nil then _menu_state[id] = def or 0 end
    return _menu_state[id]
end

function menu.button(id, label) return false end
function menu.tree_node(id, label) return false end

return menu
