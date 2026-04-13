-- ═══════════════════════════════════════════════════════════════
--  core.world — World API
-- ═══════════════════════════════════════════════════════════════

local world = {}

function world.scan_scene()
    return _cmd("SCAN_SCENE")
end

function world.scan_nearby()
    return _cmd("SCAN_NEARBY")
end

function world.active_quests()
    return _cmd("ACTIVE_QUESTS")
end

function world.nearby_count()
    return tonumber(_cmd("NEARBY_COUNT")) or 0
end

function world.scene_count()
    return tonumber(_cmd("SCENE_COUNT")) or 0
end

function world.scene_corpses()
    return _cmd("SCENE_CORPSES")
end

function world.entity_by_uid(uid)
    return _cmd("ENTITY_BY_UID " .. uid)
end

function world.companions()
    return _cmd("COMPANIONS")
end

function world.exit_game()
    return _cmd("EXIT_GAME")
end

function world.monsterdex_scan()
    return _cmd("MONSTERDEX_SCAN")
end

function world.monsterdex_nearby()
    return _cmd("MONSTERDEX_NEARBY")
end

function world.monsterdex_target()
    return _cmd("MONSTERDEX_TARGET")
end

function world.monsterdex_by_uid(uid)
    return _cmd("MONSTERDEX_BY_UID " .. uid)
end

function world.monsterdex_spells(uid)
    return _cmd("MONSTERDEX_SPELLS " .. uid)
end

-- ── Parsed helpers ──

function world.get_nearby()
    return _parse_lines(_cmd("SCAN_NEARBY"))
end

function world.get_scene()
    return _parse_lines(_cmd("SCAN_SCENE"))
end

function world.get_monsterdex_nearby()
    return _parse_lines(_cmd("MONSTERDEX_NEARBY"))
end

function world.get_monsterdex_target()
    local raw = _cmd("MONSTERDEX_TARGET")
    local list = _parse_lines(raw)
    return list[1]
end

-- ── Global / Character helpers ──

function world.global_state()
    return _cmd("GLOBAL_STATE")
end

function world.get_global_state()
    return _parse_single(_cmd("GLOBAL_STATE"))
end

function world.char_list()
    return _cmd("CHAR_LIST")
end

function world.get_char_list()
    return _parse_lines(_cmd("CHAR_LIST"))
end

function world.quest_detail(name)
    return _cmd("QUEST_DETAIL " .. name)
end

function world.get_quest_detail(name)
    local raw = _cmd("QUEST_DETAIL " .. name)
    if not raw or raw == "NOT_FOUND" then return nil end
    return _parse_lines(raw)
end

return world
