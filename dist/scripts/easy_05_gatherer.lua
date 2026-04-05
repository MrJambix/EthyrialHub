--[[
  Easy Example 05 — Simple Gatherer
  Gathers resource nodes nearby. Fights back if attacked.

  HOW TO CUSTOMIZE:
  Change GATHER_FILTER to what you want to gather:
    ""        = gather anything
    "Iron"    = only iron ore
    "Copper"  = only copper ore
    "Oak"     = only oak trees
    etc.
]]

require("common/_api/ethy_easy")

Say("=== Gatherer Started! ===")

-- =============================================
-- CHANGE THIS:
-- =============================================
local GATHER_FILTER = ""        -- leave empty for anything, or "Iron", "Oak", etc.
local COMBAT_SPELLS = {         -- spells to fight back with if attacked
    "Stormbolt",
    "Tempest",
}

-- =============================================
-- MAIN LOOP
-- =============================================
while not ShouldStop() do
    if InCombat() then
        -- We got attacked! Fight back
        if HasTarget() then
            CastFirstReady(COMBAT_SPELLS)
        end
        Sleep(0.3)
    else
        -- Look for nodes to gather
        local nodes = ScanUsableNodes(GATHER_FILTER)

        if #nodes > 0 then
            SayF("Found %d nodes, gathering...", #nodes)
            GatherNearest(GATHER_FILTER)
            Sleep(2)  -- wait for gathering animation
        else
            Say("No nodes found, waiting...")
            Sleep(5)  -- wait before scanning again
        end
    end
end
