"""
Auto-Rotation — UI with DPS / Heals toggles.
Click DPS On or Heals On to run that mode. Click again to turn off.

Improvements:
  • Auto-loot when loot window opens (like loot_all.py)
  • Buff refresh during combat
  • DEBUG toggle (verbose console output)
"""
import time
import threading
import tkinter as tk

DEBUG = False  # Toggle in UI for verbose console output

# Auto-loot: spam LOOT_ALL multiple times per new window (from loot_all.py)
LOOT_SPAM_COUNT = 8
LOOT_SPAM_DELAY = 0.05


def _set_debug(on):
    global DEBUG
    DEBUG = bool(on)


try:
    conn
    stop_event
except NameError:
    print("ERROR: Run from EthyTool dashboard.")
    raise SystemExit(1)


BG       = "#0a0e14"
BG_CARD  = "#12161e"
TEXT     = "#e6edf3"
TEXT_DIM = "#6e7681"
ACCENT   = "#58a6ff"
GREEN    = "#3fb950"
RED      = "#f85149"
ORANGE   = "#d29922"
BORDER   = "#21262d"
FONT     = "Segoe UI"
FONT_B   = "Segoe UI Semibold"
FONT_M   = "Cascadia Code"


class RotationEngine:
    MODE_DPS   = "dps"
    MODE_HEAL  = "heal"

    def __init__(self, conn, stop_event, log_fn):
        self.conn = conn
        self.stop_event = stop_event
        self.log = log_fn
        self.running = False
        self._thread = None
        self.mode = None
        self.stats = {"kills": 0, "heals": 0, "casts": 0, "looted": 0}
        self._profile = None
        self._was_in_combat = False
        self._last_party_print = 0
        self.loot_enabled = True
        self._loot_baseline = 0
        self._buff_tick = 0

    def _load_profile(self):
        if self._profile is None:
            self._profile = self.conn.load_profile()
        return self._profile

    def _snapshot_loot_baseline(self):
        try:
            self._loot_baseline = self.conn.get_loot_window_count()
        except Exception:
            self._loot_baseline = 0

    def _try_loot(self):
        """Loot when loot window appears — spam LOOT_ALL (like loot_all.py). Runs every tick."""
        if not self.loot_enabled:
            return
        try:
            windows = self.conn.get_loot_window_count()
            if windows > self._loot_baseline:
                new_count = windows - self._loot_baseline
                ok_count = 0
                for _ in range(LOOT_SPAM_COUNT):
                    if self.stop_event.is_set():
                        break
                    raw = self.conn._send("LOOT_ALL")
                    if raw and raw.startswith("OK"):
                        ok_count += 1
                    time.sleep(LOOT_SPAM_DELAY)
                if ok_count > 0:
                    self.stats["looted"] += new_count
                    self.log(f"  💰 Looted {new_count} window(s)")
                self._loot_baseline = self.conn.get_loot_window_count()
            elif windows < self._loot_baseline:
                self._loot_baseline = windows
        except Exception:
            pass

    def _print_party_hp(self):
        """Print all party members and their HP % when DEBUG is on."""
        if not DEBUG:
            return
        party = self.conn.get_party()
        if not party:
            print("[DEBUG] Party: none / not in party")
            return
        for m in party:
            name = m.get("name", "?")
            hp = m.get("hp", -1)
            in_range = m.get("in_range", False)
            is_self = m.get("is_self", False)
            dead = m.get("dead", False)
            idx = m.get("index", -1)
            tag = " (self)" if is_self else ""
            status = "DEAD" if dead else f"{hp:.0f}%"
            rng = "in_range" if in_range else "out_of_range"
            print(f"[DEBUG] Party member: {name}{tag} idx={idx} hp={status} {rng}")

    def start(self, mode):
        if self.running and self.mode == mode:
            return
        self.stop()
        self.mode = mode
        self.running = True
        self._was_in_combat = False
        self._thread = threading.Thread(target=self._run, daemon=True)
        self._thread.start()

    def stop(self):
        self.running = False
        self.mode = None

    def _run(self):
        p = self._load_profile()
        tick = getattr(p, "TICK_RATE", 0.3) if p else 0.3
        def_trigger = getattr(p, "DEFENSIVE_TRIGGER_HP", 20) if p else 20
        def_hp = getattr(p, "DEFENSIVE_HP", 40) if p else 40
        rest_hp = getattr(p, "REST_HP", 70) if p else 70
        heal_hp = getattr(p, "HEAL_HP", 70) if p else 70
        emergency_hp = getattr(p, "EMERGENCY_HP", 25) if p else 25

        cls = self.conn.detect_class()
        self.log(f"  {self.mode.upper()} mode — {cls}")
        if DEBUG:
            print(f"[DEBUG] Started {self.mode.upper()} mode, class={cls}")

        self.conn.do_buff()
        self._snapshot_loot_baseline()

        _last_print = 0
        while not self.stop_event.is_set() and self.running and self.conn.is_alive():
            try:
                self._try_loot()
                if DEBUG and time.time() - _last_print > 2.0:
                    _last_print = time.time()
                    print(f"[DEBUG] tick mode={self.mode} combat={self.conn.in_combat()} hp={self.conn.get_hp():.0f}% mp={self.conn.get_mp():.0f}%")
                if self.mode == self.MODE_HEAL:
                    self._tick_heal(tick, p, heal_hp, emergency_hp, def_hp)
                else:
                    self._tick_dps(tick, p, def_trigger, def_hp, rest_hp)
            except Exception as e:
                self.log(f"  [ERR] {e}")
                if DEBUG:
                    print(f"[DEBUG] Exception: {e}")
            time.sleep(tick)

        self.running = False
        s = self.stats
        self.log(f"  ■ Stopped — Kills: {s['kills']}   Looted: {s.get('looted', 0)}")

    def _tick_dps(self, tick, p, def_trigger, def_hp, rest_hp):
        in_combat = self.conn.in_combat()
        hp = self.conn.get_hp()

        if in_combat:
            if not self._was_in_combat:
                self.log(f"  ⚔ Combat!")
                if DEBUG:
                    print("[DEBUG] Entering combat")
                self.conn.do_buff()
                self.conn.do_pull()
                self._snapshot_loot_baseline()
                self._was_in_combat = True
                self._buff_tick = 0

            if getattr(self.conn, "do_meditation_if_low_mana", lambda: False)():
                if DEBUG:
                    print("[DEBUG] Meditating (low mana)")
                return

            if not self.conn.has_target():
                if DEBUG:
                    print("[DEBUG] No target, targeting nearest")
                self.conn.target_nearest()

            if hp < def_trigger or hp < def_hp:
                if DEBUG:
                    print(f"[DEBUG] Low HP {hp:.0f}% - defending")
                self.conn.do_defend()

            # Refresh buffs every ~1.5s during combat
            self._buff_tick += 1
            if self._buff_tick >= 5:
                self._buff_tick = 0
                self.conn.do_buff()

            if p:
                if self.conn.do_rotation():
                    self.stats["casts"] += 1
                else:
                    for s in self.conn.get_class_spells():
                        if self.conn.try_cast(s):
                            self.stats["casts"] += 1
                            break
        else:
            if self._was_in_combat:
                self.stats["kills"] += 1
                self.log(f"  ✓ Kill #{self.stats['kills']}")
                self._was_in_combat = False
                if hp < rest_hp:
                    self.log(f"  💊 Resting...")
                    self.conn.do_recover(hp_target=90, mp_target=80, timeout=30)

    def _tick_heal(self, tick, p, heal_hp, emergency_hp, def_hp):
        if not self.conn.in_combat():
            hp, mp = self.conn.get_hp(), self.conn.get_mp()
            if DEBUG and time.time() - self._last_party_print > 2.0:
                self._last_party_print = time.time()
                print(f"[DEBUG] OOC hp={hp:.0f}% mp={mp:.0f}%")
            if hp < 90 or mp < 80:
                if getattr(p, "REST_ENABLED", True):
                    if mp < 80 and p:
                        self.conn.try_cast_ooc(getattr(p, "MEDITATION_SPELL", "Leyline Meditation"))
                    elif hp < 90 and p:
                        self.conn.try_cast_ooc(getattr(p, "REST_SPELL", "Rest"))
            return

        if getattr(self.conn, "do_meditation_if_low_mana", lambda: False)():
            if DEBUG:
                print("[DEBUG] Meditating (low mana)")
            return

        if DEBUG and time.time() - self._last_party_print > 2.0:
            self._last_party_print = time.time()
            self._print_party_hp()

        critical = self.conn.get_party_below(emergency_hp)
        if critical:
            if DEBUG:
                for m in critical:
                    print(f"[DEBUG] CRITICAL: {m.get('name','?')} at {m.get('hp',0):.0f}%")
            self.conn.do_shield_party()
            self.conn.do_heal_party()
            return

        below_def = self.conn.get_party_below(def_hp)
        if below_def:
            if DEBUG:
                for m in below_def:
                    print(f"[DEBUG] Below def ({def_hp}%): {m.get('name','?')} at {m.get('hp',0):.0f}%")
            self.conn.do_shield_party()

        hurt = self.conn.get_party_below(heal_hp)
        if hurt:
            if DEBUG:
                for m in hurt:
                    print(f"[DEBUG] Hurt (below {heal_hp}%): {m.get('name','?')} at {m.get('hp',0):.0f}%")
            self.conn.do_heal_party()
            self.stats["heals"] += 1
            return

        if self.conn.get_hp() < heal_hp:
            if DEBUG:
                print(f"[DEBUG] Self low HP {self.conn.get_hp():.0f}% - healing self")
            party = self.conn.get_party()
            for m in party:
                if m.get("is_self"):
                    self.conn.target_party(m.get("index", 0))
                    break
            else:
                self.conn.target_party(0)
            time.sleep(0.1)
            self.conn.do_heal_target()
            self.stats["heals"] += 1
            return

        self.conn.do_buff()
        if self.conn.do_dps_weave():
            self.stats["casts"] += 1
            if DEBUG:
                print("[DEBUG] DPS weave cast")


