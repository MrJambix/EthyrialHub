--[[
  Example 01 — Hello World
  The simplest possible script. Checks the connection and prints player info.
]]

local ethy = require("common/ethy_sdk")

ethy.print("=== Hello from EthyrialHub! ===")

local player = ethy.get_player()
if not player then
    ethy.print("Not connected!")
    return
end

ethy.printf("Player: %s", player:get_name())
ethy.printf("Job:    %s", player:get_job_string())
ethy.printf("HP: %.0f%%  MP: %.0f%%", player:get_health_percent(), player:get_mana_percent())
ethy.printf("Combat: %s", player:in_combat() and "Yes" or "No")
ethy.printf("Target: %s", player:has_target() and "Yes" or "None")

ethy.print("=== Done! ===")
