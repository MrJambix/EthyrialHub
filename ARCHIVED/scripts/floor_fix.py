"""
Floor Fix Tool — client-side workaround for "stuck on level / can't drop holes"
================================================================================
Detects the TileEngine-vs-player floor mismatch and fixes it by calling
the game's own IL2CPP methods through existing DLL commands.

Two modes:
  1) Smart Fix  — auto-detects the desync and runs the game's recalculation
                  methods in the correct order.
  2) Manual Override — lets you type a target floor and force the player there.

Run from EthyTool dashboard.
"""

import time
import tkinter as tk
from tkinter import ttk
from pathlib import Path

try:
    conn
    stop_event
except NameError:
    print("ERROR: Run from EthyTool dashboard.")
    raise SystemExit(1)

# ═══════════════════════════════════════════════════════════════
#  Theme (matches floor_debug.py)
# ═══════════════════════════════════════════════════════════════

BG       = "#0a0e14"
BG_CARD  = "#12161e"
BG_INPUT = "#1a1f2b"
TEXT     = "#e6edf3"
TEXT_DIM = "#6e7681"
ACCENT   = "#58a6ff"
GREEN    = "#3fb950"
RED      = "#f85149"
ORANGE   = "#d29922"
YELLOW   = "#e3b341"
PURPLE   = "#BC8CFF"
CYAN     = "#56d4dd"
FONT     = "Segoe UI"
FONT_B   = "Segoe UI Semibold"
FONT_M   = "Cascadia Code"

# ═══════════════════════════════════════════════════════════════
#  Offsets (from game_offsets.py + IL2CPP dump)
# ═══════════════════════════════════════════════════════════════

OFF_POS_Z              = 0x140   # Entity._position.z  (f32) — floor level
OFF_DFG                = 0x130   # Entity._dfg         (f32)
OFF_LAST_DFG           = 0x124   # Entity.lastDFG      (f32)
OFF_GROUNDED           = 0x36C   # LivingEntity.grounded       (bool)
OFF_AERIAL_POS_Z       = 0x370   # LivingEntity.aerialPositionZ (f32)
OFF_IN_WORLD_COLLIDER  = 0x16D   # Entity.IsInWorldCollider    (bool)
OFF_TILE_CHANGED       = 0x574   # LocalPlayerEntity.tileChanged        (bool)
OFF_LAST_MOVE_FLOOR    = 0x690   # LocalPlayerEntity._lastMovementFloor (i32)
OFF_OUTER_COLLIDER     = 0x178   # Entity.inWorldOuterCollider (bool)

BATCH_STATE = (
    "0x140:f32 "    # pos_z
    "0x130:f32 "    # dfg
    "0x124:f32 "    # last_dfg
    "0x36C:bool "   # grounded
    "0x370:f32 "    # aerialPosZ
    "0x16D:bool "   # in_world_collider
    "0x574:bool "   # tileChanged
    "0x690:i32 "    # _lastMovementFloor
    "0x178:bool"    # inWorldOuterCollider
)
STATE_KEYS = [
    "pos_z", "dfg", "last_dfg", "grounded", "aerialPosZ",
    "in_world_collider", "tileChanged", "last_move_floor",
    "outer_collider",
]
STATE_TYPES = {
    "pos_z": float, "dfg": float, "last_dfg": float,
    "aerialPosZ": float, "grounded": bool,
    "in_world_collider": bool, "tileChanged": bool,
    "last_move_floor": int, "outer_collider": bool,
}


def _parse_val(raw, key):
    dtype = STATE_TYPES.get(key, str)
    if raw is None or raw in ("", "null", "NULL"):
        return None
    if dtype is bool:
        return raw.lower() == "true" or raw == "1"
    if dtype is float:
        try:
            return float(raw)
        except (ValueError, TypeError):
            return raw
    if dtype is int:
        try:
            return int(raw)
        except (ValueError, TypeError):
            return raw
    return raw


