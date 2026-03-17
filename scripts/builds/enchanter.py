"""
╔══════════════════════════════════════════════════════════════╗
║               ENCHANTER — Storm Mage Build                   ║
║                                                              ║
║  Playstyle: Ranged caster — Storm spells, shields, heals     ║
║  Imbue Mind: Clarity kept up via buff detection              ║
╚══════════════════════════════════════════════════════════════╝
"""

# Discipline level — set your level; skills in SKILL_LEVEL_REQUIREMENTS are blocked until you have the level.
# TODO: Add your discipline's skill: level pairs below.
DISCIPLINE_LEVEL = 25
SKILL_LEVEL_REQUIREMENTS = {
    # "Skill Name": 5,
    # "Other Skill": 10,
}
IGNORED_SPELLS = {s for s, req in SKILL_LEVEL_REQUIREMENTS.items() if DISCIPLINE_LEVEL < req}

HEAL_HP        = 70
DEFENSIVE_HP   = 40
EMERGENCY_HP   = 25
REST_HP        = 70
REST_MP        = 80

TICK_RATE = 0.3
GCD       = 0.3

BUFFS = [
    "Stormshield",               # Self shield (18s CD)
    "Imbue Body: Streaming Winds",
    "Imbue Mind: Clarity",       # Detect buff, cast when missing
    "Gust of Alacrity",
]

BUFF_CONFIG = {
    "Imbue Mind: Clarity": {
        "detect_buff": True,
        "buff_ids": ["Imbue Mind: Clarity", "ImbueMindClarity"],
    },
}

OPENER = [
    "Stormshield",
    "Storm of Haste",
    "Debilitating Waters",
    "Tempest",
    "Stormbolt",
]

ROTATION = [
    "Storm of Haste",
    "Stormshield",
    "Debilitating Waters",
    "Tempest",
    "Stormbolt",
]

HEAL_SPELLS = [
    "Stream of Life",
]

DEFENSIVE_SPELLS = [
    "Stormshield",
]

DEFENSIVE_TRIGGER_HP = 20

REST_SPELL = "Rest"
MEDITATION_SPELL = "Leyline Meditation"
MEDITATION_MANA_PCT = 10  # Use Leyline Meditation in combat when mana ≤ 10%

# ══════════════════════════════════════════════════════════════
#  DOT / PERIODIC EFFECTS
#  Debilitating Waters: 60s CD debuff — track reapplication
# ══════════════════════════════════════════════════════════════

DOT_SPELLS     = {
    "Debilitating Waters": 12.0,  # debuff lasts ~12s — reapply when it drops
}
DOT_REFRESH_AT = 2.0

# ══════════════════════════════════════════════════════════════
#  PROC BUFFS
# ══════════════════════════════════════════════════════════════

PROC_BUFFS = [
    "Stormshield",
    "Imbue Mind: Clarity",
    "Gust of Alacrity",
    "Imbue Body: Streaming Winds",
]

# ══════════════════════════════════════════════════════════════
#  BURST PHASE
#  Enchanter burst: Stormshield up → Storm of Haste → Tempest
#  (Tempest 6s channel = high sustained DPS window)
# ══════════════════════════════════════════════════════════════

BURST_PHASE = {
    "enabled":    True,
    "cd_trigger": "Storm of Haste",
    "min_stacks": 0,
    "spells": [
        "Stormshield",
        "Storm of Haste",
        "Debilitating Waters",
        "Tempest",
        "Stormbolt",
    ],
}

# ══════════════════════════════════════════════════════════════
#  INTERRUPT  — Enchanters have no hard interrupt; use Tempest
#  as a disruptive AoE channel pseudo-interrupt.
# ══════════════════════════════════════════════════════════════

INTERRUPT_SPELL = None   # Update when a proper interrupt spell is available

# ══════════════════════════════════════════════════════════════
#  CC SPELLS
# ══════════════════════════════════════════════════════════════

CC_SPELLS = ["Debilitating Waters"]

# ══════════════════════════════════════════════════════════════
#  TARGET PRIORITY
# ══════════════════════════════════════════════════════════════

TARGET_PRIORITY  = {"boss": 1, "elite": 2, "rare": 3, "normal": 4}
ANTI_KITE_SPELLS = ["Debilitating Waters"]
EMERGENCY_HP     = 25

SPELL_INFO = {
    "Storm of Haste": {"type": "damage", "cast_time": 0, "cooldown": 30, "mana_cost": 30, "range": 10},
    "Stormshield": {"type": "shield", "cast_time": 0, "cooldown": 18, "mana_cost": 15, "duration": 18, "targets_self": True},
    "Debilitating Waters": {"type": "damage", "cast_time": 0.97, "cooldown": 60, "mana_cost": 25, "range": 10},
    "Tempest": {"type": "aoe", "cast_time": 0, "cooldown": 0, "mana_cost": 40, "channel_time": 6},
    "Stormbolt": {"type": "damage", "cast_time": 1.46, "cooldown": 0, "mana_cost": 6, "range": 10},
    "Imbue Mind: Clarity": {"type": "buff", "cast_time": 0, "cooldown": 1, "mana_cost": 0, "targets_self": True},
    "Imbue Body: Streaming Winds": {"type": "buff", "cast_time": 0, "cooldown": 15, "mana_cost": 25, "duration": 15, "targets_self": True},
    "Gust of Alacrity": {"type": "buff", "cast_time": 0, "cooldown": 15, "mana_cost": 8, "duration": 15, "targets_self": True},
    "Stream of Life": {"type": "heal", "cast_time": 0, "cooldown": 0, "mana_cost": 14, "channel_time": 3, "targets_self": True},
}
