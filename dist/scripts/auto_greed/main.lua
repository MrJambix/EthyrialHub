--[[
  Auto Greed — Party Loot Roll
  Automatically clicks Greed on every NeedGreed loot roll popup.

  How it works:
    1. Polls for active NeedGreed roll windows each tick
    2. When a pending roll is detected, waits a short human-like delay
    3. Sends the Greed choice for that roll
    4. Logs every item greeded with timestamp

  Menu options:
    - Enable/Disable toggle
    - Configurable reaction delay (min/max)
    - Log of recently greeded items
]]

local ethy = require("common/ethy_sdk")

ethy.print("=== Auto Greed loaded ===")

-- ── Config ───────────────────────────────────────────────────
local POLL_RATE     = 0.5       -- how often to check for roll windows (seconds)
local DELAY_MIN     = 0.4       -- minimum delay before clicking greed
local DELAY_MAX     = 1.8       -- maximum delay before clicking greed
local MAX_LOG       = 30        -- recent items to keep in log

-- ── State ────────────────────────────────────────────────────
local enabled       = true
local last_poll     = 0
local stats         = { greeded = 0, passed = 0, session_start = nil }
local event_log     = {}        -- { time, item, result }
local pending       = {}        -- ptr -> { item, detected_at, fire_at }

local function log(msg, ...)
    ethy.printf("[AutoGreed] " .. msg, ...)
end

local function add_event(item, result)
    event_log[#event_log + 1] = {
        time   = ethy.now(),
        item   = item,
        result = result,
    }
    while #event_log > MAX_LOG do
        table.remove(event_log, 1)
    end
end

local function random_delay()
    return DELAY_MIN + math.random() * (DELAY_MAX - DELAY_MIN)
end

-- ── Scan & act ───────────────────────────────────────────────

local function scan_and_greed()
    -- Use the parsed scan from ethy_sdk
    local rolls = ethy.loot_roll.scan()

    -- Track which ptrs are still active
    local active_ptrs = {}

    for _, roll in ipairs(rolls) do
        local ptr = roll.ptr
        active_ptrs[ptr] = true

        if not pending[ptr] then
            -- New roll detected — schedule greed after a delay
            local delay = random_delay()
            pending[ptr] = {
                item        = roll.item or "Unknown",
                detected_at = ethy.now(),
                fire_at     = ethy.now() + delay,
                remaining   = roll.remaining or 0,
            }
            log("Roll detected: %s (greed in %.1fs)", roll.item or "?", delay)
        end
    end

    -- Clean up rolls that disappeared (timed out / someone else rolled)
    for ptr, info in pairs(pending) do
        if not active_ptrs[ptr] then
            log("Roll expired before we greeded: %s", info.item)
            pending[ptr] = nil
        end
    end

    -- Fire greed on any that have passed their delay
    local now = ethy.now()
    for ptr, info in pairs(pending) do
        if now >= info.fire_at then
            local result = ethy.loot_roll.choose(ptr, "GREED")
            if result == "OK" then
                stats.greeded = stats.greeded + 1
                add_event(info.item, "GREED")
                log("Greeded: %s (#%d)", info.item, stats.greeded)
            else
                add_event(info.item, "FAIL: " .. tostring(result))
                log("Failed to greed %s: %s", info.item, tostring(result))
            end
            pending[ptr] = nil
        end
    end
end

-- ── Update loop ──────────────────────────────────────────────

ethy.on_update(function()
    if not enabled then return end
    if not stats.session_start then stats.session_start = ethy.now() end

    local now = ethy.now()
    if now - last_poll < POLL_RATE then return end
    last_poll = now

    local player = ethy.get_player()
    if not player then return end

    scan_and_greed()
end)

-- ── Menu overlay ─────────────────────────────────────────────

ethy.on_render_menu(function()
    enabled = core.menu.checkbox("ag_on", "Auto Greed", enabled)

    if enabled then
        DELAY_MIN = core.menu.slider_float("ag_dmin", "Min Delay", DELAY_MIN, 0.1, 3.0)
        DELAY_MAX = core.menu.slider_float("ag_dmax", "Max Delay", DELAY_MAX, 0.2, 5.0)
        if DELAY_MAX < DELAY_MIN then DELAY_MAX = DELAY_MIN + 0.1 end
        POLL_RATE = core.menu.slider_float("ag_poll", "Poll Rate", POLL_RATE, 0.1, 2.0)
    end
end)

ethy.print("Auto Greed ready — will greed on all party loot rolls.")
