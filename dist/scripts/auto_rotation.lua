--[[
╔══════════════════════════════════════════════════════════════╗
║              Auto Rotation — Smart Class Detection            ║
║                                                              ║
║  Detects class from spells, loads the matching build from     ║
║  builds/ folder, and runs a DPS rotation loop.               ║
║  Falls back to a generic rotation if no build found.         ║
╚══════════════════════════════════════════════════════════════╝
]]

local TICK_RATE = 0.3
local DEFENSIVE_HP = 40

local stats = { kills = 0, casts = 0, last_target = "", player_name = "" }
local was_in_combat = false

-- ═══════════════════════════════════════════════════════════
--  CLASS DETECTION — derive class from spells since PLAYER_JOB
--  returns the vocation string which may be "None"
-- ═══════════════════════════════════════════════════════════

local function detect_class()
    local spells_raw = core.spells.all()
    if not spells_raw or spells_raw == "" then return "Unknown" end

    local class_votes = {}
    local spells = core.spells.get_all()
    for _, sp in ipairs(spells) do
        local cat = sp.cat
        if cat and cat ~= "Misc" then
            class_votes[cat] = (class_votes[cat] or 0) + 1
        end
    end

    local best, best_count = "Unknown", 0
    for cls, count in pairs(class_votes) do
        if count > best_count then
            best = cls
            best_count = count
        end
    end
    return best
end

-- ═══════════════════════════════════════════════════════════
--  PLAYER & TARGET NAMES
-- ═══════════════════════════════════════════════════════════

local function get_player_name()
    local data = core.player.get_all()
    if data and data.name then return data.name end
    return "Unknown"
end

local function get_target_name()
    local name = core.targeting.target_name()
    if name and name ~= "" and name ~= "NO_TARGET" then return name end
    return nil
end

-- ═══════════════════════════════════════════════════════════
--  GENERIC ROTATION — sorts spells by CD, casts first ready
-- ═══════════════════════════════════════════════════════════

local all_spells = {}
local buff_spells = {}
local dps_spells = {}

local SKIP_SPELLS = {
    ["Rest"] = true, ["Leyline"] = true, ["Meditate"] = true,
    ["rest"] = true, ["leyline"] = true, ["meditate"] = true,
}

local function load_spells()
    all_spells = core.spells.get_all() or {}
    buff_spells = {}
    dps_spells = {}

    for _, sp in ipairs(all_spells) do
        local name = sp.name or ""
        if SKIP_SPELLS[name] then
            -- never auto-cast these
        else
            local is_self = (sp.self == 1 or sp.self_target == 1)
            if is_self and sp.cd and sp.cd >= 20 then
                buff_spells[#buff_spells + 1] = name
            elseif name ~= "" then
                dps_spells[#dps_spells + 1] = name
            end
        end
    end

    if #dps_spells > 0 then
        print("  DPS spells: " .. table.concat(dps_spells, ", "))
    end
    if #buff_spells > 0 then
        print("  Buff spells: " .. table.concat(buff_spells, ", "))
    end
end

local function try_cast(spell_name)
    if core.spells.is_ready(spell_name) then
        local result = core.spells.cast(spell_name)
        if result and result:find("OK") then
            stats.casts = stats.casts + 1
            return true
        end
    end
    return false
end

local PRIORITY_BUFFS = {
    "Nature Arrows",
}

local function do_priority_buffs()
    for _, name in ipairs(PRIORITY_BUFFS) do
        if not core.buff_manager.has_buff(name) then
            if try_cast(name) then return true end
        end
    end
    return false
end

local function do_buffs()
    if do_priority_buffs() then return true end
    for _, name in ipairs(buff_spells) do
        try_cast(name)
    end
    return false
end

local function do_rotation()
    for _, name in ipairs(dps_spells) do
        if try_cast(name) then return true end
    end
    return false
end

-- Rest/Leyline are NEVER auto-used. Only external scripts may trigger them.

-- ═══════════════════════════════════════════════════════════
--  TRY LOADING BUILD PROFILE
-- ═══════════════════════════════════════════════════════════

local detected_class = detect_class()
stats.player_name = get_player_name()

print(string.format("Player: %s | Detected class: %s", stats.player_name, detected_class))

local build_loaded = false
local build_map = {
    Ranger = "builds/ranger",
    Enchanter = "builds/enchanter",
}

if build_map[detected_class] then
    local ok, mod = pcall(require, build_map[detected_class])
    if ok and mod then
        print("Loaded build profile: " .. detected_class)
        build_loaded = true
    else
        print("Build profile not loaded, using generic rotation")
    end
end

if not build_loaded then
    load_spells()
    print(string.format("Generic rotation loaded — %d DPS spells, %d buffs",
        #dps_spells, #buff_spells))
end

-- If the build profile registers callbacks, it runs via the update loop.
-- If generic, we run our own loop below.

if build_loaded then
    print("DPS Rotation started (build profile) - Tick: " .. TICK_RATE .. "s")
else
    do_buffs()
    print("DPS Rotation started - Tick: " .. TICK_RATE .. "s")

    while not is_stopped() do
        local hp = conn.get_hp()
        local mp = conn.get_mp()
        local in_combat = conn.in_combat()

        if in_combat then
            if not was_in_combat then
                local tgt = get_target_name()
                print(string.format("Combat started! Target: %s", tgt or "(none)"))
                do_buffs()
                was_in_combat = true
            end

            if not conn.has_target() then
                conn.target_nearest()
                local tgt = get_target_name()
                if tgt then
                    stats.last_target = tgt
                end
            end

            if hp < DEFENSIVE_HP and core.spells.is_ready("Linked Rejuvenation") then
                try_cast("Linked Rejuvenation")
            end

            do_rotation()
        else
            if was_in_combat then
                stats.kills = stats.kills + 1
                print(string.format("Kill #%d — %s (Casts: %d)",
                    stats.kills, stats.last_target, stats.casts))
                was_in_combat = false
            end

            do_buffs()
        end

        _ethy_sleep(TICK_RATE)
    end

    print(string.format("Rotation stopped. Player: %s | Kills: %d, Casts: %d",
        stats.player_name, stats.kills, stats.casts))
end
