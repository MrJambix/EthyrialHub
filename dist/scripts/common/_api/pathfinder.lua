-- ═══════════════════════════════════════════════════════════════
--  core.pathfinder — A* Grid Pathfinding for Ethyrial
--
--  Scans the game world via WALKABILITY_GRID, builds a tile grid,
--  overlays blocking entities, and runs A* to find walkable paths.
--  Supports long-distance navigation via progressive chunk scanning.
--
--  Usage:
--    core.pathfinder.navigate_to(target_x, target_z, { on_step = print })
-- ═══════════════════════════════════════════════════════════════

local pathfinder = {}

-- ─── Configuration defaults ─────────────────────────────────
pathfinder.SCAN_RADIUS    = 40
pathfinder.FLOOR          = 0
pathfinder.MOVE_TOLERANCE = 1.8
pathfinder.STEP_DELAY     = 0.25
pathfinder.STUCK_TIMEOUT  = 6.0
pathfinder.STUCK_DIST     = 0.5
pathfinder.MAX_ITERATIONS = 50000
pathfinder.DIAG_COST      = 1.414

local DIRS = {
    { 0, -1, 1.0},   { 1,  0, 1.0},   { 0,  1, 1.0},   {-1,  0, 1.0},
    { 1, -1, 1.414},  { 1,  1, 1.414},  {-1,  1, 1.414},  {-1, -1, 1.414},
}

-- ═══════════════════════════════════════════════════════════════
--  GRID SCANNING
-- ═══════════════════════════════════════════════════════════════

function pathfinder.parse_grid(raw, cx, cy, radius)
    local walkable = {}
    local blocked  = {}
    local meta = { cx = cx, cy = cy, radius = radius }
    if not raw or raw == "" then return walkable, blocked, meta end

    local hcx, hcy, hr = raw:match("center=(-?%d+),(-?%d+)|floor=%-?%d+|radius=(%d+)")
    if hcx then
        meta.cx = tonumber(hcx); meta.cy = tonumber(hcy); meta.radius = tonumber(hr)
    end

    for ry, bits in raw:gmatch("ROW|(-?%d+)|([01]+)") do
        local y = tonumber(ry)
        walkable[y] = walkable[y] or {}
        local x_start = meta.cx - meta.radius
        for i = 1, #bits do
            walkable[y][x_start + (i - 1)] = (bits:sub(i, i) == "1")
        end
    end

    for line in raw:gmatch("[^\n]+") do
        if line:sub(1, 6) == "BLOCK|" then
            local cls = line:match("class=([^|]+)") or ""
            local tx, ty = line:match("tile=(-?%d+),(-?%d+)")
            if tx and ty then
                tx, ty = tonumber(tx), tonumber(ty)
                if cls ~= "LocalPlayerEntity" then
                    blocked[tx .. "," .. ty] = true
                    if walkable[ty] then walkable[ty][tx] = false end
                end
            end
        end
    end
    return walkable, blocked, meta
end

function pathfinder.scan(cx, cy, floor, radius)
    floor  = floor  or pathfinder.FLOOR
    radius = radius or pathfinder.SCAN_RADIUS
    local raw
    if core and core.terrain and core.terrain.walkability then
        raw = core.terrain.walkability(cx, cy, floor, radius)
    elseif core and core.send_command then
        raw = core.send_command(string.format("WALKABILITY_GRID %d %d %d %d", cx, cy, floor, radius))
    end
    if not raw or raw:sub(1, 3) == "ERR" then return nil, nil, nil end
    return pathfinder.parse_grid(raw, cx, cy, radius)
end

function pathfinder.is_walkable(walkable, x, y)
    return walkable[y] and walkable[y][x] == true
end

-- ═══════════════════════════════════════════════════════════════
--  A* PATHFINDING
-- ═══════════════════════════════════════════════════════════════

local function heap_new() return { data = {}, n = 0 } end

local function heap_push(h, cost, item)
    h.n = h.n + 1
    h.data[h.n] = { cost = cost, item = item }
    local i = h.n
    while i > 1 do
        local p = math.floor(i / 2)
        if h.data[p].cost > h.data[i].cost then
            h.data[p], h.data[i] = h.data[i], h.data[p]; i = p
        else break end
    end
end

local function heap_pop(h)
    if h.n == 0 then return nil end
    local top = h.data[1]
    h.data[1] = h.data[h.n]; h.data[h.n] = nil; h.n = h.n - 1
    local i = 1
    while true do
        local l, r = i * 2, i * 2 + 1
        local smallest = i
        if l <= h.n and h.data[l].cost < h.data[smallest].cost then smallest = l end
        if r <= h.n and h.data[r].cost < h.data[smallest].cost then smallest = r end
        if smallest == i then break end
        h.data[i], h.data[smallest] = h.data[smallest], h.data[i]; i = smallest
    end
    return top.cost, top.item
end

