--[[
  Easy Example 02 — Simple Combat Rotation
  Casts spells in priority order during combat.

  HOW TO CUSTOMIZE:
  1. Change the spell names in MY_SPELLS to your class's spells
  2. Change HEAL_SPELL to your heal ability
  3. Adjust HEAL_AT to change when healing triggers
]]

require("common/_api/ethy_easy")

Say("=== Combat Rotation Started! ===")

-- =============================================
-- CHANGE THESE TO YOUR SPELLS:
-- =============================================
local MY_SPELLS = {
    "Tempest",              -- big cooldown (highest priority)
    "Storm of Haste",       -- AoE damage
    "Debilitating Waters",  -- DoT
    "Stormbolt",            -- filler (lowest priority)
}

local HEAL_SPELL = "Stream of Life"
local HEAL_AT    = 50   -- heal below this HP%

local BUFF_SPELL = "Stormshield"

-- =============================================
-- MAIN LOOP (you probably don't need to change this)
-- =============================================
while not ShouldStop() do
    if not IsDead() and not IsFrozen() then

        -- Always keep buff active
        MaintainBuff(BUFF_SPELL)

        if InCombat() and HasTarget() then
            -- Heal if needed
            StayAlive(HEAL_SPELL, HEAL_AT)

            -- Cast spells in priority order
            local cast = CastFirstReady(MY_SPELLS)
            if cast then
                SayF("Cast: %s", cast)
            end

        else
            -- Out of combat: rest if low
            RestIfNeeded("Rest", 80, 50)
        end
    end

    Sleep(0.3)
end
