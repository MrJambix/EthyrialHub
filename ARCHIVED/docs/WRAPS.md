# EthyTool Wraps — Quick Reference

Use `from ethytool_wraps import *` at the top of your script.

## Player
| Call | Returns | Description |
|------|---------|-------------|
| `hp()` | `85.5` | Health % |
| `mp()` | `92.3` | Mana % |
| `max_hp()` | `4785` | Max health |
| `max_mp()` | `1011` | Max mana |
| `gold()` | `54321` | Gold |
| `pos()` | `(x, y, z)` | Position |
| `x()` / `y()` / `z()` | `float` | Single coordinate |
| `speed()` | `4.5` | Move speed |
| `food()` | `85.0` | Food level |
| `job()` | `"Mining"` | Current job |
| `alive()` | `True` | HP > 0? |
| `moving()` | `False` | Walking? |
| `frozen()` | `False` | Controls locked? |
| `combat()` | `True` | In combat? |
| `safe_zone()` | `False` | In safe zone? |
| `wildlands()` | `True` | In PvP zone? |
| `low_hp(30)` | `True` | HP below 30%? |
| `low_mp(20)` | `True` | MP below 20%? |
| `dist(x, y)` | `42.5` | Distance to point |
| `near(x, y, 10)` | `True` | Within 10 units? |

## Target
| Call | Returns | Description |
|------|---------|-------------|
| `target()` | `dict` or `None` | Full target info |
| `target_hp()` | `60.5` | Target HP % |
| `target_name()` | `"Wolf"` | Target name |
| `has_target()` | `True` | Have a target? |
| `target_dead()` | `False` | Target HP = 0? |
| `target_boss()` | `False` | Is boss? |
| `target_elite()` | `False` | Is elite? |
| `friendly()` | `dict` or `None` | Friendly target |

## Casting
| Call | Returns | Description |
|------|---------|-------------|
| `cast("Fireball")` | `True` | Cast a spell |
| `cast_first(["A","B"])` | `"A"` or `None` | First available |
| `spells()` | `[dict]` | All spells |
| `spell_names()` | `[str]` | Spell names |
| `has_spell("Heal")` | `True` | Know this spell? |
| `spell_ready("Heal")` | `True` | Off cooldown? |
| `my_class()` | `"Warrior"` | Detected class |
| `available(["A","B"])` | `["A"]` | Filter to known |

## Gathering
| Call | Returns | Description |
|------|---------|-------------|
| `use("Stone")` | `True` | Interact with entity |
| `gather("Stone")` | `True` | Full gather cycle |
| `progress()` | `True` | Bar active? |
| `wait_progress()` | `True` | Wait for bar |
| `doodads()` | `[dict]` | All doodads |
| `harvestable()` | `[dict]` | Full nodes only |
| `scan()` | `[dict]` | DLL nearby scan |
| `scan_all()` | `[dict]` | DLL scene scan |

## Inventory
| Call | Returns | Description |
|------|---------|-------------|
| `items()` | `[dict]` | All items |
| `item_count()` | `24` | Item count |
| `item_names()` | `[str]` | Item names |
| `has("Potion")` | `True` | Have this item? |
| `count_item("Ore")` | `47` | Stack total |
| `find_item("Sword")` | `dict` or `None` | Find item |
| `equipped()` | `[dict]` | Equipped gear |

## Loot
| Call | Returns | Description |
|------|---------|-------------|
| `loot()` | `True` | Loot all windows |
| `loot_nearest()` | `True` | Find + loot nearest |
| `auto_loot()` | `True` | Open + loot |
| `open_corpse()` | `True` | Open nearest corpse |
| `has_loot()` | `True` | Loot window open? |
| `loot_items()` | `[dict]` | Window contents |

## Wait Helpers
| Call | Description |
|------|-------------|
| `sleep(1)` | Wait 1 second |
| `wait_no_combat()` | Until out of combat |
| `wait_hp(90)` | Until HP above 90% |
| `wait_still()` | Until not moving |
| `wait_dead()` | Until target dead |
| `wait_spell("Heal")` | Until spell ready |
| `heal_if_low("Heal", 50)` | Heal if HP < 50% |

## Bulk
| Call | Returns | Description |
|------|---------|-------------|
| `all_stats()` | `dict` | Everything in one call |
| `ping()` | `True` | DLL alive? |
| `version()` | `"3.0.0"` | DLL version |