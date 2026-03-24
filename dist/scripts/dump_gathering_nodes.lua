--[[
╔══════════════════════════════════════════════════════════════════════╗
║        Dump Gathering Nodes — Full Resource Catalog                  ║
║                                                                      ║
║  Scans the game scene to catalog every gathering resource:           ║
║  herbs, trees, ore veins, and skinning nodes.                        ║
║                                                                      ║
║  Writes to: dist/scripts/gathering_nodes_dump.txt                    ║
║  Only phase progress shows in the Hub log.                           ║
╚══════════════════════════════════════════════════════════════════════╝
]]

local cmd = conn.send_command

-- ═══════════════════════════════════════════════════════════════
-- File output
-- ═══════════════════════════════════════════════════════════════

local script_dir = ""
do
    local info = debug.getinfo(1, "S")
    if info and info.source then
        local src = info.source:gsub("^@", "")
        script_dir = src:match("^(.*)[/\\]") or "."
    end
end

local out_path = script_dir .. "/gathering_nodes_dump.txt"
local file = io.open(out_path, "w")
if not file then
    out_path = "gathering_nodes_dump.txt"
    file = io.open(out_path, "w")
end
if not file then
    print("[ERROR] Cannot open output file.")
    return
end

local line_count = 0
local function W(text)
    file:write(text .. "\n")
    line_count = line_count + 1
    if line_count % 200 == 0 then file:flush() end
end

local unique_herbs = {}
local unique_trees = {}
local unique_ores  = {}
local unique_skins = {}
local unique_all   = {}
local total_nodes  = 0

-- ═══════════════════════════════════════════════════════════════
-- Helpers
-- ═══════════════════════════════════════════════════════════════

local function safe_cmd(command)
    local ok, result = pcall(cmd, command)
    if not ok then return nil end
    if not result or result == "" or result == "NONE" or result == "EMPTY"
       or result == "NOT_FOUND" or result == "UNKNOWN_CMD" then
        return nil
    end
    if result:sub(1, 4) == "ERR:" or result:sub(1, 4) == "ERR|" then return nil end
    return result
end

