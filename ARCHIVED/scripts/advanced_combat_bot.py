"""
Advanced Combat Bot — Full State Machine
=========================================
Features:
  • Priority targeting  : Boss → Elite → Rare → Normal (closest per tier)
  • DoT maintenance     : Never let periodic effects fall off
  • Burst phase         : Holds major CDs for aligned burst windows
  • Emergency survival  : Kite + defensives + heals below EMERGENCY_HP
  • Auto-loot           : Detect & spam LOOT_ALL on new corpse windows
  • Anti-AFK            : Random micro-jitter every ~2 min out of combat
  • Interrupt detection : Interrupt target when animation state = casting
  • Enhanced rotation   : do_rotation_pro() — DoT + burst + AoE + priority
  • Full Tkinter UI     : State display, cooldown grid, buff status, live stats
"""

import time
import threading
import math
import random
import tkinter as tk
from tkinter import ttk

try:
    conn
    stop_event
except NameError:
    print("ERROR: Run from EthyTool dashboard.")
    raise SystemExit(1)

# ── palette ──────────────────────────────────────────────────
BG       = "#0a0e14"
BG_CARD  = "#12161e"
BG_PANEL = "#0e1219"
TEXT     = "#e6edf3"
TEXT_DIM = "#6e7681"
ACCENT   = "#58a6ff"
GREEN    = "#3fb950"
RED      = "#f85149"
ORANGE   = "#d29922"
YELLOW   = "#e3b341"
PURPLE   = "#bc8cff"
CYAN     = "#79c0ff"
BORDER   = "#21262d"
FONT     = "Segoe UI"
FONT_B   = "Segoe UI Semibold"
FONT_M   = "Cascadia Code"

LOOT_SPAM_COUNT   = 8
LOOT_SPAM_DELAY   = 0.05
ANTI_AFK_INTERVAL = 120   # seconds between anti-AFK jitters

DEBUG = False


def _dbg(msg):
    if DEBUG:
        print(f"[BOT] {msg}")


# ══════════════════════════════════════════════════════════════
#  Bot State
# ══════════════════════════════════════════════════════════════

class BotState:
    IDLE       = "IDLE"
    BUFFING    = "BUFFING"
    SCANNING   = "SCANNING"
    PULLING    = "PULLING"
    FIGHTING   = "FIGHTING"
    LOOTING    = "LOOTING"
    RECOVERING = "RECOVERING"
    DEAD       = "DEAD"

    COLORS = {
        IDLE:       TEXT_DIM,
        BUFFING:    CYAN,
        SCANNING:   ACCENT,
        PULLING:    YELLOW,
        FIGHTING:   RED,
        LOOTING:    "#FFD700",
        RECOVERING: GREEN,
        DEAD:       RED,
    }

    @classmethod
    def color(cls, state):
        return cls.COLORS.get(state, TEXT_DIM)


# ══════════════════════════════════════════════════════════════
#  AdvancedCombatBot
# ══════════════════════════════════════════════════════════════

