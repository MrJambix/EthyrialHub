-- ═══════════════════════════════════════════════════════════════
--  core.matchmaking — Matchmaking API
-- ═══════════════════════════════════════════════════════════════

local matchmaking = {}

function matchmaking.status()
    return _cmd("MATCHMAKING_STATUS")
end

function matchmaking.get_status()
    return _parse_single(_cmd("MATCHMAKING_STATUS"))
end

function matchmaking.maps()
    return _cmd("MATCHMAKING_MAPS")
end

function matchmaking.get_maps()
    return _parse_lines(_cmd("MATCHMAKING_MAPS"))
end

function matchmaking.in_queue()
    local s = matchmaking.get_status()
    return s and tonumber(s.status) ~= 0
end

function matchmaking.map_count()
    local s = matchmaking.get_status()
    return s and tonumber(s.map_count) or 0
end

return matchmaking
