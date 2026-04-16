-- ═══════════════════════════════════════════════════════════════════════════
--  WHITELISTED ADDON API  —  PETS & COMPANIONS
--  Namespace: core.pets.*
--  Category:  Pet Management, Companion Data
-- ═══════════════════════════════════════════════════════════════════════════
--
--  Query companion stats, manage attack speed, and issue pet commands.
--
-- ───────────────────────────────────────────────────────────────────────────

---@class PetsAPI

--- Get active pet/companion count.
---@return number count
-- core.pets.count()

--- Get full companion info (raw).
---@return string raw
-- core.pets.companion_full()

--- Get parsed full companion data.
---@return table companion
-- core.pets.get_full()

--- Get companion list (raw).
---@return string raw
-- core.pets.companions()

--- Get parsed companion list.
---@return table companions
-- core.pets.get_companions()

--- Get pet/companion attack speed.
---@return number atk_speed
-- core.pets.atk_speed()

--- Get companion detail (raw).
---@return string raw
-- core.pets.companion_detail()

--- Get parsed companion detail list.
---@return table[] details
-- core.pets.get_companion_detail()

--- Get pet debug info.
---@return string debug
-- core.pets.debug()