class AdvancedCombatBot:

    def __init__(self, conn, stop_event, log_fn):
        self.conn       = conn
        self.stop_event = stop_event
        self.log        = log_fn
        self.running    = False
        self._thread    = None
        self._profile   = None
        self._bt        = None
        self._state     = BotState.IDLE

        # Stats
        self.kills         = 0
        self.looted        = 0
        self.casts         = 0
        self.deaths        = 0
        self.session_start = time.time()
        self._was_in_combat   = False
        self._last_loot_base  = 0
        self._last_anti_afk   = time.time()
        self._last_buff_tick  = 0
        self._pull_at         = 0.0

        # Feature toggles (written by UI)
        self.auto_loot      = True
        self.anti_afk       = True
        self.burst_mode     = True
        self.dot_tracking   = True
        self.smart_target   = True
        self.interrupt_mode = True

    # ── lifecycle ────────────────────────────────────────────────

    def start(self):
        if self.running:
            return
        self.running = True
        self.session_start = time.time()
        self.kills = self.looted = self.casts = self.deaths = 0
        self._was_in_combat = False
        self._state = BotState.BUFFING
        self._thread = threading.Thread(target=self._run, daemon=True)
        self._thread.start()

    def stop(self):
        self.running = False
        self._state  = BotState.IDLE

    @property
    def state(self):
        return self._state

    # ── helpers ──────────────────────────────────────────────────

    def _load(self):
        if self._profile is None:
            self._profile = self.conn.load_profile()
        return self._profile

    def _bt_(self):
        if self._bt is None:
            try:
                self._bt = self.conn.get_buff_tracker()
            except Exception:
                self._bt = None
        return self._bt

    def _tick(self):
        return getattr(self._profile, "TICK_RATE", 0.3) if self._profile else 0.3

    # ── main loop ────────────────────────────────────────────────

    def _run(self):
        p   = self._load()
        cls = self.conn.detect_class()
        self.log(f"  ⚔ Advanced Combat Bot — {cls}")
        if p:
            rot   = getattr(p, "ROTATION",         [])
            buffs = getattr(p, "BUFFS",             [])
            defs  = getattr(p, "DEFENSIVE_SPELLS",  [])
            dots  = getattr(p, "DOT_SPELLS",        {})
            self.log(f"  Rotation : {', '.join(rot[:5])}{'…' if len(rot)>5 else ''}")
            self.log(f"  Buffs    : {', '.join(buffs)}")
            self.log(f"  Defensives: {', '.join(defs)}")
            if dots:
                self.log(f"  DoTs     : {', '.join(dots.keys())}")
        self._state = BotState.BUFFING
        self.conn.do_buff()
        self._snapshot_loot_baseline()
        self._state = BotState.SCANNING
        tick = self._tick()

        while not self.stop_event.is_set() and self.running:
            try:
                self._cycle(p, tick)
            except Exception as exc:
                _dbg(f"Cycle error: {exc}")
                self.log(f"  [ERR] {exc}")
            time.sleep(tick)

        self.running = False
        self._state  = BotState.IDLE
        self._print_final_stats()

    # ── cycle ────────────────────────────────────────────────────

    def _cycle(self, p, tick):
        if not self.conn.is_alive():
            if self._state != BotState.DEAD:
                self.deaths += 1
                self._state  = BotState.DEAD
                self.log(f"  💀 Died — waiting for respawn…")
            self._wait_for_alive()
            self._state = BotState.RECOVERING
            self.conn.do_buff()
            self._state = BotState.SCANNING
            return

        in_combat = self.conn.in_combat()

        # Anti-AFK jitter out of combat
        if self.anti_afk and not in_combat:
            self._maybe_anti_afk()

        # Loot detection every tick
        if self.auto_loot:
            self._try_loot()

        if in_combat:
            self._handle_combat(p)
        else:
            self._handle_ooc(p)

    # ── combat ───────────────────────────────────────────────────

    def _handle_combat(self, p):
        if not self._was_in_combat:
            self._was_in_combat = True
            self._pull_at = time.time()
            self._state   = BotState.PULLING
            self.log(f"  ⚔ Combat!")
            self.conn.do_buff()
            self.conn.do_pull()

        self._state = BotState.FIGHTING
        c  = self.conn
        hp = c.get_hp()

        emergency_hp = getattr(p, "EMERGENCY_HP", 20) if p else 20
        def_trigger  = getattr(p, "DEFENSIVE_TRIGGER_HP", 25) if p else 25
        def_hp       = getattr(p, "DEFENSIVE_HP", 40) if p else 40

        # Emergency: kite + defensives + emergency heals
        if hp < emergency_hp:
            _dbg(f"Emergency HP {hp:.0f}% — kiting")
            c.do_defend()
            c.do_kite()
            for h in getattr(p, "HEAL_SPELLS", []) if p else []:
                if c.try_cast_emergency(h):
                    break
            return

        # Interrupt target if casting
        if self.interrupt_mode and p and getattr(p, "INTERRUPT_SPELL", None):
            try:
                if c.is_target_casting():
                    if c.interrupt_target():
                        _dbg("Interrupted target cast")
                        return
            except Exception:
                pass

        # Soft defensive on low HP
        if hp < def_trigger or hp < def_hp:
            c.do_defend()

        # Periodic buff refresh (every ~1.5 s)
        self._last_buff_tick += 1
        if self._last_buff_tick >= 5:
            self._last_buff_tick = 0
            c.do_buff()

        # No target — scan for one
        if not c.has_target() or c.is_target_dead():
            self._find_next_target()
            return

        # Full enhanced rotation
        cast_fn = getattr(c, "do_rotation_pro", None) or (lambda: c.do_rotation())
        if cast_fn():
            self.casts += 1
            return

        # Fallback: any ready class spell
        for s in c.get_class_spells():
            if c.try_cast(s):
                self.casts += 1
                break

    # ── out-of-combat ─────────────────────────────────────────────

    def _handle_ooc(self, p):
        if self._was_in_combat:
            self._was_in_combat = False
            self.kills += 1
            dur = time.time() - self._pull_at
            self.log(f"  ✓ Kill #{self.kills}  ({dur:.1f}s)")
            self._state = BotState.LOOTING
            time.sleep(0.4)

        if self._state in (BotState.LOOTING, BotState.FIGHTING):
            self._state = BotState.RECOVERING

        if self._state == BotState.RECOVERING:
            hp = self.conn.get_hp()
            mp = self.conn.get_mp()
            rest_hp = getattr(p, "REST_HP", 70) if p else 70
            rest_mp = getattr(p, "REST_MP", 60) if p else 60
            if hp < rest_hp or mp < rest_mp:
                self.conn.do_recover(hp_target=rest_hp, mp_target=rest_mp, timeout=30)
            self._state = BotState.SCANNING

        if self._state == BotState.SCANNING:
            # Buff up then look for target
            self.conn.do_buff()
            self._find_next_target()

    # ── targeting ────────────────────────────────────────────────

    def _find_next_target(self):
        if not self.conn.has_target() or self.conn.is_target_dead():
            try:
                if self.smart_target and hasattr(self.conn, "smart_target_nearest"):
                    result = self.conn.smart_target_nearest()
                else:
                    result = self.conn.target_nearest()
                if result:
                    name = result.get("name", "?") if isinstance(result, dict) else "?"
                    tier = ""
                    if isinstance(result, dict):
                        if result.get("boss"):  tier = " [BOSS]"
                        elif result.get("elite"): tier = " [ELITE]"
                        elif result.get("rare"):  tier = " [RARE]"
                    _dbg(f"Targeted: {name}{tier}")
            except Exception as e:
                _dbg(f"Target error: {e}")

    # ── loot ─────────────────────────────────────────────────────

    def _try_loot(self):
        try:
            windows = self.conn.get_loot_window_count()
            if windows > self._last_loot_base:
                new_count = windows - self._last_loot_base
                ok_count  = 0
                for _ in range(LOOT_SPAM_COUNT):
                    if self.stop_event.is_set():
                        break
                    n, _ = self.conn.loot_all()
                    if n > 0:
                        ok_count += 1
                    time.sleep(LOOT_SPAM_DELAY)
                if ok_count > 0:
                    self.looted += new_count
                    self.log(f"  💰 Looted {new_count} window(s)")
                self._last_loot_base = self.conn.get_loot_window_count()
            elif windows < self._last_loot_base:
                self._last_loot_base = windows
        except Exception:
            pass

    def _snapshot_loot_baseline(self):
        try:
            self._last_loot_base = self.conn.get_loot_window_count()
        except Exception:
            self._last_loot_base = 0

    # ── anti-AFK ─────────────────────────────────────────────────

    def _maybe_anti_afk(self):
        now = time.time()
        if now - self._last_anti_afk < ANTI_AFK_INTERVAL:
            return
        self._last_anti_afk = now
        try:
            px, py, _ = self.conn.get_position()
            angle  = random.uniform(0, 2 * math.pi)
            jitter = random.uniform(0.5, 2.0)
            nx = px + math.cos(angle) * jitter
            ny = py + math.sin(angle) * jitter
            self.conn.move_to(nx, ny)
            time.sleep(random.uniform(0.3, 0.8))
            self.conn.stop_moving()
            _dbg(f"Anti-AFK jitter {jitter:.1f}u @ {angle:.1f}rad")
        except Exception:
            pass

    # ── wait helpers ─────────────────────────────────────────────

    def _wait_for_alive(self, timeout=120):
        start = time.time()
        while time.time() - start < timeout:
            if self.stop_event.is_set() or not self.running:
                return
            if self.conn.is_alive():
                return
            time.sleep(1.0)

    # ── stats ────────────────────────────────────────────────────

    def get_stats(self) -> dict:
        elapsed = time.time() - self.session_start
        kph = self.kills / max(elapsed / 3600, 1e-6)
        cpm = self.casts / max(elapsed / 60, 1e-6)
        return {
            "state": self._state,
            "kills": self.kills,
            "looted": self.looted,
            "casts": self.casts,
            "deaths": self.deaths,
            "elapsed": elapsed,
            "kph": kph,
            "cpm": cpm,
        }

    def _print_final_stats(self):
        s    = self.get_stats()
        mins = s["elapsed"] / 60
        self.log(f"  ═══ Session Complete ═══")
        self.log(f"  Time   : {mins:.1f} min")
        self.log(f"  Kills  : {s['kills']}  ({s['kph']:.0f}/hr)")
        self.log(f"  Looted : {s['looted']}")
        self.log(f"  Casts  : {s['casts']}  ({s['cpm']:.1f}/min)")
        self.log(f"  Deaths : {s['deaths']}")


