-- ═══════════════════════════════════════════════════════════════
--  core.social — Social API
-- ═══════════════════════════════════════════════════════════════

local social = {}

function social.chat_send(msg)
    return _cmd("CHAT_SEND " .. msg)
end

function social.party_count()
    return tonumber(_cmd("PARTY_COUNT")) or 0
end

function social.party_scan()
    return _cmd("PARTY_SCAN")
end

function social.party_all()
    return _cmd("PARTY_ALL")
end

function social.nearby_players()
    return _cmd("NEARBY_PLAYERS")
end

function social.inbox_new()
    return _cmd("INBOX_NEW")
end

-- ── Parsed helpers ──

function social.get_party()
    return _parse_lines(_cmd("PARTY_ALL"))
end

return social
