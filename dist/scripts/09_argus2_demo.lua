--[[
╔══════════════════════════════════════════════════════════════════════════════╗
║  Argus2 + ShapeDrawer — Demo & Verification Script                         ║
║                                                                            ║
║  Draws every shape type around the player to verify the system works.      ║
║  Tests: default args, headingOffset, keepHeading, offsetIsAbsolute,        ║
║         entity attachment, color interpolation, cancel.                    ║
╚══════════════════════════════════════════════════════════════════════════════╝
]]

local Argus2, ShapeDrawer = require("argus2")

local log = ethy and ethy.print or print

log("[Argus2Demo] Loaded. Free slots: " .. Argus2.freeSlots())

-- ══════════════════════════════════════════════════════════════════════════
--  CONFIG
-- ══════════════════════════════════════════════════════════════════════════

local CFG = {
    enabled = true,
    demo_running = false,
}

-- ══════════════════════════════════════════════════════════════════════════
--  HELPER: get player position (game coords)
-- ══════════════════════════════════════════════════════════════════════════

local function get_player_pos()
    if core and core.player and core.player.get_position then
        local ok, pos = pcall(core.player.get_position)
        if ok and pos then return pos.x, pos.y, pos.z end
    end
    return 0, 0, 0
end

local function get_player_dir()
    if core and core.player and core.player.direction then
        local ok, dir = pcall(core.player.direction)
        if ok and dir then return dir end
    end
    return 0
end

-- ══════════════════════════════════════════════════════════════════════════
--  DEMO: Spawn all shape types in a ring around the player
-- ══════════════════════════════════════════════════════════════════════════

