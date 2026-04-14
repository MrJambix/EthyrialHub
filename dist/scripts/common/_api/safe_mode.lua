-- ═══════════════════════════════════════════════════════════════
--  core.safe_mode — Prevention / Anti-Detection System
--
--  When an admin or watchlist player is detected, enters AFK
--  mode: stops movement, clears target, cancels casts, optionally
--  casts RestSpell to sit down. Delays resume with randomized
--  cooldown so you don't instantly start farming when they leave.
--
--  All scripts should gate their main loop with:
--    if core.safe_mode.is_active() then <pause logic> end
--  or the shorthand:
--    if _G.safe_mode_active then return end
--
--  Entity Radar drives the enter/exit lifecycle:
--    core.safe_mode.enter(reason)     -- admin spotted
--    core.safe_mode.signal_clear()    -- admin left, start countdown
--    core.safe_mode.tick()            -- call each radar cycle
-- ═══════════════════════════════════════════════════════════════

local M = {}

math.randomseed(os.time() + (os.clock() * 1000))

-- ── Config ───────────────────────────────────────────────────
M.RESUME_DELAY_MIN  = 15      -- min seconds after admin leaves before resuming
M.RESUME_DELAY_MAX  = 45      -- max seconds
M.TRY_REST          = true    -- cast RestSpell to look AFK (sitting)
M.CLEAR_TARGET      = true    -- untarget hostile on enter
M.STOP_MOVEMENT     = true    -- stop movement on enter
M.CLEAR_QUEUE       = true    -- clear pending command queue on enter
M.REST_RECAST_INTERVAL = 25   -- re-cast rest every N seconds while paused

-- ── Player Detection Config ──────────────────────────────────
M.PLAYER_PAUSE       = true    -- pause scripts when ANY player is nearby
M.PLAYER_SCAN_RATE   = 2.0    -- seconds between player scans
M.LOGOUT_TIMEOUT     = 120    -- seconds: log out if a player lingers this long
M.LOGOUT_ENABLED     = true   -- enable forced logout on timeout

-- ── Internal State ───────────────────────────────────────────
local active        = false
local enter_time    = 0
local resume_time   = 0       -- epoch when allowed to resume (0 = not counting)
local resume_delay  = 0       -- randomized delay for this pause instance
local last_rest     = 0       -- last time we cast rest to maintain sitting

-- Player detection state
local player_first_seen = 0   -- when we first spotted a nearby player
local player_nearby     = false
local last_player_scan  = 0
local nearby_player_name = nil

-- ── Globals (readable by any script) ─────────────────────────
_G.safe_mode_active = false

-- ═══════════════════════════════════════════════════════════════
-- Public API
-- ═══════════════════════════════════════════════════════════════

--- Check if safe mode is currently active.
function M.is_active()
    return _G.safe_mode_active == true
end

--- How long has safe mode been active (seconds). 0 if not active.
function M.elapsed()
    if not active then return 0 end
    return core.time() - enter_time
end

--- Enter safe mode immediately. Called by entity_radar on detection.
---@param reason string  Human-readable reason for the log
function M.enter(reason)
    if active then return end  -- already safe
    active = true
    _G.safe_mode_active = true
    enter_time = core.time()
    resume_time = 0
    last_rest = 0

    -- Randomize this instance's resume delay
    resume_delay = M.RESUME_DELAY_MIN
        + math.random() * (M.RESUME_DELAY_MAX - M.RESUME_DELAY_MIN)

    print(string.format("[SafeMode] ENTERING — %s (resume delay: %.0fs)",
        reason or "admin detected", resume_delay))

    -- 1. Stop all movement
    if M.STOP_MOVEMENT then
        pcall(function() _cmd("STOP_MOVEMENT") end)
    end

    -- 2. Clear hostile target so we're not staring at a mob
    if M.CLEAR_TARGET then
        pcall(function() _cmd("UNTARGET") end)
    end

    -- 3. Flush pending command queue (stops casts in progress)
    if M.CLEAR_QUEUE then
        pcall(function() _cmd("CLEAR_COMMANDS") end)
    end

    -- 4. Try to look AFK — sit down via RestSpell
    if M.TRY_REST then
        M._try_rest()
    end
end

--- Signal that the admin threat has cleared. Starts resume countdown.
--- Does NOT immediately exit — waits resume_delay seconds first.
function M.signal_clear()
    if not active then return end
    if resume_time > 0 then return end  -- already counting down

    resume_time = core.time() + resume_delay
    print(string.format("[SafeMode] Threat cleared — will resume in %.0fs", resume_delay))
end

--- Tick — call every entity_radar cycle. Returns true when safe mode exits.
function M.tick()
    if not active then return false end

    -- If admin came back, cancel any resume countdown
    if _G.admin_detected then
        resume_time = 0

        -- Periodically re-cast rest to stay sitting
        if M.TRY_REST then
            local now = core.time()
            if now - last_rest >= M.REST_RECAST_INTERVAL then
                M._try_rest()
            end
        end

        return false
    end

    -- Start countdown if not yet started
    if resume_time == 0 then
        M.signal_clear()
        return false
    end

    -- Check if resume delay has elapsed
    if core.time() >= resume_time then
        M.exit()
        return true
    end

    return false
end

