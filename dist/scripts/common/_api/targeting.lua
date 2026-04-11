-- ═══════════════════════════════════════════════════════════════
--  core.targeting — Targeting API
-- ═══════════════════════════════════════════════════════════════

local tgt = {}

function tgt.target_nearest()
    return _cmd("TARGET_NEAREST")
end

function tgt.target_nearest_filtered(filter)
    return _cmd("TARGET_NEAREST_FILTERED " .. filter)
end

function tgt.target_entity(uid)
    return _cmd("TARGET_ENTITY " .. uid)
end

function tgt.target_party(idx)
    return _cmd("TARGET_PARTY " .. idx)
end

function tgt.target_friendly(uid)
    return _cmd("TARGET_FRIENDLY " .. uid)
end

function tgt.has_target()
    return B(_cmd("HAS_TARGET"))
end

function tgt.target_hp()
    return N(_cmd("TARGET_HP"))
end

function tgt.target_hp_v2()
    return _cmd("TARGET_HP_V2")
end

function tgt.target_name()
    return _cmd("TARGET_NAME")
end

function tgt.target_distance()
    return N(_cmd("TARGET_DISTANCE"))
end

function tgt.target_info()
    return _cmd("TARGET_INFO")
end

function tgt.target_info_v2()
    return _cmd("TARGET_INFO_V2")
end

function tgt.target_full()
    return _cmd("TARGET_FULL")
end

function tgt.friendly_target()
    return _cmd("FRIENDLY_TARGET")
end

function tgt.legal_targets()
    return _cmd("LEGAL_TARGETS")
end

function tgt.scan_enemies()
    return _cmd("SCAN_ENEMIES")
end

function tgt.target_by_ptr(ptr)
    return _cmd("TARGET_PTR_" .. _ptr_hex(ptr))
end

function tgt.target_casting_dump()
    return _cmd("TARGET_CASTING_DUMP")
end

function tgt.is_target_boss()
    local r = _cmd("TARGET_FULL")
    if not r or r == "" then return false end
    return r:find("is_boss=1") ~= nil
end

function tgt.is_target_elite()
    local r = _cmd("TARGET_FULL")
    if not r or r == "" then return false end
    return r:find("is_elite=1") ~= nil
end

function tgt.is_target_dead()
    local has = _cmd("HAS_TARGET")
    if has ~= "1" then return true end
    return tonumber(_cmd("TARGET_HP")) <= 0
end

function tgt.face_target(uid)
    if uid then return _cmd("LOOK_AT " .. uid) end
    local r = _cmd("TARGET_FULL")
    local u = r and r:match("uid=(%d+)")
    if u and u ~= "0" then return _cmd("LOOK_AT " .. u) end
    return "NO_TARGET"
end

function tgt.target_casting()
    local r = _cmd("TARGET_CASTING")
    if not r or r:sub(1, 7) ~= "CASTING" then return nil end
    local t = { is_casting = true }
    t.spell    = r:match("spell=([^|]+)") or ""
    t.duration = tonumber(r:match("duration=([^|]+)")) or 0
    t.elapsed  = tonumber(r:match("elapsed=([^|]+)")) or 0
    t.type     = tonumber(r:match("type=([^|]+)")) or 0
    return t
end

-- ── Parsed helpers ──

function tgt.get_enemies()
    return _parse_lines(_cmd("SCAN_ENEMIES"))
end

function tgt.get_target()
    return _parse_single(_cmd("TARGET_FULL"))
end

function tgt.get_target_v2()
    return _parse_single(_cmd("TARGET_INFO_V2"))
end

function tgt.get_friendly()
    return _parse_single(_cmd("FRIENDLY_TARGET"))
end

return tgt