local function banner(title)
    W("")
    W("╔══════════════════════════════════════════════════════════════╗")
    W("║  " .. title .. string.rep(" ", 60 - #title) .. "║")
    W("╚══════════════════════════════════════════════════════════════╝")
    print("[Nodes] " .. title)
end

local function section(title)
    W("")
    W("── " .. title .. " " .. string.rep("─", 58 - #title))
end

local function parse_kv(entry)
    local t = {}
    for k, v in entry:gmatch("([%w_]+)=([^|]+)") do
        local num = tonumber(v)
        t[k] = (num ~= nil) and num or v
    end
    return t
end

local function parse_response(raw)
    if not raw then return {} end
    local results = {}
    for entry in raw:gmatch("[^#]+") do
        entry = entry:match("^%s*(.-)%s*$")
        if entry ~= "" and not entry:match("^count=") and not entry:match("^fallback=") then
            local t = parse_kv(entry)
            if next(t) then results[#results + 1] = t end
        end
    end
    return results
end

local function track_unique(node, category, unique_table)
    local name = node.name or node.disp or node.display or "Unknown"
    local key = name:lower()
    total_nodes = total_nodes + 1

    if not unique_table[key] then
        unique_table[key] = {
            name     = name,
            category = category,
            count    = 0,
            sample_uid = node.uid,
            fields   = {},
        }
        for k, v in pairs(node) do
            unique_table[key].fields[k] = tostring(v)
        end
    end
    unique_table[key].count = unique_table[key].count + 1

    local all_key = category .. ":" .. key
    if not unique_all[all_key] then
        unique_all[all_key] = unique_table[key]
    end
end

local function write_node_table(label, nodes, unique_table)
    section(label .. " (" .. #nodes .. " in scene)")
    if #nodes == 0 then
        W("  (none found)")
        return
    end
    for i, n in ipairs(nodes) do
        local name = n.name or n.disp or "?"
        local uid  = n.uid or "?"
        local dist = n.dist or n.distance or "?"
        local extra = ""
        for k, v in pairs(n) do
            if k ~= "name" and k ~= "disp" and k ~= "uid" and k ~= "x" and k ~= "y"
               and k ~= "z" and k ~= "dist" and k ~= "distance" and k ~= "type" then
                extra = extra .. k .. "=" .. tostring(v) .. " "
            end
        end
        W(string.format("  [%3d] %-30s uid=%-8s dist=%-6s %s",
            i, name, tostring(uid), tostring(dist), extra))
    end
end

local function write_unique_summary(label, unique_table)
    local sorted = {}
    for _, entry in pairs(unique_table) do
        sorted[#sorted + 1] = entry
    end
    table.sort(sorted, function(a, b) return a.name < b.name end)

    section(label .. " — " .. #sorted .. " unique types")
    for i, entry in ipairs(sorted) do
        W(string.format("  [%2d] %-35s  (x%d in scene)", i, entry.name, entry.count))
        local field_str = ""
        for k, v in pairs(entry.fields) do
            if k ~= "name" and k ~= "x" and k ~= "y" and k ~= "z" then
                field_str = field_str .. k .. "=" .. v .. " | "
            end
        end
        if field_str ~= "" then
            W("       Fields: " .. field_str)
        end
    end
end

local function count_unique(t)
    local c = 0
    for _ in pairs(t) do c = c + 1 end
    return c
end

-- ═══════════════════════════════════════════════════════════════
-- Start
-- ═══════════════════════════════════════════════════════════════

print("[Nodes] Writing to: " .. out_path)

banner("GATHERING NODE CATALOG")
W("Output file: " .. out_path)
W("Time: " .. os.date("%Y-%m-%d %H:%M:%S"))

local ping = safe_cmd("PING")
if ping ~= "PONG" then
    W("[ERROR] Not connected.")
    print("[ERROR] Not connected. Connect first.")
    file:close()
    return
end
W("[OK] Connected | Job: " .. (safe_cmd("PLAYER_JOB") or "?"))
W("[OK] Position: " .. (safe_cmd("PLAYER_POS") or "?"))

-- ═══════════════════════════════════════════════════════════════
-- PHASE 1 — Scan each resource type
-- ═══════════════════════════════════════════════════════════════

banner("PHASE 1 — Scene Resource Scans")

local herbs = parse_response(safe_cmd("SCENE_SCAN_HERBS"))
for _, n in ipairs(herbs) do track_unique(n, "Herb", unique_herbs) end
write_node_table("HERBS", herbs, unique_herbs)
_ethy_sleep(0.2)

local trees = parse_response(safe_cmd("SCENE_SCAN_TREES"))
for _, n in ipairs(trees) do track_unique(n, "Tree", unique_trees) end
write_node_table("TREES", trees, unique_trees)
_ethy_sleep(0.2)

local ores = parse_response(safe_cmd("SCENE_SCAN_ORES"))
for _, n in ipairs(ores) do track_unique(n, "Ore", unique_ores) end
write_node_table("ORE VEINS", ores, unique_ores)
_ethy_sleep(0.2)

local skins = parse_response(safe_cmd("SCENE_SCAN_SKINS"))
for _, n in ipairs(skins) do track_unique(n, "Skin", unique_skins) end
write_node_table("SKINNING NODES", skins, unique_skins)
_ethy_sleep(0.2)

if is_stopped() then file:close(); return end

-- ═══════════════════════════════════════════════════════════════
-- PHASE 2 — NODE_SCAN variants
-- ═══════════════════════════════════════════════════════════════

banner("PHASE 2 — NODE_SCAN (All Formats)")

local scan_cmds = {
    { "NODE_SCAN",              "All Nodes" },
    { "NODE_SCAN_USABLE",       "Usable Nodes" },
    { "NODE_SCAN_herb",         "Herbs" },
    { "NODE_SCAN_tree",         "Trees" },
    { "NODE_SCAN_ore",          "Ores" },
    { "NODE_SCAN_skin",         "Skins" },
    { "NODE_SCAN_USABLE_herb",  "Usable Herbs" },
    { "NODE_SCAN_USABLE_tree",  "Usable Trees" },
    { "NODE_SCAN_USABLE_ore",   "Usable Ores" },
    { "NODE_SCAN_USABLE_skin",  "Usable Skins" },
}

for _, sc in ipairs(scan_cmds) do
    local result = safe_cmd(sc[1])
    section(sc[2])
    if result then
        local entries = parse_response(result)
        if #entries > 0 then
            for i, n in ipairs(entries) do
                local name = n.name or n.disp or "?"
                local ntype = n.type or "?"
                local dist = n.dist or n.distance or "?"
                W(string.format("  [%d] %-30s type=%-6s dist=%s", i, name, tostring(ntype), tostring(dist)))
            end
            W("  Count: " .. #entries)
        else
            W("  (no data)")
        end
    else
        W("  (empty / not supported)")
    end
    _ethy_sleep(0.1)
    if is_stopped() then break end
end

-- ═══════════════════════════════════════════════════════════════
-- PHASE 3 — IL2CPP class definitions
-- ═══════════════════════════════════════════════════════════════

banner("PHASE 3 — IL2CPP Gathering Class Definitions")

safe_cmd("CACHE_ALL_CLASSES")
_ethy_sleep(0.3)

local gather_classes = {
    "GrowingDoodad", "ConstructionDoodad", "Doodad",
    "DoodadPresetInformation", "DoodadMod",
    "ItemEntity", "WallEntity",
    "Entity", "EntityPresetInformation",
    "SkillProgression",
}

for _, cls in ipairs(gather_classes) do
    section("CLASS: " .. cls)
    local full = safe_cmd("DUMP_CLASS_FULL " .. cls)
    if full then
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
    else
        W("  (class not found)")
    end
    _ethy_sleep(0.1)
    if is_stopped() then break end
end

section("Search: gathering-related classes")
local gather_search_terms = {
    "Doodad", "Growing", "Resource", "Gather",
    "Herb", "Ore", "Vein", "Mine", "Fish",
    "Harvest", "Forage", "Woodcut", "Profession",
}
local found_classes = {}
local seen_cls = {}

for _, term in ipairs(gather_search_terms) do
    local result = safe_cmd("LIST_CACHED_CLASSES " .. term)
    if result then
        for cls in result:gmatch("[^|,\n]+") do
            cls = cls:match("^%s*(.-)%s*$")
            if cls ~= "" and not seen_cls[cls]
               and not cls:find("^<>c__Display")
               and not cls:find("^<>c__")
               and not cls:find("^<<")
               and not cls:find("^%d+>d$")
               and not cls:find("^page=")
               and not cls:find("^total=")
               and #cls > 3 then
                seen_cls[cls] = true
                found_classes[#found_classes + 1] = cls
            end
        end
    end
end

table.sort(found_classes)
if #found_classes > 0 then
    W("  Real gathering-related classes:")
    for i, cls in ipairs(found_classes) do
        W(string.format("    [%d] %s", i, cls))
    end
end

-- ═══════════════════════════════════════════════════════════════
-- PHASE 4 — UNIQUE NODE CATALOG
-- ═══════════════════════════════════════════════════════════════

banner("PHASE 4 — COMPLETE NODE CATALOG")

write_unique_summary("HERBS", unique_herbs)
write_unique_summary("TREES", unique_trees)
write_unique_summary("ORE VEINS", unique_ores)
write_unique_summary("SKINNING NODES", unique_skins)

section("MASTER LIST — All Unique Gathering Resources")

local master = {}
for _, tbl in ipairs({unique_herbs, unique_trees, unique_ores, unique_skins}) do
    for _, entry in pairs(tbl) do
        master[#master + 1] = entry
    end
end
table.sort(master, function(a, b)
    if a.category ~= b.category then return a.category < b.category end
    return a.name < b.name
end)

local current_cat = ""
for _, entry in ipairs(master) do
    if entry.category ~= current_cat then
        current_cat = entry.category
        W("")
        W("  ┌─ " .. current_cat:upper() .. " ─────────────────────────────────────────")
    end
    local uid_str = entry.sample_uid and ("  uid=" .. tostring(entry.sample_uid)) or ""
    W(string.format("  │ %-35s  x%-3d%s", entry.name, entry.count, uid_str))
end
W("  └────────────────────────────────────────────────────────")

-- ═══════════════════════════════════════════════════════════════
-- PHASE 5 — Copy-paste Lua reference table
-- ═══════════════════════════════════════════════════════════════

banner("PHASE 5 — Lua Reference Table (copy-paste ready)")

W("")
W("-- Paste this into your scripts as a node name reference")
W("local GATHER_NODES = {")
for _, entry in ipairs(master) do
    local t = entry.fields.type or ""
    local u = entry.fields.usable or ""
    local extras = ""
    if t ~= "" then extras = extras .. ', type="' .. t .. '"' end
    if u ~= "" then extras = extras .. ', usable=' .. u end
    W(string.format('    { name="%s", category="%s"%s },', entry.name, entry.category, extras))
end
W("}")

-- ═══════════════════════════════════════════════════════════════
-- Summary
-- ═══════════════════════════════════════════════════════════════

banner("DUMP COMPLETE")
W("")
W(string.format("  Total nodes scanned:    %d", total_nodes))
W(string.format("  Unique herbs:           %d", count_unique(unique_herbs)))
W(string.format("  Unique trees:           %d", count_unique(unique_trees)))
W(string.format("  Unique ores:            %d", count_unique(unique_ores)))
W(string.format("  Unique skins:           %d", count_unique(unique_skins)))
W(string.format("  Master catalog total:   %d", #master))
W(string.format("  IL2CPP classes found:   %d", #found_classes))
W(string.format("  Lines written:          %d", line_count + 3))
W("")
W("  TIP: Travel to different zones and run again to discover")
W("       zone-specific nodes not currently loaded in the scene.")

file:flush()
file:close()

print(string.format("[Nodes] DONE — %d unique nodes, %d lines -> %s", #master, line_count, out_path))
print(string.format("[Nodes] Herbs: %d | Trees: %d | Ores: %d | Skins: %d",
    count_unique(unique_herbs), count_unique(unique_trees),
    count_unique(unique_ores), count_unique(unique_skins)))
