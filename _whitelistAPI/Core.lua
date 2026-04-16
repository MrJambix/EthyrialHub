-- ═══════════════════════════════════════════════════════════════════════════
--  WHITELISTED ADDON API  —  CORE & UTILITIES
--  Namespaces: core.*, core.stations.*, core.network.*, core.ui.*,
--              core.game_time.*, zone.*
--  Category:   System Functions, Logging, Profiles, Time, Zones
-- ═══════════════════════════════════════════════════════════════════════════
--
--  Core system functions, logging, profile storage, game time,
--  zone detection, and crafting station scanning.
--
-- ───────────────────────────────────────────────────────────────────────────

-- ┌─────────────────────────────────────────────────────────────┐
-- │  Core System Functions                                      │
-- └─────────────────────────────────────────────────────────────┘

--- Log a message to the console.
---@param message string
-- core.log(message)

--- Get current time in seconds (high-resolution monotonic clock).
---@return number seconds
-- core.time()

--- Check if developer mode is active.
---@return boolean
-- core.is_dev_mode()

--- Read a profile value by key.
---@param key string
---@return string|nil value
-- core.profile_read(key)

--- Write a profile value by key.
---@param key string
---@param value string
-- core.profile_write(key, value)

--- Check if the script/addon has been told to stop.
---@return boolean
-- is_stopped()

-- ┌─────────────────────────────────────────────────────────────┐
-- │  core.game_time.*  —  In-Game Clock                        │
-- └─────────────────────────────────────────────────────────────┘

--- Get raw game time string.
---@return string raw
-- core.game_time.raw()

--- Get parsed game time.
---@return table time  {hour, minute, second, multiplier}
-- core.game_time.get()

--- Get in-game hour.
---@return number hour
-- core.game_time.hour()

--- Get in-game minute.
---@return number minute
-- core.game_time.minute()

--- Get in-game second.
---@return number second
-- core.game_time.second()

--- Get time multiplier.
---@return number multiplier
-- core.game_time.multiplier()

--- Get formatted time "HH:MM".
---@return string formatted
-- core.game_time.formatted()

-- ┌─────────────────────────────────────────────────────────────┐
-- │  Zone Module  —  Map & Region Detection                    │
-- │  (require via: local zone = require("zone"))               │
-- └─────────────────────────────────────────────────────────────┘

--- Get current zone/map name.
---@return string name
-- zone.name()

--- Get current region name.
---@return string region
-- zone.region()

--- Check if in a specific zone (partial match).
---@param zone_name string
---@return boolean
-- zone.is(zone_name)

--- Check if in a specific region (partial match).
---@param region_name string
---@return boolean
-- zone.is_region(region_name)

--- Seconds spent in the current zone.
---@return number seconds
-- zone.time_in_zone()

--- Get previous zone name.
---@return string name
-- zone.previous()

--- Is the player in a PvP zone?
---@return boolean
-- zone.is_pvp()

--- Is the player in the wildlands?
---@return boolean
-- zone.is_wildlands()

--- Is the current zone safe (not PvP, not wildlands)?
---@return boolean
-- zone.is_safe()

--- Register a callback for zone changes.
---@param callback fun(old_zone: string, new_zone: string, old_region: string, new_region: string)
-- zone.on_change(callback)

--- Remove all zone change callbacks.
-- zone.clear_callbacks()

--- Register a config table for a named zone.
---@param zone_name string
---@param config table
-- zone.register_config(zone_name, config)

--- Get the config for the current zone (nil if unregistered).
---@return table|nil config
-- zone.config()

--- Get a config value with fallback default.
---@param key string
---@param default any
---@return any value
-- zone.config_value(key, default)

--- Per-frame zone detection tick. Call from on_update.
-- zone.tick()

--- Force re-read zone data.
-- zone.refresh()

--- Get zone debug info string.
---@return string debug
-- zone.debug()

-- ┌─────────────────────────────────────────────────────────────┐
-- │  core.stations.*  —  Crafting Stations                     │
-- └─────────────────────────────────────────────────────────────┘

--- Scan for nearby crafting stations (raw).
---@param filter? string
---@return string raw
-- core.stations.scan(filter)

--- Get parsed crafting station list.
---@param filter? string
---@return table[] stations
-- core.stations.get(filter)

-- NOTE: Station use/interact functions are not available in the addon API.
--       Addons can only scan and display station locations.

-- ┌─────────────────────────────────────────────────────────────┐
-- │  core.network.*  —  Network Info                           │
-- └─────────────────────────────────────────────────────────────┘

--- Get current server address.
---@return string address
-- core.network.server_address()

--- Dump network-related classes.
-- core.network.net_classes()

-- ┌─────────────────────────────────────────────────────────────┐
-- │  core.ui.*  —  Built-In UI Popups                          │
-- └─────────────────────────────────────────────────────────────┘

--- Dump current messagebox/popup state.
---@return string dump
-- core.ui.messagebox_dump()

-- NOTE: Teleport, safe mode, and messagebox click functions are not
--       available in the addon API. Addons can only READ UI/game state.

-- ┌─────────────────────────────────────────────────────────────┐
-- │  Asset Dumper  —  Game Data Queries                        │
-- └─────────────────────────────────────────────────────────────┘

--- Initialize asset dump system.
-- core._asset_init()

--- Scan/refresh asset data from DLL.
-- core._asset_scan()

--- Get asset dump stats.
---@return string stats
-- core._asset_stats()

--- List asset categories.
---@return table categories
-- core._asset_list_categories()

--- Get items in a category.
---@param category string
---@return table[] items
-- core._asset_get_items(category)

--- Search items by name substring.
---@param query string
---@return table[] items
-- core._asset_search_items(query)

--- Find a specific item by exact name.
---@param name string
---@return table|nil item
-- core._asset_find_item(name)

--- Get items by rarity.
---@param rarity string
---@return table[] items
-- core._asset_get_by_rarity(rarity)

--- List item types.
---@return table types
-- core._asset_list_types()

--- Count items by type.
---@param type_name string
---@return number count
-- core._asset_count_by_type(type_name)

--- Dump all items to file.
-- core._asset_dump_items()

--- Generate a dump report.
---@return string report
-- core._asset_dump_report()
