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

--- Get your attack speed value.
function GetAttackSpeed()
    return tonumber(core.player.attack_speed()) or 0
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

--- Move toward your current target.
function MoveToTarget()
    return core.movement.move_to_target()
end

--- Stop all movement.
function StopMoving()
    return core.movement.stop()
end

--- Follow an entity by its unique ID.
function Follow(uid)
    return core.movement.follow_entity(uid)
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

--- Scan for skinning nodes nearby.
function ScanSkins()
    return core.gathering.scan_skins() or {}
end

--- Scan for fishing spots nearby.
function ScanFishingSpots()
    return core.gathering.fishing_spots() or {}
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