class RotationUI:
    def __init__(self, conn, stop_event, script_print):
        self.conn = conn
        self.stop_event = stop_event
        self.script_print = script_print
        self.engine = RotationEngine(conn, stop_event, self._log)

        self.win = tk.Toplevel()
        self.win.title("Auto-Rotation")
        self.win.configure(bg=BG)
        self.win.geometry("340x480")
        self.win.resizable(False, True)
        self.win.wm_attributes("-topmost", True)
        self.win.protocol("WM_DELETE_WINDOW", self._on_close)

        x = (self.win.winfo_screenwidth() - 340) // 2
        y = (self.win.winfo_screenheight() - 480) // 2
        self.win.geometry(f"+{x}+{y}")

        # Header
        hdr = tk.Frame(self.win, bg=BG_CARD, height=44)
        hdr.pack(fill=tk.X)
        hdr.pack_propagate(False)
        tk.Label(hdr, text="⚔", font=("Segoe UI Emoji", 16), bg=BG_CARD, fg=ACCENT
                 ).pack(side=tk.LEFT, padx=(12, 8))
        tk.Label(hdr, text="Auto-Rotation", font=(FONT_B, 14), bg=BG_CARD, fg=TEXT
                 ).pack(side=tk.LEFT)
        tk.Frame(self.win, bg=ACCENT, height=2).pack(fill=tk.X)

        cls = conn.detect_class()
        tk.Label(self.win, text=f"  {cls}", font=(FONT_M, 9), bg=BG, fg=TEXT_DIM
                 ).pack(anchor=tk.W, padx=14, pady=(8, 0))

        # DPS / Heals toggles
        btn_frame = tk.Frame(self.win, bg=BG, pady=12, padx=14)
        btn_frame.pack(fill=tk.X)

        self.dps_btn = tk.Button(
            btn_frame, text="▶  DPS On", font=(FONT_B, 12),
            bg="#1a3a2a", fg=GREEN, relief=tk.FLAT,
            activebackground=GREEN, activeforeground=BG,
            padx=24, pady=12, cursor="hand2",
            command=lambda: self._toggle("dps"),
        )
        self.dps_btn.pack(side=tk.LEFT, padx=(0, 6))

        self.heal_btn = tk.Button(
            btn_frame, text="▶  Heals On", font=(FONT_B, 12),
            bg="#1a3a2a", fg=GREEN, relief=tk.FLAT,
            activebackground=GREEN, activeforeground=BG,
            padx=24, pady=12, cursor="hand2",
            command=lambda: self._toggle("heal"),
        )
        self.heal_btn.pack(side=tk.LEFT)

        self.status = tk.Label(self.win, text="", font=(FONT_M, 9), bg=BG, fg=TEXT_DIM)
        self.status.pack(pady=(0, 8))

        self.stats_label = tk.Label(self.win, text="Kills: 0   Heals: 0   Casts: 0   Looted: 0",
                                    font=(FONT_M, 8), bg=BG, fg=TEXT_DIM)
        self.stats_label.pack(fill=tk.X, padx=14, pady=(0, 4))

        # Options
        opt_frame = tk.Frame(self.win, bg=BG, padx=14)
        opt_frame.pack(fill=tk.X, pady=(0, 4))
        self._loot_var = tk.BooleanVar(value=True)
        tk.Checkbutton(
            opt_frame, text="💰 Auto-loot when window opens",
            variable=self._loot_var, font=(FONT_B, 9),
            bg=BG, fg="#FFD700", selectcolor=BG_CARD,
            activebackground=BG, activeforeground="#FFD700",
            highlightthickness=0, bd=0,
            command=self._toggle_loot,
        ).pack(anchor=tk.W)
        self._debug_var = tk.BooleanVar(value=False)
        tk.Checkbutton(
            opt_frame, text="🐛 Debug (verbose console)",
            variable=self._debug_var, font=(FONT_B, 9),
            bg=BG, fg=TEXT_DIM, selectcolor=BG_CARD,
            activebackground=BG, activeforeground=TEXT_DIM,
            highlightthickness=0, bd=0,
            command=self._toggle_debug,
        ).pack(anchor=tk.W)

        # Log
        log_frame = tk.Frame(self.win, bg=BG_CARD)
        log_frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=(0, 8))
        self.log_box = tk.Text(log_frame, font=(FONT_M, 8), bg="#060a10", fg=TEXT_DIM,
                               height=10, relief=tk.FLAT, highlightthickness=0,
                               padx=8, pady=6, state=tk.DISABLED, wrap=tk.WORD)
        self.log_box.pack(fill=tk.BOTH, expand=True, padx=4, pady=(0, 6))

        self._update_buttons()
        self._update_stats()
        self._poll_stop()

    def _toggle(self, mode):
        if self.engine.running and self.engine.mode == mode:
            self.engine.stop()
            self._log(f"  {mode.upper()} off")
        else:
            self.engine.loot_enabled = self._loot_var.get()
            self.engine.start(mode)
            self._log(f"  {mode.upper()} on")
        self._update_buttons()

    def _toggle_loot(self):
        self.engine.loot_enabled = self._loot_var.get()

    def _toggle_debug(self):
        _set_debug(self._debug_var.get())

    def _update_buttons(self):
        if self.engine.mode == "dps":
            self.dps_btn.configure(text="■  DPS Off", bg="#3a1a1a", fg=RED)
            self.heal_btn.configure(text="▶  Heals On", bg="#1a3a2a", fg=GREEN)
        elif self.engine.mode == "heal":
            self.dps_btn.configure(text="▶  DPS On", bg="#1a3a2a", fg=GREEN)
            self.heal_btn.configure(text="■  Heals Off", bg="#3a1a1a", fg=RED)
        else:
            self.dps_btn.configure(text="▶  DPS On", bg="#1a3a2a", fg=GREEN)
            self.heal_btn.configure(text="▶  Heals On", bg="#1a3a2a", fg=GREEN)

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

    def _update_stats(self):
        if not self.win.winfo_exists():
            return
        s = self.engine.stats
        self.stats_label.configure(
            text=f"Kills: {s['kills']}   Heals: {s['heals']}   Casts: {s['casts']}   Looted: {s.get('looted', 0)}"
        )
        if self.engine.running:
            self.status.configure(
                text=f"{self.engine.mode.upper()} running" + (" ⚔" if self.conn.in_combat() else ""),
                fg=RED if self.conn.in_combat() else GREEN,
            )
        else:
            self.status.configure(text="", fg=TEXT_DIM)
        self.win.after(500, self._update_stats)

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


# Entry — must create UI on main thread
def _open_ui():
    global ui
    ui = RotationUI(conn, stop_event, print)

_root = getattr(tk, "_default_root", None)
if _root and _root.winfo_exists():
    _root.after(0, _open_ui)
    print("  Opening Auto-Rotation UI...")
else:
    print("  Opening Auto-Rotation UI...")
    ui = RotationUI(conn, stop_event, print)
