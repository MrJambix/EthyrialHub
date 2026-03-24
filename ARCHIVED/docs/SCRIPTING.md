# Writing Custom Scripts

## Basics

Scripts are Python files in the `scripts/` folder. They run inside EthyTool with `conn` already connected.

### Simplest possible script
```python
from ethytool_wraps import *

print(f"HP: {hp()}")
print(f"Gold: {gold()}")
print(f"Position: {pos()}")
```

### Loop script
```python
from ethytool_wraps import *

while True:
    print(f"HP: {hp():.0f}%  MP: {mp():.0f}%")
    sleep(1)
```

## Common Patterns

### Auto-heal
```python
from ethytool_wraps import *

while True:
    if low_hp(50):
        cast("Heal")
    sleep(0.5)
```

### Gather one type
```python
from ethytool_wraps import *

while True:
    if gather("Stone"):
        print("Got stone!")
    sleep(1)
```

### Fight and loot
```python
from ethytool_wraps import *

while True:
    if combat() and has_target():
        cast_first(["Fireball", "Lightning", "Auto Attack"])
    elif not combat():
        loot_nearest()
    sleep(0.5)
```

### Monitor inventory
```python
from ethytool_wraps import *

while True:
    ore = count_item("Iron Ore")
    print(f"Iron Ore: {ore}")
    if ore >= 100:
        print("Inventory full!")
        break
    sleep(5)
```

## Tips

- `sleep(0.5)` between actions to avoid spamming
- `cast_first([...])` is better than multiple `cast()` calls
- `harvestable()` already filters out depleted nodes
- `gather("Stone")` does the full cycle — use + wait + delay
- `from ethytool_wraps import *` gives you all simple functions
- Use `conn.whatever()` for advanced stuff not in wraps
```