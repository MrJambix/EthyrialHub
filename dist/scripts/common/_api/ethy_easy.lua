--[[
╔══════════════════════════════════════════════════════════════╗
║            EthyEasy — Simple Scripting for Everyone          ║
║                                                              ║
║  A flat, plain-English API inspired by AutoIt.               ║
║  No nested tables, no colons, no confusing syntax.           ║
║  Just simple function calls that read like sentences.        ║
║                                                              ║
║  Usage:                                                      ║
║    require("common/_api/ethy_easy")                          ║
║                                                              ║
║  Then just call functions directly:                          ║
║    if InCombat() then CastSpell("Fireball") end              ║
╚══════════════════════════════════════════════════════════════╝
]]

-- Load the full SDK internally (we wrap it with simpler names)
local ethy = require("common/ethy_sdk")

-- ═══════════════════════════════════════════════════════════════
--  PRINTING & LOGGING
--  How to show messages in the Hub log panel.
-- ═══════════════════════════════════════════════════════════════

--- Print a message to the log panel.
--- Example: Say("Hello world!")
--- Example: Say("My HP is", GetHP())
function Say(...)
    ethy.print(...)
end

--- Print a formatted message (uses % placeholders).
--- Example: SayF("HP: %d%%  MP: %d%%", GetHP(), GetMP())
function SayF(fmt, ...)
    ethy.printf(fmt, ...)
end

--- Print a warning message (shows in yellow).
--- Example: Warn("Low health!")
function Warn(msg)
    ethy.log_warning(tostring(msg))
end

--- Print an error message (shows in red).
--- Example: Error("Something went wrong!")
function Error(msg)
    ethy.log_error(tostring(msg))
end

-- ═══════════════════════════════════════════════════════════════
--  TIMING & SLEEPING
--  Control how fast your script runs.
-- ═══════════════════════════════════════════════════════════════

--- Pause the script for a number of seconds.
--- Example: Sleep(0.5)   -- pause for half a second
--- Example: Sleep(2)     -- pause for 2 seconds
function Sleep(seconds)
    _ethy_sleep(seconds or 0.3)
end

--- Get the current time in seconds (for measuring elapsed time).
--- Example: local start = Now()  ...later...  Say("Took", Now() - start, "seconds")
function Now()
    return ethy.now()
end

--- How many seconds have passed since a given time.
--- Example: if TimeSince(lastCast) > 2 then ... end
function TimeSince(past_time)
    return ethy.time_since(past_time)
end

--- Run a function after a delay.
--- Example: After(0.5, function() Say("Delayed!") end)
function After(delay_seconds, callback)
    ethy.after(delay_seconds, callback)
end

-- ═══════════════════════════════════════════════════════════════
--  SCRIPT CONTROL
--  Check if the script should stop running.
-- ═══════════════════════════════════════════════════════════════

--- Returns true when the user clicks "Stop" in the Hub.
--- Always use this in your main loop!
--- Example:
---   while not ShouldStop() do
---       -- your code here
---       Sleep(0.3)
---   end
function ShouldStop()
    return is_stopped()
end

-- ═══════════════════════════════════════════════════════════════
--  PLAYER INFO
--  Get information about YOUR character.
-- ═══════════════════════════════════════════════════════════════

-- Internal: get the player object
local function _player()
    return ethy.get_player()
end

--- Get your current health percentage (0 to 100).
--- Example: if GetHP() < 50 then Say("Low health!") end
function GetHP()
    local p = _player()
    return p and p:get_health_percent() or 0
end

--- Get your current mana percentage (0 to 100).
--- Example: if GetMP() < 20 then Say("Low mana!") end
function GetMP()
    local p = _player()
    return p and p:get_mana_percent() or 0
end

--- Get your maximum health points (raw number).
function GetMaxHP()
    local p = _player()
    return p and p:get_max_hp() or 0
end

--- Get your maximum mana points (raw number).
function GetMaxMP()
    local p = _player()
    return p and p:get_max_mp() or 0
end

--- Get your character's name.
--- Example: Say("Hello, " .. GetMyName())
function GetMyName()
    local p = _player()
    return p and p:get_name() or "Unknown"
end

--- Get your class/job name (e.g. "Enchanter", "Ranger").
--- Example: if GetMyClass() == "Ranger" then ... end
function GetMyClass()
    local p = _player()
    return p and p:get_job_string() or "Unknown"
end

--- Get your current gold amount.
function GetGold()
    return tonumber(core.player.gold()) or 0
end

--- Get your movement speed.
function GetSpeed()
    return tonumber(core.player.speed()) or 0
end

--- Get your facing direction (0 to 359 degrees).
function GetDirection()
    return tonumber(core.player.direction()) or 0
end

--- Get your food/satiation level.
function GetFood()
    return tonumber(core.player.food()) or 0
end

--- Get your combat level.
function GetCombatLevel()
    return tonumber(core.player.combat_level()) or 0
end

--- Get your profession/gathering level.
function GetProfessionLevel()
    return tonumber(core.player.profession_level()) or 0
end

--- Get your physical armor value.
function GetPhysicalArmor()
    return tonumber(core.player.phys_armor()) or 0
end

--- Get your magical armor value.
function GetMagicalArmor()
    return tonumber(core.player.mag_armor()) or 0
end

-- ═══════════════════════════════════════════════════════════════
--  PLAYER STATE
--  Check what your character is currently doing.
-- ═══════════════════════════════════════════════════════════════

--- Are you in combat right now?
--- Example: if InCombat() then Say("Fighting!") end
function InCombat()
    local p = _player()
    return p and p:in_combat() or false
end

--- Are you currently moving?
function IsMoving()
    local p = _player()
    return p and p:is_moving() or false
end

--- Are you dead?
function IsDead()
    local p = _player()
    return p and p:is_dead() or false
end

--- Are your controls frozen (stunned, loading screen, etc)?
function IsFrozen()
    local p = _player()
    return p and p:is_frozen() or false
