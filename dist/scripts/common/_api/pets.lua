-- ═══════════════════════════════════════════════════════════════
--  core.pets — Pets & Companions API
-- ═══════════════════════════════════════════════════════════════

local pets = {}

function pets.count()
    return tonumber(_cmd("PET_COUNT")) or 0
end

function pets.companion_full()
    return _cmd("COMPANION_FULL")
end

function pets.companions()
    return _cmd("COMPANIONS")
end

function pets.atk_speed()
    return _cmd("PET_ATK_SPEED")
end

function pets.set_atk_speed(val)
    return _cmd("PET_SET_ATK_SPEED " .. val)
end

function pets.rush_atk()
    return _cmd("PET_RUSH_ATK")
end

function pets.debug()
    return _cmd("PET_DEBUG")
end

-- ── Parsed helpers ──

function pets.get_companions()
    return _parse_single(_cmd("COMPANIONS"))
end

function pets.get_full()
    return _parse_single(_cmd("COMPANION_FULL"))
end

return pets
