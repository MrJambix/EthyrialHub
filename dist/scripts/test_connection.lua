-- test_connection.lua
-- Verifies the Hub <-> EthyTool pipe is working and all systems report data.

print("Testing connection...")

local pong = conn.send_command("PING")
print("PING -> " .. pong)

if pong ~= "PONG" then
    print("ERROR: Expected PONG, got: " .. pong)
    return
end
print("Connection OK!")

local ver = conn.send_command("VERSION")
print("EthyTool version: " .. ver)

local hp = conn.get_hp()
local mp = conn.get_mp()
print(string.format("HP: %.1f%%  MP: %.1f%%", hp, mp))

local name = (core.player.get_all() or {}).name or "?"
print("Player: " .. name)

local job = core.player.job()
print("Job: " .. job)

local cls = "Unknown"
local spells = core.spells.get_all()
if spells and #spells > 0 then
    local votes = {}
    for _, sp in ipairs(spells) do
        if sp.cat and sp.cat ~= "Misc" then
            votes[sp.cat] = (votes[sp.cat] or 0) + 1
        end
    end
    local best, best_n = "Unknown", 0
    for c, n in pairs(votes) do
        if n > best_n then best = c; best_n = n end
    end
    cls = best
end
print("Detected class: " .. cls .. " (" .. #spells .. " spells)")

if conn.in_combat() then
    print("Currently IN COMBAT")
else
    print("Out of combat")
end

if conn.has_target() then
    local tgt = core.targeting.target_name()
    print("Target: " .. (tgt or "?"))
else
    print("No target selected")
end

print("All checks passed!")
