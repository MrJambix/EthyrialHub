-- ═══════════════════════════════════════════════════════════════
--  core.item_db — Item Database & Potion Tier Library
--
--  Provides tier-aware potion lookup so scripts can say:
--    "use Tier 3 health potion at 50% HP, Tier 8 at 20% HP"
--
--  Tier extraction order:
--    1. Roman numeral suffix: "Health Potion III" → tier 3
--    2. "Tier N" / "T<N>" pattern: "Health Potion Tier 5" → tier 5
--    3. Prefix keywords: Minor=1, Lesser=2, (none)=3, Greater=4,
--       Superior=5, Grand=6, Major=7, Supreme=8
--    4. Rarity fallback: Common=1 .. Artifact=7
-- ═══════════════════════════════════════════════════════════════

local item_db = {}

-- ── Internal state ────────────────────────────────────────────

local _master_cache   = nil   -- cached master DB entries
local _master_time    = 0
local _master_ttl     = 30    -- refresh every 30s
local _inv_cache      = nil
local _inv_time       = 0
local _inv_ttl        = 1.0   -- refresh every 1s
local _potion_rules   = {}    -- { {type, tier, threshold, cooldown, last_used} }

-- ── Roman numeral parser ──────────────────────────────────────

local _roman = {
    I=1, II=2, III=3, IV=4, V=5, VI=6, VII=7, VIII=8,
    IX=9, X=10, XI=11, XII=12, XIII=13, XIV=14, XV=15,
}

-- ── Prefix → tier mapping ─────────────────────────────────────

local _prefix_tier = {
    ["minor"]    = 1,
    ["lesser"]   = 2,
    ["small"]    = 2,
    ["greater"]  = 4,
    ["superior"] = 5,
    ["grand"]    = 6,
    ["major"]    = 7,
    ["supreme"]  = 8,
    ["ultimate"] = 9,
    ["divine"]   = 10,
}

-- ── Potion type keywords ──────────────────────────────────────

local _potion_types = {
    { pattern = "health",      type = "health"  },
    { pattern = "hp",          type = "health"  },
    { pattern = "healing",     type = "health"  },
    { pattern = "life",        type = "health"  },
    { pattern = "mana",        type = "mana"    },
    { pattern = "mp",          type = "mana"    },
    { pattern = "magic",       type = "mana"    },
    { pattern = "stamina",     type = "stamina" },
    { pattern = "energy",      type = "stamina" },
    { pattern = "speed",       type = "speed"   },
    { pattern = "haste",       type = "speed"   },
    { pattern = "strength",    type = "strength"},
    { pattern = "defense",     type = "defense" },
    { pattern = "armour",      type = "defense" },
    { pattern = "armor",       type = "defense" },
    { pattern = "resist",      type = "resist"  },
    { pattern = "antidote",    type = "cure"    },
    { pattern = "cleanse",     type = "cure"    },
    { pattern = "food",        type = "food"    },
    { pattern = "elixir",      type = "elixir"  },
}

-- ══════════════════════════════════════════════════════════════
-- Tier Extraction
-- ══════════════════════════════════════════════════════════════

--- Extract tier number from an item name.
--- Returns tier (int) or 3 as default (mid-tier).
function item_db.get_tier(name)
    if not name or name == "" then return 3 end

    -- 1. Check for "Tier N" or "T<N>" pattern
    local tier_num = name:match("[Tt]ier%s*(%d+)")
    if tier_num then return tonumber(tier_num) end

    local t_num = name:match("%sT(%d+)%s*$")
    if t_num then return tonumber(t_num) end

    -- 2. Check for Roman numeral suffix
    local roman = name:match("%s([IVXL]+)%s*$")
    if roman and _roman[roman] then return _roman[roman] end

    -- 3. Check for prefix keywords
    local lower = name:lower()
    for prefix, tier in pairs(_prefix_tier) do
        if lower:find(prefix, 1, true) then return tier end
    end

    -- 4. Default to mid-tier
    return 3
end

--- Classify a potion's type from its name.
--- Returns type string (e.g., "health", "mana") or "unknown".
function item_db.get_potion_type(name)
    if not name or name == "" then return "unknown" end
    local lower = name:lower()
    for _, entry in ipairs(_potion_types) do
        if lower:find(entry.pattern, 1, true) then
            return entry.type
        end
    end
    return "unknown"
end

