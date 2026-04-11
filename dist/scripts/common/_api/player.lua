-- ═══════════════════════════════════════════════════════════════
--  core.player — Player API
-- ═══════════════════════════════════════════════════════════════

local player = {}

function player.hp()       return N(_cmd("PLAYER_HP")) end
function player.mp()       return N(_cmd("PLAYER_MP")) end
function player.max_hp()   return N(_cmd("PLAYER_MAX_HP")) end
function player.max_mp()   return N(_cmd("PLAYER_MAX_MP")) end
function player.pos()      return _cmd("PLAYER_POS") end
function player.moving()   return B(_cmd("PLAYER_MOVING")) end
function player.combat()   return B(_cmd("PLAYER_COMBAT")) end
function player.frozen()   return B(_cmd("PLAYER_FROZEN")) end
function player.job()      return _cmd("PLAYER_JOB") end
function player.gold()     return tonumber(_cmd("PLAYER_GOLD")) or 0 end
function player.speed()    return N(_cmd("PLAYER_SPEED")) end
function player.direction()    return N(_cmd("PLAYER_DIRECTION")) end
function player.attack_speed() return N(_cmd("PLAYER_ATTACK_SPEED")) end
function player.infamy()   return N(_cmd("PLAYER_INFAMY")) end
function player.food()     return N(_cmd("PLAYER_FOOD")) end
function player.pz_zone()  return B(_cmd("PLAYER_PZ_ZONE")) end
function player.spectator() return B(_cmd("PLAYER_SPECTATOR")) end
function player.wildlands() return B(_cmd("PLAYER_WILDLANDS")) end
function player.combat_level()     return N(_cmd("PLAYER_COMBAT_LEVEL")) end
function player.profession_level() return N(_cmd("PLAYER_PROFESSION_LEVEL")) end
function player.address()  return _cmd("PLAYER_ADDRESS") end
function player.phys_armor() return N(_cmd("PLAYER_PHYS_ARMOR")) end
function player.mag_armor()  return N(_cmd("PLAYER_MAG_ARMOR")) end
function player.all()       return _cmd("PLAYER_ALL") end
function player.info()      return _cmd("PLAYER_INFO") end
function player.movement()  return _cmd("PLAYER_MOVEMENT") end
function player.animation() return _cmd("PLAYER_ANIMATION") end
function player.infobar()   return _cmd("PLAYER_INFOBAR") end
function player.buffs()     return _cmd("PLAYER_BUFFS") end
function player.skills()    return _cmd("PLAYER_SKILLS") end
function player.talents()   return _cmd("PLAYER_TALENTS") end

function player.stacks(filter)
    return _cmd(filter and ("PLAYER_STACKS " .. filter) or "PLAYER_STACKS")
end

function player.skill(name)
    return _cmd("PLAYER_SKILL " .. name)
end

-- ── Parsed helpers ──

function player.get_all()
    return _parse_single(_cmd("PLAYER_ALL"))
end

function player.get_info()
    return _parse_single(_cmd("PLAYER_INFO"))
end

function player.get_movement()
    return _parse_single(_cmd("PLAYER_MOVEMENT"))
end

function player.get_skills()
    return _parse_lines(_cmd("PLAYER_SKILLS"))
end

function player.get_talents()
    return _parse_lines(_cmd("PLAYER_TALENTS"))
end

function player.get_buffs()
    return _parse_lines(_cmd("PLAYER_BUFFS"))
end

function player.get_position()
    local r = _cmd("PLAYER_POS")
    local x, y, z = r:match("([%d%.%-]+),([%d%.%-]+),([%d%.%-]+)")
    return { x = tonumber(x) or 0, y = tonumber(y) or 0, z = tonumber(z) or 0 }
end

return player
