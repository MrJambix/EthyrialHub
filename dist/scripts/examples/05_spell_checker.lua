--[[
  Example 05 — Spell Checker
  Lists all your spells and their ready/cooldown status.
]]

local ethy = require("common/ethy_sdk")

ethy.print("=== Spell Checker ===")

local spells = ethy.spell_book.get_all()
ethy.printf("Total spells: %d\n", #spells)

for _, spell in ipairs(spells) do
    local ready = ethy.spell_book.is_ready(spell.name)
    local cd = ethy.spell_book.get_cooldown(spell.name)
    local status = ready and "READY" or string.format("CD: %.1fs", cd)
    ethy.printf("  %s: %s", spell.name, status)
end

ethy.print("\nDone!")
