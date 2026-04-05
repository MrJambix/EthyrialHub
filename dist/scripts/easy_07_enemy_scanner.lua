--[[
  Easy Example 07 — Enemy Scanner
  Scans and lists all nearby enemies and party members.
  This is a one-shot info script (not a loop).
]]

require("common/_api/ethy_easy")

Say("=== Enemy Scanner ===")

-- Show player info
SayF("You: %s (%s)  HP:%d%%  MP:%d%%",
    GetMyName(), GetMyClass(), GetHP(), GetMP())

-- Scan enemies
local enemies = GetNearbyEnemies(50)
SayF("\nEnemies within 50 range: %d", #enemies)
for i, enemy in ipairs(enemies) do
    SayF("  %d. %s  HP:%d%%  Dist:%.1f  Type:%s",
        i, enemy.name, enemy.hp, enemy.distance, enemy.classification or "Normal")
end

-- Scan party
local party = GetPartyMembers()
SayF("\nParty members: %d", #party)
for i, member in ipairs(party) do
    SayF("  %d. %s  HP:%d%%", i, member.name, member.hp)
end

-- Scan players
local players = GetNearbyPlayers()
SayF("\nNearby players: %d", #players)

Say("\n=== Scan Complete! ===")
