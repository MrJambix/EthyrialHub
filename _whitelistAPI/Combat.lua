-- ═══════════════════════════════════════════════════════════════════════════
--  WHITELISTED ADDON API  —  COMBAT & SPELLS
--  Namespaces: core.spells.*, core.spell_book.*, core.rotation.*
--  Category:   Spell Casting, Cooldowns, Spell Data
-- ═══════════════════════════════════════════════════════════════════════════
--
--  Check cooldowns, query spell info, inspect the spell book,
--  and read rotation data. Casting functions are not available in the
--  addon API — addons may only READ spell data and display it.
--
-- ───────────────────────────────────────────────────────────────────────────

-- ┌─────────────────────────────────────────────────────────────┐
-- │  core.spells.*  —  Primary Spell API                       │
-- └─────────────────────────────────────────────────────────────┘

--- Is a spell off cooldown and ready to use?
---@param spell_name string
---@return boolean
-- core.spells.is_ready(spell_name)

--- Get remaining cooldown in seconds.
---@param spell_name string
---@return number seconds
-- core.spells.cooldown(spell_name)

--- Get raw spell info string.
---@param spell_name string
---@return string raw
-- core.spells.info(spell_name)

--- Get parsed spell info table.
---@param spell_name string
---@return table info
-- core.spells.get_info(spell_name)

--- Get total spell count.
---@return number count
-- core.spells.count()

--- Get all spells as raw string (line-separated).
---@return string raw
-- core.spells.all()

--- Get parsed list of all spells.
---@return table[] spells
-- core.spells.get_all()

--- Full spell dump with all metadata.
---@return table[] spells
-- core.spells.dump_all()

--- Get spell link string (for chat/display).
---@param spell_name string
---@return string link
-- core.spells.link(spell_name)

--- Get parsed spell link table.
---@param spell_name string
---@return table link
-- core.spells.get_link(spell_name)

-- ┌─────────────────────────────────────────────────────────────┐
-- │  core.spell_book.*  —  Extended Spell Book                 │
-- └─────────────────────────────────────────────────────────────┘

--- Get remaining cooldown of a spell.
---@param name string
---@return number seconds
-- core.spell_book.get_cooldown(name)

--- Get raw spell info string.
---@param name string
---@return string raw
-- core.spell_book.get_spell_info(name)

--- Get total spell count.
---@return number count
-- core.spell_book.get_spell_count()

--- Get all spells raw dump.
---@return string raw
-- core.spell_book.get_all_spells()

--- Get parsed full spell dump with all fields.
---@return table[] spells
-- core.spell_book.dump_all_spells()

--- Dump game flags.
---@return string raw
-- core.spell_book.dump_game_flags()

--- Scan all scene entities for their unique spells.
---@return table[] spells, number total_spells, number total_entities
-- core.spell_book.scan_all_entity_spells()

--- Dump animation list for player or target.
---@param who? string  "player" or "target" (default: player)
---@return table anim_list
-- core.spell_book.dump_anim_list(who)

-- ┌─────────────────────────────────────────────────────────────┐
-- │  core.rotation.*  —  Class Rotation Data                   │
-- └─────────────────────────────────────────────────────────────┘

--- Dump raw rotation/spell data.
-- core.rotation.dump_spells()

--- Dump class ID information.
-- core.rotation.dump_class_ids()

--- Get the player's class ID and name.
---@return number id, string name
-- core.rotation.get_class_id()

--- Get all parsed spell data entries.
---@return table[] spell_data
-- core.rotation.get_all_spell_data()
