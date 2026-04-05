--[[
  Easy Example 01 — Hello World
  The simplest script. Prints your character info.
]]

require("common/_api/ethy_easy")

Say("=== Hello from EthyrialHub! ===")
Say("Name:  " .. GetMyName())
Say("Class: " .. GetMyClass())
SayF("HP: %d%%  MP: %d%%", GetHP(), GetMP())

if InCombat() then
    Say("Currently in combat!")
else
    Say("Not in combat")
end

if HasTarget() then
    Say("Target: " .. GetTargetName())
else
    Say("No target selected")
end

Say("=== Done! ===")
