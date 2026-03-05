"""
Auto-Loot v4 — Standalone with keyboard corpse opener
Polls for kills, presses interact to open corpse, then loots all.
"""
import time
import ctypes
import ctypes.wintypes
import ethytool_wraps
ethytool_wraps.conn = conn
from ethytool_wraps import *

# ════════════════════════════════════════════════════════════
#  CONFIG
# ════════════════════════════════════════════════════════════

INTERACT_SCANCODE = 0x21   # F key — CHANGE if your interact key is different!
POLL_RATE = 0.3

# ════════════════════════════════════════════════════════════
#  KEYBOARD
# ════════════════════════════════════════════════════════════

user32 = ctypes.windll.user32
INPUT_KEYBOARD = 1
KEYEVENTF_SCANCODE = 0x0008
KEYEVENTF_KEYUP = 0x0002

class KEYBDINPUT(ctypes.Structure):
    _fields_ = [
        ("wVk", ctypes.wintypes.WORD),
        ("wScan", ctypes.wintypes.WORD),
        ("dwFlags", ctypes.wintypes.DWORD),
        ("time", ctypes.wintypes.DWORD),
        ("dwExtraInfo", ctypes.POINTER(ctypes.c_ulong)),
    ]

class INPUT_UNION(ctypes.Union):
    _fields_ = [("ki", KEYBDINPUT)]

class INPUT(ctypes.Structure):
    _fields_ = [
        ("type", ctypes.wintypes.DWORD),
        ("union", INPUT_UNION),
    ]

def press_key(scan):
    down = INPUT()
    down.type = INPUT_KEYBOARD
    down.union.ki.wVk = 0
    down.union.ki.wScan = scan
    down.union.ki.dwFlags = KEYEVENTF_SCANCODE
    down.union.ki.time = 0
    down.union.ki.dwExtraInfo = None

    up = INPUT()
    up.type = INPUT_KEYBOARD
    up.union.ki.wVk = 0
    up.union.ki.wScan = scan
    up.union.ki.dwFlags = KEYEVENTF_SCANCODE | KEYEVENTF_KEYUP
    up.union.ki.time = 0
    up.union.ki.dwExtraInfo = None

    user32.SendInput(1, ctypes.byref(down), ctypes.sizeof(INPUT))
    time.sleep(0.05)
    user32.SendInput(1, ctypes.byref(up), ctypes.sizeof(INPUT))

def focus_game():
    result = [None]
    def check(hwnd, _):
        if user32.IsWindowVisible(hwnd):
            length = user32.GetWindowTextLengthW(hwnd)
            if length > 0:
                buf = ctypes.create_unicode_buffer(length + 1)
                user32.GetWindowTextW(hwnd, buf, length + 1)
                if "ethyrial" in buf.value.lower():
                    result[0] = hwnd
                    return False
        return True
    WNDENUMPROC = ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.wintypes.HWND, ctypes.wintypes.LPARAM)
    user32.EnumWindows(WNDENUMPROC(check), 0)
    if result[0]:
        user32.SetForegroundWindow(result[0])
        time.sleep(0.1)
    return result[0] is not None

def should_stop():
    try:
        return stop_event.is_set()
    except NameError:
        return False

def try_loot():
    """Attempt to loot. Returns number of items looted, or 0."""
    ok = loot()
    return 1 if ok else 0

# ════════════════════════════════════════════════════════════
#  MAIN LOOP
# ════════════════════════════════════════════════════════════

print()
print("+" + "-" * 53 + "+")
print("|  AUTO-LOOT v4 — Standalone                         |")
print("|  Detects kills -> interact -> loot all              |")
print(f"|  Interact key scancode: 0x{INTERACT_SCANCODE:02X}                        |")
print("+" + "-" * 53 + "+")
print()

had_target = False
total_looted = 0
loot_events = 0

try:
    while not should_stop():
        tgt = has_target()

        if tgt:
            had_target = True

        # Target just died — we had one, now it's gone
        if had_target and not tgt:
            had_target = False

            print("  Kill detected, opening corpse...")
            sleep(0.6)

            if focus_game():
                press_key(INTERACT_SCANCODE)
                sleep(0.5)

                if try_loot():
                    loot_events += 1
                    total_looted += 1
                    print(f"  [{loot_events}] LOOTED  Total: {total_looted}")
                else:
                    # Retry once — window may have been slow
                    sleep(0.4)
                    if try_loot():
                        loot_events += 1
                        total_looted += 1
                        print(f"  [{loot_events}] LOOTED (retry)  Total: {total_looted}")
                    else:
                        print("  Loot failed — no window open?")
            else:
                print("  Could not focus game window")

            print()

        # Also check for open loot windows (from manual clicks etc)
        if has_loot():
            if try_loot():
                loot_events += 1
                total_looted += 1
                print(f"  [{loot_events}] Passive loot  Total: {total_looted}")

        sleep(POLL_RATE)

except KeyboardInterrupt:
    pass

print()
print("+" + "-" * 53 + "+")
print(f"|  Stopped.  {loot_events} events, {total_looted} looted".ljust(54) + "|")
print("+" + "-" * 53 + "+")