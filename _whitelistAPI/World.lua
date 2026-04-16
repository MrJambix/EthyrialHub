-- ═══════════════════════════════════════════════════════════════════════════
--  WHITELISTED ADDON API  —  WORLD & ENTITIES
--  Namespaces: core.world.*, core.entities.*, core.object_manager.*
--  Category:   Scene, NPCs, Monsters, Quests, Entity Scanning
-- ═══════════════════════════════════════════════════════════════════════════
--
--  Scan the world for entities, query the scene, inspect quests,
--  companions, MonsterDex data, and use the object-manager proxy objects.
--
-- ───────────────────────────────────────────────────────────────────────────

-- ┌─────────────────────────────────────────────────────────────┐
-- │  core.world.*  —  World & Scene Queries                    │
-- └─────────────────────────────────────────────────────────────┘

--- Scan the entire current scene (raw lines).
---@return string raw
-- core.world.scan_scene()

--- Get parsed scene entity list.
---@return table[] entities
-- core.world.get_scene()

--- Scan nearby entities (raw lines).
---@return string raw
-- core.world.scan_nearby()

--- Get parsed nearby entity list.
---@return table[] entities  { {name, uid, type, hp, distance, ptr, ...}, ... }
-- core.world.get_nearby()

--- Get entity count in the scene.
---@return number count
-- core.world.scene_count()

--- Get nearby entity count.
---@return number count
-- core.world.nearby_count()

--- Get corpses in the scene (raw).
---@return string raw
-- core.world.scene_corpses()

--- Get entity data by UID (raw).
---@param uid string
---@return string raw
-- core.world.entity_by_uid(uid)

--- Get active quest data (raw).
---@return string raw
-- core.world.active_quests()

--- Get companion list (raw).
---@return string raw
-- core.world.companions()

--- MonsterDex scan (raw).
---@return string raw
-- core.world.monsterdex_scan()

--- MonsterDex nearby entities (raw lines).
---@return string raw
-- core.world.monsterdex_nearby()

--- Get parsed MonsterDex list for nearby mobs.
---@return table[] mobs
-- core.world.get_monsterdex_nearby()

--- MonsterDex for the current target (raw).
---@return string raw
-- core.world.monsterdex_target()

--- Get parsed MonsterDex data for the target.
---@return table|nil dex
-- core.world.get_monsterdex_target()

--- MonsterDex data by entity UID (raw).
---@param uid string
---@return string raw
-- core.world.monsterdex_by_uid(uid)

--- MonsterDex spell list for an entity (raw).
---@param uid string
---@return string raw
-- core.world.monsterdex_spells(uid)

--- Get global game state (raw).
---@return string raw
-- core.world.global_state()

--- Get parsed global game state table.
---@return table state
-- core.world.get_global_state()

--- Get character list (raw).
---@return string raw
-- core.world.char_list()

--- Get parsed character list.
---@return table[] characters
-- core.world.get_char_list()

--- Get quest detail by name (raw).
---@param name string
---@return string raw
-- core.world.quest_detail(name)

--- Get parsed quest data.
---@param name string
---@return table[]|nil quest_data
-- core.world.get_quest_detail(name)

-- ┌─────────────────────────────────────────────────────────────┐
-- │  core.entities.*  —  Entity Scanning & Interaction         │
-- └─────────────────────────────────────────────────────────────┘

--- Scan all nearby entities (raw).
---@return string raw
-- core.entities.nearby_all()

--- Scan nearby living entities (raw).
---@return string raw
-- core.entities.nearby_living()

--- All entities in current scene (raw).
---@return string raw
-- core.entities.scene_all()

--- Scene scan with optional name/type filter (raw).
---@param filter? string
---@return string raw
-- core.entities.scene_scan(filter)

--- Get entity under the mouse cursor.
---@return string raw
-- core.entities.entity_under_mouse()

--- Debug search for entities by name.
---@param search string
---@return string raw
-- core.entities.debug_find(search)

--- Get buff stacks on entity by name.
---@param name string
---@return string stacks
-- core.entities.buff_stacks(name)

--- Get raw player radar scan.
---@return string raw
-- core.entities.player_radar()

--- Get raw nearby players scan.
---@return string raw
-- core.entities.nearby_players()

--- Get parsed player radar results.
---@return table[] players
-- core.entities.get_player_radar()

-- ┌─────────────────────────────────────────────────────────────┐
-- │  core.object_manager.*  —  Object Manager (OOP Proxies)    │
-- └─────────────────────────────────────────────────────────────┘

--- Get local player proxy object.
---@return Player player  (see Player Proxy Methods below)
-- core.object_manager.get_local_player()

--- Get current target proxy (nil if no target).
---@return Target|nil target  (see Target Proxy Methods below)
-- core.object_manager.get_target()

--- Get parsed nearby enemies within range.
---@param range number
---@return table[] enemies
-- core.object_manager.get_nearby_enemies(range)

--- Get all parsed nearby entities.
---@return table[] entities
-- core.object_manager.get_nearby_all()

--- Get parsed party members.
---@return table[] party
-- core.object_manager.get_party_members()

--- Get entity data by UID (raw).
---@param uid string
---@return string raw
-- core.object_manager.get_entity_by_uid(uid)

--- Get count of nearby entities.
---@return number count
-- core.object_manager.get_nearby_count()

--- Get count of party members.
---@return number count
-- core.object_manager.get_party_count()

-- ── Player Proxy Methods ──────────────────────────────────────
-- local me = core.object_manager.get_local_player()
--   me:is_valid()              → boolean
--   me:get_name()              → string
--   me:get_uid()               → string
--   me:get_hp()                → number
--   me:get_mp()                → number
--   me:get_max_hp()            → number
--   me:get_max_mp()            → number
--   me:get_health_percent()    → number (0-100)
--   me:get_mana_percent()      → number (0-100)
--   me:get_job()               → number (job ID)
--   me:get_job_string()        → string (class name)
--   me:get_position()          → table {x, y, z}
--   me:get_direction()         → number
--   me:get_move_speed()        → number
--   me:get_attack_speed()      → number
--   me:get_food()              → number
--   me:get_gold()              → number
--   me:get_infamy()            → number
--   me:get_phys_armor()        → number
--   me:get_mag_armor()         → number
--   me:get_combat_level()      → number
--   me:get_profession_level()  → number
--   me:in_combat()             → boolean
--   me:is_dead()               → boolean
--   me:is_frozen()             → boolean
--   me:is_moving()             → boolean
--   me:is_spectator()          → boolean
--   me:in_pvp_zone()           → boolean
--   me:in_wildlands()          → boolean
--   me:has_target()            → boolean
--   me:get_target_name()       → string
--   me:get_target_hp()         → number
--   me:get_target_distance()   → number
--   me:get_target_info()       → table
--   me:is_target_boss()        → boolean
--   me:is_target_elite()       → boolean
--   me:is_target_rare()        → boolean
--   me:get_buffs()             → table[]
--   me:has_buff(name)          → boolean
--   me:get_stacks(name)        → number
--   me:is_spell_ready(name)    → boolean
--   me:get_spell_cooldown(name)→ number
--   me:distance_to(pos)        → number  {x, y, z}

-- ── Target Proxy Methods ──────────────────────────────────────
-- local t = core.object_manager.get_target()
--   t:is_valid()     → boolean
--   t:get_name()     → string
--   t:get_hp()       → number
--   t:get_distance() → number
--   t:get_info()     → table
--   t:get_full()     → table