--- Exit safe mode. Called after resume delay or manually.
function M.exit()
    if not active then return end
    local elapsed = core.time() - enter_time
    active = false
    _G.safe_mode_active = false
    resume_time = 0
    last_rest = 0

    print(string.format("[SafeMode] EXITING — safe mode lasted %.0fs", elapsed))
end

-- ═══════════════════════════════════════════════════════════════
-- Player Detection — scan for nearby players and auto-pause/logout
-- Call this from gather scripts every tick.
-- Returns: "ok" | "paused" | "logout"
-- ═══════════════════════════════════════════════════════════════

--- Parse PLAYER_RADAR response into a list of player entries.
local function parse_radar(raw)
    local players = {}
    if not raw or raw == "" or raw == "NONE" or raw:find("^ERR") then
        return players
    end
    for entry in raw:gmatch("[^#]+") do
        local p = {}
        for k, v in entry:gmatch("([%w_]+)=([^|]+)") do
            p[k] = v
        end
        if p.name then
            p.dist = tonumber(p.dist) or 999
            p.hidden = p.hidden == "1"
            p.targeting_me = p.targeting_me == "1"
            p.combat = p.combat == "1"
            table.insert(players, p)
        end
    end
    return players
end

--- Scan for nearby players and manage pause/logout.
--- Call this from your gather loop every tick.
--- Returns: "ok" (no players), "paused" (player nearby, waiting),
---          "logout" (2min timeout reached, will exit game)
function M.check_players()
    if not M.PLAYER_PAUSE then return "ok" end

    local now = core.time()
    if now - last_player_scan < M.PLAYER_SCAN_RATE then
        -- Between scans, return current state
        if player_nearby then
            -- Check logout timeout
            if M.LOGOUT_ENABLED and player_first_seen > 0
               and (now - player_first_seen) >= M.LOGOUT_TIMEOUT then
                return "logout"
            end
            return "paused"
        end
        return "ok"
    end
    last_player_scan = now

    -- Scan using PLAYER_RADAR (includes hidden admins)
    local ok, raw = pcall(_cmd, "PLAYER_RADAR")
    if not ok then raw = "" end
    local players = parse_radar(raw)

    if #players > 0 then
        -- Player(s) detected
        local first = players[1]
        if not player_nearby then
            -- First detection
            player_nearby = true
            player_first_seen = now
            nearby_player_name = first.name or "Unknown"
            print(string.format("[SafeMode] Player nearby: %s (%.0fm) — pausing",
                nearby_player_name, first.dist or 0))

            -- Enter safe mode
            M.enter(string.format("player nearby: %s", nearby_player_name))
        end

        -- Check if anyone is targeting us
        for _, p in ipairs(players) do
            if p.targeting_me then
                print(string.format("[SafeMode] ⚠ %s is TARGETING YOU!", p.name or "?"))
            end
        end

        -- Check logout timeout
        if M.LOGOUT_ENABLED and (now - player_first_seen) >= M.LOGOUT_TIMEOUT then
            print(string.format(
                "[SafeMode] Player %s nearby for %ds — LOGGING OUT",
                nearby_player_name, M.LOGOUT_TIMEOUT))
            M._do_logout()
            return "logout"
        end

        return "paused"
    else
        -- No players nearby
        if player_nearby then
            local left_name = nearby_player_name or "?"
            print(string.format("[SafeMode] Player %s left — starting resume countdown", left_name))
            player_nearby = false
            player_first_seen = 0
            nearby_player_name = nil
            M.signal_clear()
            -- Notify via notify module if available
            local ok_n, nfy = pcall(require, "common/_api/notify")
            if ok_n and nfy then
                nfy.info(string.format("Player %s left — resuming in %.0fs", left_name, resume_delay))
            end
        end
        return "ok"
    end
end

--- Returns true if a player is currently nearby.
function M.player_nearby()
    return player_nearby
end

--- Returns how long the current player has been nearby (seconds).
function M.player_nearby_elapsed()
    if not player_nearby or player_first_seen == 0 then return 0 end
    return core.time() - player_first_seen
end

--- Returns the name of the nearby player (or nil).
function M.get_nearby_player_name()
    return nearby_player_name
end

--- Returns seconds until resume (0 if not counting down).
function M.resume_remaining()
    if not active or resume_time == 0 then return 0 end
    return math.max(0, resume_time - core.time())
end

-- ═══════════════════════════════════════════════════════════════
-- Internal
-- ═══════════════════════════════════════════════════════════════

--- Force logout — calls EXIT_GAME to close the game process.
function M._do_logout()
    pcall(function()
        _cmd("STOP_MOVEMENT")
        _cmd("UNTARGET")
        _cmd("CLEAR_COMMANDS")
    end)
    -- Small delay so the stop commands actually fire
    pcall(function() _ethy_sleep(0.5) end)
    pcall(function() _cmd("EXIT_GAME") end)
end

function M._try_rest()
    last_rest = core.time()
    pcall(function()
        -- Only rest if out of combat and HP isn't full (rest cancels if full)
        local hp = N(_cmd("PLAYER_HP"))
        local combat = B(_cmd("PLAYER_COMBAT"))
        if not combat then
            _cmd("CAST_RestSpell")
        end
    end)
end

return M
