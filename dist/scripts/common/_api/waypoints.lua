--[[
╔══════════════════════════════════════════════════════════════╗
║         Waypoints — Path Recording & Replay System           ║
║                                                              ║
║  Record player movement as waypoints, replay paths,          ║
║  detect stuck conditions, and loop patrol routes.            ║
║                                                              ║
║  Usage:                                                      ║
║    local wp = require("common/_api/waypoints")               ║
║    wp.record_start()    -- start recording movement          ║
║    wp.record_stop()     -- stop and save waypoints           ║
║    wp.follow(points, {loop=true})  -- follow a path          ║
╚══════════════════════════════════════════════════════════════╝
]]

local waypoints = {}

-- ══════════════════════════════════════════════════════════════
-- Internal state
-- ══════════════════════════════════════════════════════════════

local _recording = false
local _recorded = {}        -- list of {x, y, z}
local _record_interval = 1.5  -- seconds between waypoint captures
local _last_record_time = 0
local _min_distance = 2.0   -- minimum distance to record a new point

-- Follow state
local _following = false
local _follow_path = {}
local _follow_idx = 1
local _follow_opts = {}
local _follow_callback = nil

-- Stuck detection
local _stuck_pos = nil
local _stuck_time = 0
local _stuck_threshold = 3.0   -- seconds without movement = stuck
local _stuck_distance = 1.0    -- minimum distance to count as "moved"
local _unstick_attempts = 0

-- ══════════════════════════════════════════════════════════════
-- Helpers
-- ══════════════════════════════════════════════════════════════

