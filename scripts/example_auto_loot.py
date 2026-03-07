"""
Auto-Loot v5 — Corpse Window Looter
Detects kills, waits for corpse window, calls TakeAll via DLL.
"""
import time
import ethytool_wraps
ethytool_wraps.conn = conn
from ethytool_wraps import *

POLL_RATE = 0.3

def should_stop():
    try:
        return stop_event.is_set()
    except NameError:
        return False

def try_loot_corpse(max_wait=3.0):
    """Wait for corpse window to appear, then loot it. Returns True if looted."""
    start = time.time()
    while time.time() - start < max_wait:
        r = conn._send("LOOT_CORPSE_WINDOW")
        if r and "OK" in r:
            return True, r
        if r and "NO_CORPSE_WINDOW" not in r and "NO_METHOD" not in r:
            return False, r  # Something unexpected
        time.sleep(0.25)
    return False, "TIMEOUT"

print()
print("+" + "-" * 53 + "+")
print("|  AUTO-LOOT v5 — Corpse Window Looter               |")
print("|  Detects kills -> waits for corpse -> TakeAll       |")
print("+" + "-" * 53 + "+")
print()

had_target = False
last_target_name = ""
total_looted = 0
loot_events = 0

try:
    while not should_stop():
        tgt = has_target()

        if tgt:
            had_target = True
            n = target_name()
            if n:
                last_target_name = n

        if had_target and not tgt:
            had_target = False
            time.sleep(0.3)

            ok, result = try_loot_corpse(3.0)
            if ok:
                loot_events += 1
                total_looted += 1
                # Parse item count from response
                items = "?"
                if "items=" in result:
                    items = result.split("items=")[1].split("|")[0]
                print(f"  [{loot_events}] Looted {items} items from {last_target_name}  (Total: {total_looted})")
            else:
                print(f"  No loot from {last_target_name} ({result})")

        time.sleep(POLL_RATE)

except KeyboardInterrupt:
    pass

print()
print("+" + "-" * 53 + "+")
print(f"|  Stopped. {loot_events} kills, {total_looted} looted".ljust(54) + "|")
print("+" + "-" * 53 + "+")