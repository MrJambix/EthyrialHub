-- ═══════════════════════════════════════════════════════════════
--  core.guild — Guild Data API
-- ═══════════════════════════════════════════════════════════════

local guild = {}

function guild.info()
    return _cmd("GUILD_INFO")
end

function guild.get_info()
    return _parse_single(_cmd("GUILD_INFO"))
end

function guild.members()
    return _cmd("GUILD_MEMBERS")
end

function guild.get_members()
    return _parse_lines(_cmd("GUILD_MEMBERS"))
end

function guild.member_count()
    local info = guild.get_info()
    return info and tonumber(info.members) or 0
end

function guild.name()
    local info = guild.get_info()
    return info and info.name or ""
end

function guild.level()
    local info = guild.get_info()
    return info and tonumber(info.level) or 0
end

return guild
