-- ═══════════════════════════════════════════════════════════════
--  core.discovered_nav — Exploration-Built Walkability Map
--
--  A cell is "known walkable" only after the player has physically
--  stood on it. Each tick samples player position, raycasts down to
--  confirm ground, and writes the cell into a quantized grid keyed
--  by (ix, iy, floor). The map persists per-zone to disk so walked
--  ground is remembered across sessions.
--
--  Draw uses gfx.navgrid_areas by building a local window grid
--  around the player from the discovered set.
-- ═══════════════════════════════════════════════════════════════

local terrain = require("common/_api/terrain")
local player  = require("common/_api/player")
local gfx     = require("common/_api/graphics")

local dn = {}
dn.__index = dn

-- ── Defaults ──
local DEFAULTS = {
    step          = 1.0,     -- quantization bucket size in game units
    ray_dist      = 50.0,    -- max downward ray distance
    ray_offset    = 2.0,     -- cast from this far above player altitude
    layer_mask    = -17,     -- exclude water layer
    draw_radius   = 20,      -- window half-size for draw()
    save_every    = 15.0,    -- autosave interval in seconds
    min_dt        = 0.10,    -- don't record faster than this (seconds)
    min_move      = 0.25,    -- skip if player moved less than this
    save_dir      = nil,     -- defaults to scripts/data
}

-- Resolve the scripts directory from debug.getinfo so we can colocate saves.
local function script_root()
    local info = debug.getinfo(2, "S")
    local src = info and info.source and info.source:gsub("^@", "") or ""
    -- src is .../common/_api/discovered_nav.lua → want .../scripts
    local dir = src:match("^(.-)[/\\]common[/\\]_api[/\\]") or src:match("^(.*)[/\\]") or "."
    return dir
end

local SCRIPT_ROOT = script_root()

-- ── Constructor ──
--- Create a new discovered nav instance for the given zone.
--- @param opts table|nil { zone=string, step=num, draw_radius=num, ... }
--- @return table dn instance
function dn.new(opts)
    opts = opts or {}
    local self = setmetatable({}, dn)
    for k, v in pairs(DEFAULTS) do self[k] = v end
    for k, v in pairs(opts)     do self[k] = v end

    self.zone       = opts.zone or "unknown"
    self.cells      = {}          -- key "ix,iy,floor" → { uy, slope, visits, t }
    self.cell_count = 0
    self._last_t    = 0
    self._last_x    = nil
    self._last_y    = nil
    self._last_save = 0
    self._dirty     = false

    if not self.save_dir then
        self.save_dir = SCRIPT_ROOT .. "/data"
    end
    return self
end

-- ── Cell key: game units → quantized grid ──
local function key(ix, iy, floor)
    return ix .. "," .. iy .. "," .. floor
end

local function quantize(self, gx, gy)
    local ix = math.floor(gx / self.step + 0.5)
    local iy = math.floor(gy / self.step + 0.5)
    return ix, iy
end

--- World-space center of a quantized cell.
function dn:cell_center(ix, iy)
    return ix * self.step, iy * self.step
end

-- ── Time helper ──
local function now()
    return (os and os.clock and os.clock()) or 0
end

-- ══════════════════════════════════════════════════════════════
--  Recording
-- ══════════════════════════════════════════════════════════════

--- Record the player's current position as a walkable cell. Cheap
--- enough to call every tick; internally rate-limited by min_dt.
--- @return boolean added_new_cell, string|nil err
function dn:tick()
    local t = now()
    if (t - self._last_t) < self.min_dt then return false, nil end
    self._last_t = t

    -- Read game pos (x, y, floor). floor is integer; gz is not altitude.
    local p = player.get_position()
    if not p or (p.x == 0 and p.y == 0) then
        return false, "no player pos"
    end

    -- Movement gate — don't spam the same cell every tick
    if self._last_x and self._last_y then
        local dx = p.x - self._last_x
        local dy = p.y - self._last_y
        if (dx*dx + dy*dy) < (self.min_move * self.min_move) then
            return false, nil
        end
    end
    self._last_x, self._last_y = p.x, p.y

    -- Raycast down from well above player to find the real Unity Y of the
    -- ground they're standing on. We don't know the player's Unity Y here,
    -- but we can cast from a high altitude (sky is well above any floor)
    -- and get the first hit. Mask excludes water.
    local hit = terrain.raycast_down(p.x, p.y, 1000, self.ray_dist + 1000, self.layer_mask)
    if not hit then
        -- Fallback: cast from player altitude shape — Unity uses real Y,
        -- but game p.z is floor index. Try a moderate raycast above.
        hit = terrain.raycast_down(p.x, p.y, 100, 200, self.layer_mask)
    end
    if not hit then return false, "no ground raycast" end

    local ix, iy = quantize(self, p.x, p.y)
    local floor  = math.floor(p.z + 0.5)
    local k = key(ix, iy, floor)

    local cell = self.cells[k]
    if cell then
        cell.visits = cell.visits + 1
        cell.t      = t
        -- Smooth uy a bit in case of jitter
        cell.uy     = cell.uy * 0.7 + hit.gz * 0.3
        self._dirty = true
        return false, nil
    end

    self.cells[k] = {
        ix     = ix,
        iy     = iy,
        floor  = floor,
        uy     = hit.gz,
        slope  = hit.slope or 0,
        visits = 1,
        t      = t,
    }
    self.cell_count = self.cell_count + 1
    self._dirty = true

    -- Periodic autosave
    if (t - self._last_save) >= self.save_every then
        self:save()
    end
    return true, nil
