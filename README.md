# EthyTool

Hit that Star Button if you enjoy this!

Hit Pull Request to merge your scripts/updates!

Work in Progress

A modding and scripting toolkit for Ethyrial: Echoes of Yore. Read game data, interact with entities, build overlays, track stats, create custom tools — all through a simple Python API.

---

flowchart LR
    subgraph current [Current: Everything On One Pipe]
        PY1[GatherBot] -->|"SCENE_SCAN_HERBS"| CMD[EthyToolPipe]
        PY2[CombatScript] -->|"PLAYER_HP"| CMD
        PY3[CombatScript] -->|"TARGET_HP"| CMD
        PY4[CombatScript] -->|"SPELL_CD"| CMD
        CMD -->|"blocks while scanning"| DLL[ProcessCommand]
    end


## Requirements

- **Windows 10/11**
- **Python 3.10+** — [Download here](https://www.python.org/downloads/)
  - Use the **classic executable installer** — **do not use the new Python Installation Manager** (Store/WinGet). The new installer can cause compatibility issues.
  - During install, check **"Add Python to PATH"**
- **Ethyrial: Echoes of Yore**

---

## Setup

1. Download the latest release
2. Extract to any folder
3. **Run `install_all.bat`** (right-click → Run as administrator) — installs VC++ Redist, Defender exclusion, firewall rules, and optional Python packages
4. Or install manually:
   - Install Python if you haven't already (classic installer only)
   - Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
5. **Get a key** — reach out to **MrJambix** on Discord
6. Launch the game
7. Run `EthyTool.exe`
8. Enter your key when prompted
9. Click **Inject**
10. Open the Scripts tab and run scripts

## Folder Structure

```
EthyTool/
├── EthyTool.exe              run this
├── EthyTool.dll              auto-injected
├── install_all.bat           full setup (VC++, Defender, firewall, deps)
├── install_firewall.ps1       used by install_all.bat
├── check_pipe_block.bat      pipe diagnostic if connection fails
├── server_config.yaml        token list (keys validated locally)
├── requirements.txt          Python dependencies
├── lib/
│   ├── ethytool_lib.py       low-level API + ScreenReader
│   └── ethytool_wraps.py     simple API
├── scripts/                  your scripts go here
│   ├── auto_rotation.py
│   ├── dps_dashboard.py      live DPS charts
│   ├── loot_all.py
│   ├── builds/               class rotations
│   ├── debugs/               debug utilities
│   ├── dumps/                dump scripts (spells, doodads, etc.)
│   ├── templates/            auto_gather, auto_farm, etc.
│   └── plugins/
└── docs/
    ├── WRAPS.md              wraps reference
    ├── COMMANDS.md           raw DLL commands
    └── SCRIPTING.md          how to write scripts
```

---

## Links

- [Wraps Reference](docs/WRAPS.md) — every simple function
- [Scripting Guide](docs/SCRIPTING.md) — how to write scripts
- [DLL Commands](docs/COMMANDS.md) — raw pipe commands
