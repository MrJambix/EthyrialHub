-- ═══════════════════════════════════════════════════════════════
--  core.spell_book — Spell Book API
-- ═══════════════════════════════════════════════════════════════

local sb = {}

function sb.is_spell_ready(name)
    return _cmd("SPELL_READY " .. name) == "1"
end

function sb.cast_spell(name)
    return _cmd("CAST_" .. name):find("OK") ~= nil
end

function sb.cast_spell_ooc(name)
    return _cmd("CAST_" .. name):find("OK") ~= nil
end

function sb.get_cooldown(name)
    return N(_cmd("SPELL_CD " .. name))
end

function sb.get_spell_info(name)
    return _cmd("SPELL_INFO " .. name)
end

function sb.get_spell_count()
    return tonumber(_cmd("SPELL_COUNT")) or 0
end

function sb.get_all_spells()
    return _cmd("SPELLS_ALL")
end

function sb.update() end

return sb