--- Classify an item: returns {type=string, tier=int, is_potion=bool}
function item_db.classify(name, rarity)
    local tier = item_db.get_tier(name)
    local ptype = item_db.get_potion_type(name)
    local lower = (name or ""):lower()

    local is_potion = lower:find("potion", 1, true) ~= nil
                   or lower:find("elixir", 1, true) ~= nil
                   or lower:find("flask", 1, true) ~= nil
                   or lower:find("vial", 1, true) ~= nil

    -- If rarity provided and no tier extracted from name, use rarity
    if rarity and tier == 3 then
        -- Only override default if name didn't have explicit tier info
        local has_explicit = (name or ""):match("[Tt]ier%s*%d+")
                          or (name or ""):match("%s[IVXL]+%s*$")
                          or (name or ""):match("%sT%d+%s*$")
        if not has_explicit then
            for _, v in pairs(_prefix_tier) do
                if (name or ""):lower():find(_, 1, true) then
                    has_explicit = true
                    break
                end
            end
        end
        if not has_explicit then
            tier = (rarity or 0) + 1  -- Common(0)→1, Uncommon(1)→2, etc.
        end
    end

    return {
        type = ptype,
        tier = tier,
        is_potion = is_potion,
    }
end

-- ══════════════════════════════════════════════════════════════
-- Master Item Database (via IPC)
-- ══════════════════════════════════════════════════════════════

--- Search the master item database by name/category substring.
--- Returns array of {name, display, cat, rarity, rarity_name, price, tp, notable}
function item_db.search(query)
    if not query or query == "" then return {} end
    return _parse_lines(_cmd("ITEM_DB_SEARCH " .. query))
end

--- Get all items from the master database.
--- Results are cached for _master_ttl seconds.
function item_db.get_all_master()
    local now = os.clock()
    if _master_cache and now - _master_time < _master_ttl then
        return _master_cache
    end
    _master_cache = _parse_lines(_cmd("ITEM_DB_ALL"))
    _master_time = now
    return _master_cache
end

