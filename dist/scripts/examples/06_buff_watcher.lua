--[[
  Example 06 — Buff Watcher
  Monitors active buffs and re-applies when they drop.
]]

local ethy = require("common/ethy_sdk")

ethy.print("=== Buff Watcher ===")

local BUFFS_TO_WATCH = {
    "Stormshield",
    "Imbue Body: Streaming Winds",
    "Imbue Mind: Clarity",
    "Gust of Alacrity",
}

ethy.on_update(function()
    local player = ethy.get_player()
    if not player then return end

    local missing = {}
    for _, buff_name in ipairs(BUFFS_TO_WATCH) do
        if not ethy.buff_manager.has_buff(buff_name) then
            missing[#missing + 1] = buff_name
        end
    end

    if #missing > 0 then
        ethy.printf("Missing buffs: %s", table.concat(missing, ", "))
        for _, buff_name in ipairs(missing) do
            if ethy.spell_book.is_ready(buff_name) then
                ethy.spell_book.cast(buff_name)
                ethy.printf("  Re-applied: %s", buff_name)
            end
        end
    end
end)
