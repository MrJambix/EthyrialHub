-- ═══════════════════════════════════════════════════════════════
--  enums — Game Enumerations (matching lua_runtime.cpp / enums.h)
-- ═══════════════════════════════════════════════════════════════

local enums = {}

enums.job_id = {
    UNKNOWN = -1, ANY = 0,
    ENCHANTER = 1, RANGER = 2, ASSASSIN = 3, SPELLBLADE = 4,
    EARTHGUARD = 5, GUARDIAN = 6, ILLUSIONIST = 7, DRUID = 8,
    SHADOWCASTER = 9, BERSERKER = 10, BRAWLER = 11, DEMONKNIGHT = 12,
}

enums.spell_category = {
    UNKNOWN = 0, DAMAGE = 1, AOE = 2, HEAL = 3, SHIELD = 4,
    BUFF = 5, DEBUFF = 6, CC = 7, UTILITY = 8, DEFENSIVE = 9,
    DOT = 10, CHANNEL = 11, PET = 12, REST = 13, BURST = 14, GAP_CLOSER = 15,
}

enums.buff_type = {
    UNKNOWN = 0, BUFF = 1, DEBUFF = 2, DOT = 3, HOT = 4,
    SHIELD = 5, PROC = 6, CC = 7, STANCE = 8, PASSIVE = 9,
    FOOD = 10, IMMUNITY = 11,
}

enums.classification = {
    UNKNOWN = -1, NORMAL = 0, ELITE = 1, RARE = 2, BOSS = 3, CRITTER = 4,
}

enums.entity_type = {
    UNKNOWN = 0, MONSTER = 1, NPC = 2, HOSTILE = 3, PLAYER = 4,
    PET = 5, COMPANION = 6, CORPSE = 7, GATHER_NODE = 8, SCENE_OBJECT = 9,
}

enums.combat_state = {
    IDLE = 0, IN_COMBAT = 1, DEAD = 2, FROZEN = 3, RESTING = 4,
    GATHERING = 5, CASTING = 6, CHANNELING = 7, MOUNTED = 8,
}

enums.group_role = {
    NONE = -1, TANK = 0, HEALER = 1, DPS = 2,
}

enums.gather_node_type = {
    UNKNOWN = 0, HERB = 1, TREE = 2, ORE = 3, SKIN = 4,
}

enums.power_type = {
    NONE = -1, HEALTH = 0, MANA = 1, FURY = 2, SPIRIT_LINK = 3, FOOD = 4,
}

-- ── Game enums (matching Layout::Enums in game_class_layout_systems.h) ──

enums.vocation = {
    NONE = 0,
    FIGHTER = 1, PROTECTOR = 2, ARCHER = 3, ROGUE = 4,
    ARCANIST = 5, MYSTIC = 6, BRAWLER = 7, BERSERKER = 8,
    SPELLBLADE = 9, CRUSADER = 10, PALADIN = 11, WARDEN = 12,
    SOULWEAVER = 13, GUARDIAN = 14, EARTHGUARD = 15,
    DRAGONKNIGHT = 16, DEMONKNIGHT = 17,
    HUNTER = 18, RANGER = 19, DUSKBOW = 20,
    ASSASSIN = 21, SHADOWBLADE = 22,
    ELEMENTALIST = 23, SHADOWCASTER = 24, ILLUSIONIST = 25,
    INFUSER = 26, HEXWEAVER = 27, ENCHANTER = 28,
    PRIEST = 29, DRUID = 30, CULTIST = 31,
}

enums.element_type = {
    NONE = 0, ARCANE = 1, FIRE = 2, WATER = 3, AIR = 4,
    NATURE = 5, FROST = 6, DIVINE = 7, DEMONIC = 8,
    LIGHTNING = 9, SHADOW = 10, EARTH = 11,
    PIERCING = 12, SLASHING = 13, CRUSHING = 14,
}

enums.damage_type = {
    NONE = 0, PHYSICAL = 1, MAGIC = 2, PURE = 3, SYSTEM = 4,
}

enums.game_state = {
    PLAYING = 0, LOADING = 1,
}

enums.game_mode = {
    STANDARD = 0, HARDCORE = 1, IRONMAN = 2,
    HARDCORE_IRONMAN = 3, ULTIMATE_IRONMAN = 4,
    GROUP_IRONMAN = 5, DEADMAN = 6, NONE = 7,
}

enums.entity_type_il2cpp = {
    NONE = 0, DOODAD = 1, PLAYER = 2, PROJECTILE = 3,
    ITEM = 4, MONSTER = 5, NPC = 6, WALL = 7,
    CORPSE = 8, PLACEHOLDER = 9,
}

return enums
