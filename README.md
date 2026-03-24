# EthyrialHub

Automation toolkit for **Ethyrial: Echoes of Yore**. Native C++ hub with embedded Lua 5.4, ImGui overlay, and a full game-injection toolkit. Includes gather bots, combat rotations, speed hacks, and a scriptable plugin system.

## Quick Start

1. **Download** the latest ZIP from this repo (Code > Download ZIP)
2. **Extract** the full folder — keep `dist/scripts/` next to the EXE
3. Launch the game first, then **right-click `EthyrialHub.exe` > Run as Administrator**
4. Click **Connect** on the Home tab — the hub finds the game and injects automatically
5. Use the tabs to control everything

## Tabs

| Tab | What It Does |
|-----|-------------|
| **Home** | Connection status, player card (HP/MP/target/position) |
| **Rotation** | Class-specific combat rotations (Enchanter, Ranger, Brawler) |
| **Plugins** | Load/unload Lua plugins with their own ImGui overlay windows |
| **Scripts** | Browse and run standalone `.lua` / `.py` scripts |
| **Dev Tools** | Buff inspector, spell book, entity scanner, move/attack speed hacks, raw IPC console |
| **Settings** | Tick rates, overlay mode toggle, theme |
| **Log** | Color-coded, filterable live log of all events |

## Folder Structure

```
EthyrialHub/
├── EthyrialHub.exe                  <- Main application (run as admin)
└── dist/
    └── scripts/
        ├── gather_trees.lua         <- Tree-specific gathering
        ├── grind_bot.lua            <- Auto-grind with targeting & looting
        ├── auto_rotation.lua        <- Automatic DPS rotation
        ├── heal_rotation.lua        <- Automatic heal rotation
        ├── node_esp.lua             <- Node ESP overlay
        ├── test_connection.lua      <- Connection / API sanity check
        ├── api_check.lua            <- Full API endpoint test
        ├── debug_dump.lua           <- Dump game data for debugging
        ├── dump_brawler_spells.lua  <- Brawler spell data dump
        ├── live_capture.lua         <- Live data capture to file
        ├── builds/                  <- Class rotation profiles (.lua)
        ├── common/                  <- SDK & API libraries (required)
        ├── examples/                <- Scripting tutorials (01-07)
        └── gather_loop/             <- Plugin: interactive resource farmer
            ├── header.lua
            └── main.lua
```

## Plugins vs Scripts

**Plugins** are folders inside `dist/scripts/` containing `header.lua` + `main.lua`. They run inside the LuaRuntime with full access to ImGui windows, overlay graphics, and callbacks. Loading a plugin with a render callback automatically enables game overlay mode.

**Scripts** are standalone `.lua` or `.py` files. They run in isolated Lua states with pipe-based game access. Good for one-off tasks, dumps, and simpler automation.

## Gather Loop Plugin

The flagship plugin. Go to the **Plugins** tab, click **Load** on `gather_loop`:

- A floating window appears with checkboxes for every ore, tree, herb, and skin node in the game
- Check what you want, set range/gather wait, press **Start**
- It scans for matching nodes, walks to the nearest one, gathers it, and repeats
- Tracks stats (gathered/skipped), pauses when in combat or low HP

## Dev Tools — Speed Hacks

On the **Dev Tools** tab under **Player Mods**:

- **Movement Speed**: Slider from 1-30, Apply Once or Lock (continuous write). Quick presets: Normal (5), Fast (10), Sprint (15), Turbo (25)
- **Attack Speed**: Slider from 0.1-10, same Apply/Lock controls. Presets: Normal (1.0), Fast (0.5), Rapid (0.2), Instant (0.05)
- Response feedback shows OK or error (e.g., `NO_PLAYER` if not connected)

## Rotation Profiles

Built-in class rotations on the **Rotation** tab:

| Class | Key Mechanic |
|-------|-------------|
| **Enchanter** | Healer/support — Stormbolt filler, shields, Stream of Life |
| **Ranger** | Spirit Link stacks — SpiritShot generates, SpiritburstArrow spends (4+) |
| **Brawler** | Martial Combo stacks — generators build stacks, finishers spend them. Can't auto-attack with stacks up |

Select your class (or Auto-Detect), then Start Rotation.

## Writing Your Own Scripts

Check `dist/scripts/examples/` for tutorials starting with `01_hello_world.lua`.

### Available APIs

```lua
-- Player
core.player.hp()                    -- Current HP %
core.player.combat()                -- In combat?
core.player.pos()                   -- "x,y,z" string

-- Targeting
core.targeting.target_nearest()     -- Target nearest enemy
core.targeting.has_target()         -- Has a target?
core.targeting.target_hp()          -- Target HP %

-- Spells
core.spells.cast("SpellName")       -- Cast by name
core.spells.is_ready("SpellName")   -- Off cooldown?
core.spells.cooldown("SpellName")   -- Remaining CD

-- Movement
core.movement.move_to(x, y)        -- Walk to position
core.movement.stop()                -- Stop moving

-- Gathering
core.gathering.node_scan()          -- Scan all nodes
core.gathering.gather_nearest()     -- Gather closest node

-- Graphics (overlay drawing, use in on_render callbacks)
core.graphics.text_2d(x, y, "text", color)
core.graphics.line_2d(x1, y1, x2, y2, color)
core.graphics.circle_2d(cx, cy, r, color)
core.graphics.set_camera(cx,cy,cz, lx,ly,lz, fov)
core.graphics.world_to_screen(wx, wy, wz)  -- -> sx, sy
core.graphics.text_3d(wx, wy, wz, "text", color)
core.graphics.line_3d(x1,y1,z1, x2,y2,z2, color)
core.graphics.circle_3d(wx, wy, wz, radius, color)

-- ImGui (create your own windows)
core.imgui.begin_window("Title")
core.imgui.button("Click Me")
core.imgui.checkbox("Option", default)
core.imgui.slider_int("Speed", value, min, max)
core.imgui.end_window()

-- Callbacks
ethy.on_update(function() ... end)  -- Called every tick
ethy.on_render(function() ... end)  -- Called every frame (draw here)
```

## Requirements

- Windows 10/11 (64-bit)
- Ethyrial: Echoes of Yore running
- **Run as Administrator** (required for process injection)
- No VC++ Redistributable needed (static CRT)

## Building From Source

Requires Visual Studio 2022 with C++ desktop workload.

1. Build **EthyTool** project first (produces the DLL)
2. Build **EthyrialHub** project (embeds the DLL as payload automatically)
3. Copy `x64/Debug/EthyrialHub.exe` (or `x64/Build/`) to the repo root