local function heuristic(x1, y1, x2, y2)
    local dx = math.abs(x2 - x1)
    local dy = math.abs(y2 - y1)
    return math.max(dx, dy) + (1.414 - 1.0) * math.min(dx, dy)
end

function pathfinder.find_path(walkable, sx, sy, gx, gy)
    if not pathfinder.is_walkable(walkable, sx, sy) then
        local found = false
        for r = 1, 3 do
            for _, d in ipairs(DIRS) do
                local nx, ny = sx + d[1] * r, sy + d[2] * r
                if pathfinder.is_walkable(walkable, nx, ny) then
                    sx, sy = nx, ny; found = true; break
                end
            end
            if found then break end
        end
        if not found then return nil, "start_blocked" end
    end
    if not pathfinder.is_walkable(walkable, gx, gy) then
        local found = false
        for r = 1, 3 do
            for _, d in ipairs(DIRS) do
                local nx, ny = gx + d[1] * r, gy + d[2] * r
                if pathfinder.is_walkable(walkable, nx, ny) then
                    gx, gy = nx, ny; found = true; break
                end
            end
            if found then break end
        end
        if not found then return nil, "goal_blocked" end
    end

    local open = heap_new()
    local g_cost = {}
    local came_from = {}
    local closed = {}
    local sk = sx .. "," .. sy
    g_cost[sk] = 0
    heap_push(open, heuristic(sx, sy, gx, gy), sk)

    local iters = 0
    while open.n > 0 do
        iters = iters + 1
        if iters > pathfinder.MAX_ITERATIONS then return nil, "max_iterations" end
        local _, current = heap_pop(open)
        if closed[current] then goto continue end
        closed[current] = true
        local cx, cy = current:match("(-?%d+),(-?%d+)")
        cx, cy = tonumber(cx), tonumber(cy)
        if cx == gx and cy == gy then
            local path = {}
            local key = current
            while key do
                local px, py = key:match("(-?%d+),(-?%d+)")
                table.insert(path, 1, { x = tonumber(px), y = tonumber(py) })
                key = came_from[key]
            end
            return path
        end
        local cur_g = g_cost[current]
        for _, d in ipairs(DIRS) do
            local nx, ny = cx + d[1], cy + d[2]
            local nk = nx .. "," .. ny
            if not closed[nk] and pathfinder.is_walkable(walkable, nx, ny) then
                local passable = true
                if d[1] ~= 0 and d[2] ~= 0 then
                    if not pathfinder.is_walkable(walkable, cx + d[1], cy) or
                       not pathfinder.is_walkable(walkable, cx, cy + d[2]) then
                        passable = false
                    end
                end
                if passable then
                    local new_g = cur_g + d[3]
                    if not g_cost[nk] or new_g < g_cost[nk] then
                        g_cost[nk] = new_g
                        came_from[nk] = current
                        heap_push(open, new_g + heuristic(nx, ny, gx, gy), nk)
                    end
                end
            end
        end
        ::continue::
    end
    return nil, "no_path"
end

-- ═══════════════════════════════════════════════════════════════
--  PATH SIMPLIFICATION
-- ═══════════════════════════════════════════════════════════════

local function line_clear(walkable, x0, y0, x1, y1)
    local dx = math.abs(x1 - x0)
    local dy = math.abs(y1 - y0)
    local sx = x0 < x1 and 1 or -1
    local sy = y0 < y1 and 1 or -1
    local err = dx - dy
    local x, y = x0, y0
    while true do
        if not pathfinder.is_walkable(walkable, x, y) then return false end
        if x == x1 and y == y1 then return true end
        local e2 = 2 * err
        if e2 > -dy then err = err - dy; x = x + sx end
        if e2 <  dx then err = err + dx; y = y + sy end
    end
end

