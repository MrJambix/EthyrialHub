"""
╔══════════════════════════════════════════════════════════════╗
║                  SPELLBLADE — Arcane Melee Build             ║
║                                                              ║
║  Playstyle: Imbue weapon → burst combo → shield → repeat     ║
║                                                              ║
║  COMBO LOGIC:                                                ║
║    1. Imbue Weapon: Arcane (permanent — cast once)           ║
║    2. Leyline Brilliance (30 min buff — cast once)           ║
║    3. Arcane Slashes (spam — 2s CD, main damage)             ║
║    4. Arcane Wave (5s CD, melee cleave)                      ║
║    5. Arcane Shockwave (6s CD, point-blank AOE)              ║
║    6. Supernova (12s CD, big AOE burst)                      ║
║    7. Siphon Instability (10s CD, mana/resource drain)       ║
║                                                              ║
║  DEFENSE:                                                    ║
║    - Arcanic Bulwark — INVULNERABLE for 3s (20s CD)         ║
║    - Counterspell — interrupt casters (12s CD)               ║
║    # Arcane Blitz — ground-target teleport (18s CD) DISABLED ║
║                                                              ║
║  BUFF:                                                       ║
║    - Imbue Weapon: Arcane (permanent — only cast if missing) ║
║    - Leyline Brilliance (30 min — only cast if missing)      ║
╚══════════════════════════════════════════════════════════════╝
"""

# ═══════════════════════════════════════════════════════════
#  DISCIPLINE LEVEL CHECKS
# ═══════════════════════════════════════════════════════════
# Set your level; skills in SKILL_LEVEL_REQUIREMENTS are blocked until you have the level.
# TODO: Add your discipline's skill: level pairs below.
DISCIPLINE_LEVEL = 25
SKILL_LEVEL_REQUIREMENTS = {
    # "Skill Name": 5,
    # "Other Skill": 10,
}
IGNORED_SPELLS = {s for s, req in SKILL_LEVEL_REQUIREMENTS.items() if DISCIPLINE_LEVEL < req}

# ═══════════════════════════════════════════════════════════
#  THRESHOLDS
# ═══════════════════════════════════════════════════════════

HEAL_HP        = 50
DEFENSIVE_HP   = 40
EMERGENCY_HP   = 20
REST_HP        = 80
REST_MP        = 60
MANA_CONSERVE  = 20

# ═══════════════════════════════════════════════════════════
#  TICK RATE
# ═══════════════════════════════════════════════════════════

TICK_RATE = 0.25
GCD       = 0.3

# ═══════════════════════════════════════════════════════════
#  BUFFS — only cast if not already active
# ═══════════════════════════════════════════════════════════

BUFFS = [
    "Imbue Weapon: Arcane",
    "Leyline Brilliance",
]

BUFF_CONFIG = {
    "Imbue Weapon: Arcane": {
        "permanent": True,
        "check_before_cast": True,
        "recast_interval": 0,
    },
    "Leyline Brilliance": {
        "permanent": False,
        "check_before_cast": True,
        "duration": 1800,
        "recast_interval": 1800,
    },
}

# ═══════════════════════════════════════════════════════════
#  OPENER
# ═══════════════════════════════════════════════════════════

OPENER = [
    "Arcane Shockwave",
    "Arcane Slashes",
]

# ═══════════════════════════════════════════════════════════
#  GAP CLOSERS
# ═══════════════════════════════════════════════════════════

GAP_CLOSERS = []

# ═══════════════════════════════════════════════════════════
#  ESCAPE
# ═══════════════════════════════════════════════════════════

ESCAPE_SPELLS = [
    # "Arcane Blitz",            # Ground-target teleport (18s CD) — disabled
]

# ═══════════════════════════════════════════════════════════
#  ROTATION (priority order)
# ═══════════════════════════════════════════════════════════

ROTATION = [
    "Supernova",
    "Arcane Shockwave",
    "Arcane Wave",
    "Siphon Instability",
    "Arcane Slashes",
]

# ═══════════════════════════════════════════════════════════
#  AOE ROTATION (3+ mobs)
# ═══════════════════════════════════════════════════════════

AOE_SPELLS = [
    "Supernova",
    "Arcane Shockwave",
    "Arcane Wave",
    "Arcane Slashes",
]

# ═══════════════════════════════════════════════════════════
#  DEFENSIVE
# ═══════════════════════════════════════════════════════════

DEFENSIVE_SPELLS = [
    "Arcanic Bulwark",
    "Counterspell",
    # "Arcane Blitz",            # Teleport escape — disabled
]

DEFENSIVE_TRIGGER_HP = 20

DEFENSIVE_COMBO = [
    "Arcanic Bulwark",
    # "Arcane Blitz",            # Teleport out while invuln — disabled
]

