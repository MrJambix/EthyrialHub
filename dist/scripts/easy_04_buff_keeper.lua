--[[
  Easy Example 04 — Buff Keeper
  Automatically re-casts buffs when they expire.

  HOW TO CUSTOMIZE:
  Change MY_BUFFS to your class's buff spells.
  Format: { buff = "InternalBuffName", spell = "SpellToCast" }
  If the buff name and spell name are the same, you only need one.
]]

require("common/_api/ethy_easy")

Say("=== Buff Keeper Started! ===")

-- =============================================
-- CHANGE THESE TO YOUR BUFFS:
-- =============================================
local MY_BUFFS = {
    { buff = "Stormshield",      spell = "Stormshield" },
    { buff = "ImbueMindClarity", spell = "Imbue Mind: Clarity" },
    { buff = "GustOfAlacrity",   spell = "Gust of Alacrity" },
}

-- =============================================
-- MAIN LOOP
-- =============================================
while not ShouldStop() do
    for _, entry in ipairs(MY_BUFFS) do
        -- Check if buff is missing or about to expire (< 5 seconds left)
        if IsBuffExpiring(entry.buff, 5) then
            if TryCast(entry.spell) then
                SayF("Refreshed: %s", entry.spell)
                Sleep(0.5)  -- small pause between casts
            end
        end
    end

    Sleep(1)  -- check once per second
end
