-- ═══════════════════════════════════════════════════════════════
--  core.asset_dump — Comprehensive Asset & Data Dumping API
--
--  Two data sources:
--    1) Local asset files (Unity YAML from game install dir)
--       → item databases, textures, sprites, meshes, audio, etc.
--    2) Runtime IL2CPP memory (via pipe to EthyTool DLL)
--       → loaded scenes, enums, singletons, ScriptableObjects, etc.
-- ═══════════════════════════════════════════════════════════════

local ad = {}

-- ═══════════════════════════════════════════════════════════════
--  LOCAL ASSET FILE FUNCTIONS (C-bound via core._asset_*)
--  These read from the game's install directory, no injection needed
-- ═══════════════════════════════════════════════════════════════

--- Initialize the asset dumper with the game's install path.
--- Auto-detects the asset/ExportedProject/Assets subfolder.
---@param game_path string|nil  Game install dir (auto-detected if nil)
---@return boolean success
function ad.init(game_path)
    if core._asset_init then
        return core._asset_init(game_path or "")
    end
    -- Fallback: try to get game path from DLL
    if not game_path or game_path == "" then
        game_path = _cmd("DUMP_GAME_PATH")
        if not game_path or game_path:sub(1, 4) == "ERR:" then
            print("[asset_dump] Could not determine game path")
            return false
        end
    end
    if core._asset_init then
        return core._asset_init(game_path)
    end
    print("[asset_dump] Asset dumper not available (C bindings missing)")
    return false
end

--- Scan all game assets (items, textures, sprites, meshes, etc.)
--- Must call init() first.
---@return integer total_items  Number of items found, or -1 on error
function ad.scan()
    if core._asset_scan then
        return core._asset_scan()
    end
    print("[asset_dump] Asset scanner not available")
    return -1
end

--- Get asset dump statistics
---@return table|nil stats  {categories, items, textures, sprites, meshes, audio, ...}
function ad.stats()
    if core._asset_stats then
        local raw = core._asset_stats()
        if raw then return _parse_kv(raw) end
    end
    return nil
end

