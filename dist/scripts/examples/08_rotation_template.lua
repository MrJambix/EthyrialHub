--[[
╔══════════════════════════════════════════════════════════════╗
║          ROTATION TEMPLATE — Build Your Own                  ║
║                                                              ║
║  A complete, heavily-documented example showing every        ║
║  rotation concept: buff tracking, spell priority, DoT        ║
║  management, resource gating, follow-up combos, mana         ║
║  conservation, and rest/meditation.                          ║
║                                                              ║
║  Copy this file, rename it to your class, and customize.     ║
║  Every section is labeled so you know what to change.        ║
╚══════════════════════════════════════════════════════════════╝

HOW SPELLS WORK:
  - Spells are referenced by their INTERNAL name (not display name).
  - Use the SDK Dumper tab or SPELLS_ALL pipe command to find names.
  - core.spells.is_ready(name) → true if off cooldown + has mana
  - core.spells.cast(name) → sends cast command, returns "OK" on success

HOW BUFFS WORK:
  - Buffs are tracked by their internal unique name.
  - core.buff_manager.has_buff(name) → true/false
  - core.buff_manager.get_stacks(name) → number (0 if not active)
  - core.buff_manager.get_buff_data(name) → table with fields:
      .is_active, .name, .display_name, .stacks, .duration, .max_duration
  - core.player.buffs() → raw pipe string of all active buffs

HOW EVENTS WORK:
  - ethy.on_update(fn) → called every frame (~60/sec), main rotation tick
  - ethy.on_combat_enter(fn) → fired once when combat starts
  - ethy.on_combat_leave(fn) → fired once when combat ends
  - ethy.on_buff_applied(fn) → fn(buff_name) when a buff appears
  - ethy.on_buff_removed(fn) → fn(buff_name) when a buff falls off
  - ethy.on_spell_cast(fn) → fn(spell_name) after a spell is cast
]]

local ethy = require("common/ethy_sdk")

-- ═════════════════════════════════════════════════════════════
--  SECTION 1: CONFIGURATION
--  Change these numbers to tune your rotation's behavior.
-- ═════════════════════════════════════════════════════════════

