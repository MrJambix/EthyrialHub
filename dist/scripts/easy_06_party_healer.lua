--[[
  Easy Example 06 — Party Healer
  Heals the lowest HP party member during combat.

  HOW TO CUSTOMIZE:
  Change the spell names and HP thresholds for your class.
]]

require("common/_api/ethy_easy")

Say("=== Party Healer Started! ===")

-- =============================================
-- CHANGE THESE:
-- =============================================
local MAIN_HEAL      = "Stream of Life"     -- your main heal
local EMERGENCY_HEAL = "Cleansing Waters"   -- emergency/big heal
local BUFF_SPELL     = "Stormshield"        -- self-buff to maintain

local HEAL_AT        = 70    -- heal party members below this HP%
local EMERGENCY_AT   = 35    -- use emergency heal below this HP%
local SELF_HEAL_AT   = 50    -- heal yourself below this HP%

-- =============================================
-- MAIN LOOP
-- =============================================
while not ShouldStop() do
    if not IsDead() and not IsFrozen() then

        -- Keep self-buff up
        MaintainBuff(BUFF_SPELL)

        -- Heal yourself first if critical
        if GetHP() < SELF_HEAL_AT then
            TryCast(EMERGENCY_HEAL)
            TryCast(MAIN_HEAL)
        end

        -- Find the most wounded party member
        local wounded = GetLowestPartyMember()

        if wounded then
            if wounded.hp < EMERGENCY_AT then
                -- Emergency! Target them and big heal
                TargetByID(wounded.uid)
                if TryCast(EMERGENCY_HEAL) then
                    SayF("EMERGENCY HEAL on %s (%d%%)", wounded.name, wounded.hp)
                end
            elseif wounded.hp < HEAL_AT then
                -- Normal heal
                TargetByID(wounded.uid)
                if TryCast(MAIN_HEAL) then
                    SayF("Healed %s (%d%%)", wounded.name, wounded.hp)
                end
            end
        end

        -- Rest when out of combat and low resources
        if not InCombat() then
            RestIfNeeded("Rest", 80, 50)
        end
    end

    Sleep(0.3)
end
