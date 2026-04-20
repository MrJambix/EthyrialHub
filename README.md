# EthyrialHub

A companion app for **Ethyrial: Echoes of Yore** — manage addons, plugins, scripts, and live game data from a single desktop hub.

## DISCORD
https://discord.gg/thSFuUm3gu

## Quick Start

1. **Download** the latest release ZIP from [Releases](../../releases) or clone this repo
2. **Extract** the full folder — keep the folder structure intact
3. Launch **Ethyrial: Echoes of Yore** first
4. **Right-click `EthyrialHub.exe` → Run as Administrator**
5. Click **Connect** on the Home tab — the hub detects the game and injects automatically

## Features

| Tab | Description |
|-----|-------------|
| **Home** | Connection dashboard — scan for the game process, inject, connect/reconnect. Shows inject status and quick-start info. |
| **Player** | Live player stats — name, level, class, HP/MP, position, zone, and current target info (polled every second). |
| **Addons** | WoW-style addon manager — scans `.toc` files in the game's `Addons/` folder. Enable/disable addons, browse metadata. |
| **Plugins** | Manage Lua plugins in the game's `plugins/` directory. Load, unload, reload individually or all at once. |
| **Scripts** | Inline Lua editor — write and execute Lua code live inside the game. |
| **Discovery** | Online plugin catalog — browse, search, and install community plugins from the companion API. |
| **Downloads** | Track in-progress and completed downloads. |
| **Map** | Interactive map overlay with player position (coming soon). |
| **Navmesh** | Navigation mesh recorder for pathfinding (coming soon). |
| **Log** | Real-time log viewer with filtering, auto-scroll, copy, and clear. |
| **Settings** | Game path configuration (auto-detects Steam install), connection controls, render settings, language prefs. |

## How It Works

- **DLL Injection** — Injects `EthyTool.dll` into the running game via PowerShell/C# interop (`CreateRemoteThread` + `LoadLibraryW`). No native Node modules required.
- **Named Pipe Bridge** — Communicates with the injected DLL over three named pipes per game instance (commands, events, status).
- **In-Game Overlay** — Automatically starts an ImGui overlay on connection so plugins can render UI inside the game.
- **Auto-Reconnect** — Burst retries followed by slow retries, with a grace period before reporting disconnection.

## Requirements

- Windows 10/11 (64-bit)
- Ethyrial: Echoes of Yore running
- **Run as Administrator** (required for process injection)
