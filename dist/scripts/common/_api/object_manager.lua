-- ═══════════════════════════════════════════════════════════════
--  core.object_manager — Object Manager API
-- ═══════════════════════════════════════════════════════════════

local om = {}

function om.get_local_player()
    local p = {}
    function p:is_valid() return true end
    function p:get_name() return _cmd("PLAYER_ALL"):match("name=([^|]+)") or "" end
    function p:get_uid()
        local r = _cmd("PLAYER_ALL")
        return tonumber(r:match("uid=(%d+)")) or 0
    end
    function p:get_hp() return N(_cmd("PLAYER_HP")) end
    function p:get_mp() return N(_cmd("PLAYER_MP")) end
    function p:get_max_hp() return N(_cmd("PLAYER_MAX_HP")) end
    function p:get_max_mp() return N(_cmd("PLAYER_MAX_MP")) end
    function p:get_health_percent() return N(_cmd("PLAYER_HP")) end
    function p:get_mana_percent() return N(_cmd("PLAYER_MP")) end
    function p:get_job() return 0 end
    function p:get_job_string() return _cmd("PLAYER_JOB") end
    function p:get_position()
        local r = _cmd("PLAYER_POS")
        local x, y, z = r:match("([%d%.%-]+),([%d%.%-]+),([%d%.%-]+)")
        return { x = tonumber(x) or 0, y = tonumber(y) or 0, z = tonumber(z) or 0 }
    end
    function p:get_direction() return N(_cmd("PLAYER_DIRECTION")) end
    function p:get_move_speed() return N(_cmd("PLAYER_SPEED")) end
    function p:get_attack_speed() return N(_cmd("PLAYER_ATTACK_SPEED")) end
    function p:get_food() return N(_cmd("PLAYER_FOOD")) end
    function p:get_gold() return tonumber(_cmd("PLAYER_GOLD")) or 0 end
    function p:get_infamy() return N(_cmd("PLAYER_INFAMY")) end
    function p:get_phys_armor() return N(_cmd("PLAYER_PHYS_ARMOR")) end
    function p:get_mag_armor() return N(_cmd("PLAYER_MAG_ARMOR")) end
    function p:get_combat_level() return N(_cmd("PLAYER_COMBAT_LEVEL")) end
    function p:get_profession_level() return N(_cmd("PLAYER_PROFESSION_LEVEL")) end
    function p:in_combat() return B(_cmd("PLAYER_COMBAT")) end
    function p:is_dead() return false end
    function p:is_frozen() return B(_cmd("PLAYER_FROZEN")) end
    function p:is_moving() return B(_cmd("PLAYER_MOVING")) end
    function p:is_spectator() return B(_cmd("PLAYER_SPECTATOR")) end
    function p:in_pvp_zone() return B(_cmd("PLAYER_PZ_ZONE")) end
    function p:in_wildlands() return B(_cmd("PLAYER_WILDLANDS")) end
    function p:has_target() return B(_cmd("HAS_TARGET")) end
    function p:get_target_name() return _cmd("TARGET_NAME") end
    function p:get_target_hp() return N(_cmd("TARGET_HP")) end
    function p:get_target_distance() return N(_cmd("TARGET_DISTANCE")) end
    function p:get_target_info() return _cmd("TARGET_INFO_V2") end
    function p:is_target_boss()
        local r = _cmd("TARGET_FULL")
        return r:match("is_boss=1") ~= nil
    end
    function p:is_target_elite()
        local r = _cmd("TARGET_FULL")
        return r:match("is_elite=1") ~= nil
    end
    function p:is_target_rare()
        local r = _cmd("TARGET_FULL")
        return r:match("is_rare=1") ~= nil
    end
    function p:get_buffs() return _cmd("PLAYER_BUFFS") end
    function p:has_buff(n)
        local r = _cmd("PLAYER_BUFFS")
        return r:find("name=" .. n) ~= nil
    end
    function p:get_stacks(n) return N(_cmd("BUFF_STACKS " .. n)) end
    function p:is_spell_ready(n) return _cmd("SPELL_READY " .. n) == "1" end
    function p:cast_spell(n) return _cmd("CAST_" .. n):find("OK") ~= nil end
    function p:cast_spell_ooc(n) return _cmd("CAST_" .. n):find("OK") ~= nil end
    function p:get_spell_cooldown(n) return N(_cmd("SPELL_CD " .. n)) end
    function p:distance_to(pt)
        local pos = self:get_position()
        local dx = pos.x - (pt.x or 0)
        local dy = pos.y - (pt.y or 0)
        local dz = pos.z - (pt.z or 0)
        return math.sqrt(dx*dx + dy*dy + dz*dz)
    end
    return p
end

function om.get_target()
    if not B(_cmd("HAS_TARGET")) then return nil end
    local t = {}
    function t:is_valid() return B(_cmd("HAS_TARGET")) end
    function t:get_name() return _cmd("TARGET_NAME") end
    function t:get_hp() return N(_cmd("TARGET_HP")) end
    function t:get_distance() return N(_cmd("TARGET_DISTANCE")) end
    function t:get_info() return _cmd("TARGET_INFO_V2") end
    function t:get_full() return _cmd("TARGET_FULL") end
    return t
end

function om.get_nearby_enemies(range)
    return _parse_lines(_cmd("SCAN_ENEMIES"))
end

function om.get_nearby_all()
    return _parse_lines(_cmd("SCAN_NEARBY"))
end

function om.get_party_members()
    return _parse_lines(_cmd("PARTY_SCAN"))
end

function om.get_entity_by_uid(uid)
    return _cmd("ENTITY_BY_UID " .. uid)
end

function om.get_nearby_count()
    return tonumber(_cmd("NEARBY_COUNT")) or 0
end

function om.get_party_count()
    return tonumber(_cmd("PARTY_COUNT")) or 0
end

return om
