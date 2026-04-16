-- ═══════════════════════════════════════════════════════════════════════════
--  WHITELISTED ADDON API  —  INVENTORY & LOOT
--  Namespaces: core.inventory.*, core.loot.*, core.loot_roll.*, core.item_db.*
--  Category:   Items, Equipment, Loot, Potions
-- ═══════════════════════════════════════════════════════════════════════════
--
--  Read inventory contents, equipment, loot rolls, and query the item
--  database. Action functions (equipping, using, dropping) are not available
--  in the addon API — addons may only READ item data and display it.
--
-- ───────────────────────────────────────────────────────────────────────────

-- ┌─────────────────────────────────────────────────────────────┐
-- │  core.inventory.*  —  Inventory Management                 │
-- └─────────────────────────────────────────────────────────────┘

--- Get raw inventory data.
---@return string raw
-- core.inventory.get_all()

--- Get parsed inventory item list.
---@return table[] items  { {name, uid, count, rarity, slot, ...}, ... }
-- core.inventory.get_items()

--- Get total inventory item count.
---@return number count
-- core.inventory.get_count()

--- Get equipped items (raw).
---@return string raw
-- core.inventory.equipped()

--- Get parsed equipped item list.
---@return table[] items
-- core.inventory.get_equipped()

-- ┌─────────────────────────────────────────────────────────────┐
-- │  core.loot.*  —  Recent Loot                               │
-- └─────────────────────────────────────────────────────────────┘

--- Get raw recent loot string.
---@return string raw
-- core.loot.recent()

--- Get parsed recent loot entries.
---@return table[] entries
-- core.loot.get_recent()

-- ┌─────────────────────────────────────────────────────────────┐
-- │  core.loot_roll.*  —  Loot Roll Info (Read-Only)            │
-- └─────────────────────────────────────────────────────────────┘

--- Scan pending roll windows (raw).
---@return string raw
-- core.loot_roll.scan_raw()

--- Get parsed pending roll entries.
---@return table[] rolls  { {item, timer, remaining, ptr, qptr}, ... }
-- core.loot_roll.scan()

-- NOTE: Roll action functions (choose, greed_all, need_all, pass_all)
--       are not available in the addon API. Addons can only display roll info.

-- ┌─────────────────────────────────────────────────────────────┐
-- │  core.item_db.*  —  Item Database (Read-Only)               │
-- └─────────────────────────────────────────────────────────────┘

--- Extract tier number from an item name (roman numerals, prefixes).
---@param name string
---@return number tier
-- core.item_db.get_tier(name)

--- Classify a potion type ("health", "mana", etc).
---@param name string
---@return string potion_type
-- core.item_db.get_potion_type(name)

--- Classify item: {type, tier, is_potion}.
---@param name string
---@param rarity? string
---@return table classification
-- core.item_db.classify(name, rarity)

--- Search the master item database by substring.
---@param query string
---@return table[] items
-- core.item_db.search(query)

--- Get all items from the master database (cached 30s).
---@return table[] items
-- core.item_db.get_all_master()

--- Get all potions from the master database.
---@return table[] potions
-- core.item_db.get_all_potions_master()

--- Get all potions in inventory with tier info.
---@return table[] potions
-- core.item_db.get_potions()

--- Find potions by type and optional minimum tier.
---@param ptype string  "health" | "mana" | etc.
---@param min_tier? number
---@return table[] potions
-- core.item_db.find_potion(ptype, min_tier)

--- Find the highest-tier potion of a type.
---@param ptype string
---@return table|nil potion
-- core.item_db.find_best_potion(ptype)

--- Find the lowest-tier potion of a type.
---@param ptype string
---@return table|nil potion
-- core.item_db.find_lowest_potion(ptype)

--- Find a potion at a specific tier (or closest).
---@param ptype string
---@param tier number
---@return table|nil potion
-- core.item_db.find_potion_at_tier(ptype, tier)

--- Get item mods for a specific UID.
---@param uid string
---@return table[] mods
-- core.item_db.get_mods(uid)

-- NOTE: Item use, equip, auto-potion, and drop functions are not available
--       in the addon API. Addons can only READ item data and display it.
