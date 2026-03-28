--[[
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                            ║
║   EthyrialHub — Complete Lua API Reference Library                         ║
║   ─────────────────────────────────────────────────────────────────────     ║
║                                                                            ║
║   STATUS: REFERENCE ONLY — DO NOT require() THIS FILE IN SCRIPTS          ║
║                                                                            ║
║   This file documents the ASPIRATIONAL full API surface.  Some functions   ║
║   listed here (core.network.*, core.floor.*, and various get_*() parsed    ║
║   helpers) are not yet implemented in lua_runtime.cpp and will be nil.     ║
║                                                                            ║
║   For the actual runtime API, see lua_runtime.cpp or use ethy_sdk.lua.     ║
║                                                                            ║
║   Parameters marked [opt] are optional.                                    ║
║                                                                            ║
╚══════════════════════════════════════════════════════════════════════════════╝
]]

local lib = {}

-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 1 — GLOBALS                                                   ║
-- ║  Top-level functions available without any table prefix.               ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

lib.globals = {}

--- print(...)
--- Overridden to route output to the Hub log panel instead of stdout.
--- Accepts any number of arguments; they are tostring'd and tab-separated.
--- @param ... any
--- @return nil
---
--- Example:
---   print("HP:", core.player.hp(), "MP:", core.player.mp())
---
lib.globals.print = print

--- is_stopped() -> boolean
--- Returns true when the Hub has requested this script to stop.
--- Always check this in your main loop to allow clean shutdown.
--- @return boolean
---
--- Example:
---   while not is_stopped() do
---       -- your logic
---       _ethy_sleep(0.3)
---   end
---
lib.globals.is_stopped = is_stopped

--- _ethy_sleep(seconds)
--- Pauses script execution. Clamped to [0.01, 5.0] seconds.
--- @param seconds number  — sleep duration (default 0.1)
--- @return nil
---
--- Example:
---   _ethy_sleep(0.5)  -- sleep 500ms
---
lib.globals._ethy_sleep = _ethy_sleep


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 2 — core.*  (Core Utilities)                                  ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

lib.core = {}

--- core.log(message)
--- Write a message to the Hub log panel.
--- @param message string
--- @return nil
lib.core.log = core.log

--- core.log_warning(message)
--- Write a [WARN] prefixed message to the Hub log.
--- @param message string
--- @return nil
lib.core.log_warning = core.log_warning

--- core.log_error(message)
--- Write an [ERROR] prefixed message to the Hub log.
--- @param message string
--- @return nil
lib.core.log_error = core.log_error

--- core.time() -> number
--- High-resolution monotonic clock in seconds (float).
--- @return number  — seconds since system boot
---
--- Example:
---   local start = core.time()
---   -- do work
---   print("Elapsed:", core.time() - start, "seconds")
---
lib.core.time = core.time

--- core.time_ms() -> integer
--- High-resolution monotonic clock in milliseconds (integer).
--- @return integer
lib.core.time_ms = core.time_ms

--- core.send_command(cmd) -> string
--- Send a raw IPC command to EthyTool and get the string response.
--- This is the low-level escape hatch for any command not wrapped above.
--- @param cmd string  — e.g. "PLAYER_HP", "CAST_Fireball", "TARGET_NEAREST"
--- @return string     — raw response from EthyTool
---
--- Example:
---   local hp = tonumber(core.send_command("PLAYER_HP")) or 0
---   local result = core.send_command("CAST_Fireball")
---
lib.core.send_command = core.send_command


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 3 — core.player.*  (Player Data)                             ║
-- ║                                                                        ║
-- ║  Direct pipe-based access to the local player's stats.                ║
-- ║  All functions return the current value with zero arguments.           ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

lib.core_player = {}

--- core.player.hp() -> number
--- Current health as a percentage (0–100).
lib.core_player.hp = core.player.hp

--- core.player.mp() -> number
--- Current mana as a percentage (0–100).
lib.core_player.mp = core.player.mp

--- core.player.max_hp() -> number
--- Maximum health points (raw integer).
lib.core_player.max_hp = core.player.max_hp

--- core.player.max_mp() -> number
--- Maximum mana points (raw integer).
lib.core_player.max_mp = core.player.max_mp

--- core.player.pos() -> string
--- Player position as "x,y,z" string.
--- For parsed table, use core.player.get_position().
--- @return string  — e.g. "123.45,67.89,10.00"
lib.core_player.pos = core.player.pos

--- core.player.get_position() -> table
--- Parsed player position.
--- @return table  — { x=number, y=number, z=number }
---
--- Example:
---   local pos = core.player.get_position()
---   print("At:", pos.x, pos.y, pos.z)
---
lib.core_player.get_position = core.player.get_position

--- core.player.moving() -> boolean
--- True if the player is currently moving.
lib.core_player.moving = core.player.moving

--- core.player.combat() -> boolean
--- True if the player is in combat.
lib.core_player.combat = core.player.combat

--- core.player.frozen() -> boolean
--- True if the player's controls are frozen (CC'd, loading, etc).
lib.core_player.frozen = core.player.frozen

--- core.player.job() -> string
--- Player's current class/job name (e.g. "Enchanter", "Ranger").
lib.core_player.job = core.player.job

--- core.player.gold() -> integer
--- Total gold/currency.
lib.core_player.gold = core.player.gold

--- core.player.speed() -> number
--- Current movement speed.
lib.core_player.speed = core.player.speed

--- core.player.direction() -> integer
--- Facing direction (0–359 degrees).
lib.core_player.direction = core.player.direction

--- core.player.attack_speed() -> number
--- Current attack speed value.
lib.core_player.attack_speed = core.player.attack_speed

--- core.player.infamy() -> number
--- PvP infamy points.
lib.core_player.infamy = core.player.infamy

--- core.player.food() -> number
--- Current food/satiation level.
lib.core_player.food = core.player.food

--- core.player.pz_zone() -> boolean
--- True if the player is in a protected zone.
lib.core_player.pz_zone = core.player.pz_zone

--- core.player.spectator() -> boolean
--- True if in spectator mode.
lib.core_player.spectator = core.player.spectator

--- core.player.wildlands() -> boolean
--- True if in the Wildlands (PvP zone).
lib.core_player.wildlands = core.player.wildlands

--- core.player.combat_level() -> number
--- Combat level.
lib.core_player.combat_level = core.player.combat_level

--- core.player.profession_level() -> number
--- Profession/gathering level.
lib.core_player.profession_level = core.player.profession_level

--- core.player.address() -> string
--- Player memory address (debug).
lib.core_player.address = core.player.address

--- core.player.phys_armor() -> number
--- Total physical armor.
lib.core_player.phys_armor = core.player.phys_armor

--- core.player.mag_armor() -> number
--- Total magical armor.
lib.core_player.mag_armor = core.player.mag_armor

--- core.player.all() -> string
--- Raw pipe dump of all player data. Use get_all() for parsed table.
lib.core_player.all = core.player.all

--- core.player.get_all() -> table|nil
--- Parsed player data table with keys: name, uid, hp, mp, gold, etc.
lib.core_player.get_all = core.player.get_all

--- core.player.info() -> string
--- Player info string. Use get_info() for parsed table.
lib.core_player.info = core.player.info

--- core.player.get_info() -> table|nil
--- Parsed player info table.
lib.core_player.get_info = core.player.get_info

--- core.player.movement() -> string
--- Raw movement data string. Use get_movement() for parsed table.
lib.core_player.movement = core.player.movement

--- core.player.get_movement() -> table|nil
--- Parsed movement data table.
lib.core_player.get_movement = core.player.get_movement

--- core.player.animation() -> string
--- Current animation state string.
lib.core_player.animation = core.player.animation

--- core.player.infobar() -> string
--- Player infobar data string.
lib.core_player.infobar = core.player.infobar

--- core.player.buffs() -> string
--- Raw buff list string. Use get_buffs() for parsed table.
lib.core_player.buffs = core.player.buffs

--- core.player.get_buffs() -> table
--- Parsed array of buff tables: { name, dur, stacks, ... }
lib.core_player.get_buffs = core.player.get_buffs

--- core.player.stacks([buff_id]) -> string
--- Stack count for a specific buff, or all stacks if no argument.
--- @param buff_id string|nil  [opt]
lib.core_player.stacks = core.player.stacks

--- core.player.skills() -> string
--- Raw skill list. Use get_skills() for parsed table.
lib.core_player.skills = core.player.skills

--- core.player.get_skills() -> table
--- Parsed array of skill tables.
lib.core_player.get_skills = core.player.get_skills

--- core.player.talents() -> string
--- Raw talent list. Use get_talents() for parsed table.
lib.core_player.talents = core.player.talents

--- core.player.get_talents() -> table
--- Parsed array of talent tables.
lib.core_player.get_talents = core.player.get_talents

--- core.player.skill(name) -> string
--- Get info for a specific skill by name.
--- @param name string
lib.core_player.skill = core.player.skill


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 4 — core.targeting.*  (Targeting System)                      ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

lib.core_targeting = {}

--- core.targeting.target_nearest() -> string
--- Target the nearest hostile enemy.
lib.core_targeting.target_nearest = core.targeting.target_nearest

--- core.targeting.target_nearest_filtered(filter) -> string
--- Target nearest matching a filter string.
--- @param filter string  — name substring or filter keyword
lib.core_targeting.target_nearest_filtered = core.targeting.target_nearest_filtered

--- core.targeting.target_entity(uid) -> string
--- Target a specific entity by its unique ID.
--- @param uid integer
lib.core_targeting.target_entity = core.targeting.target_entity

--- core.targeting.target_party(index) -> string
--- Target a party member by their party index.
--- @param index integer  — 0-based party slot
lib.core_targeting.target_party = core.targeting.target_party

