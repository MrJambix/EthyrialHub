"""
Rotation Pro — Advanced Rotation Tracker & Buff Monitor
=========================================================
Real-time overlay showing everything you need for optimal play:

  • HP / MP bars with live %
  • GCD spinner — countdown bar for global cooldown
  • Active buffs with countdown timers + colored urgency bars
  • Spell cooldown grid — all spells, color coded by readiness
  • Fury / stack meter (for stack-based classes)
  • Rotation phase indicator: OOC / OPENING / MAINTAIN / BURST / RECOVER
  • DoT status panel — shows DoT timers from profile's DOT_SPELLS
  • Party HP mini-panel
  • Next suggested spell
  • DPS / Heal toggle with live rotation engine
  • Live session stats
"""

import time
import threading
import tkinter as tk
from tkinter import ttk

try:
    conn
    stop_event
except NameError:
    print("ERROR: Run from EthyTool dashboard.")
    raise SystemExit(1)

# ── palette ──────────────────────────────────────────────────
BG       = "#080c12"
BG_CARD  = "#0f1319"
BG_PANEL = "#0b0f16"
TEXT     = "#e6edf3"
TEXT_DIM = "#5a6370"
ACCENT   = "#58a6ff"
GREEN    = "#3fb950"
RED      = "#f85149"
ORANGE   = "#d29922"
YELLOW   = "#e3b341"
PURPLE   = "#bc8cff"
CYAN     = "#79c0ff"
TEAL     = "#39d353"
BORDER   = "#1c2128"
FONT     = "Segoe UI"
FONT_B   = "Segoe UI Semibold"
FONT_M   = "Cascadia Code"

GCD_DEFAULT = 0.5

LOOT_SPAM_COUNT = 8
LOOT_SPAM_DELAY = 0.05

DEBUG = False


# ══════════════════════════════════════════════════════════════
#  Rotation phase labels
# ══════════════════════════════════════════════════════════════

class Phase:
    OOC      = "OUT OF COMBAT"
    OPENING  = "OPENER"
    MAINTAIN = "MAINTAIN"
    BURST    = "BURST"
    RECOVER  = "RECOVER"
    DEAD     = "DEAD"

    COLORS = {
        OOC:      TEXT_DIM,
        OPENING:  YELLOW,
        MAINTAIN: GREEN,
        BURST:    ORANGE,
        RECOVER:  CYAN,
        DEAD:     RED,
    }


# ══════════════════════════════════════════════════════════════
#  RotationProEngine (background thread)
# ══════════════════════════════════════════════════════════════

