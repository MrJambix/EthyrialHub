--[[
╔══════════════════════════════════════════════════════════════╗
║            Dump All Strings — Raw IPC Surface                ║
║                                                              ║
║  Sends every known IPC command and prints the raw response.  ║
║  Use "Copy All" on the Log tab to save the full dump.        ║
╚══════════════════════════════════════════════════════════════╝
]]

local cmd = conn.send_command

local total = 0
local empty = 0

local function section(title)
    print("")
    print("══════════════════════════════════════════════════════════════")
    print("  " .. title)
    print("══════════════════════════════════════════════════════════════")
end

local function dump(label, command)
    total = total + 1
    local ok, result = pcall(cmd, command)
    if not ok then
        print("[" .. label .. "] ERROR: " .. tostring(result))
        empty = empty + 1
        return nil
    end
    if not result or result == "" then
        print("[" .. label .. "] (empty)")
        empty = empty + 1
        return nil
    end
    if #result > 600 then
        print("[" .. label .. "] " .. result:sub(1, 600))
        print("  ... (" .. #result .. " chars total)")
    else
        print("[" .. label .. "] " .. result)
    end
    return result
end

local function dump_multi(label, command)
    total = total + 1
    local ok, result = pcall(cmd, command)
    if not ok then
        print("[" .. label .. "] ERROR: " .. tostring(result))
        empty = empty + 1
        return nil
    end
    if not result or result == "" or result == "NONE" or result == "EMPTY" then
        print("[" .. label .. "] (empty)")
        empty = empty + 1
        return nil
    end
    print("[" .. label .. "]")
    local lines = 0
    for line in result:gmatch("[^\n]+") do
        print("  " .. line)
        lines = lines + 1
        if lines >= 40 then
            print("  ... (truncated, " .. #result .. " chars total)")
            break
        end
    end
    if lines == 0 then
        print("  " .. result:sub(1, 400))
    end
    return result
end

-- ═══════════════════════════════════════════════════════════
print("╔══════════════════════════════════════════════════════════╗")
print("║       EthyTool — Dump All IPC Strings                   ║")
print("╚══════════════════════════════════════════════════════════╝")

-- ── SYSTEM ──
section("SYSTEM")
dump("PING", "PING")
dump("VERSION", "VERSION")
dump("IS_INIT", "IS_INIT")
dump("LAST_ERROR", "ERROR")

-- ── PLAYER — scalars ──
section("PLAYER SCALARS")
dump("JOB", "PLAYER_JOB")
dump("HP", "PLAYER_HP")
dump("MP", "PLAYER_MP")
dump("MAX_HP", "PLAYER_MAX_HP")
dump("MAX_MP", "PLAYER_MAX_MP")
dump("POS", "PLAYER_POS")
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
dump("PHYS_ARMOR", "PLAYER_PHYS_ARMOR")
dump("MAG_ARMOR", "PLAYER_MAG_ARMOR")
dump("ADDRESS", "PLAYER_ADDRESS")

-- ── PLAYER — compound ──
section("PLAYER COMPOUND")
dump("PLAYER_ALL", "PLAYER_ALL")
dump("PLAYER_INFO", "PLAYER_INFO")
dump("PLAYER_MOVEMENT", "PLAYER_MOVEMENT")
dump("PLAYER_ANIMATION", "PLAYER_ANIMATION")
dump("PLAYER_INFOBAR", "PLAYER_INFOBAR")

-- ── BUFFS ──
section("BUFFS & STACKS")
dump("PLAYER_BUFFS", "PLAYER_BUFFS")
dump("PLAYER_STACKS", "PLAYER_STACKS")

-- ── SKILLS ──
section("SKILLS")
dump_multi("PLAYER_SKILLS", "PLAYER_SKILLS")

-- ── TALENTS ──
section("TALENTS")
dump("PLAYER_TALENTS", "PLAYER_TALENTS")

-- ── SPELLS ──
section("SPELLS")
dump("SPELL_COUNT", "SPELL_COUNT")
dump_multi("SPELLS_ALL", "SPELLS_ALL")

-- ── TARGET ──
section("TARGET")
dump("HAS_TARGET", "HAS_TARGET")
dump("TARGET_NAME", "TARGET_NAME")
dump("TARGET_HP", "TARGET_HP")
dump("TARGET_HP_V2", "TARGET_HP_V2")
dump("TARGET_DISTANCE", "TARGET_DISTANCE")
dump("TARGET_INFO", "TARGET_INFO")
dump("TARGET_INFO_V2", "TARGET_INFO_V2")
dump("TARGET_FULL", "TARGET_FULL")
dump("TARGET_ANIMATION", "TARGET_ANIMATION")
dump("TARGET_INFOBAR", "TARGET_INFOBAR")
dump("FRIENDLY_TARGET", "FRIENDLY_TARGET")
dump("LEGAL_TARGETS", "LEGAL_TARGETS")

-- ── CAMERA ──
section("CAMERA")
dump("CAMERA", "CAMERA")
dump("CAMERA_DISTANCE", "CAMERA_DISTANCE")
dump("CAMERA_ANGLE", "CAMERA_ANGLE")
dump("CAMERA_PITCH", "CAMERA_PITCH")

-- ── INVENTORY ──
section("INVENTORY")
dump("INV_COUNT", "INV_COUNT")
dump_multi("EQUIPPED", "EQUIPPED")
dump("OPEN_CONTAINERS_COUNT", "OPEN_CONTAINERS_COUNT")
dump("OPEN_CONTAINERS", "OPEN_CONTAINERS")
dump("LOOT_WINDOW_COUNT", "LOOT_WINDOW_COUNT")

-- ── NEARBY ──
section("NEARBY ENTITIES")
dump("NEARBY_COUNT", "NEARBY_COUNT")
dump_multi("SCAN_ENEMIES", "SCAN_ENEMIES")
dump_multi("SCAN_NEARBY", "SCAN_NEARBY")

-- ── SCENE ──
section("SCENE")
dump("SCENE_COUNT", "SCENE_COUNT")
dump_multi("SCENE_CORPSES", "SCENE_CORPSES")

-- ── RESOURCES ──
section("RESOURCE NODES — HERBS")
dump_multi("HERBS", "SCENE_SCAN_HERBS")
section("RESOURCE NODES — TREES")
dump_multi("TREES", "SCENE_SCAN_TREES")
section("RESOURCE NODES — ORES")
dump_multi("ORES", "SCENE_SCAN_ORES")
section("RESOURCE NODES — SKINS")
dump_multi("SKINS", "SCENE_SCAN_SKINS")
section("RESOURCE NODES — FISHING")
dump_multi("FISHING", "FISHING_SPOTS")

-- ── PARTY ──
section("PARTY")
dump("PARTY_COUNT", "PARTY_COUNT")
dump_multi("PARTY_ALL", "PARTY_ALL")
dump("NEARBY_PLAYERS", "NEARBY_PLAYERS")
dump("INBOX_NEW", "INBOX_NEW")

-- ── PETS & COMPANIONS ──
section("PETS & COMPANIONS")
dump("PET_COUNT", "PET_COUNT")
dump("COMPANIONS", "COMPANIONS")
dump("COMPANION_FULL", "COMPANION_FULL")
dump("PET_ATK_SPEED", "PET_ATK_SPEED")

-- ── QUESTS ──
section("QUESTS")
dump("ACTIVE_QUESTS", "ACTIVE_QUESTS")

-- ── MONSTERDEX ──
section("MONSTERDEX")
dump_multi("MONSTERDEX_NEARBY", "MONSTERDEX_NEARBY")
dump_multi("MONSTERDEX_TARGET", "MONSTERDEX_TARGET")

-- ── ENTITIES ──
section("ENTITIES")
dump_multi("NEARBY_ALL", "NEARBY_ALL")
dump_multi("NEARBY_LIVING", "NEARBY_LIVING")
dump("ENTITY_UNDER_MOUSE", "ENTITY_UNDER_MOUSE")

-- ── NETWORK ──
section("NETWORK")
dump("SERVER_ADDRESS", "DUMP_SERVER_ADDRESS")

-- ── FLOOR ──
section("FLOOR ITEMS")
dump("FLOOR_DEBUG", "FLOOR_DEBUG")
dump("FLOOR_SEARCH", "FLOOR_SEARCH")

-- ── IL2CPP / DEBUG ──
section("IL2CPP OFFSETS")
dump_multi("OFFSET_DUMP", "OFFSET_DUMP")
dump_multi("DUMP_OFFSETS", "DUMP_OFFSETS")

section("FIELD LAYOUT")
dump_multi("DUMP_FIELDS", "DUMP_FIELDS")

section("SINGLETONS")
dump("DUMP_SINGLETONS", "DUMP_SINGLETONS")

section("CLASS CACHE")
dump("CLASS_CACHE_SIZE", "CLASS_CACHE_SIZE")

section("ASSEMBLIES")
dump("DUMP_ASSEMBLIES", "DUMP_ASSEMBLIES")

section("HOOKS (page 0)")
dump_multi("HOOKS_PAGE_0", "DUMP_ALL_HOOKS_PAGE 0")

-- ═══════════════════════════════════════════════════════════
section("SUMMARY")
print(string.format("Total commands: %d", total))
print(string.format("Returned data:  %d", total - empty))
print(string.format("Empty/missing:  %d", empty))
print(string.format("Coverage:       %.1f%%", (total - empty) / total * 100))
print("")
print("Done. Use 'Copy All' to save the full dump.")
