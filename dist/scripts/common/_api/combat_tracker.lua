-- ═══════════════════════════════════════════════════════════════
--  core.combat_tracker — Enemy Combat & Casting Tracker
--
--  Provides a unified, cached view of nearby enemies with:
--    • Aggressor detection (enemies targeting the player)
--    • Enemy spell cast detection (what spell, duration, progress)
--    • Cast-start notifications (detects new casts vs ongoing)
--    • Range-bucketed enemy counts
--    • Player status effect cache (buffs, debuffs)
--
--  Single SCAN_ENEMIES call per refresh (~0.3s) feeds all queries.
--  PLAYER_STATUS_EFFECTS call feeds buff/debuff queries.
--
--  Usage:
--    core.combat_tracker.refresh()
--    local aggressors = core.combat_tracker.get_aggressors()
--    local casting, caster = core.combat_tracker.is_enemy_casting(10)
--    local has_debuff = core.combat_tracker.player_has_debuffs()
-- ═══════════════════════════════════════════════════════════════

local ct = {}

-- ── Internal helpers ────────────────────────────────────────────

local function _now() return os.clock() end

local function _parse_kv(line)
    local t = {}
    for k, v in line:gmatch("([%w_]+)=([^|]+)") do
        local n = tonumber(v)
        if n then t[k] = n else t[k] = v end
    end
    return t
end

local function _log(tag, msg, ...)
    if core and core.log then
        core.log(string.format("[CT:%s] " .. msg, tag, ...))
    end
end

-- ══════════════════════════════════════════════════════════════
-- ENEMY SCAN CACHE
-- ══════════════════════════════════════════════════════════════

local _scan = {
    time         = 0,
    enemies      = {},      -- full parsed enemy list
    range_counts = {},      -- pre-computed enemy counts by range
    aggressors   = {},      -- enemies whose hostile target == player
    in_combat    = {},      -- enemies in combat (targeting me OR combat=1)
    casters      = {},      -- enemies actively casting a spell
}
local _prev_casters = {}    -- {uid -> spell_name} from last tick
local _scan_interval = 0.3  -- seconds between refreshes