local CONFIG = {
    TICK_RATE       = 0.3,    -- seconds between rotation ticks (don't go below 0.2)
    HEAL_HP         = 55,     -- cast heal spells below this HP %
    EMERGENCY_HP    = 30,     -- cast emergency/defensive spells below this
    REST_HP         = 75,     -- sit down to rest below this (out of combat)
    REST_MP         = 50,     -- sit down to rest below this mana %
    MANA_CONSERVE   = 20,     -- stop DPS rotation below this mana %
    DOT_DURATION    = 6.0,    -- how long your DoT lasts (for refresh tracking)
}

-- ═════════════════════════════════════════════════════════════
--  SECTION 2: SPELL NAMES
--  Replace these with your class's actual internal spell names.
--  To find them: connect to game → Dev Tools → Raw IPC → SPELLS_ALL
--  Or use the SDK Dumper to inspect the Spell class.
-- ═════════════════════════════════════════════════════════════

local SPELLS = {
    -- Damage
    FILLER          = "Stormbolt",           -- spammable filler
    AOE             = "StormOfHaste",        -- area damage
    BIG_HIT         = "Tempest",             -- high-damage cooldown
    DOT             = "DebilitatingWaters",  -- damage over time

    -- Buffs (self-cast, need upkeep)
    BUFF_1          = "Stormshield",         -- shield buff
    BUFF_2          = "ImbueMindClarity",    -- haste/crit buff

    -- Heals
    HEAL            = "StreamOfLife",        -- main heal
    EMERGENCY_HEAL  = "CleansingWaters",     -- cleanse + heal

    -- Defensive
    DEFENSIVE       = "Stormshield",         -- damage absorb

    -- Rest
    REST            = "Rest",                -- out-of-combat regen
    MEDITATION      = "LeylineMeditation",   -- mana regen (channeled)
}

-- ═════════════════════════════════════════════════════════════
--  SECTION 3: BUFF NAMES
--  Internal buff IDs as they appear in the status effect system.
--  These are the names you check with has_buff() / get_stacks().
--  To find them: PLAYER_STATUS_EFFECTS or BUFF_LIST pipe command.
-- ═════════════════════════════════════════════════════════════

local BUFFS = {
    SHIELD_BUFF     = "Stormshield",         -- from Stormshield spell
    HASTE_BUFF      = "ImbueMindClarity",    -- from Imbue Mind: Clarity
    DOT_DEBUFF      = "DebilitatingWaters",  -- DoT we apply to enemy
    WELL_FED        = "well-fedT3",          -- food buff
}

-- ═════════════════════════════════════════════════════════════
--  SECTION 4: STATE TRACKING
--  Internal variables the rotation uses to remember things
--  between ticks. You shouldn't need to edit these.
-- ═════════════════════════════════════════════════════════════

local state = {
    last_cast_time  = 0,      -- timestamp of last successful cast
    last_cast_name  = "",     -- name of last spell cast
    dot_applied_at  = 0,      -- when we last applied our DoT
    follow_up       = nil,    -- queued spell to cast next tick
    combo_step      = 0,      -- for multi-spell combos
    buffs_raw       = "",     -- cached raw buff string
}

-- ═════════════════════════════════════════════════════════════
--  SECTION 5: HELPER FUNCTIONS
--  Reusable building blocks. Customize or add more as needed.
-- ═════════════════════════════════════════════════════════════

--- Try to cast a spell. Returns true if successful.
local function cast(spell_name)
    if not spell_name or spell_name == "" then return false end

    -- Check if spell is ready (off cooldown + enough mana)
    local ready = core.spells.is_ready(spell_name)
    if not ready then return false end

    -- Send the cast
    local result = core.spells.cast(spell_name)
    if result and (result:find("OK") or result == "") then
        state.last_cast_time = ethy.now()
        state.last_cast_name = spell_name
        ethy.printf("[Rotation] Cast: %s", spell_name)
        return true
    end
    return false
end

--- Check if a buff is active on the player.
--- Checks both the buff manager API and the raw buff string as fallback.
local function has_buff(buff_name)
    -- Method 1: Use the buff manager (fast, preferred)
    if ethy.buff_manager.has_buff(buff_name) then
        return true
    end

    -- Method 2: Check the raw buff string (catches display name variants)
    if state.buffs_raw and state.buffs_raw ~= "" and state.buffs_raw ~= "NONE" then
        if state.buffs_raw:find("name=" .. buff_name, 1, true) then
            return true
        end
    end

    return false
end

--- Get the stack count of a buff.
local function get_stacks(buff_name)
    local s = ethy.buff_manager.get_stacks(buff_name)
    return (s and s > 0) and s or 0
end

--- Get detailed buff info (duration, stacks, etc.)
local function get_buff_info(buff_name)
    return ethy.buff_manager.get_buff_data(buff_name)
end

--- Refresh the cached raw buff string (call once per tick).
local function refresh_buffs()
    state.buffs_raw = core.player.buffs() or ""
end

--- Check if our DoT needs refreshing (based on tracked duration).
local function dot_needs_refresh()
    if state.dot_applied_at == 0 then return true end
    return ethy.time_since(state.dot_applied_at) > (CONFIG.DOT_DURATION - 1.5)
end

--- Check if enough time has passed since last cast (GCD respect).
local function gcd_ready()
    return ethy.time_since(state.last_cast_time) >= CONFIG.TICK_RATE
end

-- ═════════════════════════════════════════════════════════════
--  SECTION 6: BUFF UPKEEP
--  Checks each buff and casts the spell if it's missing.
--  Called both in and out of combat.
-- ═════════════════════════════════════════════════════════════

local function maintain_buffs()
    refresh_buffs()

    -- Shield buff — reapply if not active
    if not has_buff(BUFFS.SHIELD_BUFF) then
        if cast(SPELLS.BUFF_1) then return true end
    end

    -- Haste buff — reapply if not active
    if not has_buff(BUFFS.HASTE_BUFF) then
        if cast(SPELLS.BUFF_2) then return true end
    end

    -- You can add more buffs here following the same pattern:
    -- if not has_buff("YourBuffName") then
    --     if cast("YourBuffSpellName") then return true end
    -- end

    return false
end

-- ═════════════════════════════════════════════════════════════
--  SECTION 7: COMBAT ROTATION
--  The core DPS/heal priority list. Goes top to bottom,
--  first spell that's ready and meets conditions gets cast.
-- ═════════════════════════════════════════════════════════════

local function do_combat(hp, mp)
    -- ──────────────────────────────────────────────────────
    -- PRIORITY 1: Emergency — cast defensive/heal if low HP
    -- ──────────────────────────────────────────────────────
    if hp < CONFIG.EMERGENCY_HP then
        if cast(SPELLS.EMERGENCY_HEAL) then return true end
        if cast(SPELLS.DEFENSIVE) then return true end
    end

    -- ──────────────────────────────────────────────────────
    -- PRIORITY 2: Heal — cast heal if HP below threshold
    -- ──────────────────────────────────────────────────────
    if hp < CONFIG.HEAL_HP then
        if cast(SPELLS.HEAL) then return true end
    end

    -- ──────────────────────────────────────────────────────
    -- PRIORITY 3: Follow-up combo — if we queued a spell
    -- Example: after a big spender, immediately follow up
    -- ──────────────────────────────────────────────────────
    if state.follow_up then
        local spell = state.follow_up
        state.follow_up = nil
        if cast(spell) then return true end
    end

    -- ──────────────────────────────────────────────────────
    -- PRIORITY 4: Mana conservation — stop DPS if OOM
    -- ──────────────────────────────────────────────────────
    if mp < CONFIG.MANA_CONSERVE then
        ethy.print("[Rotation] Low mana, conserving")
        return false
    end

    -- ──────────────────────────────────────────────────────
    -- PRIORITY 5: Buff upkeep — refresh buffs mid-combat
    -- ──────────────────────────────────────────────────────
    if maintain_buffs() then return true end

    -- ──────────────────────────────────────────────────────
    -- PRIORITY 6: Cooldowns — use big abilities when ready
    -- ──────────────────────────────────────────────────────
    if cast(SPELLS.BIG_HIT) then
        -- Queue a follow-up after the big hit (combo example)
        state.follow_up = SPELLS.AOE
        ethy.printf("[Rotation] -> queued %s as follow-up", SPELLS.AOE)
        return true
    end

    -- ──────────────────────────────────────────────────────
    -- PRIORITY 7: DoT — apply/refresh damage-over-time
    -- ──────────────────────────────────────────────────────
    if dot_needs_refresh() then
        if cast(SPELLS.DOT) then
            state.dot_applied_at = ethy.now()
            return true
        end
    end

    -- ──────────────────────────────────────────────────────
    -- PRIORITY 8: AoE — use if available
    -- ──────────────────────────────────────────────────────
    if cast(SPELLS.AOE) then
        return true
    end

    -- ──────────────────────────────────────────────────────
    -- PRIORITY 9: Filler — always-available spam spell
    -- ──────────────────────────────────────────────────────
    if cast(SPELLS.FILLER) then
        return true
    end

    return false
end

-- ═════════════════════════════════════════════════════════════
--  SECTION 8: OUT-OF-COMBAT BEHAVIOR
--  Handles buff upkeep, resting, and meditation when idle.
-- ═════════════════════════════════════════════════════════════

local function do_out_of_combat(hp, mp)
    -- Maintain buffs even out of combat
    if maintain_buffs() then return true end

    -- Rest if HP or MP is low
    if hp < CONFIG.REST_HP or mp < CONFIG.REST_MP then
        -- Try meditation first (faster mana regen)
        if mp < CONFIG.REST_MP then
            if cast(SPELLS.MEDITATION) then return true end
        end
        -- Fall back to rest
        if cast(SPELLS.REST) then return true end
    end

    return false
end

-- ═════════════════════════════════════════════════════════════
--  SECTION 9: EVENT HOOKS
--  React to combat state changes and buff events.
-- ═════════════════════════════════════════════════════════════

ethy.on_combat_enter(function()
    state.follow_up = nil
    state.dot_applied_at = 0
    state.combo_step = 0
    ethy.print("[Rotation] === COMBAT START ===")
end)

ethy.on_combat_leave(function()
    state.follow_up = nil
    state.combo_step = 0
    ethy.print("[Rotation] === COMBAT END ===")
end)

-- Optional: react when specific buffs are applied
ethy.on_buff_applied(function(buff_name)
    -- Example: log when your shield procs
    if buff_name == BUFFS.SHIELD_BUFF then
        ethy.printf("[Rotation] Shield active! (%s)", buff_name)
    end
end)

-- Optional: react when buffs fall off
ethy.on_buff_removed(function(buff_name)
    if buff_name == BUFFS.SHIELD_BUFF then
        ethy.print("[Rotation] Shield expired, will refresh next tick")
    end
end)

-- ═════════════════════════════════════════════════════════════
--  SECTION 10: MAIN LOOP
--  This runs every frame. It checks state and calls the
--  appropriate rotation function.
-- ═════════════════════════════════════════════════════════════

ethy.print("╔══════════════════════════════════════════════════╗")
ethy.print("║  Rotation Template Loaded                        ║")
ethy.print("║  Edit SPELLS table with your class's spells      ║")
ethy.print("║  Edit BUFFS table with your buff internal names  ║")
ethy.print("║  Edit CONFIG to tune HP/MP thresholds            ║")
ethy.print("╚══════════════════════════════════════════════════╝")

ethy.on_update(function()
    local player = ethy.get_player()
    if not player then return end

    -- Skip if dead or frozen (CC'd)
    if player:is_dead() or player:is_frozen() then return end

    -- Get player resources
    local hp = player:get_health_percent()
    local mp = player:get_mana_percent()
    if hp <= 0 then return end

    -- Respect the GCD
    if not gcd_ready() then return end

    -- Branch based on combat state
    if player:in_combat() then
        do_combat(hp, mp)
    else
        do_out_of_combat(hp, mp)
    end
end)

--[[
═══════════════════════════════════════════════════════════════
 QUICK REFERENCE — HOW TO CUSTOMIZE THIS FOR YOUR CLASS
═══════════════════════════════════════════════════════════════

1. FIND YOUR SPELL NAMES:
   - In the Hub, go to Dev Tools → Raw IPC → type SPELLS_ALL
   - Each spell shows: name=InternalName|display=Display Name|cd=...
   - Use the "name=" value in the SPELLS table above

2. FIND YOUR BUFF NAMES:
   - In combat, go to Dev Tools → Raw IPC → type PLAYER_STATUS_EFFECTS
   - Each buff shows: name=InternalName|display=Display Name|stacks=...
   - Use the "name=" value in the BUFFS table above

3. ADD STACK-GATED SPELLS:
   Example — only cast "Spiritburst" when you have 4+ Spirit Link stacks:

       local stacks = get_stacks("SpiritLink")
       if stacks >= 4 then
           if cast("SpiritburstArrow") then return true end
       end

4. ADD BUFF-GATED SPELLS:
   Example — only cast "Envenom" when target has your poison debuff:

       if has_buff("PoisonDebuff") then
           if cast("Envenom") then return true end
       end

5. ADD PROC-BASED SPELLS:
   Example — cast "Execute" only when a proc buff is active:

       if has_buff("ExecuteProc") then
           if cast("Execute") then return true end
       end

6. ADD MULTI-SPELL COMBOS:
   Example — after casting A, immediately queue B:

       if cast("SpellA") then
           state.follow_up = "SpellB"
           return true
       end

7. CHECK BUFF DURATION:
   Example — refresh a buff when it has < 3 seconds remaining:

       local info = get_buff_info("MyBuff")
       if not info or not info.is_active or info.duration < 3.0 then
           if cast("MyBuffSpell") then return true end
       end

8. RESOURCE-GATED SPELLS:
   Example — only use expensive spell above 60% mana:

       if mp > 60 then
           if cast("ExpensiveSpell") then return true end
       end

═══════════════════════════════════════════════════════════════
]]
