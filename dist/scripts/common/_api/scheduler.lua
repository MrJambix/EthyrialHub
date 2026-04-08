--[[
╔══════════════════════════════════════════════════════════════╗
║          Scheduler — Coroutine-based Async Tasks             ║
║                                                              ║
║  Run multiple tasks concurrently using Lua coroutines.       ║
║  Supports wait(), wait_until(), wait_frames(), cancel().     ║
║                                                              ║
║  Usage:                                                      ║
║    local sched = require("common/_api/scheduler")            ║
║    sched.async(function()                                    ║
║        sched.wait(1.0)           -- wait 1 second            ║
║        sched.wait_until(fn)      -- wait until fn() is true  ║
║    end)                                                      ║
╚══════════════════════════════════════════════════════════════╝
]]

local scheduler = {}

local _tasks = {}      -- { { co, resume_at, wait_fn, name, id, status } }
local _next_id = 1
local _current_task = nil  -- the task currently executing (for yield calls)

-- ══════════════════════════════════════════════════════════════
-- Task creation
-- ══════════════════════════════════════════════════════════════

--- Launch an async task. Returns task ID.
function scheduler.async(fn, name)
    local co = coroutine.create(fn)
    local id = _next_id
    _next_id = _next_id + 1

    local task = {
        co = co,
        resume_at = 0,
        wait_fn = nil,
        name = name or ("task_" .. id),
        id = id,
        status = "running",
    }

    _tasks[#_tasks + 1] = task

    -- Immediately run until first yield
    _current_task = task
    local ok, err = coroutine.resume(co)
    _current_task = nil

    if not ok then
        task.status = "error"
        if core and core.log_error then
            core.log_error("[Scheduler] Task '" .. task.name .. "' error: " .. tostring(err))
        end
    elseif coroutine.status(co) == "dead" then
        task.status = "done"
    end

    return id
end

--- Cancel a running task by ID.
function scheduler.cancel(task_id)
    for i, task in ipairs(_tasks) do
        if task.id == task_id then
            task.status = "cancelled"
            return true
        end
    end
    return false
end

--- Cancel all tasks.
function scheduler.cancel_all()
    for _, task in ipairs(_tasks) do
        task.status = "cancelled"
    end
end

-- ══════════════════════════════════════════════════════════════
-- Yield functions — call from inside an async task
-- ══════════════════════════════════════════════════════════════

--- Wait for N seconds.
function scheduler.wait(seconds)
    if not _current_task then error("scheduler.wait() called outside async task") end
    local now = core and core.time() or os.clock()
    _current_task.resume_at = now + seconds
    _current_task.wait_fn = nil
    coroutine.yield()
end

--- Wait until predicate function returns true.
function scheduler.wait_until(fn, timeout)
    if not _current_task then error("scheduler.wait_until() called outside async task") end
    local now = core and core.time() or os.clock()
    _current_task.resume_at = timeout and (now + timeout) or math.huge
    _current_task.wait_fn = fn
    coroutine.yield()
end

--- Wait for N tick/update cycles.
function scheduler.wait_frames(n)
    if not _current_task then error("scheduler.wait_frames() called outside async task") end
    n = n or 1
    for _ = 1, n do
        _current_task.resume_at = 0
        _current_task.wait_fn = nil
        coroutine.yield()
    end
end

--- Yield once (let other tasks run, resume next tick).
function scheduler.yield()
    if not _current_task then return end
    _current_task.resume_at = 0
    _current_task.wait_fn = nil
    coroutine.yield()
end

-- ══════════════════════════════════════════════════════════════
-- Tick — call every frame to drive all coroutines
-- ══════════════════════════════════════════════════════════════

function scheduler.tick()
    local now = core and core.time() or os.clock()
    local alive = {}

    for _, task in ipairs(_tasks) do
        if task.status == "cancelled" or task.status == "error" then
            -- drop it
        elseif task.status == "done" then
            -- drop it
        elseif coroutine.status(task.co) == "dead" then
            task.status = "done"
        else
            local should_resume = false

            if task.wait_fn then
                -- Check predicate
                local ok_pred, result = pcall(task.wait_fn)
                if (ok_pred and result) or now >= task.resume_at then
                    should_resume = true
                end
            elseif now >= task.resume_at then
                should_resume = true
            end

            if should_resume then
                task.wait_fn = nil
                _current_task = task
                local ok, err = coroutine.resume(task.co)
                _current_task = nil

                if not ok then
                    task.status = "error"
                    if core and core.log_error then
                        core.log_error("[Scheduler] Task '" .. task.name .. "' error: " .. tostring(err))
                    end
                elseif coroutine.status(task.co) == "dead" then
                    task.status = "done"
                end
            end

            if task.status ~= "done" and task.status ~= "error" and task.status ~= "cancelled" then
                alive[#alive + 1] = task
            end
        end
    end

    _tasks = alive
end

--- Get number of active tasks.
function scheduler.active_count()
    local n = 0
    for _, task in ipairs(_tasks) do
        if task.status == "running" then n = n + 1 end
    end
    return n
end

--- Get list of active task names.
function scheduler.active_tasks()
    local names = {}
    for _, task in ipairs(_tasks) do
        if task.status ~= "done" and task.status ~= "error" and task.status ~= "cancelled" then
            names[#names + 1] = task.name
        end
    end
    return names
end

return scheduler
