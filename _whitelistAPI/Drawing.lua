-- ═══════════════════════════════════════════════════════════════════════════
--  WHITELISTED ADDON API  —  DRAWING & GRAPHICS
--  Namespaces: core.graphics.*, core.draw.*, Argus2 module
--  Category:   2D/3D Rendering, Ground Shapes, Telegraphs
-- ═══════════════════════════════════════════════════════════════════════════
--
--  Draw overlay text, lines, circles, and rectangles in 2D/3D space.
--  Use ground-projected shapes for telegraphs, AoE indicators, and
--  navigation markers via the Argus2 shape system.
--
-- ───────────────────────────────────────────────────────────────────────────

-- ┌─────────────────────────────────────────────────────────────┐
-- │  core.graphics.*  —  Overlay 2D/3D Drawing                 │
-- └─────────────────────────────────────────────────────────────┘

--- Create a color object (for use with other draw calls).
---@param r number 0-255
---@param g number 0-255
---@param b number 0-255
---@param a? number 0-255 (default 255)
---@return userdata color
-- core.graphics.color(r, g, b, a)

--- Get screen dimensions.
---@return number width, number height
-- core.graphics.screen_size()

--- Measure text size at given font size.
---@param text string
---@param size number
---@return number width, number height
-- core.graphics.text_size(text, size)

--- Set camera data for world-to-screen projection.
-- core.graphics.set_camera()

--- Convert world position to screen coordinates.
---@param x number
---@param y number
---@param z number
---@return number sx, number sy, boolean on_screen
-- core.graphics.world_to_screen(x, y, z)

--- Draw 2D text on the overlay.
---@param x number
---@param y number
---@param text string
---@param color userdata
---@param size number
-- core.graphics.text_2d(x, y, text, color, size)

--- Draw a 2D line.
---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
---@param color userdata
---@param thickness? number
-- core.graphics.line_2d(x1, y1, x2, y2, color, thickness)

--- Draw a 2D rectangle.
---@param x number
---@param y number
---@param w number
---@param h number
---@param color userdata
---@param filled? boolean
-- core.graphics.rect_2d(x, y, w, h, color, filled)

--- Draw a 2D circle.
---@param x number
---@param y number
---@param radius number
---@param color userdata
---@param segments? number
-- core.graphics.circle_2d(x, y, radius, color, segments)

--- Draw 3D text at world coordinates.
---@param x number
---@param y number
---@param z number
---@param text string
---@param color userdata
---@param size number
-- core.graphics.text_3d(x, y, z, text, color, size)

--- Draw a 3D line between two world points.
---@param x1 number
---@param y1 number
---@param z1 number
---@param x2 number
---@param y2 number
---@param z2 number
---@param color userdata
---@param thickness? number
-- core.graphics.line_3d(x1, y1, z1, x2, y2, z2, color, thickness)

--- Draw a 3D circle at world coordinates.
---@param x number
---@param y number
---@param z number
---@param radius number
---@param color userdata
---@param segments? number
-- core.graphics.circle_3d(x, y, z, radius, color, segments)

-- ┌─────────────────────────────────────────────────────────────┐
-- │  core.draw.*  —  Ground Shape System                       │
-- └─────────────────────────────────────────────────────────────┘

--- Initialize the overlay draw system.
-- core.draw.init()

--- Draw a line on the ground.
---@param x1 number
---@param y1 number
---@param z1 number
---@param x2 number
---@param y2 number
---@param z2 number
---@param r number 0-1
---@param g number 0-1
---@param b number 0-1
---@param a number 0-1
-- core.draw.line(x1, y1, z1, x2, y2, z2, r, g, b, a)

--- Draw a circle on the ground.
---@param x number
---@param y number
---@param z number
---@param radius number
---@param r number 0-1
---@param g number 0-1
---@param b number 0-1
---@param a number 0-1
-- core.draw.circle(x, y, z, radius, r, g, b, a)

--- Hide all drawn shapes.
-- core.draw.hide()

--- Clear all drawn shapes.
-- core.draw.clear()

-- ── Ground-Projected Mesh Shapes ──────────────────────────────

--- Initialize the ground mesh draw system.
-- core.draw.ground_init()

--- Get ground draw system status.
---@return string status
-- core.draw.ground_status()

--- Draw a circle projected on the ground mesh.
---@param x number
---@param y number
---@param z number
---@param radius number
---@param r number 0-1
---@param g number 0-1
---@param b number 0-1
---@param a number 0-1
-- core.draw.ground_circle(x, y, z, radius, r, g, b, a)

