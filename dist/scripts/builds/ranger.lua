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
    EMERGENCY_HP    = 30,
    HEAL_HP         = 55,
    MANA_CONSERVE   = 15,
    REST_HP         = 80,
    REST_MP         = 50,
    DOT_DURATION    = 6.0,
    BURST_STACKS    = 4,
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
    MEDITATION        = "LeylineMeditation",
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

-- #region agent log
local _LOGPATH = [[C:\Users\mrjam\OneDrive\Desktop\EthyrialInjector\debug-11adf5.log]]
local function _dbglog(hyp, msg, data)
    local parts = {}
    if data then
        for k, v in pairs(data) do
            parts[#parts+1] = string.format('%s=%s', tostring(k), tostring(v))
        end
    end
    local summary = string.format("[DBG:%s] %s {%s}", hyp, msg, table.concat(parts, ", "))
    ethy.print(summary)
    local jparts = {}
    if data then
        for k, v in pairs(data) do
            jparts[#jparts+1] = string.format('"%s":%s', tostring(k),
                type(v) == "string" and ('"'..v:gsub('"','\\"')..'"') or tostring(v))
        end
    end
    local line = string.format(
        '{"sessionId":"11adf5","hypothesisId":"%s","location":"ranger.lua","message":"%s","data":{%s},"timestamp":%d}\n',
        hyp, msg, table.concat(jparts,","), (os.time or function() return 0 end)() * 1000)
    pcall(function() local f = io.open(_LOGPATH,"a"); if f then f:write(line); f:close() end end)
end
-- #endregion

-- ═══════════════════════════════════════════════════════════════
--  HELPERS
-- ═══════════════════════════════════════════════════════════════

local function cast(spell)
    if not spell or spell == "" then return false end
    if not core.spells.is_ready(spell) then return false end

    local result = core.spells.cast(spell)
    if result and (result:find("OK") or result == "") then
        state.last_cast_time = ethy.now()
        state.last_cast_name = spell
        ethy.printf("[Ranger] %s", spell)
        return true
    end
    return false
end

local _prev_stacks = -1
local _stk_dbg_tick = 0

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

    -- #region agent log
    _stk_dbg_tick = _stk_dbg_tick + 1
    if _stk_dbg_tick <= 3 or best ~= _prev_stacks then
        _dbglog("F", "spirit_link_stacks", {
            api_shortcut = tostring(s1), type_s1 = type(s1),
            SpiritLink = tostring(s2), type_s2 = type(s2),
            Spirit_Link_space = tostring(s3), type_s3 = type(s3),
            SpiritLink_Stacks = tostring(s4), type_s4 = type(s4),
            best = tostring(best),
        })
    end
    -- #endregion

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
    return ethy.time_since(state.last_cast_time) >= CONFIG.TICK_RATE
end

-- ═══════════════════════════════════════════════════════════════
--  BUFF UPKEEP
-- ═══════════════════════════════════════════════════════════════

-- #region agent log
local _na_dbg_count = 0
-- #endregion

local function maintain_buffs()
    -- NaturesSwiftness: check BUFF name + 60-min internal CD
    local ns_has = has_buff(BUFF.NATURES_SWIFTNESS)
    local ns_cd_ok = (state.natures_swift_cast_at == 0) or (ethy.time_since(state.natures_swift_cast_at) >= BUFF_COOLDOWN)
    if not ns_has and ns_cd_ok then
        if cast(S.NATURES_SWIFTNESS) then
            state.natures_swift_cast_at = ethy.now()
            return true
        end
    end

    -- NatureArrows: check BUFF name "Nature_Arrows" + 60-min internal CD
    local na_has = has_buff(BUFF.NATURE_ARROWS)
    local na_cd_ok = (state.nature_arrows_cast_at == 0) or (ethy.time_since(state.nature_arrows_cast_at) >= BUFF_COOLDOWN)

    -- #region agent log
    _na_dbg_count = _na_dbg_count + 1
    if _na_dbg_count <= 5 then
        _dbglog("A", "NatureArrows_buff_check_FIXED", {
            has_Nature_Arrows = tostring(na_has),
            type_has = type(na_has),
            cd_ok = tostring(na_cd_ok),
            will_cast = tostring(not na_has and na_cd_ok),
        })
    end
    -- #endregion

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

-- #region agent log
local _dbg_dump_tick = 0
-- #endregion

ethy.on_update(function()
    local player = ethy.get_player()
    if not player then return end
    if player:is_dead() or player:is_frozen() then return end

    local hp = player:get_health_percent()
    local mp = player:get_mana_percent()
    if hp <= 0 then return end

    -- Monitor stacks continuously (before GCD gate)
    get_stacks()

    -- #region agent log
    _dbg_dump_tick = _dbg_dump_tick + 1
    if _dbg_dump_tick == 1 or _dbg_dump_tick % 200 == 0 then
        local all = core.buff_manager.get_all_buffs()
        if all then
            local names = {}
            for _, b in ipairs(all) do
                names[#names+1] = string.format("%s/%s(stk=%s,rem=%s)",
                    tostring(b.name or "?"), tostring(b.display_name or "?"),
                    tostring(b.stacks or 0), tostring(b.remaining or "?"))
            end
            _dbglog("B", "ALL_ACTIVE_BUFFS", {count = tostring(#all), buffs = table.concat(names, "; ")})
        else
            _dbglog("B", "ALL_ACTIVE_BUFFS", {count = "nil"})
        end
    end
    -- #endregion

    if not gcd_ready() then return end

    if player:in_combat() then
        do_combat(hp, mp)
    else
        do_out_of_combat(hp, mp)
    end
end)
