-- ═══════════════════════════════════════════════════════════════
--  core.nav_grid — Sampled Walkability Grid (Phase 1)
--
--  Builds a grid of terrain samples around a center point.
--  Each cell stores: position, ground height, normal, slope,
--  walkable flag, area type, cost, cliff/edge flag.
--
--  Neighbor analysis rejects cells with steep slopes, high step
--  differences, or cliff drops.
-- ═══════════════════════════════════════════════════════════════

local terrain = require("common/_api/terrain")

local nav = {}

-- ── Configuration defaults ──
nav.config = {
    step           = 2.0,     -- grid spacing in game units
    max_slope      = 45.0,    -- max walkable slope in degrees
    max_step_up    = 1.5,     -- max height diff to adjacent cell (up)
    max_step_down  = 3.0,     -- max height diff to adjacent cell (down/cliff)
    ray_dist       = 50.0,    -- max downward ray distance
    ray_offset     = 2.0,     -- cast from this far above center z
    layer_mask     = -17,     -- physics layer mask: all except Water (layer 4)
                              -- -1 = all layers, ~(1<<4) = -17 excludes water
}

-- ── Area types ──
nav.AREA_UNKNOWN   = 0
nav.AREA_ROAD      = 1
nav.AREA_GRASS     = 2
nav.AREA_LOW_RISK  = 3
nav.AREA_HIGH_RISK = 4
nav.AREA_BLOCKED   = 5
nav.AREA_OFFMESH   = 6

-- ── Area costs ──
nav.COST = {
    [0] = 1.0,   -- unknown
    [1] = 0.5,   -- road (cheap)
    [2] = 1.0,   -- grass (normal)
    [3] = 2.0,   -- low risk
    [4] = 5.0,   -- high risk
    [5] = math.huge,  -- blocked
    [6] = 1.0,   -- off-mesh
}

-- ══════════════════════════════════════════════════════════════
--  Grid data structure
-- ══════════════════════════════════════════════════════════════
--
--  grid = {
--    cx, cy, cz   = center game pos
--    radius        = scan radius
--    step          = cell spacing
--    cols, rows    = grid dimensions
--    cells         = 2D array [iy][ix] of cell or nil
--    config        = config snapshot
--  }
--
--  cell = {
--    ix, iy        = grid indices
--    gx, gy, gz    = ground position (game coords)
--    nx, ny, nz    = surface normal (game coords)
--    slope         = slope angle in degrees
--    walkable      = boolean
--    area          = area type (nav.AREA_*)
--    cost          = movement cost
--    cliff         = boolean (edge/cliff detected)
--    region        = region id (0 = unassigned)
--    blocked_reason = string or nil
--  }

