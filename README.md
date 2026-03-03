# EthyTool

Automation tool for Ethyrial: Echoes of Yore.

## Setup

1. Download the latest release
2. Extract to any folder
3. Run `EthyTool.exe`
4. Launch the game
5. Click **Inject** in EthyTool
6. Run scripts from the Scripts tab

## Writing Scripts

Scripts go in the `scripts/` folder. They have access to two libraries:

### Simple Mode (recommended)
```python
from ethytool_wraps import *

# Your HP
print(hp())

# Cast a spell
cast("Fireball")

# Gather a node
gather("Stone")

# Check if in combat
if combat():
    cast_first(["Fireball", "Lightning"])
```

### Advanced Mode
```python
# conn is always available
target = conn.get_target()
if target:
    print(f"Fighting {target['name']} at {target['hp']:.0f}%")
```

### Quick Reference

| Simple (wraps)        | Advanced (lib)              | What it does           |
|-----------------------|-----------------------------|------------------------|
| `hp()`                | `conn.get_hp()`             | Your HP %              |
| `mp()`                | `conn.get_mp()`             | Your MP %              |
| `gold()`              | `conn.get_gold()`           | Your gold              |
| `pos()`               | `conn.get_position()`       | Your (x, y, z)         |
| `combat()`            | `conn.in_combat()`          | In combat?             |
| `cast("Heal")`        | `conn.cast("Heal")`         | Cast a spell           |
| `cast_first([...])`   | `conn.cast_first([...])`    | Cast first available   |
| `has_target()`        | `conn.has_target()`         | Have a target?         |
| `target_hp()`         | `conn.get_target_hp()`      | Target HP %            |
| `target_name()`       | `conn.get_target_name()`    | Target name            |
| `use("Stone")`        | `conn.use_entity("Stone")`  | Interact with entity   |
| `gather("Stone")`     | `conn.gather("Stone")`      | Full gather cycle      |
| `harvestable()`       | `conn.scan_harvestable()`   | List full nodes        |
| `loot()`              | `conn.loot()`               | Loot all               |
| `items()`             | `conn.get_inventory()`      | Your inventory         |
| `has("Potion")`       | `conn.has_item("Potion")`   | Have an item?          |
| `nearby()`            | `conn.get_nearby()`         | Nearby entities        |
| `sleep(1)`            | `time.sleep(1)`             | Wait                   |

## Combat Rotations

1. Copy `scripts/rotations/template.py`
2. Rename to your class (e.g. `warrior.py`)
3. Fill in your spell names
4. Run `combat.py` — it auto-detects your class!

## Folder Structure

```
EthyTool/
├── EthyTool.exe          ← run this
├── EthyTool.dll          ← auto-injected
├── lib/                  ← don't touch
│   ├── ethytool_lib.py
│   └── ethytool_wraps.py
├── scripts/              ← your scripts go here
│   ├── combat.py
│   ├── harvest.py
│   └── rotations/
│       └── template.py
└── docs/                 ← reference guides
```