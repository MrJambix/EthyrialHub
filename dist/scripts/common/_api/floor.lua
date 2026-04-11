-- ═══════════════════════════════════════════════════════════════
--  core.floor — Floor Items API
-- ═══════════════════════════════════════════════════════════════

local floor = {}

function floor.debug()
    return _cmd("FLOOR_DEBUG")
end

function floor.search()
    return _cmd("FLOOR_SEARCH")
end

function floor.inspect(index)
    return _cmd("FLOOR_INSPECT_" .. index)
end

return floor
