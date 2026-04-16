-- ════════════════════════════════════════════════════════════════════════════
-- EthyUI — WoW-style Addon UI Framework
--
-- Creates real Unity GameObjects inside the game via IL2CPP.
-- Addons call safe, clean OOP methods — no raw handles, no IL2CPP knowledge.
--
-- Usage:
--   local ui = require("EthyUI")
--
--   local frame = ui.frame({ x=0, y=100, w=220, h=160, a=0.9 })
--   frame:set_movable(true)
--
--   local title = frame:add_text({ y=60, text="My Addon", font_size=18 })
--
--   local hp = frame:add_bar({ y=20, w=200, h=22,
--       fill_r=0.1, fill_g=0.85, fill_b=0.2 })
--   hp:set_value(0.75)
--
--   frame:destroy()
-- ════════════════════════════════════════════════════════════════════════════

local EthyUI = {}
EthyUI._VERSION = "1.0"

local _inited = false
local function _ensure_init()
    if _inited then return true end
    if game and game.ui and game.ui.init then
        _inited = game.ui.init()
    end
    return _inited
end

-- ── Frame ──────────────────────────────────────────────────────────────────
-- A panel rendered as a Unity Image/RawImage on the game's screen-space canvas.

local Frame = {}
Frame.__index = Frame

--- Create a top-level frame (panel) in the game UI.
-- @param opts table {x, y, w, h, r, g, b, a}
-- @return Frame or nil
function EthyUI.frame(opts)
    if not _ensure_init() then return nil end
    opts = opts or {}
    local x = opts.x or 0
    local y = opts.y or 0
    local w = opts.w or 200
    local h = opts.h or 150
    local r = opts.r or 0.08
    local g = opts.g or 0.08
    local b = opts.b or 0.12
    local a = opts.a or 0.88

    local handle = game.ui.panel(x, y, w, h, r, g, b, a)
    if handle == 0 then return nil end

    local self = setmetatable({}, Frame)
    self._handle   = handle
    self._x = x
    self._y = y
    self._w = w
    self._h = h
    self._children = {}
    self._visible  = true
    return self
end

function Frame:set_pos(x, y)
    self._x = x; self._y = y
    game.ui.set_pos(self._handle, x, y)
    return self
end

function Frame:set_size(w, h)
    self._w = w; self._h = h
    game.ui.set_size(self._handle, w, h)
    return self
end

function Frame:set_color(r, g, b, a)
    game.ui.set_color(self._handle, r, g, b, a or 1)
    return self
end

function Frame:set_visible(visible)
    self._visible = visible
    game.ui.set_visible(self._handle, visible)
    -- Cascade to children
    for _, child in ipairs(self._children) do
        if child.set_visible then child:set_visible(visible) end
    end
    return self
end

function Frame:set_movable(movable)
    game.ui.set_movable(self._handle, movable ~= false)
    return self
end

function Frame:get_pos()
    local x, y, ok = game.ui.get_pos(self._handle)
    if ok then self._x = x; self._y = y end
    return x, y
end

function Frame:set_parent(parentFrame)
    local ph = 0
    if parentFrame and parentFrame._handle then ph = parentFrame._handle end
    game.ui.set_parent(self._handle, ph)
    return self
end

--- Create a child text element inside this frame.
-- @param opts table {x, y, w, h, font_size, r, g, b, a, text}
-- @return Text or nil
function Frame:add_text(opts)
    return EthyUI._create_text(self, opts)
end

--- Create a child bar inside this frame.
-- @param opts table {x, y, w, h, bg_r, bg_g, bg_b, bg_a, fill_r, fill_g, fill_b, fill_a}
-- @return Bar or nil
function Frame:add_bar(opts)
    return EthyUI._create_bar(self, opts)
end

--- Create a child frame (sub-panel) inside this frame.
-- @param opts table {x, y, w, h, r, g, b, a}
-- @return Frame or nil
function Frame:add_frame(opts)
    return EthyUI._create_child_frame(self, opts)
end

function Frame:destroy()
    -- Children are Unity-parented, so destroying the parent GO destroys them.
    -- But we also clear Lua references for GC.
    for _, child in ipairs(self._children) do
        if child._handle then child._handle = nil end
        if child._children then
            for _, gc in ipairs(child._children) do
                if gc._handle then gc._handle = nil end
            end
        end
    end
    self._children = {}
    if self._handle then
        game.ui.destroy(self._handle)
        self._handle = nil
    end
end

-- ── Text ───────────────────────────────────────────────────────────────────

local Text = {}
Text.__index = Text

function EthyUI._create_text(parent, opts)
    if not _ensure_init() then return nil end
    opts = opts or {}
    local parentHandle = (parent and parent._handle) or 0
    local x  = opts.x or 0
    local y  = opts.y or 0
    local w  = opts.w or (parent and parent._w or 200)
    local h  = opts.h or 30
    local fs = opts.font_size or 14
    local r  = opts.r or 1
    local g  = opts.g or 1
    local b  = opts.b or 1
    local a  = opts.a or 1
    local tx = opts.text or ""

    local handle = game.ui.text(parentHandle, x, y, w, h, fs, r, g, b, a, tx)
    if handle == 0 then return nil end

    local self = setmetatable({}, Text)
    self._handle = handle

    if parent and parent._children then
        table.insert(parent._children, self)
    end
    return self
end

function Text:set_text(t)
    if self._handle then game.ui.set_text(self._handle, t) end
    return self
end

function Text:set_pos(x, y)
    if self._handle then game.ui.set_pos(self._handle, x, y) end
    return self
