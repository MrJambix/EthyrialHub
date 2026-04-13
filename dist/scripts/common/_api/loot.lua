-- ═══════════════════════════════════════════════════════════════
--  core.loot — Loot Display API
-- ═══════════════════════════════════════════════════════════════

local loot = {}

function loot.recent()
    return _cmd("LOOT_RECENT")
end

function loot.get_recent()
    return _parse_lines(_cmd("LOOT_RECENT"))
end

return loot
