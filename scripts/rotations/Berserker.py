"""
Berserker Rotation — Ethyrial
Melee DPS with self-buffs, CC, and execute phase.
"""

# ── Buff spells (re-applied periodically, only in combat) ──
BUFFS = [
    "Battlecry",
    "Bloodlust",
]
REBUFF_INTERVAL = 55.0

# ── Main rotation (priority order — first ready wins) ──
ROTATION = [
    "Staggering Shout",    # AoE CC / shout
    "Furious Charge",      # Gap closer
    "Heavy Blow",          # Big hit
    "Hamstring",           # CC / slow
    "Furious Cleave",      # AoE / cleave
    "Raging Blow",         # Core filler
]

# ── Execute spells (used when target HP < EXECUTE_HP) ──
EXECUTE_SPELLS = ["Executioner's Blow"]
EXECUTE_HP = 25.0

# ── Defensive spells (used when player HP < DEFENSIVE_HP) ──
DEFENSIVE_SPELLS = ["Undying Fury"]
DEFENSIVE_HP = 40.0

# ── Healing (none for Berserker) ──
HEAL_SPELLS = []
HEAL_HP = 0.0

# ── Tick rate ──
TICK_RATE = 0.5