class RotationProEngine:
    MODE_DPS  = "dps"
    MODE_HEAL = "heal"
    MODE_OFF  = "off"

    def __init__(self, conn, stop_event, log_fn):
        self.conn       = conn
        self.stop_event = stop_event
        self.log        = log_fn
        self.running    = False
        self._thread    = None
        self.mode       = self.MODE_OFF
        self._profile   = None
        self._bt        = None

        # Public state (read by UI)
        self.phase        = Phase.OOC
        self.last_cast    = ""
        self.next_spell   = ""
        self.kills        = 0
        self.heals        = 0
        self.casts        = 0
        self.looted       = 0
        self._loot_base   = 0
        self._in_combat   = False
        self._pull_count  = 0

    # ── lifecycle ────────────────────────────────────────────────

    def start(self, mode):
        if self.running and self.mode == mode:
            return
        self.stop()
        self.mode    = mode
        self.running = True
        self._thread = threading.Thread(target=self._run, daemon=True)
        self._thread.start()

    def stop(self):
        self.running = False
        self.mode    = self.MODE_OFF
        self.phase   = Phase.OOC

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

    # ── main run loop ─────────────────────────────────────────────

    def _run(self):
        p   = self._load()
        cls = self.conn.detect_class()
        tick = getattr(p, "TICK_RATE", 0.3) if p else 0.3

        self.log(f"  Rotation Pro [{self.mode.upper()}] — {cls}")
        self.conn.do_buff()
        self._snapshot_loot()

        while not self.stop_event.is_set() and self.running and self.conn.is_alive():
            try:
                self._try_loot()
                if self.mode == self.MODE_HEAL:
                    self._tick_heal(p, tick)
                else:
                    self._tick_dps(p, tick)
            except Exception as exc:
                if DEBUG:
                    self.log(f"  [ERR] {exc}")
            time.sleep(tick)

        self.running = False
        self.phase   = Phase.OOC

    # ── DPS tick ──────────────────────────────────────────────────

    def _tick_dps(self, p, tick):
        in_combat = self.conn.in_combat()
        hp        = self.conn.get_hp()

        if not in_combat:
            if self._in_combat:
                self._in_combat = False
                self.kills += 1
                self.log(f"  ✓ Kill #{self.kills}")
                if hp < (getattr(p, "REST_HP", 70) if p else 70):
                    self.phase = Phase.RECOVER
                    self.conn.do_recover(hp_target=90, mp_target=80, timeout=30)
            self.phase = Phase.OOC
            self.conn.do_buff()
            return

        if not self._in_combat:
            self._in_combat = True
            self._pull_count += 1
            self.phase = Phase.OPENING
            self.log(f"  ⚔ Combat! (pull #{self._pull_count})")
            self.conn.do_buff()
            self.conn.do_pull()

        # Determine phase
        p_obj = self._profile
        if p_obj:
            burst = getattr(p_obj, "BURST_PHASE", {})
            trigger = burst.get("cd_trigger") if burst else None
            if burst and burst.get("enabled") and trigger and self.conn.is_spell_ready(trigger):
                self.phase = Phase.BURST
            elif hp < (getattr(p_obj, "DEFENSIVE_HP", 40)):
                self.phase = Phase.RECOVER
            else:
                self.phase = Phase.MAINTAIN

        # Low mana meditation
        if self.conn.do_meditation_if_low_mana():
            return

        # Defensives on low HP
        def_hp = getattr(p, "DEFENSIVE_TRIGGER_HP", 25) if p else 25
        if hp < def_hp:
            self.conn.do_defend()

        # Ensure target
        if not self.conn.has_target():
            self.conn.target_nearest()
            return

        # Full pro rotation
        cast_fn = getattr(self.conn, "do_rotation_pro", None)
        if cast_fn is None:
            cast_fn = self.conn.do_rotation

        if cast_fn():
            self.casts += 1
            # Peek at what was last cast from state
            cc = self.conn.state.cast_counts
            if cc:
                self.last_cast = max(cc, key=cc.get)
            return

        # Fallback: any class spell
        for s in self.conn.get_class_spells():
            if self.conn.try_cast(s):
                self.casts += 1
                self.last_cast = s
                break

    # ── Heal tick ─────────────────────────────────────────────────

    def _tick_heal(self, p, tick):
        in_combat = self.conn.in_combat()

        if not in_combat:
            self.phase    = Phase.OOC
            self._in_combat = False
            hp, mp = self.conn.get_hp(), self.conn.get_mp()
            if hp < 90 or mp < 80:
                self.conn.do_recover(hp_target=90, mp_target=80, timeout=20)
            self.conn.do_buff()
            return

        if not self._in_combat:
            self._in_combat = True
            self.phase = Phase.OPENING

        if self.conn.do_meditation_if_low_mana():
            return

        emergency_hp = getattr(p, "EMERGENCY_HP", 25) if p else 25
        def_hp       = getattr(p, "DEFENSIVE_HP",  40) if p else 40
        heal_hp      = getattr(p, "HEAL_HP",        70) if p else 70

        critical = self.conn.get_party_below(emergency_hp)
        if critical:
            self.phase = Phase.BURST
            self.conn.do_shield_party()
            self.conn.do_heal_party()
            self.heals += 1
            return

        self.phase = Phase.MAINTAIN

        if self.conn.get_party_below(def_hp):
            self.conn.do_shield_party()

        if self.conn.get_party_below(heal_hp):
            self.conn.do_heal_party()
            self.heals += 1
            return

        if self.conn.get_hp() < heal_hp:
            self.conn.do_heal_target()
            self.heals += 1
            return

        self.conn.do_buff()
        if self.conn.do_dps_weave():
            self.casts += 1

    # ── loot ──────────────────────────────────────────────────────

    def _try_loot(self):
        try:
            w = self.conn.get_loot_window_count()
            if w > self._loot_base:
                ok = 0
                for _ in range(LOOT_SPAM_COUNT):
                    if self.stop_event.is_set():
                        break
                    n, _ = self.conn.loot_all()
                    if n > 0:
                        ok += 1
                    time.sleep(LOOT_SPAM_DELAY)
                if ok > 0:
                    self.looted += w - self._loot_base
                self._loot_base = self.conn.get_loot_window_count()
            elif w < self._loot_base:
                self._loot_base = w
        except Exception:
            pass

    def _snapshot_loot(self):
        try:
            self._loot_base = self.conn.get_loot_window_count()
        except Exception:
            self._loot_base = 0


# ══════════════════════════════════════════════════════════════
#  Widget helpers
# ══════════════════════════════════════════════════════════════

