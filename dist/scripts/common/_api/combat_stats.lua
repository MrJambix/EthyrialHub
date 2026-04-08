--[[
╔══════════════════════════════════════════════════════════════╗
║        CombatStats — DPS Tracker & Session Metrics           ║
║                                                              ║
║  Tracks kills/hour, damage estimates, combat uptime,         ║
║  spell usage frequency, and session statistics.              ║
║                                                              ║
║  Usage:                                                      ║
║    local stats = require("common/_api/combat_stats")         ║
║    stats.start_session()                                     ║
║    -- in your combat loop:                                   ║
║    stats.on_kill("Goblin")                                   ║
║    stats.on_cast("Fireball")                                 ║
║    print(stats.summary())                                    ║
╚══════════════════════════════════════════════════════════════╝
]]

local stats = {}

-- Session data
local _session = {
    start_time = 0,
    kills = 0,
    deaths = 0,
    casts = 0,
    loots = 0,
    combat_time = 0,       -- total seconds in combat
    idle_time = 0,         -- total seconds out of combat
    gold_start = 0,
    gold_current = 0,

    -- Rolling window for kills/hour
    kill_times = {},       -- timestamps of recent kills
    cast_counts = {},      -- { spell_name = count }
    kill_counts = {},      -- { mob_name = count }
    loot_items = {},       -- { item_name = count }

    -- Combat tracking
    in_combat = false,
    combat_start_time = 0,
    last_target_hp = 100,
    damage_dealt = 0,      -- estimated from target HP changes
}

local function get_time()
    if core and core.time then return core.time() end
    return os.clock()
end

-- ══════════════════════════════════════════════════════════════
-- Session Management
-- ══════════════════════════════════════════════════════════════

--- Start a new tracking session.
function stats.start_session()
    local now = get_time()
    _session.start_time = now
    _session.kills = 0
    _session.deaths = 0
    _session.casts = 0
    _session.loots = 0
    _session.combat_time = 0
    _session.idle_time = 0
    _session.kill_times = {}
    _session.cast_counts = {}
    _session.kill_counts = {}
    _session.loot_items = {}
    _session.in_combat = false
    _session.combat_start_time = 0
    _session.last_target_hp = 100
    _session.damage_dealt = 0

    if conn and conn.get_gold then
        _session.gold_start = conn.get_gold() or 0
    end
    _session.gold_current = _session.gold_start
end

--- Get session elapsed time in seconds.
function stats.elapsed()
    if _session.start_time == 0 then return 0 end
    return get_time() - _session.start_time
end

-- ══════════════════════════════════════════════════════════════
-- Event Recording
-- ══════════════════════════════════════════════════════════════

