-- ═══════════════════════════════════════════════════════════════
--  core.humanize — Anti-detection timing & session management
--
--  Gaussian-distributed delays, micro-pauses, and session
--  break patterns to make bot behavior look human.
--
--  Usage:
--    local delay = core.humanize.reaction_delay()
--    _ethy_sleep(delay)
-- ═══════════════════════════════════════════════════════════════

local M = {}

math.randomseed(os.time() + (os.clock() * 1000))

-- ─── Box-Muller normal distribution ──────────────────────────
local function box_muller()
    local u1 = math.random()
    local u2 = math.random()
    if u1 < 1e-10 then u1 = 1e-10 end
    return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
end

--- Gaussian-distributed delay in seconds.
---@param mean_ms number  Mean delay in milliseconds
---@param std_ms  number  Standard deviation in milliseconds
---@return number seconds
function M.gaussian_delay(mean_ms, std_ms)
    local d = mean_ms + box_muller() * std_ms
    d = math.max(30, math.min(d, mean_ms * 4))
    return d / 1000
end

--- Simulated human reaction time (~250ms ± 55ms).
function M.reaction_delay()
    return M.gaussian_delay(250, 55)
end

--- Simulated cast-queue reaction (~180ms ± 40ms).
function M.cast_delay()
    return M.gaussian_delay(180, 40)
end

--- Sleep for base_seconds with ±30% jitter.
function M.jittered_sleep(base_seconds)
    local jitter = base_seconds * (0.7 + math.random() * 0.6)
    _ethy_sleep(jitter)
end

--- Roll a misplay chance (default 3%).
function M.should_misplay(chance)
    chance = chance or 0.03
    return math.random() < chance
end

--- Random pause between min_s and max_s seconds.
function M.random_pause(min_s, max_s)
    min_s = min_s or 0.5
    max_s = max_s or 3.0
    _ethy_sleep(min_s + math.random() * (max_s - min_s))
end

-- ═══════════════════════════════════════════════════════════════
--  SESSION MANAGER
--  Tracks play time, triggers periodic micro-breaks and longer
--  breaks to mimic human session patterns.
-- ═══════════════════════════════════════════════════════════════

M.session = {
    _start_time = nil,
    _last_break = nil,
    _micro_interval = nil,
    _break_interval = nil,
}

function M.session.start()
    local s = M.session
    s._start_time = core.time()
    s._last_break = core.time()
    s._micro_interval = 300 + math.random() * 600     -- 5-15 min
    s._break_interval = 2700 + math.random() * 2700   -- 45-90 min
end

--- Check if a break is due.
---@return string action  "long_break" | "micro_pause" | "ok"
---@return number duration  Seconds to break for (0 if ok)
function M.session.check()
    local s = M.session
    if not s._start_time then s.start() end

    local now = core.time()
    local since_break = now - s._last_break

    if since_break >= s._break_interval then
        local break_len = 180 + math.random() * 420   -- 3-10 min
        s._last_break = now + break_len
        s._break_interval = 2700 + math.random() * 2700
        s._micro_interval = 300 + math.random() * 600
        return "long_break", break_len
    end

    if since_break >= s._micro_interval then
        local pause_len = 3 + math.random() * 15      -- 3-18 sec
        s._last_break = now
        s._micro_interval = 300 + math.random() * 600
        return "micro_pause", pause_len
    end

    return "ok", 0
end

function M.session.elapsed()
    if not M.session._start_time then return 0 end
    return core.time() - M.session._start_time
end

return M
