"""
Auto-Combat v9 — Class Detection + Rotation Loading
Detects your class from spells, loads the right rotation file.
Waits for combat + hostile target before using any abilities.
"""
import time
import sys
import os
import importlib.util
import ethytool_wraps
ethytool_wraps.conn = conn
from ethytool_wraps import *

# ════════════════════════════════════════════════════════════
#  HELPERS
# ════════════════════════════════════════════════════════════

def should_stop():
    try:
        return stop_event.is_set()
    except NameError:
        return False

def load_rotation(name, rotation_dir):
    """Try to find and load a rotation file. Tries multiple casings."""
    candidates = [
        f"{name}.py",
        f"{name.lower()}.py",
        f"{name.capitalize()}.py",
        f"{name.upper()}.py",
    ]
    for fname in candidates:
        path = os.path.join(rotation_dir, fname)
        if os.path.exists(path):
            spec = importlib.util.spec_from_file_location("rotation", path)
            rot = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(rot)
            return rot, fname
    return None, None

# ════════════════════════════════════════════════════════════
#  DETECT CLASS
# ════════════════════��═══════════════════════════════════════

print()
print("+" + "-" * 53 + "+")
print("|  AUTO-COMBAT v6 — Class Detection                  |")
print("+" + "-" * 53 + "+")
print()

all_spells = spells()
all_names = spell_set()

if all_spells:
    print(f"  Found {len(all_spells)} spells")
    detected_class = my_class()
    print(f"  Detected class: {detected_class}")
else:
    detected_class = "Unknown"
    print("  No spells found!")

print()

# ════════════════════════════════════════════════════════════
#  LOAD ROTATION
# ════════════════════════════════════════════════════════════

rotation_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "rotations")
os.makedirs(rotation_dir, exist_ok=True)

rot, rot_filename = load_rotation(detected_class, rotation_dir)

if rot:
    print(f"  Loaded rotation: rotations/{rot_filename}")
else:
    print(f"  [!] No rotation file for '{detected_class}'")
    print(f"      Looked in: {rotation_dir}")
    print()

    available_rots = [f for f in os.listdir(rotation_dir) if f.endswith(".py") and f != "template.py"]
    if available_rots:
        print(f"      Available rotations: {', '.join(available_rots)}")
    print()

    template_path = os.path.join(rotation_dir, "template.py")
    if not os.path.exists(template_path):
        with open(template_path, "w") as f:
            f.write('''"""
Rotation Template — Copy this to <classname>.py
Example: berserker.py, ranger.py, mage.py
"""

BUFFS = []
REBUFF_INTERVAL = 60

ROTATION = [
    # "Spell Name Here",
]

EXECUTE_SPELLS = []
EXECUTE_HP = 25

DEFENSIVE_SPELLS = []
DEFENSIVE_HP = 40

HEAL_SPELLS = []
HEAL_HP = 70

TICK_RATE = 0.6
''')
        print(f"      Created template: {template_path}")

    sys.exit(1)

# ── Pull config ──
BUFFS            = getattr(rot, "BUFFS", [])
REBUFF_CD        = getattr(rot, "REBUFF_INTERVAL", 60.0)
ROTATION         = getattr(rot, "ROTATION", [])
EXECUTE_SPELLS   = getattr(rot, "EXECUTE_SPELLS", [])
EXECUTE_HP       = getattr(rot, "EXECUTE_HP", 25.0)
DEFENSIVE_SPELLS = getattr(rot, "DEFENSIVE_SPELLS", [])
DEFENSIVE_HP     = getattr(rot, "DEFENSIVE_HP", 40.0)
HEAL_SPELLS      = getattr(rot, "HEAL_SPELLS", [])
HEAL_HP          = getattr(rot, "HEAL_HP", 70.0)
TICK_RATE        = getattr(rot, "TICK_RATE", 0.6)

# ── Filter to spells we actually have ──
avail_rot    = available(ROTATION)
avail_exec   = available(EXECUTE_SPELLS)
avail_def    = available(DEFENSIVE_SPELLS)
avail_buffs  = available(BUFFS)
avail_heals  = available(HEAL_SPELLS)

