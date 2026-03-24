--[[
  Example 03 — Auto-Loot
  Automatically loots after every kill using combat leave callback.
]]

local ethy = require("common/ethy_sdk")

ethy.print("=== Auto-Loot ===")

local loots = 0

ethy.on_combat_leave(function()
    ethy.after(0.5, function()
        local result = core.send_command("LOOT_ALL")
        if result and result:find("OK") then
            loots = loots + 1
            ethy.printf("Looted! (Total: %d)", loots)
        else
            ethy.print("Nothing to loot.")
        end
    end)
end)
