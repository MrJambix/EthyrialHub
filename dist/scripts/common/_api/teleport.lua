-- ═══════════════════════════════════════════════════════════════
--  core.teleport — Position manipulation API
--
--  Usage:
--    core.teleport.to(x, y, z)
--    core.teleport.lock(x, y, z)  -- hold position every frame
--    core.teleport.release()
-- ═══════════════════════════════════════════════════════════════

local M = {}

--- Teleport to position (full sync: stops movement, writes position,
--- snaps transform, updates tiles).
---@return table|string result  Parsed {ok, from, to, snap, ...} or raw error
function M.to(x, y, z)
    local raw = core.send_command(string.format("TELEPORT %.2f %.2f %.2f", x, y, z or 0))
    if not raw or raw:sub(1, 3) ~= "OK|" then return raw end
    local result = { ok = true, raw = raw }
    for kv in raw:gmatch("[^|]+") do
        local k, v = kv:match("^(.-)=(.+)$")
        if k then
            local num = tonumber(v)
            if num then result[k] = num else result[k] = v end
        end
    end
    return result
end

--- Snap to position (Entity.SnapToPosition only, lighter than full teleport).
function M.snap_to(x, y, z)
    return core.send_command(string.format("SNAP_TO %.2f,%.2f,%.2f", x, y, z or 0))
end

--- Freeze player at position (written every frame, suppresses server corrections).
--- Call release() to stop.
function M.hold(x, y, z)
    return core.send_command(string.format("TELEPORT_HOLD %.2f %.2f %.2f", x, y, z or 0))
end

--- Stop freezing position.
function M.release()
    return core.send_command("TELEPORT_RELEASE")
end

--- Check if position hold is active.
---@return string  "HOLDING|pos=x,y,z" or "RELEASED"
function M.status()
    return core.send_command("TELEPORT_STATUS")
end

--- Teleport and hold — teleports then freezes at the destination.
--- MUST call release() when done.
function M.lock(x, y, z)
    local result = M.to(x, y, z)
    M.hold(x, y, z or 0)
    return result
end

--- Get teleport debug info (position fields, pointers, waypoints).
function M.debug()
    return core.send_command("TELEPORT_DEBUG")
end

return M
