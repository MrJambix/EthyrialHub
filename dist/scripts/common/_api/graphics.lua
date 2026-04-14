-- ═══════════════════════════════════════════════════════════════
--  core.graphics — In-Game 3D Drawing (Unity LineRenderers)
--
--  All positions are in GAME coordinates (x=east, y=north, z=alt).
--  Internally converts to Unity coords for core.draw.* calls.
--
--  Uses DrawSystem slots 40-63 (slots 0-39 reserved by telegraph/argus).
--  Slot pool is auto-managed: call gfx.begin_frame() at start of
--  each render tick, then draw freely — slots auto-recycle.
-- ═══════════════════════════════════════════════════════════════

local gfx = {}

-- ── Slot management ──
local SLOT_MIN  = 40
local SLOT_MAX  = 63
local SLOT_COUNT = SLOT_MAX - SLOT_MIN + 1
local _next_slot = 0        -- next slot offset within pool
local _used_this_frame = 0  -- how many slots used this frame
local _inited = false

local function alloc_slot()
    if _used_this_frame >= SLOT_COUNT then return nil end
    local slot = SLOT_MIN + _next_slot
    _next_slot = (_next_slot + 1) % SLOT_COUNT
    _used_this_frame = _used_this_frame + 1
    return slot
end

--- Call at the start of each render callback to reset slot allocator
--- and hide previous frame's drawings.
function gfx.begin_frame()
    if not _inited then
        _cmd("DRAW_INIT")
        _inited = true
    end
    -- Hide all our slots from previous frame
    for i = SLOT_MIN, SLOT_MAX do
        _cmd(string.format("DRAW_HIDE %d", i))
    end
    _next_slot = 0
    _used_this_frame = 0
end

-- ── Coordinate conversion: Game(x,y,z) → Unity(x,z,y) ──
-- Game: x=east, y=north, z=altitude
-- Unity: x=east, y=up,   z=north

--- Draw a 3D line between two game-space positions.
--- @param p1 table {x,y,z} start position (game coords)
--- @param p2 table {x,y,z} end position (game coords)
--- @param r number red 0-1
--- @param g number green 0-1
--- @param b number blue 0-1
--- @param a number alpha 0-1
--- @param width number line width (default 0.05)
--- @return boolean success
function gfx.line_3d(p1, p2, r, g, b, a, width)
    local slot = alloc_slot()
    if not slot then return false end
    width = width or 0.05
    r = r or 0; g = g or 1; b = b or 1; a = a or 1
    -- Convert game→Unity: swap y↔z
    local res = _cmd(string.format("DRAW_LINE %d %.4f %.4f %.4f %.4f %.4f %.4f %.3f %.3f %.3f %.3f %.3f",
        slot, p1.x, p1.z, p1.y, p2.x, p2.z, p2.y, r, g, b, a, width))
    return res == "OK"
end

--- Draw a 3D circle at a game-space position (horizontal, on ground plane).
--- @param pos table {x,y,z} center (game coords)
--- @param radius number circle radius
--- @param r number red 0-1
--- @param g number green 0-1
--- @param b number blue 0-1
--- @param a number alpha 0-1
--- @param segments number|nil (default 32)
--- @param width number|nil line width (default 0.05)
--- @return boolean success
function gfx.circle_3d(pos, radius, r, g, b, a, segments, width)
    local slot = alloc_slot()
    if not slot then return false end
    segments = segments or 32
    width = width or 0.05
    r = r or 0; g = g or 1; b = b or 1; a = a or 1
    -- Convert game→Unity: swap y↔z
    local res = _cmd(string.format("DRAW_CIRCLE %d %.4f %.4f %.4f %.4f %.3f %.3f %.3f %.3f %d %.3f",
        slot, pos.x, pos.z, pos.y, radius, r, g, b, a, segments, width))
    return res == "OK"
end