class BarWidget(tk.Frame):
    """Horizontal colored fill bar with a text label on the right."""

    def __init__(self, parent, label, fill_color, height=12, **kw):
        super().__init__(parent, bg=BG_PANEL, **kw)
        tk.Label(self, text=label, font=(FONT_B, 8), bg=BG_PANEL,
                 fg=TEXT_DIM, width=4, anchor="e").pack(side=tk.LEFT, padx=(0, 4))
        self._cv = tk.Canvas(self, height=height, bg=BG_CARD,
                             highlightthickness=0)
        self._cv.pack(side=tk.LEFT, fill=tk.X, expand=True)
        self._txt = tk.Label(self, text="100%", font=(FONT_M, 8),
                             bg=BG_PANEL, fg=TEXT_DIM, width=6, anchor="e")
        self._txt.pack(side=tk.RIGHT, padx=(4, 0))
        self._color = fill_color
        self._rect  = None
        self._h     = height

    def set(self, pct: float, text: str = None):
        pct = max(0.0, min(100.0, float(pct)))
        w   = max(4, self._cv.winfo_width())
        bw  = int(w * pct / 100)
        if self._rect is None:
            self._rect = self._cv.create_rectangle(
                0, 0, bw, self._h, fill=self._color, outline="")
        else:
            self._cv.coords(self._rect, 0, 0, bw, self._h)
        self._txt.configure(text=text if text is not None else f"{pct:.0f}%")


class GCDBar(tk.Frame):
    """GCD countdown bar — flashes from full to empty then snaps back."""

    def __init__(self, parent, **kw):
        super().__init__(parent, bg=BG_PANEL, **kw)
        tk.Label(self, text="GCD", font=(FONT_B, 8), bg=BG_PANEL,
                 fg=TEXT_DIM, width=4, anchor="e").pack(side=tk.LEFT, padx=(0, 4))
        self._cv = tk.Canvas(self, height=8, bg=BG_CARD, highlightthickness=0)
        self._cv.pack(side=tk.LEFT, fill=tk.X, expand=True)
        self._rect = None
        self._last_gcd = 0.0
        self._gcd_dur  = GCD_DEFAULT

    def trigger(self, duration: float = GCD_DEFAULT):
        self._last_gcd = time.time()
        self._gcd_dur  = max(duration, 0.1)

    def refresh(self):
        elapsed = time.time() - self._last_gcd
        pct     = max(0.0, 1.0 - elapsed / self._gcd_dur) * 100
        w = max(4, self._cv.winfo_width())
        bw = int(w * pct / 100)
        color = ACCENT if pct > 30 else (ORANGE if pct > 10 else GREEN)
        if self._rect is None:
            self._rect = self._cv.create_rectangle(0, 0, bw, 8, fill=color, outline="")
        else:
            self._cv.coords(self._rect, 0, 0, bw, 8)
            self._cv.itemconfigure(self._rect, fill=color)


# ══════════════════════════════════════════════════════════════
#  Buff Row Panel
# ══════════════════════════════════════════════════════════════

class BuffRow(tk.Frame):
    """Single buff entry: name, countdown bar, seconds remaining."""

    def __init__(self, parent, name: str, **kw):
        super().__init__(parent, bg=BG_CARD, padx=6, pady=2, **kw)
        short = name[:20] + ("…" if len(name) > 20 else "")
        self._name_lbl = tk.Label(self, text=short, font=(FONT_M, 7),
                                  bg=BG_CARD, fg=GREEN, anchor="w", width=20)
        self._name_lbl.pack(side=tk.LEFT)
        self._cv = tk.Canvas(self, height=6, bg=BG_PANEL, highlightthickness=0)
        self._cv.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=4)
        self._timer_lbl = tk.Label(self, text="", font=(FONT_M, 7),
                                   bg=BG_CARD, fg=TEXT_DIM, width=5, anchor="e")
        self._timer_lbl.pack(side=tk.RIGHT)
        self._stacks_lbl = tk.Label(self, text="", font=(FONT_B, 7),
                                    bg=BG_CARD, fg=PURPLE, width=3, anchor="e")
        self._stacks_lbl.pack(side=tk.RIGHT)
        self._bar = None
        self._name = name

    def update_buff(self, stacks: int, elapsed: float, known_dur: float = 0.0):
        self._stacks_lbl.configure(text=f"×{stacks}" if stacks > 1 else "")
        if known_dur > 0:
            remaining = max(0.0, known_dur - elapsed)
            pct = (remaining / known_dur) * 100
            if remaining < 3:
                color = RED
            elif remaining < known_dur * 0.33:
                color = ORANGE
            else:
                color = GREEN
            self._timer_lbl.configure(text=f"{remaining:.1f}s", fg=color)
        else:
            self._timer_lbl.configure(text="∞", fg=TEXT_DIM)
            pct = 100.0
        w = max(4, self._cv.winfo_width())
        bw = int(w * pct / 100)
        bar_color = RED if pct < 20 else (ORANGE if pct < 50 else GREEN)
        if self._bar is None:
            self._bar = self._cv.create_rectangle(0, 0, bw, 6, fill=bar_color, outline="")
        else:
            self._cv.coords(self._bar, 0, 0, bw, 6)
            self._cv.itemconfigure(self._bar, fill=bar_color)


