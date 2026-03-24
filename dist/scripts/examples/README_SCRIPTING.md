# EthyrialHub Scripting Guide

## How Scripts Work

The Hub connects to the game via named pipes. Scripts send text commands
and receive text responses. The `conn` object wraps all of this.

**Python scripts** (.py) get `conn` and `stop_event` injected automatically
by the Hub's script runner. Just write your logic — no boilerplate needed.

**Lua scripts** (.lua) get a `conn` table and `is_stopped()` function.

---

## Quick Start

### Python Script Template

```python
# my_script.py — place in the scripts folder
import time

print("Script started!")
print("Class: " + conn.detect_class())

while not stop_event.is_set():
    hp = conn.get_hp()
    mp = conn.get_mp()
    print(f"HP: {hp:.0f}%  MP: {mp:.0f}%")
    time.sleep(1)

print("Script stopped.")
```

### Lua Script Template

```lua
-- my_script.lua — place in the scripts folder

print("Script started!")
print("Class: " .. conn.send_command("DETECT_CLASS"))

while not is_stopped() do
    local hp = conn.get_hp()
    local mp = conn.get_mp()
    print(string.format("HP: %.0f%%  MP: %.0f%%", hp, mp))
    conn.send_command("SLEEP 1000")
end

print("Script stopped.")
```

---

## conn API Reference (Python)

### Vitals
- `conn.get_hp()` → float (0-100)
- `conn.get_mp()` → float (0-100)
- `conn.in_combat()` → bool
- `conn.has_target()` → bool
- `conn.is_dead()` → bool
- `conn.is_alive()` → bool
- `conn.get_pos()` → (x, y, z)

### Targeting
- `conn.target_nearest()` → target the closest enemy
- `conn.target_party(index)` → target party member by index
- `conn.target_friendly(uid)` → target a friendly by UID

### Combat
- `conn.try_cast("Spell Name")` → bool (True if cast succeeded)
- `conn.do_rotation()` → run the loaded rotation
- `conn.do_buff()` → cast all buff spells
- `conn.do_pull()` → initiate combat (gap closer + opener)
- `conn.do_defend()` → cast defensive spells
- `conn.do_recover(hp_target=90, mp_target=80, timeout=30)` → rest until thresholds

### Healing
- `conn.do_heal_target()` → heal current target
- `conn.do_heal_party()` → heal lowest-HP party member
- `conn.do_shield_party()` → shield the party
- `conn.get_party_below(hp)` → get party members below HP%

### Loot / Gather
- `conn.do_loot()` or `conn.send_command("LOOT_ALL")` → loot everything
- `conn.send_command("GATHER_NEAREST")` → gather nearest node

### Movement
- `conn.send_command("MOVE_TO_TARGET")` → walk to target
- `conn.send_command("STOP_MOVEMENT")` → stop moving
- `conn.send_command("FOLLOW_ENTITY uid")` → follow an entity
- `conn.send_command("MOVE_TO x y z")` → walk to coordinates

### Scanning
- `conn.send_command("SCAN_NEARBY")` → list nearby entities
- `conn.send_command("SCAN_ENEMIES")` → list enemies
- `conn.send_command("PARTY_SCAN")` → list party members
- `conn.send_command("NODE_SCAN")` → list gathering nodes
- `conn.send_command("SCENE_SCAN_HERBS")` → list herbs
- `conn.send_command("SCENE_SCAN_ORES")` → list ores

### Info
- `conn.detect_class()` → player's class name
- `conn.get_class_spells()` → list of spells
- `conn.send_command("PLAYER_ALL")` → full player data dump
- `conn.send_command("SPELLS_ALL")` → all spell details
- `conn.send_command("INV_ALL")` → inventory list

### Items
- `conn.send_command("USE_ITEM Name")` → use an item
- `conn.send_command("EQUIP_ITEM Name")` → equip an item
- `conn.send_command("INV_COUNT")` → inventory slot count

### Pets
- `conn.send_command("COMPANIONS")` → list companions
- `conn.send_command("PET_ATK_SPEED")` → pet attack speed

### Raw Commands
- `conn.send_command("ANY_COMMAND")` → send any IPC command directly

---

## Creating a Build Profile

Build profiles define spell rotations for a class. Place them in `builds/`.

```python
# builds/my_class.py

HEAL_HP        = 50    # Start healing below this HP%
DEFENSIVE_HP   = 40    # Use defensives below this HP%
EMERGENCY_HP   = 20    # Emergency shields below this HP%
REST_HP        = 80    # Rest after combat below this HP%
REST_MP        = 60
MANA_CONSERVE  = 25
TICK_RATE      = 0.3   # Seconds between rotation ticks

BUFFS = [
    "Buff Spell 1",
    "Buff Spell 2",
]

OPENER = [
    "Opening Spell 1",
    "Opening Spell 2",
]

ROTATION = [
    "Main Damage Spell",
    "Secondary Spell",
    "Filler Spell",
]

HEAL_SPELLS = [
    "Healing Spell",
]

DEFENSIVE_SPELLS = [
    "Shield Spell",
    "Defensive Spell",
]

REST_SPELL = "Rest"
MEDITATION_SPELL = "Leyline Meditation"
```

The rotation engine will auto-detect your class and load the matching profile.
