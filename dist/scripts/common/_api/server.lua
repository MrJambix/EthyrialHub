-- ═══════════════════════════════════════════════════════════════
--  core.server — Server, network, and protocol queries
--
--  Usage:
--    local info = core.server.info()
--    local lat  = core.server.latency()
-- ═══════════════════════════════════════════════════════════════

local M = {}

-- ─── Server info ────────────────────────────────────────────

function M.info()
    local raw = core.send_command("SERVER_INFO")
    if not raw or raw:sub(1, 3) == "ERR" then return nil end
    local t = {}
    for kv in raw:gmatch("[^|]+") do
        local k, v = kv:match("^(.-)=(.+)$")
        if k then
            local num = tonumber(v)
            if num then t[k] = num else t[k] = v end
        end
    end
    return t
end

function M.ip()
    return core.send_command("SERVER_IP")
end

function M.port()
    local r = core.send_command("SERVER_PORT")
    return tonumber(r) or 0
end

function M.latency()
    local r = core.send_command("SERVER_LATENCY")
    return tonumber(r) or 0
end

function M.rtt()
    local r = core.send_command("SERVER_RTT")
    return tonumber(r) or 0
end

function M.status()
    return core.send_command("SERVER_STATUS")
end

function M.stats()
    local raw = core.send_command("SERVER_STATS")
    if not raw or raw:sub(1, 3) == "ERR" then return nil end
    local t = {}
    for kv in raw:gmatch("[^|]+") do
        local k, v = kv:match("^(.-)=(.+)$")
        if k then
            local num = tonumber(v)
            if num then t[k] = num else t[k] = v end
        end
    end
    return t
end

function M.net_peer_status()
    return core.send_command("NET_PEER_STATUS")
end

function M.player_uid()
    local r = core.send_command("PLAYER_UID")
    return tonumber(r) or 0
end

function M.account_id()
    return core.send_command("ACCOUNT_ID")
end

function M.scene_name()
    return core.send_command("SCENE_NAME")
end

-- ─── Weight Lock ────────────────────────────────────────────

function M.weight_lock(max_weight)
    if max_weight then
        return core.send_command(string.format("WEIGHT_LOCK %.0f", max_weight))
    end
    return core.send_command("WEIGHT_LOCK")
end

function M.weight_unlock()
    return core.send_command("WEIGHT_UNLOCK")
end

function M.weight_status()
    return core.send_command("WEIGHT_STATUS")
end

-- ─── Dumps ──────────────────────────────────────────────────

function M.dump_state()
    return core.send_command("DUMP_SERVER_STATE")
end

function M.dump_protocol()
    return core.send_command("DUMP_PROTOCOL")
end

function M.dump_net_classes()
    return core.send_command("DUMP_NET_CLASSES")
end

-- ─── Protocol enum lookups ──────────────────────────────────

M.protocol = {}

function M.protocol.msg_type(id)
    return core.send_command("MSG_TYPE " .. tostring(id))
end

function M.protocol.msg_type_name(name)
    return core.send_command("MSG_TYPE_NAME " .. name)
end

function M.protocol.msg_type_all()
    return core.send_command("MSG_TYPE_ALL")
end

function M.protocol.admin_msg_type(id)
    return core.send_command("ADMIN_MSG_TYPE " .. tostring(id))
end

function M.protocol.admin_msg_type_all()
    return core.send_command("ADMIN_MSG_TYPE_ALL")
end

function M.protocol.editor_msg_type(id)
    return core.send_command("EDITOR_MSG_TYPE " .. tostring(id))
end

function M.protocol.editor_msg_type_all()
    return core.send_command("EDITOR_MSG_TYPE_ALL")
end

return M
