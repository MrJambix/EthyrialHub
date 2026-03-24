--[[
╔══════════════════════════════════════════════════════════════╗
║         API Check — Validate All core.* Functions            ║
║                                                              ║
║  Calls every core.* function and reports PASS/FAIL/EMPTY.    ║
║  Tests both raw string APIs and parsed table APIs.           ║
║  Use "Copy All" on the Log tab to review results.            ║
╚══════════════════════════════════════════════════════════════╝
]]

local pass_count = 0
local fail_count = 0
local empty_count = 0
local total_count = 0

local function section(title)
    print("")
    print("─── " .. title .. " ───")
end

local function check(name, fn)
    total_count = total_count + 1
    local ok, result = pcall(fn)
    if not ok then
        fail_count = fail_count + 1
        print("  [FAIL] " .. name .. " => " .. tostring(result))
        return
    end

    local rtype = type(result)

    if result == nil then
        empty_count = empty_count + 1
        print("  [----] " .. name .. " => nil")
    elseif rtype == "string" then
        if result == "" or result == "NONE" or result == "EMPTY" or result == "UNKNOWN_CMD" then
            empty_count = empty_count + 1
            print("  [----] " .. name .. " => \"" .. result .. "\"")
        else
            pass_count = pass_count + 1
            local display = result
            if #display > 80 then display = display:sub(1, 77) .. "..." end
            print("  [ OK ] " .. name .. " => \"" .. display .. "\"")
        end
    elseif rtype == "number" then
        pass_count = pass_count + 1
        print("  [ OK ] " .. name .. " => " .. tostring(result))
    elseif rtype == "boolean" then
        pass_count = pass_count + 1
        print("  [ OK ] " .. name .. " => " .. tostring(result))
    elseif rtype == "table" then
        local count = 0
        for _ in pairs(result) do count = count + 1 end
        if count == 0 then
            empty_count = empty_count + 1
            print("  [----] " .. name .. " => {} (empty table)")
        else
            pass_count = pass_count + 1
            local sample = ""
            for k, v in pairs(result) do
                if sample ~= "" then sample = sample .. ", " end
                sample = sample .. tostring(k) .. "=" .. tostring(v)
                if #sample > 70 then sample = sample .. "..." break end
            end
            print("  [ OK ] " .. name .. " => {" .. sample .. "} (" .. count .. " fields)")
        end
    else
        pass_count = pass_count + 1
        print("  [ OK ] " .. name .. " => (" .. rtype .. ")")
    end
end

