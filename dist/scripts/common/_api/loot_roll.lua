-- ═══════════════════════════════════════════════════════════════
--  core.loot_roll — Need / Greed / Pass roll windows
--
--  Usage:
--    local rolls = core.loot_roll.scan()
--    core.loot_roll.greed_all()
-- ═══════════════════════════════════════════════════════════════

local M = {}

-- Detect whether native core.loot_roll bindings exist.
-- Falls back to core.send_command() if not available.
local _has_native = (type(core.loot_roll) == "table")

local function _send(cmd)
    return core.send_command(cmd)
end

--- Scan for pending NeedGreed roll windows (raw IPC string).
function M.scan_raw()
    if _has_native then return core.loot_roll.scan() end
    return _send("NEED_GREED_SCAN")
end

--- Parse scan results into a Lua table.
--- Each entry: { item, timer, remaining, ptr, qptr }
function M.scan()
    local raw = M.scan_raw()
    if not raw or raw == "NONE" or raw:find("^NO_") then return {} end
    local results = {}
    for entry in raw:gmatch("[^#]+") do
        entry = entry:match("^%s*(.-)%s*$")
        if entry ~= "" and not entry:match("^count=") then
            local t = {}
            for k, v in entry:gmatch("([%w_]+)=([^|]+)") do
                t[k] = tonumber(v) or v
            end
            if t.item then results[#results + 1] = t end
        end
    end
    return results
end

--- Send a choice (NEED, GREED, or PASS) for a specific roll window.
---@param ptr string  Hex pointer from scan results
---@param choice string  "NEED", "GREED", or "PASS"
function M.choose(ptr, choice)
    if _has_native then return core.loot_roll.choose(tostring(ptr), tostring(choice)) end
    return _send("NEED_GREED_CHOOSE " .. tostring(ptr) .. " " .. tostring(choice))
end

--- Convenience: greed on all pending rolls.
function M.greed_all()
    if _has_native then return core.loot_roll.greed_all() end
    return _send("NEED_GREED_GREED_ALL")
end

return M
