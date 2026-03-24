--[[
╔══════════════════════════════════════════════════════════════╗
║            Debug Dump — Full IL2CPP Inspection                ║
║                                                              ║
║  Dumps offsets, memory addresses, methods, hooks, classes,   ║
║  singletons, and player data to the Hub log.                 ║
║  Use the "Copy All" button in the Log tab to save output.   ║
╚══════════════════════════════════════════════════════════════╝
]]

local cmd = conn.send_command

local function section(title)
    print("")
    print("══════════════════════════════════════════════════════════════")
    print("  " .. title)
    print("══════════════════════════════════════════════════════════════")
end

local function dump(label, command)
    local result = cmd(command)
    if not result or result == "" then
        print("[" .. label .. "] (empty)")
        return result
    end
    -- Split long results by ### or | for readability
    if #result > 200 and result:find("###") then
        print("[" .. label .. "]")
        for part in result:gmatch("[^###]+") do
            print("  " .. part)
        end
    elseif #result > 500 then
        -- Print first 500 chars + truncation notice
        print("[" .. label .. "] " .. result:sub(1, 500))
        if #result > 500 then
            print("  ... (" .. #result .. " chars total, truncated)")
        end
    else
        print("[" .. label .. "] " .. result)
    end
    return result
end

local function dump_lines(label, command)
    local result = cmd(command)
    if not result or result == "" then
        print("[" .. label .. "] (empty)")
        return
    end
    print("[" .. label .. "]")
    for line in result:gmatch("[^\n]+") do
        print("  " .. line)
    end
end

-- ═══════════════════════════════════════════════════════════
print("╔══════════════════════════════════════════════════════════╗")
print("║          EthyTool Debug Dump — Starting...              ║")
print("╚══════════════════════════════════════════════════════════╝")

-- System
section("SYSTEM STATUS")
dump("PING", "PING")
dump("VERSION", "VERSION")
dump("IS_INIT", "IS_INIT")
dump("LAST_ERROR", "ERROR")

-- Player identity & vitals
section("PLAYER DATA")
dump("JOB", "PLAYER_JOB")
dump("HP", "PLAYER_HP")
dump("MP", "PLAYER_MP")
dump("MAX_HP", "PLAYER_MAX_HP")
dump("MAX_MP", "PLAYER_MAX_MP")
dump("POSITION", "PLAYER_POS")
dump("DIRECTION", "PLAYER_DIRECTION")
dump("SPEED", "PLAYER_SPEED")
dump("ATTACK_SPEED", "PLAYER_ATTACK_SPEED")
dump("MOVING", "PLAYER_MOVING")
dump("FROZEN", "PLAYER_FROZEN")
dump("COMBAT", "PLAYER_COMBAT")
dump("GOLD", "PLAYER_GOLD")
dump("INFAMY", "PLAYER_INFAMY")
dump("FOOD", "PLAYER_FOOD")
dump("PZ_ZONE", "PLAYER_PZ_ZONE")
dump("SPECTATOR", "PLAYER_SPECTATOR")
dump("WILDLANDS", "PLAYER_WILDLANDS")
dump("COMBAT_LEVEL", "PLAYER_COMBAT_LEVEL")
dump("PROFESSION_LEVEL", "PLAYER_PROFESSION_LEVEL")
dump("ADDRESS", "PLAYER_ADDRESS")

-- Player extended
section("PLAYER ALL (full snapshot)")
dump("PLAYER_ALL", "PLAYER_ALL")

section("PLAYER INFO (entity info)")
dump("PLAYER_INFO", "PLAYER_INFO")

section("PLAYER MOVEMENT (detailed)")
dump("MOVEMENT", "PLAYER_MOVEMENT")

section("PLAYER ANIMATION")
dump("ANIMATION", "PLAYER_ANIMATION")

-- Camera
section("CAMERA")
dump("CAMERA", "CAMERA")

-- Target
section("TARGET")
dump("HAS_TARGET", "HAS_TARGET")
dump("TARGET_NAME", "TARGET_NAME")
dump("TARGET_HP", "TARGET_HP")
dump("TARGET_HP_V2", "TARGET_HP_V2")
dump("TARGET_DISTANCE", "TARGET_DISTANCE")
dump("TARGET_INFO", "TARGET_INFO")
dump("TARGET_INFO_V2", "TARGET_INFO_V2")
dump("TARGET_FULL", "TARGET_FULL")
dump("FRIENDLY_TARGET", "FRIENDLY_TARGET")
dump("LEGAL_TARGETS", "LEGAL_TARGETS")

-- Buffs
section("PLAYER BUFFS")
dump("BUFFS", "PLAYER_BUFFS")
dump("STACKS", "PLAYER_STACKS")

-- Skills & Talents
section("SKILLS")
dump("SKILLS", "PLAYER_SKILLS")

section("TALENTS")
dump("TALENTS", "PLAYER_TALENTS")

-- Spells
section("SPELLS")
dump("SPELL_COUNT", "SPELL_COUNT")
dump("SPELLS_ALL", "SPELLS_ALL")

-- Inventory
section("INVENTORY")
dump("INV_COUNT", "INV_COUNT")
dump("EQUIPPED", "EQUIPPED")
dump("OPEN_CONTAINERS_COUNT", "OPEN_CONTAINERS_COUNT")

-- Nearby entities
section("NEARBY ENTITIES")
dump("NEARBY_COUNT", "NEARBY_COUNT")
dump("SCAN_ENEMIES", "SCAN_ENEMIES")
dump("SCAN_NEARBY", "SCAN_NEARBY")

-- Scene
section("SCENE")
dump("SCENE_COUNT", "SCENE_COUNT")

-- Resource nodes
section("RESOURCE NODES")
dump("HERBS", "SCENE_SCAN_HERBS")
dump("TREES", "SCENE_SCAN_TREES")
dump("ORES", "SCENE_SCAN_ORES")
dump("SKINS", "SCENE_SCAN_SKINS")
dump("FISHING", "FISHING_SPOTS")

-- Party
section("PARTY")
dump("PARTY_COUNT", "PARTY_COUNT")
dump("PARTY_ALL", "PARTY_ALL")
dump("NEARBY_PLAYERS", "NEARBY_PLAYERS")

-- Companions & Pets
section("COMPANIONS & PETS")
dump("COMPANIONS", "COMPANIONS")
dump("PET_COUNT", "PET_COUNT")

-- Quests
section("QUESTS")
dump("ACTIVE_QUESTS", "ACTIVE_QUESTS")

-- IL2CPP Offsets & Memory
section("IL2CPP OFFSETS")
dump_lines("OFFSET_DUMP", "OFFSET_DUMP")

section("FIELD OFFSETS (raw)")
dump_lines("DUMP_OFFSETS", "DUMP_OFFSETS")

section("FIELD LAYOUT")
dump_lines("DUMP_FIELDS", "DUMP_FIELDS")

-- Singletons
section("SINGLETONS (instance pointers)")
dump("SINGLETONS", "DUMP_SINGLETONS")

-- Class cache
section("CLASS CACHE")
dump("CACHE_SIZE", "CLASS_CACHE_SIZE")

-- Key game classes — dump fields + methods
section("KEY CLASS DUMPS")
local key_classes = {
    "LocalPlayerEntity",
    "PlayerEntity",
    "EntityBase",
    "MonsterEntity",
    "NPCEntity",
    "GameUI",
    "CameraController",
    "EntityManager",
    "SkillProgression",
    "StatusEffect",
    "SpellDefinition",
    "InventoryItem",
    "LootWindowController",
}

for _, cls in ipairs(key_classes) do
    print("")
    print("─── " .. cls .. " ───")
    local full = cmd("DUMP_CLASS_FULL " .. cls)
    if full and full ~= "NOT_FOUND" and full ~= "" then
        -- Split FIELDS###...METHODS###...
        local fields_part = full:match("FIELDS###(.-)METHODS###") or ""
        local methods_part = full:match("METHODS###(.+)$") or ""

        if fields_part ~= "" then
            print("  FIELDS:")
            for f in fields_part:gmatch("[^|]+") do
                if f ~= "" then print("    " .. f) end
            end
        end
        if methods_part ~= "" then
            print("  METHODS:")
            for m in methods_part:gmatch("[^|]+") do
                if m ~= "" then print("    " .. m) end
            end
        end
        if fields_part == "" and methods_part == "" then
            print("  " .. full:sub(1, 300))
        end
    else
        print("  (not found or not resolved)")
    end
end

-- Hooks dump (first page)
section("ACTIVE HOOKS (page 0)")
local hooks = cmd("DUMP_ALL_HOOKS_PAGE 0")
if hooks and hooks ~= "" and hooks ~= "END" then
    for line in hooks:gmatch("[^\n]+") do
        print("  " .. line)
    end
else
    print("  (no hooks or empty)")
end

-- Assemblies
section("LOADED ASSEMBLIES")
dump("ASSEMBLIES", "DUMP_ASSEMBLIES")

-- Network
section("NETWORK")
dump("SERVER_ADDRESS", "DUMP_SERVER_ADDRESS")

-- MonsterDex
section("MONSTERDEX")
dump("MONSTERDEX_NEARBY", "MONSTERDEX_NEARBY")
dump("MONSTERDEX_TARGET", "MONSTERDEX_TARGET")

-- Summary
section("DUMP COMPLETE")
print("All data has been written to the Hub log.")
print("Use the 'Copy All' button on the Log tab to save to clipboard.")
print("Total commands executed: ~50+")
print("")
