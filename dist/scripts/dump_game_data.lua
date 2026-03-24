--[[
╔══════════════════════════════════════════════════════════════════════╗
║           Dump Game Data — ALL Spells, Buffs & Debuffs              ║
║                                                                      ║
║  Deep IL2CPP reflection scan that dumps every spell definition,      ║
║  status effect (buff/debuff), talent, and skill the game has.        ║
║                                                                      ║
║  Writes output to:  dist/scripts/game_data_dump.txt                  ║
║  Only phase progress is shown in the Hub log to avoid crashes.       ║
╚══════════════════════════════════════════════════════════════════════╝
]]

local cmd = conn.send_command

-- ═══════════════════════════════════════════════════════════════
-- File output — all dump data goes here, NOT to print()
-- ═══════════════════════════════════════════════════════════════

local script_dir = ""
do
    local info = debug.getinfo(1, "S")
    if info and info.source then
        local src = info.source:gsub("^@", "")
        script_dir = src:match("^(.*)[/\\]") or "."
    end
end

local out_path = script_dir .. "/game_data_dump.txt"
local file = io.open(out_path, "w")
if not file then
    out_path = "game_data_dump.txt"
    file = io.open(out_path, "w")
end
if not file then
    print("[ERROR] Cannot open output file. Check write permissions.")
    return
end

local line_count = 0
local stats = { sections = 0, items = 0, classes_found = 0, errors = 0 }

local function W(text)
    file:write(text .. "\n")
    line_count = line_count + 1
    if line_count % 500 == 0 then
        file:flush()
    end
end

