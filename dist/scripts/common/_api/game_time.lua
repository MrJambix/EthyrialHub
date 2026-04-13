-- ═══════════════════════════════════════════════════════════════
--  core.game_time — In-Game Time API
-- ═══════════════════════════════════════════════════════════════

local game_time = {}

function game_time.raw()
    return _cmd("GAME_TIME")
end

function game_time.get()
    return _parse_single(_cmd("GAME_TIME"))
end

function game_time.hour()
    local t = game_time.get()
    return t and tonumber(t.hour) or 0
end

function game_time.minute()
    local t = game_time.get()
    return t and tonumber(t.minute) or 0
end

function game_time.second()
    local t = game_time.get()
    return t and tonumber(t.second) or 0
end

function game_time.multiplier()
    local t = game_time.get()
    return t and tonumber(t.multiplier) or 1.0
end

function game_time.formatted()
    local t = game_time.get()
    if not t then return "00:00" end
    return string.format("%02d:%02d", tonumber(t.hour) or 0, tonumber(t.minute) or 0)
end

return game_time
