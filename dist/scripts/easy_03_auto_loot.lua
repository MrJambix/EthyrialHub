--[[
  Easy Example 03 — Auto Loot
  Automatically loots after every kill.
]]

require("common/_api/ethy_easy")

Say("=== Auto Loot Started! ===")

local totalLoots = 0

OnCombatEnd(function()
    -- Wait a moment for loot to appear, then grab it
    After(0.5, function()
        LootAll()
        totalLoots = totalLoots + 1
        SayF("Looted! (Total: %d)", totalLoots)
    end)
end)
