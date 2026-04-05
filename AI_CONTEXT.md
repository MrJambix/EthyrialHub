# EthyrialHub Scripting API — AI Context File

**Paste this entire file into ChatGPT, Claude, or any AI assistant before asking it to write scripts.**

You are writing Lua scripts for EthyrialHub, a game automation tool for the MMORPG Ethyrial. Scripts use a simplified "Easy API" with plain English function names. No advanced Lua knowledge is needed.

---

## How Scripts Work

- Scripts are `.lua` files placed in the `scripts/` folder
- Every script starts with: `require("common/_api/ethy_easy")`
- After that line, all functions below are available as plain globals
- Scripts run in a loop that checks `ShouldStop()` and calls `Sleep()` each tick
- Comments start with `--`

## Basic Script Template

```lua
require("common/_api/ethy_easy")

Say("Script started!")

while not ShouldStop() do
    -- Your logic here

    Sleep(0.3)  -- REQUIRED: always sleep in loops
end

Say("Script stopped!")
```

## Event-Driven Template (for plugins)

```lua
require("common/_api/ethy_easy")

OnCombatStart(function()
    Say("Combat!")
end)

OnCombatEnd(function()
    After(0.5, function() LootAll() end)
end)

OnUpdate(function()
    -- Runs every frame
    if InCombat() and HasTarget() then
        TryCast("Fireball")
    end
end)
```

## Plugin Folder Format

For scripts with UI/settings, use a folder:
```
scripts/my_plugin/header.lua   -- metadata
scripts/my_plugin/main.lua     -- code
```

header.lua:
```lua
return {
    name = "My Plugin",
    description = "What it does",
    version = "1.0",
    author = "Name",
}
```

---

## COMPLETE FUNCTION LIST

### Printing
- `Say(...)` — Print message to log. Example: `Say("Hello!", GetHP())`
- `SayF(fmt, ...)` — Formatted print. Example: `SayF("HP: %d%%", GetHP())`
- `Warn(msg)` — Yellow warning message
- `Error(msg)` — Red error message

### Timing
- `Sleep(seconds)` — Pause script. Example: `Sleep(0.5)`
- `Now()` — Current time in seconds (float)
- `TimeSince(past_time)` — Seconds elapsed since a time
- `After(seconds, function)` — Run code after delay
- `ShouldStop()` — True when user clicks Stop

### Player Info (Your Character)
- `GetHP()` — Health % (0-100)
- `GetMP()` — Mana % (0-100)
- `GetMaxHP()` — Max health points
- `GetMaxMP()` — Max mana points
- `GetMyName()` — Character name string
- `GetMyClass()` — Class name (e.g. "Enchanter", "Ranger", "Assassin")
- `GetGold()` — Gold amount
- `GetSpeed()` — Movement speed
- `GetDirection()` — Facing (0-359 degrees)
- `GetAttackSpeed()` — Attack speed value
- `GetFood()` — Food/satiation level
- `GetCombatLevel()` — Combat level
- `GetProfessionLevel()` — Gathering/profession level
- `GetPhysicalArmor()` — Physical armor
- `GetMagicalArmor()` — Magical armor
- `GetPosition()` — Returns x, y, z (three numbers)

### Player State
- `InCombat()` — true if fighting
- `IsMoving()` — true if walking/running
- `IsDead()` — true if dead
- `IsFrozen()` — true if stunned/CC'd
- `InSafeZone()` — true if in protected zone
- `InWildlands()` — true if in PvP area

### Targeting
- `HasTarget()` — true if you have a target
- `GetTargetName()` — Target's name
- `GetTargetHP()` — Target's health %
- `GetTargetDistance()` — Distance to target
- `IsTargetBoss()` — true if target is a boss
- `IsTargetElite()` — true if target is elite
- `TargetNearest()` — Target nearest enemy
- `TargetByID(uid)` — Target specific entity
- `TargetPartyMember(index)` — Target party member (1, 2, 3...)
- `GetTargetInfo()` — Full target data table

### Spells & Casting
- `CastSpell(name)` — Cast spell, returns true on success
- `IsSpellReady(name)` — true if off cooldown + has mana
- `TryCast(name)` — Cast only if ready (MOST COMMON — use this)
- `GetCooldown(name)` — Remaining cooldown in seconds
- `GetAllSpells()` — List of all spells: `{name, category, ...}`
- `CastFirstReady({"Spell1", "Spell2", ...})` — Cast first ready from list, returns name or nil

### Buffs & Debuffs
- `HasBuff(name)` — true if buff is active
- `GetStacks(name)` — Number of stacks (0 if not active)
- `GetBuffInfo(name)` — Table: `{is_active, name, stacks, duration, max_duration}`
- `GetAllBuffs()` — List of all active buffs
- `IsBuffExpiring(name, seconds)` — true if buff expires within X seconds (default 3)
- `MaintainBuff(buff_name, spell_name, threshold)` — Auto-refresh buff if missing/expiring

### Enemies & Scanning
- `GetNearbyEnemies(range)` — List of enemies within range (default 50). Each: `{name, hp, distance, uid, classification}`
- `CountNearbyEnemies(range)` — Count of nearby enemies
- `GetNearbyAll()` — All entities (enemies, NPCs, objects)
- `GetEntityByID(uid)` — Get entity by unique ID

