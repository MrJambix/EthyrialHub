--[[
  Example 02 — Combat Monitor
  Watches combat state and logs transitions in real time.
]]

local ethy = require("common/ethy_sdk")

ethy.print("=== Combat Monitor ===")

local kill_count = 0

ethy.on_combat_enter(function()
    local player = ethy.get_player()
    ethy.printf("COMBAT START  HP:%.0f%% MP:%.0f%%",
        player:get_health_percent(), player:get_mana_percent())
end)

ethy.on_combat_leave(function()
    kill_count = kill_count + 1
    local player = ethy.get_player()
    ethy.printf("COMBAT END  Kill #%d  HP:%.0f%% MP:%.0f%%",
        kill_count, player:get_health_percent(), player:get_mana_percent())
end)

ethy.on_update(function()
    local player = ethy.get_player()
    if not player then return end

    if player:in_combat() and player:has_target() then
        ethy.printf("  Fighting: %s  HP: %.0f%%",
            player:get_target_name(), player:get_target_hp())
    end
end)