local function check_table_array(name, fn)
    total_count = total_count + 1
    local ok, result = pcall(fn)
    if not ok then
        fail_count = fail_count + 1
        print("  [FAIL] " .. name .. " => " .. tostring(result))
        return
    end
    if type(result) ~= "table" then
        fail_count = fail_count + 1
        print("  [FAIL] " .. name .. " => expected table, got " .. type(result))
        return
    end
    local count = #result
    if count == 0 then
        empty_count = empty_count + 1
        print("  [----] " .. name .. " => [] (0 entries)")
        return
    end
    pass_count = pass_count + 1
    local first = result[1]
    local keys = {}
    if type(first) == "table" then
        for k, _ in pairs(first) do keys[#keys + 1] = tostring(k) end
    end
    local key_str = table.concat(keys, ", ")
    if #key_str > 60 then key_str = key_str:sub(1, 57) .. "..." end
    print("  [ OK ] " .. name .. " => [" .. count .. " entries] keys={" .. key_str .. "}")
    if type(first) == "table" then
        local sample = "    [1] "
        for k, v in pairs(first) do
            sample = sample .. tostring(k) .. "=" .. tostring(v) .. " | "
            if #sample > 100 then sample = sample .. "..." break end
        end
        print(sample)
    end
end

-- ═══════════════════════════════════════════════════════════
print("╔══════════════════════════════════════════════════════════╗")
print("║       EthyTool — API Validation Check                   ║")
print("╚══════════════════════════════════════════════════════════╝")

-- ── PLAYER RAW ──
section("core.player (raw)")
check("player.hp()",               function() return core.player.hp() end)
check("player.mp()",               function() return core.player.mp() end)
check("player.max_hp()",           function() return core.player.max_hp() end)
check("player.max_mp()",           function() return core.player.max_mp() end)
check("player.pos()",              function() return core.player.pos() end)
check("player.moving()",           function() return core.player.moving() end)
check("player.combat()",           function() return core.player.combat() end)
check("player.frozen()",           function() return core.player.frozen() end)
check("player.job()",              function() return core.player.job() end)
check("player.gold()",             function() return core.player.gold() end)
check("player.speed()",            function() return core.player.speed() end)
check("player.direction()",        function() return core.player.direction() end)
check("player.attack_speed()",     function() return core.player.attack_speed() end)
check("player.infamy()",           function() return core.player.infamy() end)
check("player.food()",             function() return core.player.food() end)
check("player.pz_zone()",          function() return core.player.pz_zone() end)
check("player.spectator()",        function() return core.player.spectator() end)
check("player.wildlands()",        function() return core.player.wildlands() end)
check("player.combat_level()",     function() return core.player.combat_level() end)
check("player.profession_level()", function() return core.player.profession_level() end)
check("player.address()",          function() return core.player.address() end)
check("player.phys_armor()",       function() return core.player.phys_armor() end)
check("player.mag_armor()",        function() return core.player.mag_armor() end)
check("player.all()",              function() return core.player.all() end)
check("player.info()",             function() return core.player.info() end)
check("player.movement()",         function() return core.player.movement() end)
check("player.animation()",        function() return core.player.animation() end)
check("player.infobar()",          function() return core.player.infobar() end)
check("player.buffs()",            function() return core.player.buffs() end)
check("player.stacks()",           function() return core.player.stacks() end)
check("player.skills()",           function() return core.player.skills() end)
check("player.talents()",          function() return core.player.talents() end)

-- ── PLAYER PARSED ──
section("core.player (parsed)")
check("player.get_all()",          function() return core.player.get_all() end)
check("player.get_info()",         function() return core.player.get_info() end)
check("player.get_movement()",     function() return core.player.get_movement() end)
check("player.get_position()",     function() return core.player.get_position() end)
check_table_array("player.get_skills()",  function() return core.player.get_skills() end)
check_table_array("player.get_talents()", function() return core.player.get_talents() end)
check_table_array("player.get_buffs()",   function() return core.player.get_buffs() end)

-- ── TARGETING RAW ──
section("core.targeting (raw)")
check("targeting.has_target()",       function() return core.targeting.has_target() end)
check("targeting.target_hp()",        function() return core.targeting.target_hp() end)
check("targeting.target_hp_v2()",     function() return core.targeting.target_hp_v2() end)
check("targeting.target_name()",      function() return core.targeting.target_name() end)
check("targeting.target_distance()",  function() return core.targeting.target_distance() end)
check("targeting.target_info()",      function() return core.targeting.target_info() end)
check("targeting.target_info_v2()",   function() return core.targeting.target_info_v2() end)
check("targeting.target_full()",      function() return core.targeting.target_full() end)
check("targeting.friendly_target()",  function() return core.targeting.friendly_target() end)
check("targeting.legal_targets()",    function() return core.targeting.legal_targets() end)
check("targeting.scan_enemies()",     function() return core.targeting.scan_enemies() end)

-- ── TARGETING PARSED ──
section("core.targeting (parsed)")
check("targeting.get_target()",       function() return core.targeting.get_target() end)
check("targeting.get_target_v2()",    function() return core.targeting.get_target_v2() end)
check("targeting.get_friendly()",     function() return core.targeting.get_friendly() end)
check_table_array("targeting.get_enemies()", function() return core.targeting.get_enemies() end)

-- ── SPELLS RAW ──
section("core.spells (raw)")
check("spells.count()",   function() return core.spells.count() end)
check("spells.all()",     function() return core.spells.all() end)

-- ── SPELLS PARSED ──
section("core.spells (parsed)")
check_table_array("spells.get_all()", function() return core.spells.get_all() end)

-- per-spell checks using first spell found
do
    local spells = core.spells.get_all()
    if spells and #spells > 0 then
        local s = spells[1]
        local sname = s.name or "SpiritShot"
        section("core.spells — per-spell ('" .. sname .. "')")
        check("spells.is_ready('" .. sname .. "')", function() return core.spells.is_ready(sname) end)
        check("spells.cooldown('" .. sname .. "')", function() return core.spells.cooldown(sname) end)
        check("spells.info('" .. sname .. "')",     function() return core.spells.info(sname) end)
        check("spells.get_info('" .. sname .. "')", function() return core.spells.get_info(sname) end)
    end
end

-- ── INVENTORY RAW ──
section("core.inventory (raw)")
check("inventory.get_count()",            function() return core.inventory.get_count() end)
check("inventory.equipped()",             function() return core.inventory.equipped() end)
check("inventory.open_containers_count()", function() return core.inventory.open_containers_count() end)
check("inventory.open_containers()",      function() return core.inventory.open_containers() end)
check("inventory.loot_window_count()",    function() return core.inventory.loot_window_count() end)

-- ── INVENTORY PARSED ──
section("core.inventory (parsed)")
check_table_array("inventory.get_equipped()", function() return core.inventory.get_equipped() end)
check_table_array("inventory.get_items()",    function() return core.inventory.get_items() end)

-- ── GATHERING RAW ──
section("core.gathering (raw)")
check("gathering.scan_herbs()",  function() return core.gathering.scan_herbs() end)
check("gathering.scan_trees()",  function() return core.gathering.scan_trees() end)
check("gathering.scan_ores()",   function() return core.gathering.scan_ores() end)
check("gathering.scan_skins()",  function() return core.gathering.scan_skins() end)
check("gathering.fishing_spots()", function() return core.gathering.fishing_spots() end)

-- ── GATHERING PARSED ──
section("core.gathering (parsed)")
check_table_array("gathering.get_herbs()",   function() return core.gathering.get_herbs() end)
check_table_array("gathering.get_trees()",   function() return core.gathering.get_trees() end)
check_table_array("gathering.get_ores()",    function() return core.gathering.get_ores() end)
check_table_array("gathering.get_skins()",   function() return core.gathering.get_skins() end)
check_table_array("gathering.get_fishing()", function() return core.gathering.get_fishing() end)

-- ── CAMERA ──
section("core.camera")
check("camera.get()",        function() return core.camera.get() end)
check("camera.distance()",   function() return core.camera.distance() end)
check("camera.angle()",      function() return core.camera.angle() end)
check("camera.pitch()",      function() return core.camera.pitch() end)
check("camera.get_parsed()", function() return core.camera.get_parsed() end)

-- ── SOCIAL RAW ──
section("core.social (raw)")
check("social.party_count()",    function() return core.social.party_count() end)
check("social.party_scan()",     function() return core.social.party_scan() end)
check("social.party_all()",      function() return core.social.party_all() end)
check("social.nearby_players()", function() return core.social.nearby_players() end)
check("social.inbox_new()",      function() return core.social.inbox_new() end)

-- ── SOCIAL PARSED ──
section("core.social (parsed)")
check_table_array("social.get_party()", function() return core.social.get_party() end)

-- ── WORLD RAW ──
section("core.world (raw)")
check("world.nearby_count()",       function() return core.world.nearby_count() end)
check("world.scene_count()",        function() return core.world.scene_count() end)
check("world.scan_nearby()",        function() return core.world.scan_nearby() end)
check("world.scan_scene()",         function() return core.world.scan_scene() end)
check("world.scene_corpses()",      function() return core.world.scene_corpses() end)
check("world.active_quests()",      function() return core.world.active_quests() end)
check("world.companions()",         function() return core.world.companions() end)
check("world.monsterdex_nearby()",  function() return core.world.monsterdex_nearby() end)
check("world.monsterdex_target()",  function() return core.world.monsterdex_target() end)

-- ── WORLD PARSED ──
section("core.world (parsed)")
check_table_array("world.get_nearby()",            function() return core.world.get_nearby() end)
check_table_array("world.get_monsterdex_nearby()", function() return core.world.get_monsterdex_nearby() end)
check("world.get_monsterdex_target()",             function() return core.world.get_monsterdex_target() end)

-- ── PETS RAW ──
section("core.pets (raw)")
check("pets.count()",          function() return core.pets.count() end)
check("pets.companion_full()", function() return core.pets.companion_full() end)
check("pets.companions()",     function() return core.pets.companions() end)
check("pets.atk_speed()",      function() return core.pets.atk_speed() end)

-- ── PETS PARSED ──
section("core.pets (parsed)")
check("pets.get_companions()", function() return core.pets.get_companions() end)
check("pets.get_full()",       function() return core.pets.get_full() end)

-- ── NETWORK ──
section("core.network")
check("network.server_address()", function() return core.network.server_address() end)
check("network.net_classes()",    function() return core.network.net_classes() end)

-- ── FLOOR ──
section("core.floor")
check("floor.debug()",  function() return core.floor.debug() end)
check("floor.search()", function() return core.floor.search() end)

-- ── ENTITIES ──
section("core.entities")
check("entities.nearby_all()",        function() return core.entities.nearby_all() end)
check("entities.nearby_living()",     function() return core.entities.nearby_living() end)
check("entities.entity_under_mouse()", function() return core.entities.entity_under_mouse() end)

-- ── BUFF MANAGER ──
section("core.buff_manager")
check("buff_manager.has_buff('X')",     function() return core.buff_manager.has_buff("Nature_Arrows") end)
check("buff_manager.get_stacks('X')",   function() return core.buff_manager.get_stacks("Fury") end)
check_table_array("buff_manager.get_all_buffs()", function() return core.buff_manager.get_all_buffs() end)
check("buff_manager.get_buff_data('Nature_Arrows')", function() return core.buff_manager.get_buff_data("Nature_Arrows") end)

-- ── SPELL BOOK ──
section("core.spell_book")
check("spell_book.get_spell_count()", function() return core.spell_book.get_spell_count() end)
check("spell_book.get_all_spells()",  function() return core.spell_book.get_all_spells() end)

-- ── OBJECT MANAGER ──
section("core.object_manager")
check("object_manager.get_nearby_count()", function() return core.object_manager.get_nearby_count() end)
check("object_manager.get_party_count()",  function() return core.object_manager.get_party_count() end)

do
    local p = core.object_manager.get_local_player()
    if p then
        section("core.object_manager.get_local_player()")
        check("player:is_valid()",           function() return p:is_valid() end)
        check("player:get_name()",           function() return p:get_name() end)
        check("player:get_uid()",            function() return p:get_uid() end)
        check("player:get_hp()",             function() return p:get_hp() end)
        check("player:get_mp()",             function() return p:get_mp() end)
        check("player:get_max_hp()",         function() return p:get_max_hp() end)
        check("player:get_max_mp()",         function() return p:get_max_mp() end)
        check("player:get_health_percent()", function() return p:get_health_percent() end)
        check("player:get_mana_percent()",   function() return p:get_mana_percent() end)
        check("player:get_job()",            function() return p:get_job() end)
        check("player:get_job_string()",     function() return p:get_job_string() end)
        check("player:get_position()",       function() return p:get_position() end)
        check("player:get_direction()",      function() return p:get_direction() end)
        check("player:get_move_speed()",     function() return p:get_move_speed() end)
        check("player:get_attack_speed()",   function() return p:get_attack_speed() end)
        check("player:get_food()",           function() return p:get_food() end)
        check("player:get_gold()",           function() return p:get_gold() end)
        check("player:get_infamy()",         function() return p:get_infamy() end)
        check("player:get_phys_armor()",     function() return p:get_phys_armor() end)
        check("player:get_mag_armor()",      function() return p:get_mag_armor() end)
        check("player:get_combat_level()",   function() return p:get_combat_level() end)
        check("player:get_profession_level()", function() return p:get_profession_level() end)
        check("player:in_combat()",          function() return p:in_combat() end)
        check("player:is_dead()",            function() return p:is_dead() end)
        check("player:is_frozen()",          function() return p:is_frozen() end)
        check("player:is_moving()",          function() return p:is_moving() end)
        check("player:is_spectator()",       function() return p:is_spectator() end)
        check("player:in_pvp_zone()",        function() return p:in_pvp_zone() end)
        check("player:in_wildlands()",       function() return p:in_wildlands() end)
        check("player:has_target()",         function() return p:has_target() end)
        check("player:get_target_name()",    function() return p:get_target_name() end)
        check("player:get_target_hp()",      function() return p:get_target_hp() end)
        check("player:get_target_distance()", function() return p:get_target_distance() end)
        check("player:get_target_info()",    function() return p:get_target_info() end)
        check("player:get_buffs()",          function() return p:get_buffs() end)
    else
        print("  [FAIL] get_local_player() returned nil")
        fail_count = fail_count + 1
        total_count = total_count + 1
    end
end

do
    local t = core.object_manager.get_target()
    if t then
        section("core.object_manager.get_target()")
        check("target:is_valid()",    function() return t:is_valid() end)
        check("target:get_name()",    function() return t:get_name() end)
        check("target:get_hp()",      function() return t:get_hp() end)
        check("target:get_distance()", function() return t:get_distance() end)
        check("target:get_info()",    function() return t:get_info() end)
        check("target:get_full()",    function() return t:get_full() end)
    else
        section("core.object_manager.get_target()")
        print("  [----] get_target() => nil (no target selected)")
    end
end

-- ── DEBUG (sampling, skip heavy dumps) ──
section("core.debug (sample)")
check("debug.cache_size()",      function() return core.debug.cache_size() end)
check("debug.offset_dump()",     function() return core.debug.offset_dump() end)
check("debug.dump_singletons()", function() return core.debug.dump_singletons() end)
check("debug.dump_assemblies()", function() return core.debug.dump_assemblies() end)

-- ── ENUMS ──
section("enums")
check("enums.job_id.RANGER",            function() return enums.job_id.RANGER end)
check("enums.job_id.ENCHANTER",         function() return enums.job_id.ENCHANTER end)
check("enums.job_id.DEMONKNIGHT",       function() return enums.job_id.DEMONKNIGHT end)
check("enums.spell_category.DAMAGE",    function() return enums.spell_category.DAMAGE end)
check("enums.spell_category.HEAL",      function() return enums.spell_category.HEAL end)
check("enums.buff_type.BUFF",           function() return enums.buff_type.BUFF end)
check("enums.buff_type.IMMUNITY",       function() return enums.buff_type.IMMUNITY end)
check("enums.classification.BOSS",      function() return enums.classification.BOSS end)
check("enums.entity_type.MONSTER",      function() return enums.entity_type.MONSTER end)
check("enums.combat_state.IN_COMBAT",   function() return enums.combat_state.IN_COMBAT end)
check("enums.group_role.DPS",           function() return enums.group_role.DPS end)
check("enums.group_role.TANK",          function() return enums.group_role.TANK end)
check("enums.gather_node_type.HERB",    function() return enums.gather_node_type.HERB end)
check("enums.power_type.MANA",          function() return enums.power_type.MANA end)

-- ═══════════════════════════════════════════════════════════
section("RESULTS")
print("")
print(string.format("  Total tests:  %d", total_count))
print(string.format("  PASS [ OK ]:  %d", pass_count))
print(string.format("  EMPTY [----]: %d", empty_count))
print(string.format("  FAIL [FAIL]:  %d", fail_count))
print("")
if fail_count == 0 then
    print("  All functions callable — no crashes or errors.")
else
    print(string.format("  WARNING: %d function(s) threw errors!", fail_count))
end
print(string.format("  Data coverage: %d/%d (%.1f%%)",
    pass_count, total_count, pass_count / total_count * 100))
print("")
print("  Done. Use 'Copy All' to save the full report.")
