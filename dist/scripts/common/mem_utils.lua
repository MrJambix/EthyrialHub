--[[
mem_utils — Shared memory-read helpers for EthyrialHub Lua scripts.

Provides cached player pointer, condition mask decoding,
direct combat/movement reads, and IL2CPP collection walkers.

Usage:
    local mem = require("common/mem_utils")
    local ptr = mem.player_ptr()
    local cc  = mem.read_conditions()
    if cc.stunned then ... end
]]

local M = {}

-- ═══════════════════════════════════════════════════════════════
--  CACHED PLAYER POINTER
-- ═══════════════════════════════════════════════════════════════

local _ptr_cache  = nil
local _ptr_time   = 0
local PTR_TTL     = 5.0  -- re-fetch every 5s (pointer rarely changes)

function M.player_ptr(force)
    local now = os.clock()
    if not force and _ptr_cache and (now - _ptr_time) < PTR_TTL then
        return _ptr_cache
    end
    local raw = core.send_command("PLAYER_ADDRESS") or ""
    if raw == "" or raw:find("ERR") or raw == "NULL" then
        _ptr_cache = nil
        return nil
    end
    _ptr_cache = raw
    _ptr_time  = now
    return _ptr_cache
end

function M.invalidate_ptr()
    _ptr_cache = nil
end

-- ═══════════════════════════════════════════════════════════════
--  SINGLE FIELD READS
-- ═══════════════════════════════════════════════════════════════

function M.read_field(offset, typ)
    local ptr = M.player_ptr()
    if not ptr then return nil end
    local cmd = string.format("READ_AT %s %s %s", ptr, offset, typ)
    local raw = core.send_command(cmd) or ""
    if raw == "" or raw:find("ERR") or raw == "UNKNOWN_TYPE" or raw == "ACCESS_VIOLATION" then
        return nil
    end
    return raw
end

function M.read_float(offset)
    local v = M.read_field(offset, "float")
    return v and tonumber(v)
end

function M.read_int(offset)
    local v = M.read_field(offset, "int")
    return v and tonumber(v)
end

function M.read_u32(offset)
    local v = M.read_field(offset, "u32")
    return v and tonumber(v)
end

function M.read_bool(offset)
    local v = M.read_field(offset, "bool")
    return v == "true"
end

function M.read_ptr(offset)
    local v = M.read_field(offset, "ptr")
    if not v or v == "NULL" then return nil end
    return v
end

-- ═══════════════════════════════════════════════════════════════
--  COMMON PLAYER FIELDS (direct offsets)
-- ═══════════════════════════════════════════════════════════════

function M.in_combat()
    return M.read_bool("0x344")
end

function M.is_moving()
    return M.read_bool("0x280")
end

function M.is_hidden()
    return M.read_bool("0x158")
end

function M.health_pct()
    return M.read_float("0x21C")
end

function M.mana_pct()
    return M.read_float("0x220")
end

function M.attack_speed()
    return M.read_float("0x324")
end

function M.move_speed()
    return M.read_float("0x2B0")
end

-- ═══════════════════════════════════════════════════════════════
--  CONDITION MASK (0x278) — CC state flags
-- ═══════════════════════════════════════════════════════════════

-- Bit definitions (empirical — observe in Game Inspector to confirm)
M.CONDITION = {
    NONE       = 0x00,
    STUNNED    = 0x01,
    ROOTED     = 0x02,
    SILENCED   = 0x04,
    FROZEN     = 0x08,
    FEARED     = 0x10,
    SLEEPING   = 0x20,
    BLINDED    = 0x40,
    KNOCKED    = 0x80,
}

-- Reverse lookup: bit -> name
M.CONDITION_NAMES = {}
for name, bit in pairs(M.CONDITION) do
    if bit > 0 then M.CONDITION_NAMES[bit] = name end
end

function M.read_condition_mask()
    return M.read_u32("0x278") or 0
end

function M.read_conditions()
    local mask = M.read_condition_mask()
    return {
        mask     = mask,
        stunned  = (mask & M.CONDITION.STUNNED)  ~= 0,
        rooted   = (mask & M.CONDITION.ROOTED)   ~= 0,
        silenced = (mask & M.CONDITION.SILENCED)  ~= 0,
        frozen   = (mask & M.CONDITION.FROZEN)   ~= 0,
        feared   = (mask & M.CONDITION.FEARED)   ~= 0,
        sleeping = (mask & M.CONDITION.SLEEPING) ~= 0,
        blinded  = (mask & M.CONDITION.BLINDED)  ~= 0,
        knocked  = (mask & M.CONDITION.KNOCKED)  ~= 0,
    }
end