end

--- Are you in a safe/protected zone?
function InSafeZone()
    return core.player.pz_zone() == true or core.player.pz_zone() == "1"
end

--- Are you in the wildlands (PvP area)?
function InWildlands()
    return core.player.wildlands() == true or core.player.wildlands() == "1"
end

-- ═══════════════════════════════════════════════════════════════
--  PLAYER POSITION
--  Get your character's location in the world.
-- ═══════════════════════════════════════════════════════════════

--- Get your X, Y, Z position as three separate numbers.
--- Example: local x, y, z = GetPosition()
function GetPosition()
    local pos = core.player.get_position and core.player.get_position()
    if pos then
        return pos.x or 0, pos.y or 0, pos.z or 0
    end
    -- Fallback: parse the raw string
    local raw = core.player.pos() or "0,0,0"
    local x, y, z = raw:match("([^,]+),([^,]+),([^,]+)")
    return tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 0
end

--- Calculate distance between two 3D points.
--- Example: local dist = Distance3D(x1,y1,z1, x2,y2,z2)
function Distance3D(x1, y1, z1, x2, y2, z2)
    local dx = x2 - x1
    local dy = y2 - y1
    local dz = z2 - z1
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

--- Calculate flat (horizontal) distance (ignores height).
--- Example: local dist = Distance2D(x1,z1, x2,z2)
function Distance2D(x1, z1, x2, z2)
    local dx = x2 - x1
    local dz = z2 - z1
    return math.sqrt(dx*dx + dz*dz)
end

-- ═══════════════════════════════════════════════════════════════
--  TARGETING
--  Select and get info about enemies/friends.
-- ═══════════════════════════════════════════════════════════════

--- Do you currently have a target selected?
--- Example: if HasTarget() then Say("Target: " .. GetTargetName()) end
function HasTarget()
    local p = _player()
    return p and p:has_target() or false
end

--- Get the name of your current target.
--- Example: Say("Fighting: " .. GetTargetName())
function GetTargetName()
    local p = _player()
    return p and p:get_target_name() or "None"
end

--- Get your target's health percentage (0 to 100).
--- Example: if GetTargetHP() < 20 then Say("Almost dead!") end
function GetTargetHP()
    local p = _player()
    return p and p:get_target_hp() or 0
end

--- Get the distance to your current target.
--- Example: if GetTargetDistance() > 30 then Say("Too far!") end
function GetTargetDistance()
    local p = _player()
    return p and p:get_target_distance() or 999
end

--- Is your target a boss?
function IsTargetBoss()
    local p = _player()
    return p and p:is_target_boss() or false
end

--- Is your target elite?
function IsTargetElite()
    local p = _player()
    return p and p:is_target_elite() or false
end

--- Target the nearest enemy.
--- Example: TargetNearest()
function TargetNearest()
    return core.targeting.target_nearest()
end

--- Target a specific entity by its unique ID.
--- Example: TargetByID(12345)
function TargetByID(uid)
    return core.targeting.target_entity(uid)
end

--- Target a party member by index (1, 2, 3...).
--- Example: TargetPartyMember(1)
function TargetPartyMember(index)
    return core.targeting.target_party(index)
end

--- Get full info about your target as a table.
--- Returns: { uid, name, hp, max_hp, distance, classification, ... }
function GetTargetInfo()
    return core.targeting.target_full()
end

-- ═══════════════════════════════════════════════════════════════
--  SPELLS & CASTING
--  Cast spells and check cooldowns.
-- ═══════════════════════════════════════════════════════════════

--- Cast a spell by name. Returns true if it worked.
--- Example: CastSpell("Fireball")
--- Example: if CastSpell("Heal") then Say("Healed!") end
function CastSpell(name)
    if not name then return false end
    return ethy.spell_book.cast(name)
end

--- Check if a spell is ready to cast (off cooldown and enough mana).
--- Example: if IsSpellReady("Fireball") then CastSpell("Fireball") end
function IsSpellReady(name)
    if not name then return false end
    return ethy.spell_book.is_ready(name)
end

--- Try to cast a spell only if it's ready. Returns true if it cast.
--- This is the most common pattern — combines IsSpellReady + CastSpell.
--- Example: TryCast("Fireball")
function TryCast(name)
    if not name then return false end
    if ethy.spell_book.is_ready(name) then
        return ethy.spell_book.cast(name)
    end
    return false
end

--- Get the remaining cooldown of a spell in seconds.
--- Example: Say("Fireball ready in", GetCooldown("Fireball"), "seconds")
function GetCooldown(name)
    return ethy.spell_book.get_cooldown(name) or 0
end

--- Get a list of ALL your spells.
--- Returns a table of spell info: { {name="...", category="...", ...}, ... }
function GetAllSpells()
    return ethy.spell_book.get_all() or {}
end

--- Cast the first ready spell from a priority list.
--- Returns the name of the spell that was cast, or nil if none were ready.
--- Example:
---   local cast = CastFirstReady({"Big Hit", "Medium Hit", "Small Hit"})
---   if cast then Say("Cast: " .. cast) end
function CastFirstReady(spell_list)
    for _, name in ipairs(spell_list) do
        if TryCast(name) then
            return name
        end
    end
    return nil
end

-- ═══════════════════════════════════════════════════════════════
--  BUFFS & DEBUFFS
--  Check what buffs/debuffs are active.
-- ═══════════════════════════════════════════════════════════════

--- Check if you have a specific buff active.
--- Example: if HasBuff("Stormshield") then Say("Protected!") end
function HasBuff(name)
    return ethy.buff_manager.has_buff(name) or false
end

--- Get how many stacks of a buff you have.
--- Example: if GetStacks("FuryStatus") >= 4 then CastSpell("Fury Strike") end
function GetStacks(name)
    return ethy.buff_manager.get_stacks(name) or 0
end

