# EthyTool

Automation toolkit for Ethyrial: Echoes of Yore. Includes a hub application with built-in script engine, gather bots, combat rotations, and a full Lua scripting API.

## Quick Start

1. **Clone or download** this repo
2. Launch the game first, then **right-click `EthyrialHub.exe` → Run as Administrator**
3. Click **Connect** on the Home tab — the hub will find the game and inject automatically
4. Go to the **Bots** or **Scripts** tab to start automation

## Folder Structure

```
EthyTool/
├── EthyrialHub.exe              ← Main application (run as admin)
└── dist/
    └── scripts/
        ├── gather_loop.lua      ← Interactive resource farming bot
        ├── grind_bot.lua        ← Auto-grind with targeting & looting
        ├── auto_rotation.lua    ← Automatic DPS rotation
        ├── heal_rotation.lua    ← Automatic heal rotation
        ├── node_esp.lua         ← Node ESP overlay
        ├── gather_trees.lua     ← Tree-specific gathering
        ├── test_connection.lua  ← Connection / API sanity check
        ├── builds/              ← Class-specific build profiles
        ├── common/              ← SDK & API libraries (required)
        └── examples/            ← Scripting tutorials & samples
```

## Included Scripts

| Script | Description |
|--------|-------------|
| `gather_loop.lua` | Opens a floating window with checkboxes for every node type. Check what you want, press Start, and it farms them automatically. |
| `grind_bot.lua` | Full auto-grind: target enemies, run rotation, loot corpses, rest when low. |
| `auto_rotation.lua` | Fires your DPS rotation based on class build profile. |
| `heal_rotation.lua` | Party healer — heals lowest HP member, weaves DPS when safe. |
| `node_esp.lua` | Draws ESP markers on nearby gathering nodes. |
| `gather_trees.lua` | Specialized tree chopping loop. |
| `test_connection.lua` | Quick check that IPC, SHM, and APIs are working. |

## Writing Your Own Scripts

Check out `dist/scripts/examples/` for step-by-step tutorials, starting with `01_hello_world.lua`. The full API reference is in `dist/scripts/examples/README_SCRIPTING.md`.

Every script has access to:
- `core.imgui.*` — Create your own floating ImGui windows
- `core.menu.*` — Add checkboxes/sliders to the Settings tab
- `core.player.*` — Read HP, mana, position, combat state
- `core.movement.*` — Move to coordinates, follow targets
- `core.targeting.*` — Target enemies, interact with objects
- `core.spells.*` — Cast spells, check cooldowns
- `core.gathering.*` — Scan and interact with resource nodes
- `core.inventory.*` — Check bags, loot items

## Requirements

- Windows 10/11 (64-bit)
- Ethyrial: Echoes of Yore running
- **Run as Administrator** (required for process injection)

## Building From Source

Requires Visual Studio 2022 with C++ desktop workload.

1. Open `EthyrialHub.sln` in Visual Studio
2. Set configuration to **Release | x64**
3. Build the solution
4. Copy `x64/Release/EthyrialHub.exe` into the repo root
