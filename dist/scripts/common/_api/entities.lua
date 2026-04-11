-- ═══════════════════════════════════════════════════════════════
--  core.entities — Entity Scan API
-- ═══════════════════════════════════════════════════════════════

local ent = {}

function ent.nearby_all()
    return _cmd("NEARBY_ALL")
end

function ent.nearby_living()
    return _cmd("NEARBY_LIVING")
end

function ent.scene_all()
    return _cmd("SCENE_ALL")
end

function ent.scene_scan(filter)
    return _cmd(filter and ("SCENE_SCAN_ENTITIES_" .. filter) or "SCENE_SCAN_ENTITIES")
end

function ent.entity_under_mouse()
    return _cmd("ENTITY_UNDER_MOUSE")
end

function ent.debug_find(search)
    return _cmd("DEBUG_FIND_" .. search)
end

function ent.buff_stacks(name)
    return _cmd("BUFF_STACKS " .. name)
end

function ent.use_by_ptr(ptr)
    return _cmd("USE_PTR_" .. _ptr_hex(ptr))
end

function ent.target_by_ptr(ptr)
    return _cmd("TARGET_PTR_" .. _ptr_hex(ptr))
end

return ent
