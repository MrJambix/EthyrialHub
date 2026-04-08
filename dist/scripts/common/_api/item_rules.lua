--[[
╔══════════════════════════════════════════════════════════════╗
║        ItemRules — Inventory Automation Engine               ║
║                                                              ║
║  Auto-use items based on conditions (HP potions when low,    ║
║  food when buff drops, equipment set swapping).              ║
║                                                              ║
║  Usage:                                                      ║
║    local items = require("common/_api/item_rules")           ║
║    items.use_when("Health Potion", function()                ║
║        return ethy.hp() < 40                                 ║
║    end)                                                      ║
╚══════════════════════════════════════════════════════════════╝
]]

local items = {}

-- Internal state
local _rules = {}          -- { { name, condition, cooldown, last_used, priority } }
local _equipment_sets = {} -- { set_name = { slot = item_name, ... } }
local _inv_cache = nil
local _inv_cache_time = 0
local _inv_cache_ttl = 1.0  -- seconds

-- ══════════════════════════════════════════════════════════════
-- Inventory Cache
-- ══════════════════════════════════════════════════════════════

local function refresh_inventory()
    local now = core and core.time() or os.clock()
    if _inv_cache and now - _inv_cache_time < _inv_cache_ttl then
        return _inv_cache
    end

    _inv_cache = {}
    if conn and conn.send_command then
        local raw = conn.send_command("INV_ALL")
        if raw and raw ~= "NONE" and raw ~= "" then
            for entry in raw:gmatch("[^#]+") do
                local item = {}
                for k, v in entry:gmatch("([%w_]+)=([^|]+)") do
                    item[k] = tonumber(v) or v
                end
                if item.name then
                    _inv_cache[#_inv_cache + 1] = item
                end
            end
        end
    end

    _inv_cache_time = now
    return _inv_cache
end

-- ══════════════════════════════════════════════════════════════
-- Item Queries
-- ══════════════════════════════════════════════════════════════

--- Find an item by name. Returns item data or nil.
function items.find(name)
    local inv = refresh_inventory()
    for _, item in ipairs(inv) do
        if item.name == name then return item end
    end
    return nil
end

--- Find all items matching a pattern.
function items.find_all(pattern)
    local inv = refresh_inventory()
    local results = {}
    for _, item in ipairs(inv) do
        if item.name and item.name:find(pattern) then
            results[#results + 1] = item
        end
    end
    return results
end

--- Count how many of an item we have.
function items.count(name)
    local inv = refresh_inventory()
    local total = 0
    for _, item in ipairs(inv) do
        if item.name == name then
            total = total + (item.count or item.qty or 1)
        end
    end
    return total
end

--- Check if we have an item.
function items.has(name)
    return items.find(name) ~= nil
end

--- Get full inventory list.
function items.inventory()
    return refresh_inventory()
end

--- Use an item by name.
function items.use(name)
    if conn and conn.send_command then
        return conn.send_command("USE_ITEM " .. name)
    end
    return "ERR:NO_CONNECTION"
end

--- Equip an item by name.
function items.equip(name)
    if conn and conn.send_command then
        return conn.send_command("EQUIP_ITEM " .. name)
    end
    return "ERR:NO_CONNECTION"
end

--- Unequip a slot.
function items.unequip(slot)
    if conn and conn.send_command then
        return conn.send_command("UNEQUIP_SLOT " .. slot)
    end
    return "ERR:NO_CONNECTION"
end

-- ══════════════════════════════════════════════════════════════
-- Auto-use Rules
-- ══════════════════════════════════════════════════════════════

--- Register a rule to auto-use an item when a condition is met.
--- @param name string     Item name
--- @param condition function  Returns true when item should be used
--- @param cooldown number   Minimum seconds between uses (default 1.0)
--- @param priority number   Higher = checked first (default 0)
function items.use_when(name, condition, cooldown, priority)
    _rules[#_rules + 1] = {
        name = name,
        condition = condition,
        cooldown = cooldown or 1.0,
        last_used = 0,
        priority = priority or 0,
    }

    -- Sort by priority (highest first)
    table.sort(_rules, function(a, b) return a.priority > b.priority end)
end

--- Remove a rule by item name.
function items.remove_rule(name)
    for i = #_rules, 1, -1 do
        if _rules[i].name == name then
            table.remove(_rules, i)
            return true
        end
    end
    return false
end

--- Clear all rules.
function items.clear_rules()
    _rules = {}
end

-- ══════════════════════════════════════════════════════════════
-- Equipment Sets
-- ══════════════════════════════════════════════════════════════

--- Save the current equipment as a named set.
function items.save_set(set_name)
    if conn and conn.send_command then
        local raw = conn.send_command("EQUIPPED")
        if raw and raw ~= "NONE" then
            local equipment = {}
            for entry in raw:gmatch("[^#]+") do
                local slot, name
                for k, v in entry:gmatch("([%w_]+)=([^|]+)") do
                    if k == "slot" then slot = v
                    elseif k == "name" then name = v
                    end
                end
                if slot and name then
                    equipment[slot] = name
                end
            end
            _equipment_sets[set_name] = equipment
            return true
        end
    end
    return false
end

--- Equip a saved equipment set.
function items.load_set(set_name)
    local set = _equipment_sets[set_name]
    if not set then return false end

    for slot, item_name in pairs(set) do
        items.equip(item_name)
    end
    return true
end

--- List saved set names.
function items.list_sets()
    local names = {}
    for name, _ in pairs(_equipment_sets) do
        names[#names + 1] = name
    end
    return names
end

-- ══════════════════════════════════════════════════════════════
-- Tick — call every frame to process rules
-- ══════════════════════════════════════════════════════════════

function items.tick()
    local now = core and core.time() or os.clock()

    for _, rule in ipairs(_rules) do
        if now - rule.last_used >= rule.cooldown then
            local ok, should_use = pcall(rule.condition)
            if ok and should_use then
                if items.has(rule.name) then
                    local result = items.use(rule.name)
                    if result and result:find("OK") then
                        rule.last_used = now
                        _inv_cache = nil  -- invalidate cache
                    end
                end
            end
        end
    end
end

--- Get debug info.
function items.debug()
    return {
        rules = #_rules,
        sets = #items.list_sets(),
        inv_size = _inv_cache and #_inv_cache or 0,
    }
end

return items