print(f"  Rotation:  {', '.join(avail_rot) or '(empty)'}")
if avail_exec:  print(f"  Execute:   {', '.join(avail_exec)}")
if avail_def:   print(f"  Defensive: {', '.join(avail_def)}")
if avail_buffs: print(f"  Buffs:     {', '.join(avail_buffs)}")
if avail_heals: print(f"  Heals:     {', '.join(avail_heals)}")

missing = [s for s in ROTATION if s not in all_names]
if missing:
    print(f"  [!] Missing: {', '.join(missing)}")

if not avail_rot:
    print()
    print("  [ERROR] No usable spells in rotation!")
    print(f"          Your spells: {', '.join(sorted(spell_names())[:20])}")
    print()
    print("  Check that spell names in your rotation match exactly.")
    print("  Run check_spells.py to see what the game calls them.")
    sys.exit(1)

print()
print("+" + "-" * 53 + "+")
print("|  Idle — waiting for combat + target...              |")
print("+" + "-" * 53 + "+")
print()

# ════════════════════════════════════════════════════════════
#  MAIN LOOP
# ════════════════════════════════════════════════════════════

last_buff_time = 0
kills = 0
total_casts = 0
was_active = False
last_target_name = ""

try:
    while not should_stop():
        my = hp()
        fighting = combat()

        # ── Self-heal even out of combat ──
        if avail_heals and my < HEAL_HP:
            for spell in avail_heals:
                if cast(spell):
                    print(f"  [HEAL]  {spell}  (HP:{my:.0f}%)")
                    sleep(TICK_RATE)
                    break

        # ── Target check ──
        tgt = target()
        got_target = tgt is not None
        active = fighting and got_target

        # ── State transitions ──
        if active and not was_active:
            t_name = tgt.get("name", "???")
            last_target_name = t_name
            print(f"  >> ENGAGED — {t_name}")
        elif not active and was_active:
            if not got_target and fighting:
                kills += 1
                print(f"  >> KILL #{kills} ({last_target_name})  Total casts: {total_casts}")
            else:
                print(f"  >> DISENGAGED")
            print()

        was_active = active

        if not active:
            sleep(0.5)
            continue

        # ════════════════════════════════════════════
        #  ACTIVE COMBAT
        # ════════════════════════════════════════════

        t_hp = tgt.get("hp", 100.0)
        if isinstance(t_hp, str):
            try: t_hp = float(t_hp)
            except: t_hp = 100.0

        t_name = tgt.get("name", "???")
        last_target_name = t_name

        # ── Buffs ──
        now = time.time()
        if avail_buffs and now - last_buff_time > REBUFF_CD:
            for buff in avail_buffs:
                if cast(buff):
                    print(f"  [BUFF]  {buff}")
                    sleep(0.3)
            last_buff_time = now

        # ── DEFENSIVE (priority — skip rotation) ──
        if avail_def and my < DEFENSIVE_HP:
            for spell in avail_def:
                if cast(spell):
                    print(f"  [DEF]   {spell}  (HP:{my:.0f}%)")
                    sleep(TICK_RATE)
                    break
            continue

        # ── SELF HEAL in combat ──
        if avail_heals and my < HEAL_HP:
            for spell in avail_heals:
                if cast(spell):
                    print(f"  [HEAL]  {spell}  (HP:{my:.0f}%)")
                    sleep(TICK_RATE)
                    break

        # ── EXECUTE ──
        if avail_exec and t_hp < EXECUTE_HP:
            for spell in avail_exec:
                if cast(spell):
                    total_casts += 1
                    print(f"  [EXEC]  {spell}  Target:{t_name} {t_hp:.0f}%")
                    sleep(TICK_RATE)
                    break

        # ── MAIN ROTATION ──
        for spell in avail_rot:
            if cast(spell):
                total_casts += 1
                print(f"  [CAST]  {spell:25s}  HP:{my:.0f}%  vs {t_name} {t_hp:.0f}%")
                break

        sleep(TICK_RATE)

except KeyboardInterrupt:
    pass

print()
print("+" + "-" * 53 + "+")
print(f"|  Stopped.  Kills: {kills}   Casts: {total_casts}".ljust(54) + "|")
print("+" + "-" * 53 + "+")