--- Sample the terrain and build a walkability grid.
--- @param cx number center X (game)
--- @param cy number center Y (game)
--- @param cz number center Z altitude (game)
--- @param radius number scan radius in game units
--- @param cfg table|nil override config fields
--- @return table grid data structure
function nav.build(cx, cy, cz, radius, cfg)
    local c = {}
    for k, v in pairs(nav.config) do c[k] = v end
    if cfg then for k, v in pairs(cfg) do c[k] = v end end

    local step = c.step
    local cols = math.floor(radius * 2 / step) + 1
    local rows = cols

    local grid = {
        cx = cx, cy = cy, cz = cz,
        radius = radius,
        step = step,
        cols = cols, rows = rows,
        cells = {},
        config = c,
    }

    -- ── Phase 1a: Sample terrain via RAYCAST_BATCH ──
    local raw = terrain.raycast_batch(cx, cy, cz, radius, step, c.ray_dist, c.layer_mask)
    if not raw or raw:find("^ERR") then
        print("[NAV] RAYCAST_BATCH failed: " .. tostring(raw))
        return grid
    end

    local batch = terrain.parse_batch(raw)
    if not batch or not batch.grid then
        print("[NAV] Failed to parse batch response")
        return grid
    end

    -- Real player altitude in Unity coords (from GRID header).
    -- This is authoritative — the game `cz` passed in by callers is
    -- a floor number, NOT a Unity Y altitude. Use this for every
    -- height comparison below.
    grid.player_uy = (batch.header and batch.header.uy) or cz

    -- ── Phase 1b: Populate cells from batch data ──
    for iy = 0, rows - 1 do
        grid.cells[iy] = {}
        local batch_row = batch.grid[iy]
        for ix = 0, cols - 1 do
            local gx = cx - radius + ix * step
            local gy = cy - radius + iy * step

            local cell = nil
            if batch_row then
                local sample = batch_row[ix + 1]  -- Lua 1-indexed; false=miss, table=hit
                if sample and sample ~= false and sample.height then
                    cell = {
                        ix = ix, iy = iy,
                        gx = gx, gy = gy, gz = sample.height,
                        nx = 0, ny = 0, nz = 1,  -- batch doesn't give full normal
                        slope = sample.slope or 0,
                        walkable = true,
                        area = nav.AREA_UNKNOWN,
                        cost = 1.0,
                        cliff = false,
                        region = 0,
                        blocked_reason = nil,
                    }
                end
            end
            grid.cells[iy][ix] = cell
        end
    end

    -- ── Phase 1c: Slope rejection ──
    for iy = 0, rows - 1 do
        for ix = 0, cols - 1 do
            local cell = grid.cells[iy] and grid.cells[iy][ix]
            if cell and cell.slope > c.max_slope then
                cell.walkable = false
                cell.blocked_reason = "slope"
            end
        end
    end

    -- ── Phase 1d: Neighbor analysis — step height and cliff detection ──
    local dirs = { {0,1}, {1,0}, {0,-1}, {-1,0}, {1,1}, {-1,1}, {1,-1}, {-1,-1} }
    for iy = 0, rows - 1 do
        for ix = 0, cols - 1 do
            local cell = grid.cells[iy] and grid.cells[iy][ix]
            if cell and cell.walkable then
                for _, d in ipairs(dirs) do
                    local nx, ny = ix + d[1], iy + d[2]
                    if nx >= 0 and nx < cols and ny >= 0 and ny < rows then
                        local neighbor = grid.cells[ny] and grid.cells[ny][nx]
                        if neighbor then
                            local dz = neighbor.gz - cell.gz
                            -- Step up too high
                            if dz > c.max_step_up then
                                -- Don't mark cell unwalkable, just note cliff
                                cell.cliff = true
                            end
                            -- Drop too steep (cliff)
                            if -dz > c.max_step_down then
                                cell.cliff = true
                            end
                        else
                            -- Missing neighbor = edge of world / void
                            cell.cliff = true
                        end
                    end
                end
            end
        end
    end

    -- ── Phase 1e: Floor-clamp ──
    -- Cast rays can slip through holes in the current floor and hit
    -- geometry on lower floors. Anything significantly below the
    -- player's real altitude is not part of this floor — drop it so
    -- the mesh stops drawing "under" the terrain at Z=1.
    local FLOOR_DROP_REJECT = 1.25  -- cells more than this below player = wrong floor
    local puy = grid.player_uy
    for iy = 0, rows - 1 do
        for ix = 0, cols - 1 do
            local cell = grid.cells[iy] and grid.cells[iy][ix]
            if cell and (puy - cell.gz) > FLOOR_DROP_REJECT then
                -- Belongs to a lower floor — remove from the current-floor grid.
                grid.cells[iy][ix] = nil
            end
        end
    end

    -- ── Phase 1f: Water detection (flat-height cluster heuristic) ──
    -- Water surfaces are flat planes sitting noticeably BELOW the
    -- player's real Unity altitude. Compare against `grid.player_uy`
    -- (not `cz`, which is a floor integer) so indoor flooring doesn't
    -- false-positive and so real water below a shoreline gets caught.
    local WATER_MIN_DROP    = 0.35  -- cluster must be ≥0.35u below player
    local WATER_MIN_CLUSTER = 8     -- reject small flat spots (rugs, slabs)

    local flat_cells = {}
    for iy = 0, rows - 1 do
        for ix = 0, cols - 1 do
            local cell = grid.cells[iy] and grid.cells[iy][ix]
            if cell and cell.walkable and cell.slope < 2 then
                flat_cells[#flat_cells + 1] = cell
            end
        end
    end

    -- Group by height (within 0.15 tolerance)
    local height_groups = {}
    for _, cell in ipairs(flat_cells) do
        local added = false
        for _, grp in ipairs(height_groups) do
            if math.abs(cell.gz - grp.h) < 0.15 then
                grp.cells[#grp.cells + 1] = cell
                added = true
                break
            end
        end
        if not added then
            height_groups[#height_groups + 1] = { h = cell.gz, cells = { cell } }
        end
    end

    local water_count = 0
    for _, grp in ipairs(height_groups) do
        -- Water: large flat cluster meaningfully below player altitude.
        if #grp.cells >= WATER_MIN_CLUSTER and (puy - grp.h) >= WATER_MIN_DROP then
            for _, cell in ipairs(grp.cells) do
                cell.walkable = false
                cell.blocked_reason = "water"
                cell.area = nav.AREA_BLOCKED
                water_count = water_count + 1
            end
        end
    end

    -- ── Phase 1f: Mark cells without ground as unwalkable ──
    local stats = { total = 0, walkable = 0, blocked = 0, cliff = 0, missing = 0, water = water_count }
    for iy = 0, rows - 1 do
        for ix = 0, cols - 1 do
            stats.total = stats.total + 1
            local cell = grid.cells[iy] and grid.cells[iy][ix]
            if not cell then
                stats.missing = stats.missing + 1
            elseif not cell.walkable then
                stats.blocked = stats.blocked + 1
            else
                stats.walkable = stats.walkable + 1
                if cell.cliff then stats.cliff = stats.cliff + 1 end
            end
        end
    end
    grid.stats = stats

    return grid
end

--- Get a cell by grid indices.
--- @return table|nil cell
function nav.get_cell(grid, ix, iy)
    if not grid.cells[iy] then return nil end
    return grid.cells[iy][ix]
end

--- Get the cell closest to a game-space position.
--- @return table|nil cell, number ix, number iy
function nav.get_cell_at(grid, gx, gy)
    local ix = math.floor((gx - grid.cx + grid.radius) / grid.step + 0.5)
    local iy = math.floor((gy - grid.cy + grid.radius) / grid.step + 0.5)
    if ix < 0 or ix >= grid.cols or iy < 0 or iy >= grid.rows then return nil end
    return nav.get_cell(grid, ix, iy), ix, iy
end

--- Check if a cell is walkable and not a cliff edge.
function nav.is_safe(cell)
    return cell ~= nil and cell.walkable and not cell.cliff
end

--- Iterate all cells (yields cell, ix, iy).
function nav.iter_cells(grid)
    local ix, iy = -1, 0
    return function()
        ix = ix + 1
        if ix >= grid.cols then ix = 0; iy = iy + 1 end
        if iy >= grid.rows then return nil end
        return nav.get_cell(grid, ix, iy), ix, iy
    end
end

--- Get walkable neighbors of a cell (for pathfinding).
--- Returns list of {cell, cost} pairs.
function nav.get_neighbors(grid, ix, iy)
    local result = {}
    local cell = nav.get_cell(grid, ix, iy)
    if not cell or not cell.walkable then return result end

    local dirs = {
        {0,1,1.0}, {1,0,1.0}, {0,-1,1.0}, {-1,0,1.0},         -- cardinal
        {1,1,1.414}, {-1,1,1.414}, {1,-1,1.414}, {-1,-1,1.414}, -- diagonal
    }
    local c = grid.config

    for _, d in ipairs(dirs) do
        local nx, ny = ix + d[1], iy + d[2]
        local neighbor = nav.get_cell(grid, nx, ny)
        if neighbor and neighbor.walkable then
            local step_ok = (neighbor.gz - cell.gz) <= c.max_step_up
                        and (cell.gz - neighbor.gz) <= c.max_step_down
            if step_ok then
                local move_cost = d[3] * (nav.COST[neighbor.area] or 1.0) * neighbor.cost
                result[#result + 1] = { cell = neighbor, ix = nx, iy = ny, cost = move_cost }
            end
        end
    end
    return result
end

--- Simple A* pathfinding on the grid.
--- @param grid table built grid
--- @param sx number start game X
--- @param sy number start game Y
--- @param gx number goal game X
--- @param gy number goal game Y
--- @return table|nil list of {gx, gy, gz} waypoints, or nil if no path
function nav.find_path(grid, sx, sy, gx, gy)
    local start_cell, six, siy = nav.get_cell_at(grid, sx, sy)
    local goal_cell, gix, giy = nav.get_cell_at(grid, gx, gy)

    if not start_cell or not start_cell.walkable then return nil, "start not walkable" end
    if not goal_cell or not goal_cell.walkable then return nil, "goal not walkable" end

    -- A* with binary heap would be faster but this works for grids up to ~200x200
    local function heuristic(ax, ay, bx, by)
        return math.sqrt((ax - bx)^2 + (ay - by)^2) * grid.step
    end

    local open = {}   -- {ix, iy, f}
    local g_score = {} -- [iy*cols+ix] = cost
    local came_from = {} -- [iy*cols+ix] = {ix, iy}
    local closed = {} -- [iy*cols+ix] = true

    local function key(ax, ay) return ay * grid.cols + ax end

    local sk = key(six, siy)
    g_score[sk] = 0
    open[#open + 1] = { ix = six, iy = siy, f = heuristic(six, siy, gix, giy) }

    local iterations = 0
    local max_iter = grid.cols * grid.rows * 2

    while #open > 0 and iterations < max_iter do
        iterations = iterations + 1

        -- Find lowest f in open (simple scan — fine for small grids)
        local best_i = 1
        for i = 2, #open do
            if open[i].f < open[best_i].f then best_i = i end
        end
        local current = open[best_i]
        table.remove(open, best_i)

        local ck = key(current.ix, current.iy)
        if closed[ck] then goto continue end
        closed[ck] = true

        -- Goal reached
        if current.ix == gix and current.iy == giy then
            -- Reconstruct path
            local path = {}
            local k = ck
            while k do
                local iy2 = math.floor(k / grid.cols)
                local ix2 = k - iy2 * grid.cols
                local c = nav.get_cell(grid, ix2, iy2)
                if c then
                    table.insert(path, 1, { gx = c.gx, gy = c.gy, gz = c.gz })
                end
                k = came_from[k]
            end
            return path
        end

        -- Expand neighbors
        local neighbors = nav.get_neighbors(grid, current.ix, current.iy)
        for _, n in ipairs(neighbors) do
            local nk = key(n.ix, n.iy)
            if not closed[nk] then
                local tentative = (g_score[ck] or 0) + n.cost
                if not g_score[nk] or tentative < g_score[nk] then
                    g_score[nk] = tentative
                    came_from[nk] = ck
                    local f = tentative + heuristic(n.ix, n.iy, gix, giy)
                    open[#open + 1] = { ix = n.ix, iy = n.iy, f = f }
                end
            end
        end

        ::continue::
    end

    return nil, "no path found (iterations=" .. iterations .. ")"
end

--- Smooth a path by removing redundant points using line-of-sight checks.
--- @param grid table built grid
--- @param path table list of {gx,gy,gz} waypoints
--- @return table smoothed path
function nav.smooth_path(grid, path)
    if not path or #path <= 2 then return path end

    local smoothed = { path[1] }
    local i = 1

    while i < #path do
        local farthest = i + 1
        -- Try to skip ahead as far as possible with LOS
        for j = #path, i + 2, -1 do
            if nav.has_los(grid, path[i].gx, path[i].gy, path[j].gx, path[j].gy) then
                farthest = j
                break
            end
        end
        smoothed[#smoothed + 1] = path[farthest]
        i = farthest
    end

    return smoothed
end

--- Check line-of-sight between two game positions on the grid.
--- Walks the grid in small steps and checks each cell is walkable.
function nav.has_los(grid, x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    local dist = math.sqrt(dx*dx + dy*dy)
    if dist < 0.01 then return true end

    local steps = math.ceil(dist / (grid.step * 0.5))
    for s = 0, steps do
        local t = s / steps
        local px = x1 + dx * t
        local py = y1 + dy * t
        local cell = nav.get_cell_at(grid, px, py)
        if not cell or not cell.walkable then return false end
    end
    return true
end

return nav