function M.decode_mask_string(mask)
    if mask == 0 then return "NONE" end
    local parts = {}
    -- Check known bits
    local sorted_bits = { 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80 }
    for _, bit in ipairs(sorted_bits) do
        if (mask & bit) ~= 0 then
            parts[#parts + 1] = M.CONDITION_NAMES[bit] or string.format("BIT_%02X", bit)
        end
    end
    -- Check for unknown high bits
    local known = 0xFF
    local unknown = mask & ~known
    if unknown ~= 0 then
        parts[#parts + 1] = string.format("UNKNOWN(0x%X)", unknown)
    end
    return table.concat(parts, " | ")
end

function M.can_cast()
    local cc = M.read_conditions()
    return not (cc.stunned or cc.silenced or cc.frozen or cc.sleeping or cc.knocked)
end

function M.can_move()
    local cc = M.read_conditions()
    return not (cc.stunned or cc.rooted or cc.frozen or cc.sleeping or cc.knocked)
end

-- ═══════════════════════════════════════════════════════════════
--  IL2CPP LIST WALKER  (List<T>)
--  Layout: +0x10 = _items (array ptr), +0x18 = _size (int)
--  Array:  +0x18 = length, +0x20 = first element
-- ═══════════════════════════════════════════════════════════════

function M.read_list_count(list_ptr)
    if not list_ptr then return 0 end
    local cmd = string.format("READ_AT %s 0x18 int", list_ptr)
    local raw = core.send_command(cmd) or ""
    local n = tonumber(raw)
    if not n or n < 0 or n > 1000 then return 0 end
    return n
end

function M.read_list_array(list_ptr)
    if not list_ptr then return nil end
    local cmd = string.format("READ_AT %s 0x10 ptr", list_ptr)
    local raw = core.send_command(cmd) or ""
    if raw == "NULL" or raw == "" or raw:find("ERR") then return nil end
    return raw
end

function M.read_list_element(array_ptr, index)
    if not array_ptr then return nil end
    local offset = string.format("0x%X", 0x20 + index * 8)
    local cmd = string.format("READ_AT %s %s ptr", array_ptr, offset)
    local raw = core.send_command(cmd) or ""
    if raw == "NULL" or raw == "" or raw:find("ERR") then return nil end
    return raw
end

function M.walk_list(list_ptr, max_elements)
    max_elements = max_elements or 50
    local count = M.read_list_count(list_ptr)
    if count == 0 then return {}, 0 end
    count = math.min(count, max_elements)

    local arr = M.read_list_array(list_ptr)
    if not arr then return {}, 0 end

    local elements = {}
    for i = 0, count - 1 do
        local elem = M.read_list_element(arr, i)
        if elem then elements[#elements + 1] = elem end
    end
    return elements, count
end

-- ═══════════════════════════════════════════════════════════════
--  IL2CPP DICTIONARY WALKER  (Dictionary<K,V>)
--  Layout: +0x18 = _entries (array ptr), +0x20 = _count (int)
--  Entry array starts at +0x20, each entry is `stride` bytes
--  Entry: +0x00 hashCode(i32), +0x04 next(i32), +0x08 key, +value_offset value
-- ═══════════════════════════════════════════════════════════════

function M.read_dict_count(dict_ptr)
    if not dict_ptr then return 0 end
    local cmd = string.format("READ_AT %s 0x20 int", dict_ptr)
    local raw = core.send_command(cmd) or ""
    local n = tonumber(raw)
    if not n or n < 0 or n > 1000 then return 0 end
    return n
end

function M.read_dict_entries(dict_ptr)
    if not dict_ptr then return nil end
    local cmd = string.format("READ_AT %s 0x18 ptr", dict_ptr)
    local raw = core.send_command(cmd) or ""
    if raw == "NULL" or raw == "" or raw:find("ERR") then return nil end
    return raw
end

--- Walk a dictionary and return entries as {key=..., value=...} tables.
--- @param dict_ptr string      base pointer to the Dictionary object
--- @param stride number         byte size of each Entry struct
--- @param key_off number        offset of key within Entry
--- @param key_type string       READ_AT type for key ("int", "ptr", etc.)
--- @param val_off number        offset of value within Entry
--- @param val_type string       READ_AT type for value ("float", "int", "ptr", etc.)
--- @param max_entries number?   safety cap (default 50)
function M.walk_dict(dict_ptr, stride, key_off, key_type, val_off, val_type, max_entries)
    max_entries = max_entries or 50
    local count = M.read_dict_count(dict_ptr)
    if count == 0 then return {}, 0 end

    local entries_arr = M.read_dict_entries(dict_ptr)
    if not entries_arr then return {}, 0 end

    local results = {}
    local checked = 0
    -- Dictionary entries array: skip IL2CPP array header (0x20), each entry is stride bytes
    -- We scan the capacity (not count) because entries can have gaps (hashCode < 0 = unused)
    -- But to limit IPC calls, we stop after finding `count` valid entries
    for i = 0, math.min(count * 2, 200) - 1 do
        local base_off = 0x20 + i * stride
        -- Read hashCode to check if slot is used (>= 0 means used)
        local hash_cmd = string.format("READ_AT %s 0x%X int", entries_arr, base_off)
        local hash_raw = core.send_command(hash_cmd) or ""
        local hash = tonumber(hash_raw)
        if hash and hash >= 0 then
            -- Read key and value
            local k_cmd = string.format("READ_AT %s 0x%X %s", entries_arr, base_off + key_off, key_type)
            local v_cmd = string.format("READ_AT %s 0x%X %s", entries_arr, base_off + val_off, val_type)
            local k_raw = core.send_command(k_cmd) or ""
            local v_raw = core.send_command(v_cmd) or ""
            results[#results + 1] = { key = k_raw, value = v_raw, hash = hash }
            checked = checked + 1
            if checked >= max_entries then break end
        end
    end
    return results, count
end

-- ═══════════════════════════════════════════════════════════════
--  PROGRESS LIST HELPERS  (Player + 0x258)
--  Quick check: is the player currently in a gather/craft progress?
-- ═══════════════════════════════════════════════════════════════

function M.progress_count()
    local ptr = M.player_ptr()
    if not ptr then return 0 end
    local prog_ptr = M.read_ptr("0x258")
    if not prog_ptr then return 0 end
    return M.read_list_count(prog_ptr)
end

function M.has_progress()
    return M.progress_count() > 0
end

return M
