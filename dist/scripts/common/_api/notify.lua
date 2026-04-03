--[[
╔══════════════════════════════════════════════════════════════╗
║             EthyrialHub — Notification System                ║
║                                                              ║
║  Queue-based on-screen toast / alert notifications.          ║
║  Renders via ImGui foreground draw list during on_render.    ║
║                                                              ║
║  Usage:                                                      ║
║    local notify = require("common/_api/notify")              ║
║    notify.info("Hello world")                                ║
║    notify.success("Kill confirmed!")                         ║
║    notify.warning("Low mana!")                               ║
║    notify.error("Connection lost")                           ║
║    notify.toast("Custom", {r=1,g=1,b=0}, 3.0)               ║
║    notify.big("BOSS INCOMING", {r=1,g=0.2,b=0.2}, 2.0)      ║
║                                                              ║
║  Call notify.render() from your on_render callback, or       ║
║  call notify.install() once to auto-register.                ║
╚══════════════════════════════════════════════════════════════╝
]]

local notify = {}

-- ═══════════════════════════════════════════════════════════════
--  CONFIG
-- ═══════════════════════════════════════════════════════════════

local CFG = {
    -- Toast position (top-right corner)
    TOAST_ANCHOR_X   = 0.98,    -- fraction of screen width (right side)
    TOAST_ANCHOR_Y   = 0.06,    -- fraction of screen height (top)
    TOAST_WIDTH      = 320,     -- toast box width in pixels
    TOAST_HEIGHT     = 36,      -- toast box height in pixels
    TOAST_PADDING    = 6,       -- vertical gap between stacked toasts
    TOAST_MAX        = 8,       -- max visible toasts at once

    -- Big notification (center screen)
    BIG_ANCHOR_Y     = 0.25,    -- fraction of screen height

    -- Animation
    FADE_IN_TIME     = 0.15,    -- seconds to fade in
    FADE_OUT_TIME    = 0.4,     -- seconds to fade out
    DEFAULT_DURATION = 3.0,     -- default display time
    BIG_DURATION     = 2.5,
}