--- List all item categories
---@return string[] categories
function ad.list_categories()
    if core._asset_list_categories then
        local raw = core._asset_list_categories()
        if not raw or raw == "" then return {} end
        local cats = {}
        for c in raw:gmatch("[^|]+") do
            cats[#cats + 1] = c
        end
        return cats
    end
    return {}
end

--- Get all items in a category
---@param category string  Category name or partial match
---@return table[] items  Array of {name, display_name, category, rarity, ...}
function ad.get_items(category)
    if core._asset_get_items then
        local raw = core._asset_get_items(category)
        if not raw or raw == "" or raw:sub(1, 4) == "ERR:" then return {} end
        return _parse_lines(raw)
    end
    return {}
end

--- Search items by name, display name, or category
---@param pattern string  Search pattern (case-insensitive)
---@return table[] items
function ad.search_items(pattern)
    if core._asset_search_items then
        local raw = core._asset_search_items(pattern)
        if not raw or raw == "" or raw:sub(1, 4) == "ERR:" then return {} end
        return _parse_lines(raw)
    end
    return {}
end

--- Find a specific item by exact name
---@param name string  Internal item name
---@return table|nil item
function ad.find_item(name)
    if core._asset_find_item then
        local raw = core._asset_find_item(name)
        if not raw or raw == "" or raw:sub(1, 4) == "ERR:" then return nil end
        return _parse_kv(raw)
    end
    return nil
end

--- Get items filtered by rarity
---@param rarity integer  0=Common, 1=Uncommon, 2=Rare, 3=Epic, 4=Legendary, 5=Mythic, 6=Artifact
---@return table[] items
function ad.get_items_by_rarity(rarity)
    if core._asset_get_by_rarity then
        local raw = core._asset_get_by_rarity(rarity)
        if not raw or raw == "" or raw:sub(1, 4) == "ERR:" then return {} end
        return _parse_lines(raw)
    end
    return {}
end

--- List all asset types (Texture2D, Sprite, Mesh, AudioClip, etc.)
---@return string[] types
function ad.list_asset_types()
    if core._asset_list_types then
        local raw = core._asset_list_types()
        if not raw or raw == "" then return {} end
        local types = {}
        for t in raw:gmatch("[^|]+") do
            types[#types + 1] = t
        end
        return types
    end
    return {}
end

--- Get asset count for a specific type
---@param asset_type string  e.g. "Texture2D", "Sprite", "Mesh"
---@return integer count
function ad.get_asset_count(asset_type)
    if core._asset_count_by_type then
        return core._asset_count_by_type(asset_type)
    end
    return 0
end

--- Search across all asset files
---@param pattern string  Search pattern
---@return table[] assets  Array of {name, type, path, size}
function ad.search_assets(pattern)
    if core._asset_search then
        local raw = core._asset_search(pattern)
        if not raw or raw == "" or raw:sub(1, 4) == "ERR:" then return {} end
        return _parse_lines(raw)
    end
    return {}
end

--- List data categories (Weapons, Armour, Consumables, etc.)
---@return string[] categories
function ad.list_data_categories()
    if core._asset_list_data_categories then
        local raw = core._asset_list_data_categories()
        if not raw or raw == "" then return {} end
        local cats = {}
        for c in raw:gmatch("[^|]+") do
            cats[#cats + 1] = c
        end
        return cats
    end
    return {}
end

--- Dump all items to a text file
---@param output_path string  File path to write to
---@return string result  "OK|..." or "ERR:..."
function ad.dump_items_to_file(output_path)
    if core._asset_dump_items then
        return core._asset_dump_items(output_path)
    end
    return "ERR:NOT_AVAILABLE"
end

--- Dump full report (items + asset catalog + CSV) to a directory
---@param output_dir string  Directory path
---@return string result  "OK|..." or "ERR:..."
function ad.dump_full_report(output_dir)
    if core._asset_dump_report then
        return core._asset_dump_report(output_dir)
    end
    return "ERR:NOT_AVAILABLE"
end

-- ═══════════════════════════════════════════════════════════════
--  RUNTIME IL2CPP DUMP FUNCTIONS (via pipe to EthyTool DLL)
--  These read live game memory and require injection
-- ═══════════════════════════════════════════════════════════════

--- Dump all loaded Unity scenes
---@return table|nil scene_info
function ad.dump_scenes()
    local raw = _cmd("DUMP_LOADED_SCENES")
    if not raw or raw:sub(1, 4) == "ERR:" then return nil end
    return _parse_kv(raw)
end

--- Dump game settings classes
---@return table[] settings
function ad.dump_game_settings()
    local raw = _cmd("DUMP_GAME_SETTINGS")
    if not raw or raw == "NO_CONFIG_CLASSES" then return {} end
    return _parse_lines(raw)
end

--- Dump all enum types (optionally filtered)
---@param filter string|nil  Optional filter pattern
---@return string raw  Raw dump result
function ad.dump_enums(filter)
    if filter then
        return _cmd("DUMP_ENUM " .. filter)
    end
    return _cmd("DUMP_ENUMS")
end

--- Dump singleton classes
---@return string raw
function ad.dump_singletons()
    return _cmd("DUMP_SINGLETONS")
end

--- Dump ScriptableObject types
---@return string raw
function ad.dump_scriptable_objects()
    return _cmd("DUMP_ALL_SCRIPTABLEOBJECTS")
end

--- Dump runtime item database classes
---@return string raw
function ad.dump_item_db()
    return _cmd("DUMP_ITEMDB")
end

--- Get the game's executable directory
---@return string path
function ad.get_game_path()
    return _cmd("DUMP_GAME_PATH")
end

--- Dump a specific IL2CPP class (fields + methods)
---@param class_name string
---@return string raw
function ad.dump_class(class_name)
    return _cmd("DUMP_CLASS_FULL " .. class_name)
end

--- Dump fields of a class
---@param class_name string
---@return string raw
function ad.dump_class_fields(class_name)
    return _cmd("DUMP_FIELDS_" .. class_name)
end

--- Dump methods of a class
---@param class_name string
---@return string raw
function ad.dump_class_methods(class_name)
    return _cmd("DUMP_METHODS_" .. class_name)
end

--- SDK full dump to disk
---@param base_path string|nil  Output directory (uses game dir if nil)
---@return string result
function ad.sdk_dump_to_file(base_path)
    if base_path then
        return _cmd("SDK_DUMP_TO_FILE " .. base_path)
    end
    return _cmd("SDK_DUMP_TO_FILE")
end

--- SDK stats
---@return table|nil stats
function ad.sdk_stats()
    local raw = _cmd("SDK_STATS")
    if not raw or raw:sub(1, 4) == "ERR:" then return nil end
    return _parse_kv(raw)
end

--- Dump all assemblies
---@return string[] assemblies
function ad.dump_assemblies()
    local raw = _cmd("DUMP_ASSEMBLIES")
    if not raw or raw:sub(1, 4) == "ERR:" then return {} end
    -- Parse "count=N###asm1|asm2|..."
    local body = raw:match("###(.+)")
    if not body then return {} end
    local result = {}
    for a in body:gmatch("[^|]+") do
        result[#result + 1] = a
    end
    return result
end

--- Get class hierarchy
---@param class_name string
---@return string hierarchy
function ad.class_hierarchy(class_name)
    return _cmd("SDK_HIERARCHY " .. class_name)
end

--- Search SDK classes
---@param pattern string
---@return string raw
function ad.search_classes(pattern)
    return _cmd("SDK_SEARCH_CLASS " .. pattern)
end

--- Search SDK fields
---@param pattern string
---@return string raw
function ad.search_fields(pattern)
    return _cmd("SDK_SEARCH_FIELD " .. pattern)
end

--- Search SDK methods
---@param pattern string
---@return string raw
function ad.search_methods(pattern)
    return _cmd("SDK_SEARCH_METHOD " .. pattern)
end

-- ═══════════════════════════════════════════════════════════════
--  CONVENIENCE: Dump everything possible
-- ═══════════════════════════════════════════════════════════════

--- Mega-dump: dump EVERYTHING to a directory.
--- Runs both local asset scan and runtime IL2CPP dumps.
---@param output_dir string  Output directory for all dump files
---@return table results  Summary of what was dumped
function ad.dump_everything(output_dir)
    local results = {
        ok = true,
        files = {},
        errors = {},
    }

    print("[DUMP] Starting comprehensive dump to: " .. output_dir)

    -- 1) Local asset dump
    print("[DUMP] Phase 1: Scanning local asset files...")
    local init_ok = ad.init()
    if init_ok then
        local count = ad.scan()
        print("[DUMP]   Found " .. tostring(count) .. " items in asset files")

        local r = ad.dump_full_report(output_dir)
        if r and r:sub(1, 2) == "OK" then
            print("[DUMP]   Asset report written successfully")
            results.files[#results.files + 1] = "asset_report"
        else
            results.errors[#results.errors + 1] = "asset_report: " .. tostring(r)
        end
    else
        results.errors[#results.errors + 1] = "asset_init_failed"
        print("[DUMP]   Skipping local assets (init failed)")
    end

    -- 2) Runtime SDK dump
    print("[DUMP] Phase 2: Runtime IL2CPP SDK dump...")
    local sdk_r = ad.sdk_dump_to_file(output_dir)
    if sdk_r and sdk_r:sub(1, 2) == "OK" then
        print("[DUMP]   SDK dump written successfully")
        results.files[#results.files + 1] = "sdk_dump"
    else
        results.errors[#results.errors + 1] = "sdk_dump: " .. tostring(sdk_r)
    end

    -- 3) Enums
    print("[DUMP] Phase 3: Dumping all enums...")
    local enums_raw = ad.dump_enums()
    if enums_raw and enums_raw ~= "NO_ENUMS" and enums_raw:sub(1, 4) ~= "ERR:" then
        local enum_file = output_dir .. "\\enums_dump.txt"
        local f = io.open(enum_file, "w")
        if f then
            f:write("# Ethyrial — All IL2CPP Enum Types\n\n")
            f:write(enums_raw:gsub("###", "\n\n"):gsub("|", "\n  "))
            f:close()
            results.files[#results.files + 1] = enum_file
            print("[DUMP]   Enums written to file")
        end
    end

    -- 4) Singletons
    print("[DUMP] Phase 4: Dumping singletons...")
    local singletons_raw = ad.dump_singletons()
    if singletons_raw and singletons_raw ~= "NO_SINGLETONS" and singletons_raw:sub(1, 4) ~= "ERR:" then
        local sing_file = output_dir .. "\\singletons_dump.txt"
        local f = io.open(sing_file, "w")
        if f then
            f:write("# Ethyrial — All Singleton Classes\n\n")
            local body = singletons_raw:match("###(.+)") or singletons_raw
            f:write(body:gsub("|", "\n"))
            f:close()
            results.files[#results.files + 1] = sing_file
            print("[DUMP]   Singletons written to file")
        end
    end

    -- 5) Game settings
    print("[DUMP] Phase 5: Dumping game settings...")
    local settings_raw = _cmd("DUMP_GAME_SETTINGS")
    if settings_raw and settings_raw ~= "NO_CONFIG_CLASSES" and settings_raw:sub(1, 4) ~= "ERR:" then
        local set_file = output_dir .. "\\game_settings_dump.txt"
        local f = io.open(set_file, "w")
        if f then
            f:write("# Ethyrial — Game Settings Classes\n\n")
            f:write(settings_raw:gsub("###", "\n\n"):gsub("|", "\n  "))
            f:close()
            results.files[#results.files + 1] = set_file
            print("[DUMP]   Game settings written to file")
        end
    end

    -- 6) Item database classes
    print("[DUMP] Phase 6: Dumping runtime item DB classes...")
    local itemdb_raw = ad.dump_item_db()
    if itemdb_raw and itemdb_raw ~= "NO_ITEM_CLASSES" and itemdb_raw:sub(1, 4) ~= "ERR:" then
        local idb_file = output_dir .. "\\itemdb_classes_dump.txt"
        local f = io.open(idb_file, "w")
        if f then
            f:write("# Ethyrial — Runtime Item Database Classes\n\n")
            f:write(itemdb_raw:gsub("###", "\n\n"):gsub("|", "\n  "))
            f:close()
            results.files[#results.files + 1] = idb_file
            print("[DUMP]   Item DB classes written to file")
        end
    end

    -- 7) Assemblies list
    print("[DUMP] Phase 7: Dumping assembly list...")
    local assemblies = ad.dump_assemblies()
    if #assemblies > 0 then
        local asm_file = output_dir .. "\\assemblies_dump.txt"
        local f = io.open(asm_file, "w")
        if f then
            f:write("# Ethyrial — IL2CPP Assemblies (" .. #assemblies .. " total)\n\n")
            for i, a in ipairs(assemblies) do
                f:write(i .. ". " .. a .. "\n")
            end
            f:close()
            results.files[#results.files + 1] = asm_file
            print("[DUMP]   " .. #assemblies .. " assemblies written")
        end
    end

    -- Summary
    print("[DUMP] ════════════════════════════════════════════════")
    print("[DUMP] Dump complete!")
    print("[DUMP]   Files written: " .. #results.files)
    print("[DUMP]   Errors: " .. #results.errors)
    for _, e in ipairs(results.errors) do
        print("[DUMP]   ERROR: " .. e)
    end
    print("[DUMP] Output directory: " .. output_dir)

    results.ok = #results.errors == 0
    return results
end

return ad