local function banner(title)
    stats.sections = stats.sections + 1
    W("")
    W("╔══════════════════════════════════════════════════════════════╗")
    W("║  " .. title .. string.rep(" ", 60 - #title) .. "║")
    W("╚══════════════════════════════════════════════════════════════╝")
    print("[Dump] " .. title)
end

local function section(title)
    stats.sections = stats.sections + 1
    W("")
    W("── " .. title .. " " .. string.rep("─", 58 - #title))
end

local function safe_cmd(command)
    local ok, result = pcall(cmd, command)
    if not ok then
        stats.errors = stats.errors + 1
        return nil
    end
    if not result or result == "" or result == "NONE" or result == "EMPTY"
       or result == "NOT_FOUND" or result == "UNKNOWN_CMD" then
        return nil
    end
    if result:sub(1, 4) == "ERR:" or result:sub(1, 4) == "ERR|" then
        return nil
    end
    return result
end

local function write_entries(raw, delimiter)
    delimiter = delimiter or "#"
    if not raw then W("  (no data)"); return 0 end
    local count = 0
    for entry in raw:gmatch("[^" .. delimiter .. "]+") do
        entry = entry:match("^%s*(.-)%s*$")
        if entry ~= "" and not entry:match("^count=") and not entry:match("^fallback=") then
            count = count + 1
            stats.items = stats.items + 1
            W("  [" .. count .. "] " .. entry)
        end
    end
    return count
end

local function write_class_dump(class_name)
    local full = safe_cmd("DUMP_CLASS_FULL " .. class_name)
    if not full then
        W("  (class not found: " .. class_name .. ")")
        return false
    end
    stats.classes_found = stats.classes_found + 1

    local fields_part = full:match("FIELDS###(.-)METHODS###") or full:match("FIELDS###(.+)$") or ""
    local methods_part = full:match("METHODS###(.+)$") or ""

    if fields_part ~= "" then
        W("  FIELDS:")
        for f in fields_part:gmatch("[^|]+") do
            f = f:match("^%s*(.-)%s*$")
            if f ~= "" then W("    " .. f) end
        end
    end
    if methods_part ~= "" then
        W("  METHODS:")
        for m in methods_part:gmatch("[^|]+") do
            m = m:match("^%s*(.-)%s*$")
            if m ~= "" then W("    " .. m) end
        end
    end
    if fields_part == "" and methods_part == "" then
        W("  " .. full:sub(1, 800))
        if #full > 800 then W("  ... (" .. #full .. " chars)") end
    end
    return true
end

-- ═══════════════════════════════════════════════════════════════
-- 0. Preflight
-- ═══════════════════════════════════════════════════════════════

print("[Dump] Writing to: " .. out_path)

banner("GAME DATA DUMP — Spells / Buffs / Debuffs")
W("Output file: " .. out_path)
W("Time: " .. os.date("%Y-%m-%d %H:%M:%S"))
W("")

local ping = safe_cmd("PING")
if ping ~= "PONG" then
    W("[ERROR] Not connected to game.")
    print("[ERROR] Not connected. Connect first.")
    file:close()
    return
end
W("[OK] Connected to game")
W("[OK] Job: " .. (safe_cmd("PLAYER_JOB") or "unknown"))

-- ═══════════════════════════════════════════════════════════════
-- 1. Build class cache
-- ═══════════════════════════════════════════════════════════════

banner("PHASE 1 — Building IL2CPP Class Cache")

local cache_result = safe_cmd("CACHE_ALL_CLASSES")
W("  Cache result: " .. (cache_result or "(no response)"))

local cache_size = safe_cmd("CLASS_CACHE_SIZE")
W("  Cache size: " .. (cache_size or "0") .. " classes")
_ethy_sleep(0.5)

-- ═══════════════════════════════════════════════════════════════
-- 2. Discover spell/buff/effect classes
-- ═══════════════════════════════════════════════════════════════

banner("PHASE 2 — Discovering Spell/Buff/Effect Classes")

local search_terms = {
    "Spell", "Buff", "Debuff", "StatusEffect", "Effect",
    "Ability", "Talent", "Skill", "Aura", "Passive",
    "Cooldown", "Cast", "Projectile", "Damage", "Heal",
    "Combat", "Battle", "Action", "Power",
}

local discovered_classes = {}
local seen = {}

for _, term in ipairs(search_terms) do
    local result = safe_cmd("LIST_CACHED_CLASSES " .. term)
    if result then
        local count = 0
        for cls in result:gmatch("[^|,\n]+") do
            cls = cls:match("^%s*(.-)%s*$")
            if cls ~= "" and not seen[cls] then
                seen[cls] = true
                discovered_classes[#discovered_classes + 1] = cls
                count = count + 1
            end
        end
        if count > 0 then
            W("  '" .. term .. "' -> " .. count .. " classes")
        end
    end
    if is_stopped() then break end
end

table.sort(discovered_classes)
W("")
W("Total unique classes discovered: " .. #discovered_classes)
for i, cls in ipairs(discovered_classes) do
    W("  [" .. i .. "] " .. cls)
end

-- ═══════════════════════════════════════════════════════════════
-- 3. Core combat class definitions
-- ═══════════════════════════════════════════════════════════════

banner("PHASE 3 — Core Combat Class Definitions")

local core_classes = {
    "Spell", "SpellSlot", "StatusEffect",
    "Projectile", "ProjectileTarget",
    "DamageInfo", "BattleUtility", "BattleUtility_Field",
    "Effects", "EffectScript",
    "SkillProgression", "ActiveTalent", "TalentInfo",
    "PlayerEntityInformation",
    "StatusEffectTrackerWindow",
    "ProjectileCollisionBehaviour",
}

for _, cls in ipairs(core_classes) do
    section(cls)
    write_class_dump(cls)
    _ethy_sleep(0.1)
    if is_stopped() then break end
end

local extra_classes = {}
for _, cls in ipairs(discovered_classes) do
    local dominated = false
    for _, core in ipairs(core_classes) do
        if cls == core then dominated = true; break end
    end
    if not dominated then
        extra_classes[#extra_classes + 1] = cls
    end
end

if #extra_classes > 0 then
    banner("PHASE 3b — Additional Discovered Classes")
    for _, cls in ipairs(extra_classes) do
        section(cls)
        write_class_dump(cls)
        _ethy_sleep(0.05)
        if is_stopped() then break end
    end
end

-- ═══════════════════════════════════════════════════════════════
-- 4. Player spells
-- ═══════════════════════════════════════════════════════════════

banner("PHASE 4 — Player's Spell Book")

section("Raw Spell List")
local spells_raw = safe_cmd("SPELLS_ALL")
local spell_count = write_entries(spells_raw, "#")
W("  Total spells in spell book: " .. spell_count)

section("Per-Spell Detail")
if spells_raw then
    local spell_names = {}
    for entry in spells_raw:gmatch("[^#]+") do
        local name = entry:match("name=([^|]+)")
        if name and name ~= "" then
            spell_names[#spell_names + 1] = name
        end
    end

    for i, sname in ipairs(spell_names) do
        local info = safe_cmd("SPELL_INFO " .. sname)
        local ready = safe_cmd("SPELL_READY " .. sname)
        local cd = safe_cmd("SPELL_CD " .. sname)
        W(string.format("  [%d] %s", i, sname))
        W(string.format("       Ready: %s  |  CD: %s", ready or "?", cd or "0"))
        if info then W("       Info: " .. info) end
        stats.items = stats.items + 1
        _ethy_sleep(0.05)
        if is_stopped() then break end
    end
    W("  Total detailed spells: " .. #spell_names)
end

-- ═══════════════════════════════════════════════════════════════
-- 5. Player buffs/debuffs
-- ═══════════════════════════════════════════════════════════════

banner("PHASE 5 — Player Buffs & Debuffs")

section("Raw Buff List")
local buffs_raw = safe_cmd("PLAYER_BUFFS")
local buff_count = write_entries(buffs_raw, "#")
W("  Total active buffs: " .. buff_count)

section("Buff Stacks")
local stacks_raw = safe_cmd("PLAYER_STACKS")
if stacks_raw then W("  " .. stacks_raw) end

section("Well-Known Buff Status Check")
local known_buffs = {
    "Fury", "SpiritLink", "Rage", "Stealth", "Shield",
    "Blessing", "Poison", "Bleed", "Stun", "Root",
    "Silence", "Fear", "Slow", "Haste", "Regen",
    "Barrier", "Thorns", "Reflect", "Immunity", "Invulnerable",
    "Nature_Arrows", "Fire_Arrows", "Ice_Arrows", "Lightning_Arrows",
    "Bloodlust", "Enrage", "Fortify", "Empower", "Weaken",
    "Vulnerable", "Blind", "Charm", "Confusion", "Daze",
    "Mark", "Taunt", "Provoke", "HolyShield", "ManaShield",
    "DarkPact", "SoulLink", "BeastWithin", "NaturesGrace",
}

local found_buffs = 0
for _, bname in ipairs(known_buffs) do
    local stacks = safe_cmd("BUFF_STACKS " .. bname)
    if stacks and stacks ~= "0" and stacks ~= "" then
        found_buffs = found_buffs + 1
        W(string.format("  [ACTIVE] %-25s stacks=%s", bname, stacks))
    end
end
W("  Known buffs currently active: " .. found_buffs .. " / " .. #known_buffs .. " checked")

-- ═══════════════════════════════════════════════════════════════
-- 6. Skills & talents
-- ═══════════════════════════════════════════════════════════════

banner("PHASE 6 — Skills & Talents")

section("Skills")
local skills_raw = safe_cmd("PLAYER_SKILLS")
local skill_count = write_entries(skills_raw, "#")
W("  Total skills: " .. skill_count)

section("Talents")
local talents_raw = safe_cmd("PLAYER_TALENTS")
local talent_count = write_entries(talents_raw, "#")
W("  Total talents: " .. talent_count)

-- ═══════════════════════════════════════════════════════════════
-- 7. Monsterdex
-- ═══════════════════════════════════════════════════════════════

banner("PHASE 7 — MonsterDex (Enemy Abilities)")

section("Full MonsterDex Scan")
local mdex_scan = safe_cmd("MONSTERDEX_SCAN")
local mdex_count = 0

if mdex_scan then
    for entry in mdex_scan:gmatch("[^#]+") do
        entry = entry:match("^%s*(.-)%s*$")
        if entry ~= "" and not entry:match("^count=") then
            mdex_count = mdex_count + 1
            stats.items = stats.items + 1
            W("  [" .. mdex_count .. "] " .. entry)
        end
    end
end
W("  Total monsterdex entries: " .. mdex_count)

section("Nearby Monster Data")
local mdex_nearby = safe_cmd("MONSTERDEX_NEARBY")
local nearby_count = write_entries(mdex_nearby, "#")
W("  Nearby monsters with dex data: " .. nearby_count)

section("Monster Spells/Abilities (from nearby)")
if mdex_nearby then
    local nearby_uids = {}
    for entry in mdex_nearby:gmatch("[^#]+") do
        local uid = entry:match("uid=(%d+)")
        if uid then nearby_uids[#nearby_uids + 1] = uid end
    end

    local total_monster_spells = 0
    for _, uid in ipairs(nearby_uids) do
        local spells = safe_cmd("MONSTERDEX_SPELLS " .. uid)
        if spells and spells ~= "NONE" and spells ~= "" then
            local name = "uid=" .. uid
            for entry in mdex_nearby:gmatch("[^#]+") do
                if entry:find("uid=" .. uid) then
                    local n = entry:match("name=([^|]+)")
                    if n then name = n end
                    break
                end
            end
            W("  " .. name .. ":")
            for spell_entry in spells:gmatch("[^#]+") do
                spell_entry = spell_entry:match("^%s*(.-)%s*$")
                if spell_entry ~= "" and not spell_entry:match("^count=") then
                    total_monster_spells = total_monster_spells + 1
                    stats.items = stats.items + 1
                    W("    * " .. spell_entry)
                end
            end
        end
        _ethy_sleep(0.05)
        if is_stopped() then break end
    end
    W("  Total monster spells discovered: " .. total_monster_spells)
end

section("Current Target MonsterDex")
local tgt_mdex = safe_cmd("MONSTERDEX_TARGET")
if tgt_mdex then
    W("  " .. tgt_mdex)
    local tgt_uid = tgt_mdex:match("uid=(%d+)")
    if tgt_uid then
        local tgt_spells = safe_cmd("MONSTERDEX_SPELLS " .. tgt_uid)
        if tgt_spells then
            W("  Target's spells:")
            write_entries(tgt_spells, "#")
        end
    end
else
    W("  (no target)")
end

-- ═══════════════════════════════════════════════════════════════
-- 8. Scene entities
-- ═══════════════════════════════════════════════════════════════

banner("PHASE 8 — Scene Entity Scan")

section("All Nearby Living Entities")
local nearby_living = safe_cmd("NEARBY_LIVING")
local living_count = write_entries(nearby_living, "#")
W("  Living entities nearby: " .. living_count)

section("Scene Entity Count")
W("  Scene total: " .. (safe_cmd("SCENE_COUNT") or "?"))
W("  Nearby total: " .. (safe_cmd("NEARBY_COUNT") or "?"))

-- ═══════════════════════════════════════════════════════════════
-- 9. IL2CPP deep reflection
-- ═══════════════════════════════════════════════════════════════

banner("PHASE 9 — IL2CPP Deep Reflection")

section("Loaded Assemblies")
local assemblies = safe_cmd("DUMP_ASSEMBLIES")
if assemblies then
    for asm in assemblies:gmatch("[^|,\n]+") do
        asm = asm:match("^%s*(.-)%s*$")
        if asm ~= "" then W("  " .. asm) end
    end
end

section("Singletons")
local singletons = safe_cmd("DUMP_SINGLETONS")
if singletons then
    for s in singletons:gmatch("[^|,\n]+") do
        s = s:match("^%s*(.-)%s*$")
        if s ~= "" then W("  " .. s) end
    end
end

section("Game Assembly Classes (spell/buff related)")
local game_assemblies = { "Game.dll", "Assembly-CSharp.dll", "RPGLibrary.dll" }
for _, asm_name in ipairs(game_assemblies) do
    W("")
    W("  Assembly: " .. asm_name)
    local classes = safe_cmd("DUMP_IMAGE_CLASSES " .. asm_name)
    if classes then
        local relevant = {}
        for cls in classes:gmatch("[^|,\n]+") do
            cls = cls:match("^%s*(.-)%s*$")
            local lower = cls:lower()
            if lower:find("spell") or lower:find("buff") or lower:find("debuff")
               or lower:find("effect") or lower:find("aura") or lower:find("talent")
               or lower:find("skill") or lower:find("ability") or lower:find("passive")
               or lower:find("combat") or lower:find("damage") or lower:find("heal")
               or lower:find("cast") or lower:find("cooldown") or lower:find("projectile")
               or lower:find("status") or lower:find("condition") then
                relevant[#relevant + 1] = cls
            end
        end
        table.sort(relevant)
        if #relevant > 0 then
            for _, cls in ipairs(relevant) do W("    " .. cls) end
            W("    (" .. #relevant .. " relevant classes)")
        else
            W("    (no spell/buff classes in this assembly)")
        end
    else
        W("    (assembly not found)")
    end
    _ethy_sleep(0.2)
    if is_stopped() then break end
end

-- ═══════════════════════════════════════════════════════════════
-- 10. Deep class field/method dumps
-- ═══════════════════════════════════════════════════════════════

banner("PHASE 10 — Full Field/Method Dumps")

local deep_dump_classes = {
    "Spell", "SpellSlot", "StatusEffect",
    "LivingEntity", "LocalPlayerEntity", "PlayerEntity",
    "Entity", "EntityManager", "EntityModel",
    "SkillProgression", "ActiveTalent", "TalentInfo",
    "DamageInfo", "BattleUtility",
    "Projectile", "Effects", "EffectScript",
    "QuickBar", "QuickSlot",
}

for _, cls in ipairs(deep_dump_classes) do
    section("DUMP: " .. cls)

    W("  Fields:")
    local fields = safe_cmd("DUMP_FIELDS_" .. cls)
    if fields then
        for f in fields:gmatch("[^|\n]+") do
            f = f:match("^%s*(.-)%s*$")
            if f ~= "" then W("    " .. f) end
        end
    else
        W("    (no fields or class not found)")
    end

    W("  Methods:")
    local methods = safe_cmd("DUMP_METHODS_" .. cls)
    if methods then
        for m in methods:gmatch("[^|\n]+") do
            m = m:match("^%s*(.-)%s*$")
            if m ~= "" then W("    " .. m) end
        end
    else
        W("    (no methods or class not found)")
    end

    _ethy_sleep(0.1)
    if is_stopped() then break end
end

-- ═══════════════════════════════════════════════════════════════
-- 11. Field offsets
-- ═══════════════════════════════════════════════════════════════

banner("PHASE 11 — Field Offsets")

section("All Known Offsets")
local offsets = safe_cmd("OFFSET_DUMP")
if offsets then
    for line in offsets:gmatch("[^\n]+") do W("  " .. line) end
else
    W("  (no offset data)")
end

section("Field Layout Dump")
local field_layout = safe_cmd("DUMP_FIELDS")
if field_layout then
    for line in field_layout:gmatch("[^\n|]+") do
        line = line:match("^%s*(.-)%s*$")
        if line ~= "" then W("  " .. line) end
    end
end

-- ═══════════════════════════════════════════════════════════════
-- 12. Active hooks
-- ═══════════════════════════════════════════════════════════════

banner("PHASE 12 — Active Hooks")

for page = 0, 5 do
    local hooks = safe_cmd("DUMP_ALL_HOOKS_PAGE " .. page)
    if not hooks or hooks == "END" then break end
    if page == 0 then W("  All registered function hooks:") end
    for line in hooks:gmatch("[^\n]+") do
        line = line:match("^%s*(.-)%s*$")
        if line ~= "" then W("  " .. line) end
    end
    _ethy_sleep(0.1)
    if is_stopped() then break end
end

-- ═══════════════════════════════════════════════════════════════
-- 13. Scene search
-- ═══════════════════════════════════════════════════════════════

banner("PHASE 13 — Scene Object Search")

local scene_searches = {
    "Spell", "Effect", "Buff", "Aura", "Projectile",
    "Status", "Skill", "Talent", "Combat",
}

for _, term in ipairs(scene_searches) do
    local result = safe_cmd("SCENE_FIND_" .. term)
    if result and result ~= "NOT_FOUND" and result ~= "" then
        W("  [" .. term .. "] " .. result:sub(1, 500))
        if #result > 500 then W("    ... (" .. #result .. " chars)") end
    end
    _ethy_sleep(0.05)
end

-- ═══════════════════════════════════════════════════════════════
-- Summary & close file
-- ═══════════════════════════════════════════════════════════════

banner("DUMP COMPLETE")
W("")
W(string.format("  Sections scanned:     %d", stats.sections))
W(string.format("  Data items logged:    %d", stats.items))
W(string.format("  Classes inspected:    %d", stats.classes_found))
W(string.format("  Errors/missing:       %d", stats.errors))
W(string.format("  Total lines written:  %d", line_count + 4))
W("")

file:flush()
file:close()

print(string.format("[Dump] DONE — %d lines written to: %s", line_count, out_path))
print(string.format("[Dump] %d items, %d classes, %d errors", stats.items, stats.classes_found, stats.errors))
print("[Dump] Open the file in any text editor to browse.")