-- ═══════════════════════════════════════════════════════════════
--  PRESETS  (ASCII-safe icons — Unicode doesn't render in ImGui default font)
-- ═══════════════════════════════════════════════════════════════

local PRESET = {
    info       = { r = 0.55, g = 0.82, b = 1.00, icon = "[i]",  bg = { r = 0.08, g = 0.12, b = 0.22 } },
    success    = { r = 0.30, g = 0.92, b = 0.40, icon = "[OK]", bg = { r = 0.06, g = 0.18, b = 0.08 } },
    warning    = { r = 1.00, g = 0.85, b = 0.20, icon = "[!!]", bg = { r = 0.22, g = 0.18, b = 0.04 } },
    error      = { r = 1.00, g = 0.30, b = 0.25, icon = "[X]",  bg = { r = 0.22, g = 0.06, b = 0.06 } },
    toggle_on  = { r = 0.30, g = 0.95, b = 0.50, icon = "[+]",  bg = { r = 0.06, g = 0.20, b = 0.08 } },
    toggle_off = { r = 0.95, g = 0.35, b = 0.30, icon = "[-]",  bg = { r = 0.22, g = 0.06, b = 0.06 } },
    combat     = { r = 1.00, g = 0.60, b = 0.15, icon = "[!]",  bg = { r = 0.24, g = 0.12, b = 0.04 } },
}

-- ═══════════════════════════════════════════════════════════════
--  STATE
-- ═══════════════════════════════════════════════════════════════

local queue = {}           -- active toast notifications
local big_queue = {}       -- center-screen big notifications
local gfx = nil            -- resolved lazily
local now_fn               -- time function

local function get_now()
    if now_fn then return now_fn() end
    if core and core.time then
        now_fn = core.time
        return now_fn()
    end
    local ok, ethy = pcall(require, "common/ethy_sdk")
    if ok and ethy and ethy.now then
        now_fn = ethy.now
        return now_fn()
    end
    now_fn = os.clock
    return now_fn()
end

-- ═══════════════════════════════════════════════════════════════
--  COLOR HELPER
--
--  core.graphics.color() returns an IM_COL32 integer (ABGR packed).
--  But text_2d/rect_2d pass it through LuaColorToImU32 which, when
--  given an integer, re-interprets it as 0xRRGGBB — swapping R/B
--  and losing alpha.
--
--  Fix: adding +0.0 coerces integer→float in Lua 5.3+, which hits
--  the lua_isnumber (not lua_isinteger) path in C++. That path does
--  a raw cast: (ImU32)value — passing the IM_COL32 through unchanged.
-- ═══════════════════════════════════════════════════════════════

local function ensure_gfx()
    if gfx then return true end
    if core and core.graphics then
        gfx = core.graphics
        return true
    end
    return false
end

local function rgba(r, g, b, a)
    if not ensure_gfx() then return 0xFFFFFFFF end
    return gfx.color(
        math.floor(r * 255 + 0.5),
        math.floor(g * 255 + 0.5),
        math.floor(b * 255 + 0.5),
        math.floor((a or 1) * 255 + 0.5)
    ) + 0.0  -- coerce to float to bypass broken integer path
end

-- ═══════════════════════════════════════════════════════════════
--  DRAW HELPERS  (use correct API signatures)
-- ═══════════════════════════════════════════════════════════════

local function draw_rect_filled(x, y, w, h, col)
    gfx.rect_2d(x, y, w, h, col, true)
end

local function draw_rect_outline(x, y, w, h, col)
    gfx.rect_2d(x, y, w, h, col, false)
end

local function draw_text(x, y, text, col)
    gfx.text_2d(x, y, text, col)
end

local function screen_size()
    local w, h = 1920, 1080
    pcall(function() w, h = gfx.screen_size() end)
    return w, h
end

-- ═══════════════════════════════════════════════════════════════
--  INTERNAL: Push notifications
-- ═══════════════════════════════════════════════════════════════

local function push_toast(msg, color, duration, preset_name)
    local preset = PRESET[preset_name] or PRESET.info
    local c = color or preset
    local bg = preset.bg or { r = 0.10, g = 0.10, b = 0.14 }

    table.insert(queue, 1, {
        text      = tostring(msg),
        icon      = preset.icon or "",
        color     = c,
        bg_color  = bg,
        duration  = duration or CFG.DEFAULT_DURATION,
        created   = get_now(),
    })

    while #queue > CFG.TOAST_MAX * 2 do
        table.remove(queue)
    end
end

local function push_big(msg, color, duration)
    table.insert(big_queue, 1, {
        text     = tostring(msg),
        color    = color or { r = 1, g = 1, b = 1 },
        duration = duration or CFG.BIG_DURATION,
        created  = get_now(),
    })
    while #big_queue > 3 do
        table.remove(big_queue)
    end
end

-- ═══════════════════════════════════════════════════════════════
--  RENDER — call from on_render callback
-- ═══════════════════════════════════════════════════════════════

function notify.render()
    if not ensure_gfx() then return end

    local now = get_now()
    local sw, sh = screen_size()

    -- ── Toasts (top-right, stacking down) ─────────────────────────
    local base_x = sw * CFG.TOAST_ANCHOR_X - CFG.TOAST_WIDTH
    local base_y = sh * CFG.TOAST_ANCHOR_Y
    local y_off = 0
    local drawn = 0

    local i = 1
    while i <= #queue do
        local e = queue[i]
        local age = now - e.created
        local lifetime = e.duration + CFG.FADE_OUT_TIME

        if age > lifetime then
            table.remove(queue, i)
        else
            if drawn < CFG.TOAST_MAX then
                -- Alpha curve: fade in → hold → fade out
                local a = 1.0
                if age < CFG.FADE_IN_TIME then
                    a = age / CFG.FADE_IN_TIME
                elseif age > e.duration then
                    a = 1.0 - (age - e.duration) / CFG.FADE_OUT_TIME
                end
                a = math.max(0, math.min(1, a))

                -- Slide in from right during fade-in
                local slide = math.min(1.0, age / CFG.FADE_IN_TIME)
                local x = base_x + (1 - slide) * 80
                local y = base_y + y_off
                local w = CFG.TOAST_WIDTH
                local h = CFG.TOAST_HEIGHT
                local bg = e.bg_color
                local c  = e.color

                -- 1) Background fill
                draw_rect_filled(x, y, w, h, rgba(bg.r, bg.g, bg.b, a * 0.85))

                -- 2) Left accent bar (4px wide)
                draw_rect_filled(x, y, 4, h, rgba(c.r, c.g, c.b, a))

                -- 3) Thin border outline
                draw_rect_outline(x, y, w, h, rgba(c.r, c.g, c.b, a * 0.35))

                -- 4) Icon text (colored)
                if e.icon ~= "" then
                    draw_text(x + 10, y + 10, e.icon, rgba(c.r, c.g, c.b, a * 0.7))
                end

                -- 5) Message text (bright white for contrast)
                local text_x = (e.icon ~= "") and (x + 10 + #e.icon * 8 + 6) or (x + 12)
                draw_text(text_x, y + 10, e.text, rgba(1, 1, 1, a))

                y_off = y_off + h + CFG.TOAST_PADDING
                drawn = drawn + 1
            end
            i = i + 1
        end
    end

    -- ── Big center-screen notifications ───────────────────────────
    local j = 1
    while j <= #big_queue do
        local e = big_queue[j]
        local age = now - e.created
        local lifetime = e.duration + CFG.FADE_OUT_TIME

        if age > lifetime then
            table.remove(big_queue, j)
        else
            local a = 1.0
            if age < CFG.FADE_IN_TIME then
                a = age / CFG.FADE_IN_TIME
            elseif age > e.duration then
                a = 1.0 - (age - e.duration) / CFG.FADE_OUT_TIME
            end
            a = math.max(0, math.min(1, a))

            local c = e.color
            local text_w = #e.text * 9  -- rough char width estimate
            local cx = (sw - text_w) * 0.5
            local cy = sh * CFG.BIG_ANCHOR_Y + (j - 1) * 50

            -- Background pill behind big text
            draw_rect_filled(cx - 16, cy - 6, text_w + 32, 30, rgba(0, 0, 0, a * 0.6))
            draw_rect_outline(cx - 16, cy - 6, text_w + 32, 30, rgba(c.r, c.g, c.b, a * 0.4))

            -- Shadow
            draw_text(cx + 1, cy + 1, e.text, rgba(0, 0, 0, a * 0.5))

            -- Main text
            draw_text(cx, cy, e.text, rgba(c.r, c.g, c.b, a))

            j = j + 1
        end
    end
end

-- ═══════════════════════════════════════════════════════════════
--  PUBLIC API
-- ═══════════════════════════════════════════════════════════════

--- Show an info toast (blue)
function notify.info(msg, duration)
    push_toast(msg, nil, duration, "info")
end

--- Show a success toast (green)
function notify.success(msg, duration)
    push_toast(msg, nil, duration, "success")
end

--- Show a warning toast (yellow)
function notify.warning(msg, duration)
    push_toast(msg, nil, duration, "warning")
end

--- Show an error toast (red)
function notify.error(msg, duration)
    push_toast(msg, nil, duration, "error")
end

--- Show a toggle-ON toast
function notify.toggle_on(msg, duration)
    push_toast(msg, nil, duration or 2.0, "toggle_on")
end

--- Show a toggle-OFF toast
function notify.toggle_off(msg, duration)
    push_toast(msg, nil, duration or 2.0, "toggle_off")
end

--- Show a combat toast (orange)
function notify.combat(msg, duration)
    push_toast(msg, nil, duration, "combat")
end

--- Show a custom toast with explicit color
function notify.toast(msg, color, duration, preset)
    push_toast(msg, color, duration, preset or "info")
end

--- Show a big center-screen notification
function notify.big(msg, color, duration)
    push_big(msg, color, duration)
end

--- Show a toggle notification with state
function notify.toggle(name, enabled, duration)
    if enabled then
        notify.toggle_on(name .. " — ENABLED", duration)
    else
        notify.toggle_off(name .. " — DISABLED", duration)
    end
end

--- Clear all notifications
function notify.clear()
    queue = {}
    big_queue = {}
end

--- Get active toast count
function notify.count()
    return #queue + #big_queue
end

-- ═══════════════════════════════════════════════════════════════
--  KEYBIND TOGGLE HELPER
-- ═══════════════════════════════════════════════════════════════

-- Track previous key states for edge detection
local _key_prev = {}

--- Check if a key was just pressed this frame (rising edge).
--- Use this in on_update, NOT on_render (which runs per-frame too).
function notify.key_just_pressed(vk_code)
    local pressed = false
    pcall(function()
        pressed = core.menu.is_key_just_pressed(vk_code)
    end)
    return pressed
end

--- Helper: Toggle a boolean with a keybind and show notification.
--- Returns the new state.
--- @param state boolean current state
--- @param vk_code integer virtual key code
--- @param name string display name for the notification
--- @return boolean new_state
function notify.keybind_toggle(state, vk_code, name)
    if notify.key_just_pressed(vk_code) then
        state = not state
        notify.toggle(name, state)
    end
    return state
end

-- ═══════════════════════════════════════════════════════════════
--  AUTO-INSTALL
-- ═══════════════════════════════════════════════════════════════

local _installed = false

--- Register the render callback automatically.
--- Safe to call multiple times.
function notify.install()
    if _installed then return end
    _installed = true

    if core and core.register_on_render_callback then
        core.register_on_render_callback(function()
            notify.render()
        end)
    end
end

-- ═══════════════════════════════════════════════════════════════
--  VIRTUAL KEY CONSTANTS (common keys)
-- ═══════════════════════════════════════════════════════════════

notify.VK = {
    -- Function keys
    F1 = 0x70, F2 = 0x71, F3 = 0x72, F4 = 0x73,
    F5 = 0x74, F6 = 0x75, F7 = 0x76, F8 = 0x77,
    F9 = 0x78, F10 = 0x79, F11 = 0x7A, F12 = 0x7B,

    -- Number keys
    KEY_0 = 0x30, KEY_1 = 0x31, KEY_2 = 0x32, KEY_3 = 0x33,
    KEY_4 = 0x34, KEY_5 = 0x35, KEY_6 = 0x36, KEY_7 = 0x37,
    KEY_8 = 0x38, KEY_9 = 0x39,

    -- Numpad
    NUM_0 = 0x60, NUM_1 = 0x61, NUM_2 = 0x62, NUM_3 = 0x63,
    NUM_4 = 0x64, NUM_5 = 0x65, NUM_6 = 0x66, NUM_7 = 0x67,
    NUM_8 = 0x68, NUM_9 = 0x69,
    NUM_MULTIPLY = 0x6A, NUM_ADD = 0x6B, NUM_SUBTRACT = 0x6D,
    NUM_DECIMAL = 0x6E, NUM_DIVIDE = 0x6F,

    -- Modifiers
    SHIFT = 0x10, CTRL = 0x11, ALT = 0x12,
    LSHIFT = 0xA0, RSHIFT = 0xA1,
    LCTRL = 0xA2, RCTRL = 0xA3,

    -- Common
    TAB = 0x09, ENTER = 0x0D, ESCAPE = 0x1B, SPACE = 0x20,
    BACKSPACE = 0x08, DELETE = 0x2E, INSERT = 0x2D,
    HOME = 0x24, END_ = 0x23,
    PAGE_UP = 0x21, PAGE_DOWN = 0x22,
    LEFT = 0x25, UP = 0x26, RIGHT = 0x27, DOWN = 0x28,

    -- Special
    TILDE = 0xC0, MINUS = 0xBD, EQUALS = 0xBB,
    LBRACKET = 0xDB, RBRACKET = 0xDD,
    BACKSLASH = 0xDC, SEMICOLON = 0xBA,
    QUOTE = 0xDE, COMMA = 0xBC, PERIOD = 0xBE, SLASH = 0xBF,
}

return notify