def _fmt(val):
    if isinstance(val, float):
        return f"{val:.3f}"
    return str(val) if val is not None else "?"


# ═══════════════════════════════════════════════════════════════
#  Engine — reads state, detects mismatches, applies fixes
# ═══════════════════════════════════════════════════════════════

class FloorFixEngine:
    REFRESH_MS = 500

    def __init__(self, conn, stop_event, log_fn):
        self.conn = conn
        self.stop_event = stop_event
        self.log = log_fn
        self.state = {}
        self.te_ground_floor = None
        self.te_layer = None
        self.te_floors_changed = None
        self.issues = []

    def read_state(self):
        c = self.conn
        snap = {}

        raw_vals = c.batch_read("player", BATCH_STATE)
        if not raw_vals or len(raw_vals) < len(STATE_KEYS):
            return None
        for i, key in enumerate(STATE_KEYS):
            snap[key] = _parse_val(raw_vals[i] if i < len(raw_vals) else None, key)

        for te_key, method, fallback, dtype in [
            ("te_ground_floor", "get_GroundFloor", "<GroundFloor>k__BackingField", "i32"),
            ("te_layer",        "get_Layer",       "layer",                         "i32"),
        ]:
            val = None
            try:
                raw = c._send(f"INVOKE_METHOD TileEngine {method} 0")
                if raw and raw not in ("NOT_FOUND", "UNKNOWN_CMD", "NO_INSTANCE",
                                       "ERROR", "INVOKE_ERROR", "CLASS_NOT_FOUND",
                                       "METHOD_NOT_FOUND"):
                    val = int(raw)
            except Exception:
                pass
            if val is None:
                try:
                    raw = c._send(f"READ_FIELD TileEngine {fallback}")
                    if raw and raw not in ("NOT_FOUND", "UNKNOWN_CMD", "NO_INSTANCE"):
                        val = int(raw)
                except Exception:
                    pass
            snap[te_key] = val

        try:
            raw = c._send("READ_FIELD TileEngine floorsHasChanged")
            if raw and raw not in ("NOT_FOUND", "UNKNOWN_CMD", "NO_INSTANCE"):
                snap["te_floors_changed"] = (raw.lower() == "true" or raw == "1")
            else:
                snap["te_floors_changed"] = None
        except Exception:
            snap["te_floors_changed"] = None

        self.state = snap
        self.te_ground_floor = snap.get("te_ground_floor")
        self.te_layer = snap.get("te_layer")
        self.te_floors_changed = snap.get("te_floors_changed")
        return snap

    def diagnose(self):
        s = self.state
        if not s:
            return ["Cannot read player state"]

        issues = []
        pos_z = s.get("pos_z")
        player_floor = int(pos_z) if isinstance(pos_z, (int, float)) and pos_z is not None else None
        te_layer = s.get("te_layer")
        te_gf = s.get("te_ground_floor")
        tile_chg = s.get("tileChanged")
        dfg = s.get("dfg")
        grounded = s.get("grounded")
        last_mf = s.get("last_move_floor")

        if player_floor is not None and te_layer is not None and te_layer != player_floor:
            issues.append(f"DESYNC: TileEngine.layer={te_layer} but player floor={player_floor}")

        if player_floor is not None and te_gf is not None and te_gf != player_floor:
            issues.append(f"DESYNC: TileEngine.GroundFloor={te_gf} but player floor={player_floor}")

        if tile_chg is False:
            issues.append("tileChanged stuck at False — floor transition blocked")

        if isinstance(dfg, (int, float)) and dfg == 0.0 and player_floor is not None and player_floor > 0:
            issues.append(f"dfg=0.0 on floor {player_floor} — hole detection not working")

        if grounded is True and isinstance(dfg, (int, float)) and dfg == 0.0:
            issues.append("Permanently grounded with dfg=0 — can never enter aerial/drop state")

        if player_floor is not None and last_mf is not None and last_mf != player_floor:
            issues.append(f"_lastMovementFloor={last_mf} != pos_z floor={player_floor}")

        self.issues = issues
        return issues

    def smart_fix(self):
        s = self.state
        if not s:
            self.log("[ERROR] No state — refresh first")
            return False

        pos_z = s.get("pos_z")
        player_floor = int(pos_z) if isinstance(pos_z, (int, float)) else None
        if player_floor is None:
            self.log("[ERROR] Cannot determine player floor from pos_z")
            return False

        c = self.conn
        steps = 6
        ok = True

        self.log(f"[FIX 1/{steps}] Syncing TileEngine.layer -> {player_floor}")
        r = c._send(f"INVOKE_METHOD TileEngine set_Layer 1 {player_floor}")
        self.log(f"  result: {r}")
        if r in ("CLASS_NOT_FOUND", "METHOD_NOT_FOUND", "NO_INSTANCE"):
            self.log("  [WARN] TileEngine.set_Layer failed — trying GroundFloor")
            r2 = c._send(f"INVOKE_METHOD TileEngine set_GroundFloor 1 {player_floor}")
            self.log(f"  set_GroundFloor result: {r2}")

        self.log(f"[FIX 2/{steps}] Setting tileChanged = true")
        r = c.write_at("player", OFF_TILE_CHANGED, "bool", "1")
        self.log(f"  result: {'OK' if r else 'FAILED'}")
        if not r:
            ok = False

        self.log(f"[FIX 3/{steps}] ForceUpdateOnTiles()")
        r = c._send("INVOKE_METHOD Entity ForceUpdateOnTiles 0")
        self.log(f"  result: {r}")

        self.log(f"[FIX 4/{steps}] CheckCurrentTile(force=true)")
        r = c._send("INVOKE_METHOD LocalPlayerEntity CheckCurrentTile 1 1")
        self.log(f"  result: {r}")
        if r in ("CLASS_NOT_FOUND", "METHOD_NOT_FOUND"):
            r = c._send("INVOKE_METHOD Entity CheckCurrentTile 1 1")
            self.log(f"  fallback Entity.CheckCurrentTile: {r}")

        self.log(f"[FIX 5/{steps}] UpdateFloor()")
        r = c._send("INVOKE_METHOD Entity UpdateFloor 0")
        self.log(f"  result: {r}")

        self.log(f"[FIX 6/{steps}] CheckDFG()")
        r = c._send("INVOKE_METHOD Entity CheckDFG 0")
        self.log(f"  result: {r}")

        time.sleep(0.1)
        self.read_state()
        new_issues = self.diagnose()
        if not new_issues:
            self.log("[SUCCESS] All mismatches resolved!")
        else:
            self.log(f"[PARTIAL] {len(new_issues)} issue(s) remain after smart fix:")
            for iss in new_issues:
                self.log(f"  - {iss}")
        return len(new_issues) == 0

    def manual_override(self, target_floor):
        c = self.conn
        steps = 7
        self.log(f"[OVERRIDE] Forcing player to floor {target_floor}")

        self.log(f"[OVRD 1/{steps}] Writing pos_z = {float(target_floor):.1f}")
        r = c.write_at("player", OFF_POS_Z, "f32", str(float(target_floor)))
        self.log(f"  result: {'OK' if r else 'FAILED'}")

        self.log(f"[OVRD 2/{steps}] Writing _lastMovementFloor = {target_floor}")
        r = c.write_at("player", OFF_LAST_MOVE_FLOOR, "i32", str(target_floor))
        self.log(f"  result: {'OK' if r else 'FAILED'}")

        self.log(f"[OVRD 3/{steps}] Setting tileChanged = true")
        r = c.write_at("player", OFF_TILE_CHANGED, "bool", "1")
        self.log(f"  result: {'OK' if r else 'FAILED'}")

        self.log(f"[OVRD 4/{steps}] Syncing TileEngine.layer -> {target_floor}")
        r = c._send(f"INVOKE_METHOD TileEngine set_Layer 1 {target_floor}")
        self.log(f"  result: {r}")
        r2 = c._send(f"INVOKE_METHOD TileEngine set_GroundFloor 1 {target_floor}")
        self.log(f"  set_GroundFloor: {r2}")

        self.log(f"[OVRD 5/{steps}] ForceUpdateOnTiles()")
        r = c._send("INVOKE_METHOD Entity ForceUpdateOnTiles 0")
        self.log(f"  result: {r}")

        self.log(f"[OVRD 6/{steps}] CheckCurrentTile(force=true)")
        r = c._send("INVOKE_METHOD LocalPlayerEntity CheckCurrentTile 1 1")
        self.log(f"  result: {r}")

        self.log(f"[OVRD 7/{steps}] UpdateFloor() + CheckDFG()")
        c._send("INVOKE_METHOD Entity UpdateFloor 0")
        c._send("INVOKE_METHOD Entity CheckDFG 0")
        self.log("  done")

        time.sleep(0.1)
        self.read_state()
        new_issues = self.diagnose()
        if not new_issues:
            self.log(f"[SUCCESS] Player now on floor {target_floor}, all synced!")
        else:
            self.log(f"[PARTIAL] {len(new_issues)} issue(s) remain:")
            for iss in new_issues:
                self.log(f"  - {iss}")


