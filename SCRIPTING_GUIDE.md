# EthyrialHub Scripting Guide

**For non-programmers and AI-assisted script writing**

This guide teaches you how to write Lua scripts for EthyrialHub from scratch. No programming experience needed. You can also copy this into ChatGPT, Claude, or any AI assistant to help you write scripts.

---

## Table of Contents

1. [What is a Script?](#what-is-a-script)
2. [Your First Script](#your-first-script)
3. [The Basics of Lua](#the-basics-of-lua)
4. [The Easy API (Recommended)](#the-easy-api)
5. [Common Patterns](#common-patterns)
6. [Complete Function Reference](#complete-function-reference)
7. [Making a Combat Rotation](#making-a-combat-rotation)
8. [Making a Gathering Bot](#making-a-gathering-bot)
9. [Making a Buff Manager](#making-a-buff-manager)
10. [Plugin Format (Multi-File Scripts)](#plugin-format)
11. [Tips for Using AI to Write Scripts](#tips-for-using-ai)
12. [Troubleshooting](#troubleshooting)

---

## What is a Script?

A script is a text file ending in `.lua` that tells EthyrialHub what to do in the game. Scripts can:

- **Cast spells automatically** (combat rotations)
- **Gather resources** (herbs, ore, wood, fish)
- **Monitor your character** (health, buffs, enemies)
- **Loot automatically** after kills
- **Maintain buffs** (re-cast when they expire)
- **Show information** (nearby enemies, party health)

Scripts are placed in the `scripts/` folder and started from the Hub interface.

---

## Your First Script

Create a new file called `my_first_script.lua` in the `scripts/` folder. Paste this:

```lua
-- This is my first script!
-- Lines starting with -- are comments (notes for humans, ignored by the game)

require("common/_api/ethy_easy")

Say("Hello! My script is running!")
Say("My name is: " .. GetMyName())
Say("My class is: " .. GetMyClass())
Say("HP: " .. GetHP() .. "%")
Say("MP: " .. GetMP() .. "%")

if InCombat() then
    Say("I'm in combat!")
else
    Say("I'm not in combat")
end

Say("Script finished!")
```

That's it! When you run this script, it will print your character info to the Hub log.

---

## The Basics of Lua

You don't need to learn a whole programming language. Here are the only things you need:

### Comments (notes to yourself)

```lua
-- This is a comment. The game ignores it.
-- Use comments to explain what your code does.
```

### Variables (storing values)

```lua
local myHP = GetHP()          -- Store your HP in a variable
local myName = GetMyName()    -- Store your name
local healAt = 50             -- A number you choose
```

### If/Then (making decisions)

```lua
if GetHP() < 50 then
    Say("Low health!")
end

-- With "else" (otherwise):
if InCombat() then
    Say("Fighting!")
else
    Say("Chilling")
end

-- Multiple conditions with "and" / "or":
if InCombat() and GetHP() < 30 then
    CastSpell("Emergency Heal")
end

if GetHP() < 50 or GetMP() < 20 then
    Say("Need to rest!")
end
```

### Loops (repeating actions)

```lua
-- Keep running until the user clicks Stop:
while not ShouldStop() do
    -- Your code here (runs over and over)

    Sleep(0.3)  -- IMPORTANT: always sleep to avoid freezing!
end
```

### Lists (multiple items)

```lua
-- A list of spell names:
local mySpells = {
    "Fireball",
    "Ice Bolt",
    "Lightning",
}

-- Go through each spell in the list:
for _, spellName in ipairs(mySpells) do
    Say("I have spell: " .. spellName)
end
```

### Functions (reusable blocks)

```lua
-- Define a function:
local function healIfNeeded()
    if GetHP() < 50 then
        CastSpell("Heal")
        Say("Healing!")
    end
end

-- Call it whenever you want:
healIfNeeded()
```

### Joining text together

```lua
-- Use .. to join text:
Say("Hello " .. GetMyName() .. "! You have " .. GetHP() .. "% HP")
```

That's all the Lua you need to know!

---

## The Easy API

The Easy API is our simplified wrapper. It gives you plain English function names with no confusing syntax.

**To use it, add this line at the top of every script:**

```lua
require("common/_api/ethy_easy")
```

After that line, all functions are available as simple names like `GetHP()`, `CastSpell()`, `InCombat()`, etc. No `local E =` prefix needed — just the bare `require`.

### Quick Example

```lua
require("common/_api/ethy_easy")

while not ShouldStop() do
    if InCombat() and HasTarget() then
        if GetHP() < 50 then
            TryCast("Heal")
        else
            TryCast("Fireball")
        end
    end
    Sleep(0.3)
end
```

---

## Common Patterns

### Pattern 1: The Main Loop

Almost every script follows this pattern:

```lua
require("common/_api/ethy_easy")

Say("Script started!")

while not ShouldStop() do
    -- Your logic goes here

    Sleep(0.3)  -- Check 3 times per second
end

Say("Script stopped!")
```

### Pattern 2: Cast First Ready Spell

```lua
local mySpells = {"Big Hit", "Medium Hit", "Small Hit"}
CastFirstReady(mySpells)  -- Tries each one, casts the first that's ready
```

### Pattern 3: Heal When Low

```lua
StayAlive("Heal Spell Name", 50)  -- Heals below 50% HP
```

### Pattern 4: Maintain Buffs

```lua
MaintainBuff("Stormshield")  -- Re-casts if missing or about to expire
```

### Pattern 5: Rest When Idle

```lua
RestIfNeeded("Rest", 80, 50)  -- Rest below 80% HP or 50% MP
```

### Pattern 6: React to Events

```lua
OnCombatStart(function()
    Say("Fight started!")
end)

OnCombatEnd(function()
    Say("Fight over!")
    After(0.5, function()
        LootAll()
    end)
end)
```

---

## Complete Function Reference

### Printing & Logging

| Function | What it does | Example |
|----------|-------------|---------|
| `Say(...)` | Print a message to the log | `Say("Hello!")` |
| `SayF(fmt, ...)` | Print formatted message | `SayF("HP: %d%%", GetHP())` |
| `Warn(msg)` | Print a yellow warning | `Warn("Low health!")` |
| `Error(msg)` | Print a red error | `Error("Something broke!")` |

### Timing

| Function | What it does | Example |
|----------|-------------|---------|
| `Sleep(seconds)` | Pause the script | `Sleep(0.5)` |
| `Now()` | Current time in seconds | `local t = Now()` |
| `TimeSince(time)` | Seconds since a time | `if TimeSince(t) > 5 then` |
| `After(sec, fn)` | Run code after a delay | `After(1, function() Say("!") end)` |
| `ShouldStop()` | Is the script stopping? | `while not ShouldStop() do` |

### Your Character

| Function | What it does | Returns |
|----------|-------------|---------|
| `GetHP()` | Health percentage | 0 to 100 |
| `GetMP()` | Mana percentage | 0 to 100 |
| `GetMaxHP()` | Maximum health points | number |
| `GetMaxMP()` | Maximum mana points | number |
| `GetMyName()` | Character name | text |
| `GetMyClass()` | Class/job name | text like "Ranger" |
| `GetGold()` | Gold amount | number |
| `GetSpeed()` | Movement speed | number |
| `GetDirection()` | Facing direction | 0 to 359 |
| `GetAttackSpeed()` | Attack speed | number |
| `GetFood()` | Food/satiation | number |
| `GetCombatLevel()` | Combat level | number |
| `GetProfessionLevel()` | Gathering level | number |
| `GetPhysicalArmor()` | Physical armor | number |
| `GetMagicalArmor()` | Magical armor | number |
| `GetPosition()` | X, Y, Z coordinates | three numbers |

### Your State

| Function | What it does | Returns |
|----------|-------------|---------|
| `InCombat()` | Are you fighting? | true/false |
| `IsMoving()` | Are you walking? | true/false |
| `IsDead()` | Are you dead? | true/false |
| `IsFrozen()` | Are you stunned/CC'd? | true/false |
| `InSafeZone()` | In a protected zone? | true/false |
| `InWildlands()` | In PvP area? | true/false |

### Targeting

| Function | What it does | Example |
|----------|-------------|---------|
| `HasTarget()` | Do you have a target? | `if HasTarget() then` |
| `GetTargetName()` | Target's name | `Say(GetTargetName())` |
| `GetTargetHP()` | Target's health % | `if GetTargetHP() < 20 then` |
| `GetTargetDistance()` | Distance to target | `if GetTargetDistance() < 30 then` |
| `IsTargetBoss()` | Is it a boss? | `if IsTargetBoss() then` |
| `IsTargetElite()` | Is it elite? | `if IsTargetElite() then` |
| `TargetNearest()` | Target nearest enemy | `TargetNearest()` |
| `TargetByID(uid)` | Target by ID | `TargetByID(12345)` |
| `TargetPartyMember(n)` | Target party member | `TargetPartyMember(1)` |

### Spells

| Function | What it does | Example |
|----------|-------------|---------|
| `CastSpell(name)` | Cast a spell | `CastSpell("Fireball")` |
| `IsSpellReady(name)` | Is it off cooldown? | `if IsSpellReady("Heal") then` |
| `TryCast(name)` | Cast only if ready | `TryCast("Fireball")` |
| `GetCooldown(name)` | Seconds until ready | `Say(GetCooldown("Heal"))` |
| `GetAllSpells()` | List all your spells | `local spells = GetAllSpells()` |
| `CastFirstReady(list)` | Cast first ready from list | `CastFirstReady({"A","B","C"})` |

### Buffs

| Function | What it does | Example |
|----------|-------------|---------|
| `HasBuff(name)` | Is buff active? | `if HasBuff("Shield") then` |
| `GetStacks(name)` | Stack count | `if GetStacks("Fury") >= 4 then` |
| `GetBuffInfo(name)` | Detailed buff data | `local b = GetBuffInfo("Shield")` |
| `IsBuffExpiring(name, sec)` | Expiring within X sec? | `if IsBuffExpiring("Shield", 3) then` |
| `MaintainBuff(buff, spell)` | Auto-refresh a buff | `MaintainBuff("Stormshield")` |

### Enemies & Scanning

| Function | What it does | Example |
|----------|-------------|---------|
| `GetNearbyEnemies(range)` | List enemies nearby | `local e = GetNearbyEnemies(40)` |
| `CountNearbyEnemies(range)` | Count enemies | `if CountNearbyEnemies(30) > 3 then` |
| `GetNearbyAll()` | All entities nearby | `local all = GetNearbyAll()` |
| `GetEntityByID(uid)` | Find entity by ID | `local e = GetEntityByID(123)` |

### Party

| Function | What it does | Example |
|----------|-------------|---------|
| `GetPartyMembers()` | List party members | `local party = GetPartyMembers()` |
| `GetPartySize()` | Party member count | `Say("Party: " .. GetPartySize())` |
| `GetLowestPartyMember()` | Weakest member | `local w = GetLowestPartyMember()` |

### Movement

| Function | What it does | Example |
|----------|-------------|---------|
| `MoveTo(x, y)` | Walk to position | `MoveTo(100, 200)` |
| `MoveToTarget()` | Walk to target | `MoveToTarget()` |
| `StopMoving()` | Stop walking | `StopMoving()` |
| `Follow(uid)` | Follow an entity | `Follow(12345)` |

### Inventory & Loot

| Function | What it does | Example |
|----------|-------------|---------|
| `LootAll()` | Loot everything | `LootAll()` |
| `GetInventory()` | Full inventory list | `local inv = GetInventory()` |
| `GetInventoryCount()` | Item count | `Say(GetInventoryCount() .. " items")` |
| `UseItem(uid)` | Use an item | `UseItem(12345)` |
| `EquipItem(uid)` | Equip an item | `EquipItem(12345)` |
| `GetEquipped()` | Equipped gear list | `local gear = GetEquipped()` |

### Gathering

| Function | What it does | Example |
|----------|-------------|---------|
| `GatherNearest(filter)` | Gather nearest node | `GatherNearest("Iron")` |
| `ScanHerbs()` | Find herb nodes | `local herbs = ScanHerbs()` |
| `ScanOres()` | Find mining nodes | `local ores = ScanOres()` |
| `ScanTrees()` | Find trees | `local trees = ScanTrees()` |
| `ScanSkins()` | Find skinning nodes | `local skins = ScanSkins()` |
| `ScanFishingSpots()` | Find fishing spots | `local fish = ScanFishingSpots()` |
| `ScanAllNodes(filter)` | Find any node type | `local nodes = ScanAllNodes()` |
| `ScanUsableNodes(filter)` | Nodes you can use | `local ok = ScanUsableNodes()` |

### Social

| Function | What it does | Example |
|----------|-------------|---------|
| `SendChat(msg)` | Send chat message | `SendChat("Hello!")` |
| `GetNearbyPlayers()` | Players near you | `local p = GetNearbyPlayers()` |

### Loot Rolling

| Function | What it does | Example |
|----------|-------------|---------|
| `GetLootRolls()` | Pending roll windows | `local rolls = GetLootRolls()` |
| `GreedAll()` | Greed on everything | `GreedAll()` |

### Events (Callbacks)

| Function | What it does | Example |
|----------|-------------|---------|
| `OnUpdate(fn)` | Run every frame | `OnUpdate(function() ... end)` |
| `OnCombatStart(fn)` | When combat begins | `OnCombatStart(function() ... end)` |
| `OnCombatEnd(fn)` | When combat ends | `OnCombatEnd(function() ... end)` |
| `OnBuffGained(fn)` | When you get a buff | `OnBuffGained(function(name) ... end)` |
| `OnBuffLost(fn)` | When a buff expires | `OnBuffLost(function(name) ... end)` |
| `OnTargetChanged(fn)` | When target changes | `OnTargetChanged(function() ... end)` |
| `OnSpellCast(fn)` | After casting a spell | `OnSpellCast(function(name) ... end)` |

### Humanization

| Function | What it does | Example |
|----------|-------------|---------|
| `HumanDelay()` | Random ~250ms pause | `HumanDelay()` |
| `RandomPause(min, max)` | Random pause | `RandomPause(0.5, 2.0)` |
| `ShouldMisplay(chance)` | Random "mistake" | `if ShouldMisplay() then Sleep(1) end` |

### Utility

| Function | What it does | Example |
|----------|-------------|---------|
| `GetCameraDistance()` | Zoom distance | `Say(GetCameraDistance())` |
| `Distance3D(...)` | 3D distance | `Distance3D(x1,y1,z1, x2,y2,z2)` |
| `Distance2D(...)` | 2D distance | `Distance2D(x1,z1, x2,z2)` |
| `SendCommand(cmd)` | Raw IPC command | `SendCommand("PLAYER_HP")` |

---

## Making a Combat Rotation

A combat rotation casts spells in priority order. Here's a complete template:

```lua
require("common/_api/ethy_easy")

Say("Combat Rotation Started!")

-- =============================================
-- STEP 1: List your spells in priority order
-- (highest priority first)
-- =============================================
local EMERGENCY_HEAL = "Cleansing Waters"   -- use when HP is critical
local MAIN_HEAL      = "Stream of Life"     -- use when HP is low
local BUFF_SPELL     = "Stormshield"        -- keep this buff active
local DOT_SPELL      = "Debilitating Waters" -- damage over time
local BIG_DAMAGE     = "Tempest"            -- heavy cooldown
local AOE_SPELL      = "Storm of Haste"     -- area damage
local FILLER         = "Stormbolt"          -- spam this

-- =============================================
-- STEP 2: Set your thresholds
-- =============================================
local EMERGENCY_HP = 30   -- use emergency heal below this %
local HEAL_HP      = 55   -- use normal heal below this %
local REST_HP      = 75   -- rest out of combat below this %
local REST_MP      = 50   -- rest out of combat below this mana %
local SAVE_MANA    = 20   -- stop DPS below this mana %

-- =============================================
-- STEP 3: Main loop (don't change this part)
-- =============================================
while not ShouldStop() do
    -- Skip if dead or frozen
    if not IsDead() and not IsFrozen() then
        local hp = GetHP()
        local mp = GetMP()

        if InCombat() and HasTarget() then
            -- EMERGENCY: Heal if very low HP
            if hp < EMERGENCY_HP then
                TryCast(EMERGENCY_HEAL)
            end

            -- HEAL: Normal heal if HP is low
            if hp < HEAL_HP then
                TryCast(MAIN_HEAL)
            end

            -- BUFFS: Keep buffs active
            MaintainBuff(BUFF_SPELL)

            -- SAVE MANA: Stop DPS if mana is too low
            if mp > SAVE_MANA then
                -- DPS PRIORITY LIST:
                TryCast(BIG_DAMAGE)    -- try big cooldown first
                TryCast(DOT_SPELL)     -- then DoT
                TryCast(AOE_SPELL)     -- then AoE
                TryCast(FILLER)        -- then spam filler
            end

        else
            -- OUT OF COMBAT:
            MaintainBuff(BUFF_SPELL)
            RestIfNeeded("Rest", REST_HP, REST_MP)
        end
    end

    Sleep(0.3)
end
```

### How to customize it:

1. **Change the spell names** to match YOUR class's spells
2. **Change the HP/MP thresholds** to match your preference
3. **Reorder the priority** (move important spells higher up)
4. **Add more spells** by adding more `TryCast("SpellName")` lines
5. **Add stack-based spells:**

```lua
if GetStacks("FuryStatus") >= 4 then
    TryCast("Fury Strike")
end
```

6. **Add buff-gated spells:**

```lua
if HasBuff("SomeProc") then
    TryCast("Special Attack")
end
```

---

## Making a Gathering Bot

```lua
require("common/_api/ethy_easy")

Say("Gathering Bot Started!")

-- What to gather (change to "Ore", "Tree", "Herb", etc.)
local GATHER_TYPE = "Ore"

while not ShouldStop() do
    -- Don't gather while in combat!
    if not InCombat() then
        GatherNearest(GATHER_TYPE)
        Sleep(1)  -- Wait for gathering animation
    else
        -- If something attacks us, fight back
        if HasTarget() then
            TryCast("Stormbolt")
        end
        Sleep(0.3)
    end
end
```

### Smarter version with scanning:

```lua
require("common/_api/ethy_easy")

Say("Smart Gatherer Started!")

while not ShouldStop() do
    if not InCombat() then
        -- Scan for usable ore nodes
        local nodes = ScanUsableNodes("Iron")

        if #nodes > 0 then
            SayF("Found %d nodes!", #nodes)
            GatherNearest("Iron")
            Sleep(2)  -- Wait for gather
        else
            Say("No nodes found, waiting...")
            Sleep(5)  -- Wait and scan again
        end
    else
        Sleep(0.5)
    end
end
```

---

## Making a Buff Manager

```lua
require("common/_api/ethy_easy")

Say("Buff Manager Started!")

-- List your buffs here:
-- Each line: { buff name to check, spell name to cast }
local MY_BUFFS = {
    { buff = "Stormshield",       spell = "Stormshield" },
    { buff = "ImbueMindClarity",  spell = "Imbue Mind: Clarity" },
    { buff = "GustOfAlacrity",    spell = "Gust of Alacrity" },
}

while not ShouldStop() do
    for _, entry in ipairs(MY_BUFFS) do
        if not HasBuff(entry.buff) then
            if TryCast(entry.spell) then
                SayF("Re-applied: %s", entry.spell)
                Sleep(0.5)  -- Brief pause between casts
            end
        end
    end

    Sleep(1)  -- Check every second
end
```

---

## Plugin Format

For scripts with a settings UI, use a folder with two files:

```
scripts/
  my_plugin/
    header.lua    -- Name & description
    main.lua      -- Your code
```

**header.lua:**

```lua
return {
    name        = "My Cool Plugin",
    description = "Does cool things automatically",
    version     = "1.0",
    author      = "YourName",
}
```

**main.lua:** (same as any script, just in a folder)

```lua
require("common/_api/ethy_easy")

Say("My plugin loaded!")

-- Your code here...
```

---

## Tips for Using AI to Write Scripts

When asking ChatGPT, Claude, or any AI to write scripts for you:

### 1. Give the AI the context file

Copy the contents of `AI_CONTEXT.md` (in this same folder) and paste it into your AI conversation first. This tells the AI exactly what functions are available.

### 2. Be specific about what you want

**Bad:** "Make me a script"
**Good:** "Make me an Enchanter rotation script that casts Stormshield when it's not active, uses Tempest on cooldown, and spams Stormbolt as filler. Heal with Stream of Life below 50% HP."

### 3. Tell the AI your class and spells

"My class is Ranger. My spells are: Arrow Shot, Piercing Arrow, Rain of Arrows, Spirit Link Arrow, Nature's Gift, Rest"

### 4. Tell the AI about conditions

"Cast Fury Strike only when I have 4 or more Fury stacks"
"Use Emergency Heal when below 30% HP"
"Don't DPS when mana is below 20%"

### 5. Ask for the Easy API

"Use the EthyEasy API with functions like TryCast(), GetHP(), InCombat(), etc."

---

## Troubleshooting

### "attempt to call a nil value"

This means you tried to use a function that doesn't exist. Check:
- Did you add `require("common/_api/ethy_easy")` at the top?
- Is the function name spelled correctly? (names are case-sensitive!)

### "module not found"

The require path is wrong. It should be exactly:
```lua
require("common/_api/ethy_easy")
```

### Script does nothing

- Make sure you have `Sleep()` in your loop (without it, the script freezes)
- Make sure your conditions are correct (are you actually in combat? do you have a target?)
- Add `Say()` messages to debug: `Say("HP is: " .. GetHP())`

### Spells don't cast

- Make sure you're using the **internal spell name**, not the display name
- To find internal names: go to Dev Tools > Raw IPC > type `SPELLS_ALL`
- Check if the spell is on cooldown: `Say(GetCooldown("SpellName"))`

### Script runs too fast / too slow

Adjust the `Sleep()` time:
- `Sleep(0.1)` = very fast (10 times/sec) — use for combat rotations
- `Sleep(0.3)` = normal (3 times/sec) — good default
- `Sleep(1.0)` = slow (once/sec) — good for gathering/buff checking

### "Two ways to do the same thing?"

Yes! There are two APIs:
- **Easy API** (`ethy_easy`) — Simple names, recommended for beginners
- **Full SDK** (`ethy_sdk` / `core.*`) — More control, for advanced users

Both work. The Easy API calls the Full SDK under the hood. Use whichever you're comfortable with.

---

## Finding Your Spell & Buff Names

This is the most common question! Spell and buff names used in scripts are **internal names**, which are sometimes different from what you see in-game.

### Method 1: Dev Tools (In-Hub)

1. Open the Hub
2. Go to Dev Tools > Raw IPC
3. Type `SPELLS_ALL` and press Enter
4. Each line shows: `name=InternalName|display=Display Name|...`
5. Use the `name=` value in your scripts

### Method 2: Run the Spell Checker Script

Run the built-in example script `05_spell_checker.lua` — it lists all your spells.

### Method 3: For Buffs

1. Get into combat or apply buffs
2. In Dev Tools > Raw IPC, type `PLAYER_STATUS_EFFECTS`
3. Use the `name=` value from the output

---

*Last updated: 2026-04-05*
*Works with EthyrialHub Easy API v1.0*
