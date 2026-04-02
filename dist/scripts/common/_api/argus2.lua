--[[
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                            ║
║   Argus2 + ShapeDrawer — Timed Shape Drawing System                        ║
║   ─────────────────────────────────────────────────────────────────────     ║
║                                                                            ║
║   Pure Lua layer over core.draw.ground_* primitives.                       ║
║   Provides timed, entity-attached, heading-aware shape drawing.            ║
║                                                                            ║
║   Shapes: Rect, CenteredRect, Cone, DonutCone, Cross, Arrow, Chevron      ║
║                                                                            ║
║   Usage:                                                                   ║
║     local Argus2, ShapeDrawer = require("argus2")                          ║
║     Argus2.addTimedConeFilled(3.0, x,y,z, 10, 60, heading, ...)           ║
║                                                                            ║
║     local sd = ShapeDrawer.new(entityUID)                                  ║
║     sd:addTimedConeOnEnt(3.0, 10, 60, heading, ...)                        ║
║                                                                            ║
╚══════════════════════════════════════════════════════════════════════════════╝
]]

local Argus2 = {}
local ShapeDrawer = {}
ShapeDrawer.__index = ShapeDrawer

-- ═══════════════════════════════════════════════════════════════════════════
--  INTERNAL STATE
-- ═══════════════════════════════════════════════════════════════════════════

local _shapes         = {}      -- id → shape record
local _next_id        = 1
local _slot_in_use    = {}      -- slot (int) → shape id
local _entity_cache   = {}      -- uid → { x, y, z }
local _ground_inited  = false
local _tick_registered = false

local PI        = math.pi
local TWO_PI    = PI * 2
local DEG2RAD   = PI / 180
local RAD2DEG   = 180 / PI
local Y_OFFSET  = 0.05

-- Slots 0–3 reserved for ad-hoc/non-timed use. Timed shapes use 4–31.
local SLOT_MIN  = 4
local SLOT_MAX  = 31

local sin  = math.sin
local cos  = math.cos
local atan2 = math.atan2 or math.atan
local abs  = math.abs
local max  = math.max
local min  = math.min
local floor = math.floor

-- ═══════════════════════════════════════════════════════════════════════════
--  TIME SOURCE
-- ═══════════════════════════════════════════════════════════════════════════

local function now()
    if ethy and ethy.now then return ethy.now() end
    if os and os.clock then return os.clock() end
    return 0
end

-- ═══════════════════════════════════════════════════════════════════════════
--  SLOT ALLOCATOR
-- ═══════════════════════════════════════════════════════════════════════════