--- Draw a square outline at a game-space position (horizontal).
--- @param pos table {x,y,z} center (game coords)
--- @param size number side length
--- @param r number red 0-1
--- @param g number green 0-1
--- @param b number blue 0-1
--- @param a number alpha 0-1
--- @param width number|nil line width (default 0.05)
function gfx.square_3d(pos, size, r, g, b, a, width)
    local hs = size * 0.5
    -- Four corners in game coords
    local c1 = { x = pos.x - hs, y = pos.y - hs, z = pos.z }
    local c2 = { x = pos.x + hs, y = pos.y - hs, z = pos.z }
    local c3 = { x = pos.x + hs, y = pos.y + hs, z = pos.z }
    local c4 = { x = pos.x - hs, y = pos.y + hs, z = pos.z }
    gfx.line_3d(c1, c2, r, g, b, a, width)
    gfx.line_3d(c2, c3, r, g, b, a, width)
    gfx.line_3d(c3, c4, r, g, b, a, width)
    gfx.line_3d(c4, c1, r, g, b, a, width)
end

-- ── Terrain-hugging draws (raycasts per vertex, sticks to ground) ──
-- These use known ground altitude (gz) to cast from gz+2 downward,
-- same as RAYCAST_BATCH. This avoids the sky dome collider at Y≈72.

--- Draw a line on the terrain surface between two game-space positions.
--- The DLL subdivides and raycasts at each vertex so the line follows slopes.
--- @param p1 table {x,y,z} start position (game coords, z=ground altitude)
--- @param p2 table {x,y,z} end position (game coords, z=ground altitude)
--- @param r number red 0-1
--- @param g number green 0-1
--- @param b number blue 0-1
--- @param a number alpha 0-1
--- @param width number line width (default 0.3)
--- @param step number|nil subdivision step in game units (default 1.0)
--- @param offset number|nil height above terrain (default 0.15)
--- @return boolean success
function gfx.line_terrain(p1, p2, r, g, b, a, width, step, offset)
    local slot = alloc_slot()
    if not slot then return false end
    width = width or 0.3
    step = step or 1.0
    offset = offset or 0.15
    r = r or 0; g = g or 1; b = b or 1; a = a or 1
    -- gz1/gz2 = ground altitude at each endpoint
    local gz1 = p1.z or 0
    local gz2 = p2.z or 0
    local res = _cmd(string.format("DRAW_LINE_TERRAIN %d %.4f %.4f %.4f %.4f %.4f %.4f %.3f %.3f %.3f %.3f %.3f %.2f %.3f",
        slot, p1.x, p1.y, gz1, p2.x, p2.y, gz2, r, g, b, a, width, step, offset))
    return res == "OK"
end

--- Draw a circle on the terrain surface at a game-space position.
--- Each vertex is raycasted to ground, so the circle follows terrain slopes.
--- @param pos table {x,y,z} center (game coords, z=ground altitude)
--- @param radius number circle radius
--- @param r number red 0-1
--- @param g number green 0-1
--- @param b number blue 0-1
--- @param a number alpha 0-1
--- @param segments number|nil (default 16)
--- @param width number|nil line width (default 0.3)
--- @param offset number|nil height above terrain (default 0.15)
--- @return boolean success
function gfx.circle_terrain(pos, radius, r, g, b, a, segments, width, offset)
    local slot = alloc_slot()
    if not slot then return false end
    segments = segments or 16
    width = width or 0.3
    offset = offset or 0.15
    r = r or 0; g = g or 1; b = b or 1; a = a or 1
    local gcz = pos.z or 0
    local res = _cmd(string.format("DRAW_CIRCLE_TERRAIN %d %.4f %.4f %.4f %.4f %.3f %.3f %.3f %.3f %d %.3f %.3f",
        slot, pos.x, pos.y, gcz, radius, r, g, b, a, segments, width, offset))
    return res == "OK"
end

-- ── Filled navmesh overlay (TelegraphSystem MeshRenderer) ──

