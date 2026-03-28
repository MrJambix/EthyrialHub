--[[
╔══════════════════════════════════════════════════════════════╗
║    Telegraph Warning — AoE Danger Zone Visualization         ║
║                                                              ║
║  Scans all nearby entities for active spell casts and        ║
║  renders filled ground shapes with countdown timers.         ║
║                                                              ║
║  Uses:                                                       ║
║    core.telegraphs.scan()     — detect active casts          ║
║    core.draw.ground_circle()  — filled circle on ground      ║
║    core.draw.ground_cone()    — filled cone on ground        ║
║    core.graphics.text_3d()    — countdown timer text         ║
║                                                              ║
║  Color coding:                                               ║
║    Red/Orange  = enemy AoE (danger)                          ║
║    Green/Cyan  = friendly / own AoE                          ║
║    Alpha pulses as timer gets close to zero.                 ║
║                                                              ║
║  Mode: DLL Plugin                                            ║
╚══════════════════════════════════════════════════════════════╝
]]

local ethy = require("common/ethy_sdk")

-- ═══════════════════════════════════════════════════════════════
--  CONFIG
-- ═══════════════════════════════════════════════════════════════

local CFG = {
    enabled        = true,
    show_enemy     = true,
    show_friendly  = true,
    show_own       = true,
    show_timer     = true,

    enemy_color    = { 0.95, 0.25, 0.15 },
    friendly_color = { 0.15, 0.80, 0.95 },
    own_color      = { 0.95, 0.85, 0.20 },

    base_alpha     = 0.30,
    urgent_alpha   = 0.55,
    urgent_threshold = 1.5,

    default_radius = 5.0,
    unity_y_offset = 0.12,
    coord_mode     = "unity",
    segments       = 24,
    max_slots      = 16,
}

-- ═══════════════════════════════════════════════════════════════
--  STATE
-- ═══════════════════════════════════════════════════════════════

local active_slots = {}
local my_uid = 0

local telegraph_api_ok = (core.telegraphs and core.telegraphs.scan) ~= nil
local draw_api_ok      = (core.draw and core.draw.ground_circle) ~= nil

-- ═══════════════════════════════════════════════════════════════
--  HELPERS
-- ═══════════════════════════════════════════════════════════════

local function game_to_unity(px, py, pz, mode, y_extra)
    local ex = y_extra or 0
    if mode == "unity" then
        return px, py + ex, pz
    end
    return px, pz + ex, py
end

local function get_alpha(remaining, duration)
    if remaining <= 0 then return CFG.base_alpha end
    if remaining < CFG.urgent_threshold then
        local t = remaining / CFG.urgent_threshold
        return CFG.urgent_alpha + (CFG.base_alpha - CFG.urgent_alpha) * t
    end
    return CFG.base_alpha
end

local function get_color(t)
    local uid = t.uid or 0
    if uid == my_uid then return CFG.own_color end
    return CFG.enemy_color
end

-- ═══════════════════════════════════════════════════════════════
--  UPDATE
-- ═══════════════════════════════════════════════════════════════

local function on_update()
    if not telegraph_api_ok or not draw_api_ok or not CFG.enabled then
        return
    end

    local me = ethy.get_player()
    if me and me.get_uid then
        my_uid = me:get_uid() or 0
    end

    local telegraphs = core.telegraphs.scan()

    local used_slots = {}

    for i, t in ipairs(telegraphs) do
        if i > CFG.max_slots then break end

        local is_own = (t.uid == my_uid)
        if is_own and not CFG.show_own then goto next_tele end
        if not is_own and not CFG.show_enemy then goto next_tele end

        local slot = i - 1
        used_slots[slot] = true

        local radius = (t.radius and t.radius > 0.1) and t.radius or CFG.default_radius
        local remaining = t.remaining or 0
        local duration = t.duration or 1
        local alpha = get_alpha(remaining, duration)
        local col = get_color(t)

        local ux, uy, uz = game_to_unity(
            t.x or 0, t.y or 0, t.z or 0,
            CFG.coord_mode, CFG.unity_y_offset)

        local htype = t.htype or 0
        if htype == 2 or htype == 3 then
            local angle = 90
            local dir = t.dir or 0
            core.draw.ground_cone(slot,
                ux, uy, uz,
                radius, dir, angle,
                col[1], col[2], col[3], alpha,
                CFG.segments)
        else
            core.draw.ground_circle(slot,
                ux, uy, uz,
                radius,
                col[1], col[2], col[3], alpha,
                CFG.segments)
        end

        active_slots[slot] = true
        ::next_tele::
    end

    for slot = 0, CFG.max_slots - 1 do
        if not used_slots[slot] and active_slots[slot] then
            core.draw.ground_hide(slot)
            active_slots[slot] = nil
        end
    end
end

-- ═══════════════════════════════════════════════════════════════
--  RENDER  (overlay timer text)
-- ═══════════════════════════════════════════════════════════════

local cached_telegraphs = {}

