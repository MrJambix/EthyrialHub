-- ═══════════════════════════════════════════════════════════════
--  core.spells — Spells API
-- ═══════════════════════════════════════════════════════════════

local spells = {}

function spells.cast(name)
    return _cmd("CAST_" .. name)
end

function spells.is_ready(name)
    return _cmd("SPELL_READY " .. name) == "1"
end

function spells.cooldown(name)
    return N(_cmd("SPELL_CD " .. name))
end

function spells.info(name)
    return _cmd("SPELL_INFO " .. name)
end

function spells.count()
    return tonumber(_cmd("SPELL_COUNT")) or 0
end

function spells.all()
    return _cmd("SPELLS_ALL")
end

function spells.autocast_on(name)
    return _cmd("AUTOCAST_ON " .. name)
end

function spells.autocast_off(name)
    return _cmd("AUTOCAST_OFF " .. name)
end

-- ── Parsed helpers ──

function spells.get_all()
    return _parse_lines(_cmd("SPELLS_ALL"))
end

function spells.get_info(name)
    return _parse_single(_cmd("SPELL_INFO " .. name))
end

function spells.dump_all()
    return _parse_lines(_cmd("SPELL_DUMP"))
end

return spells