# ══════════════════════════════════════════════════════════════
#  Cooldown Panel widget
# ══════════════════════════════════════════════════════════════

class CooldownPanel(tk.Frame):
    """Grid of spell cooldown indicators — green when ready, orange/red when on CD."""

    def __init__(self, parent, conn, **kw):
        super().__init__(parent, bg=BG_PANEL, **kw)
        self.conn    = conn
        self._labels = {}   # spell_name -> (name_lbl, cd_lbl, frame)
        self._cols   = 3
        self._built  = False

    def build(self, spell_list):
        for w in self.winfo_children():
            w.destroy()
        self._labels.clear()
        for i, name in enumerate(spell_list):
            row, col = divmod(i, self._cols)
            cell = tk.Frame(self, bg=BG_CARD, padx=6, pady=4, relief=tk.FLAT)
            cell.grid(row=row, column=col, padx=3, pady=3, sticky="ew")
            short = name[:14] + ("…" if len(name) > 14 else "")
            name_lbl = tk.Label(cell, text=short, font=(FONT_M, 7),
                                bg=BG_CARD, fg=CYAN, anchor="w")
            name_lbl.pack(fill=tk.X)
            cd_lbl = tk.Label(cell, text="READY", font=(FONT_B, 8),
                              bg=BG_CARD, fg=GREEN, anchor="w")
            cd_lbl.pack(fill=tk.X)
            self._labels[name] = (name_lbl, cd_lbl, cell)
        for c in range(self._cols):
            self.columnconfigure(c, weight=1)
        self._built = True

    def refresh(self, spell_list):
        if not self._built or set(spell_list) != set(self._labels):
            self.build(spell_list)
            return
        try:
            game_spells = {s.get("name", ""): s for s in self.conn.get_spells()}
        except Exception:
            return
        for name, (_, cd_lbl, cell) in self._labels.items():
            s = game_spells.get(name, {})
            cd_raw = s.get("cd", s.get("cooldown", 0))
            try:
                cd = float(cd_raw) if cd_raw else 0.0
            except (ValueError, TypeError):
                cd = 0.0
            if cd <= 0:
                cd_lbl.configure(text="READY", fg=GREEN)
                cell.configure(bg=BG_CARD)
            elif cd < 3:
                cd_lbl.configure(text=f"{cd:.1f}s", fg=ORANGE)
                cell.configure(bg="#1a160a")
            else:
                cd_lbl.configure(text=f"{cd:.0f}s", fg=RED)
                cell.configure(bg="#1a0a0a")


