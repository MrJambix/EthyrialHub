-- ═══════════════════════════════════════════════════════════════════════════
--  WHITELISTED ADDON API  —  SOCIAL
--  Namespaces: core.social.*, core.guild.*, core.matchmaking.*
--  Category:   Chat, Party, Guild, Matchmaking
-- ═══════════════════════════════════════════════════════════════════════════
--
--  Send chat messages, query party composition, guild info, and
--  matchmaking status.
--
-- ───────────────────────────────────────────────────────────────────────────

-- ┌─────────────────────────────────────────────────────────────┐
-- │  core.social.*  —  Chat & Party                            │
-- └─────────────────────────────────────────────────────────────┘

--- Get party member count.
---@return number count
-- core.social.party_count()

--- Get raw party scan data.
---@return string raw
-- core.social.party_scan()

--- Get all party members (raw lines).
---@return string raw
-- core.social.party_all()

--- Get parsed party member list.
---@return table[] party  { {name, hp, job, distance, uid, ...}, ... }
-- core.social.get_party()

--- Get nearby players (raw).
---@return string raw
-- core.social.nearby_players()

--- Has new inbox messages?
---@return boolean
-- core.social.inbox_new()

-- ┌─────────────────────────────────────────────────────────────┐
-- │  core.guild.*  —  Guild Information                        │
-- └─────────────────────────────────────────────────────────────┘

--- Get guild info (raw).
---@return string raw
-- core.guild.info()

--- Get parsed guild info table.
---@return table guild_info
-- core.guild.get_info()

--- Get guild member list (raw).
---@return string raw
-- core.guild.members()

--- Get parsed guild members.
---@return table[] members
-- core.guild.get_members()

--- Get guild member count.
---@return number count
-- core.guild.member_count()

--- Get guild name.
---@return string name
-- core.guild.name()

--- Get guild level.
---@return number level
-- core.guild.level()

-- ┌─────────────────────────────────────────────────────────────┐
-- │  core.matchmaking.*  —  PvP Matchmaking                    │
-- └─────────────────────────────────────────────────────────────┘

--- Get matchmaking status (raw).
---@return string raw
-- core.matchmaking.status()

--- Get parsed matchmaking status.
---@return table status
-- core.matchmaking.get_status()

--- Get available maps (raw).
---@return string raw
-- core.matchmaking.maps()

--- Get parsed map list.
---@return table[] maps
-- core.matchmaking.get_maps()

--- Is the player currently in a matchmaking queue?
---@return boolean
-- core.matchmaking.in_queue()

--- Get number of available maps.
---@return number count
-- core.matchmaking.map_count()
