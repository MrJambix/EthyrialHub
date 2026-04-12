-- ═══════════════════════════════════════════════════════════════
--  core.reflect — IL2CPP reflection queries
--
--  Usage:
--    local addr = core.reflect.method_addr("LivingEntity", "TakeDamage", 2)
--    local off  = core.reflect.field_offset("Entity", "Position")
-- ═══════════════════════════════════════════════════════════════

local M = {}

function M.method_addr(class_name, method_name, arg_count)
    arg_count = arg_count or 0
    return core.send_command(string.format("METHOD_ADDR %s %s %d", class_name, method_name, arg_count))
end

function M.method_list(class_name)
    return core.send_command("METHOD_LIST " .. class_name)
end

function M.field_offset(class_name, field_name)
    return core.send_command("FIELD_OFFSET " .. class_name .. " " .. field_name)
end

function M.field_list(class_name)
    return core.send_command("FIELD_LIST " .. class_name)
end

return M
