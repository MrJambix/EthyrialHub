local ethy = require("common/ethy_sdk")

ethy.print("=== Auto Loot loaded ===")

local POLL_RATE      = 0.3
local CORPSE_RANGE   = 3.0
local INTERACT_CD    = 3

local last_tick      = 0
local interact_log   = {}
local stats          = { looted = 0, corpses_opened = 0 }

local function log(msg, ...)
    ethy.printf("[AutoLoot] " .. msg, ...)
end

local function parse_lines(raw)
    if not raw or raw == "" or raw == "NONE" then return {} end
    local results = {}
    for entry in raw:gmatch("[^#]+") do
        entry = entry:match("^%s*(.-)%s*$")
        if entry ~= "" and not entry:match("^count=") then
            local t = {}
            for k, v in entry:gmatch("([%w_]+)=([^|]+)") do
                if k == "ptr" then
                    t[k] = v
                else
                    local num = tonumber(v)
                    t[k] = num ~= nil and num or v
                end
            end
            if next(t) then results[#results + 1] = t end
        end
    end
    return results
end

local function is_safe()
    local hp = core.player.hp()
    if not hp or hp <= 0 then return false end
    if core.player.frozen() then return false end
    return true
end

local function is_on_cooldown(uid)
    if not uid then return false end
    local exp = interact_log[uid]
    if not exp then return false end
    if ethy.now() > exp then
        interact_log[uid] = nil
        return false
    end
    return true
end

local function mark_interacted(uid)
    if uid then
        interact_log[uid] = ethy.now() + INTERACT_CD
    end
end

local function try_loot_windows()
    local count = tonumber(core.send_command("LOOT_WINDOW_COUNT")) or 0
    if count > 0 then
        local result = core.inventory.loot_all()
        stats.looted = stats.looted + 1
        log("Looted %d window(s) -> %s  (total: %d)", count, tostring(result), stats.looted)
        return true
    end
    return false
end

local last_debug = 0
local function try_open_corpses()
    local raw = core.entities.scene_scan("corpse")
    local entities = parse_lines(raw)
    local opened = 0

    local now = ethy.now()
    if #entities > 0 and now - last_debug > 3 then
        last_debug = now
        local nearest = entities[1]
        log("Scan: %d corpse(s), nearest: class=%s name=%s dist=%.1f uid=%s",
            #entities, tostring(nearest.class), tostring(nearest.name),
            nearest.dist or 999, tostring(nearest.uid))
    end

    for _, e in ipairs(entities) do
        local dist = e.dist or 999
        local uid  = e.uid
        local ptr  = e.ptr
        local cls  = e.class or ""

        if cls:lower():find("corpse") and dist <= CORPSE_RANGE and not is_on_cooldown(uid) then
            mark_interacted(uid)
            local result = core.send_command("USE_PTR_" .. ptr)
            stats.corpses_opened = stats.corpses_opened + 1
            opened = opened + 1
            log("Opened corpse uid=%s ptr=%s dist=%.1f -> %s  (total: %d)",
                tostring(uid), tostring(ptr), dist, tostring(result), stats.corpses_opened)
        end
    end
    return opened
end

local function tick()
    local now = ethy.now()
    if now - last_tick < POLL_RATE then return end
    last_tick = now

    if not is_safe() then return end

    try_open_corpses()
    try_loot_windows()
end

ethy.on_update(function()
    tick()
end)

ethy.print("Auto Loot ready.")