local function _refresh_scan()
    local t = _now()
    if (t - _scan.time) < _scan_interval then return end
    _scan.time = t
    _scan.enemies      = {}
    _scan.range_counts = {}
    _scan.aggressors   = {}
    _scan.in_combat    = {}
    _scan.casters      = {}

    local ok, raw = pcall(_cmd, "SCAN_ENEMIES")
    if not ok or not raw or raw == "NONE" or raw == "" then return end

    local distances = {}
    for entry in raw:gmatch("[^#]+") do
        local kv = _parse_kv(entry)
        if kv and kv.uid and kv.name then
            local enemy = {
                name         = kv.name or "?",
                uid          = kv.uid or 0,
                dist         = kv.dist or 999,
                hp           = kv.hp or 0,
                max_hp       = kv.max_hp or 0,
                boss         = (kv.boss == 1),
                elite        = (kv.elite == 1),
                rare         = (kv.rare == 1),
                combat       = (kv.combat == 1),
                targeting_me = (kv.targeting_me == 1),
                is_casting   = (kv.is_casting == 1),
                cast_spell   = kv.cast_spell or "",
                cast_dur     = kv.cast_dur or 0,
                cast_elapsed = kv.cast_elapsed or 0,
            }
            _scan.enemies[#_scan.enemies + 1] = enemy
            distances[#distances + 1] = enemy.dist

            if enemy.targeting_me then
                _scan.aggressors[#_scan.aggressors + 1] = enemy
            end
            if enemy.targeting_me or enemy.combat then
                _scan.in_combat[#_scan.in_combat + 1] = enemy
            end
            if enemy.is_casting and enemy.cast_spell ~= "" then
                _scan.casters[#_scan.casters + 1] = enemy
                local prev = _prev_casters[enemy.uid]
                if not prev or prev ~= enemy.cast_spell then
                    _log("CAST", "%s started casting [%s] (%.1fs, dist=%.1f)",
                        enemy.name, enemy.cast_spell, enemy.cast_dur, enemy.dist)
                end
            end
        end
    end

    _prev_casters = {}
    for _, c in ipairs(_scan.casters) do
        _prev_casters[c.uid] = c.cast_spell
    end

    for _, r in ipairs({4, 6, 8, 10, 15, 20, 30, 60}) do
        local c = 0
        for _, d in ipairs(distances) do
            if d <= r then c = c + 1 end
        end
        _scan.range_counts[r] = c
    end
end

-- ══════════════════════════════════════════════════════════════
-- PLAYER STATUS EFFECTS CACHE
-- ══════════════════════════════════════════════════════════════

local _effects = {
    time        = 0,
    buffs       = {},
    debuffs     = {},
    has_debuffs = false,
}
local _effects_interval = 0.3

local function _refresh_effects()
    local t = _now()
    if (t - _effects.time) < _effects_interval then return end
    _effects.time = t
    _effects.buffs = {}
    _effects.debuffs = {}
    _effects.has_debuffs = false

    local ok, raw = pcall(_cmd, "PLAYER_STATUS_EFFECTS")
    if not ok or not raw or raw == "" or raw == "NONE" then return end
    if raw:sub(1, 4) == "ERR:" or raw:sub(1, 4) == "ERR|" then return end

    local body = raw:match("###(.+)") or raw
    for entry in (body .. "|||"):gmatch("(.-)|||") do
        if entry ~= "" then
            local e = {}
            for k, v in entry:gmatch("([%w_]+)=([^|]+)") do
                local n = tonumber(v)
                if n then e[k] = n else e[k] = v end
            end
            if e.name or e.display then
                local etype = e.type or -1
                local maxd  = e.max_dur or 0
                local rem   = e.remaining or e.dur or 0
                if rem < 0 then rem = 0 end
                local info = {
                    name      = e.display or e.name or "?",
                    unique    = e.name or "",
                    stacks    = math.floor(e.stacks or 0),
                    remaining = rem,
                    max_dur   = maxd,
                    type      = etype,
                }
                -- StatusEffectTypes enum (empirically mapped):
                --   0 = Buff, 1 = PassiveBuff, 2+ = Debuff/CC
                if etype >= 2 then
                    _effects.debuffs[#_effects.debuffs + 1] = info
                    _effects.has_debuffs = true
                else
                    _effects.buffs[#_effects.buffs + 1] = info
                end
            end
        end
    end
end

-- ══════════════════════════════════════════════════════════════
-- PUBLIC API — Enemy Scan
-- ══════════════════════════════════════════════════════════════

--- Force refresh enemy scan data.
function ct.refresh()
    _refresh_scan()
end

--- Set scan refresh interval (default 0.3s).
function ct.set_scan_interval(seconds)
    _scan_interval = seconds
end

--- Get all enemies within scan range (60 units).
--- @return table[] array of enemy tables
function ct.get_all_enemies()
    _refresh_scan()
    return _scan.enemies
end

--- Count enemies within a given range (meters).
--- @param range number
--- @return number
function ct.enemies_in_range(range)
    _refresh_scan()
    if _scan.range_counts[range] then
        return _scan.range_counts[range]
    end
    local c = 0
    for _, e in ipairs(_scan.enemies) do
        if e.dist <= range then c = c + 1 end
    end
    _scan.range_counts[range] = c
    return c
end

--- Get enemies whose hostile target is the player.
--- @return table[] array of enemy tables
function ct.get_aggressors()
    _refresh_scan()
    return _scan.aggressors
end

--- Count enemies targeting the player.
--- @return number
function ct.get_aggressor_count()
    _refresh_scan()
    return #_scan.aggressors
end

--- Get enemies in combat (targeting me OR has combat flag).
--- @return table[] array of enemy tables
function ct.get_enemies_in_combat()
    _refresh_scan()
    return _scan.in_combat
end

--- Get enemies currently casting a spell.
--- @return table[] each with cast_spell, cast_dur, cast_elapsed
function ct.get_enemy_casters()
    _refresh_scan()
    return _scan.casters
end

--- Check if any enemy within `range` is casting.
--- @param range number|nil max distance filter (nil = any range)
--- @return boolean, table|nil  is_casting, caster_enemy
function ct.is_enemy_casting(range)
    _refresh_scan()
    for _, c in ipairs(_scan.casters) do
        if not range or c.dist <= range then return true, c end
    end
    return false, nil
end

-- ══════════════════════════════════════════════════════════════
-- PUBLIC API — Player Status Effects
-- ══════════════════════════════════════════════════════════════

--- Force refresh player status effects.
function ct.refresh_effects()
    _refresh_effects()
end

--- Set effects refresh interval (default 0.3s).
function ct.set_effects_interval(seconds)
    _effects_interval = seconds
end

--- Check if the player has any active debuffs (type >= 2).
--- @return boolean
function ct.player_has_debuffs()
    _refresh_effects()
    return _effects.has_debuffs
end

--- Get all active player debuffs.
--- @return table[] array of {name, unique, stacks, remaining, max_dur, type}
function ct.get_player_debuffs()
    _refresh_effects()
    return _effects.debuffs
end

--- Get all active player buffs.
--- @return table[] array of {name, unique, stacks, remaining, max_dur, type}
function ct.get_player_buffs()
    _refresh_effects()
    return _effects.buffs
end

--- Find an active effect by unique or display name.
--- @param name string
--- @return table|nil  effect info or nil
function ct.find_effect(name)
    _refresh_effects()
    for _, b in ipairs(_effects.buffs) do
        if b.unique == name or b.name == name then return b end
    end
    for _, d in ipairs(_effects.debuffs) do
        if d.unique == name or d.name == name then return d end
    end
    return nil
end

--- Check if a specific buff/debuff is active.
--- @param name string unique or display name
--- @return boolean
function ct.has_effect(name)
    return ct.find_effect(name) ~= nil
end

--- Get stacks of a specific effect.
--- @param name string
--- @return number  0 if not found
function ct.effect_stacks(name)
    local e = ct.find_effect(name)
    return e and e.stacks or 0
end

--- Get remaining duration of a specific effect.
--- @param name string
--- @return number  0 if not found or permanent
function ct.effect_remaining(name)
    local e = ct.find_effect(name)
    return e and e.remaining or 0
end

return ct