class BuffPanel(tk.Frame):
    """Scrollable list of active player buffs with countdown bars."""

    def __init__(self, parent, conn, **kw):
        super().__init__(parent, bg=BG_PANEL, **kw)
        self.conn  = conn
        self._rows = {}   # name -> BuffRow
        self._max  = 10

    def refresh(self, spell_info: dict = None):
        spell_info = spell_info or {}
        try:
            buffs = self.conn.get_player_buffs()
        except Exception:
            return
        live  = {}
        for b in buffs[:self._max]:
            name = b.get("name", "")
            if not name:
                continue
            stacks = int(b.get("stacks", b.get("stack", 1)) or 1)
            live[name] = stacks

        # Remove stale rows
        for n in list(self._rows):
            if n not in live:
                try:
                    self._rows[n].destroy()
                except Exception:
                    pass
                del self._rows[n]

        # Add / update
        for name, stacks in live.items():
            info    = spell_info.get(name, {})
            dur     = float(info.get("duration", 0))
            tracker = None
            if hasattr(self.conn, "get_buff_tracker"):
                try:
                    tracker = self.conn.get_buff_tracker()
                except Exception:
                    pass
            elapsed = 0.0
            if tracker:
                cache = tracker._buff_cache.get(name, {})
                elapsed = time.time() - cache.get("applied_at", time.time())

            if name not in self._rows:
                row = BuffRow(self, name)
                row.pack(fill=tk.X, pady=1)
                self._rows[name] = row
            self._rows[name].update_buff(stacks, elapsed, dur)


# ══════════════════════════════════════════════════════════════
#  DoT Panel
# ══════════════════════════════════════════════════════════════

class DotPanel(tk.Frame):
    """Shows DoT timers for all DOT_SPELLS in the active profile."""

    def __init__(self, parent, conn, **kw):
        super().__init__(parent, bg=BG_PANEL, **kw)
        self.conn  = conn
        self._rows = {}   # name -> (name_lbl, bar_cv, bar_rect, time_lbl)

    def refresh(self, dot_spells: dict):
        if not dot_spells:
            return
        tracker = None
        if hasattr(self.conn, "get_buff_tracker"):
            try:
                tracker = self.conn.get_buff_tracker()
            except Exception:
                pass

        for name, duration in dot_spells.items():
            remaining = 0.0
            if tracker:
                remaining = tracker.dot_remaining(name, duration)
            pct = (remaining / max(duration, 0.01)) * 100

            if name not in self._rows:
                row = tk.Frame(self, bg=BG_CARD, padx=6, pady=2)
                row.pack(fill=tk.X, pady=1)
                short = name[:18] + ("…" if len(name) > 18 else "")
                n_lbl = tk.Label(row, text=short, font=(FONT_M, 7),
                                 bg=BG_CARD, fg=PURPLE, anchor="w", width=18)
                n_lbl.pack(side=tk.LEFT)
                cv = tk.Canvas(row, height=6, bg=BG_PANEL, highlightthickness=0)
                cv.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=4)
                t_lbl = tk.Label(row, text="", font=(FONT_M, 7),
                                 bg=BG_CARD, fg=TEXT_DIM, width=5, anchor="e")
                t_lbl.pack(side=tk.RIGHT)
                rect = cv.create_rectangle(0, 0, 0, 6, fill=PURPLE, outline="")
                self._rows[name] = (n_lbl, cv, rect, t_lbl)

            _, cv, rect, t_lbl = self._rows[name]
            w  = max(4, cv.winfo_width())
            bw = int(w * pct / 100)
            cv.coords(rect, 0, 0, bw, 6)
            color = RED if pct < 15 else (ORANGE if pct < 40 else PURPLE)
            cv.itemconfigure(rect, fill=color)
            t_lbl.configure(text=f"{remaining:.1f}s",
                            fg=RED if remaining < 2 else TEXT_DIM)


# ══════════════════════════════════════════════════════════════
#  Cooldown Grid
# ══════════════════════════════════════════════════════════════

class CooldownGrid(tk.Frame):
    """3-column grid of spell icons with CD timers — green=ready, orange/red=on CD."""

    def __init__(self, parent, conn, cols: int = 4, **kw):
        super().__init__(parent, bg=BG_PANEL, **kw)
        self.conn   = conn
        self._cols  = cols
        self._cells = {}   # name -> (cell_frame, cd_lbl)
        self._spells= []

    def build(self, spells: list):
        for w in self.winfo_children():
            w.destroy()
        self._cells.clear()
        self._spells = spells
        for i, name in enumerate(spells):
            row, col = divmod(i, self._cols)
            cell = tk.Frame(self, bg=BG_CARD, padx=5, pady=4)
            cell.grid(row=row, column=col, padx=2, pady=2, sticky="nsew")
            short = name[:13] + ("…" if len(name) > 13 else "")
            tk.Label(cell, text=short, font=(FONT_M, 6), bg=BG_CARD,
                     fg=CYAN, anchor="w").pack(fill=tk.X)
            cd_lbl = tk.Label(cell, text="READY", font=(FONT_B, 8),
                              bg=BG_CARD, fg=GREEN)
            cd_lbl.pack(fill=tk.X)
            self._cells[name] = (cell, cd_lbl)
        for c in range(self._cols):
            self.columnconfigure(c, weight=1)

    def refresh(self, spells: list):
        if not spells:
            return
        if spells != self._spells:
            self.build(spells)
        try:
            game_spells = {s.get("name", ""): s for s in self.conn.get_spells()}
        except Exception:
            return
        for name, (cell, cd_lbl) in self._cells.items():
            s   = game_spells.get(name, {})
            raw = s.get("cd", s.get("cooldown", 0))
            try:
                cd = float(raw) if raw else 0.0
            except (ValueError, TypeError):
                cd = 0.0
            if cd <= 0:
                cd_lbl.configure(text="READY", fg=GREEN)
                cell.configure(bg=BG_CARD)
            elif cd < 3:
                cd_lbl.configure(text=f"{cd:.1f}s", fg=ORANGE)
                cell.configure(bg="#181308")
            else:
                cd_lbl.configure(text=f"{cd:.0f}s", fg=RED)
                cell.configure(bg="#180808")


