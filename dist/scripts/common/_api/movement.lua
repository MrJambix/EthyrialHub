-- ═══════════════════════════════════════════════════════════════
--  core.movement — Movement API
-- ═══════════════════════════════════════════════════════════════

local move = {}

function move.move_to(x, y, z)
    if z then
        return _cmd(string.format("MOVE_TO %.2f %.2f %.2f", x, y, z))
    else
        return _cmd(string.format("MOVE_TO %.2f %.2f", x, y))
    end
end

function move.move_to_ptr(hex, range)
    return _cmd(string.format("MOVE_TO_PTR %s %.1f", hex, range or 2.0))
end

function move.move_to_target()
    return _cmd("MOVE_TO_TARGET")
end

function move.stop()
    return _cmd("STOP_MOVEMENT")
end

function move.follow_entity(uid)
    return _cmd("FOLLOW_ENTITY " .. uid)
end

function move.autorun_on()
    return _cmd("AUTORUN_ON")
end

function move.autorun_off()
    return _cmd("AUTORUN_OFF")
end

return move
