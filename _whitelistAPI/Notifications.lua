-- ═══════════════════════════════════════════════════════════════════════════
--  WHITELISTED ADDON API  —  NOTIFICATIONS
--  Namespace: notify.* (module)
--  Category:  Toast Alerts, In-Game Popups, Overlay Notifications
-- ═══════════════════════════════════════════════════════════════════════════
--
--  Show overlay and in-game toast notifications for status updates,
--  warnings, errors, toggle states, and combat events.
--
-- ───────────────────────────────────────────────────────────────────────────

-- ┌─────────────────────────────────────────────────────────────┐
-- │  Overlay Toasts  —  Drawn via ImGui overlay                │
-- └─────────────────────────────────────────────────────────────┘

--- Show an info toast (blue).
---@param message string
-- notify.info(message)

--- Show a success toast (green).
---@param message string
-- notify.success(message)

--- Show a warning toast (yellow).
---@param message string
-- notify.warning(message)

--- Show an error toast (red).
---@param message string
-- notify.error(message)

--- Show a "toggle ON" toast (green).
---@param message string
-- notify.toggle_on(message)

--- Show a "toggle OFF" toast (gray).
---@param message string
-- notify.toggle_off(message)

--- Show a combat alert toast (orange).
---@param message string
-- notify.combat(message)

--- Show a custom toast with explicit color and duration.
---@param title string
---@param color table  {r, g, b, a} (0-1 each)
---@param duration? number  seconds (default 3)
-- notify.toast(title, color, duration)

--- Show a big center-screen notification.
---@param title string
---@param color table  {r, g, b, a}
---@param duration? number  seconds (default 4)
-- notify.big(title, color, duration)

--- Render overlay notifications (call from on_render callback).
-- notify.render()

--- Auto-register render + tick callbacks. Call once at addon startup.
-- notify.install()

--- Clear all active notifications.
-- notify.clear()

-- ┌─────────────────────────────────────────────────────────────┐
-- │  In-Game Toasts  —  Unity Canvas UI notifications          │
-- └─────────────────────────────────────────────────────────────┘

--- Show an in-game info toast (blue, Unity UI).
---@param message string
-- notify.in_game.info(message)

--- Show an in-game success toast (green, Unity UI).
---@param message string
-- notify.in_game.success(message)

--- Show an in-game error toast (red, Unity UI).
---@param message string
-- notify.in_game.error(message)

--- Update & expire in-game toasts (call from on_update or auto via install).
-- notify.tick()
