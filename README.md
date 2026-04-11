# EthyrialHub

Native C++ hub with embedded Lua 5.4, ImGui overlay, and a full game-injection toolkit. Includes a scriptable plugin system.

## DISCORD
https://discord.gg/thSFuUm3gu

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
| **Plugins** | Load/unload Lua plugins with their own ImGui overlay windows |
| **Scripts** | Browse and run standalone `.lua` / `.py` scripts |
| **Settings** | Tick rates, overlay mode toggle, theme |
| **Log** | Color-coded, filterable live log of all events |

## Folder Structure

```
EthyrialHub/
├── EthyrialHub.exe                  <- Main application (run as admin)
└── dist/
    └── scripts/
        ├── test_connection.lua      <- Connection / API sanity check
```

## Plugins vs Scripts

**Plugins** are folders inside `dist/scripts/` containing `header.lua` + `main.lua`. They run inside the LuaRuntime with full access to ImGui windows, overlay graphics, and callbacks. Loading a plugin with a render callback automatically enables game overlay mode.

**Scripts** are standalone `.lua` files. 

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
