-- ═══════════════════════════════════════════════════════════════
--  core.spell_book — Spell Book API
-- ═══════════════════════════════════════════════════════════════

local sb = {}

function sb.is_spell_ready(name)
    return _cmd("SPELL_READY " .. name) == "1"
end

function sb.cast_spell(name)
    return _cmd("CAST_" .. name):find("OK") ~= nil
end

function sb.cast_spell_ooc(name)
    return _cmd("CAST_" .. name):find("OK") ~= nil
end

function sb.get_cooldown(name)
    return N(_cmd("SPELL_CD " .. name))
end

function sb.get_spell_info(name)
    return _cmd("SPELL_INFO " .. name)
end

function sb.get_spell_count()
    return tonumber(_cmd("SPELL_COUNT")) or 0
end

function sb.get_all_spells()
    return _cmd("SPELLS_ALL")
end

function sb.dump_all_spells()
    local raw = _cmd("DUMP_SPELLS_FULL")
    if not raw or raw == "" or raw == "NONE" then return {} end
    local results = {}
    for entry in raw:gmatch("[^#]+") do
        if entry:find("=") then
            local s = _parse_kv(entry)
            if s and s.name then
                results[#results + 1] = s
            end
        end
    end
    return results
end

function sb.dump_game_flags()
    local raw = _cmd("DUMP_GAME_FLAGS")
    if not raw or raw == "" then return raw end
    return raw
end

--- Scan ALL entities in the scene and collect every unique spell.
--- Returns a table of spell entries with entity_uid/entity_name fields.
function sb.scan_all_entity_spells()
    local raw = _cmd("SCAN_ALL_ENTITY_SPELLS")
    if not raw or raw == "" or raw == "NONE" then return {}, 0, 0 end
    local results = {}
    local total_spells = 0
    local total_entities = 0
    for entry in raw:gmatch("[^#]+") do
        if entry:find("=") then
            local s = _parse_kv(entry)
            if s then
                -- First entry is the summary header
                if s.total_spells and not s.name then
                    total_spells = tonumber(s.total_spells) or 0
                    total_entities = tonumber(s.total_entities) or 0
                elseif s.name then
                    results[#results + 1] = s
                end
            end
        end
    end
    return results, total_spells, total_entities
end

--- Dump animation list for player or target entity model.
--- Returns a parsed table with impl_anims, impl_states, etc.
function sb.dump_anim_list(who)
    who = who or "player"
    local raw = _cmd("DUMP_ANIM_LIST " .. who)
    if not raw or raw == "" or raw:find("ERR:") then return nil, raw end
    return _parse_kv(raw)
end

function sb.update() end

return sb
