-- ═══════════════════════════════════════════════════════════════
--  core.terrain — Terrain / Walkability / Raycasting API
-- ═══════════════════════════════════════════════════════════════

local terrain = {}

function terrain.dump(cx, cy, floor, radius)
    floor = floor or 0; radius = radius or 5
    return _cmd(string.format("TERRAIN_DUMP %d %d %d %d", cx, cy, floor, radius))
end

function terrain.walkability(cx, cy, floor, radius)
    floor = floor or 0; radius = radius or 5
    return _cmd(string.format("WALKABILITY_GRID %d %d %d %d", cx, cy, floor, radius))
end

-- ═══════════════════════════════════════════════════════════════
-- Raycasting — Physics.Raycast wrappers
-- ═══════════════════════════════════════════════════════════════

--- Generic raycast: origin + direction.
--- @param ox number  origin X
--- @param oy number  origin Y
--- @param oz number  origin Z (altitude)
--- @param dx number  direction X
--- @param dy number  direction Y
--- @param dz number  direction Z
--- @param dist number  max distance
--- @param mask number|nil  layer mask (-1 = all)
--- @return table|nil  { px,py,pz, nx,ny,nz, dist } or nil on miss
function terrain.raycast(ox, oy, oz, dx, dy, dz, dist, mask)
    mask = mask or -1
    local raw = _cmd(string.format("RAYCAST %.4f %.4f %.4f %.4f %.4f %.4f %.4f %d",
                     ox, oy, oz, dx, dy, dz, dist, mask))
    if not raw or raw == "MISS" or raw:find("^ERR") then return nil end
    local t = {}
    for k, v in raw:gmatch("([%w_]+)=([^|]+)") do
        t[k] = tonumber(v) or v
    end
    return t
end

--- Raycast straight down from a position. Returns ground hit info.
--- @param x number  world X
--- @param y number  world Y
--- @param z number  world Z (altitude)
--- @param dist number|nil  max downward distance (default 100)
--- @param mask number|nil  layer mask (-1 = all)
--- @return table|nil  { gx,gy,gz, nx,ny,nz, slope, dist } or nil on miss
function terrain.raycast_down(x, y, z, dist, mask)
    dist = dist or 100
    mask = mask or -1
    local raw = _cmd(string.format("RAYCAST_DOWN %.4f %.4f %.4f %.4f %d",
                     x, y, z, dist, mask))
    if not raw or raw == "MISS" or raw:find("^ERR") then return nil end
    local t = {}
    for k, v in raw:gmatch("([%w_]+)=([^|]+)") do
        t[k] = tonumber(v) or v
    end
    return t
end

--- Batch downward raycasts in a grid pattern.
--- @param cx number  center X
--- @param cy number  center Y
--- @param cz number  center Z (altitude)
--- @param radius number  half-size of scan area
--- @param step number  grid spacing (units between samples)
--- @param maxDist number|nil  max downward distance (default 100)
--- @param mask number|nil  layer mask (-1 = all)
--- @return string  raw grid response (multi-line, parse with terrain.parse_batch)
function terrain.raycast_batch(cx, cy, cz, radius, step, maxDist, mask)
    maxDist = maxDist or 100
    mask = mask or -1
    return _cmd(string.format("RAYCAST_BATCH %.4f %.4f %.4f %.4f %.4f %.4f %d",
                cx, cy, cz, radius, step, maxDist, mask))
end

--- Parse a RAYCAST_BATCH response into a 2D grid of cells.
--- @param raw string  raw IPC response from raycast_batch()
--- @return table  { header={cx,cy,cz,radius,step,cols,rows}, grid=2D array of {height,slope} or nil, summary={total,hits,miss} }
function terrain.parse_batch(raw)
    if not raw or raw:find("^ERR") then return { header={}, grid={}, summary={} } end

    local result = { header = {}, grid = {}, summary = {} }

    for line in raw:gmatch("[^\n]+") do
        if line:find("^GRID|") then
            for k, v in line:gmatch("([%w_]+)=([^|]+)") do
                result.header[k] = tonumber(v) or v
            end
        elseif line:find("^ROW|") then
            local row_idx = tonumber(line:match("^ROW|(%d+)"))
            if row_idx then
                local row = {}
                local after_wy = line:match("^ROW|%d+|gy=[^|]+(.*)")
                if after_wy then
                    local ci = 1
                    for cell in after_wy:gmatch("|([^|]+)") do
                        if cell == "X" then
                            row[ci] = false  -- miss (false, not nil, to keep indices)
                        else
                            local h, s = cell:match("([^,]+),([^,]+)")
                            if h then
                                row[ci] = { height = tonumber(h), slope = tonumber(s) }
                            else
                                row[ci] = false
                            end
                        end
                        ci = ci + 1
                    end
                end
                result.grid[row_idx] = row
            end
        elseif line:find("^SUMMARY|") then
            for k, v in line:gmatch("([%w_]+)=([^|]+)") do
                result.summary[k] = tonumber(v) or v
            end
        end
    end

    return result
end

return terrain
