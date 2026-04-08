--[[
╔══════════════════════════════════════════════════════════════╗
║         BuffTracker — Advanced Buff/Debuff Tracking          ║
║                                                              ║
║  High-level buff queries with duration, stacks, and          ║
║  expiry warnings. Wraps core.buff_manager with caching.     ║
║                                                              ║
║  Usage:                                                      ║
║    local bt = require("common/_api/buff_tracker")            ║
║    bt.refresh()                                              ║
║    if bt.has("Regen") then ... end                           ║
║    local rem = bt.remaining("Shield")                        ║
╚══════════════════════════════════════════════════════════════╝
]]

local bt = {}

-- Internal cache
local _buffs = {}          -- { name = { stacks, remaining, elapsed, max_duration, active } }
local _buff_list = {}      -- ordered list of active buff names
local _debuffs = {}        -- same structure for debuffs
local _last_refresh = 0
local _refresh_interval = 0.2  -- seconds

-- ══════════════════════════════════════════════════════════════
-- Refresh
-- ══════════════════════════════════════════════════════════════

--- Force refresh buff data from the game.
function bt.refresh()
    _buffs = {}
    _buff_list = {}
    _debuffs = {}

    -- Use core.buff_manager if available
    if core and core.buff_manager and core.buff_manager.get_all_buffs then
        local all = core.buff_manager.get_all_buffs()
        if all then
            for _, b in ipairs(all) do
                local entry = {
                    name = b.name or b.display_name or "Unknown",
                    display_name = b.display_name or b.name or "Unknown",
                    stacks = b.stacks or 1,
                    elapsed = b.elapsed or 0,
                    max_duration = b.max_duration or 0,
                    remaining = 0,
                    active = true,
                    is_debuff = b.is_debuff or false,
                }

                if entry.max_duration > 0 then
                    entry.remaining = math.max(0, entry.max_duration - entry.elapsed)
                end

                if entry.is_debuff then
                    _debuffs[entry.name] = entry
                else
                    _buffs[entry.name] = entry
                    _buff_list[#_buff_list + 1] = entry.name
                end
            end
        end
    elseif conn and conn.send_command then
        -- Fallback: parse PLAYER_BUFFS raw response
        local raw = conn.send_command("PLAYER_BUFFS")
        if raw and raw ~= "NONE" and raw ~= "" then
            for segment in raw:gmatch("[^#]+") do
                local entry = { active = true }
                for k, v in segment:gmatch("([%w_]+)=([^|]+)") do
                    if k == "name" then entry.name = v
                    elseif k == "disp" then entry.display_name = v
                    elseif k == "stacks" then entry.stacks = tonumber(v) or 1
                    elseif k == "dur" then entry.elapsed = tonumber(v) or 0
                    elseif k == "maxdur" then entry.max_duration = tonumber(v) or 0
                    end
                end
                if entry.name then
                    if entry.max_duration and entry.max_duration > 0 then
                        entry.remaining = math.max(0, entry.max_duration - (entry.elapsed or 0))
                    else
                        entry.remaining = 0
                    end
                    _buffs[entry.name] = entry
                    _buff_list[#_buff_list + 1] = entry.name
                end
            end
        end
    end

    _last_refresh = core and core.time() or os.clock()
end

local function auto_refresh()
    local now = core and core.time() or os.clock()
    if now - _last_refresh >= _refresh_interval then
        bt.refresh()
    end
end

-- ══════════════════════════════════════════════════════════════
-- Query API
-- ══════════════════════════════════════════════════════════════

--- Check if a buff is active.
function bt.has(name)
    auto_refresh()
    return _buffs[name] ~= nil
end

--- Check if a debuff is active.
function bt.has_debuff(name)
    auto_refresh()
    return _debuffs[name] ~= nil
end

--- Get remaining duration of a buff (0 if permanent or not found).
function bt.remaining(name)
    auto_refresh()
    local b = _buffs[name] or _debuffs[name]
    if not b then return 0 end
    return b.remaining
end

--- Get stack count of a buff.
function bt.stacks(name)
    auto_refresh()
    local b = _buffs[name] or _debuffs[name]
    if not b then return 0 end
    return b.stacks
end

--- Check if a buff is expiring soon.
function bt.expiring(name, threshold)
    threshold = threshold or 3.0
    auto_refresh()
    local b = _buffs[name]
    if not b then return false end
    if b.max_duration <= 0 then return false end  -- permanent
    return b.remaining <= threshold
end

--- Check if a buff is permanent (no duration).
function bt.is_permanent(name)
    auto_refresh()
    local b = _buffs[name]
    if not b then return false end
    return b.max_duration <= 0
end

--- Get full buff data table.
function bt.get(name)
    auto_refresh()
    return _buffs[name] or _debuffs[name]
end

--- Get list of all active buff names.
function bt.all_names()
    auto_refresh()
    return _buff_list
end

--- Get all buff data as a table.
function bt.all()
    auto_refresh()
    return _buffs
end

--- Get all debuff data.
function bt.all_debuffs()
    auto_refresh()
    return _debuffs
end

--- Count active buffs.
function bt.count()
    auto_refresh()
    return #_buff_list
end

--- Get a set of active buff names (for event_bus integration).
function bt.active_set()
    auto_refresh()
    local set = {}
    for name, _ in pairs(_buffs) do
        set[name] = true
    end
    return set
end

--- Check if ANY of the given buffs are active.
function bt.has_any(...)
    auto_refresh()
    for _, name in ipairs({...}) do
        if _buffs[name] then return true, name end
    end
    return false
end

--- Check if ALL of the given buffs are active.
function bt.has_all(...)
    auto_refresh()
    for _, name in ipairs({...}) do
        if not _buffs[name] then return false, name end
    end
    return true
end

--- Set the auto-refresh interval.
function bt.set_refresh_interval(seconds)
    _refresh_interval = seconds
end

return bt
