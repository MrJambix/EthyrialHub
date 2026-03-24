# Druid Mechanics — From Game Assemblies & Spell Dump

## Game Assembly Structure (RPGLibrary + Game)

### Spell Class (from decompiled Game assembly)
- **StatusEffectCosts** — `List<SpellStatusEffectCost>` — Some spells consume or require status effects (buff/debuff stacks)
- **SpellStatusEffectCost** — `StatusEffectID` (string), `Count` (int)
- **Pattern** — `SpellPattern` — Defines spell effect behavior (logic is in native IL2CPP)
- **InterupCastOnMovement** / **InterupChannelOnMovement** — Movement cancels cast/channel
- **CastTime**, **ChannelTime** — As in spell dump

### Vocations
- **Druid = 603** (Mystic base class 600)

---

## Druid Spells — Inferred Mechanics

| Spell | CD | Cast | Mana | Notes |
|-------|-----|------|------|-------|
| **Bloom** | 30s | ⚡ | 6 | Can target self or ally. Instant. No Seed of Silcress required on target. |
| **Bolt of Narun** | 0 | 1.45s | 6 | Filler nuke. No CD. |
| **Ensnaring Spore** | 18s | 1.45s | 5 | Internal: BarbedUndergrowth. Root/snare CC. |
| **Flourish** | 8s | 0.5s | 14 | Short cast. May consume Bloom stacks (check StatusEffectCosts in-game). |
| **Grove of Rejuvenation** | 36s | ⚡ | 14 | Not self-target — ground/AOE heal. |
| **Ironbark** | 45s | ⚡ | 25 | Range 0 — self-only defensive (armor). |
| **Narun's Blast** | 8s | 1.9s | 12 | Big damage spell. |
| **Nourishing Touch** | 0 | 1.45s | 6 | Main single-target heal. Self-target capable. |
| **Purify Corruption** | 6s | ⚡ | 6 | Cleanse. |
| **Seed of Silcress** | 2s | ⚡ | 6 | Short CD. Could apply DoT or debuff; may synergize with Bloom. |
| **Spiritual Outburst** | 42s | 6s channel | 250 | Heavy mana cost. Long channel — stand still 6s. |
| **Rest** | 10s | 20s channel | 0 | OOC only. |

---

## StatusEffectCosts — Unknown Without Runtime Data

The `Spell.StatusEffectCosts` list defines which status effects a spell consumes. Examples of possible mechanics:
- **Flourish** might require/consume "Bloom" or "BloomStatus" stacks
- **Bloom** can be used on targeted ally without Seed of Silcress
- **Spiritual Outburst** might have special requirements

**To verify:** Extend `SPELLS_ALL` in ipc_bridge to include `StatusEffectCosts` per spell, or inspect in-game tooltips.

---

## Build Recommendations

1. **Bloom** — Keep as opener/buff. If it grants stacks, use before Flourish/Seed.
2. **Spiritual Outburst** — 250 mana is very high; use only when mana is full and target is worth the 6s channel.
3. **Nourishing Touch** — 1.45s cast; ensure channel_time is respected in heal logic.
4. **Grove of Rejuvenation** — May need ground targeting; verify cast behavior.
5. **Ironbark** — Range 0 = self only. Use as defensive.

---

## Files Referenced

- `Game/Spell.cs` — Spell fields, StatusEffectCosts
- `Game/SpellStatusEffectCost.cs` — StatusEffectID, Count
- `RPGLibrary/Vocations.cs` — Druid = 603
- `RPGLibrary/StatusEffectTypes.cs` — Buff, Debuff
- `RPGLibrary/SpellTypes.cs` — Spell, Ability