--- Draw a filled mesh overlay for a nav_grid on the terrain.
--- Uses TelegraphSystem (filled triangles, not lines) for area visualization.
--- @param grid table nav_grid.build() result
--- @param r number red 0-1
--- @param g number green 0-1
--- @param b number blue 0-1
--- @param a number alpha 0-1 (0.3 recommended for good visibility)
--- @param tele_slot number TelegraphSystem slot (0-39, default 0)
--- @param offset number|nil height above ground (default 0.05)
--- @return boolean success
function gfx.navgrid_mesh(grid, r, g, b, a, tele_slot, offset)
    tele_slot = tele_slot or 0
    offset = offset or 0.05
    r = r or 0; g = g or 1; b = b or 0; a = a or 0.3

    -- Build walkability bitmap (row-major string of 0/1)
    local bits = {}
    for iy = 0, grid.rows - 1 do
        for ix = 0, grid.cols - 1 do
            local cell = grid.cells[iy] and grid.cells[iy][ix]
            if cell and cell.walkable then
                bits[#bits + 1] = "1"
            else
                bits[#bits + 1] = "0"
            end
        end
    end
    local walk_str = table.concat(bits)

    local res = _cmd(string.format("DRAW_NAVGRID %d %.4f %.4f %.4f %.1f %.2f %.3f %.3f %.3f %.3f %.3f %s",
        tele_slot, grid.cx, grid.cy, grid.cz, grid.radius, grid.step,
        r, g, b, a, offset, walk_str))
    return res == "OK"
end

--- Draw filled mesh overlay for specific area types in a nav_grid.
--- Draws one mesh per area type with distinct colors.
--- @param grid table nav_grid.build() result
--- @param area_colors table map of area_type → {r,g,b,a} (optional, uses defaults)
--- @param base_slot number starting TelegraphSystem slot (default 0)
--- @param offset number|nil height above ground (default 0.05)
--- @return number slots_used
function gfx.navgrid_areas(grid, area_colors, base_slot, offset)
    base_slot = base_slot or 0
    offset = offset or 0.05

    -- Default area colors (semi-transparent)
    local default_colors = {
        walkable = { 0.0, 0.8, 0.0, 0.25 },   -- green = walkable
        blocked  = { 1.0, 0.0, 0.0, 0.30 },    -- red = blocked
        cliff    = { 1.0, 0.5, 0.0, 0.30 },    -- orange = cliff edge
    }
    area_colors = area_colors or default_colors

    -- Build bitmaps by category
    local function make_bitmap(filter_fn)
        local bits = {}
        for iy = 0, grid.rows - 1 do
            for ix = 0, grid.cols - 1 do
                local cell = grid.cells[iy] and grid.cells[iy][ix]
                bits[#bits + 1] = (cell and filter_fn(cell)) and "1" or "0"
            end
        end
        return table.concat(bits)
    end

    local slot = base_slot
    local used = 0

    -- Walkable cells (not cliff)
    if area_colors.walkable then
        local bm = make_bitmap(function(c) return c.walkable and not c.cliff end)
        local clr = area_colors.walkable
        local res = _cmd(string.format("DRAW_NAVGRID %d %.4f %.4f %.4f %.1f %.2f %.3f %.3f %.3f %.3f %.3f %s",
            slot, grid.cx, grid.cy, grid.cz, grid.radius, grid.step,
            clr[1], clr[2], clr[3], clr[4], offset, bm))
        if res == "OK" then used = used + 1 end
        slot = slot + 1
    end

    -- Cliff edge cells
    if area_colors.cliff then
        local bm = make_bitmap(function(c) return c.walkable and c.cliff end)
        local clr = area_colors.cliff
        local res = _cmd(string.format("DRAW_NAVGRID %d %.4f %.4f %.4f %.1f %.2f %.3f %.3f %.3f %.3f %.3f %s",
            slot, grid.cx, grid.cy, grid.cz, grid.radius, grid.step,
            clr[1], clr[2], clr[3], clr[4], offset, bm))
        if res == "OK" then used = used + 1 end
        slot = slot + 1
    end

    -- Blocked cells
    if area_colors.blocked then
        local bm = make_bitmap(function(c) return not c.walkable end)
        local clr = area_colors.blocked
        local res = _cmd(string.format("DRAW_NAVGRID %d %.4f %.4f %.4f %.1f %.2f %.3f %.3f %.3f %.3f %.3f %s",
            slot, grid.cx, grid.cy, grid.cz, grid.radius, grid.step,
            clr[1], clr[2], clr[3], clr[4], offset + 0.01, bm))
        if res == "OK" then used = used + 1 end
        slot = slot + 1
    end

    return used
end

-- Legacy stubs for compatibility
function gfx.text_2d() end
function gfx.line_2d() end
function gfx.rect_2d() end
function gfx.circle_2d() end

return gfx
