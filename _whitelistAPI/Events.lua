-- ═══════════════════════════════════════════════════════════════════════════
--  WHITELISTED ADDON API  —  EVENTS & CALLBACKS
--  Namespace: core.register_on_*_callback(), callbacks module
--  Category:  Event System, Lifecycle Hooks, Combat Events
-- ═══════════════════════════════════════════════════════════════════════════
--
--  Register functions that fire on game events: frame updates, render,
--  spell casts, combat enter/leave, buff changes, target changes, etc.
--
-- ───────────────────────────────────────────────────────────────────────────

-- ┌─────────────────────────────────────────────────────────────┐
-- │  Lifecycle Callbacks                                        │
-- └─────────────────────────────────────────────────────────────┘

--- Called every frame (~60 Hz). Use for polling, state machines, ticking.
---@param fn fun()
-- core.register_on_update_callback(fn)

--- Called every render frame. Use for overlay drawing (core.graphics.*).
---@param fn fun()
-- core.register_on_render_callback(fn)

--- Called when the settings/menu panel is drawn. Use for core.menu.* widgets.
---@param fn fun()
-- core.register_on_render_menu_callback(fn)

--- Called when the plugin sidebar tab is drawn. Use for per-plugin config UI.
---@param fn fun()
-- core.register_on_plugin_tab_callback(fn)

-- ┌─────────────────────────────────────────────────────────────┐
-- │  Combat Callbacks                                           │
-- └─────────────────────────────────────────────────────────────┘

--- Fires when the player casts a spell.
---@param fn fun(spell_name: string)
-- core.register_on_spell_cast_callback(fn)

--- Fires when the player enters combat.
---@param fn fun()
-- core.register_on_combat_enter_callback(fn)

--- Fires when the player leaves combat.
---@param fn fun()
-- core.register_on_combat_leave_callback(fn)

--- Fires when damage is taken by the player.
---@param fn fun(amount: number, source: string)
-- core.register_on_damage_taken_callback(fn)

--- Fires when damage is dealt by the player.
---@param fn fun(amount: number, target: string)
-- core.register_on_damage_dealt_callback(fn)

-- ┌─────────────────────────────────────────────────────────────┐
-- │  Buff/Debuff Callbacks                                      │
-- └─────────────────────────────────────────────────────────────┘

--- Fires when a buff/debuff is applied to the player.
---@param fn fun(buff_name: string)
-- core.register_on_buff_applied_callback(fn)

--- Fires when a buff/debuff is removed from the player.
---@param fn fun(buff_name: string)
-- core.register_on_buff_removed_callback(fn)

-- ┌─────────────────────────────────────────────────────────────┐
-- │  Targeting Callbacks                                        │
-- └─────────────────────────────────────────────────────────────┘

--- Fires when the player's target changes.
---@param fn fun(new_target_name: string|nil)
-- core.register_on_target_changed_callback(fn)

-- ┌─────────────────────────────────────────────────────────────┐
-- │  Combat Tracker Module  —  Enemy & Effect Scanning         │
-- │  (require via: local ct = require("combat_tracker"))       │
-- └─────────────────────────────────────────────────────────────┘

-- ── Enemy Scan ────────────────────────────────────────────────

--- Force-refresh enemy scan data.
-- ct.refresh()

--- Set enemy scan interval (default 0.3s).
---@param seconds number
-- ct.set_scan_interval(seconds)

--- Get all enemies within 60 units.
---@return table[] enemies
-- ct.get_all_enemies()

--- Count enemies within given range.
---@param range number
---@return number count
-- ct.enemies_in_range(range)

--- Get enemies whose target is the player (aggressors).
---@return table[] aggressors
-- ct.get_aggressors()

--- Get aggressor count.
---@return number count
-- ct.get_aggressor_count()

--- Get enemies in combat with the player.
---@return table[] enemies
-- ct.get_enemies_in_combat()

--- Get enemies currently casting spells.
---@return table[] casters  {cast_spell, cast_dur, cast_elapsed, ...}
-- ct.get_enemy_casters()

--- Is any enemy in range currently casting?
---@param range? number  (default: all)
---@return boolean casting, table|nil caster
-- ct.is_enemy_casting(range)

-- ── Player Effects ────────────────────────────────────────────

--- Force-refresh player buff/debuff effects.
-- ct.refresh_effects()

--- Set effects refresh interval (default 0.3s).
---@param seconds number
-- ct.set_effects_interval(seconds)

--- Does the player have any debuffs?
---@return boolean
-- ct.player_has_debuffs()

--- Get all active player debuffs.
---@return table[] debuffs
-- ct.get_player_debuffs()

--- Get all active player buffs.
---@return table[] buffs
-- ct.get_player_buffs()

--- Find a specific effect by name.
---@param name string
---@return table|nil effect
-- ct.find_effect(name)

--- Check if a specific effect is active.
---@param name string
---@return boolean
-- ct.has_effect(name)

--- Get stack count of an effect.
---@param name string
---@return number stacks
-- ct.effect_stacks(name)

--- Get remaining duration of an effect.
---@param name string
---@return number seconds
-- ct.effect_remaining(name)

-- ┌─────────────────────────────────────────────────────────────┐
-- │  Combat Stats Module  —  Session Performance Tracking      │
-- │  (require via: local stats = require("combat_stats"))      │
-- └─────────────────────────────────────────────────────────────┘

--- Start/reset a new tracking session.
-- stats.start_session()

--- Get session elapsed time (seconds).
---@return number seconds
-- stats.elapsed()

--- Record a kill event.
---@param mob_name string
-- stats.on_kill(mob_name)

--- Record a spell cast event.
---@param spell_name string
-- stats.on_cast(spell_name)

--- Record a loot pickup event.
---@param item_name string
-- stats.on_loot(item_name)

--- Record a player death.
-- stats.on_death()

--- Get kills per hour.
---@return number kph
-- stats.kills_per_hour()

--- Get kills in last N minutes (default 5).
---@param minutes? number
---@return number count, number per_hour
-- stats.kills_recent(minutes)

--- Get casts per minute.
---@return number cpm
-- stats.casts_per_minute()

--- Get combat uptime percentage.
---@return number percent
-- stats.combat_uptime()

--- Get gold earned this session.
---@return number gold
-- stats.gold_earned()

--- Get gold per hour.
---@return number gph
-- stats.gold_per_hour()

--- Get most-cast spell and its count.
---@return string name, number count
-- stats.top_spell()

--- Get most-killed mob and its count.
---@return string name, number count
-- stats.top_mob()

--- Get spell cast breakdown {spell_name = count}.
---@return table breakdown
-- stats.spell_breakdown()

--- Get kill breakdown {mob_name = count}.
---@return table breakdown
-- stats.kill_breakdown()

--- Get raw session data table.
---@return table raw
-- stats.raw()

--- Per-frame update: tracks combat time & DPS estimation.
---@param in_combat boolean
---@param target_hp number
-- stats.tick(in_combat, target_hp)

--- Get a formatted multi-line summary string.
---@return string summary
-- stats.summary()
