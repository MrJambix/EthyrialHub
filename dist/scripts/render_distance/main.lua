--[[
╔══════════════════════════════════════════════════════════════╗
║           Render Distance & Performance Optimizer            ║
║                                                              ║
║  Full control over Unity render pipeline settings:           ║
║  - Render distance / far clip / shadow distance              ║
║  - LOD bias, fog, quality level, VSync                       ║
║  - Shader warmup, scene renderer caching                     ║
║  - Camera FOV, pixel lights, grass density                   ║
╚══════════════════════════════════════════════════════════════╝
]]

local ethy = require("common/ethy_sdk")
local ui   = core.imgui

ethy.print("=== Render Distance & Performance ===")

-- ═══════════════════════════════════════════════════════════════
--  CONFIG
-- ═══════════════════════════════════════════════════════════════

local POLL_INTERVAL = 1.0
local IPC_RETRY     = 5

-- ═══════════════════════════════════════════════════════════════
--  STATE
-- ═══════════════════════════════════════════════════════════════

local show_window     = true
local last_poll       = 0
local last_error      = nil
local ipc_available   = nil
local ipc_check_time  = 0
local active_tab      = 1  -- 1=Render, 2=Camera, 3=Performance, 4=Warmup

-- Live values from RENDER_SETTINGS
local live = {
    render_dist   = -1,
    lod_bias      = -1,
    shadow_quality = -1,
    shadow_dist   = -1,
    quality_level = -1,
    vsync         = -1,
    max_queued    = -1,
    pixel_lights  = -1,
    fog_start     = -1,
    fog_end       = -1,
    fog_density   = -1,
    fog_enabled   = -1,
    far_clip      = -1,
    near_clip     = -1,
    fov           = -1,
    -- Camera (from existing CAMERA command)
    cam_dist      = -1,
    cam_max_dist  = -1,
    cam_min_dist  = -1,
    -- Grass (separate command)
    grass_density = -1,
}