local function dist3d(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    local dz = a.z - b.z
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

local function dist2d(a, b)
    local dx = a.x - b.x
    local dz = a.z - b.z
    return math.sqrt(dx*dx + dz*dz)
end

local function get_pos()
    if conn and conn.get_pos then
        local x, y, z = conn.get_pos()
        return {x = x or 0, y = y or 0, z = z or 0}
    end
    return {x = 0, y = 0, z = 0}
end

local function get_time()
    if core and core.time then return core.time() end
    return os.clock()
end

-- ══════════════════════════════════════════════════════════════
-- Recording
-- ══════════════════════════════════════════════════════════════

--- Start recording waypoints from player movement.
function waypoints.record_start(interval, min_dist)
    _recording = true
    _recorded = {}
    _record_interval = interval or 1.5
    _min_distance = min_dist or 2.0
    _last_record_time = 0
end

--- Stop recording and return the recorded path.
function waypoints.record_stop()
    _recording = false
    return _recorded
end

--- Check if currently recording.
function waypoints.is_recording()
    return _recording
end

--- Get the recorded waypoints.
function waypoints.get_recorded()
    return _recorded
end

--- Manually add a waypoint.
function waypoints.add(x, y, z)
    _recorded[#_recorded + 1] = {x = x, y = y, z = z}
end

-- ══════════════════════════════════════════════════════════════
-- Path Following
-- ══════════════════════════════════════════════════════════════

--- Follow a list of waypoints.
--- @param path table  List of {x, y, z} points
--- @param opts table  {loop=false, arrival_dist=3.0, reverse=false, on_complete=fn, on_stuck=fn}
function waypoints.follow(path, opts)
    opts = opts or {}
    _follow_path = path
    _follow_idx = opts.reverse and #path or 1
    _follow_opts = {
        loop = opts.loop or false,
        reverse = opts.reverse or false,
        arrival_dist = opts.arrival_dist or 3.0,
        on_complete = opts.on_complete,
        on_stuck = opts.on_stuck,
    }
    _following = true
    _stuck_pos = nil
    _stuck_time = 0
    _unstick_attempts = 0
end

--- Stop following the current path.
function waypoints.stop()
    _following = false
    _follow_path = {}
    if conn and conn.send_command then
        conn.send_command("STOP_MOVEMENT")
    end
end

--- Check if currently following a path.
function waypoints.is_following()
    return _following
end

--- Get current waypoint index and total count.
function waypoints.progress()
    return _follow_idx, #_follow_path
end

--- Reverse the follow direction mid-path.
function waypoints.reverse()
    _follow_opts.reverse = not _follow_opts.reverse
end

-- ══════════════════════════════════════════════════════════════
-- Stuck Detection
-- ══════════════════════════════════════════════════════════════

--- Configure stuck detection.
function waypoints.set_stuck_config(threshold_sec, distance)
    _stuck_threshold = threshold_sec or 3.0
    _stuck_distance = distance or 1.0
end

--- Attempt to unstick: small random movement.
local function try_unstick()
    _unstick_attempts = _unstick_attempts + 1
    if conn and conn.send_command then
        -- Try jumping or small random move
        local pos = get_pos()
        local angle = math.random() * math.pi * 2
        local dist = 3 + math.random() * 3
        local nx = pos.x + math.cos(angle) * dist
        local nz = pos.z + math.sin(angle) * dist
        conn.send_command(string.format("MOVE_TO %.2f %.2f %.2f", nx, pos.y, nz))
    end
end

-- ══════════════════════════════════════════════════════════════
-- Tick — call every frame
-- ══════════════════════════════════════════════════════════════

function waypoints.tick()
    local now = get_time()
    local pos = get_pos()

    -- Recording logic
    if _recording then
        if now - _last_record_time >= _record_interval then
            local should_add = true
            if #_recorded > 0 then
                local last = _recorded[#_recorded]
                if dist3d(pos, last) < _min_distance then
                    should_add = false
                end
            end
            if should_add then
                _recorded[#_recorded + 1] = {x = pos.x, y = pos.y, z = pos.z}
                _last_record_time = now
            end
        end
    end

    -- Following logic
    if _following and #_follow_path > 0 then
        local target = _follow_path[_follow_idx]
        if not target then
            _following = false
            return
        end

        local d = dist2d(pos, target)

        -- Check if arrived at current waypoint
        if d <= _follow_opts.arrival_dist then
            -- Advance to next waypoint
            if _follow_opts.reverse then
                _follow_idx = _follow_idx - 1
                if _follow_idx < 1 then
                    if _follow_opts.loop then
                        _follow_idx = #_follow_path
                    else
                        _following = false
                        if _follow_opts.on_complete then
                            _follow_opts.on_complete()
                        end
                        return
                    end
                end
            else
                _follow_idx = _follow_idx + 1
                if _follow_idx > #_follow_path then
                    if _follow_opts.loop then
                        _follow_idx = 1
                    else
                        _following = false
                        if _follow_opts.on_complete then
                            _follow_opts.on_complete()
                        end
                        return
                    end
                end
            end

            -- Issue move to next waypoint
            target = _follow_path[_follow_idx]
            if target and conn and conn.send_command then
                conn.send_command(string.format("MOVE_TO %.2f %.2f %.2f", target.x, target.y, target.z))
            end

            _stuck_pos = nil
            _stuck_time = 0
        else
            -- Still moving to current waypoint — check for stuck
            if _stuck_pos then
                if dist2d(pos, _stuck_pos) < _stuck_distance then
                    if now - _stuck_time >= _stuck_threshold then
                        -- We're stuck
                        if _follow_opts.on_stuck then
                            _follow_opts.on_stuck(_unstick_attempts)
                        else
                            try_unstick()
                        end
                        _stuck_time = now
                    end
                else
                    _stuck_pos = {x = pos.x, y = pos.y, z = pos.z}
                    _stuck_time = now
                    _unstick_attempts = 0
                end
            else
                _stuck_pos = {x = pos.x, y = pos.y, z = pos.z}
                _stuck_time = now
            end

            -- Re-issue movement command periodically
            if conn and conn.send_command then
                conn.send_command(string.format("MOVE_TO %.2f %.2f %.2f", target.x, target.y, target.z))
            end
        end
    end
end

--- Create a circular patrol path around a center point.
function waypoints.circle(cx, cy, cz, radius, point_count)
    point_count = point_count or 8
    local path = {}
    for i = 0, point_count - 1 do
        local angle = (i / point_count) * math.pi * 2
        path[#path + 1] = {
            x = cx + math.cos(angle) * radius,
            y = cy,
            z = cz + math.sin(angle) * radius,
        }
    end
    return path
end

--- Create a back-and-forth path between two points with intermediate steps.
function waypoints.line(from, to, steps)
    steps = steps or 1
    local path = {}
    for i = 0, steps do
        local t = i / steps
        path[#path + 1] = {
            x = from.x + (to.x - from.x) * t,
            y = from.y + (to.y - from.y) * t,
            z = from.z + (to.z - from.z) * t,
        }
    end
    return path
end

--- Get debug info.
function waypoints.debug()
    return {
        recording = _recording,
        recorded_count = #_recorded,
        following = _following,
        follow_idx = _follow_idx,
        follow_total = #_follow_path,
        stuck_attempts = _unstick_attempts,
    }
end

return waypoints
