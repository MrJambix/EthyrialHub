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

return enums