-- Edit values (separate so sliders don't fight reads)
local edit = {}
local edit_dirty = {}

-- Lock state
local locks = {
    render_dist  = false, render_dist_val  = 200,
    far_clip     = false, far_clip_val     = 1000,
    shadow_dist  = false, shadow_dist_val  = 150,
    fog_start    = false, fog_start_val    = 200,
    fog_end      = false, fog_end_val      = 800,
    lod_bias     = false, lod_bias_val     = 2.0,
    fov          = false, fov_val          = 60,
    cam_max      = false, cam_max_val      = 30,
}

-- Warmup state
local warmup_done       = false
local warmup_time       = nil
local cache_stats       = nil
local cache_time        = nil
local auto_warmup       = false
local warmup_on_load    = false
local warmup_ran        = false

-- ═══════════════════════════════════════════════════════════════
--  PARSE
-- ═══════════════════════════════════════════════════════════════

local function parse_settings(resp)
    if not resp or resp == "" or resp:find("^ERR") or resp:find("^NO_") or resp:find("^IL2CPP") then
        return false, resp
    end
    for k, v in resp:gmatch("([%w_]+)=([^|]+)") do
        local num = tonumber(v)
        if live[k] ~= nil then
            live[k] = num or -1
        end
    end
    return true, nil
end

local function parse_cache(resp)
    if not resp or resp:find("^ERR") or resp:find("^FAIL") then return nil end
    local stats = {}
    for k, v in resp:gmatch("([%w_]+)=([^|]+)") do
        stats[k] = tonumber(v) or 0
    end
    return stats
end

-- ═══════════════════════════════════════════════════════════════
--  IPC
-- ═══════════════════════════════════════════════════════════════

local function check_ipc()
    local r = core.send_command("RENDER_SETTINGS")
    if r and not r:find("UNKNOWN_CMD") then
        ipc_available = true
        return true, r
    end
    ipc_available = false
    return false, nil
end

local function set_value(cmd_name, value_str)
    if ipc_available == false then return "IPC_UNAVAILABLE" end
    local r = core.send_command(cmd_name .. " " .. value_str)
    return r or ""
end

-- ═══════════════════════════════════════════════════════════════
--  SLIDER HELPERS
-- ═══════════════════════════════════════════════════════════════

local function setting_slider(id, live_value, min_val, max_val)
    if edit[id] == nil or not edit_dirty[id] then
        edit[id] = live_value
    end
    local new_val = ui.slider_float(id, edit[id], min_val, max_val)
    if new_val ~= edit[id] then
        edit[id] = new_val
        edit_dirty[id] = true
    end
    return new_val, edit_dirty[id]
end

local function setting_slider_int(id, live_value, min_val, max_val)
    if edit[id] == nil or not edit_dirty[id] then
        edit[id] = live_value
    end
    local new_val = ui.slider_int(id, math.floor(edit[id]), min_val, max_val)
    if new_val ~= edit[id] then
        edit[id] = new_val
        edit_dirty[id] = true
    end
    return new_val, edit_dirty[id]
end

-- ═══════════════════════════════════════════════════════════════
--  UPDATE
-- ═══════════════════════════════════════════════════════════════

ethy.on_update(function()
    local now = ethy.now()

    -- Check IPC availability
    if ipc_available == nil then
        ipc_check_time = now
        local ok, resp = check_ipc()
        if ok then
            parse_settings(resp)
            last_error = nil
            ethy.print("[RenderDist] IPC commands available!")
        else
            last_error = "Rebuild DLL -- RENDER_SETTINGS not available"
            return
        end
    end

    -- Auto-warmup on first successful connection
    if auto_warmup and not warmup_ran and ipc_available then
        warmup_ran = true
        local r = core.send_command("SHADER_WARMUP")
        if r and r == "OK" then
            warmup_done = true
            warmup_time = now
            ethy.print("[RenderDist] Auto shader warmup complete")
        end
        local cr = core.send_command("CACHE_RENDERERS")
        cache_stats = parse_cache(cr)
        if cache_stats then cache_time = now end
    end

    -- Apply locks every tick
    if locks.render_dist then
        set_value("SET_RENDER_DIST", string.format("%.1f", locks.render_dist_val))
    end
    if locks.far_clip then
        set_value("SET_FAR_CLIP", string.format("%.1f", locks.far_clip_val))
    end
    if locks.shadow_dist then
        set_value("SET_SHADOW_DIST", string.format("%.1f", locks.shadow_dist_val))
    end
    if locks.fog_start then
        set_value("SET_FOG_START", string.format("%.1f", locks.fog_start_val))
    end
    if locks.fog_end then
        set_value("SET_FOG_END", string.format("%.1f", locks.fog_end_val))
    end
    if locks.lod_bias then
        set_value("SET_LOD_BIAS", string.format("%.2f", locks.lod_bias_val))
    end
    if locks.fov then
        set_value("SET_FOV", string.format("%.1f", locks.fov_val))
    end
    if locks.cam_max then
        set_value("SET_CAMERA_MAX_DIST", string.format("%.2f", locks.cam_max_val))
    end

    -- Poll at interval
    if now - last_poll < POLL_INTERVAL then return end
    last_poll = now

    local resp = core.send_command("RENDER_SETTINGS")
    local ok, err = parse_settings(resp)
    if not ok then last_error = err else last_error = nil end

    -- Also poll camera
    local cam = core.send_command("CAMERA")
    if cam and cam ~= "" and not cam:find("^ERR") then
        local parts = {}
        for p in cam:gmatch("[^,]+") do parts[#parts + 1] = tonumber(p) end
        if #parts >= 6 then
            live.cam_dist     = parts[4]
            live.cam_max_dist = -1  -- not in CAMERA response
            live.cam_min_dist = -1
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════
--  RENDER — TAB: Render Distance & Quality
-- ═══════════════════════════════════════════════════════════════

local function render_tab_distance()
    ui.text_colored(1, 0.8, 0.2, "-- Render Distance --")
    ui.spacing()

    -- Shadow distance (primary render distance proxy)
    ui.text(string.format("  Shadow Distance: %.1f", live.shadow_dist))
    local _, sd_dirty = setting_slider("##shadow_dist", live.shadow_dist, 10, 500)
    ui.same_line()
    if ui.button("Set##sd_btn") and edit["##shadow_dist"] then
        set_value("SET_SHADOW_DIST", string.format("%.1f", edit["##shadow_dist"]))
        edit_dirty["##shadow_dist"] = false
    end
    locks.shadow_dist_val = ui.slider_float("Lock##sd_lock_val", locks.shadow_dist_val, 10, 500)
    locks.shadow_dist = ui.checkbox("Lock Shadow Distance##sd", locks.shadow_dist)

    ui.spacing()

    -- Far clip plane
    ui.text(string.format("  Far Clip Plane: %.1f", live.far_clip))
    local _, fc_dirty = setting_slider("##far_clip", live.far_clip, 50, 5000)
    ui.same_line()
    if ui.button("Set##fc_btn") and edit["##far_clip"] then
        set_value("SET_FAR_CLIP", string.format("%.1f", edit["##far_clip"]))
        edit_dirty["##far_clip"] = false
    end
    locks.far_clip_val = ui.slider_float("Lock##fc_lock_val", locks.far_clip_val, 50, 5000)
    locks.far_clip = ui.checkbox("Lock Far Clip##fc", locks.far_clip)

    ui.spacing()
    ui.separator()
    ui.spacing()

    -- LOD Bias
    ui.text_colored(1, 0.8, 0.2, "-- LOD & Quality --")
    ui.spacing()

    ui.text(string.format("  LOD Bias: %.2f  (higher = more detail)", live.lod_bias))
    local _, lb_dirty = setting_slider("##lod_bias", live.lod_bias, 0.1, 10.0)
    ui.same_line()
    if ui.button("Set##lb_btn") and edit["##lod_bias"] then
        set_value("SET_LOD_BIAS", string.format("%.2f", edit["##lod_bias"]))
        edit_dirty["##lod_bias"] = false
    end
    locks.lod_bias_val = ui.slider_float("Lock##lb_lock_val", locks.lod_bias_val, 0.1, 10.0)
    locks.lod_bias = ui.checkbox("Lock LOD Bias##lb", locks.lod_bias)

    ui.spacing()

    -- Quality Level
    ui.text(string.format("  Quality Level: %d", live.quality_level))
    local _, ql_dirty = setting_slider_int("##quality_level", live.quality_level, 0, 5)
    ui.same_line()
    if ui.button("Set##ql_btn") and edit["##quality_level"] then
        set_value("SET_QUALITY_LEVEL", tostring(math.floor(edit["##quality_level"])))
        edit_dirty["##quality_level"] = false
    end

    ui.spacing()

    -- Shadow Quality
    local sq_labels = { "OFF", "Hard Only", "All" }
    local sq_label = sq_labels[(live.shadow_quality or 0) + 1] or "?"
    ui.text(string.format("  Shadow Quality: %s (%d)", sq_label, live.shadow_quality))
    local _, sqd = setting_slider_int("##shadow_quality", live.shadow_quality, 0, 2)
    ui.same_line()
    if ui.button("Set##sq_btn") and edit["##shadow_quality"] then
        set_value("SET_SHADOW_QUALITY", tostring(math.floor(edit["##shadow_quality"])))
        edit_dirty["##shadow_quality"] = false
    end

    ui.spacing()

    -- Pixel Light Count
    ui.text(string.format("  Pixel Lights: %d", live.pixel_lights))
    local _, pl_dirty = setting_slider_int("##pixel_lights", live.pixel_lights, 0, 8)
    ui.same_line()
    if ui.button("Set##pl_btn") and edit["##pixel_lights"] then
        set_value("SET_PIXEL_LIGHTS", tostring(math.floor(edit["##pixel_lights"])))
        edit_dirty["##pixel_lights"] = false
    end
end

-- ═══════════════════════════════════════════════════════════════
--  RENDER — TAB: Camera & Fog
-- ═══════════════════════════════════════════════════════════════

local function render_tab_camera()
    ui.text_colored(1, 0.8, 0.2, "-- Camera --")
    ui.spacing()

    -- FOV
    ui.text(string.format("  Field of View: %.1f", live.fov))
    local _, fov_dirty = setting_slider("##fov", live.fov, 30, 120)
    ui.same_line()
    if ui.button("Set##fov_btn") and edit["##fov"] then
        set_value("SET_FOV", string.format("%.1f", edit["##fov"]))
        edit_dirty["##fov"] = false
    end
    locks.fov_val = ui.slider_float("Lock##fov_lock_val", locks.fov_val, 30, 120)
    locks.fov = ui.checkbox("Lock FOV##fov", locks.fov)

    ui.spacing()

    -- Camera zoom
    ui.text(string.format("  Camera Distance: %.2f", live.cam_dist))
    local _, cm_dirty = setting_slider("##cam_max", 30, 5, 100)
    ui.same_line()
    if ui.button("Set Max##cm_btn") and edit["##cam_max"] then
        set_value("SET_CAMERA_MAX_DIST", string.format("%.2f", edit["##cam_max"]))
        edit_dirty["##cam_max"] = false
    end
    locks.cam_max_val = ui.slider_float("Lock##cam_lock_val", locks.cam_max_val, 5, 100)
    locks.cam_max = ui.checkbox("Lock Camera Max##cm", locks.cam_max)

    ui.spacing()

    ui.text(string.format("  Near Clip: %.2f", live.near_clip))

    ui.spacing()
    ui.separator()
    ui.spacing()

    -- Fog
    ui.text_colored(1, 0.8, 0.2, "-- Fog --")
    ui.spacing()

    local fog_str = live.fog_enabled == 1 and "ON" or (live.fog_enabled == 0 and "OFF" or "?")
    ui.text(string.format("  Fog: %s  Density: %.4f", fog_str, live.fog_density))

    if ui.button("Fog ON##fog_on") then set_value("SET_FOG_ENABLED", "1") end
    ui.same_line()
    if ui.button("Fog OFF##fog_off") then set_value("SET_FOG_ENABLED", "0") end

    ui.spacing()

    ui.text(string.format("  Start: %.1f  End: %.1f", live.fog_start, live.fog_end))

    local _, fs_dirty = setting_slider("##fog_start", live.fog_start, 0, 2000)
    ui.same_line()
    if ui.button("Set##fs_btn") and edit["##fog_start"] then
        set_value("SET_FOG_START", string.format("%.1f", edit["##fog_start"]))
        edit_dirty["##fog_start"] = false
    end

    local _, fe_dirty = setting_slider("##fog_end", live.fog_end, 10, 5000)
    ui.same_line()
    if ui.button("Set##fe_btn") and edit["##fog_end"] then
        set_value("SET_FOG_END", string.format("%.1f", edit["##fog_end"]))
        edit_dirty["##fog_end"] = false
    end

    locks.fog_start_val = ui.slider_float("Lock Start##fs_lock", locks.fog_start_val, 0, 2000)
    locks.fog_end_val   = ui.slider_float("Lock End##fe_lock", locks.fog_end_val, 10, 5000)
    locks.fog_start = ui.checkbox("Lock Fog Start##fs", locks.fog_start)
    ui.same_line()
    locks.fog_end = ui.checkbox("Lock End##fe", locks.fog_end)

    ui.spacing()

    -- Fog Density
    local _, fd_dirty = setting_slider("##fog_density", live.fog_density, 0, 0.1)
    ui.same_line()
    if ui.button("Set##fd_btn") and edit["##fog_density"] then
        set_value("SET_FOG_DENSITY", string.format("%.4f", edit["##fog_density"]))
        edit_dirty["##fog_density"] = false
    end
end

-- ═══════════════════════════════════════════════════════════════
--  RENDER — TAB: Performance
-- ═══════════════════════════════════════════════════════════════

local function render_tab_performance()
    ui.text_colored(1, 0.8, 0.2, "-- VSync & Frame Pacing --")
    ui.spacing()

    local vsync_labels = { [0] = "OFF", [1] = "Every V-Blank", [2] = "Every 2nd" }
    local vs_label = vsync_labels[live.vsync] or "?"
    ui.text(string.format("  VSync: %s (%d)", vs_label, live.vsync))
    local _, vs_dirty = setting_slider_int("##vsync", live.vsync, 0, 2)
    ui.same_line()
    if ui.button("Set##vs_btn") and edit["##vsync"] then
        set_value("SET_VSYNC", tostring(math.floor(edit["##vsync"])))
        edit_dirty["##vsync"] = false
    end

    ui.spacing()
    ui.text(string.format("  Max Queued Frames: %d", live.max_queued))

    ui.spacing()
    ui.separator()
    ui.spacing()

    ui.text_colored(1, 0.8, 0.2, "-- Grass Density --")
    ui.spacing()
    ui.text(string.format("  Current: %.4f", live.grass_density))
    local _, gd_dirty = setting_slider("##grass_density", live.grass_density, 0, 1.0)
    ui.same_line()
    if ui.button("Set##gd_btn") and edit["##grass_density"] then
        set_value("SET_GRASS_DENSITY", string.format("%.4f", edit["##grass_density"]))
        edit_dirty["##grass_density"] = false
    end

    ui.spacing()
    ui.separator()
    ui.spacing()

    -- Quick presets
    ui.text_colored(1, 0.8, 0.2, "-- Quick Presets --")
    ui.spacing()

    if ui.button("Max Performance##preset_perf") then
        set_value("SET_SHADOW_QUALITY", "0")
        set_value("SET_SHADOW_DIST", "50")
        set_value("SET_LOD_BIAS", "0.5")
        set_value("SET_PIXEL_LIGHTS", "1")
        set_value("SET_FOG_ENABLED", "1")
        set_value("SET_FOG_END", "300")
        set_value("SET_VSYNC", "0")
        ethy.print("[RenderDist] Applied: Max Performance preset")
    end

    ui.same_line()
    if ui.button("Max Quality##preset_qual") then
        set_value("SET_SHADOW_QUALITY", "2")
        set_value("SET_SHADOW_DIST", "300")
        set_value("SET_LOD_BIAS", "4.0")
        set_value("SET_PIXEL_LIGHTS", "4")
        set_value("SET_FAR_CLIP", "2000")
        set_value("SET_VSYNC", "1")
        ethy.print("[RenderDist] Applied: Max Quality preset")
    end

    ui.same_line()
    if ui.button("Max View##preset_view") then
        set_value("SET_FAR_CLIP", "5000")
        set_value("SET_SHADOW_DIST", "500")
        set_value("SET_LOD_BIAS", "8.0")
        set_value("SET_FOG_ENABLED", "0")
        set_value("SET_CAMERA_MAX_DIST", "80")
        ethy.print("[RenderDist] Applied: Max View Distance preset")
    end

    ui.spacing()
    if ui.button("Balanced##preset_bal") then
        set_value("SET_SHADOW_QUALITY", "2")
        set_value("SET_SHADOW_DIST", "150")
        set_value("SET_LOD_BIAS", "2.0")
        set_value("SET_PIXEL_LIGHTS", "2")
        set_value("SET_FAR_CLIP", "1000")
        set_value("SET_FOG_END", "800")
        set_value("SET_VSYNC", "1")
        ethy.print("[RenderDist] Applied: Balanced preset")
    end
end

-- ═══════════════════════════════════════════════════════════════
--  RENDER — TAB: Warmup & Cache
-- ═══════════════════════════════════════════════════════════════

local function render_tab_warmup()
    ui.text_colored(1, 0.8, 0.2, "-- Shader Warmup --")
    ui.spacing()
    ui.text_colored(0.6, 0.8, 1.0,
        "  Pre-compiles shader variants so first-time")
    ui.text_colored(0.6, 0.8, 1.0,
        "  rendering of materials doesn't cause stutters.")
    ui.spacing()

    if warmup_done then
        local ago = warmup_time and string.format("%.0fs ago", ethy.now() - warmup_time) or ""
        ui.text_colored(0.4, 0.9, 0.5,
            string.format("  Shaders warmed up! (%s)", ago))
    else
        ui.text_colored(0.95, 0.7, 0.2, "  Shaders not warmed up yet")
    end

    ui.spacing()

    if ui.button("Warmup Shaders##warmup_btn") then
        local r = core.send_command("SHADER_WARMUP")
        if r == "OK" then
            warmup_done = true
            warmup_time = ethy.now()
            ethy.print("[RenderDist] Shader warmup complete!")
        else
            ethy.printf("[RenderDist] Shader warmup failed: %s", tostring(r))
        end
    end

    ui.spacing()
    auto_warmup = ui.checkbox("Auto-warmup on load##auto_warm", auto_warmup)

    ui.spacing()
    ui.separator()
    ui.spacing()

    ui.text_colored(1, 0.8, 0.2, "-- Scene Renderer Cache --")
    ui.spacing()
    ui.text_colored(0.6, 0.8, 1.0,
        "  Scans all renderers in the scene to build")
    ui.text_colored(0.6, 0.8, 1.0,
        "  a metadata cache for faster lookups.")
    ui.spacing()

    if cache_stats then
        local ago = cache_time and string.format("%.0fs ago", ethy.now() - cache_time) or ""
        ui.text_colored(0.4, 0.9, 0.5,
            string.format("  Cached! (%s)", ago))
        ui.text(string.format("    Total Renderers: %d", cache_stats.renderers or 0))
        ui.text(string.format("    Active: %d", cache_stats.active or 0))
        ui.text(string.format("    Materials: %d", cache_stats.materials or 0))
    else
        ui.text_colored(0.5, 0.5, 0.5, "  No cache built yet")
    end

    ui.spacing()

    if ui.button("Cache Scene##cache_btn") then
        local r = core.send_command("CACHE_RENDERERS")
        cache_stats = parse_cache(r)
        if cache_stats then
            cache_time = ethy.now()
            ethy.printf("[RenderDist] Scene cached: %d renderers, %d active",
                cache_stats.renderers or 0, cache_stats.active or 0)
        else
            ethy.printf("[RenderDist] Cache failed: %s", tostring(r))
        end
    end

    ui.spacing()
    ui.separator()
    ui.spacing()

    ui.text_colored(1, 0.8, 0.2, "-- What This Does --")
    ui.spacing()
    ui.text_colored(0.5, 0.7, 0.9, "  Shader Warmup:")
    ui.text_colored(0.6, 0.6, 0.6, "    Compiles all shader variants upfront")
    ui.text_colored(0.6, 0.6, 0.6, "    so new effects don't stutter on first use.")
    ui.spacing()
    ui.text_colored(0.5, 0.7, 0.9, "  Scene Cache:")
    ui.text_colored(0.6, 0.6, 0.6, "    Enumerates renderers + materials for")
    ui.text_colored(0.6, 0.6, 0.6, "    faster entity scans and draw call analysis.")
    ui.spacing()
    ui.text_colored(0.5, 0.7, 0.9, "  What you CANNOT do:")
    ui.text_colored(0.6, 0.6, 0.6, "    - Render everything once and reuse it")
    ui.text_colored(0.6, 0.6, 0.6, "    - Stop Unity from re-drawing visible objects")
    ui.text_colored(0.6, 0.6, 0.6, "    - Bake world geometry into static cache")
end

-- ═══════════════════════════════════════════════════════════════
--  MAIN RENDER
-- ═══════════════════════════════════════════════════════════════

local win_first = true

local function render_window()
    if not show_window then return end

    if win_first then
        ui.set_next_window_size(380, 520)
        ui.set_next_window_pos(940, 10)
        win_first = false
    end

    local visible, open = ui.begin_window("Render & Performance")

    if not open then
        show_window = false
        ui.end_window()
        return
    end

    local draw_ok, draw_err = pcall(function()
        if not visible then return end

        -- Error banner
        if last_error then
            ui.text_colored(1, 0.3, 0.3, "Error: " .. tostring(last_error))
            ui.spacing()
        end

        -- Tab bar
        local tab_names = { "Render", "Camera", "Perf", "Warmup" }
        for i, name in ipairs(tab_names) do
            if i > 1 then ui.same_line() end
            if active_tab == i then
                ui.text_colored(0.3, 0.9, 0.5, "[" .. name .. "]")
            else
                if ui.button(name .. "##tab_" .. tostring(i)) then
                    active_tab = i
                end
            end
        end

        ui.spacing()
        ui.separator()
        ui.spacing()

        -- Tab content
        if active_tab == 1 then
            render_tab_distance()
        elseif active_tab == 2 then
            render_tab_camera()
        elseif active_tab == 3 then
            render_tab_performance()
        elseif active_tab == 4 then
            render_tab_warmup()
        end

        -- Bottom utility bar
        ui.spacing()
        ui.separator()
        ui.spacing()

        if ui.button("Refresh##rd_refresh") then
            local resp = core.send_command("RENDER_SETTINGS")
            local ok, err = parse_settings(resp)
            if not ok then last_error = err else last_error = nil end
            -- Also refresh grass
            local gd = core.send_command("GRASS_DENSITY")
            if gd and not gd:find("^ERR") and not gd:find("^FAIL") then
                live.grass_density = tonumber(gd) or -1
            end
            edit_dirty = {}
        end

        ui.same_line()
        if ui.button("Reset##rd_reset") then
            edit = {}
            edit_dirty = {}
        end

        ui.same_line()
        if ui.button("Dump##rd_dump") then
            local resp = core.send_command("RENDER_SETTINGS")
            ethy.print("[RenderDist] Raw: " .. tostring(resp))
        end

        -- Active locks summary
        local active_locks = {}
        for k, v in pairs(locks) do
            if type(v) == "boolean" and v then
                active_locks[#active_locks + 1] = k
            end
        end
        if #active_locks > 0 then
            ui.spacing()
            ui.text_colored(0.95, 0.7, 0.2,
                string.format("  Locks active: %s", table.concat(active_locks, ", ")))
        end
    end)

    ui.end_window()

    if not draw_ok then
        ethy.printf("[RenderDist] UI error: %s", tostring(draw_err))
    end
end

ethy.on_render(function()
    render_window()
end)

ethy.on_render_menu(function()
    show_window = core.menu.checkbox("rd_show", "Render & Perf", show_window)
end)

ethy.print("Render Distance & Performance loaded.")
