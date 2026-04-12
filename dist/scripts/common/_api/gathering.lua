-- ═══════════════════════════════════════════════════════════════
--  core.gathering — Resource Gathering API
-- ═══════════════════════════════════════════════════════════════

local gather = {}

-- ── Raw commands ──

function gather.gather_nearest(filter)
    return _cmd(filter and ("GATHER_NEAREST_" .. filter) or "GATHER_NEAREST")
end

function gather.gather_by_ptr(ptr)
    return _cmd("GATHER_PTR_" .. _ptr_hex(ptr))
end

function gather.node_scan(filter)
    return _cmd(filter and ("NODE_SCAN_" .. filter) or "NODE_SCAN")
end

function gather.node_scan_usable(filter)
    return _cmd(filter and ("NODE_SCAN_USABLE_" .. filter) or "NODE_SCAN_USABLE")
end

function gather.scan_herbs()
    return _cmd("SCENE_SCAN_HERBS")
end

function gather.scan_trees()
    return _cmd("SCENE_SCAN_TREES")
end

function gather.scan_ores()
    return _cmd("SCENE_SCAN_ORES")
end

function gather.scan_corpses()
    return _cmd("SCENE_CORPSES")
end

function gather.use_tool_on_corpse(name)
    return _cmd("USE_TOOL_ON_CORPSE_" .. name)
end

function gather.use_entity(filter)
    return _cmd("USE_ENTITY_" .. filter)
end

-- ── Parsed helpers ──

function gather.get_herbs()
    return _parse_lines(_cmd("SCENE_SCAN_HERBS"))
end

function gather.get_trees()
    return _parse_lines(_cmd("SCENE_SCAN_TREES"))
end

function gather.get_ores()
    return _parse_lines(_cmd("SCENE_SCAN_ORES"))
end

function gather.get_corpses()
    return _parse_lines(_cmd("SCENE_CORPSES"))
end

function gather.get_nodes(filter)
    return _parse_lines(gather.node_scan(filter))
end

function gather.get_usable_nodes(filter)
    return _parse_lines(gather.node_scan_usable(filter))
end

-- ── Water detection ──

function gather.find_water()
    local raw = _cmd("FIND_WATER")
    if not raw or raw == "" or raw:sub(1, 3) == "ERR" then
        return { count = 0, nearest = false, can_touch = false, raw = raw or "" }
    end
    local t = {}
    t.count     = tonumber(raw:match("count=(%d+)")) or 0
    t.nearest   = raw:match("nearest=YES") ~= nil
    t.can_touch = raw:match("can_touch=1") ~= nil
    t.water_x   = tonumber(raw:match("water_x=([%d%.%-]+)"))
    t.water_y   = tonumber(raw:match("water_y=([%d%.%-]+)"))
    t.water_z   = tonumber(raw:match("water_z=([%d%.%-]+)"))
    t.ptr       = raw:match("ptr=(0x%x+)")
    t.raw       = raw
    return t
end

function gather.water_search()
    return _cmd("WATER_SEARCH")
end

function gather.water_dump()
    return _cmd("WATER_DUMP")
end

return gather
