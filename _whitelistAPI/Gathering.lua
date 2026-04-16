-- ═══════════════════════════════════════════════════════════════════════════
--  WHITELISTED ADDON API  —  GATHERING
--  Namespace: core.gathering.*
--  Category:  Resource Harvesting, Nodes, Skinning
-- ═══════════════════════════════════════════════════════════════════════════
--
--  Scan for resource nodes by type, detect water sources, and read
--  node data for display. Action functions (gathering, interacting) are
--  not available in the addon API.
--
-- ───────────────────────────────────────────────────────────────────────────

---@class GatheringAPI

--- Scan for nodes matching a filter (raw).
---@param filter? string
---@return string raw
-- core.gathering.node_scan(filter)

--- Scan for usable nodes matching a filter (raw).
---@param filter? string
---@return string raw
-- core.gathering.node_scan_usable(filter)

--- Get parsed node list.
---@param filter? string
---@return table[] nodes  { {name, ptr, distance, x, y, z, ...}, ... }
-- core.gathering.get_nodes(filter)

--- Get parsed usable node list.
---@param filter? string
---@return table[] nodes
-- core.gathering.get_usable_nodes(filter)

--- Scan herb nodes (raw).
---@return string raw
-- core.gathering.scan_herbs()

--- Scan tree nodes (raw).
---@return string raw
-- core.gathering.scan_trees()

--- Scan ore nodes (raw).
---@return string raw
-- core.gathering.scan_ores()

--- Scan corpse nodes (raw).
---@return string raw
-- core.gathering.scan_corpses()

--- Get parsed herb list.
---@return table[] herbs
-- core.gathering.get_herbs()

--- Get parsed tree list.
---@return table[] trees
-- core.gathering.get_trees()

--- Get parsed ore list.
---@return table[] ores
-- core.gathering.get_ores()

--- Get parsed corpse list.
---@return table[] corpses
-- core.gathering.get_corpses()

--- Detect nearby water sources.
---@return table water_info
-- core.gathering.find_water()

--- Search for water (raw string).
---@return string raw
-- core.gathering.water_search()

--- Detailed water dump.
---@return string dump
-- core.gathering.water_dump()
