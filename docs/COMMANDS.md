# DLL Pipe Commands Reference

Raw commands you can send via `conn._send("COMMAND")`.
You normally don't need these — use the lib or wraps instead.

## System
| Command | Response | Description |
|---------|----------|-------------|
| `PING` | `PONG` | DLL alive check |
| `VERSION` | `3.4.0` | DLL version |
| `INIT` | `OK` or error | Initialize game API |
| `IS_INIT` | `1` or `0` | Is API ready? |
| `ERROR` | string | Last error message |

## Player
| Command | Response |
|---------|----------|
| `PLAYER_HP` | `85.5000` |
| `PLAYER_MP` | `92.3000` |
| `PLAYER_MAX_HP` | `4785` |
| `PLAYER_MAX_MP` | `1011` |
| `PLAYER_POS` | `4718.0000,1306.0000,1.0000` |
| `PLAYER_COMBAT` | `1` or `0` |
| `PLAYER_MOVING` | `1` or `0` |
| `PLAYER_FROZEN` | `1` or `0` |
| `PLAYER_GOLD` | `54321` |
| `PLAYER_ALL` | `hp=85\|mp=92\|gold=54321\|...` |

## Target
| Command | Response |
|---------|----------|
| `HOSTILE_TARGET` | `uid=123\|name=Wolf\|hp=60\|...` or `NONE` |
| `FRIENDLY_TARGET` | same format or `NONE` |

## Casting
| Command | Response |
|---------|----------|
| `CAST_Fireball` | `OK_CAST`, `OK_HOTKEY`, `OK_USESLOT`, or error |
| `SPELLS_ALL` | `name=...\|display=...\|cd=...###...` |
| `SPELL_COUNT` | `8` |

## Entities
| Command | Response |
|---------|----------|
| `SCAN_NEARBY` | `count=N###class=...\|name=...\|...` |
| `SCAN_SCENE` | same format |
| `USE_ENTITY_Stone` | `OK_USED\|class=Doodad\|name=Stone\|invoke=0` |
| `HAS_PROGRESS` | `1` or `0` |
| `NEARBY_ALL` | `uid=...\|name=...\|x=...###...` |
| `NEARBY_LIVING` | same with HP fields |
| `SCENE_ALL` | same format |

## Inventory
| Command | Response |
|---------|----------|
| `INV_ALL` | `uid=...\|name=...\|stack=...###...` |
| `INV_COUNT` | `24` |
| `EQUIPPED` | same format |

## Loot
| Command | Response |
|---------|----------|
| `LOOT_ALL` | `OK_LOOTED_N` |
| `OPEN_CORPSE` | `OK_OPENED_CORPSE_OF_...` |
| `AUTO_LOOT` | `OK_OPENED...\|OK_LOOTED...` |
| `LOOT_NEAREST` | `OK_...` |
| `LIST_CORPSES` | `corpseOf=...\|contUID=...###...` |

## Debug
| Command | Response |
|---------|----------|
| `DUMP_OFFSETS` | offset dump |
| `DUMP_FIELDS_Entity` | field dump for class |
| `DUMP_METHODS_Entity` | method dump for class |