--- core.targeting.target_friendly(uid_or_name) -> string
--- Set friendly (heal) target.
--- @param uid_or_name string|integer
lib.core_targeting.target_friendly = core.targeting.target_friendly

--- core.targeting.has_target() -> boolean
--- True if the player currently has a hostile target.
lib.core_targeting.has_target = core.targeting.has_target

--- core.targeting.target_hp() -> number
--- Current target's health percentage (0–100).
lib.core_targeting.target_hp = core.targeting.target_hp

--- core.targeting.target_hp_v2() -> string
--- Extended target HP info string.
lib.core_targeting.target_hp_v2 = core.targeting.target_hp_v2

--- core.targeting.target_name() -> string
--- Name of the current target.
lib.core_targeting.target_name = core.targeting.target_name

--- core.targeting.target_distance() -> number
--- Distance to the current target.
lib.core_targeting.target_distance = core.targeting.target_distance

--- core.targeting.target_info() -> string
--- Target info string (v2 format).
lib.core_targeting.target_info = core.targeting.target_info

--- core.targeting.target_info_v2() -> string
--- Extended target info string.
lib.core_targeting.target_info_v2 = core.targeting.target_info_v2

--- core.targeting.target_full() -> string
--- Full target dump (all fields).
lib.core_targeting.target_full = core.targeting.target_full

--- core.targeting.friendly_target() -> string
--- Info about the current friendly target.
lib.core_targeting.friendly_target = core.targeting.friendly_target

--- core.targeting.legal_targets() -> string
--- List all currently legal (attackable) targets.
lib.core_targeting.legal_targets = core.targeting.legal_targets

--- core.targeting.scan_enemies() -> string
--- Scan all enemies in range. Use get_enemies() for parsed table.
lib.core_targeting.scan_enemies = core.targeting.scan_enemies

--- core.targeting.get_enemies() -> table
--- Parsed array of enemy tables with ptr for direct targeting.
--- Fields: uid, name, ptr, hp, max_hp, distance, boss, elite, rare, critter, combat
---
--- Example:
---   for _, e in ipairs(core.targeting.get_enemies()) do
---       print(e.name, "HP:", e.hp, "Dist:", e.distance, "Ptr:", e.ptr)
---   end
---
lib.core_targeting.get_enemies = core.targeting.get_enemies

--- core.targeting.target_by_ptr(ptr) -> string
--- Set combat target to a specific entity by its pointer.
--- @param ptr string  Entity pointer from a scan result (e.g. "0x1A2B3C4D")
--- Returns: "OK_TARGETED|uid=N|name=...|ptr=0x..." or error string
---
--- Example:
---   local enemies = core.targeting.get_enemies()
---   if #enemies > 0 then
---       core.targeting.target_by_ptr(enemies[1].ptr)
---   end
---
lib.core_targeting.target_by_ptr = core.targeting.target_by_ptr

--- core.targeting.get_target() -> table|nil
--- Parsed target table from TARGET_FULL.
--- Returns: { uid, name, hp, max_hp, distance, in_combat, is_boss, ... }
lib.core_targeting.get_target = core.targeting.get_target

--- core.targeting.get_target_v2() -> table|nil
--- Parsed target table from TARGET_INFO_V2.
lib.core_targeting.get_target_v2 = core.targeting.get_target_v2

--- core.targeting.get_friendly() -> table|nil
--- Parsed friendly target table.
lib.core_targeting.get_friendly = core.targeting.get_friendly


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 5 — core.movement.*  (Movement Control)                       ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

lib.core_movement = {}

--- core.movement.move_to(x, y) -> string
--- Walk to a specific world coordinate.
--- @param x number  — world X
--- @param y number  — world Y
---
--- Example:
---   core.movement.move_to(123.5, 456.7)
---
lib.core_movement.move_to = core.movement.move_to

--- core.movement.move_to_target() -> string
--- Walk toward the current target.
lib.core_movement.move_to_target = core.movement.move_to_target

--- core.movement.stop() -> string
--- Stop all movement immediately.
lib.core_movement.stop = core.movement.stop

--- core.movement.follow_entity(uid) -> string
--- Follow a specific entity by UID.
--- @param uid integer
lib.core_movement.follow_entity = core.movement.follow_entity

--- core.movement.autorun_on() -> string
--- Enable autorun.
lib.core_movement.autorun_on = core.movement.autorun_on

--- core.movement.autorun_off() -> string
--- Disable autorun.
lib.core_movement.autorun_off = core.movement.autorun_off


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 6 — core.spells.*  (Spell Casting — Direct Pipe)             ║
-- ║                                                                        ║
-- ║  These send raw pipe commands. Fast, no C++ caching.                  ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

lib.core_spells = {}

--- core.spells.cast(spell_name) -> string
--- Cast a spell by its internal name.
--- @param spell_name string  — e.g. "Fireball", "HolyLight"
--- @return string  — "OK" on success, error otherwise
---
--- Example:
---   if core.spells.is_ready("Fireball") then
---       core.spells.cast("Fireball")
---   end
---
lib.core_spells.cast = core.spells.cast

--- core.spells.is_ready(spell_name) -> boolean
--- True if the spell is off cooldown and castable.
--- @param spell_name string
--- @return boolean
lib.core_spells.is_ready = core.spells.is_ready

--- core.spells.cooldown(spell_name) -> number
--- Remaining cooldown in seconds.
--- @param spell_name string
--- @return number
lib.core_spells.cooldown = core.spells.cooldown

--- core.spells.info(spell_name) -> string
--- Raw spell info string. Use get_info() for parsed table.
--- @param spell_name string
lib.core_spells.info = core.spells.info

--- core.spells.get_info(spell_name) -> table|nil
--- Parsed spell info table.
--- Returns: { name, category, cast_time, cooldown, mana_cost, range, ... }
--- @param spell_name string
lib.core_spells.get_info = core.spells.get_info

--- core.spells.count() -> integer
--- Total number of spells in the spell book.
lib.core_spells.count = core.spells.count

--- core.spells.all() -> string
--- Raw dump of all spells. Use get_all() for parsed table.
lib.core_spells.all = core.spells.all

--- core.spells.get_all() -> table
--- Parsed array of spell tables.
--- Each entry: { name, category, cast_time, cooldown, mana_cost, range, ... }
---
--- Example:
---   for _, spell in ipairs(core.spells.get_all()) do
---       print(spell.name, "CD:", spell.cd, "Mana:", spell.mana)
---   end
---
lib.core_spells.get_all = core.spells.get_all

--- core.spells.autocast_on(spell_name) -> string
--- Enable auto-casting for a spell.
--- @param spell_name string
lib.core_spells.autocast_on = core.spells.autocast_on

--- core.spells.autocast_off(spell_name) -> string
--- Disable auto-casting for a spell.
--- @param spell_name string
lib.core_spells.autocast_off = core.spells.autocast_off