--- Record a kill.
function stats.on_kill(mob_name)
    _session.kills = _session.kills + 1
    _session.kill_times[#_session.kill_times + 1] = get_time()

    if mob_name then
        _session.kill_counts[mob_name] = (_session.kill_counts[mob_name] or 0) + 1
    end

    -- Trim old kill times (keep last 100 for rate calculation)
    while #_session.kill_times > 100 do
        table.remove(_session.kill_times, 1)
    end
end

--- Record a spell cast.
function stats.on_cast(spell_name)
    _session.casts = _session.casts + 1
    if spell_name then
        _session.cast_counts[spell_name] = (_session.cast_counts[spell_name] or 0) + 1
    end
end

--- Record a loot pickup.
function stats.on_loot(item_name)
    _session.loots = _session.loots + 1
    if item_name then
        _session.loot_items[item_name] = (_session.loot_items[item_name] or 0) + 1
    end
end

--- Record a death.
function stats.on_death()
    _session.deaths = _session.deaths + 1
end

-- ══════════════════════════════════════════════════════════════
-- Computed Metrics
-- ══════════════════════════════════════════════════════════════

--- Get kills per hour.
function stats.kills_per_hour()
    local elapsed = stats.elapsed()
    if elapsed < 1 then return 0 end
    return (_session.kills / elapsed) * 3600
end

--- Get kills in last N minutes (rolling rate).
function stats.kills_recent(minutes)
    minutes = minutes or 5
    local cutoff = get_time() - (minutes * 60)
    local count = 0
    for _, t in ipairs(_session.kill_times) do
        if t >= cutoff then count = count + 1 end
    end
    return count, (count / minutes) * 60  -- count, per_hour
end

--- Get casts per minute.
function stats.casts_per_minute()
    local elapsed = stats.elapsed()
    if elapsed < 1 then return 0 end
    return (_session.casts / elapsed) * 60
end

--- Get combat uptime percentage.
function stats.combat_uptime()
    local total = _session.combat_time + _session.idle_time
    if total < 1 then return 0 end
    return (_session.combat_time / total) * 100
end

--- Get gold earned this session.
function stats.gold_earned()
    return _session.gold_current - _session.gold_start
end

--- Get gold per hour.
function stats.gold_per_hour()
    local elapsed = stats.elapsed()
    if elapsed < 1 then return 0 end
    return (stats.gold_earned() / elapsed) * 3600
end

--- Get most-cast spell.
function stats.top_spell()
    local best_name, best_count = nil, 0
    for name, count in pairs(_session.cast_counts) do
        if count > best_count then
            best_name = name
            best_count = count
        end
    end
    return best_name, best_count
end

--- Get most-killed mob.
function stats.top_mob()
    local best_name, best_count = nil, 0
    for name, count in pairs(_session.kill_counts) do
        if count > best_count then
            best_name = name
            best_count = count
        end
    end
    return best_name, best_count
end

--- Get spell usage breakdown.
function stats.spell_breakdown()
    return _session.cast_counts
end

--- Get kill breakdown by mob.
function stats.kill_breakdown()
    return _session.kill_counts
end

--- Get raw session data.
function stats.raw()
    return _session
end

-- ══════════════════════════════════════════════════════════════
-- Tick — call every frame to track combat time
-- ══════════════════════════════════════════════════════════════

local _last_tick = 0

function stats.tick(in_combat, target_hp)
    local now = get_time()
    local dt = now - _last_tick
    if _last_tick == 0 then dt = 0 end
    _last_tick = now

    if dt > 5 then dt = 0 end  -- skip if large gap

    if in_combat then
        _session.combat_time = _session.combat_time + dt

        if not _session.in_combat then
            _session.in_combat = true
            _session.combat_start_time = now
            _session.last_target_hp = target_hp or 100
        end

        -- Estimate damage from target HP decrease
        if target_hp and target_hp < _session.last_target_hp then
            _session.damage_dealt = _session.damage_dealt + (_session.last_target_hp - target_hp)
        end
        _session.last_target_hp = target_hp or _session.last_target_hp
    else
        _session.idle_time = _session.idle_time + dt
        _session.in_combat = false
    end

    -- Update gold
    if conn and conn.get_gold then
        _session.gold_current = conn.get_gold() or _session.gold_current
    end
end

--- Get a formatted summary string.
function stats.summary()
    local elapsed = stats.elapsed()
    local mins = math.floor(elapsed / 60)
    local secs = math.floor(elapsed % 60)

    local lines = {
        string.format("Session: %dm %ds", mins, secs),
        string.format("Kills: %d (%.0f/hr)", _session.kills, stats.kills_per_hour()),
        string.format("Casts: %d (%.1f/min)", _session.casts, stats.casts_per_minute()),
        string.format("Deaths: %d | Loots: %d", _session.deaths, _session.loots),
        string.format("Combat uptime: %.0f%%", stats.combat_uptime()),
    }

    local gold = stats.gold_earned()
    if gold ~= 0 then
        lines[#lines + 1] = string.format("Gold: %+d (%.0f/hr)", gold, stats.gold_per_hour())
    end

    local top_spell, top_count = stats.top_spell()
    if top_spell then
        lines[#lines + 1] = string.format("Top spell: %s (%dx)", top_spell, top_count)
    end

    return table.concat(lines, "\n")
end

return stats