local function alloc_slots(count)
    local result = {}
    for s = SLOT_MIN, SLOT_MAX do
        if not _slot_in_use[s] then
            result[#result + 1] = s
            if #result == count then
                return result
            end
        end
    end
    return nil  -- not enough free slots
end

local function reserve_slots(slots, shape_id)
    for _, s in ipairs(slots) do
        _slot_in_use[s] = shape_id
    end
end

local function free_slots(slots)
    for _, s in ipairs(slots) do
        _slot_in_use[s] = nil
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
--  ENTITY CACHE  (rebuilt each tick)
-- ═══════════════════════════════════════════════════════════════════════════

local function rebuild_entity_cache()
    _entity_cache = {}

    -- Fast native path
    if game and game.raw and game.raw.nearby then
        local ok, nearby = pcall(game.raw.nearby)
        if ok and nearby then
            for _, e in ipairs(nearby) do
                if e.uid then
                    _entity_cache[e.uid] = { x = e.x, y = e.y, z = e.z }
                end
            end
        end
    end

    -- Also cache player position
    if core and core.player and core.player.get_position then
        local ok, pos = pcall(core.player.get_position)
        if ok and pos then
            -- Store under a special key
            _entity_cache["__player__"] = { x = pos.x, y = pos.y, z = pos.z }
        end
    end
end

local function get_entity_pos(uid)
    if not uid then return nil end
    return _entity_cache[uid]
end

local function get_player_direction()
    if core and core.player and core.player.direction then
        local ok, dir = pcall(core.player.direction)
        if ok and dir then return dir end
    end
    return 0
end

-- ═══════════════════════════════════════════════════════════════════════════
--  COORDINATE CONVERSION
--  Game coords: (x, y, z) where y is horizontal depth
--  Unity coords: (ux, uy, uz) where uy is vertical (up)
--  Mapping: ux = gx,  uy = gz + Y_OFFSET,  uz = gy
-- ═══════════════════════════════════════════════════════════════════════════

local function game_to_unity(gx, gy, gz)
    return gx, (gz or 0) + Y_OFFSET, gy
end

-- ═══════════════════════════════════════════════════════════════════════════
--  HEADING RESOLVER
-- ═══════════════════════════════════════════════════════════════════════════

--- Compute final heading in degrees.
--- @param params table  Shape record or params with heading fields
--- @return number  Final heading in degrees (0–360)
local function resolve_heading(params)
    local base = params.heading or 0

    if not params.keepHeading then
        local ent_pos = get_entity_pos(params.entityAttachID)
        local tgt_pos = get_entity_pos(params.targetAttachID)

        if ent_pos and tgt_pos then
            -- Heading from entity toward target (game XZ plane)
            local dx = tgt_pos.x - ent_pos.x
            local dz = tgt_pos.y - ent_pos.y  -- game y maps to horizontal
            base = atan2(dx, dz) * RAD2DEG
        elseif params.entityAttachID then
            -- Use player direction if entity is player (best guess)
            base = get_player_direction()
        end
    end

    if params.offsetIsAbsolute then
        return ((params.headingOffset or 0) % 360 + 360) % 360
    end

    return ((base + (params.headingOffset or 0)) % 360 + 360) % 360
end

-- ═══════════════════════════════════════════════════════════════════════════
--  POSITION RESOLVER  (follows entity if attached)
-- ═══════════════════════════════════════════════════════════════════════════

--- Resolve world position for a shape. Returns Unity coords.
--- @param shape table  Shape record
--- @return number, number, number  ux, uy, uz
local function resolve_position(shape)
    local gx, gy, gz = shape.x, shape.y, shape.z

    if shape.entityAttachID then
        local pos = get_entity_pos(shape.entityAttachID)
        if pos then
            gx, gy, gz = pos.x, pos.y, pos.z
        end
    end

    return game_to_unity(gx, gy, gz)
end

-- ═══════════════════════════════════════════════════════════════════════════
--  COLOR UTILITIES
-- ═══════════════════════════════════════════════════════════════════════════

local DEFAULT_COLOR = { 1, 1, 1, 0.4 }

local function ensure_color(c)
    if not c then return DEFAULT_COLOR end
    return {
        c[1] or c.r or 1,
        c[2] or c.g or 1,
        c[3] or c.b or 1,
        c[4] or c.a or 0.4,
    }
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

--- Interpolate between colorStart, colorMid, colorEnd over t (0→1).
--- @param cs table  Color start {r,g,b,a}
--- @param ce table  Color end {r,g,b,a}
--- @param cm table|nil  Color mid (optional)
--- @param t number  Progress 0–1
--- @return number, number, number, number  r, g, b, a
local function lerp_color(cs, ce, cm, t)
    cs = ensure_color(cs)
    ce = ensure_color(ce)
    t = max(0, min(1, t))

    if cm then
        cm = ensure_color(cm)
        if t <= 0.5 then
            local t2 = t * 2
            return lerp(cs[1], cm[1], t2),
                   lerp(cs[2], cm[2], t2),
                   lerp(cs[3], cm[3], t2),
                   lerp(cs[4], cm[4], t2)
        else
            local t2 = (t - 0.5) * 2
            return lerp(cm[1], ce[1], t2),
                   lerp(cm[2], ce[2], t2),
                   lerp(cm[3], ce[3], t2),
                   lerp(cm[4], ce[4], t2)
        end
    else
        return lerp(cs[1], ce[1], t),
               lerp(cs[2], ce[2], t),
               lerp(cs[3], ce[3], t),
               lerp(cs[4], ce[4], t)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
--  SHAPE RENDERERS
--  Each renderer draws its shape using core.draw.ground_* for a given frame.
-- ═══════════════════════════════════════════════════════════════════════════

local draw = nil  -- lazily resolved reference to core.draw

local function get_draw()
    if draw then return draw end
    if core and core.draw then
        draw = core.draw
        return draw
    end
    return nil
end

--- Draw a rectangle (line from back to front with width).
local function render_rect(slots, ux, uy, uz, heading, length, width, r, g, b, a)
    local d = get_draw()
    if not d then return end
    local rad = heading * DEG2RAD
    local dx = sin(rad)
    local dz = cos(rad)
    local half = length / 2
    local x1 = ux - dx * half
    local z1 = uz - dz * half
    local x2 = ux + dx * half
    local z2 = uz + dz * half
    d.ground_line(slots[1], x1, uy, z1, x2, uy, z2, width, r, g, b, a)
end

--- Draw a centered rectangle (origin at center, identical to rect).
local function render_centered_rect(slots, ux, uy, uz, heading, length, width, r, g, b, a)
    render_rect(slots, ux, uy, uz, heading, length, width, r, g, b, a)
end

--- Draw a cone.
local function render_cone(slots, ux, uy, uz, heading, length, angle, r, g, b, a)
    local d = get_draw()
    if not d then return end
    d.ground_cone(slots[1], ux, uy, uz, length, heading, angle, r, g, b, a, 24)
end

--- Draw a donut-cone (outer donut ring + inner cone wedge).
local function render_donut_cone(slots, ux, uy, uz, heading, innerRadius, outerRadius, angle, r, g, b, a)
    local d = get_draw()
    if not d then return end
    d.ground_donut(slots[1], ux, uy, uz, innerRadius, outerRadius, r, g, b, a, 32)
    -- Add the directional cone overlay on slot 2 if angle < 360
    if angle < 360 then
        d.ground_cone(slots[2], ux, uy, uz, outerRadius, heading, angle, r, g, b, a * 0.5, 24)
    end
end

--- Draw a cross (two perpendicular lines).
local function render_cross(slots, ux, uy, uz, heading, length, width, r, g, b, a)
    local d = get_draw()
    if not d then return end
    -- Arm 1: along heading
    local rad1 = heading * DEG2RAD
    local dx1 = sin(rad1)
    local dz1 = cos(rad1)
    local half = length / 2
    d.ground_line(slots[1],
        ux - dx1 * half, uy, uz - dz1 * half,
        ux + dx1 * half, uy, uz + dz1 * half,
        width, r, g, b, a)
    -- Arm 2: perpendicular (heading + 90)
    local rad2 = (heading + 90) * DEG2RAD
    local dx2 = sin(rad2)
    local dz2 = cos(rad2)
    d.ground_line(slots[2],
        ux - dx2 * half, uy, uz - dz2 * half,
        ux + dx2 * half, uy, uz + dz2 * half,
        width, r, g, b, a)
end

--- Draw an arrow (shaft line + cone arrowhead).
local function render_arrow(slots, ux, uy, uz, heading, length, width, r, g, b, a)
    local d = get_draw()
    if not d then return end
    local rad = heading * DEG2RAD
    local dx = sin(rad)
    local dz = cos(rad)
    -- Shaft from tail to near-tip
    local shaft_len = length * 0.7
    local tail_x = ux - dx * (length / 2)
    local tail_z = uz - dz * (length / 2)
    local tip_x  = ux + dx * (length / 2)
    local tip_z  = uz + dz * (length / 2)
    local mid_x  = tail_x + dx * shaft_len
    local mid_z  = tail_z + dz * shaft_len
    d.ground_line(slots[1], tail_x, uy, tail_z, mid_x, uy, mid_z, width, r, g, b, a)
    -- Arrowhead cone at the tip
    local head_len = length * 0.35
    d.ground_cone(slots[2], mid_x, uy, mid_z, head_len, heading, 50, r, g, b, a, 12)
end

--- Draw a chevron (two angled wings from center).
local function render_chevron(slots, ux, uy, uz, heading, length, width, r, g, b, a)
    local d = get_draw()
    if not d then return end
    local half = length / 2
    local wing_angle = 30  -- degrees offset from heading
    -- Left wing
    local rad_l = (heading - wing_angle) * DEG2RAD
    local lx = ux + sin(rad_l) * half
    local lz = uz + cos(rad_l) * half
    d.ground_line(slots[1], ux, uy, uz, lx, uy, lz, width, r, g, b, a)
    -- Right wing
    local rad_r = (heading + wing_angle) * DEG2RAD
    local rx = ux + sin(rad_r) * half
    local rz = uz + cos(rad_r) * half
    d.ground_line(slots[2], ux, uy, uz, rx, uy, rz, width, r, g, b, a)
end

-- Outline support: render outline first (wider), then fill on top.
-- Only if colorOutline is provided. Uses same slots (overdrawn).
local function render_with_outline(render_fn, slots, ux, uy, uz, heading, shape,
                                    r, g, b, a)
    if shape.colorOutline then
        local oc = ensure_color(shape.colorOutline)
        local ot = shape.outlineThickness or 0.1
        local kind = shape.kind
        if kind == "cone" then
            render_fn(slots, ux, uy, uz, heading,
                shape.length + ot * 2, shape.angle + 4,
                oc[1], oc[2], oc[3], oc[4])
        elseif kind == "donut_cone" then
            render_fn(slots, ux, uy, uz, heading,
                max(0, shape.innerRadius - ot), shape.outerRadius + ot,
                shape.angle + 4,
                oc[1], oc[2], oc[3], oc[4])
        else
            render_fn(slots, ux, uy, uz, heading,
                shape.length + ot * 2, shape.width + ot * 2,
                oc[1], oc[2], oc[3], oc[4])
        end
    end
    -- Normal fill on top
    local kind = shape.kind
    if kind == "cone" then
        render_fn(slots, ux, uy, uz, heading, shape.length, shape.angle, r, g, b, a)
    elseif kind == "donut_cone" then
        render_fn(slots, ux, uy, uz, heading,
            shape.innerRadius, shape.outerRadius, shape.angle, r, g, b, a)
    else
        render_fn(slots, ux, uy, uz, heading, shape.length, shape.width, r, g, b, a)
    end
end

-- Dispatch to the correct renderer for a shape kind.
local RENDERERS = {
    rect          = render_rect,
    centered_rect = render_centered_rect,
    cone          = render_cone,
    donut_cone    = render_donut_cone,
    cross         = render_cross,
    arrow         = render_arrow,
    chevron       = render_chevron,
}

-- Slots required per shape kind.
local SLOTS_NEEDED = {
    rect          = 1,
    centered_rect = 1,
    cone          = 1,
    donut_cone    = 2,
    cross         = 2,
    arrow         = 2,
    chevron       = 2,
}

-- ═══════════════════════════════════════════════════════════════════════════
--  TICK FUNCTION  (registered on core.register_on_update_callback)
-- ═══════════════════════════════════════════════════════════════════════════

local function argus2_tick()
    if not get_draw() then return end

    if not _ground_inited then
        local ok = pcall(function() core.draw.ground_init() end)
        _ground_inited = ok
        if not ok then return end
    end

    rebuild_entity_cache()
    local t_now = now()

    for id, shape in pairs(_shapes) do
        local age = t_now - shape.created_at

        -- Expired?
        if age >= shape.timeout then
            for _, s in ipairs(shape.slots) do
                pcall(function() core.draw.ground_hide(s) end)
            end
            free_slots(shape.slots)
            _shapes[id] = nil
            goto continue
        end

        -- In delay period?
        if age < (shape.delay or 0) then
            for _, s in ipairs(shape.slots) do
                pcall(function() core.draw.ground_hide(s) end)
            end
            goto continue
        end

        -- Compute progress t = 0→1 within active window
        local active_duration = shape.timeout - (shape.delay or 0)
        local t
        if active_duration > 0 then
            t = (age - (shape.delay or 0)) / active_duration
            t = max(0, min(1, t))
        else
            t = 1
        end

        -- Resolve position (follows entity if attached)
        local ux, uy, uz = resolve_position(shape)

        -- Resolve heading
        local heading = resolve_heading(shape)

        -- Interpolate color
        local r, g, b, a = lerp_color(shape.colorStart, shape.colorEnd, shape.colorMid, t)

        -- Apply gradient opacity if configured
        if shape.gradientIntensity and shape.gradientIntensity > 0 then
            local gmin = shape.gradientMinOpacity or 0
            local gfactor = 1.0 - shape.gradientIntensity * (1.0 - t)
            a = a * max(gmin, gfactor)
        end

        -- Render
        local renderer = RENDERERS[shape.kind]
        if renderer then
            render_with_outline(renderer, shape.slots, ux, uy, uz, heading, shape,
                                r, g, b, a)
        end

        ::continue::
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
--  SHAPE CREATION HELPERS
-- ═══════════════════════════════════════════════════════════════════════════

local function create_shape(kind, params)
    local needed = SLOTS_NEEDED[kind] or 1
    local slots = alloc_slots(needed)
    if not slots then
        -- Pool exhausted — log warning, return nil
        if ethy and ethy.print then
            ethy.print("[Argus2] WARNING: slot pool exhausted, cannot draw " .. kind)
        end
        return nil
    end

    local id = _next_id
    _next_id = _next_id + 1

    local shape = {
        id              = id,
        kind            = kind,
        slots           = slots,
        created_at      = now(),
        timeout         = params.timeout or 3.0,
        delay           = params.delay or 0,
        -- position (game coords)
        x               = params.x or 0,
        y               = params.y or 0,
        z               = params.z or 0,
        -- dimensions
        length          = params.length or 1,
        width           = params.width or 1,
        angle           = params.angle or 60,
        innerRadius     = params.innerRadius or 0,
        outerRadius     = params.outerRadius or 1,
        -- heading
        heading         = params.heading or 0,
        entityAttachID  = params.entityAttachID,
        targetAttachID  = params.targetAttachID,
        keepHeading     = params.keepHeading or false,
        headingOffset   = params.headingOffset or 0,
        offsetIsAbsolute = params.offsetIsAbsolute or false,
        keepLength      = params.keepLength or false,
        -- colors
        colorStart      = params.colorStart,
        colorEnd        = params.colorEnd,
        colorMid        = params.colorMid,
        colorOutline    = params.colorOutline,
        outlineThickness = params.outlineThickness or 0.1,
        -- gradient
        gradientIntensity  = params.gradientIntensity or 0,
        gradientMinOpacity = params.gradientMinOpacity or 0,
        -- flags
        oldDraw         = params.oldDraw or false,
        doNotDetect     = params.doNotDetect or false,
        -- entity tracking
        isOnEnt         = params.isOnEnt or false,
        entUID          = params.entUID,
    }

    reserve_slots(slots, id)
    _shapes[id] = shape

    -- Auto-register tick on first shape creation
    if not _tick_registered then
        if core and core.register_on_update_callback then
            core.register_on_update_callback(argus2_tick)
            _tick_registered = true
        end
    end

    return id
end

-- ═══════════════════════════════════════════════════════════════════════════
--  ARGUS2 PUBLIC API
-- ═══════════════════════════════════════════════════════════════════════════

--- Add a timed filled rectangle.
---@param timeout number Duration in seconds
---@param x number Game X position
---@param y number Game Y position
---@param z number Game Z position
---@param length number Rectangle length
---@param width number Rectangle width
---@param heading number Heading in degrees
---@param colorStart table? {r,g,b,a} start color
---@param colorEnd table? {r,g,b,a} end color
---@param colorMid table? {r,g,b,a} mid color (optional)
---@param delay number? Seconds before shape appears (default 0)
---@param entityAttachID number? Entity UID to follow position
---@param targetAttachID number? Target UID for heading derivation
---@param keepLength boolean? If true, length is not modified
---@param colorOutline table? {r,g,b,a} outline color
---@param outlineThickness number? Outline thickness (default 0.1)
---@param gradientIntensity number? Gradient strength 0–1
---@param gradientMinOpacity number? Minimum opacity during gradient
---@param oldDraw boolean? Legacy draw flag
---@param doNotDetect boolean? Skip detection flag
---@param headingOffset number? Constant offset added to heading (default 0)
---@param keepHeading boolean? If true, preserve raw heading; skip auto-calc
---@return integer|nil Shape ID, or nil if slots exhausted
function Argus2.addTimedRectFilled(
    timeout, x, y, z, length, width, heading,
    colorStart, colorEnd, colorMid, delay,
    entityAttachID, targetAttachID, keepLength,
    colorOutline, outlineThickness, gradientIntensity, gradientMinOpacity,
    oldDraw, doNotDetect, headingOffset, keepHeading)

    return create_shape("rect", {
        timeout = timeout, x = x, y = y, z = z,
        length = length, width = width, heading = heading,
        colorStart = colorStart, colorEnd = colorEnd, colorMid = colorMid,
        delay = delay, entityAttachID = entityAttachID,
        targetAttachID = targetAttachID, keepLength = keepLength,
        colorOutline = colorOutline, outlineThickness = outlineThickness,
        gradientIntensity = gradientIntensity,
        gradientMinOpacity = gradientMinOpacity,
        oldDraw = oldDraw, doNotDetect = doNotDetect,
        headingOffset = headingOffset, keepHeading = keepHeading,
    })
end

--- Add a timed centered filled rectangle.
---@param timeout number Duration in seconds
---@param x number Game X position (center)
---@param y number Game Y position
---@param z number Game Z position
---@param length number Rectangle length
---@param width number Rectangle width
---@param heading number Heading in degrees
---@param colorStart table? {r,g,b,a}
---@param colorEnd table? {r,g,b,a}
---@param colorMid table? {r,g,b,a}
---@param delay number?
---@param entityAttachID number?
---@param targetAttachID number?
---@param keepLength boolean?
---@param colorOutline table?
---@param outlineThickness number?
---@param gradientIntensity number?
---@param gradientMinOpacity number?
---@param oldDraw boolean?
---@param doNotDetect boolean?
---@param headingOffset number? Default = 0
---@param keepHeading boolean? If true, preserves raw heading
---@return integer|nil
function Argus2.addTimedCenteredRectFilled(
    timeout, x, y, z, length, width, heading,
    colorStart, colorEnd, colorMid, delay,
    entityAttachID, targetAttachID, keepLength,
    colorOutline, outlineThickness, gradientIntensity, gradientMinOpacity,
    oldDraw, doNotDetect, headingOffset, keepHeading)

    return create_shape("centered_rect", {
        timeout = timeout, x = x, y = y, z = z,
        length = length, width = width, heading = heading,
        colorStart = colorStart, colorEnd = colorEnd, colorMid = colorMid,
        delay = delay, entityAttachID = entityAttachID,
        targetAttachID = targetAttachID, keepLength = keepLength,
        colorOutline = colorOutline, outlineThickness = outlineThickness,
        gradientIntensity = gradientIntensity,
        gradientMinOpacity = gradientMinOpacity,
        oldDraw = oldDraw, doNotDetect = doNotDetect,
        headingOffset = headingOffset, keepHeading = keepHeading,
    })
end

--- Add a timed filled cone.
---@param timeout number Duration in seconds
---@param x number Game X position (apex)
---@param y number Game Y position
---@param z number Game Z position
---@param length number Cone reach / radius
---@param angle number Cone spread in degrees
---@param heading number Heading in degrees
---@param colorStart table? {r,g,b,a}
---@param colorEnd table? {r,g,b,a}
---@param colorMid table? {r,g,b,a}
---@param delay number?
---@param entityAttachID number?
---@param targetAttachID number?
---@param keepLength boolean?
---@param colorOutline table?
---@param outlineThickness number?
---@param gradientIntensity number?
---@param gradientMinOpacity number?
---@param oldDraw boolean?
---@param doNotDetect boolean?
---@param headingOffset number? Default = 0
---@param keepHeading boolean? If true, preserves raw heading
---@return integer|nil
function Argus2.addTimedConeFilled(
    timeout, x, y, z, length, angle, heading,
    colorStart, colorEnd, colorMid, delay,
    entityAttachID, targetAttachID, keepLength,
    colorOutline, outlineThickness, gradientIntensity, gradientMinOpacity,
    oldDraw, doNotDetect, headingOffset, keepHeading)

    return create_shape("cone", {
        timeout = timeout, x = x, y = y, z = z,
        length = length, angle = angle, heading = heading,
        colorStart = colorStart, colorEnd = colorEnd, colorMid = colorMid,
        delay = delay, entityAttachID = entityAttachID,
        targetAttachID = targetAttachID, keepLength = keepLength,
        colorOutline = colorOutline, outlineThickness = outlineThickness,
        gradientIntensity = gradientIntensity,
        gradientMinOpacity = gradientMinOpacity,
        oldDraw = oldDraw, doNotDetect = doNotDetect,
        headingOffset = headingOffset, keepHeading = keepHeading,
    })
end

--- Add a timed filled donut-cone (annular ring with directional wedge).
---@param timeout number Duration in seconds
---@param x number Game X position (center)
---@param y number Game Y position
---@param z number Game Z position
---@param innerRadius number Inner ring radius
---@param outerRadius number Outer ring radius
---@param angle number Cone spread in degrees
---@param heading number Heading in degrees
---@param colorStart table? {r,g,b,a}
---@param colorEnd table? {r,g,b,a}
---@param colorMid table? {r,g,b,a}
---@param delay number?
---@param entityAttachID number?
---@param targetAttachID number?
---@param keepLength boolean?
---@param colorOutline table?
---@param outlineThickness number?
---@param gradientIntensity number?
---@param gradientMinOpacity number?
---@param oldDraw boolean?
---@param doNotDetect boolean?
---@param headingOffset number? Default = 0
---@param keepHeading boolean? If true, preserves raw heading
---@return integer|nil
function Argus2.addTimedDonutConeFilled(
    timeout, x, y, z, innerRadius, outerRadius, angle, heading,
    colorStart, colorEnd, colorMid, delay,
    entityAttachID, targetAttachID, keepLength,
    colorOutline, outlineThickness, gradientIntensity, gradientMinOpacity,
    oldDraw, doNotDetect, headingOffset, keepHeading)

    return create_shape("donut_cone", {
        timeout = timeout, x = x, y = y, z = z,
        innerRadius = innerRadius, outerRadius = outerRadius,
        angle = angle, heading = heading,
        colorStart = colorStart, colorEnd = colorEnd, colorMid = colorMid,
        delay = delay, entityAttachID = entityAttachID,
        targetAttachID = targetAttachID, keepLength = keepLength,
        colorOutline = colorOutline, outlineThickness = outlineThickness,
        gradientIntensity = gradientIntensity,
        gradientMinOpacity = gradientMinOpacity,
        oldDraw = oldDraw, doNotDetect = doNotDetect,
        headingOffset = headingOffset, keepHeading = keepHeading,
    })
end

--- Add a timed filled cross (two perpendicular rectangles).
---@param timeout number Duration in seconds
---@param x number Game X position (center)
---@param y number Game Y position
---@param z number Game Z position
---@param length number Arm length
---@param width number Arm width
---@param heading number Heading in degrees
---@param colorStart table? {r,g,b,a}
---@param colorEnd table? {r,g,b,a}
---@param colorMid table? {r,g,b,a}
---@param delay number?
---@param entityAttachID number?
---@param targetAttachID number?
---@param keepLength boolean?
---@param colorOutline table?
---@param outlineThickness number?
---@param gradientIntensity number?
---@param gradientMinOpacity number?
---@param oldDraw boolean?
---@param doNotDetect boolean?
---@param headingOffset number? Default = 0
---@param keepHeading boolean? If true, preserves raw heading
---@return integer|nil
function Argus2.addTimedCrossFilled(
    timeout, x, y, z, length, width, heading,
    colorStart, colorEnd, colorMid, delay,
    entityAttachID, targetAttachID, keepLength,
    colorOutline, outlineThickness, gradientIntensity, gradientMinOpacity,
    oldDraw, doNotDetect, headingOffset, keepHeading)

    return create_shape("cross", {
        timeout = timeout, x = x, y = y, z = z,
        length = length, width = width, heading = heading,
        colorStart = colorStart, colorEnd = colorEnd, colorMid = colorMid,
        delay = delay, entityAttachID = entityAttachID,
        targetAttachID = targetAttachID, keepLength = keepLength,
        colorOutline = colorOutline, outlineThickness = outlineThickness,
        gradientIntensity = gradientIntensity,
        gradientMinOpacity = gradientMinOpacity,
        oldDraw = oldDraw, doNotDetect = doNotDetect,
        headingOffset = headingOffset, keepHeading = keepHeading,
    })
end

--- Add a timed filled arrow (shaft + arrowhead).
---@param timeout number Duration in seconds
---@param x number Game X position (center)
---@param y number Game Y position
---@param z number Game Z position
---@param length number Arrow total length
---@param width number Shaft width
---@param heading number Heading in degrees
---@param colorStart table? {r,g,b,a}
---@param colorEnd table? {r,g,b,a}
---@param colorMid table? {r,g,b,a}
---@param delay number?
---@param entityAttachID number?
---@param targetAttachID number?
---@param keepLength boolean?
---@param colorOutline table?
---@param outlineThickness number?
---@param gradientIntensity number?
---@param gradientMinOpacity number?
---@param oldDraw boolean?
---@param doNotDetect boolean?
---@param headingOffset number? Default = 0
---@param keepHeading boolean? If true, preserves raw heading
---@return integer|nil
function Argus2.addTimedArrowFilled(
    timeout, x, y, z, length, width, heading,
    colorStart, colorEnd, colorMid, delay,
    entityAttachID, targetAttachID, keepLength,
    colorOutline, outlineThickness, gradientIntensity, gradientMinOpacity,
    oldDraw, doNotDetect, headingOffset, keepHeading)

    return create_shape("arrow", {
        timeout = timeout, x = x, y = y, z = z,
        length = length, width = width, heading = heading,
        colorStart = colorStart, colorEnd = colorEnd, colorMid = colorMid,
        delay = delay, entityAttachID = entityAttachID,
        targetAttachID = targetAttachID, keepLength = keepLength,
        colorOutline = colorOutline, outlineThickness = outlineThickness,
        gradientIntensity = gradientIntensity,
        gradientMinOpacity = gradientMinOpacity,
        oldDraw = oldDraw, doNotDetect = doNotDetect,
        headingOffset = headingOffset, keepHeading = keepHeading,
    })
end

--- Add a timed filled chevron (two angled wings).
---@param timeout number Duration in seconds
---@param x number Game X position (vertex)
---@param y number Game Y position
---@param z number Game Z position
---@param length number Wing length
---@param width number Wing width
---@param heading number Heading in degrees
---@param colorStart table? {r,g,b,a}
---@param colorEnd table? {r,g,b,a}
---@param colorMid table? {r,g,b,a}
---@param delay number?
---@param entityAttachID number?
---@param targetAttachID number?
---@param keepLength boolean?
---@param colorOutline table?
---@param outlineThickness number?
---@param gradientIntensity number?
---@param gradientMinOpacity number?
---@param oldDraw boolean?
---@param doNotDetect boolean?
---@param headingOffset number? Default = 0
---@param keepHeading boolean? If true, preserves raw heading
---@return integer|nil
function Argus2.addTimedChevronFilled(
    timeout, x, y, z, length, width, heading,
    colorStart, colorEnd, colorMid, delay,
    entityAttachID, targetAttachID, keepLength,
    colorOutline, outlineThickness, gradientIntensity, gradientMinOpacity,
    oldDraw, doNotDetect, headingOffset, keepHeading)

    return create_shape("chevron", {
        timeout = timeout, x = x, y = y, z = z,
        length = length, width = width, heading = heading,
        colorStart = colorStart, colorEnd = colorEnd, colorMid = colorMid,
        delay = delay, entityAttachID = entityAttachID,
        targetAttachID = targetAttachID, keepLength = keepLength,
        colorOutline = colorOutline, outlineThickness = outlineThickness,
        gradientIntensity = gradientIntensity,
        gradientMinOpacity = gradientMinOpacity,
        oldDraw = oldDraw, doNotDetect = doNotDetect,
        headingOffset = headingOffset, keepHeading = keepHeading,
    })
end

-- ═══════════════════════════════════════════════════════════════════════════
--  ARGUS2 UTILITY API
-- ═══════════════════════════════════════════════════════════════════════════

--- Cancel a timed shape by ID.
---@param shapeID integer
function Argus2.cancel(shapeID)
    local shape = _shapes[shapeID]
    if not shape then return end
    for _, s in ipairs(shape.slots) do
        pcall(function() core.draw.ground_hide(s) end)
    end
    free_slots(shape.slots)
    _shapes[shapeID] = nil
end

--- Cancel all active timed shapes.
function Argus2.cancelAll()
    for id, shape in pairs(_shapes) do
        for _, s in ipairs(shape.slots) do
            pcall(function() core.draw.ground_hide(s) end)
        end
        free_slots(shape.slots)
    end
    _shapes = {}
end

--- Get number of currently active shapes.
---@return integer
function Argus2.activeCount()
    local count = 0
    for _ in pairs(_shapes) do count = count + 1 end
    return count
end

--- Explicitly initialize ground draw system.
function Argus2.init()
    if not _ground_inited and get_draw() then
        pcall(function() core.draw.ground_init() end)
        _ground_inited = true
    end
    if not _tick_registered then
        if core and core.register_on_update_callback then
            core.register_on_update_callback(argus2_tick)
            _tick_registered = true
        end
    end
end

--- Get number of free timed slots.
---@return integer
function Argus2.freeSlots()
    local count = 0
    for s = SLOT_MIN, SLOT_MAX do
        if not _slot_in_use[s] then count = count + 1 end
    end
    return count
end

-- ═══════════════════════════════════════════════════════════════════════════
--  SHAPEDRAWER CLASS
--  Entity-attached drawing with offsetIsAbsolute heading mode.
-- ═══════════════════════════════════════════════════════════════════════════

--- Create a new ShapeDrawer bound to an entity UID.
---@param entityUID integer  Entity to attach all drawings to
---@return table  ShapeDrawer instance
function ShapeDrawer.new(entityUID)
    local self = setmetatable({}, ShapeDrawer)
    self.entity = entityUID
    return self
end

--- Internal: create a shape on this entity.
function ShapeDrawer:_createOnEnt(kind, params)
    params.entityAttachID = self.entity
    params.isOnEnt = true
    params.entUID = self.entity
    -- Position will be resolved from entity each tick; seed with 0
    params.x = params.x or 0
    params.y = params.y or 0
    params.z = params.z or 0
    return create_shape(kind, params)
end

--- Add a timed rectangle on entity.
---@param timeout number Duration in seconds
---@param length number Rectangle length
---@param width number Rectangle width
---@param heading number Heading in degrees
---@param colorStart table? {r,g,b,a}
---@param colorEnd table? {r,g,b,a}
---@param colorMid table? {r,g,b,a}
---@param delay number?
---@param targetAttachID number?
---@param keepLength boolean?
---@param colorOutline table?
---@param outlineThickness number?
---@param gradientIntensity number?
---@param gradientMinOpacity number?
---@param headingOffset number? Default = 0
---@param offsetIsAbsolute boolean? If true, heading = headingOffset exactly
---@return integer|nil
function ShapeDrawer:addTimedRectOnEnt(
    timeout, length, width, heading,
    colorStart, colorEnd, colorMid, delay,
    targetAttachID, keepLength,
    colorOutline, outlineThickness, gradientIntensity, gradientMinOpacity,
    headingOffset, offsetIsAbsolute)

    return self:_createOnEnt("rect", {
        timeout = timeout, length = length, width = width, heading = heading,
        colorStart = colorStart, colorEnd = colorEnd, colorMid = colorMid,
        delay = delay, targetAttachID = targetAttachID, keepLength = keepLength,
        colorOutline = colorOutline, outlineThickness = outlineThickness,
        gradientIntensity = gradientIntensity,
        gradientMinOpacity = gradientMinOpacity,
        headingOffset = headingOffset, offsetIsAbsolute = offsetIsAbsolute,
    })
end

--- Add a timed centered rectangle on entity.
---@param timeout number
---@param length number
---@param width number
---@param heading number
---@param colorStart table?
---@param colorEnd table?
---@param colorMid table?
---@param delay number?
---@param targetAttachID number?
---@param keepLength boolean?
---@param colorOutline table?
---@param outlineThickness number?
---@param gradientIntensity number?
---@param gradientMinOpacity number?
---@param headingOffset number?
---@param offsetIsAbsolute boolean?
---@return integer|nil
function ShapeDrawer:addTimedCenteredRectOnEnt(
    timeout, length, width, heading,
    colorStart, colorEnd, colorMid, delay,
    targetAttachID, keepLength,
    colorOutline, outlineThickness, gradientIntensity, gradientMinOpacity,
    headingOffset, offsetIsAbsolute)

    return self:_createOnEnt("centered_rect", {
        timeout = timeout, length = length, width = width, heading = heading,
        colorStart = colorStart, colorEnd = colorEnd, colorMid = colorMid,
        delay = delay, targetAttachID = targetAttachID, keepLength = keepLength,
        colorOutline = colorOutline, outlineThickness = outlineThickness,
        gradientIntensity = gradientIntensity,
        gradientMinOpacity = gradientMinOpacity,
        headingOffset = headingOffset, offsetIsAbsolute = offsetIsAbsolute,
    })
end

--- Add a timed cone on entity.
---@param timeout number
---@param length number Cone reach
---@param angle number Cone spread degrees
---@param heading number
---@param colorStart table?
---@param colorEnd table?
---@param colorMid table?
---@param delay number?
---@param targetAttachID number?
---@param keepLength boolean?
---@param colorOutline table?
---@param outlineThickness number?
---@param gradientIntensity number?
---@param gradientMinOpacity number?
---@param headingOffset number?
---@param offsetIsAbsolute boolean?
---@return integer|nil
function ShapeDrawer:addTimedConeOnEnt(
    timeout, length, angle, heading,
    colorStart, colorEnd, colorMid, delay,
    targetAttachID, keepLength,
    colorOutline, outlineThickness, gradientIntensity, gradientMinOpacity,
    headingOffset, offsetIsAbsolute)

    return self:_createOnEnt("cone", {
        timeout = timeout, length = length, angle = angle, heading = heading,
        colorStart = colorStart, colorEnd = colorEnd, colorMid = colorMid,
        delay = delay, targetAttachID = targetAttachID, keepLength = keepLength,
        colorOutline = colorOutline, outlineThickness = outlineThickness,
        gradientIntensity = gradientIntensity,
        gradientMinOpacity = gradientMinOpacity,
        headingOffset = headingOffset, offsetIsAbsolute = offsetIsAbsolute,
    })
end

--- Add a timed donut-cone on entity.
---@param timeout number
---@param innerRadius number
---@param outerRadius number
---@param angle number
---@param heading number
---@param colorStart table?
---@param colorEnd table?
---@param colorMid table?
---@param delay number?
---@param targetAttachID number?
---@param keepLength boolean?
---@param colorOutline table?
---@param outlineThickness number?
---@param gradientIntensity number?
---@param gradientMinOpacity number?
---@param headingOffset number?
---@param offsetIsAbsolute boolean?
---@return integer|nil
function ShapeDrawer:addTimedDonutConeOnEnt(
    timeout, innerRadius, outerRadius, angle, heading,
    colorStart, colorEnd, colorMid, delay,
    targetAttachID, keepLength,
    colorOutline, outlineThickness, gradientIntensity, gradientMinOpacity,
    headingOffset, offsetIsAbsolute)

    return self:_createOnEnt("donut_cone", {
        timeout = timeout, innerRadius = innerRadius, outerRadius = outerRadius,
        angle = angle, heading = heading,
        colorStart = colorStart, colorEnd = colorEnd, colorMid = colorMid,
        delay = delay, targetAttachID = targetAttachID, keepLength = keepLength,
        colorOutline = colorOutline, outlineThickness = outlineThickness,
        gradientIntensity = gradientIntensity,
        gradientMinOpacity = gradientMinOpacity,
        headingOffset = headingOffset, offsetIsAbsolute = offsetIsAbsolute,
    })
end

--- Add a timed cross on entity.
---@param timeout number
---@param length number
---@param width number
---@param heading number
---@param colorStart table?
---@param colorEnd table?
---@param colorMid table?
---@param delay number?
---@param targetAttachID number?
---@param keepLength boolean?
---@param colorOutline table?
---@param outlineThickness number?
---@param gradientIntensity number?
---@param gradientMinOpacity number?
---@param headingOffset number?
---@param offsetIsAbsolute boolean?
---@return integer|nil
function ShapeDrawer:addTimedCrossOnEnt(
    timeout, length, width, heading,
    colorStart, colorEnd, colorMid, delay,
    targetAttachID, keepLength,
    colorOutline, outlineThickness, gradientIntensity, gradientMinOpacity,
    headingOffset, offsetIsAbsolute)

    return self:_createOnEnt("cross", {
        timeout = timeout, length = length, width = width, heading = heading,
        colorStart = colorStart, colorEnd = colorEnd, colorMid = colorMid,
        delay = delay, targetAttachID = targetAttachID, keepLength = keepLength,
        colorOutline = colorOutline, outlineThickness = outlineThickness,
        gradientIntensity = gradientIntensity,
        gradientMinOpacity = gradientMinOpacity,
        headingOffset = headingOffset, offsetIsAbsolute = offsetIsAbsolute,
    })
end

--- Add a timed arrow on entity.
---@param timeout number
---@param length number
---@param width number
---@param heading number
---@param colorStart table?
---@param colorEnd table?
---@param colorMid table?
---@param delay number?
---@param targetAttachID number?
---@param keepLength boolean?
---@param colorOutline table?
---@param outlineThickness number?
---@param gradientIntensity number?
---@param gradientMinOpacity number?
---@param headingOffset number?
---@param offsetIsAbsolute boolean?
---@return integer|nil
function ShapeDrawer:addTimedArrowOnEnt(
    timeout, length, width, heading,
    colorStart, colorEnd, colorMid, delay,
    targetAttachID, keepLength,
    colorOutline, outlineThickness, gradientIntensity, gradientMinOpacity,
    headingOffset, offsetIsAbsolute)

    return self:_createOnEnt("arrow", {
        timeout = timeout, length = length, width = width, heading = heading,
        colorStart = colorStart, colorEnd = colorEnd, colorMid = colorMid,
        delay = delay, targetAttachID = targetAttachID, keepLength = keepLength,
        colorOutline = colorOutline, outlineThickness = outlineThickness,
        gradientIntensity = gradientIntensity,
        gradientMinOpacity = gradientMinOpacity,
        headingOffset = headingOffset, offsetIsAbsolute = offsetIsAbsolute,
    })
end

--- Add a timed chevron on entity.
---@param timeout number
---@param length number
---@param width number
---@param heading number
---@param colorStart table?
---@param colorEnd table?
---@param colorMid table?
---@param delay number?
---@param targetAttachID number?
---@param keepLength boolean?
---@param colorOutline table?
---@param outlineThickness number?
---@param gradientIntensity number?
---@param gradientMinOpacity number?
---@param headingOffset number?
---@param offsetIsAbsolute boolean?
---@return integer|nil
function ShapeDrawer:addTimedChevronOnEnt(
    timeout, length, width, heading,
    colorStart, colorEnd, colorMid, delay,
    targetAttachID, keepLength,
    colorOutline, outlineThickness, gradientIntensity, gradientMinOpacity,
    headingOffset, offsetIsAbsolute)

    return self:_createOnEnt("chevron", {
        timeout = timeout, length = length, width = width, heading = heading,
        colorStart = colorStart, colorEnd = colorEnd, colorMid = colorMid,
        delay = delay, targetAttachID = targetAttachID, keepLength = keepLength,
        colorOutline = colorOutline, outlineThickness = outlineThickness,
        gradientIntensity = gradientIntensity,
        gradientMinOpacity = gradientMinOpacity,
        headingOffset = headingOffset, offsetIsAbsolute = offsetIsAbsolute,
    })
end

-- ═══════════════════════════════════════════════════════════════════════════
--  MODULE EXPORT
-- ═══════════════════════════════════════════════════════════════════════════

return Argus2, ShapeDrawer
