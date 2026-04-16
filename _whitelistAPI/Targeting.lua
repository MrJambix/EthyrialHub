-- ═══════════════════════════════════════════════════════════════════════════
--  WHITELISTED ADDON API  —  TARGETING
--  Namespace: core.targeting.*
--  Category:  Target Selection & Inspection
-- ═══════════════════════════════════════════════════════════════════════════
--
--  Read target health, distance, type, scan for enemies, and detect
--  casting state. Action functions (targeting entities) are not available
--  in the addon API — addons may only READ target data and display it.
--
-- ───────────────────────────────────────────────────────────────────────────

---@class TargetingAPI

--- Check if a target is currently selected.
---@return boolean
-- core.targeting.has_target()

--- Get the target's current HP.
---@return number hp
-- core.targeting.target_hp()

--- Get target HP in extended format string.
---@return string hp_v2
-- core.targeting.target_hp_v2()

--- Get the target's display name.
---@return string name
-- core.targeting.target_name()

--- Get distance to current target.
---@return number distance
-- core.targeting.target_distance()

--- Get raw target info string.
---@return string raw
-- core.targeting.target_info()

--- Get raw target info v2 (extended fields).
---@return string raw
-- core.targeting.target_info_v2()

--- Get full raw target data dump.
---@return string raw
-- core.targeting.target_full()

--- Get parsed target as table (nil if no target).
---@return table|nil target  {name, hp, max_hp, distance, uid, ...}
-- core.targeting.get_target()

--- Get parsed target (v2 format with extra fields).
---@return table|nil target
-- core.targeting.get_target_v2()

--- Get friendly target info (raw).
---@return string raw
-- core.targeting.friendly_target()

--- Get parsed friendly target.
---@return table|nil friendly
-- core.targeting.get_friendly()

--- Get list of valid/legal targets (raw).
---@return string raw
-- core.targeting.legal_targets()

--- Scan for nearby enemies (raw).
---@return string raw
-- core.targeting.scan_enemies()

--- Get parsed list of nearby enemies.
---@return table[] enemies  { {name, hp, distance, uid, ptr, ...}, ... }
-- core.targeting.get_enemies()

--- Get the current target's casting info (nil if not casting).
---@return table|nil casting  {spell, duration, elapsed, ...}
-- core.targeting.target_casting()

--- Get detailed casting dump string for the target.
---@return string dump
-- core.targeting.target_casting_dump()

--- Is the current target a boss?
---@return boolean
-- core.targeting.is_target_boss()

--- Is the current target elite?
---@return boolean
-- core.targeting.is_target_elite()

--- Is the current target dead?
---@return boolean
-- core.targeting.is_target_dead()

