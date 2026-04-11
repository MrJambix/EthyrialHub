-- ═══════════════════════════════════════════════════════════════
--  core.terrain — Terrain / Walkability API
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

return terrain
