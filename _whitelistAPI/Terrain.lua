-- ═══════════════════════════════════════════════════════════════════════════
--  WHITELISTED ADDON API  —  TERRAIN & FLOOR
--  Namespaces: core.terrain.*, core.floor.*
--  Category:   Ground Detection, Raycasting, Walkability, Floor Items
-- ═══════════════════════════════════════════════════════════════════════════
--
--  Physics raycasting, walkability grids, terrain dumps, and floor
--  item inspection for pathfinding and world analysis.
--
-- ───────────────────────────────────────────────────────────────────────────

-- ┌─────────────────────────────────────────────────────────────┐
-- │  core.terrain.*  —  Terrain & Raycasting                   │
-- └─────────────────────────────────────────────────────────────┘

--- Dump terrain data around a center point.
---@param cx number  center X
---@param cy number  center Y
---@param floor number  floor/Y level
---@param radius number
---@return string dump
-- core.terrain.dump(cx, cy, floor, radius)

--- Get walkability grid around a center point.
---@param cx number
---@param cy number
---@param floor number
---@param radius number
---@return string grid
-- core.terrain.walkability(cx, cy, floor, radius)

--- Physics raycast in a direction.
---@param ox number  origin X
---@param oy number  origin Y
---@param oz number  origin Z
---@param dx number  direction X
---@param dy number  direction Y
---@param dz number  direction Z
---@param dist number  max distance
---@param mask number  layer mask
---@return table|nil hit  {x, y, z, distance, normal, ...}
-- core.terrain.raycast(ox, oy, oz, dx, dy, dz, dist, mask)

--- Raycast straight down from a point (ground detection).
---@param x number
---@param y number
---@param z number
---@param dist number  max down distance
---@param mask number  layer mask
---@return table|nil hit  {x, y, z, distance, ...}
-- core.terrain.raycast_down(x, y, z, dist, mask)

--- Batch downward raycasts in a grid pattern.
---@param cx number  center X
---@param cy number  center Y
---@param cz number  center Z
---@param radius number  grid radius
---@param step number  grid step size
---@param maxDist number  max down distance per ray
---@param mask number  layer mask
---@return string raw  (grid of hit points)
-- core.terrain.raycast_batch(cx, cy, cz, radius, step, maxDist, mask)

--- Parse a batch raycast response into a table.
---@param raw string
---@return table grid
-- core.terrain.parse_batch(raw)

-- ┌─────────────────────────────────────────────────────────────┐
-- │  core.floor.*  —  Floor Items                              │
-- └─────────────────────────────────────────────────────────────┘

--- Dump floor item debug info.
-- core.floor.debug()

--- Search for floor items.
-- core.floor.search()

--- Inspect a floor item by index.
---@param index number
-- core.floor.inspect(index)
