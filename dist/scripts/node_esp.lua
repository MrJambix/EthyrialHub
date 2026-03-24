--[[
╔══════════════════════════════════════════════════════════════╗
║             Node ESP — 3D Resource Node Markers              ║
║                                                              ║
║  Draws world-space indicators under resource nodes using     ║
║  a 3D-to-screen projection based on the game camera.        ║
║  Shows node name, type, distance, and a pulsing circle.     ║
╚══════════════════════════════════════════════════════════════╝
]]

local ethy = require("common/ethy_sdk")

ethy.print("=== Node ESP loaded ===")

-- ═══════════════════════════════════════════════════════════
-- Config
-- ═══════════════════════════════════════════════════════════

local CFG = {
    enabled     = true,
    show_herbs  = true,
    show_trees  = true,
    show_ores   = true,
    show_skins  = true,
    max_range   = 60,
    scan_rate   = 0.5,
    fov         = 60,
    screen_w    = 1920,
    screen_h    = 1080,
}

local cached_nodes = {}
local last_scan    = 0
local pulse_phase  = 0

-- ═══════════════════════════════════════════════════════════
-- Colors (0xRRGGBB hex for core.graphics)
-- ═══════════════════════════════════════════════════════════

local COLORS = {
    Herb = 0x48C860,   -- green
    Tree = 0x80AA40,   -- olive
    Ore  = 0xD0A030,   -- gold
    Skin = 0xC08060,   -- tan
    Text = 0xE0E8FF,   -- pale blue
    Dist = 0x90A0C0,   -- dim blue
    Ring = 0x00C8FF,   -- cyan
}

-- ═══════════════════════════════════════════════════════════
-- Parse IPC scan results into node list
-- ═══════════════════════════════════════════════════════════