# ═══════════════════════════════════════════════════════════════
#  UI
# ═══════════════════════════════════════════════════════════════

class FloorFixUI:
    TAG_COLORS = {
        "FIX": GREEN, "OVRD": CYAN, "OVERRIDE": CYAN,
        "SUCCESS": GREEN, "PARTIAL": ORANGE,
        "ERROR": RED, "WARN": ORANGE,
        "DIAG": YELLOW, "STATE": TEXT_DIM,
        "SYSTEM": ACCENT,
    }

    def __init__(self, conn, stop_event, script_print):
        self.conn = conn
        self.stop_event = stop_event
        self.engine = FloorFixEngine(conn, stop_event, self._log)

        self.win = tk.Toplevel()
        self.win.title("Floor Fix Tool")
        self.win.configure(bg=BG)
        self.win.geometry("720x700")
        self.win.resizable(True, True)
        self.win.wm_attributes("-topmost", True)
        self.win.protocol("WM_DELETE_WINDOW", self._on_close)

        x = (self.win.winfo_screenwidth() - 720) // 2
        y = (self.win.winfo_screenheight() - 700) // 2
        self.win.geometry(f"+{x}+{y}")

        self._build_header()
        self._build_buttons()
        self._build_state_panel()
        self._build_diag_panel()
        self._build_manual_panel()
        self._build_log()

        self._poll_stop()
        self._do_refresh()

    # ── Header ─────────────────────────────────────────────────

    def _build_header(self):
        hdr = tk.Frame(self.win, bg=BG_CARD, height=40)
        hdr.pack(fill=tk.X)
        hdr.pack_propagate(False)
        tk.Label(hdr, text="Floor Fix Tool", font=(FONT_B, 13),
                 bg=BG_CARD, fg=TEXT).pack(side=tk.LEFT, padx=10)
        tk.Label(hdr, text="tile/layer sync + floor drop override",
                 font=(FONT, 9), bg=BG_CARD, fg=TEXT_DIM).pack(side=tk.LEFT, padx=4)
        tk.Frame(self.win, bg=ACCENT, height=2).pack(fill=tk.X)

    # ── Action buttons ─────────────────────────────────────────

    def _build_buttons(self):
        bar = tk.Frame(self.win, bg=BG, padx=10, pady=6)
        bar.pack(fill=tk.X)

        tk.Button(
            bar, text="Refresh", font=(FONT_B, 10),
            bg=BG_CARD, fg=ACCENT, relief=tk.FLAT,
            activebackground=ACCENT, activeforeground=BG,
            padx=14, pady=4, cursor="hand2", command=self._do_refresh,
        ).pack(side=tk.LEFT, padx=(0, 6))

        tk.Button(
            bar, text="Smart Fix", font=(FONT_B, 10),
            bg="#1a3a2a", fg=GREEN, relief=tk.FLAT,
            activebackground=GREEN, activeforeground=BG,
            padx=14, pady=4, cursor="hand2", command=self._do_smart_fix,
        ).pack(side=tk.LEFT, padx=(0, 6))

        tk.Button(
            bar, text="Copy Log", font=(FONT, 9),
            bg=BG_CARD, fg=TEXT_DIM, relief=tk.FLAT,
            padx=10, pady=4, cursor="hand2", command=self._copy_log,
        ).pack(side=tk.LEFT, padx=(0, 6))

        tk.Button(
            bar, text="Clear Log", font=(FONT, 9),
            bg=BG_CARD, fg=TEXT_DIM, relief=tk.FLAT,
            padx=10, pady=4, cursor="hand2", command=self._clear_log,
        ).pack(side=tk.LEFT, padx=(0, 6))

        self.status_lbl = tk.Label(bar, text="--", font=(FONT_M, 9), bg=BG, fg=TEXT_DIM)
        self.status_lbl.pack(side=tk.RIGHT)

    # ── Live state panel ───────────────────────────────────────

    def _build_state_panel(self):
        frame = tk.LabelFrame(
            self.win, text=" LIVE STATE ", font=(FONT_B, 10),
            bg=BG, fg=ACCENT, bd=1, relief=tk.GROOVE,
            highlightbackground=BG_CARD, padx=10, pady=6,
        )
        frame.pack(fill=tk.X, padx=10, pady=(6, 2))

        self.state_labels = {}
        fields = [
            ("pos_z", "Floor (pos_z)"),
            ("dfg", "DFG"),
            ("last_dfg", "Last DFG"),
            ("grounded", "Grounded"),
            ("aerialPosZ", "Aerial Pos Z"),
            ("tileChanged", "Tile Changed"),
            ("last_move_floor", "Last Move Floor"),
            ("te_ground_floor", "TE.GroundFloor"),
            ("te_layer", "TE.Layer"),
            ("te_floors_changed", "TE.FloorsChanged"),
            ("in_world_collider", "In World Collider"),
            ("outer_collider", "Outer Collider"),
        ]

        left = tk.Frame(frame, bg=BG)
        left.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        right = tk.Frame(frame, bg=BG)
        right.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)

        for i, (key, label) in enumerate(fields):
            parent = left if i < 6 else right
            row = tk.Frame(parent, bg=BG)
            row.pack(fill=tk.X, pady=1)
            tk.Label(row, text=f"{label}:", font=(FONT_M, 8), bg=BG, fg=TEXT_DIM,
                     width=18, anchor="e").pack(side=tk.LEFT)
            val_lbl = tk.Label(row, text="--", font=(FONT_M, 9), bg=BG, fg=TEXT, anchor="w")
            val_lbl.pack(side=tk.LEFT, padx=(6, 0))
            self.state_labels[key] = val_lbl

    # ── Diagnostics panel ──────────────────────────────────────

    def _build_diag_panel(self):
        frame = tk.LabelFrame(
            self.win, text=" DIAGNOSTICS ", font=(FONT_B, 10),
            bg=BG, fg=YELLOW, bd=1, relief=tk.GROOVE,
            highlightbackground=BG_CARD, padx=10, pady=4,
        )
        frame.pack(fill=tk.X, padx=10, pady=(2, 2))

        self.diag_box = tk.Text(
            frame, font=(FONT_M, 8), bg="#0d1117", fg=ORANGE,
            relief=tk.FLAT, highlightthickness=0, height=4,
            state=tk.DISABLED, wrap=tk.WORD, padx=6, pady=4,
        )
        self.diag_box.pack(fill=tk.X)

    # ── Manual override panel ──────────────────────────────────

    def _build_manual_panel(self):
        frame = tk.LabelFrame(
            self.win, text=" MANUAL OVERRIDE ", font=(FONT_B, 10),
            bg=BG, fg=CYAN, bd=1, relief=tk.GROOVE,
            highlightbackground=BG_CARD, padx=10, pady=6,
        )
        frame.pack(fill=tk.X, padx=10, pady=(2, 4))

        row = tk.Frame(frame, bg=BG)
        row.pack(fill=tk.X)

        tk.Label(row, text="Target floor:", font=(FONT_M, 9),
                 bg=BG, fg=TEXT_DIM).pack(side=tk.LEFT)

        self.floor_entry = tk.Entry(
            row, font=(FONT_M, 10), bg=BG_INPUT, fg=TEXT,
            insertbackground=TEXT, relief=tk.FLAT, width=6,
            highlightthickness=1, highlightcolor=CYAN,
            highlightbackground=BG_CARD,
        )
        self.floor_entry.pack(side=tk.LEFT, padx=(6, 10))
        self.floor_entry.insert(0, "1")
        self.floor_entry.bind("<Return>", lambda e: self._do_manual())

        tk.Button(
            row, text="Apply Override", font=(FONT_B, 9),
            bg="#1a2a3a", fg=CYAN, relief=tk.FLAT,
            activebackground=CYAN, activeforeground=BG,
            padx=12, pady=3, cursor="hand2", command=self._do_manual,
        ).pack(side=tk.LEFT)

        tk.Label(row, text="(writes pos_z + syncs TileEngine + recalculates)",
                 font=(FONT, 7), bg=BG, fg=TEXT_DIM).pack(side=tk.LEFT, padx=(10, 0))

    # ── Log output ─────────────────────────────────────────────

    def _build_log(self):
        log_frame = tk.Frame(self.win, bg=BG)
        log_frame.pack(fill=tk.BOTH, expand=True, padx=6, pady=(0, 6))

        self.log_box = tk.Text(
            log_frame, font=(FONT_M, 8), bg="#060a10", fg=TEXT_DIM,
            relief=tk.FLAT, highlightthickness=0, padx=8, pady=4,
            state=tk.DISABLED, wrap=tk.NONE,
        )
        y_scroll = tk.Scrollbar(log_frame, orient="vertical", command=self.log_box.yview,
                                bg=BG_CARD, troughcolor=BG, width=10)
        x_scroll = tk.Scrollbar(log_frame, orient="horizontal", command=self.log_box.xview,
                                bg=BG_CARD, troughcolor=BG, width=10)
        self.log_box.configure(yscrollcommand=y_scroll.set, xscrollcommand=x_scroll.set)
        self.log_box.grid(row=0, column=0, sticky="nsew")
        y_scroll.grid(row=0, column=1, sticky="ns")
        x_scroll.grid(row=1, column=0, sticky="ew")
        log_frame.grid_rowconfigure(0, weight=1)
        log_frame.grid_columnconfigure(0, weight=1)

        for tag, color in self.TAG_COLORS.items():
            self.log_box.tag_configure(tag, foreground=color)
        self.log_box.tag_configure("default", foreground=TEXT_DIM)

    # ── Log helper ─────────────────────────────────────────────

    def _log(self, line):
        ts = time.strftime("%H:%M:%S")
        ms = f"{time.time() % 1:.3f}"[1:]
        full = f"[{ts}{ms}] {line}"
        try:
            self.log_box.configure(state=tk.NORMAL)
            tag = "default"
            for t in self.TAG_COLORS:
                if f"[{t}" in line:
                    tag = t
                    break
            self.log_box.insert(tk.END, full + "\n", tag)
            total = int(self.log_box.index("end-1c").split(".")[0])
            if total > 4000:
                self.log_box.delete("1.0", f"{total - 4000}.0")
            self.log_box.see(tk.END)
            self.log_box.configure(state=tk.DISABLED)
        except tk.TclError:
            pass

    # ── Actions ────────────────────────────────────────────────

    def _do_refresh(self):
        self._log("[SYSTEM] Reading floor state...")
        snap = self.engine.read_state()
        if not snap:
            self._log("[ERROR] Cannot read player data — is DLL connected / player loaded?")
            self.status_lbl.configure(text="NO DATA", fg=RED)
            return

        for key, lbl in self.state_labels.items():
            val = snap.get(key)
            display = _fmt(val)
            color = TEXT

            pos_z = snap.get("pos_z")
            player_floor = int(pos_z) if isinstance(pos_z, (int, float)) else None

            if key in ("te_layer", "te_ground_floor"):
                if val is not None and player_floor is not None and int(val) != player_floor:
                    display += f"  << MISMATCH (player={player_floor})"
                    color = RED
            elif key == "tileChanged" and val is False:
                color = ORANGE
            elif key == "dfg" and isinstance(val, (int, float)) and val == 0.0:
                color = ORANGE
            elif key == "grounded" and val is True:
                color = GREEN

            lbl.configure(text=display, fg=color)

        issues = self.engine.diagnose()
        self.diag_box.configure(state=tk.NORMAL)
        self.diag_box.delete("1.0", tk.END)
        if issues:
            for iss in issues:
                self.diag_box.insert(tk.END, f"  [!] {iss}\n")
            self.status_lbl.configure(text=f"{len(issues)} issue(s)", fg=ORANGE)
        else:
            self.diag_box.insert(tk.END, "  No mismatches detected.\n")
            self.status_lbl.configure(text="OK", fg=GREEN)
        self.diag_box.configure(state=tk.DISABLED)

        self._log(f"[STATE] pos_z={_fmt(snap.get('pos_z'))} dfg={_fmt(snap.get('dfg'))} "
                  f"grounded={snap.get('grounded')} tileChg={snap.get('tileChanged')} "
                  f"lastMF={snap.get('last_move_floor')} "
                  f"TE.layer={snap.get('te_layer')} TE.GF={snap.get('te_ground_floor')}")

    def _do_smart_fix(self):
        self._log("[SYSTEM] === SMART FIX START ===")
        self.engine.read_state()
        issues_before = self.engine.diagnose()
        if not issues_before:
            self._log("[SYSTEM] No issues detected — nothing to fix")
            self._do_refresh()
            return

        self._log(f"[DIAG] {len(issues_before)} issue(s) detected:")
        for iss in issues_before:
            self._log(f"[DIAG]   {iss}")

        self.engine.smart_fix()
        self._log("[SYSTEM] === SMART FIX END ===")
        self._do_refresh()

    def _do_manual(self):
        raw = self.floor_entry.get().strip()
        try:
            target = int(raw)
        except ValueError:
            try:
                target = int(float(raw))
            except ValueError:
                self._log(f"[ERROR] Invalid floor number: '{raw}'")
                return

        self._log(f"[SYSTEM] === MANUAL OVERRIDE -> floor {target} ===")
        self.engine.manual_override(target)
        self._log(f"[SYSTEM] === MANUAL OVERRIDE END ===")
        self._do_refresh()

    def _copy_log(self):
        content = self.log_box.get("1.0", tk.END)
        if content.strip():
            self.win.clipboard_clear()
            self.win.clipboard_append(content)
            self.win.update()

    def _clear_log(self):
        self.log_box.configure(state=tk.NORMAL)
        self.log_box.delete("1.0", tk.END)
        self.log_box.configure(state=tk.DISABLED)

    def _poll_stop(self):
        if not self.win.winfo_exists():
            return
        if self.stop_event.is_set():
            try:
                self.win.destroy()
            except tk.TclError:
                pass
            return
        self.win.after(500, self._poll_stop)

    def _on_close(self):
        try:
            self.win.destroy()
        except tk.TclError:
            pass


# ═══════════════════════════════════════════════════════════════
#  Entry
# ═══════════════════════════════════════════════════════════════

print("  Opening Floor Fix Tool...")
ui = FloorFixUI(conn, stop_event, print)
