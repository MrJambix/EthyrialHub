--[[
  Example 04 — Nearby Scanner
  Scans nearby enemies and party members.
]]

local ethy = require("common/ethy_sdk")

ethy.print("=== Nearby Scanner ===")

local player = ethy.get_player()
if not player then
    ethy.print("Not connected!")
    return
end

local enemies = core.object_manager.get_nearby_enemies(50)
ethy.printf("Enemies nearby: %d", #enemies)
for i, e in ipairs(enemies) do
    ethy.printf("  %d. %s  HP:%.0f%%  Dist:%.1f  Rank:%s",
        i, e.name, e.hp, e.distance, e.classification)
end

local party = core.object_manager.get_party_members()
ethy.printf("\nParty members: %d", #party)
for i, p in ipairs(party) do
    ethy.printf("  %d. %s  HP:%.0f%%", i, p.name, p.hp)
end
