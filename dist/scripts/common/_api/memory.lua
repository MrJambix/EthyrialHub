-- ═══════════════════════════════════════════════════════════════
--  core.memory — Memory Read/Write, AOB Scan, Watchpoints
--
--  Low-level memory access helpers for reading game memory
--  directly via IPC. Wraps READ_AT, PATCH_BYTES, SCAN_AOB,
--  WATCH_ADDR, ALLOC_EXEC, and related commands.
--
--  Usage:
--    local mem = core.memory
--    local hp = mem.read_float("0x220")          -- player field
--    local addr = mem.scan_aob("GameAssembly", "48 89 5C 24 ??")
-- ═══════════════════════════════════════════════════════════════

local mem = {}

-- ── Cached player pointer ───────────────────────────────────

local _ptr_cache = nil
local _ptr_time  = 0
local PTR_TTL    = 5.0

function mem.player_ptr(force)
    local now = os.clock()
    if not force and _ptr_cache and (now - _ptr_time) < PTR_TTL then
        return _ptr_cache
    end
    local raw = _cmd("PLAYER_ADDRESS") or ""
    if raw == "" or raw:find("ERR") or raw == "NULL" then
        _ptr_cache = nil
        return nil
    end
    _ptr_cache = raw
    _ptr_time  = now
    return _ptr_cache
end

function mem.invalidate_ptr()
    _ptr_cache = nil
end

-- ── Single field reads (relative to player pointer) ─────────

function mem.read_field(offset, typ)
    local ptr = mem.player_ptr()
    if not ptr then return nil end
    local raw = _cmd(string.format("READ_AT %s %s %s", ptr, offset, typ)) or ""
    if raw == "" or raw:find("ERR") or raw == "UNKNOWN_TYPE" or raw == "ACCESS_VIOLATION" then
        return nil
    end
    return raw
end

function mem.read_float(offset)
    local v = mem.read_field(offset, "float")
    return v and tonumber(v)
end

function mem.read_int(offset)
    local v = mem.read_field(offset, "int")
    return v and tonumber(v)
end

function mem.read_u32(offset)
    local v = mem.read_field(offset, "u32")
    return v and tonumber(v)
end

function mem.read_bool(offset)
    local v = mem.read_field(offset, "bool")
    return v == "true"
end

function mem.read_ptr(offset)
    local v = mem.read_field(offset, "ptr")
    if not v or v == "NULL" then return nil end
    return v
end

-- ── Absolute address reads ──────────────────────────────────

function mem.read_bytes(addr, count)
    return _cmd(string.format("READ_BYTES %s %d", addr, count))
end

function mem.dump_modules()
    return _cmd("DUMP_MODULES")
end

-- ── Write / Patch ───────────────────────────────────────────

function mem.patch_bytes(addr, hex_bytes)
    return _cmd("PATCH_BYTES " .. addr .. " " .. hex_bytes)
end

function mem.nop(addr, count)
    return _cmd(string.format("NOP_BYTES %s %d", addr, count))
end

function mem.restore(addr, original_hex)
    return _cmd("RESTORE_BYTES " .. addr .. " " .. original_hex)
end

-- ── AOB / Pattern scan ──────────────────────────────────────

function mem.scan_aob(module_name, pattern)
    return _cmd("SCAN_AOB " .. module_name .. " " .. pattern)
end

-- ── Hardware watchpoints ────────────────────────────────────

function mem.watch(addr, mode)
    mode = mode or "access"
    return _cmd("WATCH_ADDR " .. addr .. " " .. mode)
end

function mem.watch_clear(dr_index)
    return _cmd("WATCH_CLEAR " .. tostring(dr_index))
end

function mem.watch_clear_all()
    return _cmd("WATCH_CLEAR_ALL")
end

function mem.watch_status()
    return _cmd("WATCH_STATUS")
end

function mem.watch_hits()
    return _cmd("WATCH_HITS")
end

-- ── Executable memory ───────────────────────────────────────

function mem.alloc_exec(size)
    return _cmd("ALLOC_EXEC " .. tostring(size))
end

function mem.free_exec(addr, size)
    return _cmd(string.format("FREE_EXEC %s %d", addr, size))
end

function mem.write_exec(addr, hex_bytes)
    return _cmd("WRITE_EXEC " .. addr .. " " .. hex_bytes)
end

-- ── IL2CPP List<T> walker ───────────────────────────────────
-- Layout: +0x10 = _items (array ptr), +0x18 = _size (int)
-- Array:  +0x18 = length, +0x20 = first element

function mem.read_list_count(list_ptr)
    if not list_ptr then return 0 end
    local raw = _cmd(string.format("READ_AT %s 0x18 int", list_ptr)) or ""
    local n = tonumber(raw)
    if not n or n < 0 or n > 1000 then return 0 end
    return n
end

function mem.read_list_array(list_ptr)
    if not list_ptr then return nil end
    local raw = _cmd(string.format("READ_AT %s 0x10 ptr", list_ptr)) or ""
    if raw == "NULL" or raw == "" or raw:find("ERR") then return nil end
    return raw
end

function mem.read_list_element(array_ptr, index)
    if not array_ptr then return nil end
    local offset = string.format("0x%X", 0x20 + index * 8)
    local raw = _cmd(string.format("READ_AT %s %s ptr", array_ptr, offset)) or ""
    if raw == "NULL" or raw == "" or raw:find("ERR") then return nil end
    return raw
