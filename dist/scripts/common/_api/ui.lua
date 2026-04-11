-- ═══════════════════════════════════════════════════════════════
--  core.ui — UI Popups API (riddle / anti-AFK)
-- ═══════════════════════════════════════════════════════════════

local ui = {}

function ui.messagebox_dump()
    return _cmd("MESSAGEBOX_DUMP")
end

function ui.messagebox_click(label)
    return _cmd("MESSAGEBOX_CLICK " .. label)
end

return ui
