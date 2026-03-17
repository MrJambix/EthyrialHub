"""
╔══════════════════════════════════════════════════════════════╗
║  ASSASSIN COMBAT PROFILE v1.2                                ║
║                                                              ║
║  ACTIVE SPELLS (what you actually have unlocked):            ║
║    Poison Vial, Ruthless Shiv, Poison Strike,                ║
║    Concealed Weapon, Envenom                                 ║
║                                                              ║
║  ═══ BUFFS ═══                                               ║
║  Viper's Agility — 30min buff, always keep up.               ║
║  Cast on pull and re-cast if detected as missing.            ║
║                                                              ║
║  ═══ DEFENSIVE ═══                                           ║
║  Adrenaline Rush — +30% dodge chance (attacks + spells).     ║
║  Fire at < 40% HP or when triggered at < 20% HP.             ║
║                                                              ║
║  ═══ ROTATION PRIORITY (single target) ═══                   ║
║  1. Envenom          — poison DoT, refresh every 8s          ║
║  2. Concealed Weapon — ranged follow-up, 6s CD               ║
║  3. Poison Strike    — fast melee, 4s CD                     ║
║  4. Ruthless Shiv    — spammable filler, 3s CD               ║
║                                                              ║
║  ═══ AOE (2+ mobs hitting you) ═══                           ║
║  Poison Vial — ground-targeted AoE, mouse location.          ║
║  Only fires when enemy_count >= 2.                           ║
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
#  TIMING
# ══════════════════════════════════════════════════════════════

TICK_RATE = 0.3           # Lower to 0.15 for faster rotation (single-thread)
GCD = 0.5
SPELL_CAST_BUFFER = 0.01 # Extra ms after cast_time (default 0.01)
OPENER_DELAY = 0.01      # Delay between opener spells (default 0.01)

# ══════════════════════════════════════════════════════════════
#  HP THRESHOLDS
# ══════════════════════════════════════════════════════════════

DEFENSIVE_HP          = 40.0
DEFENSIVE_TRIGGER_HP  = 20
REST_HP               = 75
REST_MP               = 50

# ══════════════════════════════════════════════════════════════
#  SPELL METADATA
# ══════════════════════════════════════════════════════════════

SPELL_INFO = {
    "Viper's Agility": {
        "type": "buff",
        "cast_time": 0.0,
        "cooldown": 0,
        "range": 10.0,
        "targets_self": True,
        "generates_stacks": 0,
        "consumes_stacks": 0,
        "desc": "30min self dodge/agility buff. Always keep up.",
    },
    "Adrenaline Rush": {
        "type": "defensive",
        "cast_time": 0.0,
        "cooldown": 30,
        "range": 1.8,
        "targets_self": False,
        "generates_stacks": 0,
        "consumes_stacks": 0,
        "desc": "+30% dodge vs attacks and spells. Use when low HP.",
    },
    "Envenom": {
        "type": "dot",
        "cast_time": 0.0,
        "cooldown": 8,
        "range": 2.0,
        "generates_stacks": 0,
        "consumes_stacks": 0,
        "desc": "Apply poison DoT. 8s CD. Keep refreshed.",
    },
    "Poison Vial": {
        "type": "aoe",
        "cast_time": 0.0,
        "cooldown": 12,
        "range": 4.0,
        "aoe": True,
        "ground_targeted": True,  # cast twice to auto-confirm at same spot (game option)
        "generates_stacks": 0,
        "consumes_stacks": 0,
        "desc": "Ground-targeted AoE. Double-cast to confirm at cursor. Use on 2+ mobs.",
    },
    "Concealed Weapon": {
        "type": "damage",
        "cast_time": 0.0,
        "cooldown": 6,
        "range": 4.0,
        "generates_stacks": 0,
        "consumes_stacks": 0,
        "desc": "Ranged poison attack. 6s CD.",
    },
    "Poison Strike": {
        "type": "damage",
        "cast_time": 0.0,
        "cooldown": 4,
        "range": 2.0,
        "generates_stacks": 0,
        "consumes_stacks": 0,
        "desc": "Fast melee poison. 4s CD.",
    },
    "Ruthless Shiv": {
        "type": "damage",
        "cast_time": 0.0,
        "cooldown": 3,
        "range": 2.0,
        "generates_stacks": 0,
        "consumes_stacks": 0,
        "desc": "Spammable filler stab. 3s CD.",
    },
    "Rest": {
        "type": "rest",
        "cast_time": 0.0,
        "channel_time": 20.0,
        "cooldown": 10,
        "range": 1.85,
        "targets_self": True,
        "generates_stacks": 0,
        "consumes_stacks": 0,
        "desc": "Out-of-combat regen channel.",
    },
}

# ══════════════════════════════════════════════════════════════
#  BUFFS — Viper's Agility is a permanent 30min self-buff.
#  Always recast if it's detected as missing.
#  REBUFF_INTERVAL set low so the engine checks it frequently.
# ══════════════════════════════════════════════════════════════

BUFFS = ["Viper's Agility"]
REBUFF_INTERVAL = 5.0

BUFF_DURATIONS = {
    "Viper's Agility": 1800.0,
}

BUFF_SAFETY = {
    "Viper's Agility": {
        "warn_before_expiry": 30.0,
        "warn_hp_below": 100,
        "danger": "Viper's Agility dropped — dodge chance gone!",
    },
}

# ══════════════════════════════════════════════════════════════
#  OPENER — buff up first, then open with Envenom to get
#  the DoT ticking immediately
# ══════════════════════════════════════════════════════════════

OPENER = [
    "Viper's Agility",
    "Envenom",
]

# ══════════════════════════════════════════════════════════════
#  GAP CLOSERS — none available yet
# ══════════════════════════════════════════════════════════════

GAP_CLOSERS = []

# ══════════════════════════════════════════════════════════════
#  MAIN ROTATION
#
#  Priority:
#    1. Envenom         — refresh DoT first (8s CD)
#    2. Poison Vial     — ranged poison (12s CD)
#    3. Concealed Weapon — ranged follow-up (6s CD)
#    4. Poison Strike   — fast melee (4s CD)
#    5. Ruthless Shiv   — filler, spam when all else on CD (3s CD)
# ══════════════════════════════════════════════════════════════

ROTATION = [
    "Envenom",
    "Concealed Weapon",
    "Poison Strike",
    "Ruthless Shiv",
]

# ══════════════════════════════════════════════════════════════
#  AOE ROTATION — Poison Vial is ground-targeted (mouse pos).
#  Only fires when 2+ enemies are detected hitting you.
# ══════════════════════════════════════════════════════════════

AOE_SPELLS = [
    "Poison Vial",
    "Envenom",
    "Poison Strike",
    "Ruthless Shiv",
]
AOE_THRESHOLD = 2

# ══════════════════════════════════════════════════════════════
#  DEFENSIVE — Adrenaline Rush (+30% dodge) when taking damage
#
#  Fires at < 40% HP via DEFENSIVE_HP, and as emergency at
#  < 20% HP via DEFENSIVE_TRIGGER_HP.
# ══════════════════════════════════════════════════════════════

DEFENSIVE_SPELLS = ["Adrenaline Rush"]
DEFENSIVE_COMBO  = []

HP_RULES = {
    "Adrenaline Rush": {
        "use_below_hp": 40,
        "priority_below": 1,
    },
}

# ══════════════════════════════════════════════════════════════
#  KITING
# ══════════════════════════════════════════════════════════════

KITE_HP = 15
KITE_SPELLS = [
    "Adrenaline Rush",
    "Concealed Weapon",
]

# ══════════════════════════════════════════════════════════════
#  HEALING / REST
# ══════════════════════════════════════════════════════════════

HEAL_SPELLS = []
HEAL_HP     = 0

REST_SPELL       = "Rest"
MEDITATION_SPELL = None

# ══════════════════════════════════════════════════════════════
#  STACK SYSTEM — not applicable
# ══════════════════════════════════════════════════════════════

STACK_ENABLED  = False
STACK_ID       = None
MAX_STACKS     = 0
STACK_DECAY_TIME = 0

# ══════════════════════════════════════════════════════════════
#  IGNORED SPELLS — not unlocked yet, don't attempt
# ══════════════════════════════════════════════════════════════

IGNORED_SPELLS = {
    "Caustic Assault",
    "Noxious Bomb",
    "Toxic Cleanse",
    "Adrenaline Rush",   # defensive only — handled by do_defend(), not rotation
}

# ══════════════════════════════════════════════════════════════
#  DOT TRACKING
# ══════════════════════════════════════════════════════════════

DOT_SPELLS = {
    "Envenom": 8.0,   # poison DoT — reapply every ~6s (before 2s window)
}
DOT_REFRESH_AT = 2.0

# ══════════════════════════════════════════════════════════════
#  PROC BUFFS
# ══════════════════════════════════════════════════════════════

PROC_BUFFS = ["Viper's Agility", "Adrenaline Rush"]

# ══════════════════════════════════════════════════════════════
#  BURST PHASE — when Concealed Weapon + Poison Vial align
# ══════════════════════════════════════════════════════════════

BURST_PHASE = {
    "enabled":    True,
    "cd_trigger": "Concealed Weapon",
    "min_stacks": 0,
    "spells": [
        "Envenom",
        "Poison Vial",
        "Concealed Weapon",
        "Poison Strike",
        "Ruthless Shiv",
    ],
}

# ══════════════════════════════════════════════════════════════
#  INTERRUPT
# ══════════════════════════════════════════════════════════════

INTERRUPT_SPELL = "Concealed Weapon"

# ══════════════════════════════════════════════════════════════
#  TARGET PRIORITY
# ══════════════════════════════════════════════════════════════

TARGET_PRIORITY  = {"boss": 1, "elite": 2, "rare": 3, "normal": 4}
ANTI_KITE_SPELLS = ["Concealed Weapon", "Poison Strike"]
EMERGENCY_HP     = 20
