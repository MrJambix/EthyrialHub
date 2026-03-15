"""
╔══════════════════════════════════════════════════════════════╗
║  BERSERKER COMBAT PROFILE v5.1                               ║
║                                                              ║
║  Real fury stacks from game via PLAYER_STACKS                ║
║                                                              ║
║  ═══ FURY SYSTEM ═══                                         ║
║  Each stack: +attack speed, +damage, +damage TAKEN           ║
║  Stacks decay after 12s out of combat                        ║
║                                                              ║
║  ═══ BUFF STRATEGY ═══                                       ║
║                                                              ║
║  BATTLECRY: Cast on pull. +10% max HP for 10s.               ║
║  BLOODLUST: SAVE for HP < 60%. 20% leech = emergency heal.  ║
║  UNDYING FURY: Oh shit at < 20% HP. Cannot die.              ║
║                                                              ║
║  ═══ ROTATION ═══                                            ║
║                                                              ║
║  BUILD: Cleave(+5) → Heavy(+5) → Ham(+4) → Raging(+1-5)    ║
║  20 STACKS: Executioner's Blow IMMEDIATELY (top priority)    ║
║  8+ STACKS: Staggering Shout (2s AoE stun)                  ║
║  LOW HP: Bloodlust (20% leech) → Raging Blow (better low)   ║
╚══════════════════════════════════════════════════════════════╝
"""

# ══════════════════════════════════════════════════════════════
#  DISCIPLINE LEVEL CHECKS
# ══════════════════════════════════════════════════════════════
# Set your level; skills in SKILL_LEVEL_REQUIREMENTS are blocked until you have the level.
# TODO: Add your discipline's skill: level pairs below.
DISCIPLINE_LEVEL = 25
SKILL_LEVEL_REQUIREMENTS = {
    # "Skill Name": 5,
    # "Other Skill": 10,
}
IGNORED_SPELLS = {s for s, req in SKILL_LEVEL_REQUIREMENTS.items() if DISCIPLINE_LEVEL < req}

# ══════════════════════════════════════════════════════════════
#  STACK SYSTEM
# ══════════════════════════════════════════════════════════════

STACK_ENABLED = True
STACK_ID = "FuryStatus"
MAX_STACKS = 20
STACK_DECAY_TIME = 12.0

# ══════════════════════════════════════════════════════════════
#  SPELL METADATA
# ══════════════════════════════════════════════════════════════

SPELL_INFO = {
    "Battlecry": {
        "cd": 30, "type": "buff", "duration": 10,
        "generates_stacks": 1, "consumes_stacks": 0, "min_stacks": 0,
        "desc": "+10% max HP. Cast on pull.",
    },
    "Bloodlust": {
        "cd": 24, "type": "buff", "duration": 6,
        "generates_stacks": 0, "consumes_stacks": 0, "min_stacks": 0,
        "desc": "Atk speed. 20% dmg healed. SAVE for HP < 60%.",
    },
    "Staggering Shout": {
        "cd": 20, "type": "cc", "range": 5, "aoe": True,
        "generates_stacks": 0, "consumes_stacks": 0, "min_stacks": 4,
        "desc": "AoE stun. 4 stacks=1s, 8 stacks=2s.",
    },
    "Heavy Blow": {
        "cd": 6, "type": "builder", "range": 2,
        "generates_stacks": 5, "consumes_stacks": 0, "min_stacks": 0,
        "desc": "105% wep dmg. Grants 5 fury.",
    },
    "Hamstring": {
        "cd": 5, "type": "cc", "range": 2,
        "generates_stacks": 4, "consumes_stacks": 0, "min_stacks": 0,
        "desc": "100% wep dmg. 30% slow 5s. Grants 4 fury.",
    },
    "Furious Cleave": {
        "cd": 2, "cast_time": 0.29, "type": "builder", "aoe": True,
        "generates_stacks": 5, "consumes_stacks": 0, "min_stacks": 0,
        "desc": "AoE hit. Grants 5 fury. Primary builder.",
    },
    "Raging Blow": {
        "cd": 3, "cast_time": 0.29, "type": "builder", "range": 2,
        "generates_stacks": 5, "consumes_stacks": 0, "min_stacks": 0,
        "desc": "Dmg + fury based on missing HP (up to 5). Better low.",
    },
    "Executioner's Blow": {
        "cd": 8, "type": "nuke", "range": 2,
        "generates_stacks": 0, "consumes_stacks": -1, "min_stacks": 20,
        "desc": "NUKE at 20 stacks. Consumes ALL.",
    },
    "Undying Fury": {
        "cd": 45, "type": "defensive",
        "generates_stacks": 0, "consumes_stacks": 0, "min_stacks": 0,
        "duration": 10,
        "desc": "Cannot die. +10% dmg taken. 10% HP heal on expiry.",
    },
}

