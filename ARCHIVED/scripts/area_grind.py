
"""
follow_healer.py — Multi-Class Follow-Healer Bot also a grindbot i guess
==================================================
Setup:  1. Party with tank, turn on auto-follow
        2. Select tank as friendly target
        3. Run this script

The game handles pass-through targeting:
  • Attack spells pass through friendly target → hit enemy
  • Heal spells pass through enemy → heal friendly target

Supports multiple classes via CLASS_PROFILES dict.
Auto-detects class and loads the matching profile.
"""

import time
import sys
import os
import threading
import ctypes

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ethytool_lib import create_connection, ScreenReader

try:
    conn; stop_event
except NameError:
    conn = create_connection(); conn.connect()
    stop_event = threading.Event()

e = conn


# ══════════════════════════════════════════════════════════════
#  CLASS PROFILES — add / edit your classes here
# ══════════════════════════════════════════════════════════════

CLASS_PROFILES = {


    "Infuser": {
        "attack_spells":   ["Unstable Infusion", "Attack"],
        "heal_spells":     [""],
        "buff_spells":     ["Leyline Stream"],
        "buff_cooldowns":  {"Leyline Stream": 15},   # min seconds between recasts
        "rest_spell":      "Rest",
        "heal_threshold":  70,
        "self_heal_thresh": 70,
        "rest_mp_thresh":  70,
        "rest_hp_thresh":  90,        # rest until HP above this too
        "enemy_range":     10.0,       # normal attack range
        "safe_range":      5.0,       # rest only if nothing this close
        "pull_range":      18.0,      # pull distant mobs when full HP/MP
        "ignore_mobs":     [
            "Infused Brute", "Infused Mage", "Reinforced Brute",
            "Fortified Mage", "Fortified Brute", "Infused Golem",
            "Spirit Wolf Cub", "Spirit Wolf",
        ],
    },

    "Priest": {
        "attack_spells":   ["Flame's Judgement"],
        "heal_spells":     ["Soothing Flame"],
        "buff_spells":     [],
        "buff_cooldowns":  {},
        "rest_spell":      "Rest",
        "heal_threshold":  70,
        "self_heal_thresh": 70,
        "rest_mp_thresh":  70,
        "rest_hp_thresh":  90,
        "enemy_range":     8.0,
        "safe_range":      5.0,
        "pull_range":      14.0,
        "ignore_mobs":     [
            "Infused Brute", "Infused Mage", "Reinforced Brute",
            "Fortified Mage", "Fortified Brute", "Infused Golem",
            "Spirit Wolf Cub", "Spirit Wolf",
        ],
    },


    # ── fallback if class isn't recognized ──
    "default": {
        "attack_spells":   [],
        "heal_spells":     [],
        "buff_spells":     [],
        "buff_cooldowns":  {},
        "rest_spell":      "Rest",
        "heal_threshold":  70,
        "self_heal_thresh": 70,
        "rest_mp_thresh":  70,
        "rest_hp_thresh":  90,
        "enemy_range":     8.0,
        "safe_range":      5.0,
        "pull_range":      14.0,
        "ignore_mobs":     [
            "Infused Brute", "Infused Mage", "Reinforced Brute",
            "Fortified Mage", "Fortified Brute", "Infused Golem",
            "Spirit Wolf Cub", "Spirit Wolf",
        ],
    },
}

ENEMY_RANGE = 8.0000    # default range; profiles can override via "enemy_range"
TICK        = 0.75      # main loop speed (seconds)

# ── Greed roll config ─────────────────────────────────────────
GREED_IMAGE      = "Greed.png"    # template image to look for
GREED_INTERVAL   = 3.0            # seconds between greed scans
GREED_CLICK_WAIT = 2.0            # seconds to sleep after clicking
GREED_THRESHOLD  = 0.75           # match confidence


# ══════════════════════════════════════════════════════════════
#  FollowHealerBot
# ══════════════════════════════════════════════════════════════