# ══════════════════════════════════════════════════════════════
#  Buff Status Bar widget
# ══════════════════════════════════════════════════════════════

class BuffStatusPanel(tk.Frame):
    """Shows active player buffs with elapsed time."""

    def __init__(self, parent, conn, **kw):
        super().__init__(parent, bg=BG_PANEL, **kw)
        self.conn   = conn
        self._rows  = {}  # name -> (name_lbl, timer_lbl)
        self._max   = 8

    def refresh(self):
        try:
            buffs = self.conn.get_player_buffs()
        except Exception:
            return
        names = [b.get("name", "") for b in buffs if b.get("name")][:self._max]
        # Remove rows no longer active
        for n in list(self._rows):
            if n not in names:
                row_frame = self._rows[n][2]
                try:
                    row_frame.destroy()
                except Exception:
                    pass
                del self._rows[n]
        # Add / update rows
        for i, b in enumerate(buffs[:self._max]):
            name = b.get("name", "")
            if not name:
                continue
            stacks = int(b.get("stacks", b.get("stack", 1)) or 1)
            label  = name + (f"  ×{stacks}" if stacks > 1 else "")
            if name not in self._rows:
                row = tk.Frame(self, bg=BG_CARD, padx=6, pady=2)
                row.pack(fill=tk.X, pady=1)
                n_lbl = tk.Label(row, text=label[:28], font=(FONT_M, 7),
                                 bg=BG_CARD, fg=GREEN, anchor="w")
                n_lbl.pack(side=tk.LEFT, fill=tk.X, expand=True)
                t_lbl = tk.Label(row, text="", font=(FONT_M, 7),
                                 bg=BG_CARD, fg=TEXT_DIM, width=6, anchor="e")
                t_lbl.pack(side=tk.RIGHT)
                self._rows[name] = (n_lbl, t_lbl, row)
            else:
                self._rows[name][0].configure(text=label[:28])


