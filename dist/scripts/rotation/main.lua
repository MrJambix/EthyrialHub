--[[
Rotation — Build profiles and auto-rotation.
Loads class profiles from builds/ folder and provides
automatic spell rotation with configurable thresholds.
]]

local ethy = require("common/ethy_sdk")
local ui   = core.imgui

ethy.print("=== Rotation ===")

-- Built-in profiles (fallback if no Lua file)
local PROFILES = {
    Enchanter = {
        name = "Enchanter",
        description = "Healer / Support Caster",
        HEAL_HP = 50, DEFENSIVE_HP = 40, EMERGENCY_HP = 20,
        REST_HP = 80, REST_MP = 60, TICK_RATE = 0.3,
        BUFFS = { "Stormshield", "Imbue Body: Streaming Winds", "Imbue Mind: Clarity", "Gust of Alacrity" },
        ROTATION = { "Storm of Haste", "Stormshield", "Debilitating Waters", "Tempest", "Stormbolt" },
        HEAL_SPELLS = { "Stream of Life" },
        DEFENSIVE_SPELLS = { "Stormshield", "Cleansing Waters" },
        REST_SPELL = "Rest", MEDITATION_SPELL = "Leyline Meditation",
    },
    Ranger = {
        name = "Ranger",
        description = "Physical DPS / Ranged",
        HEAL_HP = 40, DEFENSIVE_HP = 30, EMERGENCY_HP = 15,
        REST_HP = 80, REST_MP = 70, TICK_RATE = 0.3,
        BUFFS = {},
        ROTATION = { "Aimed Shot", "Multi-Shot", "Rapid Fire", "Quick Shot" },
        HEAL_SPELLS = {},
        DEFENSIVE_SPELLS = {},
        REST_SPELL = "Rest", MEDITATION_SPELL = "Leyline Meditation",
    },
}

-- Try to load profiles from builds/ folder
local function try_load_profile(name)
    local ok, profile = pcall(function()
        return require("builds/" .. name:lower())
    end)
    if ok and profile then return profile end
    return nil
end

-- State
local show_window      = true
local selected_job     = 0
local JOB_NAMES        = { "Auto-Detect", "Enchanter", "Ranger", "Assassin", "Spellblade",
                            "Earthguard", "Guardian", "Illusionist", "Druid",
                            "Shadowcaster", "Berserker", "Brawler", "Demonknight" }
local JOB_LIST_STR     = table.concat(JOB_NAMES, "\n")

-- Rotation state
local running          = false
local mode             = 0  -- 0=DPS, 1=Heal
local stats            = { casts = 0, kills = 0, heals = 0 }
local last_tick        = 0
local rotation_idx     = 1
local last_target_time = 0
local gcd_until        = 0

-- Get active profile
local function get_profile()
    local job_name = nil
    if selected_job == 0 then
        -- Auto-detect from player
        local player = ethy.get_player()
        if player then
            pcall(function()
                local r = core.send_command("PLAYER_ALL")
                if r then
                    local cls = r:match("class=(%w+)")
                    if cls then job_name = cls end
                end
            end)
        end
    else
        job_name = JOB_NAMES[selected_job + 1]
    end

    if not job_name then return nil end

    -- Try loading from file first, then fall back to built-in
    local profile = try_load_profile(job_name) or PROFILES[job_name]
    return profile
end