class FollowHealerBot:

    def __init__(self, conn, stop_event, profile, class_name):
        self.conn          = conn
        self.stop_event    = stop_event
        self.class_name    = class_name

        # unpack profile with safe defaults
        self.attack_spells   = profile.get("attack_spells",   [])
        self.heal_spells     = profile.get("heal_spells",     [])
        self.buff_spells     = profile.get("buff_spells",     [])
        self.rest_spell      = profile.get("rest_spell",      "Rest")
        self.heal_threshold  = profile.get("heal_threshold",  70)
        self.self_heal_thresh = profile.get("self_heal_thresh", 70)
        self.rest_mp_thresh  = profile.get("rest_mp_thresh",  70)
        self.rest_hp_thresh  = profile.get("rest_hp_thresh",  90)
        self.enemy_range     = profile.get("enemy_range",     ENEMY_RANGE)
        self.safe_range      = profile.get("safe_range",      5.0)
        self.pull_range      = profile.get("pull_range",      14.0)
        self.ignore_mobs     = set(profile.get("ignore_mobs", []))
        self.buff_cooldowns  = profile.get("buff_cooldowns",  {})  # spell → seconds

        # filter to spells we actually know
        self.attack_spells = self._filter_known(self.attack_spells)
        self.heal_spells   = self._filter_known(self.heal_spells)
        self.buff_spells   = self._filter_known(self.buff_spells)

        # internal state
        self._buff_tick      = 0
        self._buff_last_cast = {}   # spell name → time.time() of last cast
        self._mana_costs     = {}

        # greed roll detection
        self._last_greed_scan = 0
        self._screen = None
        try:
            pid = getattr(self.conn, "_pid", None)
            self._screen = ScreenReader(pid=pid)
            if not self._screen._ready:
                self._screen = None
        except Exception:
            self._screen = None

    # ── setup ─────────────────────────────────────────────────

    def _filter_known(self, spell_list):
        """Keep only spells the character actually has."""
        try:
            return self.conn.filter_available(spell_list)
        except Exception:
            return list(spell_list)

    def _load_mana_costs(self):
        """Read mana costs from live spell data."""
        costs = {}
        try:
            for s in self.conn.get_spells():
                name = s.get("display") or s.get("name", "")
                scaled = s.get("scaled_mana")
                raw    = s.get("mana", 0)
                if scaled is not None:
                    try:
                        sv = float(scaled)
                        costs[name] = f"{sv * 100 if sv <= 1 else sv:.0f}% MP"
                    except (ValueError, TypeError):
                        costs[name] = f"{raw} flat"
                else:
                    costs[name] = f"{raw} flat"
        except Exception as exc:
            self._log(f"  [WARN] Could not load mana costs: {exc}")
        self._mana_costs = costs

    # ── logging ───────────────────────────────────────────────

    @staticmethod
    def _log(msg):
        print(msg)

    def _print_banner(self):
        self._load_mana_costs()
        print("═══════════════════════════════════════")
        print("  Follow-Healer Bot")
        print(f"  Class:             {self.class_name}")
        print(f"  Heal friend below: {self.heal_threshold}%")
        print(f"  Heal self below:   {self.self_heal_thresh}%")
        print(f"  Rest below:        {self.rest_mp_thresh}% MP, {self.rest_hp_thresh}% HP")
        print(f"  Safe range:        {self.safe_range}  (rest if clear)")
        print(f"  Enemy range:       {self.enemy_range}  (normal attack)")
        print(f"  Pull range:        {self.pull_range}  (pull when full)")
        if self.ignore_mobs:
            print(f"  Ignoring:          {', '.join(sorted(self.ignore_mobs))}")
        print("───────────────────────────────────────")
        print("  Spells:")
        groups = [
            ("Attack", self.attack_spells),
            ("Heal",   self.heal_spells),
            ("Buff",   self.buff_spells),
            ("Rest",   [self.rest_spell]),
        ]
        for label, spells in groups:
            for name in spells:
                cost = self._mana_costs.get(name, "unknown")
                cd = self.buff_cooldowns.get(name)
                cd_str = f"  (every {cd}s)" if cd else ""
                print(f"    [{label:<6}] {name:<25} {cost}{cd_str}")
        print("───────────────────────────────────────")
        greed_status = "ON" if self._screen else "OFF (ScreenReader unavailable)"
        print(f"  Greed roll:        {greed_status}")
        if self._screen:
            print(f"    Image:           {GREED_IMAGE}")
            print(f"    Scan every:      {GREED_INTERVAL}s")
            print(f"    Click delay:     {GREED_CLICK_WAIT}s")
        print("═══════════════════════════════════════")

    # ── helpers ───────────────────────────────────────────────

    def _cast_first_ready(self, spell_list):
        """Cast the first spell in the list that is off cooldown."""
        for name in spell_list:
            try:
                if self.conn.is_spell_ready(name) and self.conn.cast(name):
                    return name
            except Exception:
                continue
        return None

    def _enemies_in_range(self, limit=None):
        """Alive enemies within limit distance, ignoring blacklisted mobs.
        Falls back to self.enemy_range if no limit given."""
        if limit is None:
            limit = self.enemy_range
        try:
            mobs = self.conn.monsterdex_nearby()
        except Exception:
            return []

        result = []
        for m in mobs:
            try:
                hp   = float(m.get("hp", 0))
                dist = float(m.get("dist", 9999))
                name = m.get("name", "")
            except (ValueError, TypeError):
                continue

            if hp <= 0:                     continue   # dead
            if dist > limit:                continue   # too far
            if name in self.ignore_mobs:    continue   # blacklisted
            result.append(m)
        return result

    def _get_hp_safe(self):
        try:
            return self.conn.get_hp()
        except Exception:
            return 100.0

    def _get_mp_safe(self):
        try:
            return self.conn.get_mp()
        except Exception:
            return 100.0

    def _in_combat_safe(self):
        try:
            return self.conn.in_combat()
        except Exception:
            return False

    def _retarget_if_far(self):
        """If current target is too far away, grab the nearest one instead."""
        try:
            if self.conn.has_target() and self.conn.get_target_distance() > 10:
                self.conn.target_nearest()
                time.sleep(TICK)
        except Exception:
            pass

    # ── greed roll detection ──────────────────────────────────

    @staticmethod
    def _click_at(x, y):
        """Move mouse to (x, y) and left-click using Windows API."""
        try:
            ctypes.windll.user32.SetCursorPos(int(x), int(y))
            time.sleep(0.05)
            # mouse_event: LEFTDOWN=0x0002, LEFTUP=0x0004
            ctypes.windll.user32.mouse_event(0x0002, 0, 0, 0, 0)
            time.sleep(0.05)
            ctypes.windll.user32.mouse_event(0x0004, 0, 0, 0, 0)
        except Exception:
            pass

    def _check_greed(self):
        """Scan screen for Greed.png; if found, click it."""
        if self._screen is None:
            return False
        now = time.time()
        if now - self._last_greed_scan < GREED_INTERVAL:
            return False
        self._last_greed_scan = now
        self._log(f"  💰 Greed scan init.")
        try:
            match = self._screen.find_image(GREED_IMAGE, threshold=GREED_THRESHOLD)
            if match:
                cx, cy, conf = match
                self._log(f"  💰 Greed found ({conf:.0%}) — clicking ({cx}, {cy})")
                self._click_at(cx, cy)
                time.sleep(GREED_CLICK_WAIT)
                return True
        except Exception as exc:
            self._log(f"  [WARN] Greed scan error: {exc}")
        return False

    # ── main loop ─────────────────────────────────────────────

    def run(self):
        self._print_banner()
        print("\n  Running... (Ctrl+C to stop)\n")

        try:
            while not self.stop_event.is_set():
                try:
                    self._tick()
                except Exception as exc:
                    self._log(f"  [ERR] {exc}")
                time.sleep(TICK)
        except KeyboardInterrupt:
            print("\n  Stopped.")

    def _tick(self):
        # ── GREED: check for loot roll popup first ────
        if self._check_greed():
            return

        my_hp     = self._get_hp_safe()
        my_mp     = self._get_mp_safe()
        in_combat = self._in_combat_safe()

        # scan once at max range, filter into tiers
        all_nearby    = self._enemies_in_range(self.pull_range)
        nearby_normal = [m for m in all_nearby if float(m.get("dist", 9999)) <= self.enemy_range]
        nearby_safe   = [m for m in all_nearby if float(m.get("dist", 9999)) <= self.safe_range]

        hp_full = my_hp >= self.rest_hp_thresh
        mp_full = my_mp >= self.rest_mp_thresh

        # ── SAFE ZONE: no enemies close → rest until topped off ──
        if not in_combat and not nearby_safe:
            if not hp_full or not mp_full:
                try:
                    if self.conn.is_spell_ready(self.rest_spell):
                        if self.conn.cast(self.rest_spell):
                            self._log(f"  ☽ Resting... (HP {my_hp:.0f}%  MP {my_mp:.0f}%)")
                            return
                except Exception:
                    pass
                return   # don't attack while recovering, even if rest failed

        # ── retarget if current target wandered off ───
        self._retarget_if_far()

        # ── refresh buffs (respecting per-spell cooldowns) ─
        self._buff_tick += 1
        if self._buff_tick >= 5 and self.buff_spells:
            self._buff_tick = 0
            now = time.time()
            for name in self.buff_spells:
                # check custom cooldown
                cd = self.buff_cooldowns.get(name, 0)
                last = self._buff_last_cast.get(name, 0)
                if cd > 0 and (now - last) < cd:
                    continue
                try:
                    if self.conn.is_spell_ready(name) and self.conn.cast(name):
                        self._buff_last_cast[name] = now
                        self._log(f"  ✦ Buff: {name}")
                        return
                except Exception:
                    continue

        # ── HEAL: self HP critical ────────────────────
        if my_hp < self.self_heal_thresh and self.heal_spells:
            result = self._cast_first_ready(self.heal_spells)
            if result:
                self._log(f"  ♥ {result}  (self HP {my_hp:.0f}%)")
            return   # skip attacking this tick even if heal failed

        # ── HEAL: friendly target low ─────────────────
        if self.heal_spells:
            try:
                ft = self.conn.get_friendly_target()
                if ft:
                    friend_hp = float(ft.get("hp", 100))
                    if friend_hp < self.heal_threshold:
                        result = self._cast_first_ready(self.heal_spells)
                        if result:
                            friend_name = ft.get("name", "friend")
                            self._log(f"  ♥ {result}  ({friend_name} HP {friend_hp:.0f}%)")
                        return
            except Exception:
                pass

        # ── ATTACK: normal range ──────────────────────
        if nearby_normal and self.attack_spells:
            result = self._cast_first_ready(self.attack_spells)
            if result:
                self._log(f"  ⚔ {result}  ({len(nearby_normal)} in range)")
            return

        # ── PULL: long range when full HP & MP ────────
        if hp_full and mp_full and all_nearby and self.attack_spells:
            result = self._cast_first_ready(self.attack_spells)
            if result:
                self._log(f"  ⚔ Pull: {result}  ({len(all_nearby)} in pull range)")


# ══════════════════════════════════════════════════════════════
#  Auto-detect class & launch
# ══════════════════════════════════════════════════════════════

def detect_and_run():
    detected = "Unknown"
    try:
        detected = e.detect_class()
    except Exception:
        pass

    # match detected class name against profile keys (case-insensitive substring)
    profile = None
    matched_name = None
    det_lower = detected.lower()

    for key in CLASS_PROFILES:
        if key == "default":
            continue
        if key.lower() in det_lower or det_lower in key.lower():
            profile = CLASS_PROFILES[key]
            matched_name = key
            break

    if profile is None:
        profile = CLASS_PROFILES["default"]
        matched_name = f"{detected} (default)"
        print(f"  [WARN] No profile for '{detected}', using default.")
        print(f"         Add a '{detected}' entry to CLASS_PROFILES to customize.")

    bot = FollowHealerBot(e, stop_event, profile, matched_name)
    bot.run()


if __name__ == "__main__":
    detect_and_run()
else:
    detect_and_run()
