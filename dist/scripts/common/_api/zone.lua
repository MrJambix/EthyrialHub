--[[
╔══════════════════════════════════════════════════════════════╗
║          Zone — Map & Region Awareness                       ║
║                                                              ║
║  Detect current zone/region, trigger zone-change events,     ║
║  and load zone-specific configs automatically.              ║
║                                                              ║
║  Usage:                                                      ║
║    local zone = require("common/_api/zone")                  ║
║    print(zone.name())       -- "Darkwood Forest"             ║
║    zone.on_change(function(old, new) ... end)                ║
╚══════════════════════════════════════════════════════════════╝
]]

local zone = {}

-- Internal state
local _current_zone = ""
local _current_region = ""
local _previous_zone = ""
local _zone_enter_time = 0
local _change_callbacks = {}
local _zone_configs = {}   -- { zone_name = config_table }
local _active_config = nil

-- PvP / danger zone tracking
local _in_pvp = false
local _in_wildlands = false

local function get_time()
    if core and core.time then return core.time() end
    return os.clock()
end

-- ══════════════════════════════════════════════════════════════
-- Core Queries
-- ══════════════════════════════════════════════════════════════

--- Get current zone/map name.
function zone.name()
    return _current_zone
end

--- Get current region name.
function zone.region()
    return _current_region
end

--- Check if in a specific zone (partial match supported).
function zone.is(zone_name)
    if not zone_name or not _current_zone then return false end
    return _current_zone:lower():find(zone_name:lower()) ~= nil
end

--- Check if in a specific region.
function zone.is_region(region_name)
    if not region_name or not _current_region then return false end
    return _current_region:lower():find(region_name:lower()) ~= nil
end

--- Get time spent in current zone (seconds).
function zone.time_in_zone()
    if _zone_enter_time == 0 then return 0 end
    return get_time() - _zone_enter_time
end

--- Get previous zone name.
function zone.previous()
    return _previous_zone
end

--- Check if in a PvP / PZ zone.
function zone.is_pvp()
    return _in_pvp
end

--- Check if in wildlands.
function zone.is_wildlands()
    return _in_wildlands
end

--- Check if zone is safe (not PvP and not wildlands).
function zone.is_safe()
    return not _in_pvp and not _in_wildlands
end

-- ══════════════════════════════════════════════════════════════
-- Zone Change Callbacks
-- ══════════════════════════════════════════════════════════════

--- Register a callback for zone changes.
--- callback(old_zone, new_zone, old_region, new_region)
function zone.on_change(callback)
    _change_callbacks[#_change_callbacks + 1] = callback
end

--- Clear all zone change callbacks.
function zone.clear_callbacks()
    _change_callbacks = {}
end

-- ══════════════════════════════════════════════════════════════
-- Zone Configs — auto-load settings per zone
-- ══════════════════════════════════════════════════════════════

--- Register a config table for a specific zone.
function zone.register_config(zone_name, config)
    _zone_configs[zone_name:lower()] = config
end

--- Get the active zone config (or nil if no config for this zone).
function zone.config()
    return _active_config
end

--- Get a config value for the current zone (with fallback).
function zone.config_value(key, default)
    if _active_config and _active_config[key] ~= nil then
        return _active_config[key]
    end
    return default
end

-- ══════════════════════════════════════════════════════════════
-- Tick — call every frame
-- ══════════════════════════════════════════════════════════════

function zone.tick()
    local new_zone = ""
    local new_region = ""
    local pz = false
    local wild = false

    -- Read zone/scene name
    if conn and conn.send_command then
        -- SCENE_NAME is the Unity scene name (fast, cached by DLL)
        local scene = conn.send_command("SCENE_NAME")
        if scene and scene ~= "" and scene ~= "UNKNOWN" and not scene:find("^ERR") then
            new_zone = scene
        end

        -- PvP/wildlands flags from shared state
        if conn.in_pz_zone then pz = conn.in_pz_zone() end
        if conn.in_wildlands then wild = conn.in_wildlands() end
    end

    _in_pvp = pz
    _in_wildlands = wild

    -- Detect zone change
    if new_zone ~= "" and new_zone ~= _current_zone then
        _previous_zone = _current_zone
        local old_region = _current_region
        _current_zone = new_zone
        _current_region = new_region
        _zone_enter_time = get_time()

        -- Look up zone config
        _active_config = _zone_configs[new_zone:lower()]

        -- Fire callbacks
        for _, cb in ipairs(_change_callbacks) do
            pcall(cb, _previous_zone, new_zone, old_region, new_region)
        end
    elseif new_region ~= _current_region then
        _current_region = new_region
    end
end

--- Force refresh zone data.
function zone.refresh()
    _current_zone = ""  -- force re-read on next tick
    zone.tick()
end

--- Get debug info.
function zone.debug()
    return string.format("zone=%s region=%s prev=%s time=%.0fs pvp=%s wild=%s config=%s",
        _current_zone ~= "" and _current_zone or "(unknown)",
        _current_region ~= "" and _current_region or "(unknown)",
        _previous_zone ~= "" and _previous_zone or "(none)",
        zone.time_in_zone(),
        _in_pvp and "YES" or "no",
        _in_wildlands and "YES" or "no",
        _active_config and "loaded" or "none")
end

return zone
