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
        ├── YOURL_LUA_SCRIPT.lua      <- Connection / API sanity check
```

## Plugins vs Scripts

**Plugins** are folders inside `dist/scripts/` containing `header.lua` + `main.lua`. They run inside the LuaRuntime with full access to ImGui windows, overlay graphics, and callbacks. Loading a plugin with a render callback automatically enables game overlay mode.

**Scripts** are standalone `.lua` files. 

## Writing Your Own Scripts

Check `dist/scripts/examples/` for tutorials starting with `01_hello_world.lua`.

### Available APIs


## Requirements

- Windows 10/11 (64-bit)
- Ethyrial: Echoes of Yore running
- **Run as Administrator** (required for process injection)
- No VC++ Redistributable needed (static CRT)
