--[[
╔══════════════════════════════════════════════════════════════╗
║    Ground Telegraph — Filled Shapes on the Game Floor        ║
║                                                              ║
║  Draws solid, semi-transparent circles and cones directly    ║
║  in the game world using Unity MeshRenderer — the same       ║
║  visual style as boss AoE telegraphs and entity rings.       ║
║                                                              ║
║  API used:                                                   ║
║    core.draw.ground_circle(slot, x,y,z, radius, r,g,b,a)    ║
║    core.draw.ground_cone(slot, x,y,z, radius, yaw, angle,   ║
║                           r,g,b,a, segments)                 ║
║    core.draw.ground_hide(slot)                               ║
║    core.draw.ground_clear()                                  ║
║                                                              ║
║  core.draw.ground_* expects Unity world space (Y up, mesh    ║
║  on the horizontal XZ plane at that Y).                      ║
║                                                              ║
║  Default (verified via debug logs): player height tracks      ║
║  game Y; game Z was ~1.0 flat while Y moved with elevation.  ║
║  Use coord "unity": Unity (X,Y,Z) = (game.x, game.y, game.z). ║
║  Legacy "game_z_up": (game.x, game.z, game.y) for old tests. ║
║                                                              ║
║  If the ring floats above the floor, the pivot is usually    ║
║  at the torso — use a negative "Unity Y offset" to drop    ║
║  the mesh toward the feet.                                   ║
║                                                              ║
║  Mode: DLL Plugin                                            ║
╚══════════════════════════════════════════════════════════════╝
]]

local ethy = require("common/ethy_sdk")

-- ═══════════════════════════════════════════════════════════════
--  CONFIG
-- ═══════════════════════════════════════════════════════════════

local CFG = {
    show_circle   = true,
    show_cone     = true,

    circle_radius = 2.0,
    cone_length   = 10.0,
    cone_angle    = 60,

    alpha         = 0.35,
    segments      = 32,
    -- Added to Unity Y after mapping (see game_to_unity); negative = lower toward feet.
    unity_y_offset = 0.12,
    -- "unity" = (x,y,z) passthrough + unity_y_offset on Y (matches runtime logs for player).
    -- "game_z_up" = (x,z,y) swap if your entity uses Z as height.
    coord_mode     = "unity",

    color = { 0, 210, 240 },
}

-- ═══════════════════════════════════════════════════════════════
--  STATE
-- ═══════════════════════════════════════════════════════════════

local state = {
    look_yaw = 0,
    pos_x = 0, pos_y = 0, pos_z = 0,
    has_data = false,
}

local ground_inited = false
local ground_api_ok = (core.draw and core.draw.ground_init) ~= nil

-- #region agent log
local _dbg_tick = 0
local function _dbg_write(hyp, loc, kvs)
    -- debug stub; replace with file writer if diagnostics are needed
end
-- #endregion

--- Game Entity._position -> Unity world for MeshRenderer ground shapes.
local function game_to_unity(px, py, pz, mode, y_extra)
    local ex = y_extra or 0
    if mode == "unity" then
        return px, py + ex, pz
    end
    return px, pz + ex, py
end

-- ═══════════════════════════════════════════════════════════════
--  UPDATE  (runs every game tick)
-- ═══════════════════════════════════════════════════════════════

local _diag_logged = false

