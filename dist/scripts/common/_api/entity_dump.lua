-- ═══════════════════════════════════════════════════════════════
--  core.entity_dump — Cumulative entity dump to JSON files
--  Outputs: mobs_dump.json, npcs_dump.json, nodes_dump.json,
--           quests_dump.json
--
--  The dump is CUMULATIVE — each call merges newly-visible
--  entities into a persistent cache keyed by spawn point.
--  Walk around and call dump_all() repeatedly to build a
--  complete world database.  Call reset() to start fresh.
-- ═══════════════════════════════════════════════════════════════

local entity_dump = {}

--- Dump all visible entities and merge into the cumulative cache.
--- @return table {ok, mobs, npcs, nodes, quests, new_mobs, new_npcs, new_nodes, accum_mobs, accum_npcs, accum_nodes, errors, total, ...files, raw}
function entity_dump.dump_all()
    local raw = _cmd("DUMP_ALL_ENTITIES")
    if not raw or raw == "" then
        return { ok = false, raw = "NO_RESPONSE" }
    end

    if raw:sub(1, 3) == "OK|" then
        local kv = _parse_kv(raw:sub(4))
        return {
            ok          = true,
            mobs        = tonumber(kv.mobs)       or 0,
            npcs        = tonumber(kv.npcs)       or 0,
            nodes       = tonumber(kv.nodes)      or 0,
            quests      = tonumber(kv.quests)     or 0,
            errors      = tonumber(kv.errors)     or 0,
            total       = tonumber(kv.total)      or 0,
            new_mobs    = tonumber(kv.new_mobs)   or 0,
            new_npcs    = tonumber(kv.new_npcs)   or 0,
            new_nodes   = tonumber(kv.new_nodes)  or 0,
            accum_mobs  = tonumber(kv.accum_mobs) or 0,
            accum_npcs  = tonumber(kv.accum_npcs) or 0,
            accum_nodes = tonumber(kv.accum_nodes)or 0,
            mobs_file   = kv.mobs_file   or "?",
            npcs_file   = kv.npcs_file   or "?",
            nodes_file  = kv.nodes_file  or "?",
            quests_file = kv.quests_file or "?",
            raw         = raw,
        }
    end

    return { ok = false, raw = raw }
end

--- Clear the cumulative entity cache so the next dump starts fresh.
function entity_dump.reset()
    local raw = _cmd("DUMP_RESET")
    return raw == "OK|RESET"
end

return entity_dump