# ══════════════════════════════════════════════════════════════
#  HP / MP bar
# ══════════════════════════════════════════════════════════════

class ResourceBar(tk.Frame):

    def __init__(self, parent, label, color, **kw):
        super().__init__(parent, bg=BG_PANEL, **kw)
        tk.Label(self, text=label, font=(FONT_B, 8), bg=BG_PANEL, fg=TEXT_DIM,
                 width=3).pack(side=tk.LEFT, padx=(0, 4))
        self._canvas = tk.Canvas(self, height=14, bg=BG_CARD,
                                 highlightthickness=0)
        self._canvas.pack(side=tk.LEFT, fill=tk.X, expand=True)
        self._pct_lbl = tk.Label(self, text="100%", font=(FONT_M, 8),
                                 bg=BG_PANEL, fg=TEXT_DIM, width=5)
        self._pct_lbl.pack(side=tk.RIGHT, padx=(4, 0))
        self._color = color
        self._bar   = None

    def set(self, pct: float):
        pct = max(0.0, min(100.0, pct))
        w = self._canvas.winfo_width()
        if w < 4:
            w = 200
        bar_w = int(w * pct / 100)
        if self._bar is None:
            self._bar = self._canvas.create_rectangle(
                0, 0, bar_w, 14, fill=self._color, outline="")
        else:
            self._canvas.coords(self._bar, 0, 0, bar_w, 14)
        self._pct_lbl.configure(text=f"{pct:.0f}%")


