-- enchanter.lua
-- Enchanter build profile (Lua table format).
-- Load this from Settings to configure spell rotations.

return {
    name = "Enchanter",
    description = "Healer / Support Caster",

    HEAL_HP = 50,
    DEFENSIVE_HP = 40,
    EMERGENCY_HP = 20,
    REST_HP = 80,
    REST_MP = 60,
    MANA_CONSERVE = 25,
    TICK_RATE = 0.3,

    BUFFS = {
        "Stormshield",
        "Imbue Body: Streaming Winds",
        "Imbue Mind: Clarity",
        "Gust of Alacrity",
    },

    OPENER = {
        "Stormshield",
        "Imbue Body: Streaming Winds",
        "Storm of Haste",
        "Stormbolt",
    },

    ROTATION = {
        "Storm of Haste",
        "Stormshield",
        "Debilitating Waters",
        "Tempest",
        "Stormbolt",
    },

    HEAL_SPELLS = {
        "Stream of Life",
    },

    DEFENSIVE_SPELLS = {
        "Stormshield",
        "Cleansing Waters",
    },

    REST_SPELL = "Rest",
    MEDITATION_SPELL = "Leyline Meditation",
}
