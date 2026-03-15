"""
Auto-Loot — loots NEW corpse windows when they appear.
Spams LOOT_ALL multiple times per window to grab everything quickly.
Run from EthyTool dashboard. Stop the script to quit.
"""
import time

try:
    conn
    stop_event
except NameError:
    print("ERROR: Run this from the EthyTool dashboard.")
    raise SystemExit(1)

POLL_FAST = 0.15
POLL_IDLE = 0.4
LOOT_SPAM_COUNT = 8   # spam LOOT_ALL this many times per new window
LOOT_SPAM_DELAY = 0.05  # 50ms between each

looted_total = 0

print("")
print("=" * 60)
print("  Auto-Loot  (stop script to quit)")
print("=" * 60)
print("")

try:
    baseline = int(conn._send("LOOT_WINDOW_COUNT") or "0")
except (ValueError, TypeError):
    baseline = 0

print(f"  Baseline: {baseline} corpse loot window(s) — watching for NEW")
print("")

prev = baseline
while not stop_event.is_set():
    try:
        raw = conn._send("LOOT_WINDOW_COUNT")
        current = int(raw) if raw else 0
    except (ValueError, TypeError):
        current = 0

    if current > prev and current > baseline:
        new_count = current - prev
        ok_count = 0
        for _ in range(LOOT_SPAM_COUNT):
            if stop_event.is_set():
                break
            raw = conn._send("LOOT_ALL")
            if raw and raw.startswith("OK"):
                ok_count += 1
            time.sleep(LOOT_SPAM_DELAY)

        if ok_count > 0:
            looted_total += new_count
            print(f"  💰 Looted {new_count} window(s)  [OK={ok_count}/{LOOT_SPAM_COUNT} total: {looted_total}]")
        else:
            print(f"  ! LOOT_ALL failed (no corpse windows?)")

        try:
            current = int(conn._send("LOOT_WINDOW_COUNT") or "0")
        except (ValueError, TypeError):
            pass

    if current < baseline:
        baseline = current

    prev = current
    time.sleep(POLL_FAST if conn.in_combat() else POLL_IDLE)

print("")
print("=" * 60)
print(f"  Stopped  —  Looted: {looted_total}")
print("=" * 60)