--- core.spells.dump_all() -> string
--- Dump ALL spells from ALL entities in the scene (not just the player's class).
--- Walks every entity in EntityManager + NearbyEntities, reads their spell lists,
--- deduplicates by UniqueName, and writes a full dump to spell_dump.txt.
--- Returns pipe-formatted string: "count=N|file=spell_dump.txt###name=...|display=...|..."
--- @return string
lib.core_spells.dump_all = core.spells.dump_all


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 7 — core.spell_book.*  (SpellBook — C++ Managed)             ║
-- ║                                                                        ║
-- ║  Uses the C++ SpellBook class with caching and rich data.             ║
-- ║  Only available in DLL (plugin) mode, not Hub ScriptEngine.           ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

lib.core_spell_book = {}

--- core.spell_book.is_spell_ready(name) -> boolean
--- @param name string
--- @return boolean
lib.core_spell_book.is_spell_ready = core.spell_book.is_spell_ready

--- core.spell_book.cast_spell(name) -> boolean
--- Cast a spell. Returns true on success.
--- @param name string
--- @return boolean
lib.core_spell_book.cast_spell = core.spell_book.cast_spell

--- core.spell_book.cast_spell_ooc(name) -> boolean
--- Cast a spell even when out of combat (for buffs, mounts, etc).
--- @param name string
--- @return boolean
lib.core_spell_book.cast_spell_ooc = core.spell_book.cast_spell_ooc

--- core.spell_book.get_cooldown(name) -> number
--- Remaining cooldown in seconds.
--- @param name string
--- @return number
lib.core_spell_book.get_cooldown = core.spell_book.get_cooldown

--- core.spell_book.get_all_spells() -> table
--- Array of SpellData tables with full metadata:
---   { name, category, cast_time, cooldown, mana_cost, range,
---     channel_time, duration, targets_self, is_ground_targeted,
---     is_instant, is_channeled, has_cooldown,
---     generates_stacks, consumes_stacks, required_stacks, stack_id }
lib.core_spell_book.get_all_spells = core.spell_book.get_all_spells

--- core.spell_book.get_spell_info(name) -> table|nil
--- Full SpellData table for a single spell.
--- @param name string
--- @return table|nil
lib.core_spell_book.get_spell_info = core.spell_book.get_spell_info

--- core.spell_book.get_spell_count() -> integer
lib.core_spell_book.get_spell_count = core.spell_book.get_spell_count

--- core.spell_book.update()
--- Force a refresh of the spell book cache from game memory.
lib.core_spell_book.update = core.spell_book.update


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 8 — core.buff_manager.*  (Buff/Debuff Tracking)              ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

lib.core_buff_manager = {}

--- core.buff_manager.has_buff(name) -> boolean
--- Check if a buff/debuff is currently active by name.
--- @param name string  — internal or display name
--- @return boolean
---
--- Example:
---   if core.buff_manager.has_buff("Fury") then
---       print("Fury is active!")
---   end
---
lib.core_buff_manager.has_buff = core.buff_manager.has_buff

--- core.buff_manager.get_stacks(name) -> integer
--- Get the stack count of a buff.
--- @param name string
--- @return integer
lib.core_buff_manager.get_stacks = core.buff_manager.get_stacks

--- core.buff_manager.get_buff_data(name) -> table
--- Detailed buff query result.
--- @param name string
--- @return table  — { is_active=bool, remaining=number, stacks=int }
---
--- Example:
---   local fury = core.buff_manager.get_buff_data("Fury")
---   if fury.is_active and fury.stacks >= 5 then
---       core.spells.cast("RagingBlow")
---   end
---
lib.core_buff_manager.get_buff_data = core.buff_manager.get_buff_data

--- core.buff_manager.get_all_buffs() -> table
--- Array of all active buff tables:
---   { name, display_name, id, type, stacks, elapsed, max_duration,
---     remaining, is_debuff, is_permanent }
lib.core_buff_manager.get_all_buffs = core.buff_manager.get_all_buffs

--- core.buff_manager.get_fury_stacks() -> integer
--- Shortcut for Fury stack count (Berserker).
lib.core_buff_manager.get_fury_stacks = core.buff_manager.get_fury_stacks

--- core.buff_manager.get_spirit_link_stacks() -> integer
--- Shortcut for Spirit Link stack count (Druid).
lib.core_buff_manager.get_spirit_link_stacks = core.buff_manager.get_spirit_link_stacks

--- core.buff_manager.invalidate()
--- Clear the buff cache so next read fetches fresh data.
lib.core_buff_manager.invalidate = core.buff_manager.invalidate

--- core.buff_manager.update()
--- Force-refresh the buff cache from game memory.
lib.core_buff_manager.update = core.buff_manager.update


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 9 — core.object_manager.*  (Entity Management)               ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

lib.core_object_manager = {}

--- core.object_manager.get_local_player() -> GameObject
--- Returns the local player as a GameObject userdata (DLL) or proxy table (Hub).
--- See SECTION 20 for all GameObject methods.
---
--- Example:
---   local me = core.object_manager.get_local_player()
---   print("HP:", me:get_hp(), "Name:", me:get_name())
---
lib.core_object_manager.get_local_player = core.object_manager.get_local_player

--- core.object_manager.get_target() -> EntityInfo|nil
--- Returns the current target as an EntityInfo table, or nil.
--- Fields: { uid, name, type, classification, hp, max_hp, distance,
---           in_combat, is_dead, is_moving, health_percent,
---           position={x,y,z}, is_boss, is_elite, is_rare, is_critter }
lib.core_object_manager.get_target = core.object_manager.get_target

--- core.object_manager.get_nearby_enemies([range]) -> table
--- Array of EntityInfo tables for hostile entities within range.
--- @param range number  [opt] — default 50.0
--- @return table
lib.core_object_manager.get_nearby_enemies = core.object_manager.get_nearby_enemies

--- core.object_manager.get_nearby_all() -> table
--- Array of EntityInfo tables for ALL nearby entities.
lib.core_object_manager.get_nearby_all = core.object_manager.get_nearby_all

--- core.object_manager.get_party_members() -> table
--- Array of EntityInfo tables for party members.
lib.core_object_manager.get_party_members = core.object_manager.get_party_members

--- core.object_manager.get_entity_by_uid(uid) -> EntityInfo|nil
--- Look up any entity by its unique ID.
--- @param uid integer
lib.core_object_manager.get_entity_by_uid = core.object_manager.get_entity_by_uid

--- core.object_manager.get_nearby_count() -> integer
--- Number of nearby entities.
lib.core_object_manager.get_nearby_count = core.object_manager.get_nearby_count

--- core.object_manager.get_party_count() -> integer
--- Number of party members.
lib.core_object_manager.get_party_count = core.object_manager.get_party_count

--- core.object_manager.update()
--- Force-refresh the object manager cache.
lib.core_object_manager.update = core.object_manager.update


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 10 — core.inventory.*  (Inventory & Equipment)               ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

lib.core_inventory = {}

--- core.inventory.get_all() -> string
--- Raw inventory dump. Use get_items() for parsed table.
lib.core_inventory.get_all = core.inventory.get_all

--- core.inventory.get_items() -> table
--- Parsed array of item tables.
--- Each: { uid, name, stack, rarity, equipped_slot, ... }
---
--- Example:
---   for _, item in ipairs(core.inventory.get_items()) do
---       print(item.name, "x" .. (item.stack or 1))
---   end
---
lib.core_inventory.get_items = core.inventory.get_items

--- core.inventory.get_count() -> integer
--- Total number of inventory items.
lib.core_inventory.get_count = core.inventory.get_count

--- core.inventory.equipped() -> string
--- Raw equipment dump. Use get_equipped() for parsed table.
lib.core_inventory.equipped = core.inventory.equipped

--- core.inventory.get_equipped() -> table
--- Parsed array of equipped item tables.
lib.core_inventory.get_equipped = core.inventory.get_equipped

--- core.inventory.use_item(uid) -> string
--- Use an item by its UID.
--- @param uid integer
lib.core_inventory.use_item = core.inventory.use_item

--- core.inventory.equip_item(uid) -> string
--- Equip an item by its UID.
--- @param uid integer
lib.core_inventory.equip_item = core.inventory.equip_item

--- core.inventory.unequip_slot(slot) -> string
--- Unequip an item from a specific equipment slot.
--- @param slot integer
lib.core_inventory.unequip_slot = core.inventory.unequip_slot

--- core.inventory.loot_all() -> string
--- Loot everything from the current loot window.
lib.core_inventory.loot_all = core.inventory.loot_all

--- core.inventory.loot_window_count() -> integer
--- Number of items in the current loot window.
lib.core_inventory.loot_window_count = core.inventory.loot_window_count

--- core.inventory.open_containers() -> string
--- Open all containers in inventory.
lib.core_inventory.open_containers = core.inventory.open_containers

--- core.inventory.open_containers_count() -> integer
--- Number of unopened containers.
lib.core_inventory.open_containers_count = core.inventory.open_containers_count


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 11 — core.gathering.*  (Resource Gathering)                   ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

lib.core_gathering = {}

--- core.gathering.gather_nearest([filter]) -> string
--- Interact with the nearest gathering node.
--- @param filter string|nil  [opt] — e.g. "HERB", "TREE", "ORE", "SKIN"
lib.core_gathering.gather_nearest = core.gathering.gather_nearest

--- core.gathering.gather_by_ptr(ptr) -> string
--- Interact with a specific gathering node by its pointer.
--- @param ptr string  Node pointer from a scan result (e.g. "0x1A2B3C4D")
--- Returns: "OK_USED|class=...|name=...|ptr=0x...|invoke=0" or error
---
--- Example:
---   local ores = core.gathering.get_ores()
---   for _, node in ipairs(ores) do
---       if node.name:find("Iron") and node.usable == 1 then
---           core.gathering.gather_by_ptr(node.ptr)
---           break
---       end
---   end
---
lib.core_gathering.gather_by_ptr = core.gathering.gather_by_ptr

--- core.gathering.node_scan([filter]) -> string
--- Scan for gathering nodes in the scene.
--- @param filter string|nil  [opt]
lib.core_gathering.node_scan = core.gathering.node_scan

--- core.gathering.node_scan_usable([filter]) -> string
--- Scan for usable (not depleted) gathering nodes.
--- @param filter string|nil  [opt]
lib.core_gathering.node_scan_usable = core.gathering.node_scan_usable

--- core.gathering.scan_herbs() -> string
--- Scan for herb nodes. Use get_herbs() for parsed table.
lib.core_gathering.scan_herbs = core.gathering.scan_herbs

--- core.gathering.get_herbs() -> table
--- Parsed array of herb node tables.
lib.core_gathering.get_herbs = core.gathering.get_herbs

--- core.gathering.scan_trees() -> string
--- Scan for tree nodes. Use get_trees() for parsed table.
lib.core_gathering.scan_trees = core.gathering.scan_trees

--- core.gathering.get_trees() -> table
--- Parsed array of tree node tables.
lib.core_gathering.get_trees = core.gathering.get_trees

--- core.gathering.scan_ores() -> string
--- Scan for ore nodes. Use get_ores() for parsed table.
lib.core_gathering.scan_ores = core.gathering.scan_ores

--- core.gathering.get_ores() -> table
--- Parsed array of ore node tables.
lib.core_gathering.get_ores = core.gathering.get_ores

--- core.gathering.scan_skins() -> string
--- Scan for skinning nodes. Use get_skins() for parsed table.
lib.core_gathering.scan_skins = core.gathering.scan_skins

--- core.gathering.get_skins() -> table
--- Parsed array of skinning node tables.
lib.core_gathering.get_skins = core.gathering.get_skins

--- core.gathering.fishing_spots() -> string
--- Scan for fishing spots. Use get_fishing() for parsed table.
lib.core_gathering.fishing_spots = core.gathering.fishing_spots

--- core.gathering.get_fishing() -> table
--- Parsed array of fishing spot tables.
lib.core_gathering.get_fishing = core.gathering.get_fishing

--- core.gathering.use_entity(filter) -> string
--- Interact with an entity by filter string (name/type).
--- @param filter string
lib.core_gathering.use_entity = core.gathering.use_entity


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 12 — core.camera.*  (Camera Control)                         ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

lib.core_camera = {}

--- core.camera.get() -> string
--- Raw camera data string. Use get_parsed() for table.
lib.core_camera.get = core.camera.get

--- core.camera.get_parsed() -> table|nil
--- Parsed camera state.
--- @return table  — { x, y, z, distance, angle, pitch }
lib.core_camera.get_parsed = core.camera.get_parsed

--- core.camera.distance() -> number
--- Camera distance from the player.
lib.core_camera.distance = core.camera.distance

--- core.camera.angle() -> number
--- Camera horizontal angle (yaw).
lib.core_camera.angle = core.camera.angle

--- core.camera.pitch() -> number
--- Camera vertical angle (pitch).
lib.core_camera.pitch = core.camera.pitch


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 13 — core.social.*  (Chat, Party, Social)                    ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

lib.core_social = {}

--- core.social.chat_send(message) -> string
--- Send a chat message in game.
--- @param message string
lib.core_social.chat_send = core.social.chat_send

--- core.social.party_count() -> integer
--- Number of players in the party.
lib.core_social.party_count = core.social.party_count

--- core.social.party_scan() -> string
--- Raw party member scan string.
lib.core_social.party_scan = core.social.party_scan

--- core.social.party_all() -> string
--- Full party data string. Use get_party() for parsed table.
lib.core_social.party_all = core.social.party_all

--- core.social.get_party() -> table
--- Parsed array of party member tables.
lib.core_social.get_party = core.social.get_party

--- core.social.nearby_players() -> string
--- List nearby player characters.
lib.core_social.nearby_players = core.social.nearby_players

--- core.social.inbox_new() -> string
--- Check for new inbox messages.
lib.core_social.inbox_new = core.social.inbox_new


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 14 — core.world.*  (World / Scene Data)                      ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

lib.core_world = {}

--- core.world.scan_scene() -> string
--- Scan all entities in the scene. Use get_scene() for parsed table.
lib.core_world.scan_scene = core.world.scan_scene

--- core.world.get_scene() -> table
--- Parsed array of all scene entity tables.
lib.core_world.get_scene = core.world.get_scene

--- core.world.scan_nearby() -> string
--- Scan nearby entities. Use get_nearby() for parsed table.
lib.core_world.scan_nearby = core.world.scan_nearby

--- core.world.get_nearby() -> table
--- Parsed array of nearby entity tables.
lib.core_world.get_nearby = core.world.get_nearby

--- core.world.active_quests() -> string
--- List of active quest data.
lib.core_world.active_quests = core.world.active_quests

--- core.world.nearby_count() -> integer
--- Total entities nearby.
lib.core_world.nearby_count = core.world.nearby_count

--- core.world.scene_count() -> integer
--- Total entities in the scene.
lib.core_world.scene_count = core.world.scene_count

--- core.world.scene_corpses() -> string
--- List of corpses in the scene (for looting).
lib.core_world.scene_corpses = core.world.scene_corpses

--- core.world.entity_by_uid(uid) -> string
--- Look up an entity by UID (raw string).
--- @param uid integer
lib.core_world.entity_by_uid = core.world.entity_by_uid

--- core.world.companions() -> string
--- List of companion/pet entities.
lib.core_world.companions = core.world.companions

--- core.world.exit_game() -> string
--- Trigger a clean game exit.
lib.core_world.exit_game = core.world.exit_game

--- core.world.monsterdex_scan() -> string
--- Full monsterdex scan of all known monsters.
lib.core_world.monsterdex_scan = core.world.monsterdex_scan

--- core.world.monsterdex_nearby() -> string
--- Monsterdex data for nearby monsters. Use get_monsterdex_nearby() for parsed.
lib.core_world.monsterdex_nearby = core.world.monsterdex_nearby

--- core.world.get_monsterdex_nearby() -> table
--- Parsed array of nearby monsterdex entries.
lib.core_world.get_monsterdex_nearby = core.world.get_monsterdex_nearby

--- core.world.monsterdex_target() -> string
--- Monsterdex data for current target. Use get_monsterdex_target() for parsed.
lib.core_world.monsterdex_target = core.world.monsterdex_target

--- core.world.get_monsterdex_target() -> table|nil
--- Parsed monsterdex entry for the current target.
lib.core_world.get_monsterdex_target = core.world.get_monsterdex_target

--- core.world.monsterdex_by_uid(uid) -> string
--- Monsterdex data for a specific entity.
--- @param uid integer
lib.core_world.monsterdex_by_uid = core.world.monsterdex_by_uid

--- core.world.monsterdex_spells(uid) -> string
--- Known spells/abilities of a monsterdex entity.
--- @param uid integer
lib.core_world.monsterdex_spells = core.world.monsterdex_spells


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 15 — core.pets.*  (Companions / Pets)                         ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

lib.core_pets = {}

--- core.pets.count() -> integer
--- Number of active pets/companions.
lib.core_pets.count = core.pets.count

--- core.pets.companion_full() -> string
--- Full companion data. Use get_full() for parsed table.
lib.core_pets.companion_full = core.pets.companion_full

--- core.pets.get_full() -> table|nil
--- Parsed companion data table.
lib.core_pets.get_full = core.pets.get_full

--- core.pets.companions() -> string
--- List of companions. Use get_companions() for parsed table.
lib.core_pets.companions = core.pets.companions

--- core.pets.get_companions() -> table|nil
--- Parsed companion list.
lib.core_pets.get_companions = core.pets.get_companions

--- core.pets.atk_speed() -> string
--- Current pet attack speed.
lib.core_pets.atk_speed = core.pets.atk_speed

--- core.pets.set_atk_speed(value) -> string
--- Override pet attack speed.
--- @param value number
lib.core_pets.set_atk_speed = core.pets.set_atk_speed

--- core.pets.debug() -> string
--- Debug dump of pet state.
lib.core_pets.debug = core.pets.debug


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 16 — core.entities.*  (Entity Scanning — Direct Pipe)         ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

lib.core_entities = {}

--- core.entities.nearby_all() -> string
--- All nearby entities (raw string).
lib.core_entities.nearby_all = core.entities.nearby_all

--- core.entities.nearby_living() -> string
--- Nearby living (non-dead) entities.
lib.core_entities.nearby_living = core.entities.nearby_living

--- core.entities.scene_all() -> string
--- All entities in the scene.
lib.core_entities.scene_all = core.entities.scene_all

--- core.entities.scene_scan([filter]) -> string
--- Scan scene entities with optional filter.
--- @param filter string|nil  [opt]
lib.core_entities.scene_scan = core.entities.scene_scan

--- core.entities.entity_under_mouse() -> string
--- Get the entity currently under the mouse cursor.
lib.core_entities.entity_under_mouse = core.entities.entity_under_mouse

--- core.entities.debug_find(substring) -> string
--- Search entities by name substring (debug tool).
--- @param substring string
lib.core_entities.debug_find = core.entities.debug_find

--- core.entities.buff_stacks(buff_name) -> string
--- Get buff stack count by name (raw pipe).
--- @param buff_name string
lib.core_entities.buff_stacks = core.entities.buff_stacks

--- core.entities.use_by_ptr(ptr) -> string
--- Interact with any entity by its raw pointer (validated against live entities).
--- @param ptr string  Entity pointer from scan results (e.g. "0x1A2B3C4D")
--- Returns: "OK_USED|class=...|name=...|ptr=0x...|invoke=0" or error
--- Errors: "STALE_PTR" if entity no longer exists, "NULL_PTR", "BAD_PTR"
lib.core_entities.use_by_ptr = core.entities.use_by_ptr

--- core.entities.target_by_ptr(ptr) -> string
--- Set combat target to any entity by its raw pointer.
--- @param ptr string  Entity pointer from scan results
--- Returns: "OK_TARGETED|uid=N|name=...|ptr=0x..." or error
lib.core_entities.target_by_ptr = core.entities.target_by_ptr


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 17 — core.debug.*  (IL2CPP Reflection & Debug Tools)          ║
-- ║                                                                        ║
-- ║  Advanced tools for reading/writing game memory, inspecting classes,   ║
-- ║  invoking methods, and dumping game internals. Use with care!          ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

lib.core_debug = {}

--- core.debug.invoke_method(args) -> string
--- Invoke an IL2CPP method by name.
--- @param args string  — "ClassName.MethodName [arg1] [arg2] ..."
lib.core_debug.invoke_method = core.debug.invoke_method

--- core.debug.read_field(args) -> string
--- Read a field from a game object.
--- @param args string  — "pointer offset type"
lib.core_debug.read_field = core.debug.read_field

--- core.debug.write_field(args) -> string
--- Write a value to a game object field.
--- @param args string  — "pointer offset type value"
lib.core_debug.write_field = core.debug.write_field

--- core.debug.get_ptr(name) -> string
--- Resolve a named pointer (singleton, manager, etc).
--- @param name string
lib.core_debug.get_ptr = core.debug.get_ptr

--- core.debug.read_at(args) -> string
--- Read memory at a specific address.
--- @param args string  — "address type"
lib.core_debug.read_at = core.debug.read_at

--- core.debug.write_at(args) -> string
--- Write memory at a specific address.
--- @param args string  — "address type value"
lib.core_debug.write_at = core.debug.write_at

--- core.debug.batch_read(args) -> string
--- Read multiple memory locations in one call.
--- @param args string
lib.core_debug.batch_read = core.debug.batch_read

--- core.debug.chain_read(args) -> string
--- Follow a chain of pointer offsets (pointer->offset->offset...).
--- @param args string
lib.core_debug.chain_read = core.debug.chain_read

--- core.debug.resolve_class(name) -> string
--- Get the IL2CPP class pointer for a class name.
--- @param name string  — e.g. "PlayerController", "SpellManager"
lib.core_debug.resolve_class = core.debug.resolve_class

--- core.debug.dump_class(name) -> string
--- Full dump of a class (fields + methods + parent info).
--- @param name string
lib.core_debug.dump_class = core.debug.dump_class

--- core.debug.dump_fields([class]) -> string
--- Dump all fields of a class. No arg = dump all known fields.
--- @param class string|nil  [opt]
lib.core_debug.dump_fields = core.debug.dump_fields

--- core.debug.dump_methods(class) -> string
--- Dump all methods of a class.
--- @param class string
lib.core_debug.dump_methods = core.debug.dump_methods

--- core.debug.dump_offsets() -> string
--- Dump all known offset values.
lib.core_debug.dump_offsets = core.debug.dump_offsets

--- core.debug.dump_assemblies() -> string
--- List all loaded IL2CPP assemblies.
lib.core_debug.dump_assemblies = core.debug.dump_assemblies

--- core.debug.dump_singletons() -> string
--- List all known singleton instances.
lib.core_debug.dump_singletons = core.debug.dump_singletons

--- core.debug.dump_image_classes(assembly) -> string
--- List all classes in a specific assembly/image.
--- @param assembly string
lib.core_debug.dump_image_classes = core.debug.dump_image_classes

--- core.debug.dump_all_hooks() -> string
--- List all active function hooks.
lib.core_debug.dump_all_hooks = core.debug.dump_all_hooks

--- core.debug.dump_all_hooks_page(page) -> string
--- Paginated hook dump.
--- @param page integer
lib.core_debug.dump_all_hooks_page = core.debug.dump_all_hooks_page

--- core.debug.cache_all_classes() -> string
--- Build the class cache (speeds up future lookups).
lib.core_debug.cache_all_classes = core.debug.cache_all_classes

--- core.debug.cache_size() -> integer
--- Number of cached class entries.
lib.core_debug.cache_size = core.debug.cache_size

--- core.debug.list_cached_classes([filter]) -> string
--- List cached classes, optionally filtered.
--- @param filter string|nil  [opt]
lib.core_debug.list_cached_classes = core.debug.list_cached_classes

--- core.debug.offset_dump() -> string
--- Alternative offset dump format.
lib.core_debug.offset_dump = core.debug.offset_dump

--- core.debug.scene_find(name) -> string
--- Find a scene object by name.
--- @param name string
lib.core_debug.scene_find = core.debug.scene_find

--- core.debug.scene_dump([depth]) -> string
--- Dump the scene hierarchy.
--- @param depth integer|nil  [opt] — recursion depth
lib.core_debug.scene_dump = core.debug.scene_dump


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 18 — core.menu.*  (ImGui Menu Widgets)                        ║
-- ║                                                                        ║
-- ║  Create persistent UI elements in the script settings panel.           ║
-- ║  Each element is identified by a unique string ID.                     ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

lib.core_menu = {}

--- core.menu.checkbox(id, label, default) -> boolean
--- Create or read a checkbox. Returns current state.
--- @param id      string   — unique element ID
--- @param label   string   — display label
--- @param default boolean  — initial value
--- @return boolean
---
--- Example:
---   local auto_loot = core.menu.checkbox("my_loot", "Auto Loot", true)
---   if auto_loot then core.inventory.loot_all() end
---
lib.core_menu.checkbox = core.menu.checkbox

--- core.menu.slider_int(id, label, default, min, max) -> integer
--- Create or read an integer slider. Returns current value.
--- @param id      string
--- @param label   string
--- @param default integer  [opt] — default 0
--- @param min     integer  [opt] — default 0
--- @param max     integer  [opt] — default 100
--- @return integer
lib.core_menu.slider_int = core.menu.slider_int

--- core.menu.slider_float(id, label, default, min, max) -> number
--- Create or read a float slider. Returns current value.
--- @param id      string
--- @param label   string
--- @param default number  [opt] — default 0.0
--- @param min     number  [opt] — default 0.0
--- @param max     number  [opt] — default 1.0
--- @return number
lib.core_menu.slider_float = core.menu.slider_float

--- core.menu.combobox(id, label, options, default_idx) -> integer
--- Create or read a dropdown/combobox. Returns selected index.
--- @param id          string
--- @param label       string
--- @param options     table   — array of string options
--- @param default_idx integer [opt] — default 0
--- @return integer
---
--- Example:
---   local mode = core.menu.combobox("mode", "Mode", {"Grind","Gather","Idle"}, 0)
---   if mode == 0 then grind() elseif mode == 1 then gather() end
---
lib.core_menu.combobox = core.menu.combobox

--- core.menu.tree_node(id, label) -> boolean
--- Collapsible tree section. Returns true if expanded.
--- @param id    string
--- @param label string
--- @return boolean
lib.core_menu.tree_node = core.menu.tree_node

--- core.menu.button(id, label) -> boolean
--- Clickable button. Returns true on the frame it was clicked.
--- @param id    string
--- @param label string
--- @return boolean
lib.core_menu.button = core.menu.button

--- core.menu.get_checkbox(id) -> boolean
--- Read a checkbox state without creating it.
--- @param id string
--- @return boolean
lib.core_menu.get_checkbox = core.menu.get_checkbox

--- core.menu.set_checkbox(id, value)
--- Programmatically set a checkbox state.
--- @param id    string
--- @param value boolean
lib.core_menu.set_checkbox = core.menu.set_checkbox


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 19 — core.graphics.*  (Overlay Drawing — 2D & 3D)            ║
-- ║                                                                        ║
-- ║  Draw overlays on screen (2D) or in game world (3D).                  ║
-- ║  Only works inside on_render callbacks.                                ║
-- ║  Colors are hex integers: 0xRRGGBB (e.g. 0xFF0000 = red).            ║
-- ║                                                                        ║
-- ║  3D drawing requires calling set_camera() first each frame to set     ║
-- ║  up the projection matrix. Camera data comes from                     ║
-- ║  core.camera.get_parsed() — see the projection model below.          ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

lib.core_graphics = {}

-- ── Utilities ────────────────────────────────────────────────────────────────

--- core.graphics.color(r, g, b [, a]) -> integer
--- Build a color integer from RGBA components (0–255).
--- @param r integer  Red (0–255)
--- @param g integer  Green (0–255)
--- @param b integer  Blue (0–255)
--- @param a integer  [opt] Alpha (0–255), default 255
--- @return integer   — packed color value for draw calls
lib.core_graphics.color = core.graphics.color

--- core.graphics.screen_size() -> number, number
--- Returns the current screen/window dimensions.
--- @return number  width
--- @return number  height
---
--- Example:
---   local w, h = core.graphics.screen_size()
---   core.graphics.text_2d(w/2, h/2, "Center!", 0xFFFFFF)
---
lib.core_graphics.screen_size = core.graphics.screen_size

-- ── Camera / 3D Projection ──────────────────────────────────────────────────
--
-- Ethyrial uses a third-person camera that orbits the player.
-- The projection model:
--   cam_pos  = player_pos + spherical(distance, angle, pitch)
--   forward  = normalize(player_pos - cam_pos)
--   right    = normalize(cross(world_up, forward))
--   up_real  = cross(forward, right)
--
-- You must call set_camera() at the start of each on_render frame
-- before any 3D draw calls or world_to_screen conversions.

--- core.graphics.set_camera(camX, camY, camZ, lookX, lookY, lookZ [, fov])
--- Set up the 3D projection matrix for world_to_screen and 3D drawing.
--- Camera position is where the camera IS; look position is where it LOOKS.
--- @param camX   number  — camera world X
--- @param camY   number  — camera world Y
--- @param camZ   number  — camera world Z
--- @param lookX  number  — look-at world X (usually player X)
--- @param lookY  number  — look-at world Y (usually player Y)
--- @param lookZ  number  — look-at world Z (usually player Z)
--- @param fov    number  [opt] — field of view in degrees, default 60
---
--- Example:
---   local cam = core.camera.get_parsed()
---   local pos = core.player.get_position()
---   core.graphics.set_camera(cam.x, cam.y, cam.z, pos.x, pos.y, pos.z)
---
lib.core_graphics.set_camera = core.graphics.set_camera

--- core.graphics.world_to_screen(wx, wy, wz) -> sx, sy | nil
--- Project a 3D world position to 2D screen coordinates.
--- Returns nil if the point is behind the camera.
--- Requires set_camera() to be called first.
--- @param wx number  — world X
--- @param wy number  — world Y
--- @param wz number  — world Z
--- @return number|nil  screen X
--- @return number|nil  screen Y
---
--- Example:
---   local sx, sy = core.graphics.world_to_screen(100, 5, 200)
---   if sx then
---       core.graphics.text_2d(sx, sy, "Marker!", 0xFF0000)
---   end
---
lib.core_graphics.world_to_screen = core.graphics.world_to_screen

-- ── 2D Primitives (screen pixel coordinates) ────────────────────────────────

--- core.graphics.text_2d(x, y, text, [color])
--- Draw text at a screen position.
--- @param x     number   — screen X
--- @param y     number   — screen Y
--- @param text  string
--- @param color integer  [opt] — hex color, default white (0xFFFFFF)
---
--- Example:
---   core.register_on_render_callback(function()
---       core.graphics.text_2d(10, 10, "HP: " .. core.player.hp(), 0x00FF00)
---   end)
---
lib.core_graphics.text_2d = core.graphics.text_2d

--- core.graphics.line_2d(x1, y1, x2, y2, [color], [thickness])
--- Draw a line between two screen points.
--- @param x1, y1     number  — start point
--- @param x2, y2     number  — end point
--- @param color       integer [opt] — hex color
--- @param thickness   number  [opt] — default 1.0
lib.core_graphics.line_2d = core.graphics.line_2d

--- core.graphics.rect_2d(x, y, w, h, [color], [filled])
--- Draw a rectangle.
--- @param x, y    number   — top-left corner
--- @param w, h    number   — width, height
--- @param color   integer  [opt] — hex color
--- @param filled  boolean  [opt] — true for filled, false for outline
lib.core_graphics.rect_2d = core.graphics.rect_2d

--- core.graphics.circle_2d(cx, cy, radius, [color], [filled])
--- Draw a circle.
--- @param cx, cy  number   — center
--- @param radius  number
--- @param color   integer  [opt] — hex color
--- @param filled  boolean  [opt] — true for filled
lib.core_graphics.circle_2d = core.graphics.circle_2d

-- ── 3D Primitives (world coordinates, auto-projected via set_camera) ────────
--
-- These draw in the game world. Coordinates are world-space (same as
-- player.get_position()). The projection is handled automatically
-- using the camera set by set_camera().

--- core.graphics.text_3d(wx, wy, wz, text, [color])
--- Draw text at a 3D world position (auto-projected to screen).
--- @param wx    number   — world X
--- @param wy    number   — world Y
--- @param wz    number   — world Z
--- @param text  string
--- @param color integer  [opt] — hex color, default white
---
--- Example:
---   -- Label an enemy's position in the world
---   core.graphics.text_3d(enemy.x, enemy.y + 2, enemy.z, enemy.name, 0xFF4444)
---
lib.core_graphics.text_3d = core.graphics.text_3d

--- core.graphics.line_3d(x1, y1, z1, x2, y2, z2, [color], [thickness])
--- Draw a line between two 3D world points.
--- @param x1, y1, z1  number  — start point (world coords)
--- @param x2, y2, z2  number  — end point (world coords)
--- @param color        integer [opt] — hex color
--- @param thickness    number  [opt] — default 1.0
---
--- Example:
---   -- Draw a line from player to target
---   local pos = core.player.get_position()
---   local tgt = target_pos
---   core.graphics.line_3d(pos.x, pos.y, pos.z, tgt.x, tgt.y, tgt.z, 0xFF0000, 2)
---
lib.core_graphics.line_3d = core.graphics.line_3d

--- core.graphics.circle_3d(wx, wy, wz, radius, [color], [segments], [thickness])
--- Draw a circle on the XZ plane at a 3D world position.
--- The circle lies flat on the ground (horizontal, Y is constant).
--- @param wx, wy, wz  number  — center world position
--- @param radius       number  — radius in world units
--- @param color        integer [opt] — hex color
--- @param segments     integer [opt] — number of line segments (default 24)
--- @param thickness    number  [opt] — line thickness, default 1.0
---
--- Example:
---   -- Draw a 5-unit radius circle at the player's feet
---   local pos = core.player.get_position()
---   core.graphics.circle_3d(pos.x, pos.y, pos.z, 5.0, 0x00FF00, 32, 2.0)
---
lib.core_graphics.circle_3d = core.graphics.circle_3d


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 19b — core.draw.*  (In-Game Drawing — Unity Objects)          ║
-- ║                                                                        ║
-- ║  Creates actual Unity GameObjects in the game world.                   ║
-- ║  LineRenderer-based (line, circle) and MeshRenderer-based (ground_*).  ║
-- ║  Ground telegraphs produce filled, semi-transparent shapes on the      ║
-- ║  ground — the same style as boss AoE indicators and entity rings.      ║
-- ║                                                                        ║
-- ║  Coordinates are Unity world space. Call from on_update (not render).  ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

lib.core_draw = {}

--- core.draw.ground_init() -> boolean
--- Initialize the ground telegraph system.  Called automatically on first use.
--- @return boolean  — true if the system initialized successfully
lib.core_draw.ground_init = core.draw.ground_init

--- core.draw.ground_status() -> string
--- Returns a diagnostic string with internal state for debugging.
lib.core_draw.ground_status = core.draw.ground_status

--- core.draw.ground_circle(slot, cx, cy, cz, radius, [r], [g], [b], [a], [segments])
--- Draw a filled circle flat on the ground at the given world position.
--- Produces a solid disc like the Spirit Wolf's selection ring.
--- @param slot     integer  — slot index (0–31), reuse a slot to move/update it
--- @param cx       number   — world X
--- @param cy       number   — world Y (Unity Y = vertical)
--- @param cz       number   — world Z
--- @param radius   number   — circle radius in world units
--- @param r        number   — [opt] red   (0–1), default 0
--- @param g        number   — [opt] green (0–1), default 1
--- @param b        number   — [opt] blue  (0–1), default 1
--- @param a        number   — [opt] alpha (0–1), default 0.4
--- @param segments integer  — [opt] mesh resolution, default 32
--- @return boolean
---
--- Example:
---   core.draw.ground_circle(0, px, py, pz, 3.0, 0.1, 0.9, 0.2, 0.4)
---
lib.core_draw.ground_circle = core.draw.ground_circle

--- core.draw.ground_cone(slot, cx, cy, cz, radius, yaw, angle, [r], [g], [b], [a], [segments])
--- Draw a filled cone/wedge flat on the ground, like a directional AoE telegraph.
--- The cone apex is at (cx,cy,cz), expanding outward to `radius`.
--- @param slot     integer  — slot index (0–31)
--- @param cx       number   — apex world X
--- @param cy       number   — apex world Y (Unity Y = vertical)
--- @param cz       number   — apex world Z
--- @param radius   number   — cone length / reach in world units
--- @param yaw      number   — direction in degrees (Unity Y-axis rotation)
--- @param angle    number   — cone spread in degrees (e.g. 60 for a 60° wedge)
--- @param r        number   — [opt] red   (0–1), default 0
--- @param g        number   — [opt] green (0–1), default 1
--- @param b        number   — [opt] blue  (0–1), default 1
--- @param a        number   — [opt] alpha (0–1), default 0.4
--- @param segments integer  — [opt] arc resolution, default 16
--- @return boolean
---
--- Example:
---   -- Cone in look direction
---   core.draw.ground_cone(1, px, py, pz, 10, look_yaw, 60, 0.9, 0.2, 0.1, 0.35)
---
lib.core_draw.ground_cone = core.draw.ground_cone

--- core.draw.ground_hide(slot)
--- Hide a ground telegraph slot (keeps the object for reuse).
--- @param slot integer
lib.core_draw.ground_hide = core.draw.ground_hide

--- core.draw.ground_clear()
--- Hide all ground telegraph slots.
lib.core_draw.ground_clear = core.draw.ground_clear


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 19c — core.telegraphs.*  (AoE Telegraph Detection)            ║
-- ║                                                                        ║
-- ║  Scans nearby entities for active spell casts and reads their           ║
-- ║  HitboxDisplay data (radius, shape type) from game memory.             ║
-- ║  Use with core.draw.ground_* to visualize telegraphs with timers.      ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

lib.core_telegraphs = {}

--- core.telegraphs.scan() -> table
--- Scan all nearby entities for active spell casts / telegraphs.
--- Returns a list of tables, one per actively casting entity:
---   { uid       = integer,  -- entity UID
---     name      = string,   -- entity display name
---     x, y, z   = number,   -- entity world position (game coords)
---     dir       = integer,  -- entity facing direction
---     spell     = string,   -- spell name being cast
---     duration  = number,   -- total cast duration (seconds)
---     elapsed   = number,   -- time already elapsed
---     remaining = number,   -- time remaining (duration - elapsed)
---     ptype     = integer,  -- ProgressInfo type enum
---     radius    = number,   -- HitboxDisplay outer radius
---     mid_radius = number,  -- HitboxDisplay mid radius
---     inner_radius = number,-- HitboxDisplay inner radius
---     htype     = integer,  -- HitboxDisplay.Type enum (shape)
---     off_x     = number,   -- pattern offset X
---     off_z     = number,   -- pattern offset Z
---   }
--- Returns empty table if no entities are casting.
---
--- Example:
---   local telegraphs = core.telegraphs.scan()
---   for _, t in ipairs(telegraphs) do
---     ethy.print(t.name .. " casting " .. t.spell .. " (" .. t.remaining .. "s)")
---   end
---
lib.core_telegraphs.scan = core.telegraphs.scan


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 20 — GameObject Methods  (Player Userdata — DLL Mode)         ║
-- ║                                                                        ║
-- ║  When running as a DLL plugin, get_local_player() returns a native    ║
-- ║  GameObject userdata with these methods (colon syntax):               ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

lib.game_object_methods = {
    -- ── Identity ──
    "player:get_name()           -> string     -- Character name",
    "player:get_uid()            -> integer    -- Unique entity ID",
    "player:get_job()            -> integer    -- Job enum value (see enums.job_id)",
    "player:get_job_string()     -> string     -- Job name (e.g. 'Enchanter')",
    "player:get_role()           -> integer    -- Default role (see enums.group_role)",
    "player:is_valid()           -> boolean    -- True if the object pointer is valid",

    -- ── Vitals ──
    "player:get_hp()             -> number     -- Health percent (0–100)",
    "player:get_mp()             -> number     -- Mana percent (0–100)",
    "player:get_max_hp()         -> integer    -- Max HP",
    "player:get_max_mp()         -> integer    -- Max MP",
    "player:get_health_percent() -> number     -- Same as get_hp()",
    "player:get_mana_percent()   -> number     -- Same as get_mp()",
    "player:get_food()           -> number     -- Food/satiation level",

    -- ── Position & Movement ──
    "player:get_position()       -> table      -- { x=num, y=num, z=num }",
    "player:get_direction()      -> integer    -- Facing direction (degrees)",
    "player:get_move_speed()     -> number     -- Movement speed",
    "player:get_attack_speed()   -> number     -- Attack speed",
    "player:is_moving()          -> boolean    -- Currently moving?",

    -- ── State ──
    "player:in_combat()          -> boolean    -- In combat?",
    "player:is_dead()            -> boolean    -- Dead?",
    "player:is_frozen()          -> boolean    -- Controls frozen?",
    "player:is_spectator()       -> boolean    -- Spectator mode?",
    "player:in_pvp_zone()        -> boolean    -- In PvP zone?",
    "player:in_wildlands()       -> boolean    -- In Wildlands?",

    -- ── Stats ──
    "player:get_phys_armor()     -> number     -- Physical armor",
    "player:get_mag_armor()      -> number     -- Magical armor",
    "player:get_gold()           -> integer    -- Gold",
    "player:get_infamy()         -> number     -- Infamy",
    "player:get_combat_level()   -> integer    -- Combat level",
    "player:get_profession_level() -> integer  -- Profession level",

    -- ── Target ──
    "player:has_target()         -> boolean    -- Has an active target?",
    "player:get_target_name()    -> string     -- Target's name",
    "player:get_target_hp()      -> number     -- Target's HP %",
    "player:get_target_distance()-> number     -- Distance to target",
    "player:is_target_boss()     -> boolean    -- Target is a boss?",
    "player:is_target_elite()    -> boolean    -- Target is elite?",
    "player:is_target_rare()     -> boolean    -- Target is rare?",
    "player:get_target_info()    -> table      -- Full EntityInfo table for target",

    -- ── Buffs ──
    "player:get_buffs()          -> table      -- Array of active buff tables",
    "player:has_buff(name)       -> boolean    -- Has a specific buff?",
    "player:get_buff_data(name)  -> table      -- { is_active, remaining, stacks }",
    "player:get_stacks(name)     -> integer    -- Stack count of a buff",

    -- ── Spells ──
    "player:is_spell_ready(name) -> boolean    -- Spell off cooldown?",
    "player:cast_spell(name)     -> boolean    -- Cast spell (in combat)",
    "player:cast_spell_ooc(name) -> boolean    -- Cast spell (out of combat)",
    "player:get_spell_cooldown(name) -> string -- Remaining CD",

    -- ── Distance ──
    "player:distance_to(point)   -> number     -- Distance to {x,y,z} table",
}


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 21 — core.network.*  (Network Debug)                          ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

lib.core_network = {}

-- NOTE: core.network is NOT YET REGISTERED in lua_runtime.cpp.
-- These bindings will be nil until implemented.
if core.network then
    lib.core_network.server_address = core.network.server_address
    lib.core_network.net_classes = core.network.net_classes
end


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 22 — core.floor.*  (Floor Items / Drops)                      ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

lib.core_floor = {}

-- NOTE: core.floor is NOT YET REGISTERED in lua_runtime.cpp.
-- These bindings will be nil until implemented.
if core.floor then
    lib.core_floor.debug = core.floor.debug
    lib.core_floor.search = core.floor.search
    lib.core_floor.inspect = core.floor.inspect
end


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 23 — game.raw.*  (Raw Bridge — Native Struct Data)            ║
-- ║                                                                        ║
-- ║  DLL-only. Returns pre-parsed Lua tables from EthyBridge C++ parsers. ║
-- ║  Faster than pipe commands because data is already structured.         ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

lib.game_raw = {}

--- game.raw.player() -> table|nil
--- Full player snapshot as a native Lua table.
--- Fields: hp, mp, max_hp, max_mp, gold, x, y, z, direction,
---         in_combat, is_moving, is_frozen, move_speed, atk_speed,
---         phys_armor, mag_armor, infamy, in_pz, food, spectator,
---         in_wildlands, is_boss, is_elite, is_critter, is_rare,
---         name, uid, job, move_state, condition_mask,
---         death_timer, hostile_lost_timer, friendly_lost_timer
lib.game_raw.player = game and game.raw and game.raw.player

--- game.raw.spells() -> table
--- Array of spell tables with native struct fields:
---   { name, display, category, cooldown, current_cd, mana_cost,
---     scaled_mana, range, cast_time, channel_time,
---     is_autocast, self_target }
lib.game_raw.spells = game and game.raw and game.raw.spells

--- game.raw.nearby() -> table
--- Array of nearby entity tables with native struct fields:
---   { uid, name, x, y, z, hidden, spawned, is_static }
lib.game_raw.nearby = game and game.raw and game.raw.nearby

--- game.raw.target() -> table|nil
--- Current target as a native struct table:
---   { name, uid, x, y, z, hp, max_hp, in_combat, is_moving,
---     is_boss, is_elite, is_critter, is_rare, move_speed, atk_speed }
lib.game_raw.target = game and game.raw and game.raw.target

--- game.raw.inventory() -> table
--- Array of inventory item tables:
---   { uid, name, stack, rarity, equipped_slot, quality,
---     in_bank, noted, material, quest_item, category }
lib.game_raw.inventory = game and game.raw and game.raw.inventory

--- game.raw.send(command) -> string
--- Send any raw IPC command through the bridge.
--- @param command string
--- @return string
lib.game_raw.send = game and game.raw and game.raw.send


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 24 — Callback Registration                                    ║
-- ║                                                                        ║
-- ║  Register Lua functions to be called on specific game events.          ║
-- ║  Callbacks persist for the lifetime of the script.                     ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

lib.callbacks = {}

--- core.register_on_update_callback(fn)
--- Called every game tick (~33ms). This is your main logic loop.
--- @param fn function()
---
--- Example:
---   core.register_on_update_callback(function()
---       if core.player.hp() < 50 then
---           core.spells.cast("Heal")
---       end
---   end)
---
lib.callbacks.on_update = core.register_on_update_callback

--- core.register_on_render_callback(fn)
--- Called every frame during rendering. Use for drawing overlays.
--- @param fn function()
lib.callbacks.on_render = core.register_on_render_callback

--- core.register_on_render_menu_callback(fn)
--- Called when the settings menu is being drawn. Add your UI elements here.
--- @param fn function()
lib.callbacks.on_render_menu = core.register_on_render_menu_callback

--- core.register_on_spell_cast_callback(fn)
--- Called whenever a spell is cast.
--- @param fn function(evt)  — evt = { spell_name=string, success=bool, timestamp=number }
---
--- Example:
---   core.register_on_spell_cast_callback(function(evt)
---       print("Cast:", evt.spell_name, "Success:", evt.success)
---   end)
---
lib.callbacks.on_spell_cast = core.register_on_spell_cast_callback

--- core.register_on_combat_enter_callback(fn)
--- Called when the player enters combat.
--- @param fn function()
lib.callbacks.on_combat_enter = core.register_on_combat_enter_callback

--- core.register_on_combat_leave_callback(fn)
--- Called when the player leaves combat.
--- @param fn function()
lib.callbacks.on_combat_leave = core.register_on_combat_leave_callback

--- core.register_on_buff_applied_callback(fn)
--- Called when a buff is applied to the player.
--- @param fn function(buff_name, evt)  — buff_name=string, evt = { buff_name, internal_id, stacks }
lib.callbacks.on_buff_applied = core.register_on_buff_applied_callback

--- core.register_on_buff_removed_callback(fn)
--- Called when a buff expires or is removed from the player.
--- @param fn function(buff_name, evt)  — buff_name=string, evt = { buff_name, internal_id, stacks }
lib.callbacks.on_buff_removed = core.register_on_buff_removed_callback

--- core.register_on_target_changed_callback(fn)
--- Called when the player's target changes.
--- @param fn function(evt)  — evt = { previous_name=string, new_name=string, new_uid=int }
lib.callbacks.on_target_changed = core.register_on_target_changed_callback


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 25 — Enums                                                    ║
-- ║                                                                        ║
-- ║  Global `enums` table with all game constants.                        ║
-- ║  Use these instead of magic numbers in your scripts.                  ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

lib.enums = {}

--- enums.job_id — Player class/job identifiers
---   UNKNOWN = -1, ANY = 0,
---   ENCHANTER = 1, RANGER = 2, ASSASSIN = 3, SPELLBLADE = 4,
---   EARTHGUARD = 5, GUARDIAN = 6, ILLUSIONIST = 7, DRUID = 8,
---   SHADOWCASTER = 9, BERSERKER = 10, BRAWLER = 11, DEMONKNIGHT = 12
---
--- Example:
---   if enums.job_id.ENCHANTER == 1 then print("Enchanter!") end
---
lib.enums.job_id = enums.job_id

--- enums.spell_category — Spell type classification
---   UNKNOWN = 0, DAMAGE = 1, AOE = 2, HEAL = 3, SHIELD = 4,
---   BUFF = 5, DEBUFF = 6, CC = 7, UTILITY = 8, DEFENSIVE = 9,
---   DOT = 10, CHANNEL = 11, PET = 12, REST = 13, BURST = 14,
---   GAP_CLOSER = 15
lib.enums.spell_category = enums.spell_category

--- enums.buff_type — Buff/debuff classification
---   UNKNOWN = 0, BUFF = 1, DEBUFF = 2, DOT = 3, HOT = 4,
---   SHIELD = 5, PROC = 6, CC = 7, STANCE = 8, PASSIVE = 9,
---   FOOD = 10, IMMUNITY = 11
lib.enums.buff_type = enums.buff_type

--- enums.classification — Entity classification/rarity
---   UNKNOWN = -1, NORMAL = 0, ELITE = 1, RARE = 2, BOSS = 3, CRITTER = 4
lib.enums.classification = enums.classification

--- enums.entity_type — Entity type identifiers
---   UNKNOWN = 0, MONSTER = 1, NPC = 2, HOSTILE = 3, PLAYER = 4,
---   PET = 5, COMPANION = 6, CORPSE = 7, GATHER_NODE = 8,
---   SCENE_OBJECT = 9
lib.enums.entity_type = enums.entity_type

--- enums.combat_state — Player/entity combat states
---   IDLE = 0, IN_COMBAT = 1, DEAD = 2, FROZEN = 3, RESTING = 4,
---   GATHERING = 5, CASTING = 6, CHANNELING = 7, MOUNTED = 8
lib.enums.combat_state = enums.combat_state

--- enums.group_role — Party/group roles
---   NONE = -1, TANK = 0, HEALER = 1, DPS = 2
lib.enums.group_role = enums.group_role

--- enums.gather_node_type — Gathering node types
---   UNKNOWN = 0, HERB = 1, TREE = 2, ORE = 3, SKIN = 4
lib.enums.gather_node_type = enums.gather_node_type

--- enums.power_type — Resource/power types
---   NONE = -1, HEALTH = 0, MANA = 1, FURY = 2, SPIRIT_LINK = 3, FOOD = 4
lib.enums.power_type = enums.power_type


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 26 — conn.*  (Legacy ScriptEngine — Hub Only)                 ║
-- ║                                                                        ║
-- ║  These are only available when running scripts via the Hub's           ║
-- ║  ScriptEngine (not DLL plugins). Prefer core.* equivalents.           ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

lib.conn = {}

--- conn.send_command(cmd) -> string
--- Send a raw command through the named pipe.
--- @param cmd string
--- @return string

--- conn.get_hp() -> number
--- Player HP from shared memory.

--- conn.get_mp() -> number
--- Player MP from shared memory.

--- conn.in_combat() -> boolean
--- Player combat state from shared memory.

--- conn.has_target() -> boolean
--- Target state from shared memory.

--- conn.try_cast(spell_name) -> boolean
--- Attempt to cast a spell. Returns true if "OK" response received.
--- @param spell_name string

--- conn.target_nearest()
--- Target the nearest hostile entity.

--- conn.detect_class() -> string
--- Get the player's class/job.

--- conn.get_class_spells() -> string
--- Get all spells for the current class.


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 27 — Helper Functions (auto-loaded by bootstrap)              ║
-- ║                                                                        ║
-- ║  These utility functions are available in all scripts.                 ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

lib.helpers = {}

--- _parse_kv(line) -> table
--- Parse a "key=value|key=value" string into a Lua table.
--- Numbers are automatically converted.
--- @param line string
--- @return table

--- _parse_lines(raw) -> table
--- Parse a "#"-delimited multi-entry response into an array of tables.
--- Skips empty/error responses. Each entry is parsed via _parse_kv.
--- @param raw string
--- @return table

--- _parse_single(raw) -> table|nil
--- Parse a single "key=value|key=value" response into a table.
--- Returns nil for empty/error responses.
--- @param raw string
--- @return table|nil

--- B(result) -> boolean
--- Convert a pipe response to boolean ("1" = true).
--- @param result string
--- @return boolean

--- N(result) -> number
--- Convert a pipe response to number (0 if not a number).
--- @param result string
--- @return number


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 28 — Quick Reference Cheat Sheet                              ║
-- ║                                                                        ║
-- ║  Copy-paste patterns for common script tasks.                         ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

lib.examples = [[

-- ═══════════════════════════════════════════════════════════════
-- PATTERN: Basic combat rotation loop
-- ═══════════════════════════════════════════════════════════════

core.register_on_update_callback(function()
    local me = core.object_manager.get_local_player()
    if not me or not me:is_valid() then return end
    if me:is_dead() or me:is_frozen() then return end

    if not me:has_target() then
        core.targeting.target_nearest()
        return
    end

    if me:get_target_distance() > 30 then
        core.movement.move_to_target()
        return
    end

    if core.spells.is_ready("Fireball") then
        core.spells.cast("Fireball")
    elseif core.spells.is_ready("IceLance") then
        core.spells.cast("IceLance")
    end
end)


-- ═══════════════════════════════════════════════════════════════
-- PATTERN: Heal rotation with menu settings
-- ═══════════════════════════════════════════════════════════════

core.register_on_render_menu_callback(function()
    core.menu.checkbox("heal_enabled", "Enable Healing", true)
    core.menu.slider_int("heal_threshold", "Heal Below HP%", 70, 0, 100)
end)

core.register_on_update_callback(function()
    if not core.menu.get_checkbox("heal_enabled") then return end
    local threshold = core.menu.slider_int("heal_threshold", "Heal Below HP%", 70, 0, 100)

    if core.player.hp() < threshold then
        if core.spells.is_ready("Heal") then
            core.spells.cast("Heal")
        end
    end
end)


-- ═══════════════════════════════════════════════════════════════
-- PATTERN: Gathering bot (ScriptEngine loop style)
-- ═══════════════════════════════════════════════════════════════

while not is_stopped() do
    local herbs = core.gathering.get_herbs()
    if #herbs > 0 then
        local nearest = herbs[1]
        print("Gathering:", nearest.name)
        core.gathering.gather_nearest("HERB")
    end
    _ethy_sleep(1.0)
end


-- ═══════════════════════════════════════════════════════════════
-- PATTERN: Event-driven buff tracking
-- ═══════════════════════════════════════════════════════════════

core.register_on_buff_applied_callback(function(evt)
    print("[+] Buff applied:", evt.buff_name, "x" .. evt.stacks)
end)

core.register_on_buff_removed_callback(function(evt)
    print("[-] Buff removed:", evt.buff_name)
end)

core.register_on_target_changed_callback(function(evt)
    print("Target changed:", evt.previous_name, "->", evt.new_name)
end)


-- ═══════════════════════════════════════════════════════════════
-- PATTERN: Draw overlay ESP
-- ═══════════════════════════════════════════════════════════════

core.register_on_render_callback(function()
    local hp = core.player.hp()
    local color = hp > 50 and 0x00FF00 or 0xFF0000
    core.graphics.text_2d(10, 10, string.format("HP: %.0f%%", hp), color)
    core.graphics.rect_2d(10, 30, 200, 20, 0x333333, true)
    core.graphics.rect_2d(10, 30, hp * 2, 20, color, true)
end)


-- ═══════════════════════════════════════════════════════════════
-- PATTERN: Using game.raw for fast native data (DLL only)
-- ═══════════════════════════════════════════════════════════════

core.register_on_update_callback(function()
    local p = game.raw.player()
    if not p then return end
    if p.hp < 30 and not p.is_frozen then
        core.spells.cast("EmergencyHeal")
    end

    local spells = game.raw.spells()
    for _, s in ipairs(spells) do
        if s.current_cd <= 0 and s.category == "Damage" then
            core.spells.cast(s.name)
            break
        end
    end
end)

]]


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  API SUMMARY — Function Count                                          ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

lib.summary = {
    ["core (utilities)"]        = 6,   -- log, log_warning, log_error, time, time_ms, send_command
    ["core.player"]             = 30,  -- hp, mp, max_hp, max_mp, pos, get_position, moving, combat, ...
    ["core.targeting"]          = 19,  -- target_nearest, target_entity, has_target, get_enemies, target_by_ptr, ...
    ["core.movement"]           = 6,   -- move_to, move_to_target, stop, follow_entity, autorun_*
    ["core.spells"]             = 10,  -- cast, is_ready, cooldown, info, get_info, count, all, get_all, autocast_*
    ["core.spell_book"]         = 8,   -- is_spell_ready, cast_spell, cast_spell_ooc, get_cooldown, ...
    ["core.buff_manager"]       = 8,   -- has_buff, get_stacks, get_buff_data, get_all_buffs, ...
    ["core.object_manager"]     = 9,   -- get_local_player, get_target, get_nearby_enemies, ...
    ["core.inventory"]          = 10,  -- get_all, get_items, get_count, equipped, use_item, equip_item, ...
    ["core.gathering"]          = 15,  -- gather_nearest, gather_by_ptr, node_scan, scan_herbs, get_herbs, ...
    ["core.camera"]             = 5,   -- get, get_parsed, distance, angle, pitch
    ["core.social"]             = 7,   -- chat_send, party_count, party_scan, party_all, get_party, ...
    ["core.world"]              = 17,  -- scan_scene, get_scene, scan_nearby, get_nearby, monsterdex_*, ...
    ["core.pets"]               = 7,   -- count, companion_full, get_full, companions, atk_speed, ...
    ["core.entities"]           = 9,   -- nearby_all, nearby_living, scene_all, scene_scan, use_by_ptr, target_by_ptr, ...
    ["core.debug"]              = 21,  -- invoke_method, read_field, write_field, dump_class, ...
    ["core.menu"]               = 8,   -- checkbox, slider_int, slider_float, combobox, ...
    ["core.graphics"]           = 11,  -- color, screen_size, set_camera, world_to_screen, text_2d, line_2d, rect_2d, circle_2d, text_3d, line_3d, circle_3d
    ["core.draw"]               = 11,  -- init, line, circle, hide, clear, ground_init, ground_status, ground_circle, ground_cone, ground_hide, ground_clear
    ["core.telegraphs"]         = 1,   -- scan
    ["core.network"]            = 2,   -- server_address, net_classes
    ["core.floor"]              = 3,   -- debug, search, inspect
    ["game.raw"]                = 6,   -- player, spells, nearby, target, inventory, send
    ["callbacks"]               = 9,   -- on_update, on_render, on_render_menu, on_spell_cast, ...
    ["enums"]                   = 8,   -- job_id, spell_category, buff_type, classification, ...
    ["GameObject methods"]      = 32,  -- get_name, get_hp, in_combat, cast_spell, distance_to, ...
    ["globals"]                 = 3,   -- print, is_stopped, _ethy_sleep
    -- ───────────────────────────────────────────────────────────────
    -- TOTAL                    = 249
}

return lib
