-- ═══════════════════════════════════════════════════════════════
--  core.debug — Debug / IL2CPP Reflection API
-- ═══════════════════════════════════════════════════════════════

local dbg = {}

function dbg.invoke_method(args) return _cmd("INVOKE_METHOD " .. args) end
function dbg.read_field(args)    return _cmd("READ_FIELD " .. args) end
function dbg.write_field(args)   return _cmd("WRITE_FIELD " .. args) end
function dbg.get_ptr(name)       return _cmd("GET_PTR " .. name) end
function dbg.read_at(args)       return _cmd("READ_AT " .. args) end
function dbg.write_at(args)      return _cmd("WRITE_AT " .. args) end
function dbg.batch_read(args)    return _cmd("BATCH_READ " .. args) end
function dbg.chain_read(args)    return _cmd("CHAIN_READ " .. args) end
function dbg.resolve_class(name) return _cmd("RESOLVE_CLASS " .. name) end
function dbg.dump_class(name)    return _cmd("DUMP_CLASS_FULL " .. name) end

function dbg.dump_fields(cls)
    return _cmd(cls and ("DUMP_FIELDS_" .. cls) or "DUMP_FIELDS")
end

function dbg.dump_methods(cls)
    return _cmd("DUMP_METHODS_" .. cls)
end

function dbg.dump_offsets()      return _cmd("DUMP_OFFSETS") end
function dbg.dump_assemblies()   return _cmd("DUMP_ASSEMBLIES") end
function dbg.dump_singletons()   return _cmd("DUMP_SINGLETONS") end

function dbg.dump_image_classes(asm)
    return _cmd("DUMP_IMAGE_CLASSES " .. asm)
end

function dbg.dump_all_hooks()    return _cmd("DUMP_ALL_HOOKS") end

function dbg.dump_all_hooks_page(page)
    return _cmd("DUMP_ALL_HOOKS_PAGE " .. page)
end

function dbg.cache_all_classes() return _cmd("CACHE_ALL_CLASSES") end

function dbg.cache_size()
    return tonumber(_cmd("CLASS_CACHE_SIZE")) or 0
end

function dbg.list_cached_classes(filter)
    return _cmd(filter and ("LIST_CACHED_CLASSES " .. filter) or "LIST_CACHED_CLASSES")
end

function dbg.offset_dump()       return _cmd("OFFSET_DUMP") end

function dbg.scene_find(name)
    return _cmd("SCENE_FIND_" .. name)
end

function dbg.scene_dump(depth)
    return _cmd(depth and ("SCENE_DUMP_" .. depth) or "SCENE_DUMP")
end

return dbg
