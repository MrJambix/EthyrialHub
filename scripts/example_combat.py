"""
Auto-Combat v8 — Uses wraps, auto-detects class, loads rotation
"""
from ethytool_wraps import *
import sys
import os
import importlib.util
import time

# ════════════════════════════════════════════════════════════
#  SETUP
# ════════════════════════════════════════════════════════════

detected = my_class()
known = spell_set()

print()
print("AUTO-COMBAT v8")
print(f"  Class: {detected}")
print(f"  Spells: {len(spell_names())}")

rotation_file = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "rotations",
    f"{detected.lower()}.py"
)

if not os.path.exists(rotation_file):
    print(f"  No rotation file: rotations/{detected.lower()}.py")
    print(f"  Copy rotations/template.py and rename it")
    sys.exit(1)

spec = importlib.util.spec_from_file_location("rotation", rotation_file)
rot = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rot)

ROT     = available(getattr(rot, "ROTATION", []))
EXEC    = available(getattr(rot, "EXECUTE_SPELLS", []))
DEF     = available(getattr(rot, "DEFENSIVE_SPELLS", []))
BUFFS   = available(getattr(rot, "BUFFS", []))
HEALS   = available(getattr(rot, "HEAL_SPELLS", []))
EXEC_HP = getattr(rot, "EXECUTE_HP", 25)
DEF_HP  = getattr(rot, "DEFENSIVE_HP", 40)
HEAL_HP = getattr(rot, "HEAL_HP", 70)
BUFF_CD = getattr(rot, "REBUFF_INTERVAL", 60)
TICK    = getattr(rot, "TICK_RATE", 0.6)

print(f"  Rotation: {', '.join(ROT) or 'NONE'}")
if EXEC:  print(f"  Execute:  {', '.join(EXEC)}")
if DEF:   print(f"  Defense:  {', '.join(DEF)}")
if BUFFS: print(f"  Buffs:    {', '.join(BUFFS)}")
if HEALS: print(f"  Heals:    {', '.join(HEALS)}")

missing = [s for s in getattr(rot, "ROTATION", []) if s not in known]
if missing:
    print(f"  Missing: {', '.join(missing)}")

print("Waiting for combat...")
print()

# ════════════════════════════════════════════════════════════
#  FIGHT
# ════════════════════════════════════════════════════════════

kills = 0
casts = 0
last_buff = 0
fighting = False

while True:
    if not combat() or not has_target():
        if fighting:
            fighting = False
            print("  Out of combat")
            print()
        sleep(0.5)
        continue

    if not fighting:
        fighting = True
        print("  ENGAGED")

    my  = hp()
    thp = target_hp()
    tn  = target_name()

    # 1. Heal
    if my < HEAL_HP and HEALS:
        used = cast_first(HEALS)
        if used:
            print(f"  HEAL: {used}  HP:{my:.0f}%")
            sleep(TICK)
            continue

    # 2. Defensive
    if my < DEF_HP and DEF:
        used = cast_first(DEF)
        if used:
            print(f"  DEFENSIVE: {used}  HP:{my:.0f}%")
            sleep(TICK)
            continue

    # 3. Buffs
    now = time.time()
    if now - last_buff > BUFF_CD and BUFFS:
        for b in BUFFS:
            if cast(b):
                print(f"  BUFF: {b}")
                sleep(0.3)
        last_buff = now

    # 4. Execute
    if thp < EXEC_HP and EXEC:
        used = cast_first(EXEC)
        if used:
            casts += 1
            print(f"  EXECUTE: {used}  {tn} {thp:.0f}%")
            sleep(TICK)
            continue

    # 5. Rotation
    used = cast_first(ROT)
    if used:
        casts += 1
        print(f"  {used:20s}  HP:{my:.0f}%  {tn} {thp:.0f}%")

    sleep(TICK)

    # Kill check
    if not has_target():
        kills += 1
        print(f"  KILL #{kills} ({tn})")
        print()
        sleep(0.3)