# ══════════════════════════════════════════════════════════════
#  Party HP Panel
# ══════════════════════════════════════════════════════════════

class PartyPanel(tk.Frame):
    """Shows HP for each party member as a colored bar."""

    def __init__(self, parent, conn, **kw):
        super().__init__(parent, bg=BG_PANEL, **kw)
        self.conn  = conn
        self._rows = {}   # name -> (bar_cv, bar_rect, hp_lbl)

    def refresh(self):
        try:
            party = self.conn.get_party()
        except Exception:
            return
        if not party:
            return
        live = {m.get("name", f"#{i}"): m for i, m in enumerate(party)}
        for n in list(self._rows):
            if n not in live:
                self._rows[n][0].master.destroy()
                del self._rows[n]
        for name, m in live.items():
            hp     = float(m.get("hp", 100))
            is_self= m.get("is_self", False)
            dead   = m.get("dead", False)
            color  = RED if dead else ("#2ecc71" if hp > 60 else (ORANGE if hp > 30 else RED))
            if name not in self._rows:
                row = tk.Frame(self, bg=BG_CARD, padx=6, pady=2)
                row.pack(fill=tk.X, pady=1)
                tag = " (you)" if is_self else ""
                short = name[:14] + ("…" if len(name) > 14 else "")
                tk.Label(row, text=short + tag, font=(FONT_M, 7), bg=BG_CARD,
                         fg=ACCENT, anchor="w", width=16).pack(side=tk.LEFT)
                cv = tk.Canvas(row, height=8, bg=BG_PANEL, highlightthickness=0)
                cv.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=4)
                hp_lbl = tk.Label(row, text="", font=(FONT_M, 7), bg=BG_CARD,
                                  fg=TEXT_DIM, width=5, anchor="e")
                hp_lbl.pack(side=tk.RIGHT)
                rect = cv.create_rectangle(0, 0, 0, 8, fill=color, outline="")
                self._rows[name] = (cv, rect, hp_lbl)
            cv, rect, hp_lbl = self._rows[name]
            w  = max(4, cv.winfo_width())
            bw = int(w * hp / 100)
            cv.coords(rect, 0, 0, bw, 8)
            cv.itemconfigure(rect, fill=color)
            hp_lbl.configure(text="DEAD" if dead else f"{hp:.0f}%",
                             fg=RED if dead else TEXT_DIM)


# ══════════════════════════════════════════════════════════════
#  Stack Meter
# ══════════════════════════════════════════════════════════════

class StackMeter(tk.Frame):

    def __init__(self, parent, conn, **kw):
        super().__init__(parent, bg=BG_PANEL, **kw)
        tk.Label(self, text="Stacks", font=(FONT_B, 8), bg=BG_PANEL,
                 fg=ORANGE, width=7, anchor="e").pack(side=tk.LEFT, padx=(0, 4))
        self._cv = tk.Canvas(self, height=14, bg=BG_CARD, highlightthickness=0)
        self._cv.pack(side=tk.LEFT, fill=tk.X, expand=True)
        self._count_lbl = tk.Label(self, text="0 / 0", font=(FONT_B, 9),
                                   bg=BG_PANEL, fg=ORANGE, width=7, anchor="e")
        self._count_lbl.pack(side=tk.RIGHT, padx=(4, 0))
        self._bar = None

    def set(self, stacks: int, max_stacks: int = 20):
        pct = min(100, int(stacks / max(max_stacks, 1) * 100))
        w   = max(4, self._cv.winfo_width())
        bw  = int(w * pct / 100)
        color = RED if pct >= 100 else (ORANGE if pct >= 60 else YELLOW)
        if self._bar is None:
            self._bar = self._cv.create_rectangle(0, 0, bw, 14, fill=color, outline="")
        else:
            self._cv.coords(self._bar, 0, 0, bw, 14)
            self._cv.itemconfigure(self._bar, fill=color)
        self._count_lbl.configure(text=f"{stacks} / {max_stacks}")