### Party
- `GetPartyMembers()` — List of members: `{name, hp, uid, ...}`
- `GetPartySize()` — Number of party members
- `GetLowestPartyMember()` — Member with lowest HP (for healers)

### Movement
- `MoveTo(x, y)` — Walk to coordinates
- `MoveToTarget()` — Walk toward target
- `StopMoving()` — Stop movement
- `Follow(uid)` — Follow entity by ID

### Inventory & Loot
- `LootAll()` — Loot everything
- `GetInventory()` — Full item list: `{uid, name, stack, rarity, category, ...}`
- `GetInventoryCount()` — Total items
- `UseItem(uid)` — Use item by ID
- `EquipItem(uid)` — Equip item by ID
- `GetEquipped()` — Currently equipped items

### Gathering (Resources)
- `GatherNearest(filter)` — Gather nearest node. Filter is optional name like "Iron"
- `ScanHerbs()` — List of herb nodes
- `ScanOres()` — List of ore nodes
- `ScanTrees()` — List of tree nodes
- `ScanSkins()` — List of skinning nodes
- `ScanFishingSpots()` — List of fishing spots
- `ScanAllNodes(filter)` — All nodes, optional filter
- `ScanUsableNodes(filter)` — Only nodes you can interact with

### Social
- `SendChat(message)` — Send chat message
- `GetNearbyPlayers()` — List of nearby players

### Loot Rolling
- `GetLootRolls()` — Pending roll windows
- `GreedAll()` — Greed on all rolls

### Events (Callbacks)
- `OnUpdate(function)` — Called every frame (main tick)
- `OnCombatStart(function)` — When combat begins
- `OnCombatEnd(function)` — When combat ends
- `OnBuffGained(function(name))` — When a buff is applied
- `OnBuffLost(function(name))` — When a buff expires
- `OnTargetChanged(function)` — When target changes
- `OnSpellCast(function(name))` — After casting a spell

### Humanization (Anti-Detection)
- `HumanDelay()` — Random ~250ms pause
- `RandomPause(min, max)` — Random pause between min and max seconds
- `ShouldMisplay(chance)` — Random true/false for "mistakes" (default 3%)

### Convenience Shortcuts
- `DoRotation({"Spell1", "Spell2"})` — Cast first ready + log it
- `StayAlive("HealSpell", hp_threshold)` — Auto-heal below HP% (default 50)
- `RestIfNeeded("Rest", hp_thresh, mp_thresh)` — Rest when idle and low

### Raw Command (Advanced)
- `SendCommand(cmd)` — Send raw IPC command string, returns raw response

---

## GAME CLASSES

Ethyrial has these classes: Enchanter, Ranger, Assassin, Spellblade, Earthguard, Guardian, Illusionist, Druid, Shadowcaster, Berserker, Brawler, Demonknight

## SPELL CATEGORIES

Spells have categories: Damage, AoE, Heal, Shield, Buff, CC, DoT, Channel, Pet, Burst, Utility, Defensive, Rest, Gapcloser

## BUFF TYPES

Buffs have types: Buff, Debuff, DoT, HoT, Shield, Proc, CC, Passive, Food, Immunity

## ENEMY CLASSIFICATIONS

Enemies can be: Normal, Elite, Rare, Boss, Critter

---

## IMPORTANT RULES FOR AI

1. **Always start with:** `require("common/_api/ethy_easy")`
2. **Always use `Sleep()` in loops** — without it the script freezes
3. **Use `TryCast()` instead of `CastSpell()`** — it checks if ready first
4. **Spell names are INTERNAL names**, not display names. Ask the user for their spell names or suggest they run `GetAllSpells()` to find them
5. **Always check `ShouldStop()` in while loops** so the user can stop the script
6. **Use `while not ShouldStop() do ... Sleep(0.3) end`** as the main loop pattern
7. **All functions are global** — no table prefixes needed, just `GetHP()` not `something.GetHP()`
8. **Lua uses `~=` for "not equal"**, not `!=`
9. **Lua uses `and`/`or`/`not`**, not `&&`/`||`/`!`
10. **Lua tables start at index 1**, not 0
11. **String concatenation uses `..`**, not `+`
12. **`#list` gives the length** of a list/table

## COMMON PATTERNS

### Priority-based rotation:
```lua
-- Cast the highest priority spell that's ready
if TryCast("Emergency Heal") then return end
if TryCast("Big Cooldown") then return end
if TryCast("DoT Spell") then return end
if TryCast("Filler Spam") then return end
```

### Stack-gated spell:
```lua
if GetStacks("FuryStatus") >= 4 then
    TryCast("Fury Strike")
end
```

### Buff-gated spell:
```lua
if HasBuff("SomeProc") then
    TryCast("Special Attack")
end
```

### Buff maintenance:
```lua
MaintainBuff("Stormshield")
MaintainBuff("ImbueMindClarity", "Imbue Mind: Clarity")
```

### Auto-loot after combat:
```lua
OnCombatEnd(function()
    After(0.5, function() LootAll() end)
end)
```

### Party healer logic:
```lua
local wounded = GetLowestPartyMember()
if wounded and wounded.hp < 50 then
    TargetByID(wounded.uid)
    TryCast("Heal")
end
```