function pathfinder.simplify_path(walkable, path)
    if not path or #path <= 2 then return path end
    local simplified = { path[1] }
    local i = 1
    while i < #path do
        local farthest = i + 1
        for j = #path, i + 2, -1 do
            if line_clear(walkable, path[i].x, path[i].y, path[j].x, path[j].y) then
                farthest = j; break
            end
        end
        simplified[#simplified + 1] = path[farthest]
        i = farthest
    end
    return simplified
end

-- ═══════════════════════════════════════════════════════════════
--  PLAYER POSITION HELPERS
-- ═══════════════════════════════════════════════════════════════

function pathfinder.get_player_tile()
    local raw
    if core and core.player and core.player.pos then
        raw = core.player.pos()
    end
    if not raw or raw == "" then return nil, nil, nil end
    local wx, wy, wz = raw:match("([%d%.%-]+),([%d%.%-]+),([%d%.%-]+)")
    if not wx then return nil, nil, nil end
    return math.floor(tonumber(wx)), math.floor(tonumber(wy)), tonumber(wz)
end

local function tile_dist(x1, y1, x2, y2)
    local dx = x2 - x1; local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

-- ═══════════════════════════════════════════════════════════════
--  PATH WALKING
-- ═══════════════════════════════════════════════════════════════

function pathfinder.walk_path(path, opts)
    opts = opts or {}
    local tol         = opts.tolerance   or pathfinder.MOVE_TOLERANCE
    local delay       = opts.step_delay  or pathfinder.STEP_DELAY
    local stuck_time  = opts.stuck_time  or pathfinder.STUCK_TIMEOUT
    local on_step     = opts.on_step
    local on_stuck    = opts.on_stuck
    local should_stop = opts.should_stop
    if not path or #path < 2 then return true end

    local _, _, player_z = pathfinder.get_player_tile()
    player_z = player_z or 0

    for i = 2, #path do
        local wp = path[i]
        if on_step then on_step(i, wp.x, wp.y, #path) end
        core.movement.move_to(wp.x + 0.5, wp.y + 0.5, player_z)

        local last_px, last_py = 0, 0
        local stuck_timer = 0
        while true do
            if should_stop and should_stop() then return false, "aborted" end
            _ethy_sleep(delay)
            local px, py, pz = pathfinder.get_player_tile()
            if not px then return false, "no_position" end
            if pz then player_z = pz end
            if tile_dist(px, py, wp.x, wp.y) <= tol then break end
            local moved = tile_dist(px, py, last_px, last_py)
            if moved < pathfinder.STUCK_DIST then
                stuck_timer = stuck_timer + delay
                if stuck_timer >= stuck_time then
                    if on_stuck and on_stuck(px, py) then
                        core.movement.move_to(wp.x + 0.5, wp.y + 0.5, player_z)
                        stuck_timer = 0
                    else return false, "stuck" end
                end
            else stuck_timer = 0 end
            last_px, last_py = px, py
        end
    end
    core.movement.stop()
    return true
end

-- ═══════════════════════════════════════════════════════════════
--  HIGH-LEVEL NAVIGATION
-- ═══════════════════════════════════════════════════════════════

function pathfinder.navigate_to(goal_x, goal_y, opts)
    opts = opts or {}
    local floor       = opts.floor       or pathfinder.FLOOR
    local scan_radius = opts.scan_radius or pathfinder.SCAN_RADIUS
    local on_scan     = opts.on_scan
    local max_chunks  = opts.max_chunks  or 20

    for chunk = 1, max_chunks do
        local px, py = pathfinder.get_player_tile()
        if not px then return false, "no_position" end
        local gdist = tile_dist(px, py, goal_x, goal_y)
        if gdist <= (opts.tolerance or pathfinder.MOVE_TOLERANCE) then return true end

        local scan_cx, scan_cy
        if gdist <= scan_radius then
            scan_cx = math.floor((px + goal_x) / 2)
            scan_cy = math.floor((py + goal_y) / 2)
        else
            local ratio = scan_radius / gdist * 0.8
            scan_cx = math.floor(px + (goal_x - px) * ratio)
            scan_cy = math.floor(py + (goal_y - py) * ratio)
        end
        if on_scan then on_scan(scan_cx, scan_cy, chunk) end

        local walkable, _, meta = pathfinder.scan(scan_cx, scan_cy, floor, scan_radius)
        if not walkable then return false, "scan_failed" end

        local ax, ay
        if pathfinder.is_walkable(walkable, goal_x, goal_y) then
            ax, ay = goal_x, goal_y
        else
            local steps = math.floor(gdist)
            for s = steps, 1, -1 do
                local t = s / steps
                local tx = math.floor(px + (goal_x - px) * t)
                local ty = math.floor(py + (goal_y - py) * t)
                local min_x = meta.cx - meta.radius
                local max_x = meta.cx + meta.radius
                local min_y = meta.cy - meta.radius
                local max_y = meta.cy + meta.radius
                if tx >= min_x and tx <= max_x and ty >= min_y and ty <= max_y then
                    if pathfinder.is_walkable(walkable, tx, ty) then
                        ax, ay = tx, ty; break
                    end
                end
            end
            if not ax then return false, "no_intermediate_goal" end
        end

        local path, err = pathfinder.find_path(walkable, px, py, ax, ay)
        if not path then return false, "pathfind_" .. (err or "unknown") end
        path = pathfinder.simplify_path(walkable, path)

        local walk_opts = {
            tolerance   = opts.tolerance,
            step_delay  = opts.step_delay,
            stuck_time  = opts.stuck_time,
            on_step     = opts.on_step,
            should_stop = opts.should_stop,
            on_stuck    = function(sx, sy)
                if opts.on_stuck then return opts.on_stuck(sx, sy) end
                return false
            end,
        }
        local ok, walk_err = pathfinder.walk_path(path, walk_opts)
        if not ok then
            if walk_err == "aborted" then return false, "aborted" end
        end

        local fx, fy = pathfinder.get_player_tile()
        if fx and tile_dist(fx, fy, goal_x, goal_y) <= (opts.tolerance or pathfinder.MOVE_TOLERANCE) then
            return true
        end
    end
    return false, "max_chunks_exceeded"
end

return pathfinder