local function on_update()
    -- Gather player position + camera look direction
    local me = ethy.get_player()
    if not me or not me:is_valid() then
        if not _diag_logged then ethy.print("[GroundTelegraph] on_update: no valid player yet") end
        state.has_data = false; return
    end
    local pos = me:get_position()
    if not pos or not pos.x then
        if not _diag_logged then ethy.print("[GroundTelegraph] on_update: no position data") end
        state.has_data = false; return
    end
    local cam_angle = core.camera.angle()
    if not cam_angle then
        if not _diag_logged then ethy.print("[GroundTelegraph] on_update: no camera angle") end
        state.has_data = false; return
    end

    if not _diag_logged then
        _diag_logged = true
        ethy.print(string.format("[GroundTelegraph] on_update OK: pos=%.1f,%.1f,%.1f cam=%.1f api=%s",
            pos.x, pos.y, pos.z, cam_angle, tostring(ground_api_ok)))
        if ground_api_ok then
            local init_ok = core.draw.ground_init()
            ethy.print("[GroundTelegraph] ground_init() returned: " .. tostring(init_ok))
        end
    end

    state.pos_x    = pos.x
    state.pos_y    = pos.y
    state.pos_z    = pos.z
    state.look_yaw = (cam_angle + 180) % 360
    state.has_data  = true

    -- #region agent log
    _dbg_tick = _dbg_tick + 1
    if _dbg_tick % 120 == 1 then
        _dbg_write("A", "raw_position", {game_x=pos.x, game_y=pos.y, game_z=pos.z})
        local ux_d, uy_d, uz_d = game_to_unity(pos.x, pos.y, pos.z, CFG.coord_mode, CFG.unity_y_offset)
        local cp = core.camera.get_parsed()
        local cam_s = (cp and cp.x) and string.format("%.1f,%.1f,%.1f", cp.x, cp.y, cp.z) or "nil"
        local z_flat = (math.abs(pos.z - 1.0) < 0.05) and "1" or "0"
        _dbg_write("C", "unity_coords", {ux=ux_d, uy=uy_d, uz=uz_d, mode=CFG.coord_mode, unity_y_offset=CFG.unity_y_offset, cam=cam_s, runId="post-fix", z_near_1=z_flat})
        _dbg_write("E", "state_flags", {ground_inited=tostring(ground_inited), ground_api_ok=tostring(ground_api_ok), has_data=tostring(state.has_data), tick=_dbg_tick})
    end
    -- #endregion

    -- ── Draw ground telegraphs ──
    if not ground_api_ok then return end

    if not CFG.show_circle and not CFG.show_cone then
        if ground_inited then
            core.draw.ground_clear()
            ground_inited = false
        end
        return
    end

    if not state.has_data then
        if ground_inited then core.draw.ground_clear() end
        return
    end

    if not ground_inited then
        core.draw.ground_init()
        ground_inited = true
    end

    -- Convert color from 0-255 to 0-1
    local c  = CFG.color
    local cr, cg, cb = c[1] / 255, c[2] / 255, c[3] / 255

    local ux, uy, uz = game_to_unity(state.pos_x, state.pos_y, state.pos_z, CFG.coord_mode, CFG.unity_y_offset)

    -- Slot 0: filled circle at feet
    if CFG.show_circle then
        core.draw.ground_circle(0,
            ux, uy, uz,
            CFG.circle_radius,
            cr, cg, cb, CFG.alpha,
            CFG.segments)
    else
        core.draw.ground_hide(0)
    end

    -- Slot 1: filled cone in look direction
    if CFG.show_cone then
        local cone_ok = core.draw.ground_cone(1,
            ux, uy, uz,
            CFG.cone_length,
            state.look_yaw,
            CFG.cone_angle,
            cr, cg, cb, CFG.alpha * 0.85,
            CFG.segments)
        -- #region agent log
        if _dbg_tick % 120 == 1 then
            _dbg_write("D", "draw_cone_call", {result=tostring(cone_ok), ux=ux, uy=uy, uz=uz, yaw=state.look_yaw, angle=CFG.cone_angle})
        end
        -- #endregion
    else
        core.draw.ground_hide(1)
    end
end

-- ═══════════════════════════════════════════════════════════════
--  PRESETS
-- ═══════════════════════════════════════════════════════════════

local PRESETS = {
    { name = "Cyan",   color = { 0, 210, 240 } },
    { name = "Green",  color = { 40, 230, 80 } },
    { name = "Red",    color = { 240, 50, 50 } },
    { name = "Gold",   color = { 240, 190, 30 } },
    { name = "Purple", color = { 170, 50, 240 } },
    { name = "White",  color = { 230, 230, 230 } },
    { name = "Pink",   color = { 240, 80, 180 } },
}

-- ═══════════════════════════════════════════════════════════════
--  PLUGIN MENU  (quick toggles in the sidebar)
-- ═══════════════════════════════════════════════════════════════

local show_settings = false

local function on_render_menu()
    if ground_api_ok then
        CFG.show_circle = core.menu.checkbox("gt_circle", "Ground Circle", CFG.show_circle)
        CFG.show_cone   = core.menu.checkbox("gt_cone",   "Ground Cone",   CFG.show_cone)
    else
        core.menu.checkbox("gt_na", "Ground API not loaded", false)
    end
    show_settings = core.menu.checkbox("gt_settings", "Open Settings Window", show_settings)
end

-- ═══════════════════════════════════════════════════════════════
--  SETTINGS WINDOW
-- ═══════════════════════════════════════════════════════════════

local win_first = true

