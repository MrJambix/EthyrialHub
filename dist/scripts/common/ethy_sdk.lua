--[[
╔══════════════════════════════════════════════════════════════╗
║              EthySDK — Backward-Compatibility Shim           ║
║                                                              ║
║  All real functionality has moved to core.* API modules:     ║
║    core.humanize, core.loot_roll_api, core.teleport,         ║
║    core.server, core.reflect, core.memory, core.pathfinder   ║
║                                                              ║
║  This file re-exports them under the legacy ethy.* namespace ║
║  so existing scripts continue working.                       ║
╚══════════════════════════════════════════════════════════════╝
]]

---@type ethy_sdk_api
local ethy = {}

-- Re-export enums and Vec3 for convenience
ethy.enums = enums
ethy.Vec3  = require("common/_api/vec3")

-- ══════════════════════════════════════════════════════════════
-- Framework Modules (re-exported from existing _api modules)
-- ══════════════════════════════════════════════════════════════

ethy.events      = require("common/_api/event_bus")
ethy.scheduler   = require("common/_api/scheduler")
ethy.fsm         = require("common/_api/state_machine")
ethy.waypoints   = require("common/_api/waypoints")
ethy.buffs       = require("common/_api/buff_tracker")
ethy.items       = require("common/_api/item_rules")
ethy.combat_stats = require("common/_api/combat_stats")
ethy.signals     = require("common/_api/signals")
ethy.spell_queue = require("common/_api/spell_queue")
ethy.zone        = require("common/_api/zone")

-- ══════════════════════════════════════════════════════════════
-- New API modules → legacy ethy.* namespaces
-- ══════════════════════════════════════════════════════════════

ethy.human      = core.humanize     or require("common/_api/humanize")
ethy.loot_roll  = core.loot_roll_api or require("common/_api/loot_roll")
ethy.server     = core.server       or require("common/_api/server")
ethy.reflect    = core.reflect      or require("common/_api/reflect")
ethy.memory     = core.memory       or require("common/_api/memory")
ethy.modules    = ethy.memory       -- ethy.modules.base/section/dump live in memory module
ethy.pathfinder = core.pathfinder   or require("common/_api/pathfinder")

-- Teleport is flat on ethy.*, not ethy.teleport.*
local _tp       = core.teleport     or require("common/_api/teleport")

-- ══════════════════════════════════════════════════════════════
-- Logging — thin wrappers over core.log
-- ══════════════════════════════════════════════════════════════