end

function mem.walk_list(list_ptr, max_elements)
    max_elements = max_elements or 50
    local count = mem.read_list_count(list_ptr)
    if count == 0 then return {}, 0 end
    count = math.min(count, max_elements)
    local arr = mem.read_list_array(list_ptr)
    if not arr then return {}, 0 end
    local elements = {}
    for i = 0, count - 1 do
        local elem = mem.read_list_element(arr, i)
        if elem then elements[#elements + 1] = elem end
    end
    return elements, count
end

-- ── IL2CPP Dictionary<K,V> walker ───────────────────────────
-- Layout: +0x18 = _entries (array ptr), +0x20 = _count (int)

function mem.read_dict_count(dict_ptr)
    if not dict_ptr then return 0 end
    local raw = _cmd(string.format("READ_AT %s 0x20 int", dict_ptr)) or ""
    local n = tonumber(raw)
    if not n or n < 0 or n > 1000 then return 0 end
    return n
end

function mem.read_dict_entries(dict_ptr)
    if not dict_ptr then return nil end
    local raw = _cmd(string.format("READ_AT %s 0x18 ptr", dict_ptr)) or ""
    if raw == "NULL" or raw == "" or raw:find("ERR") then return nil end
    return raw
end

function mem.walk_dict(dict_ptr, stride, key_off, key_type, val_off, val_type, max_entries)
    max_entries = max_entries or 50
    local count = mem.read_dict_count(dict_ptr)
    if count == 0 then return {}, 0 end
    local entries_arr = mem.read_dict_entries(dict_ptr)
    if not entries_arr then return {}, 0 end
    local results = {}
    local checked = 0
    for i = 0, math.min(count * 2, 200) - 1 do
        local base_off = 0x20 + i * stride
        local hash_raw = _cmd(string.format("READ_AT %s 0x%X int", entries_arr, base_off)) or ""
        local hash = tonumber(hash_raw)
        if hash and hash >= 0 then
            local k_raw = _cmd(string.format("READ_AT %s 0x%X %s", entries_arr, base_off + key_off, key_type)) or ""
            local v_raw = _cmd(string.format("READ_AT %s 0x%X %s", entries_arr, base_off + val_off, val_type)) or ""
            results[#results + 1] = { key = k_raw, value = v_raw, hash = hash }
            checked = checked + 1
            if checked >= max_entries then break end
        end
    end
    return results, count
end

-- ── Condition mask (LivingEntity) ───────────────────────────

mem.CONDITION = {
    NONE     = 0x00,
    STUNNED  = 0x01,
    ROOTED   = 0x02,
    SILENCED = 0x04,
    FROZEN   = 0x08,
    FEARED   = 0x10,
    SLEEPING = 0x20,
    BLINDED  = 0x40,
    KNOCKED  = 0x80,
}

mem.CONDITION_NAMES = {}
for name, bit in pairs(mem.CONDITION) do
    if bit > 0 then mem.CONDITION_NAMES[bit] = name end
end

function mem.read_condition_mask()
    return mem.read_u32("0x278") or 0
end

function mem.read_conditions()
    local mask = mem.read_condition_mask()
    return {
        mask     = mask,
        stunned  = (mask & mem.CONDITION.STUNNED)  ~= 0,
        rooted   = (mask & mem.CONDITION.ROOTED)   ~= 0,
        silenced = (mask & mem.CONDITION.SILENCED)  ~= 0,
        frozen   = (mask & mem.CONDITION.FROZEN)   ~= 0,
        feared   = (mask & mem.CONDITION.FEARED)   ~= 0,
        sleeping = (mask & mem.CONDITION.SLEEPING) ~= 0,
        blinded  = (mask & mem.CONDITION.BLINDED)  ~= 0,
        knocked  = (mask & mem.CONDITION.KNOCKED)  ~= 0,
    }
end

function mem.decode_mask_string(mask)
    if mask == 0 then return "NONE" end
    local parts = {}
    for _, bit in ipairs({0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80}) do
        if (mask & bit) ~= 0 then
            parts[#parts + 1] = mem.CONDITION_NAMES[bit] or string.format("BIT_%02X", bit)
        end
    end
    local unknown = mask & ~0xFF
    if unknown ~= 0 then
        parts[#parts + 1] = string.format("UNKNOWN(0x%X)", unknown)
    end
    return table.concat(parts, " | ")
end

function mem.can_cast()
    local cc = mem.read_conditions()
    return not (cc.stunned or cc.silenced or cc.frozen or cc.sleeping or cc.knocked)
end

function mem.can_move()
    local cc = mem.read_conditions()
    return not (cc.stunned or cc.rooted or cc.frozen or cc.sleeping or cc.knocked)
end

-- ── Progress list (Player + 0x258) ──────────────────────────

function mem.progress_count()
    local ptr = mem.player_ptr()
    if not ptr then return 0 end
    local prog_ptr = mem.read_ptr("0x258")
    if not prog_ptr then return 0 end
    return mem.read_list_count(prog_ptr)
end

function mem.has_progress()
    return mem.progress_count() > 0
end

-- ── Module PE queries ───────────────────────────────────────

function mem.module_base(module_name)
    return _cmd("MODULE_BASE " .. module_name)
end

function mem.module_section(module_name, section_name)
    return _cmd("MODULE_SECTION " .. module_name .. " " .. section_name)
end

return mem