-- Rotation logic
local function do_rotation_tick(profile)
    if not profile or not profile.ROTATION then return end
    local now = ethy.now()

    -- Check GCD
    if now < gcd_until then return end

    local player = ethy.get_player()
    if not player then return end

    local hp = 100
    local mp = 100
    local in_combat = false
    pcall(function() hp = player:get_hp() end)
    pcall(function() mp = player:get_mp() end)
    pcall(function() in_combat = player:in_combat() end)

    local tick_rate = profile.TICK_RATE or 0.3

    -- Rest if needed (out of combat)
    if not in_combat then
        if hp < (profile.REST_HP or 80) and profile.REST_SPELL then
            pcall(function() core.spell_book.cast_spell_ooc(profile.REST_SPELL) end)
            gcd_until = now + 1.0
            return
        end
        if mp < (profile.REST_MP or 60) and profile.MEDITATION_SPELL then
            pcall(function() core.spell_book.cast_spell_ooc(profile.MEDITATION_SPELL) end)
            gcd_until = now + 1.0
            return
        end
    end

    -- Heal check (heal mode or emergency)
    if mode == 1 or hp < (profile.EMERGENCY_HP or 20) then
        if profile.HEAL_SPELLS then
            for _, spell in ipairs(profile.HEAL_SPELLS) do
                local ready = false
                pcall(function() ready = core.spell_book.is_spell_ready(spell) end)
                if ready then
                    pcall(function() core.spell_book.cast_spell(spell) end)
                    stats.heals = stats.heals + 1
                    gcd_until = now + tick_rate
                    return
                end
            end
        end
    end

    -- Defensive check
    if hp < (profile.DEFENSIVE_HP or 40) and profile.DEFENSIVE_SPELLS then
        for _, spell in ipairs(profile.DEFENSIVE_SPELLS) do
            local ready = false
            pcall(function() ready = core.spell_book.is_spell_ready(spell) end)
            if ready then
                pcall(function() core.spell_book.cast_spell(spell) end)
                stats.casts = stats.casts + 1
                gcd_until = now + tick_rate
                return
            end
        end
    end

    -- Target if needed
    if in_combat or now - last_target_time > 2.0 then
        pcall(function()
            local has = player:has_target()
            if not has then
                core.send_command("TARGET_NEAREST")
                last_target_time = now
            end
        end)
    end

    -- DPS rotation
    local rot = profile.ROTATION
    if not rot or #rot == 0 then return end

    -- Try each spell in rotation starting from current index
    for i = 1, #rot do
        local idx = ((rotation_idx - 1 + i - 1) % #rot) + 1
        local spell = rot[idx]
        local ready = false
        pcall(function() ready = core.spell_book.is_spell_ready(spell) end)
        if ready then
            pcall(function() core.spell_book.cast_spell(spell) end)
            stats.casts = stats.casts + 1
            rotation_idx = (idx % #rot) + 1
            gcd_until = now + tick_rate
            return
        end
    end
end

-- Update
ethy.on_update(function()
    if not running then return end
    local now = ethy.now()
    local profile = get_profile()
    if not profile then return end
    local tick = profile.TICK_RATE or 0.3
    if now - last_tick < tick then return end
    last_tick = now
    do_rotation_tick(profile)
end)

-- Render
local function render_window_fn()
    if not show_window then return end

    ui.set_next_window_size(400, 480)
    ui.set_next_window_pos(600, 50)
    local visible, open = ui.begin_window("Rotation")

    if not open then
        show_window = false
        ui.end_window()
        return
    end

    local draw_ok, draw_err = pcall(function()
        if not visible then return end

        ui.text_colored(1, 0.8, 0.2, "-- Build Profile --")
        ui.spacing()

        selected_job = ui.combo("Job##rot", selected_job, JOB_LIST_STR)

        local profile = get_profile()
        if not profile then
            ui.text_colored(0.6, 0.6, 0.6, "No profile found for this class")
            ui.end_window()
            return
        end

        ui.text(string.format("Profile: %s", profile.name or "Unknown"))
        if profile.description then
            ui.text(profile.description)
        end

        if running then
            ui.spacing()
            ui.text_colored(0.28, 0.78, 0.38, "RUNNING")
            ui.text(string.format("  Casts: %d  Heals: %d", stats.casts, stats.heals))
        end

        -- Rotation priority
        ui.spacing()
        ui.separator()
        ui.text_colored(0.7, 0.9, 1.0, "Rotation Priority:")
        if profile.ROTATION then
            for i, spell in ipairs(profile.ROTATION) do
                local ready = false
                pcall(function() ready = core.spell_book.is_spell_ready(spell) end)
                if ready then
                    ui.text_colored(0.25, 0.72, 0.31, string.format("  %d. %s", i, spell))
                else
                    ui.text_colored(0.6, 0.35, 0.35, string.format("  %d. %s", i, spell))
                end
            end
        end

        if profile.HEAL_SPELLS and #profile.HEAL_SPELLS > 0 then
            ui.spacing()
            ui.text_colored(0.7, 0.9, 1.0, "Heal Spells:")
            for _, s in ipairs(profile.HEAL_SPELLS) do
                ui.text("  " .. s)
            end
        end

        if profile.DEFENSIVE_SPELLS and #profile.DEFENSIVE_SPELLS > 0 then
            ui.spacing()
            ui.text_colored(0.7, 0.9, 1.0, "Defensive Spells:")
            for _, s in ipairs(profile.DEFENSIVE_SPELLS) do
                ui.text("  " .. s)
            end
        end

        if profile.BUFFS and #profile.BUFFS > 0 then
            ui.spacing()
            ui.text_colored(0.7, 0.9, 1.0, "Buffs:")
            for _, s in ipairs(profile.BUFFS) do
                ui.text("  " .. s)
            end
        end

        -- Thresholds
        ui.spacing()
        ui.separator()
        ui.text_colored(0.7, 0.9, 1.0, "Thresholds:")
        ui.text(string.format("  Heal HP: %d%%  Defensive HP: %d%%  Emergency HP: %d%%",
            profile.HEAL_HP or 50, profile.DEFENSIVE_HP or 40, profile.EMERGENCY_HP or 20))
        ui.text(string.format("  Rest HP: %d%%  Rest MP: %d%%",
            profile.REST_HP or 80, profile.REST_MP or 60))

        -- Mode selector
        ui.spacing()
        mode = ui.combo("Mode##rot", mode, "DPS\nHeal")

        -- Start/Stop
        ui.spacing()
        if not running then
            if ui.button("Start Rotation##rot") then
                running = true
                rotation_idx = 1
                gcd_until = 0
                stats = { casts = 0, kills = 0, heals = 0 }
                ethy.print("[Rotation] Started - " .. (profile.name or "Unknown"))
            end
        else
            if ui.button("Stop Rotation##rot") then
                running = false
                ethy.print("[Rotation] Stopped")
            end
        end

        ui.same_line()
        if ui.button("Reset Stats##rot") then
            stats = { casts = 0, kills = 0, heals = 0 }
        end
    end)

    ui.end_window()

    if not draw_ok then
        ethy.printf("[Rotation] UI error: %s", tostring(draw_err))
    end
end

ethy.on_render(function()
    render_window_fn()
end)

ethy.on_render_menu(function()
    show_window = core.menu.checkbox("rot_show", "Rotation", show_window)
end)

ethy.print("Rotation loaded. Select a job and click Start.")