local function on_render()
    if not CFG.show_timer or not telegraph_api_ok or not CFG.enabled then return end

    local cam = core.camera.get_parsed()
    if not cam or not cam.x then return end

    local me = ethy.get_player()
    if not me or not me:is_valid() then return end
    local pos = me:get_position()
    if not pos then return end

    core.graphics.set_camera(
        cam.x, cam.z, cam.y,
        pos.x, pos.z, pos.y,
        60)

    local telegraphs = core.telegraphs.scan()
    for i, t in ipairs(telegraphs) do
        if i > CFG.max_slots then break end

        local remaining = t.remaining or 0
        if remaining <= 0 then goto next_txt end

        local is_own = (t.uid == my_uid)
        if is_own and not CFG.show_own then goto next_txt end
        if not is_own and not CFG.show_enemy then goto next_txt end

        local text = string.format("%.1fs", remaining)
        local spell = t.spell or "?"
        if spell ~= "unknown" and spell ~= "?" then
            text = spell .. "\n" .. text
        end

        local ux = t.x or 0
        local uy = (t.z or 0) + 2.0
        local uz = t.y or 0

        local col
        if remaining < CFG.urgent_threshold then
            col = core.graphics.color(255, 60, 60, 230)
        else
            col = core.graphics.color(255, 220, 60, 200)
        end

        core.graphics.text_3d(ux, uy, uz, text, col)
        ::next_txt::
    end
end

-- ═══════════════════════════════════════════════════════════════
--  PLUGIN MENU
-- ═══════════════════════════════════════════════════════════════

local show_settings = false

local function on_render_menu()
    if not telegraph_api_ok then
        core.menu.checkbox("tw_na", "Telegraph API not loaded", false)
        return
    end
    CFG.enabled    = core.menu.checkbox("tw_on",    "Telegraph Warning",  CFG.enabled)
    CFG.show_timer = core.menu.checkbox("tw_timer", "Show Timers",        CFG.show_timer)
    CFG.show_enemy = core.menu.checkbox("tw_enemy", "Show Enemy AoE",    CFG.show_enemy)
    CFG.show_own   = core.menu.checkbox("tw_own",   "Show Own AoE",      CFG.show_own)
    show_settings  = core.menu.checkbox("tw_set",   "Settings Window",   show_settings)
end

-- ═══════════════════════════════════════════════════════════════
--  SETTINGS WINDOW
-- ═══════════════════════════════════════════════════════════════

local win_first = true

local function render_settings()
    if not show_settings then win_first = true; return end
    if win_first then
        core.imgui.set_next_window_size(320, 420)
        core.imgui.set_next_window_pos(350, 80)
        win_first = false
    end

    local vis, open = core.imgui.begin_window("Telegraph Warning — Settings")
    if not open then
        show_settings = false
        core.menu.set_checkbox("tw_set", false)
        core.imgui.end_window()
        return
    end

    if vis then
        if not telegraph_api_ok or not draw_api_ok then
            core.imgui.text_colored(0.97, 0.32, 0.29,
                "Telegraph or Draw API not available.\nRecompile Hub + DLL.")
            core.imgui.end_window()
            return
        end

        core.imgui.text("Visibility")
        CFG.enabled    = core.imgui.checkbox("Enabled##tw",     CFG.enabled)
        CFG.show_enemy = core.imgui.checkbox("Enemy AoE##tw",   CFG.show_enemy)
        CFG.show_own   = core.imgui.checkbox("Own AoE##tw",     CFG.show_own)
        CFG.show_timer = core.imgui.checkbox("Countdown##tw",   CFG.show_timer)
        core.imgui.separator(); core.imgui.spacing()

        core.imgui.text("Appearance")
        CFG.base_alpha       = core.imgui.slider_float("Base Alpha##tw",    CFG.base_alpha,       0.05, 0.8)
        CFG.urgent_alpha     = core.imgui.slider_float("Urgent Alpha##tw",  CFG.urgent_alpha,     0.1, 1.0)
        CFG.urgent_threshold = core.imgui.slider_float("Urgent Time##tw",   CFG.urgent_threshold, 0.5, 5.0)
        CFG.default_radius   = core.imgui.slider_float("Default Radius##tw",CFG.default_radius,   1, 15)
        core.imgui.text("Ground mesh (same as Ground Telegraph)")
        local want_unity = (CFG.coord_mode == "unity")
        local nv = core.imgui.checkbox("Height from game Y (recommended)##tw", want_unity)
        CFG.coord_mode = nv and "unity" or "game_z_up"
        CFG.unity_y_offset = core.imgui.slider_float(
            "Unity Y offset##tw", CFG.unity_y_offset, -3.0, 2.0)
        local seg = core.imgui.slider_float("Detail##tw", CFG.segments + 0.0, 8, 48)
        if seg then CFG.segments = math.floor(seg) end
        core.imgui.separator(); core.imgui.spacing()

        -- Live status
        local telegraphs = core.telegraphs.scan()
        local n = #telegraphs
        if n > 0 then
            core.imgui.text_colored(0.95, 0.70, 0.20,
                string.format("Active telegraphs: %d", n))
            for i, t in ipairs(telegraphs) do
                if i > 8 then
                    core.imgui.text("  ...")
                    break
                end
                core.imgui.text(string.format("  [%d] %s — %s (%.1fs)",
                    t.uid or 0, t.name or "?", t.spell or "?", t.remaining or 0))
            end
        else
            core.imgui.text_colored(0.5, 0.5, 0.5, "No active telegraphs")
        end
    end
    core.imgui.end_window()
end

-- ═══════════════════════════════════════════════════════════════
--  REGISTER
-- ═══════════════════════════════════════════════════════════════

ethy.on_update(on_update)
ethy.on_render(function() on_render(); render_settings() end)
ethy.on_render_menu(on_render_menu)

ethy.print("[TelegraphWarn] Loaded" .. (telegraph_api_ok and "" or " (API not yet available)"))