local function run_demo()
    local px, py, pz = get_player_pos()
    local dir = get_player_dir()
    local ids = {}

    log("[Argus2Demo] Spawning shapes at (%.1f, %.1f, %.1f) heading %.0f", px, py, pz, dir)

    -- Color palettes
    local red_start   = { 1.0, 0.2, 0.2, 0.6 }
    local red_end     = { 1.0, 0.0, 0.0, 0.1 }
    local blue_start  = { 0.2, 0.4, 1.0, 0.6 }
    local blue_end    = { 0.1, 0.2, 0.8, 0.1 }
    local green_start = { 0.2, 1.0, 0.3, 0.5 }
    local green_end   = { 0.0, 0.6, 0.1, 0.1 }
    local gold_start  = { 1.0, 0.85, 0.2, 0.6 }
    local gold_end    = { 0.8, 0.6, 0.0, 0.1 }
    local purple_start = { 0.7, 0.2, 1.0, 0.6 }
    local purple_end   = { 0.4, 0.1, 0.7, 0.1 }

    -- 1. Rect — 5m ahead of player, default heading
    local offset = 5
    local rad = math.rad(dir)
    local rx = px + math.sin(rad) * offset
    local ry = py + math.cos(rad) * offset
    ids[#ids + 1] = Argus2.addTimedRectFilled(
        5.0, rx, ry, pz, 4, 1.5, dir,
        red_start, red_end)
    log("  [1] Rect: id=%s", tostring(ids[#ids]))

    -- 2. CenteredRect — 5m to the right, with headingOffset = 45
    local rx2 = px + math.sin(rad + math.pi / 2) * offset
    local ry2 = py + math.cos(rad + math.pi / 2) * offset
    ids[#ids + 1] = Argus2.addTimedCenteredRectFilled(
        5.0, rx2, ry2, pz, 3, 2, dir,
        blue_start, blue_end, nil, 0,
        nil, nil, false, nil, nil, nil, nil, false, false,
        45, false)
    log("  [2] CenteredRect (offset+45): id=%s", tostring(ids[#ids]))

    -- 3. Cone — at player, facing forward
    ids[#ids + 1] = Argus2.addTimedConeFilled(
        5.0, px, py, pz, 8, 60, dir,
        green_start, green_end)
    log("  [3] Cone: id=%s", tostring(ids[#ids]))

    -- 4. DonutCone — at player, with keepHeading=true
    ids[#ids + 1] = Argus2.addTimedDonutConeFilled(
        5.0, px, py, pz, 3, 7, 90, dir,
        gold_start, gold_end, nil, 0,
        nil, nil, false, nil, nil, nil, nil, false, false,
        0, true)
    log("  [4] DonutCone (keepHeading): id=%s", tostring(ids[#ids]))

    -- 5. Cross — 5m behind player
    local bx = px - math.sin(rad) * offset
    local by = py - math.cos(rad) * offset
    ids[#ids + 1] = Argus2.addTimedCrossFilled(
        5.0, bx, by, pz, 5, 0.8, dir,
        purple_start, purple_end)
    log("  [5] Cross: id=%s", tostring(ids[#ids]))

    -- 6. Arrow — 8m ahead, pointing forward
    local ax = px + math.sin(rad) * 8
    local ay = py + math.cos(rad) * 8
    ids[#ids + 1] = Argus2.addTimedArrowFilled(
        5.0, ax, ay, pz, 6, 0.6, dir,
        red_start, blue_end)
    log("  [6] Arrow: id=%s", tostring(ids[#ids]))

    -- 7. Chevron — 5m to the left
    local lx = px + math.sin(rad - math.pi / 2) * offset
    local ly = py + math.cos(rad - math.pi / 2) * offset
    ids[#ids + 1] = Argus2.addTimedChevronFilled(
        5.0, lx, ly, pz, 4, 0.5, dir,
        gold_start, green_end)
    log("  [7] Chevron: id=%s", tostring(ids[#ids]))

    log("[Argus2Demo] %d shapes spawned. Active: %d  Free slots: %d",
        #ids, Argus2.activeCount(), Argus2.freeSlots())

    -- After 2.5s, cancel the first shape to verify cancel works
    -- (done via a delayed check in on_update)
    return ids
end

-- ══════════════════════════════════════════════════════════════════════════
--  DEMO: ShapeDrawer entity-attached test
-- ══════════════════════════════════════════════════════════════════════════

local function run_shapedrawer_demo()
    -- Attach to player (use player UID if available)
    local me = nil
    if core and core.object_manager and core.object_manager.get_local_player then
        local ok, p = pcall(core.object_manager.get_local_player)
        if ok and p and p.get_uid then
            me = p:get_uid()
        end
    end

    if not me then
        log("[Argus2Demo] ShapeDrawer test skipped — no player UID")
        return
    end

    local sd = ShapeDrawer.new(me)
    log("[Argus2Demo] ShapeDrawer created for entity %d", me)

    -- Cone following player, heading derived from player direction
    local id1 = sd:addTimedConeOnEnt(
        6.0, 10, 45, 0,
        { 0.2, 0.8, 1.0, 0.5 }, { 0.1, 0.4, 0.8, 0.1 })
    log("  [SD-1] ConeOnEnt: id=%s", tostring(id1))

    -- Rect on entity with offsetIsAbsolute (always faces north = 0°)
    local id2 = sd:addTimedRectOnEnt(
        6.0, 5, 1, 0,
        { 1, 1, 0, 0.4 }, { 1, 0.5, 0, 0.1 }, nil, 0,
        nil, false, nil, nil, nil, nil,
        0, true)
    log("  [SD-2] RectOnEnt (absolute heading 0°): id=%s", tostring(id2))

    -- Cross on entity with heading offset
    local id3 = sd:addTimedCrossOnEnt(
        6.0, 4, 0.6, 0,
        { 0.8, 0.2, 1, 0.5 }, { 0.4, 0.1, 0.6, 0.1 }, nil, 0,
        nil, false, nil, nil, nil, nil,
        90, false)
    log("  [SD-3] CrossOnEnt (offset+90): id=%s", tostring(id3))

    log("[Argus2Demo] ShapeDrawer active. Total shapes: %d", Argus2.activeCount())
end

-- ══════════════════════════════════════════════════════════════════════════
--  CALLBACKS
-- ══════════════════════════════════════════════════════════════════════════

local demo_ids      = nil
local demo_start    = nil
local cancel_tested = false

local function on_update()
    if not CFG.enabled or not CFG.demo_running then return end

    -- Test cancel after 2.5 seconds
    if demo_ids and demo_start and not cancel_tested then
        local elapsed = (ethy and ethy.now and ethy.now() or os.clock()) - demo_start
        if elapsed >= 2.5 and demo_ids[1] then
            log("[Argus2Demo] Cancelling shape #1 (id=%d) at %.1fs", demo_ids[1], elapsed)
            Argus2.cancel(demo_ids[1])
            cancel_tested = true
            log("[Argus2Demo] After cancel: active=%d  free=%d",
                Argus2.activeCount(), Argus2.freeSlots())
        end
    end
end

local function on_render_menu()
    if not (ui and ui.text) then return end
    ui.text("[Argus2 Demo]")

    local new_enabled = ui.checkbox("Enable##a2demo", CFG.enabled)
    if new_enabled ~= nil then CFG.enabled = new_enabled end

    ui.text(string.format("Active shapes: %d  |  Free slots: %d",
        Argus2.activeCount(), Argus2.freeSlots()))

    if ui.button("Spawn All Shapes##a2demo") then
        Argus2.cancelAll()
        cancel_tested = false
        demo_ids = run_demo()
        demo_start = (ethy and ethy.now and ethy.now() or os.clock())
        CFG.demo_running = true
    end

    if ui.button("ShapeDrawer Test##a2demo") then
        run_shapedrawer_demo()
    end

    if ui.button("Cancel All##a2demo") then
        Argus2.cancelAll()
        demo_ids = nil
        CFG.demo_running = false
        log("[Argus2Demo] All shapes cancelled.")
    end
end

-- ══════════════════════════════════════════════════════════════════════════
--  REGISTER
-- ══════════════════════════════════════════════════════════════════════════

if core and core.register_on_update_callback then
    core.register_on_update_callback(on_update)
end

if core and core.register_on_render_menu_callback then
    core.register_on_render_menu_callback(on_render_menu)
end

log("[Argus2Demo] Ready. Use the menu to spawn shapes.")