--- Get detailed info about a buff.
--- Returns: { is_active, name, display_name, stacks, duration, max_duration }
--- Example:
---   local info = GetBuffInfo("Stormshield")
---   if info and info.duration < 3 then Say("Shield about to expire!") end
function GetBuffInfo(name)
    return ethy.buff_manager.get_buff_data(name)
end

--- Get a list of all active buffs.
function GetAllBuffs()
    return ethy.buff_manager.get_all_buffs()
end

--- Check if a buff is about to expire (less than X seconds remaining).
--- Example: if IsBuffExpiring("Stormshield", 3) then CastSpell("Stormshield") end
function IsBuffExpiring(name, threshold_seconds)
    threshold_seconds = threshold_seconds or 3
    local info = ethy.buff_manager.get_buff_data(name)
    if not info or not info.is_active then return true end  -- not active = "expired"
    return (info.duration or 0) < threshold_seconds
end

--- Ensure a buff stays active. If missing or expiring, tries to cast the spell.
--- Returns true if a cast was attempted.
--- Example: MaintainBuff("Stormshield", "Stormshield", 3)
--- Example: MaintainBuff("ImbueMindClarity", "Imbue Mind: Clarity")
function MaintainBuff(buff_name, spell_name, refresh_threshold)
    spell_name = spell_name or buff_name  -- often same name
    refresh_threshold = refresh_threshold or 3
    if IsBuffExpiring(buff_name, refresh_threshold) then
        return TryCast(spell_name)
    end
    return false
end

-- ═══════════════════════════════════════════════════════════════
--  ENEMIES & SCANNING
--  Find enemies and other entities nearby.
-- ═══════════════════════════════════════════════════════════════