end

function Text:set_size(w, h)
    if self._handle then game.ui.set_size(self._handle, w, h) end
    return self
end

function Text:set_color(r, g, b, a)
    if self._handle then game.ui.set_color(self._handle, r, g, b, a or 1) end
    return self
end

function Text:set_font_size(size)
    if self._handle then game.ui.set_font_size(self._handle, size) end
    return self
end

function Text:set_visible(visible)
    if self._handle then game.ui.set_visible(self._handle, visible) end
    return self
end

function Text:destroy()
    if self._handle then
        game.ui.destroy(self._handle)
        self._handle = nil
    end
end

-- ── Bar ────────────────────────────────────────────────────────────────────
-- A fill bar: background panel + left-aligned fill child.
-- set_value(0..1) controls the fill percentage.

local Bar = {}
Bar.__index = Bar

function EthyUI._create_bar(parent, opts)
    if not _ensure_init() then return nil end
    opts = opts or {}
    local parentHandle = (parent and parent._handle) or 0
    local x      = opts.x or 0
    local y      = opts.y or 0
    local w      = opts.w or (parent and parent._w or 180)
    local h      = opts.h or 20
    local bgR    = opts.bg_r  or 0.12
    local bgG    = opts.bg_g  or 0.12
    local bgB    = opts.bg_b  or 0.12
    local bgA    = opts.bg_a  or 0.9
    local fillR  = opts.fill_r or 0.2
    local fillG  = opts.fill_g or 0.8
    local fillB  = opts.fill_b or 0.2
    local fillA  = opts.fill_a or 1.0

    local handle = game.ui.bar(parentHandle, x, y, w, h,
                               bgR, bgG, bgB, bgA,
                               fillR, fillG, fillB, fillA)
    if handle == 0 then return nil end

    local self = setmetatable({}, Bar)
    self._handle = handle
    self._value  = 1.0

    if parent and parent._children then
        table.insert(parent._children, self)
    end
    return self
end

--- Set the fill level (0.0 = empty, 1.0 = full).
function Bar:set_value(v)
    if v < 0 then v = 0 end
    if v > 1 then v = 1 end
    self._value = v
    if self._handle then game.ui.set_value(self._handle, v) end
    return self
end

function Bar:get_value()
    return self._value
end

--- Set fill color.
function Bar:set_color(r, g, b, a)
    if self._handle then game.ui.set_color(self._handle, r, g, b, a or 1) end
    return self
end

function Bar:set_pos(x, y)
    if self._handle then game.ui.set_pos(self._handle, x, y) end
    return self
end

function Bar:set_size(w, h)
    if self._handle then game.ui.set_size(self._handle, w, h) end
    return self
end

function Bar:set_visible(visible)
    if self._handle then game.ui.set_visible(self._handle, visible) end
    return self
end

function Bar:destroy()
    if self._handle then
        game.ui.destroy(self._handle)
        self._handle = nil
    end
end

-- ── Child Frame (sub-panel) ────────────────────────────────────────────────

function EthyUI._create_child_frame(parent, opts)
    if not _ensure_init() then return nil end
    opts = opts or {}
    local x = opts.x or 0
    local y = opts.y or 0
    local w = opts.w or 100
    local h = opts.h or 60
    local r = opts.r or 0.1
    local g = opts.g or 0.1
    local b = opts.b or 0.14
    local a = opts.a or 0.85

    -- Create as top-level panel then reparent
    local handle = game.ui.panel(x, y, w, h, r, g, b, a)
    if handle == 0 then return nil end

    if parent and parent._handle then
        game.ui.set_parent(handle, parent._handle)
    end

    local self = setmetatable({}, Frame)
    self._handle   = handle
    self._x = x
    self._y = y
    self._w = w
    self._h = h
    self._children = {}
    self._visible  = true

    if parent and parent._children then
        table.insert(parent._children, self)
    end
    return self
end

-- ── Utility ────────────────────────────────────────────────────────────────

--- Destroy all addon-created UI elements.
function EthyUI.destroy_all()
    game.ui.destroy_all()
end

--- Get UI bridge status string from DLL.
function EthyUI.status()
    return game.ui.status()
end

-- ── Profile (save/load layout positions to file) ───────────────────────────

--- Save a table of {name=frame} positions to a Lua file.
-- @param path string  file path (e.g. "MyAddon_layout.lua")
-- @param frames table {name = frameObj, ...}
function EthyUI.profile_save(path, frames)
    local lines = { "return {" }
    for name, frame in pairs(frames) do
        if frame.get_pos then
            local x, y = frame:get_pos()
            table.insert(lines, string.format(
                '  [%q] = { x = %.1f, y = %.1f },', name, x, y))
        end
    end
    table.insert(lines, "}")

    local f = io.open(path, "w")
    if not f then return false end
    f:write(table.concat(lines, "\n"))
    f:close()
    return true
end

--- Load saved positions and apply them to frames.
-- @param path string  file path
-- @param frames table {name = frameObj, ...}
function EthyUI.profile_load(path, frames)
    local f = io.open(path, "r")
    if not f then return false end
    local src = f:read("*a")
    f:close()

    local fn, err = load(src)
    if not fn then return false end
    local ok, data = pcall(fn)
    if not ok or type(data) ~= "table" then return false end

    for name, pos in pairs(data) do
        local frame = frames[name]
        if frame and frame.set_pos and pos.x and pos.y then
            frame:set_pos(pos.x, pos.y)
        end
    end
    return true
end

return EthyUI