# ══════════════════════════════════════════════════════════════
#  STACK RULES
# ════════════════════���═════════════════════════════════════════

STACK_RULES = {
    "Executioner's Blow": {
        "min": 20,
        "priority": 1,
    },
    "Staggering Shout": {
        "min": 4,
        "sweet_spot": 8,
        "priority": 3,
    },
}

# ══════════════════════════════════════════════════════════════
#  HP RULES — when to use situational spells
#
#  Bloodlust is NOT an on-CD buff. It's a 20% leech emergency
#  heal. Save it for when HP drops below 60%.
#
#  Battlecry is the pull buff — use on CD for the +10% HP.
#
#  Raging Blow gets better the lower your HP (more missing
#  HP = more fury stacks gained). Prioritize it when low.
# ══════════════════════════════════════════════════════════════

HP_RULES = {
    "Bloodlust": {
        "use_below_hp": 60,
        "priority_below": 2,
    },
    "Raging Blow": {
        "prefer_below_hp": 50,
        "priority_below": 2,
    },
}

# ══════════════════════════════════════════════════════════════
#  BUFFS — only Battlecry auto-casts on CD (pull buff)
#  Bloodlust is HP-conditional, handled by HP_RULES
# ══════════════════════════════════════════════════════════════

BUFFS = ["Battlecry"]
REBUFF_INTERVAL = 28.0

BUFF_DURATIONS = {
    "Battlecry": 10.0,
    "Bloodlust": 6.0,
}

BUFF_SAFETY = {
    "Battlecry": {
        "warn_hp_below": 30,
        "warn_before_expiry": 2.0,
        "danger": "Losing 10% max HP can kill at low HP!",
    },
}

# ══════════════════════════════════════════════════════════════
#  OPENER — Battlecry only. Bloodlust saved.
# ══════════════════════════════════════════════════════════════

OPENER = ["Battlecry"]

# ══════════════════════════════════════════════════════════════
#  GAP CLOSERS
# ══════════════════════════════════════════════════════════════

GAP_CLOSERS = []

# ══════════════════════════════════════════════════════════════
#  MAIN ROTATION
#
#  Order:
#    1. Executioner's Blow (20 stacks — NUKE, top prio)
#    2. Bloodlust (HP < 60% — emergency leech, prio via HP_RULES)
#    3. Staggering Shout (8+ stacks — 2s stun, prio via STACK_RULES)
#    4. Heavy Blow (instant, +5 stacks, 105% dmg)
#    5. Hamstring (+4 stacks, slow)
#    6. Furious Cleave (+5 stacks, AoE, spam filler)
#    7. Raging Blow (+1-5 stacks, better at low HP)
# ══════════════════════════════════════════════════════════════

ROTATION = [
    "Executioner's Blow",
    "Bloodlust",
    "Staggering Shout",
    "Heavy Blow",
    "Hamstring",
    "Furious Cleave",
    "Raging Blow",
]

# ══════════════════════════════════════════════════════════════
#  AOE ROTATION — Cleave first (AoE builder)
# ══════════════════════════════════════════════════════════════

AOE_SPELLS = [
    "Executioner's Blow",
    "Staggering Shout",
    "Furious Cleave",
    "Heavy Blow",
    "Hamstring",
    "Raging Blow",
]
AOE_THRESHOLD = 3

# ══════════════════════════════════════════════════════════════
#  DEFENSIVE — Undying Fury is the oh-shit button
# ══════════════════════════════════════════════════════════════

DEFENSIVE_SPELLS = ["Undying Fury"]
DEFENSIVE_HP = 40.0
DEFENSIVE_TRIGGER_HP = 20
DEFENSIVE_COMBO = ["Staggering Shout"]

# ══════════════════════════════════════════════════════════════
#  KITING
# ══════════════════════════════════════════════════════════════

KITE_HP = 15
KITE_SPELLS = [
    "Undying Fury",
    "Staggering Shout",
    "Hamstring",
]

# ══════════════════════════════════════════════════════════════
#  HEALING / REST
# ══════════════════════════════════════════════════════════════

HEAL_SPELLS = []
HEAL_HP = 0

REST_SPELL = "Rest"
REST_HP = 70
REST_MP = 50
MEDITATION_SPELL = "Leyline Meditation"

# ══════════════════════════════════════════════════════════════
#  TIMING
# ══════════════════════════════════════════════════════════════

TICK_RATE = 0.3
GCD = 0.5

# ══════════════════════════════════════════════════════════════
#  IGNORED SPELLS
# ══════════════════════════════════════════════════════════════

IGNORED_SPELLS = {
    "Summon Hallowed Ghost",
    "Siphon Shadow Energies",
    "Earthglow",
    "Light of the Keeper",
    "Furious Charge",
}