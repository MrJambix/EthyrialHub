--[[
╔══════════════════════════════════════════════════════════════╗
║        FULL ROTATION TEMPLATE — Easy API Version             ║
║                                                              ║
║  A complete combat rotation with:                            ║
║  - Emergency healing                                         ║
║  - Buff maintenance                                          ║
║  - Stack-based spells                                        ║
║  - DPS priority list                                         ║
║  - Mana conservation                                         ║
║  - Out-of-combat resting                                     ║
║  - Auto-looting                                              ║
║                                                              ║
║  Copy this file and change the spell names for your class!   ║
╚══════════════════════════════════════════════════════════════╝

  HOW TO FIND YOUR SPELL NAMES:
  1. In the Hub, go to Dev Tools > Raw IPC
  2. Type SPELLS_ALL and press Enter
  3. Use the "name=" value (internal name) in the tables below

  HOW TO FIND YOUR BUFF NAMES:
  1. Apply your buffs, then in Dev Tools > Raw IPC
  2. Type PLAYER_STATUS_EFFECTS
  3. Use the "name=" value in the tables below
]]

require("common/_api/ethy_easy")

-- ═════════════════════════════════════════════════════════════
-- STEP 1: YOUR SPELL NAMES (change these!)
-- ═════════════════════════════════════════════════════════════

local EMERGENCY_HEAL = "CleansingWaters"    -- panic heal
local MAIN_HEAL      = "StreamOfLife"       -- normal heal
local BIG_DAMAGE     = "Tempest"            -- heavy cooldown
local DOT_SPELL      = "DebilitatingWaters" -- damage over time
local AOE_SPELL      = "StormOfHaste"       -- area damage
local FILLER         = "Stormbolt"          -- spammable filler
local REST_SPELL     = "Rest"               -- out-of-combat rest

-- ═════════════════════════════════════════════════════════════
-- STEP 2: YOUR BUFF NAMES (change these!)
-- Each entry: { buff = "BuffInternalName", spell = "SpellToCast" }
-- ═════════════════════════════════════════════════════════════

local MY_BUFFS = {
    { buff = "Stormshield",      spell = "Stormshield" },
    { buff = "ImbueMindClarity", spell = "Imbue Mind: Clarity" },
}

-- ═════════════════════════════════════════════════════════════
-- STEP 3: YOUR THRESHOLDS (tune these to your playstyle)
-- ═════════════════════════════════════════════════════════════

local EMERGENCY_HP = 30   -- emergency heal below this %
local HEAL_HP      = 55   -- normal heal below this %
local SAVE_MANA    = 20   -- stop DPS below this mana %
local REST_HP      = 80   -- rest out of combat below this %
local REST_MP      = 50   -- rest out of combat below this mana %

-- ═════════════════════════════════════════════════════════════
-- STEP 4: STACK-BASED SPELLS (optional, delete if not needed)
-- Example: cast "FuryStrike" when you have 4+ Fury stacks
-- ═════════════════════════════════════════════════════════════

local STACK_SPELLS = {
    -- { stack_name = "FuryStatus", min_stacks = 4, spell = "FuryStrike" },
    -- { stack_name = "SpiritLink", min_stacks = 3, spell = "SpiritburstArrow" },
}

-- ═════════════════════════════════════════════════════════════
-- AUTO-LOOT: Loot after every kill
-- ═════════════════════════════════════════════════════════════

local lootCount = 0
OnCombatEnd(function()
    After(0.5, function()
        LootAll()
        lootCount = lootCount + 1
    end)
end)

-- ═════════════════════════════════════════════════════════════
-- HELPER: Maintain all buffs
-- ═════════════════════════════════════════════════════════════

local function maintainAllBuffs()
    for _, entry in ipairs(MY_BUFFS) do
        if MaintainBuff(entry.buff, entry.spell, 5) then
            return true  -- cast something, wait for next tick
        end
    end
    return false
end

-- ═════════════════════════════════════════════════════════════
-- HELPER: Check stack-based spells
-- ═════════════════════════════════════════════════════════════

local function checkStackSpells()
    for _, entry in ipairs(STACK_SPELLS) do
        if GetStacks(entry.stack_name) >= entry.min_stacks then
            if TryCast(entry.spell) then
                SayF("Stack cast: %s (%d stacks)", entry.spell, entry.min_stacks)
                return true
            end
        end
    end
    return false
end

-- ═════════════════════════════════════════════════════════════
-- MAIN LOOP
-- ═════════════════════════════════════════════════════════════

Say("╔══════════════════════════════════════╗")
Say("║  Rotation Template (Easy API)        ║")
Say("║  Edit spell names above for your     ║")
Say("║  class, then start the script!       ║")
Say("╚══════════════════════════════════════╝")

while not ShouldStop() do
    -- Skip if dead or stunned
    if not IsDead() and not IsFrozen() then
        local hp = GetHP()
        local mp = GetMP()

        if InCombat() and HasTarget() then
            -- PRIORITY 1: Emergency heal
            if hp < EMERGENCY_HP then
                TryCast(EMERGENCY_HEAL)
            end

            -- PRIORITY 2: Normal heal
            if hp < HEAL_HP then
                TryCast(MAIN_HEAL)
            end

            -- PRIORITY 3: Buff upkeep
            maintainAllBuffs()

            -- PRIORITY 4: Stack-based spells
            checkStackSpells()

            -- PRIORITY 5: DPS (only if mana allows)
            if mp > SAVE_MANA then
                TryCast(BIG_DAMAGE)
                TryCast(DOT_SPELL)
                TryCast(AOE_SPELL)
                TryCast(FILLER)
            else
                Say("Low mana, conserving...")
            end

        else
            -- OUT OF COMBAT
            maintainAllBuffs()
            RestIfNeeded(REST_SPELL, REST_HP, REST_MP)
        end
    end

    Sleep(0.3)
end