local function parse_nodes(raw, node_type)
    if not raw or raw == "NONE" or raw == "" then return {} end

    local nodes = {}
    local records = {}
    for rec in raw:gmatch("[^###]+") do
        records[#records + 1] = rec
    end

    for i = 2, #records do
        local r = records[i]
        local node = { type = node_type }
        for kv in r:gmatch("[^|]+") do
            local k, v = kv:match("^(.-)=(.+)$")
            if k and v then node[k] = v end
        end
        if node.x then
            node.x    = tonumber(node.x) or 0
            node.y    = tonumber(node.y) or 0
            node.z    = tonumber(node.z) or 0
            node.dist = tonumber(node.dist) or 999
            node.name = node.name or node_type
            nodes[#nodes + 1] = node
        end
    end
    return nodes
end

-- ═══════════════════════════════════════════════════════════
-- World-to-Screen projection
-- ═══════════════════════════════════════════════════════════

local function world_to_screen(wx, wy, wz, px, py, pz, yaw_deg, pitch_deg)
    local dx = wx - px
    local dy = wy - py
    local dz = wz - pz

    local yaw   = math.rad(-yaw_deg)
    local pitch = math.rad(-pitch_deg)

    local cos_y, sin_y = math.cos(yaw), math.sin(yaw)
    local rx = dx * cos_y - dz * sin_y
    local rz = dx * sin_y + dz * cos_y

    local cos_p, sin_p = math.cos(pitch), math.sin(pitch)
    local ry = dy * cos_p - rz * sin_p
    rz       = dy * sin_p + rz * cos_p

    if rz < 0.1 then return nil, nil end

    local fov_scale = 1.0 / math.tan(math.rad(CFG.fov / 2))
    local half_w = CFG.screen_w / 2
    local half_h = CFG.screen_h / 2
    local sx = half_w + (rx / rz) * fov_scale * half_w
    local sy = half_h - (ry / rz) * fov_scale * half_h

    if sx < -200 or sx > CFG.screen_w + 200 or sy < -200 or sy > CFG.screen_h + 200 then
        return nil, nil
    end

    return sx, sy
end

-- ═══════════════════════════════════════════════════════════
-- Parse camera string "x,y,z,distance,angle,pitch"
-- ═══════════════════════════════════════════════════════════

local function get_camera()
    local raw = core.camera.get()
    if not raw or raw == "" then return nil end
    local parts = {}
    for v in raw:gmatch("[^,]+") do parts[#parts + 1] = tonumber(v) end
    if #parts >= 6 then
        return {
            x = parts[1], y = parts[2], z = parts[3],
            distance = parts[4], angle = parts[5], pitch = parts[6],
        }
    end
    return nil
end

-- ═══════════════════════════════════════════════════════════
-- Scan all node types
-- ═══════════════════════════════════════════════════════════

local function refresh_nodes()
    local all = {}
    if CFG.show_herbs then
        for _, n in ipairs(parse_nodes(core.gathering.scan_herbs(), "Herb")) do all[#all + 1] = n end
    end
    if CFG.show_ores then
        for _, n in ipairs(parse_nodes(core.gathering.scan_ores(), "Ore")) do all[#all + 1] = n end
    end
    if CFG.show_trees then
        for _, n in ipairs(parse_nodes(core.gathering.scan_trees(), "Tree")) do all[#all + 1] = n end
    end
    if CFG.show_skins then
        for _, n in ipairs(parse_nodes(core.gathering.scan_skins(), "Skin")) do all[#all + 1] = n end
    end

    local filtered = {}
    for _, n in ipairs(all) do
        if n.dist <= CFG.max_range then filtered[#filtered + 1] = n end
    end
    table.sort(filtered, function(a, b) return a.dist < b.dist end)
    cached_nodes = filtered
end

-- ═══════════════════════════════════════════════════════════
-- Update — scan periodically, read menu
-- ═══════════════════════════════════════════════════════════

ethy.on_update(function()
    CFG.enabled    = ethy.menu.checkbox("esp_enabled",   "Enable Node ESP",  CFG.enabled)
    CFG.show_herbs = ethy.menu.checkbox("esp_herbs",     "Show Herbs",       CFG.show_herbs)
    CFG.show_trees = ethy.menu.checkbox("esp_trees",     "Show Trees",       CFG.show_trees)
    CFG.show_ores  = ethy.menu.checkbox("esp_ores",      "Show Ores",        CFG.show_ores)
    CFG.show_skins = ethy.menu.checkbox("esp_skins",     "Show Skins",       CFG.show_skins)
    CFG.max_range  = ethy.menu.slider_int("esp_range",   "ESP Range (m)",    CFG.max_range, 10, 120)
    CFG.fov        = ethy.menu.slider_int("esp_fov",     "Camera FOV",       CFG.fov, 40, 110)

    if not CFG.enabled then return end

    local now = ethy.now()
    if now - last_scan >= CFG.scan_rate then
        last_scan = now
        refresh_nodes()
    end
end)

-- ═══════════════════════════════════════════════════════════
-- Render — draw 3D markers on screen
-- ═══════════════════════════════════════════════════════════

ethy.on_render(function()
    if not CFG.enabled or #cached_nodes == 0 then return end

    pulse_phase = pulse_phase + 0.05
    if pulse_phase > 6.283 then pulse_phase = pulse_phase - 6.283 end
    local pulse = 0.6 + 0.4 * math.sin(pulse_phase)

    local player = ethy.get_player()
    if not player or not player:is_valid() then return end

    local pos = player:get_position()
    local cam = get_camera()
    if not pos or not cam then return end

    local px, py, pz = pos.x, pos.y, pos.z

    for i, node in ipairs(cached_nodes) do
        local sx, sy = world_to_screen(
            node.x, node.y, node.z,
            cam.x, cam.y, cam.z,
            cam.angle, cam.pitch
        )

        if sx and sy then
            local col = COLORS[node.type] or COLORS.Ring
            local dist_str = string.format("%.0fm", node.dist)

            local radius = math.max(4, 20 - node.dist * 0.3)
            local pulse_r = radius + 4 * pulse

            core.graphics.circle_2d(sx, sy, pulse_r, col, false)
            core.graphics.circle_2d(sx, sy, radius, col, true)

            local label = string.format("[%s] %s", node.type, node.name)
            core.graphics.text_2d(sx - 40, sy - radius - 18, label, col)
            core.graphics.text_2d(sx - 12, sy + radius + 4, dist_str, COLORS.Dist)

            if i == 1 then
                core.graphics.line_2d(
                    CFG.screen_w / 2, CFG.screen_h / 2,
                    sx, sy,
                    COLORS.Ring, 1.0
                )
            end
        end
    end

    core.graphics.text_2d(10, 10,
        string.format("Node ESP: %d nodes in range", #cached_nodes),
        COLORS.Text)
end)

ethy.print("Node ESP ready. Toggle from Settings > Script Menu.")
