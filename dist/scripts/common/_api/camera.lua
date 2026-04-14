-- ═══════════════════════════════════════════════════════════════
--  core.camera — Camera API
-- ═══════════════════════════════════════════════════════════════

local cam = {}

function cam.get()
    return _cmd("CAMERA")
end

function cam.distance()
    return N(_cmd("CAMERA_DISTANCE"))
end

function cam.angle()
    return N(_cmd("CAMERA_ANGLE"))
end

function cam.pitch()
    return N(_cmd("CAMERA_PITCH"))
end

-- ── Parsed helpers ──

function cam.get_parsed()
    local r = _cmd("CAMERA")
    if not r or r == "" then return nil end
    local vals = {}
    for v in r:gmatch("[%d%.%-]+") do
        vals[#vals + 1] = tonumber(v) or 0
    end
    return {
        x = vals[1] or 0, y = vals[2] or 0, z = vals[3] or 0,
        distance = vals[4] or 0, angle = vals[5] or 0, pitch = vals[6] or 0,
    }
end

-- ── Setters ──

function cam.set_distance(d)    return _cmd("SET_CAMERA_DISTANCE " .. tostring(d))  end
function cam.set_angle(a)       return _cmd("SET_CAMERA_ANGLE " .. tostring(a))      end
function cam.set_pitch(p)       return _cmd("SET_CAMERA_PITCH " .. tostring(p))      end
function cam.set_max_distance(d) return _cmd("SET_CAMERA_MAX_DIST " .. tostring(d))  end
function cam.set_min_distance(d) return _cmd("SET_CAMERA_MIN_DIST " .. tostring(d))  end

return cam
