-- ═══════════════════════════════════════════════════════════════
--  core.rotation — Rotation / Class ID Dump API
-- ═══════════════════════════════════════════════════════════════

local rot = {}

function rot.dump_spells()
    return _cmd("DUMP_ROTATION")
end

function rot.dump_class_ids()
    return _cmd("DUMP_CLASS_IDS")
end

function rot.get_class_id()
    local raw = _cmd("DUMP_CLASS_IDS")
    if not raw then return -1, "Unknown" end
    local id   = raw:match("job_id=([-%d]+)")
    local name = raw:match("job_string=(%S+)")
    return tonumber(id) or -1, name or "Unknown"
end

function rot.get_all_spell_data()
    local raw = _cmd("DUMP_ROTATION")
    if not raw or raw == "NONE" then return {} end
    local spells = {}
    for entry in raw:gmatch("[^#]+") do
        if entry ~= "" then
            local sp = {}
            for k, v in entry:gmatch("([%w_]+)=([^|]+)") do
                local n = tonumber(v)
                if n then sp[k] = n else sp[k] = v end
            end
            if sp.name then spells[#spells + 1] = sp end
        end
    end
    return spells
end

return rot
