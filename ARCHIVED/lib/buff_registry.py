"""
buff_registry.py — Centralised Buff / Status-Effect Definitions
================================================================
Single source of truth for every buff's internal game name, display
name, stack cap, and duration.  All entries confirmed from live
PLAYER_BUFFS runtime data via buff_monitor.py.

Wire format reference (from ipc_bridge.cpp):
    name=<UniqueName> | disp=<DisplayName> | id=<ID>
    | stacks=<CurrentStacks> | dur=<CurrentDuration> | maxdur=<MaxDuration>

  • name / id  → use these for has_buff() / get_buff_stacks_count()
  • dur        → time elapsed since buff was applied (increases 0 → maxdur)
  • maxdur     → total duration in seconds (0 = permanent / toggle)
  • stacks     → integer 1–N  (fixed to return int after _parse_kv patch)

Usage in a build profile:
    from buff_registry import B, build_buff_config, get_buff_ids

    # Auto-generate BUFF_CONFIG for any listed buff:
    BUFF_CONFIG = build_buff_config(["Nature's Swiftness"])

    # Read stacks in a rotation:
    sl = conn.get_buff_stacks_count(B.SPIRIT_LINK)   # 0-5
"""

from __future__ import annotations


# ══════════════════════════════════════════════════════════════
#  Registry
#  Keys are the human-friendly spell / ability name used in
#  ROTATION, BUFFS, etc. lists.
# ══════════════════════════════════════════════════════════════

BUFF_REGISTRY: dict[str, dict] = {

    # ── Ranger ────────────────────────────────────────────────

    "Nature's Swiftness": {
        "id":         "NaturesSwiftnessBuff",   # confirmed runtime
        "disp":       "Nature's Swiftness",
        "max_stacks": 1,
        "duration":   8.0,                       # maxdur from runtime
        "type":       "buff",
        "source":     "ranger",
    },

    "Spirit Link": {
        "id":         "SpiritLink",              # confirmed runtime
        "disp":       "Spirit Link",
        "max_stacks": 5,
        "duration":   6.0,                       # maxdur from runtime
        "type":       "proc",
        "source":     "ranger",
        "notes":      "Gained in combat; each new stack resets the 6 s timer.",
    },

    "Linked Rejuvenation": {
        "id":         "LinkedRejuvenation",      # confirmed runtime
        "disp":       "Linked Rejuvenation",
        "max_stacks": 1,
        "duration":   10.0,
        "type":       "heal",
        "source":     "ranger",
    },

    "Ember": {
        "id":         "EmberStatus",             # confirmed runtime
        "disp":       "Ember",
        "max_stacks": 2,                         # observed 2 stacks in runtime logs
        "duration":   15.0,
        "type":       "proc",
        "source":     "ranger",
    },

    "Storm's Speed": {
        "id":         "StormsSpeed",             # confirmed runtime
        "disp":       "Storm's Speed",
        "max_stacks": 1,
        "duration":   9.0,
        "type":       "buff",
        "source":     "ranger",
    },

    # ── Passive / Toggle ──────────────────────────────────────

    "Nature Arrows": {
        "id":         "Nature_Arrows",           # confirmed runtime
        "disp":       "Nature Arrows",
        "max_stacks": 1,
        "duration":   0.0,                       # permanent toggle (maxdur=0)
        "type":       "passive",
        "source":     "ranger",
        "notes":      "Toggle — never auto-cast in rotation (IGNORED_SPELLS).",
    },

    # ── Generic / Food ────────────────────────────────────────

    "Well Fed": {
        "id":         "well-fedT3",              # confirmed runtime
        "disp":       "Well Fed",
        "max_stacks": 1,
        "duration":   0.0,                       # food buff, no expiry observed
        "type":       "passive",
        "source":     "consumable",
    },

    "Immunity": {
        "id":         "Immunity",                # confirmed runtime
        "disp":       "Immunity",
        "max_stacks": 1,
        "duration":   30.0,
        "type":       "buff",
        "source":     "system",
    },
}


# ══════════════════════════════════════════════════════════════
#  Named constants  (use B.<NAME> instead of bare strings)
# ══════════════════════════════════════════════════════════════

class B:
    """Buff internal-ID constants — avoids bare magic strings in code."""

    # Ranger procs / buffs
    NATURES_SWIFTNESS  = "NaturesSwiftnessBuff"
    SPIRIT_LINK        = "SpiritLink"
    LINKED_REJUV       = "LinkedRejuvenation"
    EMBER              = "EmberStatus"
    STORMS_SPEED       = "StormsSpeed"
    NATURE_ARROWS      = "Nature_Arrows"

    # Generic
    WELL_FED           = "well-fedT3"
    IMMUNITY           = "Immunity"


# ══════════════════════════════════════════════════════════════
#  Helpers
# ══════════════════════════════════════════════════════════════

def get_internal_id(spell_name: str) -> str:
    """
    Return the internal PLAYER_BUFFS `name=` value for a spell name.
    Falls back to the spell name itself if not registered.
    """
    return BUFF_REGISTRY.get(spell_name, {}).get("id", spell_name)


def get_buff_ids(spell_name: str) -> list[str]:
    """
    Return all ID variants to try when calling has_buff().
    Includes the internal ID and the human-readable name as fallback.
    """
    entry = BUFF_REGISTRY.get(spell_name, {})
    internal = entry.get("id", spell_name)
    ids = [internal]
    if spell_name != internal:
        ids.append(spell_name)
    return ids


def get_max_stacks(spell_name: str) -> int:
    """Maximum stack count for a buff (1 = non-stacking)."""
    return BUFF_REGISTRY.get(spell_name, {}).get("max_stacks", 1)


def get_duration(spell_name: str) -> float:
    """Total buff duration in seconds (0 = permanent/toggle)."""
    return BUFF_REGISTRY.get(spell_name, {}).get("duration", 0.0)


def build_buff_config(spell_names: list[str]) -> dict:
    """
    Auto-generate a BUFF_CONFIG dict from a list of spell names.
    Plug the result straight into a build profile as BUFF_CONFIG.

    Example:
        BUFF_CONFIG = build_buff_config(["Nature's Swiftness"])
    """
    config: dict = {}
    for name in spell_names:
        entry = BUFF_REGISTRY.get(name)
        if entry:
            config[name] = {
                "detect_buff": True,
                "buff_ids": get_buff_ids(name),
            }
    return config


def is_stackable(spell_name: str) -> bool:
    """True if the buff can accumulate more than one stack."""
    return get_max_stacks(spell_name) > 1


def lookup_by_id(internal_id: str) -> dict | None:
    """Reverse-lookup: find registry entry by its internal id."""
    for entry in BUFF_REGISTRY.values():
        if entry.get("id") == internal_id:
            return entry
    return None