end

-- ══════════════════════════════════════════════════════════════
--  Query
-- ══════════════════════════════════════════════════════════════

--- Is the given world position a known-walkable cell on the given floor?
function dn:is_known(gx, gy, floor)
    local ix, iy = quantize(self, gx, gy)
    return self.cells[key(ix, iy, floor)] ~= nil
end

--- Fetch the raw cell at a world position (or nil).
function dn:get(gx, gy, floor)
    local ix, iy = quantize(self, gx, gy)
    return self.cells[key(ix, iy, floor)]
end

-- ══════════════════════════════════════════════════════════════
--  Persistence — simple Lua table format (dofile-able)
-- ══════════════════════════════════════════════════════════════

local function sanitize_zone(z)
    return (z or "unknown"):gsub("[^%w_%-]", "_")
end

function dn:file_path()
    return self.save_dir .. "/navmesh_" .. sanitize_zone(self.zone) .. ".lua"
end

--- Serialize and write the discovered cells to disk.
function dn:save()
    self._last_save = now()
    local path = self:file_path()
    local f = io.open(path, "w")
    if not f then
        -- Directory may not exist — retry without data/
        path = SCRIPT_ROOT .. "/navmesh_" .. sanitize_zone(self.zone) .. ".lua"
        f = io.open(path, "w")
    end
    if not f then return false, "cannot open " .. path end

    f:write("-- Auto-generated discovered navmesh\n")
    f:write(string.format("-- zone=%s  step=%.3f  cells=%d\n",
        self.zone, self.step, self.cell_count))
    f:write("return {\n")
    f:write(string.format("  zone=%q,\n", self.zone))
    f:write(string.format("  step=%.3f,\n", self.step))
    f:write(string.format("  cell_count=%d,\n", self.cell_count))
    f:write("  cells={\n")
    for k, c in pairs(self.cells) do
        f:write(string.format("    [%q]={ix=%d,iy=%d,floor=%d,uy=%.4f,slope=%.2f,visits=%d},\n",
            k, c.ix, c.iy, c.floor, c.uy, c.slope or 0, c.visits or 1))
    end
    f:write("  },\n")
    f:write("}\n")
    f:close()
    self._dirty = false
    return true, path
end

--- Load cells from disk (replacing current state).
function dn:load()
    local path = self:file_path()
    local chunk, err = loadfile(path)
    if not chunk then
        -- Fallback location
        path = SCRIPT_ROOT .. "/navmesh_" .. sanitize_zone(self.zone) .. ".lua"
        chunk = loadfile(path)
        if not chunk then return false, err end
    end
    local ok, data = pcall(chunk)
    if not ok or type(data) ~= "table" then return false, "parse error" end

    self.cells = data.cells or {}
    self.cell_count = 0
    for _ in pairs(self.cells) do
        self.cell_count = self.cell_count + 1
    end
    self.step = data.step or self.step
    return true, path
end

-- ══════════════════════════════════════════════════════════════
--  Draw — build a local window grid and hand it to gfx.navgrid_areas
-- ══════════════════════════════════════════════════════════════

--- Build a grid-compatible window around a center point. The result
--- matches the shape nav_grid.build() produces, so gfx.navgrid_areas
--- can render it directly.
function dn:build_window(cx, cy, floor, radius)
    radius = radius or self.draw_radius
    local step = self.step
    local cols = math.floor(radius * 2 / step) + 1
    local rows = cols

    local grid = {
        cx = cx, cy = cy, cz = floor,
        radius = radius, step = step,
        cols = cols, rows = rows,
        cells = {},
    }

    local cix, ciy = quantize(self, cx, cy)
    local half = math.floor(cols / 2)

    for iy = 0, rows - 1 do
        grid.cells[iy] = {}
        for ix = 0, cols - 1 do
            local wix = cix - half + ix
            local wiy = ciy - half + iy
            local c = self.cells[key(wix, wiy, floor)]
            if c then
                local gx, gy = self:cell_center(wix, wiy)
                grid.cells[iy][ix] = {
                    ix = ix, iy = iy,
                    gx = gx, gy = gy, gz = c.uy,
                    slope = c.slope or 0,
                    walkable = true,
                    cliff = false,
                    area = 0, cost = 1.0,
                }
            end
        end
    end
    return grid
end

--- Draw all known cells in a window around a center as a green mesh.
--- @param cx number center world X (game)
--- @param cy number center world Y (game)
--- @param floor number floor index
--- @param radius number|nil window half-size
--- @return number layers_drawn
function dn:draw(cx, cy, floor, radius)
    local grid = self:build_window(cx, cy, floor, radius)
    return gfx.navgrid_areas(grid, {
        walkable = { 0.0, 0.9, 0.3, 0.28 },   -- green = discovered / walked
    }, 0, 0.10)
end

--- Convenience: draw around the player's current game position.
function dn:draw_around_player(radius)
    local p = player.get_position()
    if not p then return 0 end
    local floor = math.floor(p.z + 0.5)
    return self:draw(p.x, p.y, floor, radius)
end

-- ══════════════════════════════════════════════════════════════
--  Stats
-- ══════════════════════════════════════════════════════════════

function dn:stats()
    local by_floor = {}
    for _, c in pairs(self.cells) do
        by_floor[c.floor] = (by_floor[c.floor] or 0) + 1
    end
    return {
        zone       = self.zone,
        step       = self.step,
        cell_count = self.cell_count,
        by_floor   = by_floor,
    }
end

return dn
