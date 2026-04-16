-- ═══════════════════════════════════════════════════════════════════════════
--  WHITELISTED ADDON API  —  IN-GAME UI (Unity Canvas)
--  Namespace: game.ui.*
--  Category:  Unity UI Elements — Panels, Text, Bars, Drag
-- ═══════════════════════════════════════════════════════════════════════════
--
--  Create Unity Canvas UI elements (panels, text labels, progress bars),
--  control visibility, color, position, drag-to-move, and parent/child
--  relationships. For the OOP wrapper, see EthyUI.lua in this folder.
--
-- ───────────────────────────────────────────────────────────────────────────

---@class GameUIAPI

--- Initialize the in-game UI system. Must be called once before creating elements.
---@return boolean success
-- game.ui.init()

--- Create a panel (solid background rectangle).
---@param x number
---@param y number
---@param w number
---@param h number
---@param r number 0-1
---@param g number 0-1
---@param b number 0-1
---@param a number 0-1
---@return number handle
-- game.ui.panel(x, y, w, h, r, g, b, a)

--- Create a text label as child of a parent panel.
---@param parent number  parent handle
---@param x number
---@param y number
---@param w number
---@param h number
---@param size number  font size
---@param r number 0-1
---@param g number 0-1
---@param b number 0-1
---@param a number 0-1
---@param text string  initial text content
---@return number handle
-- game.ui.text(parent, x, y, w, h, size, r, g, b, a, text)

--- Create a progress bar (background + fill child).
---@param parent number  parent handle
---@param x number
---@param y number
---@param w number
---@param h number
---@param bgR number  background color R (0-1)
---@param bgG number  background color G
---@param bgB number  background color B
---@param bgA number  background color A
---@param fillR number  fill color R (0-1)
---@param fillG number  fill color G
---@param fillB number  fill color B
---@param fillA number  fill color A
---@return number handle
-- game.ui.bar(parent, x, y, w, h, bgR, bgG, bgB, bgA, fillR, fillG, fillB, fillA)

--- Update text content.
---@param handle number
---@param text string
---@return boolean success
-- game.ui.set_text(handle, text)

--- Set bar fill value (0 = empty, 1 = full).
---@param handle number
---@param value number  0.0 – 1.0
---@return boolean success
-- game.ui.set_value(handle, value)

--- Set element position.
---@param handle number
---@param x number
---@param y number
---@return boolean success
-- game.ui.set_pos(handle, x, y)

--- Set element size.
---@param handle number
---@param w number
---@param h number
---@return boolean success
-- game.ui.set_size(handle, w, h)

--- Set element color.
---@param handle number
---@param r number 0-1
---@param g number 0-1
---@param b number 0-1
---@param a number 0-1
---@return boolean success
-- game.ui.set_color(handle, r, g, b, a)

--- Set text font size.
---@param handle number
---@param size number
---@return boolean success
-- game.ui.set_font_size(handle, size)

--- Show or hide an element.
---@param handle number
---@param visible boolean
---@return boolean success
-- game.ui.set_visible(handle, visible)

--- Enable or disable drag-to-move on a panel.
---@param handle number
---@param movable boolean
---@return boolean success
-- game.ui.set_movable(handle, movable)

--- Reparent a UI element under a new parent.
---@param handle number
---@param parent_handle number
---@return boolean success
-- game.ui.set_parent(handle, parent_handle)

--- Get current element position.
---@param handle number
---@return number x, number y, boolean ok
-- game.ui.get_pos(handle)

--- Destroy a single UI element.
---@param handle number
---@return boolean success
-- game.ui.destroy(handle)

--- Destroy all UI elements.
---@return boolean success
-- game.ui.destroy_all()

--- Get UI system status string.
---@return string status
-- game.ui.status()

--- Debug: dump all Unity canvas hierarchy.
---@param depth? number  max depth (default 3)
---@param budget? number  max elements (default 200)
---@return boolean success
-- game.ui.dump_canvases(depth, budget)

--- Debug: dump a specific UI path subtree.
---@param path string  GameObject path
---@param depth? number
---@param budget? number
---@return boolean success
-- game.ui.dump_path(path, depth, budget)

-- ═══════════════════════════════════════════════════════════════════════════
--  OOP Wrapper: See EthyUI.lua in this folder for Frame/Text/Bar classes
--  with cascading destroy, profile save/load, and convenience builders.
-- ═══════════════════════════════════════════════════════════════════════════
