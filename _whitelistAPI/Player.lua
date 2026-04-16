-- ═══════════════════════════════════════════════════════════════════════════
--  WHITELISTED ADDON API  —  PLAYER
--  Namespace: core.player.*
--  Category:  Character State & Stats
-- ═══════════════════════════════════════════════════════════════════════════
--
--  Access the local player's health, mana, position, combat state,
--  class info, armor, and all parsed stat tables.
--
-- ───────────────────────────────────────────────────────────────────────────

---@class PlayerAPI

--- Get current HP.
---@return number hp
-- core.player.hp()

--- Get current MP / mana.
---@return number mp
-- core.player.mp()

--- Get maximum HP.
---@return number max_hp
-- core.player.max_hp()

--- Get maximum MP.
---@return number max_mp
-- core.player.max_mp()

--- Get player world position as raw string "x,y,z".
---@return string pos_csv
-- core.player.pos()

--- Get player position as table {x, y, z}.
---@return table pos
-- core.player.get_position()

--- Is the player currently moving?
---@return boolean
-- core.player.moving()

--- Is the player frozen (stun / CC)?
---@return boolean
-- core.player.frozen()

--- Is the player in combat?
---@return boolean
-- core.player.combat()

--- Get current job / class name.
---@return string job_name
-- core.player.job()

--- Get gold amount.
---@return number gold
-- core.player.gold()

--- Get movement speed.
---@return number speed
-- core.player.speed()

--- Get character facing direction (radians).
---@return number direction
-- core.player.direction()

--- Get auto-attack speed.
---@return number attack_speed
-- core.player.attack_speed()

--- Get infamy / PK score.
---@return number infamy
-- core.player.infamy()

--- Get food / stamina.
---@return number food
-- core.player.food()

--- Is the player in a peace zone?
---@return boolean
-- core.player.pz_zone()

--- Is the player in spectator mode?
---@return boolean
-- core.player.spectator()

--- Is the player in the wildlands?
---@return boolean
-- core.player.wildlands()

--- Get combat level.
---@return number level
-- core.player.combat_level()

--- Get profession / trade skill level.
---@return number level
-- core.player.profession_level()

--- Get physical armor value.
---@return number phys_armor
-- core.player.phys_armor()

--- Get magical armor value.
---@return number mag_armor
-- core.player.mag_armor()

--- Get all player stats as raw string (pipe-delimited).
---@return string raw
-- core.player.all()

--- Get all player stats as parsed table.
---@return table stats
-- core.player.get_all()

--- Get a player info summary string.
---@return string raw
-- core.player.info()

--- Get parsed player info table.
---@return table info
-- core.player.get_info()

--- Get movement data (speed, direction, moving state).
---@return string raw
-- core.player.movement()

--- Get parsed movement table.
---@return table movement
-- core.player.get_movement()

--- Get current animation state.
---@return string animation
-- core.player.animation()

--- Get info bar data (overhead name plate).
---@return string raw
-- core.player.infobar()

--- Get all active buffs as raw string.
---@return string raw
-- core.player.buffs()

--- Get parsed buff list.
---@return table[] buffs
-- core.player.get_buffs()

--- Get all skills as raw string.
---@return string raw
-- core.player.skills()

--- Get parsed skill list.
---@return table[] skills
-- core.player.get_skills()

--- Get all talents as raw string.
---@return string raw
-- core.player.talents()

--- Get parsed talent table.
---@return table talents
-- core.player.get_talents()

--- Get buff stacks by name.
---@param name string
---@return number stacks
-- core.player.stacks(name)

--- Get a specific skill by name.
---@param name string
---@return string info
-- core.player.skill(name)

--- Get current casting info (nil if not casting).
---@return table|nil casting  {spell, duration, elapsed, ...}
-- core.player.casting()

--- Get all cooldowns as raw string.
---@return string raw
-- core.player.cooldowns()

--- Get parsed cooldown list.
---@return table[] cooldowns
-- core.player.get_cooldowns()