# ══════════════════════════════════════════════════════════════
#  Main UI
# ══════════════════════════════════════════════════════════════

class AdvancedBotUI:

    def __init__(self, conn, stop_event, script_print):
        self.conn         = conn
        self.stop_event   = stop_event
        self.script_print = script_print
        self.bot          = AdvancedCombatBot(conn, stop_event, self._log)

        self.win = tk.Toplevel()
        self.win.title("Advanced Combat Bot")
        self.win.configure(bg=BG)
        self.win.geometry("540x780")
        self.win.resizable(False, True)
        self.win.wm_attributes("-topmost", True)
        self.win.protocol("WM_DELETE_WINDOW", self._on_close)
        cx = (self.win.winfo_screenwidth()  - 540) // 2
        cy = (self.win.winfo_screenheight() - 780) // 2
        self.win.geometry(f"+{cx}+{cy}")

        self._build_ui()
        self._update_loop()
        self._poll_stop()

    # ── UI builder ───────────────────────────────────────────────

    def _build_ui(self):
        cls = self.conn.detect_class()

        # ── header ──
        hdr = tk.Frame(self.win, bg=BG_CARD, height=46)
        hdr.pack(fill=tk.X)
        hdr.pack_propagate(False)
        tk.Label(hdr, text="⚔", font=("Segoe UI Emoji", 18),
                 bg=BG_CARD, fg=RED).pack(side=tk.LEFT, padx=(12, 6))
        tk.Label(hdr, text="Advanced Combat Bot", font=(FONT_B, 14),
                 bg=BG_CARD, fg=TEXT).pack(side=tk.LEFT)
        self._state_lbl = tk.Label(hdr, text="IDLE", font=(FONT_B, 10),
                                   bg=BG_CARD, fg=TEXT_DIM, padx=10)
        self._state_lbl.pack(side=tk.RIGHT, padx=8)
        tk.Frame(self.win, bg=ACCENT, height=2).pack(fill=tk.X)

        tk.Label(self.win, text=f"  {cls}", font=(FONT_M, 9),
                 bg=BG, fg=TEXT_DIM).pack(anchor=tk.W, padx=14, pady=(6, 0))

        # ── HP / MP bars ──
        res_frame = tk.Frame(self.win, bg=BG, padx=14)
        res_frame.pack(fill=tk.X, pady=(4, 0))
        self._hp_bar = ResourceBar(res_frame, "HP", "#c0392b")
        self._hp_bar.pack(fill=tk.X, pady=2)
        self._mp_bar = ResourceBar(res_frame, "MP", "#2980b9")
        self._mp_bar.pack(fill=tk.X, pady=2)

        # ── control buttons ──
        btn_frame = tk.Frame(self.win, bg=BG, padx=14, pady=8)
        btn_frame.pack(fill=tk.X)
        self._start_btn = tk.Button(
            btn_frame, text="▶  Start Bot", font=(FONT_B, 12),
            bg="#1a3a2a", fg=GREEN, relief=tk.FLAT,
            activebackground=GREEN, activeforeground=BG,
            padx=28, pady=10, cursor="hand2",
            command=self._toggle_bot,
        )
        self._start_btn.pack(side=tk.LEFT, padx=(0, 8))

        self._status_lbl = tk.Label(btn_frame, text="", font=(FONT_M, 9),
                                    bg=BG, fg=TEXT_DIM)
        self._status_lbl.pack(side=tk.LEFT)

        # ── toggles ──
        opt = tk.Frame(self.win, bg=BG, padx=14)
        opt.pack(fill=tk.X, pady=(0, 4))
        self._vars = {}
        toggles = [
            ("auto_loot",      "💰 Auto-loot",       "#FFD700"),
            ("anti_afk",       "🕹 Anti-AFK jitter",  CYAN),
            ("burst_mode",     "💥 Burst Phase",      ORANGE),
            ("dot_tracking",   "☠ DoT Tracking",     PURPLE),
            ("smart_target",   "🎯 Smart Targeting",  ACCENT),
            ("interrupt_mode", "⚡ Auto-Interrupt",   RED),
        ]
        for col, (attr, label, fg) in enumerate(toggles):
            var = tk.BooleanVar(value=getattr(self.bot, attr))
            self._vars[attr] = var
            cb = tk.Checkbutton(
                opt, text=label, variable=var,
                font=(FONT_B, 8), bg=BG, fg=fg,
                selectcolor=BG_CARD, activebackground=BG,
                activeforeground=fg, highlightthickness=0, bd=0,
                command=lambda a=attr, v=var: setattr(self.bot, a, v.get()),
            )
            cb.grid(row=col // 3, column=col % 3, sticky="w", padx=4, pady=1)

        # ── debug toggle ──
        self._debug_var = tk.BooleanVar(value=False)
        tk.Checkbutton(
            opt, text="🐛 Debug", variable=self._debug_var,
            font=(FONT_B, 8), bg=BG, fg=TEXT_DIM,
            selectcolor=BG_CARD, activebackground=BG,
            activeforeground=TEXT_DIM, highlightthickness=0, bd=0,
            command=self._toggle_debug,
        ).grid(row=2, column=0, sticky="w", padx=4, pady=1)

        sep = tk.Frame(self.win, bg=BORDER, height=1)
        sep.pack(fill=tk.X, padx=10, pady=4)

        # ── stats bar ──
        self._stats_lbl = tk.Label(
            self.win,
            text="Kills: 0  KPH: 0  Casts: 0  Looted: 0  Deaths: 0",
            font=(FONT_M, 8), bg=BG, fg=TEXT_DIM,
        )
        self._stats_lbl.pack(fill=tk.X, padx=14, pady=(0, 4))

        # ── active buffs ──
        buf_hdr = tk.Frame(self.win, bg=BG, padx=14)
        buf_hdr.pack(fill=tk.X)
        tk.Label(buf_hdr, text="Active Buffs", font=(FONT_B, 9),
                 bg=BG, fg=CYAN).pack(side=tk.LEFT)

        self._buff_panel = BuffStatusPanel(self.win, self.conn)
        self._buff_panel.pack(fill=tk.X, padx=14, pady=(2, 4))

        sep2 = tk.Frame(self.win, bg=BORDER, height=1)
        sep2.pack(fill=tk.X, padx=10, pady=2)

        # ── cooldown grid ──
        tk.Label(self.win, text="Spell Cooldowns", font=(FONT_B, 9),
                 bg=BG, fg=ORANGE).pack(anchor=tk.W, padx=14, pady=(2, 0))

        self._cd_panel = CooldownPanel(self.win, self.conn)
        self._cd_panel.pack(fill=tk.X, padx=14, pady=(2, 4))

        sep3 = tk.Frame(self.win, bg=BORDER, height=1)
        sep3.pack(fill=tk.X, padx=10, pady=2)

        # ── log ──
        log_frame = tk.Frame(self.win, bg=BG_CARD)
        log_frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=(0, 8))
        self.log_box = tk.Text(
            log_frame, font=(FONT_M, 8), bg="#060a10", fg=TEXT_DIM,
            height=8, relief=tk.FLAT, highlightthickness=0,
            padx=8, pady=6, state=tk.DISABLED, wrap=tk.WORD,
        )
        self.log_box.pack(fill=tk.BOTH, expand=True, padx=4, pady=(0, 6))

        self._spell_list = []

    # ── button callbacks ─────────────────────────────────────────

    def _toggle_bot(self):
        if self.bot.running:
            self.bot.stop()
            self._start_btn.configure(text="▶  Start Bot", bg="#1a3a2a", fg=GREEN)
            self._log("  ■ Bot stopped")
        else:
            self.bot.start()
            self._start_btn.configure(text="■  Stop Bot", bg="#3a1a1a", fg=RED)
            self._log("  ▶ Bot started")

    def _toggle_debug(self):
        global DEBUG
        DEBUG = self._debug_var.get()

    # ── update loop ──────────────────────────────────────────────

    def _update_loop(self):
        if not self.win.winfo_exists():
            return
        try:
            self._update_bars()
            self._update_stats()
            self._update_state()
            self._update_buffs()
            self._update_cds()
        except Exception:
            pass
        self.win.after(500, self._update_loop)

    def _update_bars(self):
        try:
            self._hp_bar.set(self.conn.get_hp())
            self._mp_bar.set(self.conn.get_mp())
        except Exception:
            pass

    def _update_stats(self):
        s = self.bot.get_stats()
        self._stats_lbl.configure(
            text=(f"Kills: {s['kills']}  KPH: {s['kph']:.0f}  "
                  f"Casts: {s['casts']}  Looted: {s['looted']}  Deaths: {s['deaths']}")
        )

    def _update_state(self):
        state = self.bot.state
        self._state_lbl.configure(text=state, fg=BotState.color(state))
        if self.bot.running:
            combat_str = " [COMBAT]" if self.conn.in_combat() else ""
            self._status_lbl.configure(
                text=f"{state}{combat_str}",
                fg=RED if self.conn.in_combat() else GREEN,
            )
        else:
            self._status_lbl.configure(text="Stopped", fg=TEXT_DIM)

    def _update_buffs(self):
        self._buff_panel.refresh()

    def _update_cds(self):
        try:
            if not self._spell_list:
                p = self.conn.load_profile()
                if p:
                    all_spells = (
                        getattr(p, "ROTATION", []) +
                        getattr(p, "BUFFS", []) +
                        getattr(p, "DEFENSIVE_SPELLS", [])
                    )
                    seen = set()
                    self._spell_list = [
                        s for s in all_spells
                        if s not in seen and not seen.add(s)
                    ]
            if self._spell_list:
                self._cd_panel.refresh(self._spell_list)
        except Exception:
            pass

    # ── log ──────────────────────────────────────────────────────

    def _log(self, msg):
        self.script_print(msg)
        try:
            self.log_box.configure(state=tk.NORMAL)
            ts = time.strftime("%H:%M:%S")
            self.log_box.insert(tk.END, f"[{ts}] {msg}\n")
            lines = int(self.log_box.index("end-1c").split(".")[0])
            if lines > 200:
                self.log_box.delete("1.0", f"{lines - 200}.0")
            self.log_box.see(tk.END)
            self.log_box.configure(state=tk.DISABLED)
        except tk.TclError:
            pass

    # ── lifecycle ────────────────────────────────────────────────

    def _poll_stop(self):
        if not self.win.winfo_exists():
            return
        if self.stop_event.is_set():
            self.bot.stop()
            return
        self.win.after(500, self._poll_stop)

    def _on_close(self):
        self.bot.stop()
        try:
            self.win.destroy()
        except tk.TclError:
            pass


# ══════════════════════════════════════════════════════════════
#  Entry point
# ══════════════════════════════════════════════════════════════

def _open_ui():
    global ui
    ui = AdvancedBotUI(conn, stop_event, print)


_root = getattr(tk, "_default_root", None)
if _root and _root.winfo_exists():
    _root.after(0, _open_ui)
    print("  Opening Advanced Combat Bot UI…")
else:
    print("  Opening Advanced Combat Bot UI…")
    ui = AdvancedBotUI(conn, stop_event, print)
