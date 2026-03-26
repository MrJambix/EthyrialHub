--[[
╔══════════════════════════════════════════════════════════════╗
║               RANGER — Full Spell Rotation                   ║
║                                                              ║
║  Priority (Combat):                                          ║
║    1. Emergency heal  (LinkedRejuvenation @ <30% HP)         ║
║    2. Follow-up combo (Spiritlife after Spiritburst)         ║
║    3. Moderate heal   (LinkedRejuvenation @ <55% HP, 2+ stk)║
║    4. Mana gate       (stop DPS if <15% mana)                ║
║    5. Buff upkeep     (NaturesSwiftness, NatureArrows)       ║
║    6. Pet             (PetAttack + SpiritbeastWrath on CD)   ║
║    7. Spiritburst     (4+ Spirit Link stacks, big hit)       ║
║    8. Verdant Barrage (on CD)                                ║
║    9. Spiritroot DoT  (apply / refresh)                      ║
║   10. Spiritlife      (1+ stacks, spend excess)              ║
║   11. Spirit Shot     (filler, generates stacks)             ║
║                                                              ║
║  Out of Combat:                                              ║
║    - Maintain buffs (NaturesSwiftness, NatureArrows)         ║
║    - Rest / Meditation when low HP or mana                   ║
╚══════════════════════════════════════════════════════════════╝
]]

local ethy = require("common/ethy_sdk")

-- ═══════════════════════════════════════════════════════════════
--  CONFIG
-- ═══════════════════════════════════════════════════════════════

local CONFIG = {
    TICK_RATE       = 0.25,
    TICK_JITTER     = 0.08,
    EMERGENCY_HP    = 30,
    HEAL_HP         = 55,
    MANA_CONSERVE   = 15,
    REST_HP         = 80,
    REST_MP         = 50,
    DOT_DURATION    = 6.0,
    BURST_STACKS    = 4,
    MISPLAY_CHANCE  = 0.02,
}

-- ═══════════════════════════════════════════════════════════════
--  SPELL NAMES
-- ═══════════════════════════════════════════════════════════════

local S = {
    SPIRIT_SHOT       = "SpiritShot",
    SPIRITBEAST_WRATH = "SpiritbeastWrath",
    NATURES_SWIFTNESS = "NaturesSwiftness",
    NATURE_ARROWS     = "NatureArrows",
    SPIRITBURST       = "SpiritburstArrow",
    SPIRITLIFE        = "SpiritlifeArrow",
    VERDANT_BARRAGE   = "VerdantBarrage",
    SPIRITROOT        = "SpiritrootArrow",
    LINKED_REJUV      = "LinkedRejuvenation",
    PET_ATTACK        = "PetAttack",
    REST              = "Rest",
    MEDITATION        = "Meditate",
}

local BUFF = {
    NATURE_ARROWS     = "Nature_Arrows",
    NATURES_SWIFTNESS = "NaturesSwiftness",
    SPIRIT_LINK       = "SpiritLink",
}

-- ═══════════════════════════════════════════════════════════════
--  STATE
-- ═══════════════════════════════════════════════════════════════

local BUFF_COOLDOWN = 3600

local state = {
    last_cast_time = 0,
    last_cast_name = "",
    dot_applied_at = 0,
    follow_up      = nil,
    nature_arrows_cast_at   = 0,
    natures_swift_cast_at   = 0,
}

-- ═══════════════════════════════════════════════════════════════
--  HELPERS
-- ═══════════════════════════════════════════════════════════════

local function cast(spell)
    if not spell or spell == "" then return false end
    if not core.spells.is_ready(spell) then return false end

    if ethy.human.should_misplay(CONFIG.MISPLAY_CHANCE) then
        return false
    end

    local result = core.spells.cast(spell)
    if result and (result:find("OK") or result == "") then
        local jitter = CONFIG.TICK_JITTER * (0.5 + math.random())
        state.last_cast_time = ethy.now() + jitter
        state.last_cast_name = spell
        return true
    end
    return false
end

local _prev_stacks = -1

local function get_stacks()
    local s1 = core.buff_manager.get_spirit_link_stacks()
    local s2 = core.buff_manager.get_stacks("SpiritLink")
    local s3 = core.buff_manager.get_stacks("Spirit Link")
    local s4 = core.buff_manager.get_stacks("SpiritLink_Stacks")

    local best = 0
    if s1 and s1 > best then best = s1 end
    if s2 and s2 > best then best = s2 end
    if s3 and s3 > best then best = s3 end
    if s4 and s4 > best then best = s4 end

    if best ~= _prev_stacks then
        ethy.printf("[Ranger] Spirit Link: %d stacks", best)
        _prev_stacks = best
    end

    return best
end

local function has_buff(name)
    return core.buff_manager.has_buff(name)
end

local function get_buff_remaining(name)
    local data = core.buff_manager.get_buff_data(name)
    if data and data.is_active then return data.remaining or 999 end
    return 0
end

local function dot_needs_refresh()
    if state.dot_applied_at == 0 then return true end
    return ethy.time_since(state.dot_applied_at) > (CONFIG.DOT_DURATION - 1.5)
end

local function gcd_ready()
    local tick = CONFIG.TICK_RATE + (math.random() - 0.5) * CONFIG.TICK_JITTER * 2
    return ethy.time_since(state.last_cast_time) >= tick
