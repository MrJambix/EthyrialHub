--[[
╔══════════════════════════════════════════════════════════════╗
║               RANGER — Full Spell Rotation                   ║
║                                                              ║
║  Uses EVERY ranger spell aggressively. No Rest/Leyline.      ║
║  Spirit Link stacks gate some spells but the rotation        ║
║  always has something to cast — never just Spirit Shot.      ║
║                                                              ║
║  Priority:                                                   ║
║    1. Emergency heal (Linked Rejuvenation)                   ║
║    2. Buff upkeep (Nature's Swiftness, Nature Arrows)        ║
║    3. Follow-up after Spiritburst → Spiritlife               ║
║    4. Spiritbeast's Wrath (pet, use on CD)                   ║
║    5. Spiritburst Arrow (4+ stacks, big hit)                 ║
║    6. Verdant Barrage (on CD)                                ║
║    7. Spiritroot Arrow (DoT, keep applied)                   ║
║    8. Spiritlife Arrow (stack spender)                       ║
║    9. Spirit Shot (filler, generates stacks)                 ║
╚══════════════════════════════════════════════════════════════╝
]]

local ethy = require("common/ethy_sdk")

-- ═══════════════════════════════════════════════════════════════
--  CONFIG
-- ═══════════════════════════════════════════════════════════════

local HEAL_HP       = 60
local EMERGENCY_HP  = 35
local TICK_RATE     = 0.3

local SPIRIT_LINK_BUFF = "SpiritLink"

-- ═══════════════════════════════════════════════════════════════
--  SPELL NAMES (edit these if your spell names differ)
-- ═══════════════════════════════════════════════════════════════

local SPELLS = {
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
}

-- ═══════════════════════════════════════════════════════════════
--  STATE
-- ═══════════════════════════════════════════════════════════════

local pending_follow_up = nil
local last_cast_time    = 0
local last_cast_name    = ""
local dot_applied_at    = 0
local DOT_DURATION      = 6.0

-- #region agent log
local _DBG_LOG = [[C:\Users\mrjam\OneDrive\Desktop\EthyrialInjector\EthyTool\debug-3fd161.log]]
local _dbg_tick = 0
local function _dbg(hid, msg, data)
    local parts = {}
    if data then
        for k, v in pairs(data) do
            local val = type(v) == "string" and ('"' .. v .. '"') or tostring(v)
            parts[#parts + 1] = string.format('"%s":%s', k, val)
        end
    end
    local json_data = "{" .. table.concat(parts, ",") .. "}"
    local line = string.format(
        '{"sessionId":"3fd161","hypothesisId":"%s","location":"ranger.lua","message":"%s","data":%s,"timestamp":%d}\n',
        hid, msg, json_data, (os.time or function() return 0 end)() * 1000)
    pcall(function()
        local f = io.open(_DBG_LOG, "a")
        if f then f:write(line); f:close() end
    end)
    ethy.printf("[DBG:%s] %s %s", hid, msg, json_data)
end
-- #endregion

-- ═══════════════════════════════════════════════════════════════
--  HELPERS
-- ═══════════════════════════════════════════════════════════════

local function cast(spell)
    if not spell or spell == "" then return false end
    local ready = core.spells.is_ready(spell)
    if not ready then return false end
    local result = core.spells.cast(spell)
    if result and (result:find("OK") or result == "") then
        last_cast_time = ethy.now()
        last_cast_name = spell
        ethy.printf("[Ranger] %s", spell)
        return true
    end
    return false
end

local function get_stacks()
    local s = ethy.buff_manager.get_stacks(SPIRIT_LINK_BUFF)
    if s and s > 0 then return s end
    local s2 = ethy.buff_manager.get_stacks("Spirit Link")
    if s2 and s2 > 0 then return s2 end
    local s3 = ethy.buff_manager.get_stacks("SpiritLink_Stacks")
    if s3 and s3 > 0 then return s3 end
    return s or 0
end

local _buffs_raw = ""

local function refresh_buffs()
    _buffs_raw = core.player.buffs() or ""
end

local _buffs_raw_logged = false

local function has_buff(name)
    if not _buffs_raw or _buffs_raw == "" or _buffs_raw == "NONE" then
        return false
    end
    -- #region agent log
    if not _buffs_raw_logged and #_buffs_raw > 100 then
        _buffs_raw_logged = true
        local snippet = _buffs_raw:sub(1, 400):gsub('"', "'")
        _dbg("RAW", "PLAYER_BUFFS pipe dump", {raw=snippet, raw_len=tostring(#_buffs_raw)})
    end
    -- #endregion
    local found = (_buffs_raw:find("name=" .. name, 1, true) ~= nil)
                or (_buffs_raw:find("disp=" .. name, 1, true) ~= nil)
    return found
end

local function dot_needs_refresh()
    if dot_applied_at == 0 then return true end
    return ethy.time_since(dot_applied_at) > (DOT_DURATION - 1.5)
end

-- ═══════════════════════════════════════════════════════════════
--  ROTATION
-- ═══════════════════════════════════════════════════════════════

local function do_combat(hp)
    local stacks = get_stacks()

    -- 1. Emergency heal
    if hp < EMERGENCY_HP and cast(SPELLS.LINKED_REJUV) then
        return true
    end

    -- 2. Follow-up: Spiritburst -> Spiritlife
    if pending_follow_up then
        local spell = pending_follow_up
        pending_follow_up = nil
        if cast(spell) then return true end
    end

    -- 3. Heal at moderate HP if we have stacks
    if hp < HEAL_HP and stacks >= 2 and cast(SPELLS.LINKED_REJUV) then
        return true
    end

    -- 4. Pet attack command (1s CD, free) + Spiritbeast's Wrath (30s CD, damage)
    cast(SPELLS.PET_ATTACK)
    if cast(SPELLS.SPIRITBEAST_WRATH) then
        return true
    end

    -- 5. Big spender: Spiritburst at 4+ stacks -> queue Spiritlife
    if stacks >= 4 then
        if cast(SPELLS.SPIRITBURST) then
            pending_follow_up = SPELLS.SPIRITLIFE
            ethy.printf("[Ranger] -> queued %s", SPELLS.SPIRITLIFE)
            return true
        end
    end

    -- 6. Verdant Barrage — strong on-CD ability
    if cast(SPELLS.VERDANT_BARRAGE) then
        return true
    end

    -- 7. Spiritroot Arrow — DoT, apply/refresh when needed
    if dot_needs_refresh() then
        if cast(SPELLS.SPIRITROOT) then
            dot_applied_at = ethy.now()
            return true
        end
    end

    -- 8. Spiritlife Arrow — spend stacks
    if stacks >= 1 and cast(SPELLS.SPIRITLIFE) then
        return true
    end

    -- 9. Filler: Spirit Shot (generates stacks)
    if cast(SPELLS.SPIRIT_SHOT) then
        return true
    end

    return false
end

local function do_buffs_ooc()
    refresh_buffs()
    if not has_buff(SPELLS.NATURES_SWIFTNESS) and not has_buff("Nature's Swiftness") then
        if cast(SPELLS.NATURES_SWIFTNESS) then return true end
    end
    if not has_buff("Nature_Arrows") and not has_buff("Nature Arrows") then
        if cast(SPELLS.NATURE_ARROWS) then return true end
    end
    return false
end

local function do_buffs_combat()
    refresh_buffs()
    -- #region agent log
    _dbg("D", "do_buffs_combat called", {})
    -- #endregion
    if not has_buff(SPELLS.NATURES_SWIFTNESS) and not has_buff("Nature's Swiftness") then
        if cast(SPELLS.NATURES_SWIFTNESS) then return true end
    end
    if not has_buff("Nature_Arrows") and not has_buff("Nature Arrows") then
        if cast(SPELLS.NATURE_ARROWS) then return true end
    end
    return false
end

-- ═══════════════════════════════════════════════════════════════
--  MAIN LOOP
-- ═══════════════════════════════════════════════════════════════

ethy.print("[Ranger] Full rotation loaded (internal names from dump)")
ethy.print("[Ranger] DPS: SpiritShot, VerdantBarrage, SpiritburstArrow, SpiritlifeArrow, SpiritrootArrow")
ethy.print("[Ranger] Pet: PetAttack, SpiritbeastWrath")
ethy.print("[Ranger] Buff: NaturesSwiftness, NatureArrows")
ethy.print("[Ranger] Heal: LinkedRejuvenation")
ethy.print("[Ranger] Rest/Leyline: DISABLED")

ethy.on_combat_enter(function()
    pending_follow_up = nil
    dot_applied_at = 0
    ethy.print("[Ranger] Combat! Resetting rotation state")
end)

ethy.on_combat_leave(function()
    pending_follow_up = nil
    ethy.print("[Ranger] Combat over")
end)

ethy.on_update(function()
    local player = ethy.get_player()
    if not player then return end
    if player:is_dead() or player:is_frozen() then return end

    local hp = player:get_health_percent()
    if hp <= 0 then return end

    -- #region agent log
    _dbg_tick = _dbg_tick + 1
    if _dbg_tick % 50 == 1 then
        local all = core.buff_manager.get_all_buffs()
        if all then
            local names = {}
            for i, b in ipairs(all) do
                names[#names + 1] = string.format("%s(id=%s,stk=%s)", tostring(b.name or b.display_name or "?"), tostring(b.id or "?"), tostring(b.stacks or 0))
            end
            _dbg("A", "all_active_buffs", {count=tostring(#all), buffs=table.concat(names, "; ")})
        else
            _dbg("A", "all_active_buffs", {count="nil"})
        end
        local d1 = ethy.buff_manager.get_buff_data("Nature_Arrows")
        local d2 = ethy.buff_manager.get_buff_data("NatureArrows")
        local d3 = ethy.buff_manager.get_buff_data("Nature Arrows")
        _dbg("A", "buff_name_test", {
            Nature_Arrows = tostring(d1 and d1.is_active),
            NatureArrows = tostring(d2 and d2.is_active),
            NatureSpace = tostring(d3 and d3.is_active),
        })
    end
    -- #endregion

    if not player:in_combat() then
        do_buffs_ooc()
        return
    end

    if ethy.time_since(last_cast_time) < TICK_RATE then return end

    if do_buffs_combat() then return end
    do_combat(hp)
end)