local function render_settings()
    if not show_settings then win_first = true; return end
    if win_first then
        core.imgui.set_next_window_size(340, 480)
        core.imgui.set_next_window_pos(20, 80)
        win_first = false
    end

    local vis, open = core.imgui.begin_window("Ground Telegraph — Settings")
    if not open then
        show_settings = false
        core.menu.set_checkbox("gt_settings", false)
        core.imgui.end_window()
        return
    end

    if vis then
        if not ground_api_ok then
            core.imgui.text_colored(0.97, 0.32, 0.29,
                "Ground telegraph API not available.\nRecompile Hub + DLL with the new bindings.")
            core.imgui.end_window()
            return
        end

        -- Elements
        core.imgui.text("Elements")
        CFG.show_circle = core.imgui.checkbox("Filled Circle##gt", CFG.show_circle)
        CFG.show_cone   = core.imgui.checkbox("Filled Cone##gt",   CFG.show_cone)
        core.imgui.separator(); core.imgui.spacing()

        -- Shape
        core.imgui.text("Shape")
        CFG.circle_radius = core.imgui.slider_float("Circle Radius##g", CFG.circle_radius, 0.5, 10)
        CFG.cone_length   = core.imgui.slider_float("Cone Length##g",   CFG.cone_length,   3, 25)
        CFG.cone_angle    = core.imgui.slider_float("Cone Angle##g",    CFG.cone_angle,    10, 180)
        core.imgui.text("Ground position space")
        local want_unity = (CFG.coord_mode == "unity")
        local nv = core.imgui.checkbox("Height from game Y (recommended)##g", want_unity)
        CFG.coord_mode = nv and "unity" or "game_z_up"
        CFG.unity_y_offset = core.imgui.slider_float(
            "Unity Y offset (height)##g", CFG.unity_y_offset, -3.0, 2.0)
        CFG.alpha         = core.imgui.slider_float("Fill Alpha##g",    CFG.alpha,         0.05, 1.0)
        local seg = core.imgui.slider_float("Fill Detail##g", CFG.segments + 0.0, 8, 64)
        if seg then CFG.segments = math.floor(seg) end
        core.imgui.separator(); core.imgui.spacing()

        -- Color
        core.imgui.text("Color")
        for i, p in ipairs(PRESETS) do
            if i > 1 then core.imgui.same_line() end
            if core.imgui.button(p.name .. "##c") then
                CFG.color = { p.color[1], p.color[2], p.color[3] }
            end
        end
        core.imgui.separator(); core.imgui.spacing()

        -- Status + Debug Coordinates
        if state.has_data then
            core.imgui.text_colored(0.25, 0.72, 0.31,
                string.format("OK | yaw=%.0f", state.look_yaw))
            core.imgui.separator(); core.imgui.spacing()
            core.imgui.text("Debug Coordinates")
            core.imgui.text(string.format("Game: x=%.2f y=%.2f z=%.2f", state.pos_x, state.pos_y, state.pos_z))
            local ux_d, uy_d, uz_d = game_to_unity(state.pos_x, state.pos_y, state.pos_z, CFG.coord_mode, CFG.unity_y_offset)
            core.imgui.text(string.format("Ground mesh (Unity): X=%.2f Y=%.2f Z=%.2f", ux_d, uy_d, uz_d))
            core.imgui.text(string.format("mode=%s (game_z_up = swap Y/Z for height)", CFG.coord_mode))
            local cam = core.camera.get_parsed()
            if cam and cam.x then
                core.imgui.text(string.format(
                    "Camera (raw): x=%.2f y=%.2f z=%.2f  |  compare Y to game y/z for axis pick",
                    cam.x, cam.y, cam.z))
            end
            core.imgui.text(
                "Tip: wrong floor/water -> uncheck height-from-Y (legacy swap) or adjust Unity Y offset.")
            core.imgui.text(string.format("Ground API inited: %s", tostring(ground_inited)))
        else
            core.imgui.text_colored(0.97, 0.32, 0.29, "Waiting for data...")
        end
    end
    core.imgui.end_window()
end

-- ═══════════════════════════════════════════════════════════════
--  REGISTER
-- ═══════════════════════════════════════════════════════════════

ethy.on_update(on_update)
ethy.on_render(render_settings)
ethy.on_render_menu(on_render_menu)

ethy.print("[GroundTelegraph] Loaded" .. (ground_api_ok and "" or " (API not yet available)"))
ethy.print("[GroundTelegraph] ground_init=" .. tostring(core.draw and core.draw.ground_init)
    .. " ground_circle=" .. tostring(core.draw and core.draw.ground_circle)
    .. " camera.angle=" .. tostring(core.camera and core.camera.angle))
