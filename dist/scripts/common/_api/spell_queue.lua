--[[
╔══════════════════════════════════════════════════════════════╗
║        SpellQueue — GCD-Aware Intelligent Casting            ║
║                                                              ║
║  Priority-based spell casting with GCD tracking, cast        ║
║  queuing, and predictive spell selection.                    ║
║                                                              ║
║  Usage:                                                      ║
║    local sq = require("common/_api/spell_queue")             ║
║    sq.set_priority({"Fireball", "Frostbolt", "Ice Lance"})  ║
║    sq.tick()   -- call every frame, casts best available     ║
╚══════════════════════════════════════════════════════════════╝
]]

local sq = {}

-- Internal state
local _priority = {}         -- ordered list of spell names (highest priority first)
local _conditions = {}       -- { spell_name = condition_fn }
local _gcd_end = 0           -- timestamp when GCD expires
local _gcd_duration = 1.0    -- estimated GCD in seconds
local _cast_end = 0          -- timestamp when current cast finishes
local _last_cast = ""        -- name of last spell cast
local _last_cast_time = 0
local _cast_history = {}     -- { { name, time }, ... }
local _max_history = 50
local _queue = {}            -- manual spell queue (FIFO)
local _enabled = true

-- Spell tracking
local _spell_cds = {}        -- { name = { cd_end, cd_duration } }

local function get_time()
    if core and core.time then return core.time() end
    return os.clock()
end

-- ══════════════════════════════════════════════════════════════
-- Configuration
-- ══════════════════════════════════════════════════════════════

--- Set the priority list (first = highest priority).
function sq.set_priority(spell_list)
    _priority = spell_list
end

--- Add a condition for when a spell should be cast.
--- If condition returns false, the spell is skipped even if ready.
function sq.set_condition(spell_name, condition_fn)
    _conditions[spell_name] = condition_fn
end

--- Set the global cooldown duration estimate.
function sq.set_gcd(seconds)
    _gcd_duration = seconds
end

--- Enable/disable the spell queue.
function sq.set_enabled(enabled)
    _enabled = enabled
end

-- ══════════════════════════════════════════════════════════════
-- Manual Queue
-- ══════════════════════════════════════════════════════════════

--- Queue a spell to be cast next (ahead of priority list).
function sq.enqueue(spell_name)
    _queue[#_queue + 1] = spell_name
end

--- Queue multiple spells in sequence.
function sq.enqueue_sequence(...)
    for _, name in ipairs({...}) do
        _queue[#_queue + 1] = name
    end
end

--- Clear the manual queue.
function sq.clear_queue()
    _queue = {}
end

-- ══════════════════════════════════════════════════════════════
-- Queries
-- ══════════════════════════════════════════════════════════════

--- Check if on global cooldown.
function sq.on_gcd()
    return get_time() < _gcd_end
end

--- Check if currently casting.
function sq.is_casting()
    return get_time() < _cast_end
end

--- Get the best spell to cast right now (without casting it).
function sq.best_spell()
    -- Check manual queue first
    if #_queue > 0 then
        for i, name in ipairs(_queue) do
            if sq.can_cast(name) then
                return name, "queued"
            end
        end
    end

    -- Check priority list
    for _, name in ipairs(_priority) do
        if sq.can_cast(name) then
            return name, "priority"
        end
    end

    return nil, "none"
end

--- Check if a specific spell can be cast right now.
function sq.can_cast(spell_name)
    -- Check condition
    local cond = _conditions[spell_name]
    if cond then
        local ok, result = pcall(cond)
        if not ok or not result then return false end
    end

    -- Check if spell is ready via game API
    if core and core.spells and core.spells.is_ready then
        return core.spells.is_ready(spell_name)
    elseif core and core.spell_book and core.spell_book.is_spell_ready then
        return core.spell_book.is_spell_ready(spell_name)
    end

    return false
end

--- Try to cast a specific spell. Returns true if cast succeeded.
function sq.try_cast(spell_name)
    if not sq.can_cast(spell_name) then return false end
    if sq.on_gcd() or sq.is_casting() then return false end

    local result
    if core and core.spells and core.spells.cast then
        result = core.spells.cast(spell_name)
    elseif core and core.spell_book and core.spell_book.cast_spell then
        result = core.spell_book.cast_spell(spell_name)
    end

    if result and tostring(result):find("OK") then
        local now = get_time()
        _gcd_end = now + _gcd_duration
        _last_cast = spell_name
        _last_cast_time = now
        _cast_history[#_cast_history + 1] = { name = spell_name, time = now }

        -- Trim history
        while #_cast_history > _max_history do
            table.remove(_cast_history, 1)
        end

        return true
    end

    return false
end

-- ══════════════════════════════════════════════════════════════
-- Tick — call every frame
-- ══════════════════════════════════════════════════════════════

function sq.tick()
    if not _enabled then return nil end
    if sq.on_gcd() or sq.is_casting() then return nil end

    -- Try manual queue first
    while #_queue > 0 do
        local name = _queue[1]
        if sq.try_cast(name) then
            table.remove(_queue, 1)
            return name
        else
            -- If queued spell isn't ready, try next in queue
            if not sq.can_cast(name) then
                table.remove(_queue, 1)
            else
                break  -- spell is ready but cast failed for other reason
            end
        end
    end

    -- Try priority list
    for _, name in ipairs(_priority) do
        if sq.try_cast(name) then
            return name
        end
    end

    return nil
end

-- ══════════════════════════════════════════════════════════════
-- History / Stats
-- ══════════════════════════════════════════════════════════════

--- Get the last spell cast.
function sq.last_cast()
    return _last_cast, _last_cast_time
end

--- Get cast history.
function sq.history(count)
    count = count or 10
    local result = {}
    local start = math.max(1, #_cast_history - count + 1)
    for i = start, #_cast_history do
        result[#result + 1] = _cast_history[i]
    end
    return result
end

--- Get casts per minute.
function sq.cpm()
    if #_cast_history < 2 then return 0 end
    local first = _cast_history[1].time
    local last = _cast_history[#_cast_history].time
    local window = last - first
    if window < 1 then return 0 end
    return (#_cast_history / window) * 60
end

--- Get debug info.
function sq.debug()
    local best, source = sq.best_spell()
    return string.format("gcd=%s cast=%s last=%s best=%s(%s) queue=%d prio=%d cpm=%.1f",
        sq.on_gcd() and "YES" or "no",
        sq.is_casting() and "YES" or "no",
        _last_cast ~= "" and _last_cast or "none",
        best or "none", source,
        #_queue, #_priority, sq.cpm())
end

return sq