# ═══════════════════════════════════════════════════════════
#  INTERRUPT
# ═══════════════════════════════════════════════════════════

INTERRUPT_SPELLS = [
    "Counterspell",
]

# ═══════════════════════════════════════════════════════════
#  REST
# ═══════════════════════════════════════════════════════════

REST_SPELL = "Rest"
MEDITATION_SPELL = "Leyline Meditation"

# ═══════════════════════════════════════════════════════════
#  STACKS
# ═══════════════════════════════════════════════════════════

MAX_STACKS = 0
STACK_DECAY_TIME = 0

DOT_SPELLS      = {}
DOT_REFRESH_AT  = 2.0
PROC_BUFFS      = ["Imbue Weapon: Arcane", "Leyline Brilliance", "Arcanic Bulwark"]
BURST_PHASE     = {
    "enabled": True, "cd_trigger": "Supernova", "min_stacks": 0,
    "spells": ["Arcanic Bulwark", "Supernova", "Arcane Shockwave", "Arcane Wave", "Siphon Instability", "Arcane Slashes"],
}
INTERRUPT_SPELL  = "Counterspell"
CC_SPELLS        = ["Counterspell"]
TARGET_PRIORITY  = {"boss": 1, "elite": 2, "rare": 3, "normal": 4}
ANTI_KITE_SPELLS = []

# ═══════════════════════════════════════════════════════════
#  SPELL INFO
# ═══════════════════════════════════════════════════════════

SPELL_INFO = {

    "Imbue Weapon: Arcane": {
        "type": "buff",
        "cast_time": 1.0,
        "cooldown": 0,
        "mana_cost": 0,
        "duration": 0,
        "targets_self": True,
        "permanent": True,
        "generates_stacks": 0,
        "consumes_stacks": 0,
    },

    "Leyline Brilliance": {
        "type": "buff",
        "cast_time": 0,
        "cooldown": 0,
        "mana_cost": 0,
        "duration": 1800,
        "targets_self": True,
        "generates_stacks": 0,
        "consumes_stacks": 0,
    },

    # "Arcane Blitz": {
    #     "type": "escape",
    #     "cast_time": 0,
    #     "cooldown": 18,
    #     "mana_cost": 5,
    #     "range": 7,
    #     "ground_target": True,
    #     "use_for": "escape",
    #     "generates_stacks": 0,
    #     "consumes_stacks": 0,
    # },

    "Arcane Slashes": {
        "type": "damage",
        "cast_time": 0,
        "cooldown": 2,
        "mana_cost": 2,
        "range": 2,
        "generates_stacks": 0,
        "consumes_stacks": 0,
    },

    "Arcane Wave": {
        "type": "damage",
        "cast_time": 0,
        "cooldown": 5,
        "mana_cost": 3,
        "range": 2,
        "generates_stacks": 0,
        "consumes_stacks": 0,
    },

    "Arcane Shockwave": {
        "type": "aoe",
        "cast_time": 0,
        "cooldown": 6,
        "mana_cost": 4,
        "range": 0,
        "generates_stacks": 0,
        "consumes_stacks": 0,
    },

    "Supernova": {
        "type": "aoe",
        "cast_time": 0,
        "cooldown": 12,
        "mana_cost": 6,
        "range": 3,
        "generates_stacks": 0,
        "consumes_stacks": 0,
    },

    "Siphon Instability": {
        "type": "damage",
        "cast_time": 0,
        "cooldown": 10,
        "mana_cost": 3,
        "range": 5,
        "generates_stacks": 0,
        "consumes_stacks": 0,
    },

    "Arcanic Bulwark": {
        "type": "invulnerable",
        "cast_time": 0,
        "cooldown": 20,
        "mana_cost": 5,
        "duration": 3,
        "range": 100,
        "targets_self": True,
        "priority": "emergency",
        "generates_stacks": 0,
        "consumes_stacks": 0,
    },

    "Counterspell": {
        "type": "interrupt",
        "cast_time": 0,
        "cooldown": 12,
        "mana_cost": 2,
        "range": 5,
        "generates_stacks": 0,
        "consumes_stacks": 0,
    },
}

# ═══════════════════════════════════════════════════════════
#  BUFF SAFETY
# ═══════════════════════════════════════════════════════════

BUFF_SAFETY = {
    "Imbue Weapon: Arcane": {
        "warn_before_expiry": 0,
        "warn_hp_below": 100,
        "danger": "Weapon imbue down! Recast immediately!",
    },
}

# ════════════════════════════���══════════════════════════════
#  IGNORED SPELLS — shared utility, never used in combat
# ═══════════════════════════════════════════════════════════

IGNORED_SPELLS = {
    "Summon Hallowed Ghost",
    "Siphon Shadow Energies",
    "Earthglow",
    "Light of the Keeper",
}