function ethy.print(...)
    local args = {...}
    local parts = {}
    for _, v in ipairs(args) do parts[#parts + 1] = tostring(v) end
    core.log(table.concat(parts, " "))
end

function ethy.printf(fmt, ...)
    core.log(string.format(fmt, ...))
end

function ethy.log(filename, ...)
    local args = {...}
    local parts = {}
    for _, v in ipairs(args) do parts[#parts + 1] = tostring(v) end
    core.log("[" .. filename .. "] " .. table.concat(parts, " "))
end

function ethy.logf(filename, fmt, ...)
    core.log("[" .. filename .. "] " .. string.format(fmt, ...))
end

function ethy.log_warning(msg) core.log_warning(msg) end
function ethy.log_error(msg)   core.log_error(msg)   end

-- ══════════════════════════════════════════════════════════════
-- Time
-- ══════════════════════════════════════════════════════════════

function ethy.now()              return core.time()    end
function ethy.now_ms()           return core.time_ms() end
function ethy.time_since(t)      return core.time() - t end
function ethy.time_since_ms(t)   return core.time_ms() - t end
function ethy.time_until(future) local r = future - core.time(); return r > 0 and r or 0 end

local _scheduled = {}
function ethy.after(delay, cb)
    _scheduled[#_scheduled + 1] = { fire_at = core.time() + delay, fn = cb }
end
function ethy._process_scheduled()
    local now, remaining = core.time(), {}
    for _, e in ipairs(_scheduled) do
        if now >= e.fire_at then e.fn() else remaining[#remaining + 1] = e end
    end
    _scheduled = remaining
end

-- ══════════════════════════════════════════════════════════════
-- Player / Target helpers
-- ══════════════════════════════════════════════════════════════

function ethy.get_player() return core.object_manager.get_local_player() end
function ethy.me()         return ethy.get_player() end
function ethy.target()
    local p = ethy.get_player()
    return p and p:has_target() and p:get_target_info() or nil
end

-- ══════════════════════════════════════════════════════════════
-- Buff / Spell helpers (direct delegation)
-- ══════════════════════════════════════════════════════════════

ethy.buff_manager = {
    get_buff_data = function(n) return core.buff_manager.get_buff_data(n) end,
    has_buff      = function(n) return core.buff_manager.has_buff(n) end,
    get_stacks    = function(n) return core.buff_manager.get_stacks(n) end,
    get_all_buffs = function()  return core.buff_manager.get_all_buffs() end,
}

ethy.spell_book = {
    is_ready     = function(n) return core.spell_book.is_spell_ready(n) end,
    cast         = function(n) return core.spell_book.cast_spell(n) end,
    get_cooldown = function(n) return core.spell_book.get_cooldown(n) end,
    get_all      = function()  return core.spell_book.get_all_spells() end,
    dump_all     = function()  return core.spells.dump_all() end,
}

-- ══════════════════════════════════════════════════════════════
-- Callback registration shortcuts
-- ══════════════════════════════════════════════════════════════

function ethy.on_update(fn)
    core.register_on_update_callback(function()
        ethy._process_scheduled()
        fn()
    end)
end
function ethy.on_render(fn)          core.register_on_render_callback(fn)          end
function ethy.on_render_menu(fn)     core.register_on_render_menu_callback(fn)     end
function ethy.on_spell_cast(fn)      core.register_on_spell_cast_callback(fn)      end
function ethy.on_combat_enter(fn)    core.register_on_combat_enter_callback(fn)    end
function ethy.on_combat_leave(fn)    core.register_on_combat_leave_callback(fn)    end
function ethy.on_buff_applied(fn)    core.register_on_buff_applied_callback(fn)    end
function ethy.on_buff_removed(fn)    core.register_on_buff_removed_callback(fn)    end
function ethy.on_target_changed(fn)  core.register_on_target_changed_callback(fn)  end

-- ══════════════════════════════════════════════════════════════
-- Menu helpers
-- ══════════════════════════════════════════════════════════════

ethy.menu = {
    checkbox     = function(id,l,d)       return core.menu.checkbox(id,l,d or false) end,
    slider_int   = function(id,l,d,mn,mx) return core.menu.slider_int(id,l,d or 0,mn or 0,mx or 100) end,
    slider_float = function(id,l,d,mn,mx) return core.menu.slider_float(id,l,d or 0.0,mn or 0.0,mx or 1.0) end,
    combobox     = function(id,l,o,di)    return core.menu.combobox(id,l,o,di or 0) end,
    tree_node    = function(id,l)         return core.menu.tree_node(id,l) end,
    button       = function(id,l)         return core.menu.button(id,l) end,
}

-- ══════════════════════════════════════════════════════════════
-- Teleport — flat on ethy namespace (legacy)
-- ══════════════════════════════════════════════════════════════

function ethy.teleport(x,y,z)         return _tp.to(x,y,z)      end
function ethy.snap_to(x,y,z)          return _tp.snap_to(x,y,z)  end
function ethy.teleport_hold(x,y,z)    return _tp.hold(x,y,z)     end
function ethy.teleport_release()      return _tp.release()        end
function ethy.teleport_status()       return _tp.status()         end
function ethy.teleport_lock(x,y,z)    return _tp.lock(x,y,z)     end
function ethy.teleport_debug()        return _tp.debug()          end

-- ══════════════════════════════════════════════════════════════
-- Weight Lock (delegated to core.server)
-- ══════════════════════════════════════════════════════════════

function ethy.weight_lock(mw)   return ethy.server.weight_lock(mw) end
function ethy.weight_unlock()   return ethy.server.weight_unlock()  end
function ethy.weight_status()   return ethy.server.weight_status()  end

-- ══════════════════════════════════════════════════════════════
-- Protocol / Network (legacy flat helpers)
-- ══════════════════════════════════════════════════════════════

ethy.protocol = ethy.server.protocol
function ethy.dump_server_state() return ethy.server.dump_state()      end
function ethy.dump_protocol()     return ethy.server.dump_protocol()   end
function ethy.dump_net_classes()  return ethy.server.dump_net_classes() end
function ethy.scene_name()        return ethy.server.scene_name()      end

-- ══════════════════════════════════════════════════════════════
-- Player State (comprehensive)
-- ══════════════════════════════════════════════════════════════

function ethy.player_state()
    local raw = core.send_command("PLAYER_STATE")
    if not raw or raw == "NO_RESPONSE" then return nil end
    local state = {}
    for kv in raw:gmatch("[^|]+") do
        local k, v = kv:match("^(.-)=(.+)$")
        if k then
            local num = tonumber(v)
            if num then state[k] = num
            elseif v == "true" then state[k] = true
            elseif v == "false" then state[k] = false
            else state[k] = v end
        end
    end
    return state
end

-- ══════════════════════════════════════════════════════════════
-- Convenience: async / wait (delegates to scheduler)
-- ══════════════════════════════════════════════════════════════

function ethy.async(fn, name) return ethy.scheduler.async(fn, name) end
function ethy.wait(seconds)   return ethy.scheduler.wait(seconds)   end
function ethy.wait_until(fn, timeout) return ethy.scheduler.wait_until(fn, timeout) end

-- ══════════════════════════════════════════════════════════════
-- Quick state queries
-- ══════════════════════════════════════════════════════════════

function ethy.hp()         return conn and conn.get_hp and conn.get_hp() or 100 end
function ethy.mp()         return conn and conn.get_mp and conn.get_mp() or 100 end
function ethy.in_combat()  return conn and conn.in_combat and conn.in_combat() or false end
function ethy.is_dead()    return conn and conn.is_dead and conn.is_dead() or false end
function ethy.has_target() return conn and conn.has_target and conn.has_target() or false end
function ethy.is_moving()  return conn and conn.is_moving and conn.is_moving() or false end

-- ══════════════════════════════════════════════════════════════
-- Unified Tick — drives all framework subsystems
-- ══════════════════════════════════════════════════════════════

function ethy.tick()
    local state = {
        hp = ethy.hp(), mp = ethy.mp(),
        in_combat = ethy.in_combat(), is_dead = ethy.is_dead(),
        has_target = ethy.has_target(), is_moving = ethy.is_moving(),
        target_uid = 0, target_name = nil, target_dead = false,
        buffs = ethy.buffs.active_set(),
    }
    if state.has_target and conn then
        if conn.get_target_uid then state.target_uid = conn.get_target_uid() or 0 end
        if conn.get_target_name then
            local n = conn.get_target_name()
            if n and n ~= "" and n ~= "NO_TARGET" then state.target_name = n end
        end
        if conn.is_target_dead then state.target_dead = conn.is_target_dead() end
    end
    ethy.events.tick(state)
    ethy.scheduler.tick()
    ethy.waypoints.tick()
    ethy.items.tick()
    ethy.zone.tick()
    ethy._process_scheduled()
    if ethy.combat_stats.elapsed() > 0 then
        local thp = nil
        if state.has_target and conn and conn.get_target_hp then thp = conn.get_target_hp() end
        ethy.combat_stats.tick(state.in_combat, thp)
    end
end

-- ══════════════════════════════════════════════════════════════
-- State Machine helper
-- ══════════════════════════════════════════════════════════════

function ethy.state_machine(states, initial, name)
    return ethy.fsm.new(states, initial, name)
end

-- ══════════════════════════════════════════════════════════════
-- Terrain & Walkability (delegates to core.terrain)
-- ══════════════════════════════════════════════════════════════

ethy.terrain = {}

function ethy.terrain.dump(cx, cy, floor, radius)
    floor = floor or 0; radius = radius or 5
    local raw = core.terrain and core.terrain.dump
        and core.terrain.dump(cx, cy, floor, radius)
        or core.send_command(string.format("TERRAIN_DUMP %d %d %d %d", cx, cy, floor, radius))
    if not raw or raw:sub(1, 3) == "ERR" then return nil end
    return raw
end

function ethy.terrain.walkability(cx, cy, floor, radius)
    floor = floor or 0; radius = radius or 5
    local raw = core.terrain and core.terrain.walkability
        and core.terrain.walkability(cx, cy, floor, radius)
        or core.send_command(string.format("WALKABILITY_GRID %d %d %d %d", cx, cy, floor, radius))
    if not raw or raw:sub(1, 3) == "ERR" then return nil end
    return raw
end

function ethy.terrain.parse_walkability(raw)
    local grid, blockers = {}, {}
    if not raw then return grid, blockers end
    for line in raw:gmatch("[^\n]+") do
        local ry, bits = line:match("^ROW|(%d+)|(%d+)$")
        if not ry then ry, bits = line:match("^ROW|%-?(%d+)|([01]+)$") end
        if ry and bits then
            local y = tonumber(ry)
            grid[y] = grid[y] or {}
            grid[y]._bits = bits
        end
        if line:sub(1, 6) == "BLOCK|" then
            local b = {}
            b.class = line:match("class=([^|]+)")
            b.name  = line:match("name=([^|]+)")
            local px, py, pz = line:match("pos=([%d%.%-]+),([%d%.%-]+),([%d%.%-]+)")
            b.x = tonumber(px); b.y = tonumber(py); b.z = tonumber(pz)
            local tx, ty = line:match("tile=([%d%-]+),([%d%-]+)")
            b.tile_x = tonumber(tx); b.tile_y = tonumber(ty)
            b.collider = line:match("collider=1") and true or false
            b.is_static = line:match("static=1") and true or false
            blockers[#blockers + 1] = b
        end
    end
    return grid, blockers
end

return ethy