# ══════════════════════════════════════════════════════════════
#  Rotation Pro UI
# ══════════════════════════════════════════════════════════════

class RotationProUI:

    def __init__(self, conn, stop_event, script_print):
        self.conn         = conn
        self.stop_event   = stop_event
        self.script_print = script_print
        self.engine       = RotationProEngine(conn, stop_event, self._log)

        self._profile     = None
        self._spell_list  = []
        self._dot_spells  = {}
        self._spell_info  = {}
        self._max_stacks  = 20
        self._stack_enabled = False
        self._session_start = time.time()

        self.win = tk.Toplevel()
        self.win.title("Rotation Pro")
        self.win.configure(bg=BG)
        self.win.geometry("580x900")
        self.win.resizable(False, True)
        self.win.wm_attributes("-topmost", True)
        self.win.protocol("WM_DELETE_WINDOW", self._on_close)
        cx = (self.win.winfo_screenwidth()  - 580) // 2
        cy = (self.win.winfo_screenheight() - 900) // 2
        self.win.geometry(f"+{cx}+{cy}")

        self._load_profile()
        self._build_ui()
        self._update_loop()
        self._poll_stop()

    # ── profile ──────────────────────────────────────────────────

    def _load_profile(self):
        try:
            p = self.conn.load_profile()
            self._profile     = p
            self._spell_info  = getattr(p, "SPELL_INFO",  {}) if p else {}
            self._dot_spells  = getattr(p, "DOT_SPELLS",  {}) if p else {}
            self._max_stacks  = getattr(p, "MAX_STACKS",  20) if p else 20
            self._stack_enabled = getattr(p, "STACK_ENABLED", False) if p else False
            if p:
                seen = set()
                all_sp = (
                    getattr(p, "ROTATION",          []) +
                    getattr(p, "BUFFS",             []) +
                    getattr(p, "DEFENSIVE_SPELLS",  []) +
                    getattr(p, "HEAL_SPELLS",       []) +
                    list(getattr(p, "DOT_SPELLS",   {}).keys())
                )
                self._spell_list = [s for s in all_sp
                                    if s not in seen and not seen.add(s)]
        except Exception:
            pass

    # ── UI builder ───────────────────────────────────────────────

    def _build_ui(self):
        cls = self.conn.detect_class()

        # ── header ──
        hdr = tk.Frame(self.win, bg=BG_CARD, height=46)
        hdr.pack(fill=tk.X)
        hdr.pack_propagate(False)
        tk.Label(hdr, text="⚡", font=("Segoe UI Emoji", 18),
                 bg=BG_CARD, fg=ACCENT).pack(side=tk.LEFT, padx=(12, 6))
        tk.Label(hdr, text="Rotation Pro", font=(FONT_B, 14),
                 bg=BG_CARD, fg=TEXT).pack(side=tk.LEFT)
        self._phase_lbl = tk.Label(hdr, text=Phase.OOC, font=(FONT_B, 9),
                                   bg=BG_CARD, fg=TEXT_DIM, padx=10)
        self._phase_lbl.pack(side=tk.RIGHT, padx=6)
        tk.Frame(self.win, bg=ACCENT, height=2).pack(fill=tk.X)

        tk.Label(self.win, text=f"  {cls}", font=(FONT_M, 9),
                 bg=BG, fg=TEXT_DIM).pack(anchor=tk.W, padx=14, pady=(6, 0))

        # ── HP / MP / GCD bars ──
        bars = tk.Frame(self.win, bg=BG, padx=14)
        bars.pack(fill=tk.X, pady=(4, 2))
        self._hp_bar = BarWidget(bars, "HP", "#c0392b")
        self._hp_bar.pack(fill=tk.X, pady=2)
        self._mp_bar = BarWidget(bars, "MP", "#2980b9")
        self._mp_bar.pack(fill=tk.X, pady=2)
        self._gcd_bar = GCDBar(bars)
        self._gcd_bar.pack(fill=tk.X, pady=2)

        # ── Stack meter (only shown for stack classes) ──
        self._stack_frame = tk.Frame(self.win, bg=BG, padx=14)
        self._stack_meter = StackMeter(self._stack_frame, self.conn)
        self._stack_meter.pack(fill=tk.X, pady=2)
        if self._stack_enabled:
            self._stack_frame.pack(fill=tk.X, pady=0)

        # ── DPS / Heals buttons ──
        btn_frame = tk.Frame(self.win, bg=BG, padx=14, pady=8)
        btn_frame.pack(fill=tk.X)
        self._dps_btn = tk.Button(
            btn_frame, text="▶  DPS On", font=(FONT_B, 11),
            bg="#1a3a2a", fg=GREEN, relief=tk.FLAT,
            activebackground=GREEN, activeforeground=BG,
            padx=20, pady=8, cursor="hand2",
            command=lambda: self._toggle("dps"),
        )
        self._dps_btn.pack(side=tk.LEFT, padx=(0, 6))
        self._heal_btn = tk.Button(
            btn_frame, text="▶  Heals On", font=(FONT_B, 11),
            bg="#1a3a2a", fg=GREEN, relief=tk.FLAT,
            activebackground=GREEN, activeforeground=BG,
            padx=20, pady=8, cursor="hand2",
            command=lambda: self._toggle("heal"),
        )
        self._heal_btn.pack(side=tk.LEFT)

        self._loot_var = tk.BooleanVar(value=True)
        tk.Checkbutton(
            btn_frame, text="💰 Loot",
            variable=self._loot_var, font=(FONT_B, 8),
            bg=BG, fg=YELLOW, selectcolor=BG_CARD,
            activebackground=BG, activeforeground=YELLOW,
            highlightthickness=0, bd=0,
        ).pack(side=tk.RIGHT, padx=4)

        # ── Next spell + last cast ──
        cast_frame = tk.Frame(self.win, bg=BG_CARD, padx=12, pady=6)
        cast_frame.pack(fill=tk.X, padx=10, pady=4)
        tk.Label(cast_frame, text="Last:", font=(FONT_B, 8),
                 bg=BG_CARD, fg=TEXT_DIM).grid(row=0, column=0, sticky="w")
        self._last_cast_lbl = tk.Label(cast_frame, text="—", font=(FONT_M, 9),
                                       bg=BG_CARD, fg=CYAN)
        self._last_cast_lbl.grid(row=0, column=1, sticky="w", padx=6)
        tk.Label(cast_frame, text="Suggest:", font=(FONT_B, 8),
                 bg=BG_CARD, fg=TEXT_DIM).grid(row=1, column=0, sticky="w")
        self._next_spell_lbl = tk.Label(cast_frame, text="—", font=(FONT_M, 9),
                                        bg=BG_CARD, fg=YELLOW)
        self._next_spell_lbl.grid(row=1, column=1, sticky="w", padx=6)

        sep = tk.Frame(self.win, bg=BORDER, height=1)
        sep.pack(fill=tk.X, padx=10, pady=2)

        # ── Active Buffs ──
        tk.Label(self.win, text="Active Buffs", font=(FONT_B, 9),
                 bg=BG, fg=GREEN).pack(anchor=tk.W, padx=14, pady=(2, 0))
        self._buff_panel = BuffPanel(self.win, self.conn)
        self._buff_panel.pack(fill=tk.X, padx=14, pady=(2, 4))

        # ── DoT Tracker (only if profile has DOT_SPELLS) ──
        if self._dot_spells:
            tk.Label(self.win, text="DoT Timers", font=(FONT_B, 9),
                     bg=BG, fg=PURPLE).pack(anchor=tk.W, padx=14, pady=(2, 0))
            self._dot_panel = DotPanel(self.win, self.conn)
            self._dot_panel.pack(fill=tk.X, padx=14, pady=(2, 4))
        else:
            self._dot_panel = None

        sep2 = tk.Frame(self.win, bg=BORDER, height=1)
        sep2.pack(fill=tk.X, padx=10, pady=2)

        # ── Cooldown grid ──
        tk.Label(self.win, text="Cooldowns", font=(FONT_B, 9),
                 bg=BG, fg=ORANGE).pack(anchor=tk.W, padx=14, pady=(2, 0))
        self._cd_grid = CooldownGrid(self.win, self.conn, cols=4)
        self._cd_grid.pack(fill=tk.X, padx=14, pady=(2, 4))
        if self._spell_list:
            self._cd_grid.build(self._spell_list)

        sep3 = tk.Frame(self.win, bg=BORDER, height=1)
        sep3.pack(fill=tk.X, padx=10, pady=2)

        # ── Party HP ──
        tk.Label(self.win, text="Party", font=(FONT_B, 9),
                 bg=BG, fg=ACCENT).pack(anchor=tk.W, padx=14, pady=(2, 0))
        self._party_panel = PartyPanel(self.win, self.conn)
        self._party_panel.pack(fill=tk.X, padx=14, pady=(2, 4))

        sep4 = tk.Frame(self.win, bg=BORDER, height=1)
        sep4.pack(fill=tk.X, padx=10, pady=2)

        # ── Stats ──
        self._stats_lbl = tk.Label(
            self.win,
            text="Kills: 0  Casts: 0  Heals: 0  Looted: 0",
            font=(FONT_M, 8), bg=BG, fg=TEXT_DIM,
        )
        self._stats_lbl.pack(fill=tk.X, padx=14, pady=(2, 4))

        # ── Log ──
        log_frame = tk.Frame(self.win, bg=BG_CARD)
        log_frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=(0, 8))
        self.log_box = tk.Text(
            log_frame, font=(FONT_M, 7), bg="#060a10", fg=TEXT_DIM,
            height=6, relief=tk.FLAT, highlightthickness=0,
            padx=8, pady=6, state=tk.DISABLED, wrap=tk.WORD,
        )
        self.log_box.pack(fill=tk.BOTH, expand=True, padx=4, pady=(0, 4))

    # ── controls ─────────────────────────────────────────────────

    def _toggle(self, mode):
        if self.engine.running and self.engine.mode == mode:
            self.engine.stop()
            self._log(f"  {mode.upper()} off")
        else:
            self.engine.start(mode)
            self._log(f"  {mode.upper()} on")
        self._update_buttons()

    def _update_buttons(self):
        m = self.engine.mode
        if m == "dps":
            self._dps_btn.configure(text="■  DPS Off", bg="#3a1a1a", fg=RED)
            self._heal_btn.configure(text="▶  Heals On", bg="#1a3a2a", fg=GREEN)
        elif m == "heal":
            self._dps_btn.configure(text="▶  DPS On", bg="#1a3a2a", fg=GREEN)
            self._heal_btn.configure(text="■  Heals Off", bg="#3a1a1a", fg=RED)
        else:
            self._dps_btn.configure(text="▶  DPS On", bg="#1a3a2a", fg=GREEN)
            self._heal_btn.configure(text="▶  Heals On", bg="#1a3a2a", fg=GREEN)

    # ── update loop ──────────────────────────────────────────────

    def _update_loop(self):
        if not self.win.winfo_exists():
            return
        try:
            self._update_bars()
            self._update_phase()
            self._update_stacks()
            self._update_casts()
            self._update_buffs()
            self._update_dots()
            self._update_cds()
            self._update_party()
            self._update_stats()
            self._gcd_bar.refresh()
        except Exception:
            pass
        self.win.after(250, self._update_loop)

    def _update_bars(self):
        try:
            self._hp_bar.set(self.conn.get_hp())
            self._mp_bar.set(self.conn.get_mp())
        except Exception:
            pass

    def _update_phase(self):
        phase = self.engine.phase
        self._phase_lbl.configure(
            text=phase,
            fg=Phase.COLORS.get(phase, TEXT_DIM),
        )

    def _update_stacks(self):
        if not self._stack_enabled:
            return
        try:
            stacks = self.conn.get_fury_stacks()
            self._stack_meter.set(stacks, self._max_stacks)
        except Exception:
            pass

    def _update_casts(self):
        self._last_cast_lbl.configure(text=self.engine.last_cast or "—")
        # Suggest next ready spell from rotation
        try:
            p = self._profile
            if p:
                for name in getattr(p, "ROTATION", []):
                    if self.conn.is_spell_ready(name):
                        self._next_spell_lbl.configure(text=name)
                        return
        except Exception:
            pass
        self._next_spell_lbl.configure(text="—")

    def _update_buffs(self):
        self._buff_panel.refresh(self._spell_info)

    def _update_dots(self):
        if self._dot_panel and self._dot_spells:
            self._dot_panel.refresh(self._dot_spells)

    def _update_cds(self):
        if self._spell_list:
            self._cd_grid.refresh(self._spell_list)

    def _update_party(self):
        try:
            if self.conn.in_party():
                self._party_panel.refresh()
        except Exception:
            pass

    def _update_stats(self):
        e = self.engine
        self._stats_lbl.configure(
            text=f"Kills: {e.kills}  Casts: {e.casts}  Heals: {e.heals}  Looted: {e.looted}"
        )

    # ── log ──────────────────────────────────────────────────────

    def _log(self, msg):
        self.script_print(msg)
        try:
            self.log_box.configure(state=tk.NORMAL)
            ts = time.strftime("%H:%M:%S")
            self.log_box.insert(tk.END, f"[{ts}] {msg}\n")
            lines = int(self.log_box.index("end-1c").split(".")[0])
            if lines > 150:
                self.log_box.delete("1.0", f"{lines - 150}.0")
            self.log_box.see(tk.END)
            self.log_box.configure(state=tk.DISABLED)
        except tk.TclError:
            pass

    # ── lifecycle ────────────────────────────────────────────────

    def _poll_stop(self):
        if not self.win.winfo_exists():
            return
        if self.stop_event.is_set():
            self.engine.stop()
            return
        self.win.after(500, self._poll_stop)

    def _on_close(self):
        self.engine.stop()
        try:
            self.win.destroy()
        except tk.TclError:
            pass


# ══════════════════════════════════════════════════════════════
#  Entry point
# ══════════════════════════════════════════════════════════════

def _open_ui():
    global ui
    ui = RotationProUI(conn, stop_event, print)


_root = getattr(tk, "_default_root", None)
if _root and _root.winfo_exists():
    _root.after(0, _open_ui)
    print("  Opening Rotation Pro UI…")
else:
    print("  Opening Rotation Pro UI…")
    ui = RotationProUI(conn, stop_event, print)