--- Draw a cone projected on the ground mesh.
---@param x number
---@param y number
---@param z number
---@param radius number
---@param angle number  cone angle (degrees)
---@param heading number  direction (radians)
---@param r number 0-1
---@param g number 0-1
---@param b number 0-1
---@param a number 0-1
-- core.draw.ground_cone(x, y, z, radius, angle, heading, r, g, b, a)

--- Draw a line projected on the ground mesh.
---@param x1 number @param y1 number @param z1 number
---@param x2 number @param y2 number @param z2 number
---@param r number @param g number @param b number @param a number
-- core.draw.ground_line(x1, y1, z1, x2, y2, z2, r, g, b, a)

--- Draw a donut (ring) projected on the ground mesh.
---@param x number @param y number @param z number
---@param inner_radius number
---@param outer_radius number
---@param r number @param g number @param b number @param a number
-- core.draw.ground_donut(x, y, z, inner_radius, outer_radius, r, g, b, a)

--- Hide all ground shapes.
-- core.draw.ground_hide()

--- Clear all ground shapes.
-- core.draw.ground_clear()

--- Draw a ground mesh (advanced).
-- core.draw.ground_mesh(...)

-- ┌─────────────────────────────────────────────────────────────┐
-- │  Argus2 Module  —  Timed Shape System & Entity Attachments │
-- │  (require via: local Argus2 = require("argus2"))           │
-- └─────────────────────────────────────────────────────────────┘

--- Add a timed rectangle at world position.
---@param duration number  seconds to display
---@param x number @param y number @param z number
---@param w number @param h number
---@param r number @param g number @param b number @param a number
---@param heading number  rotation
---@return number id
-- Argus2.addTimedRect(duration, x, y, z, w, h, r, g, b, a, heading)

--- Add a timed centered rectangle.
---@param duration number
---@param cx number @param cy number @param cz number
---@param w number @param h number
---@param r number @param g number @param b number @param a number
---@param heading number
---@return number id
-- Argus2.addTimedCenteredRect(duration, cx, cy, cz, w, h, r, g, b, a, heading)

--- Add a timed filled cone.
---@param duration number
---@param cx number @param cy number @param cz number
---@param radius number @param angle number @param heading number
---@param r number @param g number @param b number @param a number
---@return number id
-- Argus2.addTimedConeFilled(duration, cx, cy, cz, radius, angle, heading, r, g, b, a)

--- Add a timed donut cone (ring sector).
---@param duration number
---@param cx number @param cy number @param cz number
---@param inner_radius number @param outer_radius number
---@param angle number @param heading number
---@param r number @param g number @param b number @param a number
---@return number id
-- Argus2.addTimedDonutConeFilled(duration, cx, cy, cz, inner_radius, outer_radius, angle, heading, r, g, b, a)

--- Add a timed cross marker.
---@param duration number
---@param cx number @param cy number @param cz number
---@param size number
---@param r number @param g number @param b number @param a number
---@return number id
-- Argus2.addTimedCross(duration, cx, cy, cz, size, r, g, b, a)

--- Add a timed arrow between two world points.
---@param duration number
---@param x1 number @param y1 number @param z1 number
---@param x2 number @param y2 number @param z2 number
---@param r number @param g number @param b number @param a number
---@return number id
-- Argus2.addTimedArrow(duration, x1, y1, z1, x2, y2, z2, r, g, b, a)

--- Add a timed chevron marker.
---@param duration number
---@param cx number @param cy number @param cz number
---@param heading number @param size number
---@param r number @param g number @param b number @param a number
---@return number id
-- Argus2.addTimedChevron(duration, cx, cy, cz, heading, size, r, g, b, a)

--- Remove a timed shape by ID.
---@param id number
-- Argus2.removeShape(id)

--- Update all timed shapes (call from on_update).
-- Argus2.onTick()

-- ── ShapeDrawer  —  Entity-Attached Shapes ────────────────────
-- local sd = ShapeDrawer.new(entity_uid)
-- sd:addTimedRectOnEnt(duration, w, h, r, g, b, a, ...)
-- sd:addTimedConeOnEnt(duration, radius, angle, heading, r, g, b, a, ...)
-- sd:addTimedDonutConeOnEnt(duration, ir, or, angle, heading, r, g, b, a, ...)
-- sd:addTimedCrossOnEnt(duration, size, r, g, b, a, ...)