--- Get a list of enemies within a given range (default 50).
--- Each enemy: { name, hp, distance, classification, uid, ... }
--- Example:
---   local enemies = GetNearbyEnemies(40)
---   Say("There are", #enemies, "enemies nearby")
function GetNearbyEnemies(range)
    return core.object_manager.get_nearby_enemies(range or 50) or {}
end

--- Count how many enemies are nearby.
--- Example: if CountNearbyEnemies(30) > 3 then Say("Lots of mobs!") end
function CountNearbyEnemies(range)
    local enemies = GetNearbyEnemies(range)
    return #enemies
end

--- Get all entities nearby (enemies, NPCs, players, objects).
function GetNearbyAll()
    return core.object_manager.get_nearby_all() or {}
end

--- Get a specific entity by its unique ID.
function GetEntityByID(uid)
    return core.object_manager.get_entity_by_uid(uid)
end

-- ═══════════════════════════════════════════════════════════════
--  PARTY
--  Get info about your party members.
-- ═══════════════════════════════════════════════════════════════

--- Get a list of party members.
--- Each member: { name, hp, uid, ... }
function GetPartyMembers()
    return core.object_manager.get_party_members() or {}
end

--- How many people are in your party?
function GetPartySize()
    return core.object_manager.get_party_count() or 0
end

--- Find the party member with the lowest HP.
--- Returns the member table, or nil if no party.
--- Example:
---   local wounded = GetLowestPartyMember()
---   if wounded and wounded.hp < 50 then
---       TargetByID(wounded.uid)
---       CastSpell("Heal")
---   end
function GetLowestPartyMember()
    local members = GetPartyMembers()
    if #members == 0 then return nil end
    local lowest = members[1]
    for i = 2, #members do
        if members[i].hp < lowest.hp then
            lowest = members[i]
        end
    end
    return lowest
end

-- ═══════════════════════════════════════════════════════════════
--  MOVEMENT
--  Move your character around the world.
-- ═══════════════════════════════════════════════════════════════

--- Move to a specific X, Y position.
--- Example: MoveTo(100, 200)
function MoveTo(x, y)
    return core.movement.move_to(x, y)
end

--- Move toward your current hostile target.
function MoveToTarget()
    return core.movement.move_to_target()
end

--- Move toward your current friendly target.
--- Use this when you have a friendly (green) target selected.
--- Example: MoveToTargetFriendly()
function MoveToTargetFriendly()
    return core.movement.move_to_target_friendly()
end

--- Stop all movement.
function StopMoving()
    return core.movement.stop()
end

--- Follow an entity by its unique ID.
function Follow(uid)
    return core.movement.follow_entity(uid)
end

--- Follow an entity at a specific range.
--- Example: FollowRange(player_uid, 5.0)
function FollowRange(uid, range)
    return core.movement.follow_range(uid, range or 2.0)
end

-- ═══════════════════════════════════════════════════════════════
--  INVENTORY & LOOTING
--  Manage items and loot.
-- ═══════════════════════════════════════════════════════════════

--- Loot everything from the current loot window.
--- Example: LootAll()
function LootAll()
    return core.inventory.loot_all()
end

--- Get your full inventory as a list.
--- Each item: { uid, name, stack, rarity, category, ... }
function GetInventory()
    return core.inventory.get_all() or {}
end

--- Count total items in your inventory.
function GetInventoryCount()
    return core.inventory.get_count() or 0
end

--- Use an item by its unique ID.
function UseItem(uid)
    return core.inventory.use_item(uid)
end

--- Equip an item by its unique ID.
function EquipItem(uid)
    return core.inventory.equip_item(uid)
end

--- Get equipped items.
function GetEquipped()
    return core.inventory.equipped() or {}
end

--- Use an item on another item/entity (e.g. skinning knife on trophy fish).
--- Both arguments are UIDs from your inventory.
--- Example: UseItemOn(knife_uid, fish_uid)
function UseItemOn(item_uid, target_uid)
    return core.inventory.item_use_on(item_uid, target_uid)
end

--- Drop an item from your inventory.
--- amount is optional (defaults to 1).
--- Example: DropItem(item_uid)
--- Example: DropItem(item_uid, 5)  -- drop 5 of a stack
function DropItem(uid, amount)
    return core.inventory.drop_item(uid, amount or 1)
end

-- ═══════════════════════════════════════════════════════════════
--  GATHERING (Herbs, Ore, Trees, Skins, Fish)
--  Interact with resource nodes in the world.
-- ═══════════════════════════════════════════════════════════════

--- Gather the nearest resource node (optional name filter).
--- Example: GatherNearest()          -- gather anything
--- Example: GatherNearest("Iron")    -- only gather iron nodes
function GatherNearest(filter)
    return core.gathering.gather_nearest(filter)
end

--- Scan for herb nodes nearby. Returns a list.
function ScanHerbs()
    return core.gathering.scan_herbs() or {}
end

--- Scan for ore/mining nodes nearby.
function ScanOres()
    return core.gathering.scan_ores() or {}
end

--- Scan for trees/woodcutting nodes nearby.
function ScanTrees()
    return core.gathering.scan_trees() or {}
end

--- Scan for corpses nearby (with names).
function ScanCorpses()
    return core.gathering.scan_corpses() or {}
end

--- Use tool on nearest corpse matching name.
function UseToolOnCorpse(name)
    return core.gathering.use_tool_on_corpse(name)
end

--- Scan for all resource nodes (any type), optional filter.
--- Example: local nodes = ScanAllNodes("Iron")
function ScanAllNodes(filter)
    return core.gathering.node_scan(filter) or {}
end

--- Scan only for nodes you can actually use right now.
function ScanUsableNodes(filter)
    return core.gathering.node_scan_usable(filter) or {}
end

-- ═══════════════════════════════════════════════════════════════
--  CAMERA
--  Get camera information.
-- ═══════════════════════════════════════════════════════════════

--- Get camera distance (zoom level).
function GetCameraDistance()
    return core.camera.distance() or 0
end

--- Get camera angle.
function GetCameraAngle()
    return core.camera.angle() or 0
end

--- Get camera pitch (up/down tilt).
function GetCameraPitch()
    return core.camera.pitch() or 0
end

-- ═══════════════════════════════════════════════════════════════
--  SOCIAL & CHAT
--  Interact with other players.
-- ═══════════════════════════════════════════════════════════════

--- Send a chat message.
--- Example: SendChat("Hello everyone!")
function SendChat(message)
    return core.social.chat_send(message)
end

--- Get a list of players near you.
function GetNearbyPlayers()
    return core.social.nearby_players() or {}
end

-- ═══════════════════════════════════════════════════════════════
--  LOOT ROLLING (Need / Greed / Pass)
--  Handle group loot roll windows.
-- ═══════════════════════════════════════════════════════════════

--- Get all pending loot roll windows.
function GetLootRolls()
    return ethy.loot_roll.scan() or {}
end

--- Greed on all pending rolls.
function GreedAll()
    return ethy.loot_roll.greed_all()
end

-- ═══════════════════════════════════════════════════════════════
--  EVENTS (Callbacks)
--  React to things that happen in-game automatically.
-- ═══════════════════════════════════════════════════════════════

--- Run a function every frame (main loop for plugins).
--- Example:
---   OnUpdate(function()
---       if InCombat() then Say("Fighting!") end
---   end)
function OnUpdate(fn)
    ethy.on_update(fn)
end

--- Run a function when you enter combat.
--- Example: OnCombatStart(function() Say("Fight!") end)
function OnCombatStart(fn)
    ethy.on_combat_enter(fn)
end

--- Run a function when combat ends.
--- Example: OnCombatEnd(function() Say("Combat over") end)
function OnCombatEnd(fn)
    ethy.on_combat_leave(fn)
end

--- Run a function when you gain a buff.
--- Example: OnBuffGained(function(name) Say("Got buff: " .. name) end)
function OnBuffGained(fn)
    ethy.on_buff_applied(fn)
end

--- Run a function when a buff expires or is removed.
function OnBuffLost(fn)
    ethy.on_buff_removed(fn)
end

--- Run a function when your target changes.
function OnTargetChanged(fn)
    ethy.on_target_changed(fn)
end

--- Run a function after you cast a spell.
function OnSpellCast(fn)
    ethy.on_spell_cast(fn)
end

-- ═══════════════════════════════════════════════════════════════
--  HUMANIZATION
--  Make your bot behave more like a human player.
-- ═══════════════════════════════════════════════════════════════

--- Sleep for a random human-like reaction time (~250ms).
--- Example: HumanDelay()  -- pauses ~0.2-0.3 seconds
function HumanDelay()
    _ethy_sleep(ethy.human.reaction_delay())
end

--- Sleep for a random time between min and max seconds.
--- Example: RandomPause(0.5, 2.0)  -- pause 0.5 to 2 seconds
function RandomPause(min_seconds, max_seconds)
    ethy.human.random_pause(min_seconds, max_seconds)
end

--- Should the bot "misplay" this tick? (for realism)
--- chance: probability from 0.0 to 1.0 (default 0.03 = 3%)
--- Example: if ShouldMisplay() then Sleep(1) end  -- occasionally pause
function ShouldMisplay(chance)
    return ethy.human.should_misplay(chance)
end

-- ═══════════════════════════════════════════════════════════════
--  BUFF TRACKER (Advanced)
--  Enhanced buff queries with duration tracking.
-- ═══════════════════════════════════════════════════════════════

--- Get remaining duration of a buff in seconds.
--- Example: if BuffRemaining("Shield") < 3 then CastSpell("Shield") end
function BuffRemaining(name)
    return ethy.buffs.remaining(name)
end

--- Check if a buff is about to expire (uses buff_tracker).
--- Example: if BuffExpiring("Regen", 5) then CastSpell("Regen") end
function BuffExpiring(name, threshold)
    return ethy.buffs.expiring(name, threshold)
end

--- Check if you have a debuff active.
--- Example: if HasDebuff("Poison") then CastSpell("Cleanse") end
function HasDebuff(name)
    return ethy.buffs.has_debuff(name)
end

--- Check if you have ANY of the listed buffs.
--- Example: if HasAnyBuff("Shield", "Barrier") then ... end
function HasAnyBuff(...)
    return ethy.buffs.has_any(...)
end

--- Check if you have ALL of the listed buffs.
function HasAllBuffs(...)
    return ethy.buffs.has_all(...)
end

-- ═══════════════════════════════════════════════════════════════
--  SPELL QUEUE (GCD-Aware Casting)
--  Smart spell casting with priority and queue support.
-- ═══════════════════════════════════════════════════════════════

--- Set spell priority list (first = highest priority).
--- Example: SetSpellPriority({"Fireball", "Frostbolt", "Ice Lance"})
function SetSpellPriority(spell_list)
    ethy.spell_queue.set_priority(spell_list)
end

--- Queue a spell to be cast next (skips priority order).
--- Example: QueueSpell("Emergency Heal")
function QueueSpell(name)
    ethy.spell_queue.enqueue(name)
end

--- Queue multiple spells in sequence.
--- Example: QueueSequence("Buff1", "Buff2", "Buff3")
function QueueSequence(...)
    ethy.spell_queue.enqueue_sequence(...)
end

--- Run one tick of the spell queue (auto-casts best available).
--- Returns the spell name that was cast, or nil.
function RunSpellQueue()
    return ethy.spell_queue.tick()
end

--- Add a condition for when a spell should be used.
--- Example: SetSpellCondition("Heal", function() return GetHP() < 50 end)
function SetSpellCondition(spell_name, condition_fn)
    ethy.spell_queue.set_condition(spell_name, condition_fn)
end

-- ═══════════════════════════════════════════════════════════════
--  WAYPOINTS & PATHING
--  Record and follow paths.
-- ═══════════════════════════════════════════════════════════════

--- Start recording your movement as waypoints.
function RecordPathStart()
    ethy.waypoints.record_start()
end

--- Stop recording and get the path.
function RecordPathStop()
    return ethy.waypoints.record_stop()
end

--- Follow a list of waypoints.
--- Example: FollowPath(waypoints, {loop = true})
function FollowPath(path, opts)
    ethy.waypoints.follow(path, opts)
end

--- Stop following the current path.
function StopPath()
    ethy.waypoints.stop()
end

--- Are we currently following a path?
function IsFollowingPath()
    return ethy.waypoints.is_following()
end

--- Create a circular patrol path.
--- Example: local path = CirclePath(100, 50, 200, 20, 8)
function CirclePath(cx, cy, cz, radius, points)
    return ethy.waypoints.circle(cx, cy, cz, radius, points)
end

-- ═══════════════════════════════════════════════════════════════
--  ZONE AWARENESS
--  Know where you are.
-- ═══════════════════════════════════════════════════════════════

--- Get current zone/map name.
function GetZone()
    return ethy.zone.name()
end

--- Get current region name.
function GetRegion()
    return ethy.zone.region()
end

--- Check if in a specific zone (partial match).
--- Example: if InZone("Darkwood") then ... end
function InZone(name)
    return ethy.zone.is(name)
end

--- Is the current zone safe (no PvP)?
function IsZoneSafe()
    return ethy.zone.is_safe()
end

-- ═══════════════════════════════════════════════════════════════
--  COMBAT STATS
--  Track your performance.
-- ═══════════════════════════════════════════════════════════════

--- Start tracking combat statistics.
function StartStats()
    ethy.combat_stats.start_session()
end

--- Get kills per hour.
function KillsPerHour()
    return ethy.combat_stats.kills_per_hour()
end

--- Get a formatted stats summary string.
function GetStatsSummary()
    return ethy.combat_stats.summary()
end

--- Record a kill for stats tracking.
function RecordKill(mob_name)
    ethy.combat_stats.on_kill(mob_name)
end

-- ═══════════════════════════════════════════════════════════════
--  SIGNALS (Script Communication)
--  Share data between scripts.
-- ═══════════════════════════════════════════════════════════════

--- Set a shared variable that other scripts can read.
--- Example: SetShared("mode", "gathering")
function SetShared(key, value)
    ethy.signals.set(key, value)
end

--- Get a shared variable set by any script.
--- Example: local mode = GetShared("mode", "idle")
function GetShared(key, default)
    return ethy.signals.get(key, default)
end

--- Fire a signal that other scripts can listen for.
--- Example: FireSignal("pull_ready")
function FireSignal(name, data)
    ethy.signals.signal(name, data)
end

-- ═══════════════════════════════════════════════════════════════
--  INVENTORY AUTOMATION
--  Auto-use items based on conditions.
-- ═══════════════════════════════════════════════════════════════

--- Auto-use an item when a condition is met.
--- Example: AutoUseItem("Health Potion", function() return GetHP() < 40 end)
function AutoUseItem(name, condition, cooldown)
    ethy.items.use_when(name, condition, cooldown)
end

--- Check if you have an item in inventory.
--- Example: if HaveItem("Health Potion") then ... end
function HaveItem(name)
    return ethy.items.has(name)
end

--- Count how many of an item you have.
function CountItem(name)
    return ethy.items.count(name)
end

-- ═══════════════════════════════════════════════════════════════
--  UNIFIED TICK
--  Drive all framework subsystems.
-- ═══════════════════════════════════════════════════════════════

--- Call this in your main loop to power events, waypoints, items, etc.
--- Example:
---   while not ShouldStop() do
---       Tick()
---       -- your logic
---       Sleep(0.3)
---   end
function Tick()
    ethy.tick()
end

-- ═══════════════════════════════════════════════════════════════
--  RAW COMMANDS
--  Send raw pipe commands (advanced, escape hatch).
-- ═══════════════════════════════════════════════════════════════

--- Send a raw command to the game tool. Returns raw string.
--- Only use this for features not covered by the easy API.
--- Example: local result = SendCommand("PLAYER_HP")
function SendCommand(cmd)
    return core.send_command(cmd)
end

-- ═══════════════════════════════════════════════════════════════
--  CONVENIENCE SHORTCUTS
--  Common patterns wrapped into single calls.
-- ═══════════════════════════════════════════════════════════════

--- A simple combat rotation: cast the first ready spell from a list.
--- Logs which spell was cast. Returns true if something was cast.
--- Example:
---   local spells = {"Big Hit", "Fireball", "Punch"}
---   DoRotation(spells)
function DoRotation(spell_list)
    local cast = CastFirstReady(spell_list)
    if cast then
        SayF("Cast: %s", cast)
        return true
    end
    return false
end

-- ═══════════════════════════════════════════════════════════════
--  CLIENT-SIDE MODIFICATIONS
--  Things you can change that take effect instantly on your client.
--  These are visual/camera/rendering tweaks — not cheats that
--  the server would block.
-- ═══════════════════════════════════════════════════════════════

-- ── Teleport ──

--- Teleport to an exact position (client-side, full sync).
--- Example: TeleportTo(100, 50, 200)
function TeleportTo(x, y, z)
    return ethy.teleport(x, y, z)
end

--- Teleport and HOLD position (prevents rubber-banding).
--- MUST call TeleportUnlock() when done!
--- Example: TeleportLock(100, 50, 200)
function TeleportLock(x, y, z)
    return ethy.teleport_lock(x, y, z)
end

--- Release a teleport hold (stop freezing position).
function TeleportUnlock()
    return ethy.teleport_release()
end

--- Check if teleport hold is active.
function IsTeleportLocked()
    local status = ethy.teleport_status()
    return status and status:find("HOLDING") ~= nil
end

-- ── Movement Speed ──

--- Lock your movement speed to a value (client-side).
--- Example: SetMoveSpeed(8)
function SetMoveSpeed(speed)
    return SendCommand("SPEED_LOCK " .. tostring(speed or 7))
end

--- Unlock movement speed (return to normal server speed).
function UnlockMoveSpeed()
    return SendCommand("SPEED_UNLOCK")
end

-- ── Weight Lock ──

--- Lock MaxWeight to 99999 so the overweight debuff never applies.
--- Lets you move freely regardless of inventory weight.
--- Example: WeightLock()
function WeightLock(max_weight)
    return ethy.weight_lock(max_weight)
end

--- Unlock weight — restore normal overweight checking.
function WeightUnlock()
    return ethy.weight_unlock()
end

--- Get weight status info (current_weight, max_weight, overweight flag).
function WeightStatus()
    return ethy.weight_status()
end

--- Check if weight lock is active.
function IsWeightLocked()
    local status = ethy.weight_status()
    return status and status:find("locked=1") ~= nil
end

--- Get current speed status (base, current, forward, modifiers).
--- Returns raw status string.
function GetSpeedStatus()
    return SendCommand("SPEED_STATUS")
end

-- ── Camera ──

--- Set the camera zoom distance.
--- Example: SetCameraDistance(20)
function SetCameraDistance(dist)
    return SendCommand("SET_CAMERA_DISTANCE " .. tostring(dist))
end

--- Set the maximum camera zoom-out distance.
--- Example: SetCameraMaxDistance(50)
function SetCameraMaxDistance(dist)
    return SendCommand("SET_CAMERA_MAX_DIST " .. tostring(dist))
end

--- Set the minimum camera zoom-in distance.
--- Example: SetCameraMinDistance(2)
function SetCameraMinDistance(dist)
    return SendCommand("SET_CAMERA_MIN_DIST " .. tostring(dist))
end

--- Set camera horizontal angle (rotation around character).
--- Example: SetCameraAngle(180)
function SetCameraAngle(angle)
    return SendCommand("SET_CAMERA_ANGLE " .. tostring(angle))
end

--- Set camera vertical pitch (up/down tilt).
--- Example: SetCameraPitch(30)
function SetCameraPitch(pitch)
    return SendCommand("SET_CAMERA_PITCH " .. tostring(pitch))
end

-- ── Field of View ──

--- Set the camera field of view (default is ~60).
--- Higher = wider view, lower = zoomed in.
--- Example: SetFOV(90)
function SetFOV(fov)
    return SendCommand("SET_FOV " .. tostring(fov))
end

-- ── Rendering & Draw Distance ──

--- Set how far you can see (render distance).
--- Example: SetRenderDistance(1500)
function SetRenderDistance(dist)
    return SendCommand("SET_RENDER_DIST " .. tostring(dist))
end

--- Set the far clip plane (geometry beyond this is invisible).
--- Example: SetFarClip(2000)
function SetFarClip(dist)
    return SendCommand("SET_FAR_CLIP " .. tostring(dist))
end

--- Set LOD bias (Level of Detail). Higher = more detail at distance.
--- Example: SetLODBias(2.0)
function SetLODBias(bias)
    return SendCommand("SET_LOD_BIAS " .. tostring(bias))
end

--- Set shadow draw distance.
--- Example: SetShadowDistance(200)
function SetShadowDistance(dist)
    return SendCommand("SET_SHADOW_DIST " .. tostring(dist))
end

--- Set shadow quality level (0 = off, 1 = low, 2 = medium, 3 = high).
--- Example: SetShadowQuality(3)
function SetShadowQuality(level)
    return SendCommand("SET_SHADOW_QUALITY " .. tostring(level))
end

--- Set overall graphics quality level (0-5).
--- Example: SetQualityLevel(5)
function SetQualityLevel(level)
    return SendCommand("SET_QUALITY_LEVEL " .. tostring(level))
end

--- Set max pixel lights rendered.
--- Example: SetPixelLights(4)
function SetPixelLights(count)
    return SendCommand("SET_PIXEL_LIGHTS " .. tostring(count))
end

--- Set grass density (0.0 to 1.0, or higher).
--- Example: SetGrassDensity(0.5)  -- half grass
--- Example: SetGrassDensity(0)    -- no grass (performance boost)
function SetGrassDensity(density)
    return SendCommand("SET_GRASS_DENSITY " .. tostring(density))
end

--- Enable or disable VSync.
--- Example: SetVSync(true)
function SetVSync(enabled)
    return SendCommand("SET_VSYNC " .. (enabled and "1" or "0"))
end

-- ── Fog ──

--- Enable or disable fog.
--- Example: SetFogEnabled(false)  -- turn off fog
function SetFogEnabled(enabled)
    return SendCommand("SET_FOG_ENABLED " .. (enabled and "1" or "0"))
end

--- Set where fog starts (distance from camera).
--- Example: SetFogStart(500)
function SetFogStart(dist)
    return SendCommand("SET_FOG_START " .. tostring(dist))
end

--- Set where fog is fully opaque.
--- Example: SetFogEnd(2000)
function SetFogEnd(dist)
    return SendCommand("SET_FOG_END " .. tostring(dist))
end

--- Set fog density (0.0 to 1.0).
--- Example: SetFogDensity(0.01)
function SetFogDensity(density)
    return SendCommand("SET_FOG_DENSITY " .. tostring(density))
end

-- ── Entity Visuals ──

--- Set the scale of your character model.
--- Example: SetScale(2.0)   -- double size
--- Example: SetScale(0.5)   -- half size
function SetScale(scale)
    return SendCommand("SET_SCALE " .. tostring(scale))
end

--- Play an animation on your character.
--- Example: SetAnimation("dance")
function SetAnimation(anim_name)
    return SendCommand("SET_ANIM " .. tostring(anim_name))
end

--- Freeze or unfreeze player controls.
--- Example: SetFrozenState(true)  -- freeze
function SetFrozenState(frozen)
    return SendCommand("SET_FROZEN " .. (frozen and "1" or "0"))
end

-- ═══════════════════════════════════════════════════════════════
--  ADVANCED QUERIES
--  New Phase 5 commands for deeper game info.
-- ═══════════════════════════════════════════════════════════════

--- Check if a spell is FULLY ready (cooldown + mana + not silenced).
--- Returns a table: { ready, cd, mana_ok, silenced, cast_time, range }
--- Example:
---   local info = IsSpellFullyReady("Fireball")
---   if info.ready then CastSpell("Fireball") end
function IsSpellFullyReady(name)
    if not name then return { ready = false } end
    local raw = SendCommand("SPELL_IS_READY_FULL " .. name)
    if not raw or raw:find("^ERR:") then return { ready = false } end
    local t = {}
    for k, v in raw:gmatch("([%w_]+)=([^|]+)") do
        t[k] = tonumber(v) or v
    end
    t.ready = (t.ready == 1)
    t.mana_ok = (t.mana_ok == 1)
    t.silenced = (t.silenced == 1)
    return t
end

--- Get your condition states (rooted, silenced, stunned, etc).
--- Returns a table of booleans.
--- Example:
---   local cond = GetConditions()
---   if cond.silenced then Say("I'm silenced!") end
function GetConditions()
    local raw = SendCommand("PLAYER_CONDITIONS")
    if not raw or raw:find("^ERR:") then return {} end
    local t = {}
    for k, v in raw:gmatch("([%w_]+)=([^|]+)") do
        t[k] = (v == "1") or (tonumber(v) and tonumber(v) ~= 0) or false
    end
    return t
end

--- Check if you are rooted (can't move).
function IsRooted()
    local c = GetConditions()
    return c.rooted or false
end

--- Check if you are silenced (can't cast).
function IsSilenced()
    local c = GetConditions()
    return c.silenced or false
end

--- Get the last corpse you created (for manual looting).
--- Returns: { uid, x, y, z, corpse_of, container } or nil
function GetLastCorpse()
    local raw = SendCommand("LAST_CORPSE")
    if not raw or raw:find("^ERR:") then return nil end
    local t = {}
    for k, v in raw:gmatch("([%w_]+)=([^|]+)") do
        t[k] = tonumber(v) or v
    end
    return t
end

--- Get item modifications (sockets, enchants) for an item by UID.
--- Returns a list of { name, type, value, tier }
function GetItemMods(uid)
    local raw = SendCommand("ITEM_MODS " .. tostring(uid))
    if not raw or raw == "NONE" or raw:find("^ERR:") then return {} end
    local mods = {}
    for entry in raw:gmatch("[^#]+") do
        local m = {}
        for k, v in entry:gmatch("([%w_]+)=([^|]+)") do
            m[k] = tonumber(v) or v
        end
        if m.name then table.insert(mods, m) end
    end
    return mods
end

--- Get quest objectives for a named quest.
--- Returns a list of { id, title, type, complete, text }
function GetQuestObjectives(quest_name)
    local raw = SendCommand("QUEST_OBJECTIVES " .. tostring(quest_name))
    if not raw or raw:find("^ERR:") then return {} end
    local objectives = {}
    for entry in raw:gmatch("[^#]+") do
        local o = {}
        for k, v in entry:gmatch("([%w_]+)=([^|]+)") do
            o[k] = tonumber(v) or v
        end
        if o.title then
            o.complete = (o.complete == 1)
            table.insert(objectives, o)
        end
    end
    return objectives
end

-- ═══════════════════════════════════════════════════════════════
--  LEASH MODE
--  Stay within a set distance of a target player.
--  Not autofollow — only moves toward target if outside range.
-- ═══════════════════════════════════════════════════════════════

local _leash = {
    target_uid = nil,
    distance   = 10.0,
    active     = false,
}

--- Set the player UID to leash to.
--- Example: LeashTarget(12345)
function LeashTarget(uid)
    _leash.target_uid = uid
end

--- Set the max leash distance (float).
--- Example: LeashDistance(15.0)
function LeashDistance(range)
    _leash.distance = range or 10.0
end

--- Enable or disable leash mode.
--- Example: LeashActive(true)
function LeashActive(on)
    _leash.active = on and true or false
end

--- Get current leash state.
--- Returns: { active, target_uid, distance }
function GetLeashState()
    return {
        active     = _leash.active,
        target_uid = _leash.target_uid,
        distance   = _leash.distance,
    }
end

--- Call this in your main loop to enforce the leash.
--- Returns true if it moved toward the target.
--- Example:
---   while not ShouldStop() do
---       LeashCheck()
---       -- rest of your loop
---       Sleep(0.3)
---   end
function LeashCheck()
    if not _leash.active or not _leash.target_uid then return false end

    local nearby = GetNearbyAll()
    for _, ent in ipairs(nearby) do
        if ent.uid == _leash.target_uid then
            if ent.dist and ent.dist > _leash.distance then
                FollowRange(_leash.target_uid, _leash.distance)
                return true
            end
            return false
        end
    end
    -- Target not found nearby — try to follow anyway
    FollowRange(_leash.target_uid, _leash.distance)
    return true
end

-- ═══════════════════════════════════════════════════════════════
--  SAFETY MODE
--  Automatically stop scripts if other players are nearby.
--  Supports range filtering, known associates, and group ignore.
-- ═══════════════════════════════════════════════════════════════

local _safety = {
    active            = false,
    range             = 50.0,
    known_associates  = {},      -- names to ignore (friends/guildies)
    ignore_group      = false,   -- ignore party members
    safe_location     = nil,     -- {x, y} to move to when triggered
    wait_seconds      = 30,      -- how long to wait at safe location
    _triggered        = false,
    _trigger_time     = 0,
}

--- Enable or disable safety mode.
--- Example: SafetyActive(true)
function SafetyActive(on)
    _safety.active = on and true or false
end

--- Set the detection range for nearby players.
--- Example: SafetyRange(40.0)
function SafetyRange(range)
    _safety.range = range or 50.0
end

--- Set a list of known player names to ignore (friends, guildies).
--- Example: SafetyKnownAssociates({"FriendName1", "GuildMate2"})
function SafetyKnownAssociates(names)
    _safety.known_associates = {}
    if names then
        for _, n in ipairs(names) do
            _safety.known_associates[n] = true
        end
    end
end

--- Ignore party/group members in safety checks.
--- Example: SafetyIgnoreGroup(true)
function SafetyIgnoreGroup(on)
    _safety.ignore_group = on and true or false
end

--- Set an optional safe location to move to when triggered.
--- Example: SafetySetSafeLocation(100, 200, 60)
function SafetySetSafeLocation(x, y, wait_seconds)
    _safety.safe_location = { x = x, y = y }
    _safety.wait_seconds  = wait_seconds or 30
end

--- Get current safety state.
function GetSafetyState()
    return {
        active     = _safety.active,
        range      = _safety.range,
        triggered  = _safety._triggered,
        ignore_group = _safety.ignore_group,
    }
end

--- Check if unknown players are nearby (returns true = danger).
--- Filters out known associates and optionally party members.
--- Example: if PlayersNearby() then Say("Player spotted!") end
function PlayersNearby()
    if not _safety.active then return false end

    local raw = core.inventory.nearby_players()
    if not raw or raw == "NONE" then return false end

    -- Parse count header
    local count_str = raw:match("^count=(%d+)")
    if not count_str or tonumber(count_str) == 0 then return false end

    -- Get party member names for group ignore
    local party_names = {}
    if _safety.ignore_group then
        local party = GetPartyMembers()
        if party then
            for _, p in ipairs(party) do
                if p.name then party_names[p.name] = true end
            end
        end
    end

    -- Parse each player entry
    for entry in raw:gmatch("[^#]+") do
        local name = entry:match("name=([^|]+)")
        local dist = tonumber(entry:match("dist=([%d%.]+)"))
        if name and name ~= "?" and dist then
            if dist <= _safety.range then
                -- Check if this player is a known associate
                if not _safety.known_associates[name] then
                    -- Check if this player is in our party
                    if not party_names[name] then
                        return true
                    end
                end
            end
        end
    end
    return false
end

--- Call this in your main loop for full safety protection.
--- Will stop movement and return true if unsafe (script should pause).
--- Optionally moves to safe location and waits.
--- Example:
---   while not ShouldStop() do
---       if SafetyCheck() then
---           Sleep(1)  -- stay paused while unsafe
---       else
---           -- your normal bot logic
---       end
---       Sleep(0.3)
---   end
function SafetyCheck()
    if not _safety.active then return false end

    if PlayersNearby() then
        if not _safety._triggered then
            _safety._triggered = true
            _safety._trigger_time = Now()
            StopMoving()
            Warn("[Safety] Player detected nearby — pausing all activity")

            if _safety.safe_location then
                MoveTo(_safety.safe_location.x, _safety.safe_location.y)
            end
        end
        return true
    end

    -- Was triggered but no longer see players
    if _safety._triggered then
        local elapsed = TimeSince(_safety._trigger_time)
        if _safety.safe_location and elapsed < _safety.wait_seconds then
            return true  -- still waiting at safe location
        end
        _safety._triggered = false
        _safety._trigger_time = 0
        Say("[Safety] Area clear — resuming")
    end
    return false
end

-- ═══════════════════════════════════════════════════════════════
--  CONVENIENCE SHORTCUTS
--  Common patterns wrapped into single calls.
-- ═══════════════════════════════════════════════════════════════

--- A complete "stay alive" check — heals if HP is low.
--- heal_spell: name of your heal spell
--- hp_threshold: heal below this HP% (default 50)
--- Example: StayAlive("Stream of Life", 60)
function StayAlive(heal_spell, hp_threshold)
    hp_threshold = hp_threshold or 50
    if GetHP() < hp_threshold then
        return TryCast(heal_spell)
    end
    return false
end

--- Rest when out of combat and HP/MP is low.
--- Example: RestIfNeeded("Rest", 80, 50)
function RestIfNeeded(rest_spell, hp_threshold, mp_threshold)
    hp_threshold = hp_threshold or 80
    mp_threshold = mp_threshold or 50
    if not InCombat() then
        if GetHP() < hp_threshold or GetMP() < mp_threshold then
            return TryCast(rest_spell)
        end
    end
    return false
end
