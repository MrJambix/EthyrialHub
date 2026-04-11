-- ═══════════════════════════════════════════════════════════════
--  core.buff_manager — Buff Manager API
-- ═══════════════════════════════════════════════════════════════

local bm = {}

function bm.has_buff(name)
    local r = _cmd("PLAYER_BUFFS")
    if not r or r == "" or r == "NONE" then return false end
    return r:find("name=" .. name) ~= nil
end

function bm.get_stacks(name)
    local r = _cmd("BUFF_STACKS " .. name)
    return tonumber(r) or 0
end

function bm.get_all_buffs()
    return _parse_lines(_cmd("PLAYER_BUFFS"))
end

function bm.get_buff_data(name)
    local buffs = _parse_lines(_cmd("PLAYER_BUFFS"))
    for _, b in ipairs(buffs) do
        if b.name == name or b.disp == name then
            return { is_active = true, remaining = tonumber(b.dur) or 0, stacks = tonumber(b.stacks) or 0 }
        end
    end
    return { is_active = false, remaining = 0, stacks = 0 }
end

function bm.get_fury_stacks()
    return bm.get_stacks("Fury")
end

function bm.get_spirit_link_stacks()
    return bm.get_stacks("SpiritLink")
end

function bm.invalidate() end
function bm.update() end

return bm
