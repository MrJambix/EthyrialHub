-- ═══════════════════════════════════════════════════════════════
--  core.network — Network API
-- ═══════════════════════════════════════════════════════════════

local net = {}

function net.server_address()
    return _cmd("DUMP_SERVER_ADDRESS")
end

function net.net_classes()
    return _cmd("DUMP_NET_CLASSES")
end

return net