--- Search master DB for all potions/consumables.
function item_db.get_all_potions_master()
    local results = {}
    -- Search for common potion keywords
    for _, keyword in ipairs({"potion", "elixir", "flask", "vial"}) do
        local found = item_db.search(keyword)
        for _, item in ipairs(found) do
            -- Deduplicate by name
            local dupe = false
            for _, r in ipairs(results) do
                if r.name == item.name then dupe = true; break end
            end
            if not dupe then
                local info = item_db.classify(item.name, tonumber(item.rarity))
                item.potion_type = info.type
                item.tier = info.tier
                item.is_potion = info.is_potion
                results[#results + 1] = item
            end
        end
    end
    -- Sort by tier
    table.sort(results, function(a, b) return (a.tier or 0) < (b.tier or 0) end)
    return results
end

-- ══════════════════════════════════════════════════════════════
-- Inventory Potion Helpers
-- ══════════════════════════════════════════════════════════════

local function refresh_inventory()
    local now = os.clock()
    if _inv_cache and now - _inv_time < _inv_ttl then
        return _inv_cache
    end
    _inv_cache = _parse_lines(_cmd("INV_ALL"))
    _inv_time = now
    return _inv_cache
end

--- Get all potions currently in inventory, classified with tier info.
--- Returns array of {uid, name, stack, rarity, quality, category,
---                    potion_type, tier, is_potion, description}
function item_db.get_potions()
    local inv = refresh_inventory()
    local results = {}
    for _, item in ipairs(inv) do
        local lower = (item.name or ""):lower()
        if lower:find("potion", 1, true)
            or lower:find("elixir", 1, true)
            or lower:find("flask", 1, true)
            or lower:find("vial", 1, true) then
            local info = item_db.classify(item.name, tonumber(item.rarity))
            item.potion_type = info.type
            item.tier = info.tier
            item.is_potion = true
            results[#results + 1] = item
        end
    end
    table.sort(results, function(a, b) return (a.tier or 0) < (b.tier or 0) end)
    return results
end

--- Find a potion in inventory by type (e.g., "health", "mana").
--- If min_tier given, only returns potions >= that tier.
--- Returns array of matching potions sorted by tier ascending.
function item_db.find_potion(ptype, min_tier)
    min_tier = min_tier or 0
    local potions = item_db.get_potions()
    local results = {}
    for _, p in ipairs(potions) do
        if p.potion_type == ptype and (p.tier or 0) >= min_tier then
            results[#results + 1] = p
        end
    end
    return results
end

--- Find the best (highest tier) potion of a given type in inventory.
--- Returns single potion table or nil.
function item_db.find_best_potion(ptype)
    local potions = item_db.find_potion(ptype, 0)
    if #potions == 0 then return nil end
    return potions[#potions]  -- last = highest tier (sorted ascending)
end

--- Find the lowest tier potion of a given type in inventory.
--- Returns single potion table or nil.
function item_db.find_lowest_potion(ptype)
    local potions = item_db.find_potion(ptype, 0)
    if #potions == 0 then return nil end
    return potions[1]
end

--- Find a potion of exactly the specified tier, or closest available.
--- Returns single potion table or nil.
function item_db.find_potion_at_tier(ptype, target_tier)
    local potions = item_db.find_potion(ptype, 0)
    if #potions == 0 then return nil end

    -- Exact match first
    for _, p in ipairs(potions) do
        if (p.tier or 0) == target_tier then return p end
    end

    -- Closest tier (prefer higher)
    local best = nil
    local best_diff = 999
    for _, p in ipairs(potions) do
        local diff = math.abs((p.tier or 0) - target_tier)
        if diff < best_diff then
            best = p
            best_diff = diff
        end
    end
    return best
end

--- Use a potion by its uid.
function item_db.use_by_uid(uid)
    if not uid then return "ERR:NO_UID" end
    _inv_cache = nil  -- invalidate cache
    return _cmd("USE_ITEM " .. uid)
end

--- Use the best potion of a given type.
function item_db.use_best_potion(ptype)
    local p = item_db.find_best_potion(ptype)
    if not p then return nil end
    return item_db.use_by_uid(p.uid)
end

--- Use a potion at a specific tier (or closest match).
function item_db.use_potion_at_tier(ptype, tier)
    local p = item_db.find_potion_at_tier(ptype, tier)
    if not p then return nil end
    return item_db.use_by_uid(p.uid)
end

-- ══════════════════════════════════════════════════════════════
-- Auto-Potion Rules — tier-based automatic usage
--
-- Example:
--   item_db.add_potion_rule("health", 8, 0.80, 2.0)  -- Tier 8 at 80% HP
--   item_db.add_potion_rule("health", 3, 0.40, 2.0)  -- Tier 3 at 40% HP
--   item_db.add_potion_rule("mana",   5, 0.30, 3.0)  -- Tier 5 mana at 30% MP
--
-- In your update loop:
--   item_db.tick(hp_pct, mp_pct)
-- ══════════════════════════════════════════════════════════════

--- Add an auto-potion rule.
--- @param ptype string       Potion type: "health", "mana", "stamina", etc.
--- @param tier number         Target tier (closest match used if exact not available)
--- @param threshold number    Use when resource % drops BELOW this (0.0-1.0)
--- @param cooldown number     Min seconds between uses (default 2.0)
function item_db.add_potion_rule(ptype, tier, threshold, cooldown)
    _potion_rules[#_potion_rules + 1] = {
        type = ptype,
        tier = tier,
        threshold = threshold,
        cooldown = cooldown or 2.0,
        last_used = 0,
    }
    -- Sort: lower thresholds first (more urgent rules checked first)
    table.sort(_potion_rules, function(a, b) return a.threshold < b.threshold end)
end

--- Remove all rules for a potion type (or all rules if no type given).
function item_db.clear_potion_rules(ptype)
    if not ptype then
        _potion_rules = {}
        return
    end
    for i = #_potion_rules, 1, -1 do
        if _potion_rules[i].type == ptype then
            table.remove(_potion_rules, i)
        end
    end
end

--- Get current auto-potion rules (for debug/display).
function item_db.get_potion_rules()
    return _potion_rules
end

--- Process auto-potion rules. Call every tick.
--- @param hp_pct number   Current HP as fraction 0.0–1.0
--- @param mp_pct number   Current MP as fraction 0.0–1.0
--- @param stam_pct number Current stamina as fraction (optional)
function item_db.tick(hp_pct, mp_pct, stam_pct)
    if #_potion_rules == 0 then return end

    local now = os.clock()
    local resource = {
        health  = hp_pct or 1.0,
        mana    = mp_pct or 1.0,
        stamina = stam_pct or 1.0,
    }

    for _, rule in ipairs(_potion_rules) do
        local current = resource[rule.type]
        if not current then current = 1.0 end

        if current < rule.threshold and now - rule.last_used >= rule.cooldown then
            local p = item_db.find_potion_at_tier(rule.type, rule.tier)
            if p then
                local result = item_db.use_by_uid(p.uid)
                if result and not result:find("ERR") then
                    rule.last_used = now
                    return  -- one potion per tick to avoid spam
                end
            end
        end
    end
end

-- ══════════════════════════════════════════════════════════════
-- Utility
-- ══════════════════════════════════════════════════════════════

--- Dump item JSON to file (via DLL).
function item_db.dump_to_file()
    return _cmd("DUMP_ALL_ITEMS")
end

--- Get item mods for a specific item UID.
function item_db.get_mods(uid)
    if not uid then return {} end
    return _parse_lines(_cmd("ITEM_MODS " .. uid))
end

--- Invalidate all caches.
function item_db.invalidate()
    _master_cache = nil
    _inv_cache = nil
end

return item_db
