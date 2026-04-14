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

--- Apply a choice (NEED, GREED, or PASS) to ALL pending rolls atomically.
---@param choice string  "NEED", "GREED", or "PASS"
function M.choose_all(choice)
    return _send("NEED_GREED_CHOOSE_ALL " .. tostring(choice))
end

--- NEED on all pending rolls.
function M.need_all()
    return M.choose_all("NEED")
end

--- PASS on all pending rolls.
function M.pass_all()
    return M.choose_all("PASS")
end

--- Atomically choose NEED/GREED/PASS for rolls matching an item name substring.
--- Iterates the live rollQueue on the main thread — no stale pointers.
---@param choice string  "NEED", "GREED", or "PASS"
---@param item_match string  Case-insensitive substring to match against item names
function M.choose_match(choice, item_match)
    return _send("NEED_GREED_CHOOSE_MATCH " .. tostring(choice) .. " " .. tostring(item_match))
end

--- Convenience: NEED any roll matching item name substring.
function M.need_match(item_match)
    return M.choose_match("NEED", item_match)
end

--- Convenience: PASS any roll matching item name substring.
function M.pass_match(item_match)
    return M.choose_match("PASS", item_match)
end

return M
