"""
Auto-Loot v4 — Detects kills, opens corpse, loots all
"""
from ethytool_wraps import *
import ctypes
import ctypes.wintypes

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
    sleep(0.05)
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
        sleep(0.1)
    return result[0] is not None

# ════════════════════════════════════════════════════════════
#  MAIN
# ════════════════════════════════════════════════════════════

print()
print("AUTO-LOOT v4")
print(f"Interact scancode: 0x{INTERACT_SCANCODE:02X}")
print()

had_target = False
looted = 0

while True:
    if has_target():
        had_target = True

    if had_target and not has_target():
        had_target = False
        sleep(0.6)

        if focus_game():
            press_key(INTERACT_SCANCODE)
            sleep(0.5)

            if not loot():
                sleep(0.4)
                loot()

            looted += 1
            print(f"  Looted #{looted}")

    if has_loot():
        loot()

    sleep(POLL_RATE)