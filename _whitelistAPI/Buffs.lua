-- ═══════════════════════════════════════════════════════════════════════════
--  WHITELISTED ADDON API  —  BUFFS & DEBUFFS
--  Namespaces: core.buff_manager.*, buff_tracker module
--  Category:   Buff/Debuff Tracking, Stacks, Durations
-- ═══════════════════════════════════════════════════════════════════════════
--
--  Monitor active buffs and debuffs, check stacks, remaining durations,
--  and use the reactive buff tracker for rotation logic.
--
-- ───────────────────────────────────────────────────────────────────────────

-- ┌─────────────────────────────────────────────────────────────┐
-- │  core.buff_manager.*  —  Core Buff Queries                 │
-- └─────────────────────────────────────────────────────────────┘

--- Check if the player has a buff by name.
---@param name string
---@return boolean
-- core.buff_manager.has_buff(name)

--- Get stack count of a named buff.
---@param name string
---@return number stacks
-- core.buff_manager.get_stacks(name)

--- Get all active player buffs (parsed).
---@return table[] buffs
-- core.buff_manager.get_all_buffs()

--- Get full data for a specific buff.
---@param name string
---@return table data  {is_active, remaining, stacks}
-- core.buff_manager.get_buff_data(name)

--- Shortcut: get Fury buff stacks.
---@return number stacks
-- core.buff_manager.get_fury_stacks()

--- Shortcut: get Spirit Link stacks.
---@return number stacks
-- core.buff_manager.get_spirit_link_stacks()

-- ┌─────────────────────────────────────────────────────────────┐
-- │  Buff Tracker Module  —  Advanced Buff/Debuff Tracking     │
-- │  (require via: local bt = require("buff_tracker"))         │
-- └─────────────────────────────────────────────────────────────┘

--- Force-refresh buff/debuff data from the game.
-- bt.refresh()

--- Check if a buff is currently active.
---@param name string
---@return boolean
-- bt.has(name)

--- Check if a debuff is currently active.
---@param name string
---@return boolean
-- bt.has_debuff(name)

--- Get remaining duration of a buff/debuff (seconds).
---@param name string
---@return number seconds
-- bt.remaining(name)

--- Get stack count of a buff/debuff.
---@param name string
---@return number stacks
-- bt.stacks(name)

--- Is the buff expiring soon? (default threshold: 3s)
---@param name string
---@param threshold? number  seconds (default 3)
---@return boolean
-- bt.expiring(name, threshold)

--- Is the buff permanent (no duration)?
---@param name string
---@return boolean
-- bt.is_permanent(name)

--- Get full data table for a specific buff/debuff (nil if absent).
---@param name string
---@return table|nil data
-- bt.get(name)

--- Get list of all active buff names.
---@return string[] names
-- bt.all_names()

--- Get all buff data keyed by name.
---@return table all  {[name] = data}
-- bt.all()

--- Get all debuff data keyed by name.
---@return table debuffs  {[name] = data}
-- bt.all_debuffs()

--- Get count of active buffs.
---@return number count
-- bt.count()

--- Get set of active buff names {name = true}.
---@return table set
-- bt.active_set()

--- Check if ANY of the listed buffs are active.
---@param ... string  buff names
---@return boolean found, string|nil which_name
-- bt.has_any(...)

--- Check if ALL listed buffs are active.
---@param ... string  buff names
---@return boolean all_found, string|nil missing_name
-- bt.has_all(...)

--- Set auto-refresh interval (default 0.2s).
---@param seconds number
-- bt.set_refresh_interval(seconds)