end

-- ═══════════════════════════════════════════════════════════════
--  BUFF UPKEEP
-- ═══════════════════════════════════════════════════════════════

local function maintain_buffs()
    local ns_has = has_buff(BUFF.NATURES_SWIFTNESS)
    local ns_cd_ok = (state.natures_swift_cast_at == 0) or (ethy.time_since(state.natures_swift_cast_at) >= BUFF_COOLDOWN)
    if not ns_has and ns_cd_ok then
        if cast(S.NATURES_SWIFTNESS) then
            state.natures_swift_cast_at = ethy.now()
            return true
        end
    end

    local na_has = has_buff(BUFF.NATURE_ARROWS)
    local na_cd_ok = (state.nature_arrows_cast_at == 0) or (ethy.time_since(state.nature_arrows_cast_at) >= BUFF_COOLDOWN)

    if not na_has and na_cd_ok then
        if cast(S.NATURE_ARROWS) then
            state.nature_arrows_cast_at = ethy.now()
            return true
        end
    end

    return false
end

-- ═══════════════════════════════════════════════════════════════
--  COMBAT ROTATION
-- ═══════════════════════════════════════════════════════════════

local function do_combat(hp, mp)
    local stacks = _prev_stacks >= 0 and _prev_stacks or get_stacks()

    -- P1: Emergency heal
    if hp < CONFIG.EMERGENCY_HP then
        if cast(S.LINKED_REJUV) then return true end
    end

    -- P2: Follow-up combo (Spiritburst -> Spiritlife)
    if state.follow_up then
        local spell = state.follow_up
        state.follow_up = nil
        if cast(spell) then return true end
    end

    -- P3: Moderate heal when stacks available
    if hp < CONFIG.HEAL_HP and stacks >= 2 then
        if cast(S.LINKED_REJUV) then return true end
    end

    -- P4: Mana conservation
    if mp < CONFIG.MANA_CONSERVE then
        ethy.print("[Ranger] Low mana — conserving")
        return false
    end

    -- P5: Buff upkeep mid-combat
    if maintain_buffs() then return true end

    -- P6: Pet — fire and forget + Spiritbeast's Wrath
    cast(S.PET_ATTACK)
    if cast(S.SPIRITBEAST_WRATH) then return true end

    -- P7: Spiritburst at 4+ stacks -> queue Spiritlife
    if stacks >= CONFIG.BURST_STACKS then
        if cast(S.SPIRITBURST) then
            state.follow_up = S.SPIRITLIFE
            return true
        end
    end

    -- P8: Verdant Barrage on CD
    if cast(S.VERDANT_BARRAGE) then return true end

    -- P9: Spiritroot DoT — apply / refresh
    if dot_needs_refresh() then
        if cast(S.SPIRITROOT) then
            state.dot_applied_at = ethy.now()
            return true
        end
    end

    -- P10: Spiritlife — spend excess stacks
    if stacks >= 1 then
        if cast(S.SPIRITLIFE) then return true end
    end

    -- P11: Spirit Shot filler (generates stacks)
    if cast(S.SPIRIT_SHOT) then return true end

    return false
end

-- ═══════════════════════════════════════════════════════════════
--  OUT-OF-COMBAT
-- ═══════════════════════════════════════════════════════════════

local function do_out_of_combat(hp, mp)
    if maintain_buffs() then return true end

    if hp < CONFIG.REST_HP or mp < CONFIG.REST_MP then
        if mp < CONFIG.REST_MP then
            if cast(S.MEDITATION) then return true end
        end
        if cast(S.REST) then return true end
    end

    return false
end

-- ═══════════════════════════════════════════════════════════════
--  EVENT HOOKS
-- ═══════════════════════════════════════════════════════════════

ethy.on_combat_enter(function()
    state.follow_up      = nil
    state.dot_applied_at = 0
    ethy.print("[Ranger] === COMBAT ===")
end)

ethy.on_combat_leave(function()
    state.follow_up = nil
    ethy.print("[Ranger] === OUT OF COMBAT ===")
end)

-- ═══════════════════════════════════════════════════════════════
--  MAIN LOOP
-- ═══════════════════════════════════════════════════════════════

ethy.print("╔══════════════════════════════════════════════════════════╗")
ethy.print("║  Ranger Rotation Loaded                                  ║")
ethy.print("║  DPS : SpiritShot > VerdantBarrage > Spiritburst >       ║")
ethy.print("║        Spiritlife > SpiritrootArrow                      ║")
ethy.print("║  Pet : PetAttack + SpiritbeastWrath                      ║")
ethy.print("║  Buff: NaturesSwiftness + NatureArrows                   ║")
ethy.print("║  Heal: LinkedRejuvenation                                ║")
ethy.print("╚══════════════════════════════════════════════════════════╝")

ethy.on_update(function()
    local player = ethy.get_player()
    if not player then return end
    if player:is_dead() or player:is_frozen() then return end

    local hp = player:get_health_percent()
    local mp = player:get_mana_percent()
    if hp <= 0 then return end

    get_stacks()

    if not gcd_ready() then return end

    if player:in_combat() then
        do_combat(hp, mp)
    else
        do_out_of_combat(hp, mp)
    end
end)
