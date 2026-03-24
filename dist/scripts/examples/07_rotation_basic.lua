--[[
  Example 07 — Basic Rotation
  A simple combat rotation using the spell book API.
  Casts spells in priority order when in combat.
]]

local ethy = require("common/ethy_sdk")

ethy.print("=== Basic Rotation ===")

local ROTATION = {
    "Storm of Haste",
    "Stormshield",
    "Debilitating Waters",
    "Tempest",
    "Stormbolt",
}

ethy.on_update(function()
    local player = ethy.get_player()
    if not player or not player:in_combat() or not player:has_target() then
        return
    end

    for _, spell in ipairs(ROTATION) do
        if ethy.spell_book.is_ready(spell) then
            if ethy.spell_book.cast(spell) then
                ethy.printf("Cast: %s", spell)
                return
            end
        end
    end
end)
