--[[
Render Distance — adjust render distance, camera zoom,
fog distances, and grass density at runtime.
]]

local ethy = require("common/ethy_sdk")
local ui   = core.imgui

ethy.print("=== Render Distance ===")

-- Config
local POLL_INTERVAL = 1.0

-- State
local show_window   = true
local last_poll     = 0
local last_error    = nil

-- Live values
local live = {
    render_dist     = -1,
    grass_density   = -1,
    disable_shadows = -1,
    disable_postproc = -1,
    cam_dist        = -1,
    cam_max_dist    = -1,
    cam_min_dist    = -1,
    fog_start       = -1,
    fog_end         = -1,
}

-- Edit values (separate from live so sliders don't fight reads)
local edit = {}
local edit_dirty = {}

-- IPC availability
local ipc_available    = nil
local ipc_check_time   = 0
local IPC_RETRY        = 5

-- Parse RENDER_SETTINGS response
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

-- Check IPC
local function check_ipc()
    local r = core.send_command("RENDER_SETTINGS")
    if r and not r:find("UNKNOWN_CMD") then
        ipc_available = true
        return true, r
    end
    ipc_available = false
    return false, nil
end

-- Send a set command
local function set_value(cmd_name, value_str)
    if ipc_available == false then return "IPC_UNAVAILABLE" end
    local r = core.send_command(cmd_name .. " " .. value_str)
    if r and r:find("UNKNOWN_CMD") then
        ipc_available = false
        return r
    end
    return r
end

-- Slider helper
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

-- Lock state
local lock_render_dist = false
local lock_render_val  = 10
local lock_cam_max     = false
local lock_cam_max_val = 30.0
local lock_fog         = false
local lock_fog_start_val = 200.0
local lock_fog_end_val   = 800.0

-- Update loop
ethy.on_update(function()
    local now = ethy.now()

    if ipc_available == false then
        if now - ipc_check_time < IPC_RETRY then return end
        ipc_check_time = now
        local ok, resp = check_ipc()
        if ok then
            parse_settings(resp)
            last_error = nil
            ethy.print("[RenderDist] IPC commands now available!")
        else
            last_error = "Rebuild DLL -- RENDER_SETTINGS not available"
        end
        return
    end

    if ipc_available == nil then
        ipc_check_time = now
        local ok, resp = check_ipc()
        if ok then
            parse_settings(resp)
            last_error = nil
        else
            last_error = "Rebuild DLL -- RENDER_SETTINGS not available"
            return
        end
    end

    -- Apply locks every tick
    if lock_render_dist then
        set_value("SET_RENDER_DIST", tostring(lock_render_val))
    end
    if lock_cam_max then
        set_value("SET_CAMERA_MAX_DIST", string.format("%.2f", lock_cam_max_val))
    end
    if lock_fog then
        set_value("SET_FOG_START", string.format("%.1f", lock_fog_start_val))
        set_value("SET_FOG_END", string.format("%.1f", lock_fog_end_val))
    end

    -- Poll at interval
    if now - last_poll < POLL_INTERVAL then return end
    last_poll = now

    local resp = core.send_command("RENDER_SETTINGS")
    local ok, err = parse_settings(resp)
    if not ok then last_error = err else last_error = nil end
end)

-- Render
local function render_window()
    if not show_window then return end

    ui.set_next_window_size(340, 420)
    ui.set_next_window_pos(940, 10)
    local visible, open = ui.begin_window("Render Distance")

    if not open then
        show_window = false
        ui.end_window()
        return
    end

    local draw_ok, draw_err = pcall(function()
        if not visible then return end

        if last_error then
            ui.text_colored(1, 0.3, 0.3, "Error: " .. tostring(last_error))
            ui.spacing()
        end

        -- Render Distance
        ui.text_colored(1, 0.8, 0.2, "-- Render Distance --")
        ui.spacing()
        ui.text(string.format("  Current: %d", live.render_dist))

        local _, rd_dirty = setting_slider_int("##render_dist", live.render_dist, 1, 50)
        ui.same_line()
        if ui.button("Set##rd_btn") and edit["##render_dist"] then
            set_value("SET_RENDER_DIST", tostring(math.floor(edit["##render_dist"])))
            edit_dirty["##render_dist"] = false
        end

        lock_render_val = ui.slider_int("##lock_rd_val", lock_render_val, 1, 50)
        lock_render_dist = ui.checkbox("Lock Render Distance##rd", lock_render_dist)

        ui.spacing()
        ui.separator()
        ui.spacing()

        -- Camera
        ui.text_colored(1, 0.8, 0.2, "-- Camera --")
        ui.spacing()
        ui.text(string.format("  Distance: %.2f  Max: %.2f  Min: %.2f",
            live.cam_dist, live.cam_max_dist, live.cam_min_dist))

        local _, cm_dirty = setting_slider("##cam_max", live.cam_max_dist, 5.0, 100.0)
        ui.same_line()
        if ui.button("Set Max##cm_btn") and edit["##cam_max"] then
            set_value("SET_CAMERA_MAX_DIST", string.format("%.2f", edit["##cam_max"]))
            edit_dirty["##cam_max"] = false
        end

        lock_cam_max_val = ui.slider_float("##lock_cam_val", lock_cam_max_val, 5.0, 100.0)
        lock_cam_max = ui.checkbox("Lock Camera Max Dist##cm", lock_cam_max)

        ui.spacing()
        ui.separator()
        ui.spacing()

        -- Fog
        ui.text_colored(1, 0.8, 0.2, "-- Fog Distance --")
        ui.spacing()
        ui.text(string.format("  Start: %.1f  End: %.1f", live.fog_start, live.fog_end))

        local _, fs_dirty = setting_slider("##fog_start", live.fog_start, 0.0, 2000.0)
        ui.same_line()
        if ui.button("Set##fs_btn") and edit["##fog_start"] then
            set_value("SET_FOG_START", string.format("%.1f", edit["##fog_start"]))
            edit_dirty["##fog_start"] = false
        end

        local _, fe_dirty = setting_slider("##fog_end", live.fog_end, 10.0, 5000.0)
        ui.same_line()
        if ui.button("Set##fe_btn") and edit["##fog_end"] then
            set_value("SET_FOG_END", string.format("%.1f", edit["##fog_end"]))
            edit_dirty["##fog_end"] = false
        end

        lock_fog_start_val = ui.slider_float("##lock_fs_val", lock_fog_start_val, 0.0, 2000.0)
        lock_fog_end_val   = ui.slider_float("##lock_fe_val", lock_fog_end_val, 10.0, 5000.0)
        lock_fog = ui.checkbox("Lock Fog Distances##fg", lock_fog)

        ui.spacing()
        ui.separator()
        ui.spacing()

        -- Graphics toggles
        ui.text_colored(1, 0.8, 0.2, "-- Graphics --")
        ui.spacing()
        ui.text(string.format("  Grass Density: %d", live.grass_density))
        ui.text(string.format("  Shadows: %s", live.disable_shadows == 0 and "ON" or "OFF"))
        ui.text(string.format("  Post Processing: %s", live.disable_postproc == 0 and "ON" or "OFF"))

        local _, gd_dirty = setting_slider_int("##grass_density", live.grass_density, 0, 100)
        ui.same_line()
        if ui.button("Set##gd_btn") and edit["##grass_density"] then
            set_value("SET_GRASS_DENSITY", tostring(math.floor(edit["##grass_density"])))
            edit_dirty["##grass_density"] = false
        end

        ui.spacing()
        ui.separator()
        ui.spacing()

        -- Utility
        if ui.button("Refresh##rd_refresh") then
            local resp = core.send_command("RENDER_SETTINGS")
            local ok, err = parse_settings(resp)
            if not ok then last_error = err else last_error = nil end
            edit_dirty = {}
        end

        ui.same_line()
        if ui.button("Reset Sliders##rd_reset") then
            edit = {}
            edit_dirty = {}
        end

        ui.same_line()
        if ui.button("Dump##rd_dump") then
            local resp = core.send_command("RENDER_SETTINGS")
            ethy.print("[RenderDist] Raw: " .. tostring(resp))
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
    show_window = core.menu.checkbox("rd_show", "Render Distance", show_window)
end)

ethy.print("Render Distance loaded.")
