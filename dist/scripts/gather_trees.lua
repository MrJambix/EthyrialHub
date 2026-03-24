--[[
╔══════════════════════════════════════════════════════════════╗
║              Gather Trees — Woodcutting Bot                  ║
║                                                              ║
║  Scans for nearby trees, walks to the closest usable one,    ║
║  gathers it, and repeats. Pauses in combat or low HP.       ║
╚══════════════════════════════════════════════════════════════╝
]]

local MAX_RANGE       = 50
local REST_HP         = 60
local GATHER_COOLDOWN = 4.0
local TICK_RATE       = 1.0

local stats = { gathered = 0, moved = 0, rested = 0 }
local last_gather = 0
local state = "idle"
local player_name = ""

local function now()
    return core.time()
end

local function log(msg)
    print("[TreeBot] " .. msg)
end

local function parse_nodes(raw)
    if not raw or raw == "" or raw == "NONE" then return {} end
    local nodes = {}
    for entry in raw:gmatch("[^#]+") do
        entry = entry:match("^%s*(.-)%s*$")
        if entry ~= "" and not entry:match("^count=") then
            local n = {}
            for k, v in entry:gmatch("([%w_]+)=([^|]+)") do
                local num = tonumber(v)
                n[k] = (num ~= nil) and num or v
            end
            if n.name and n.dist and n.type == "tree" then
                nodes[#nodes + 1] = n
            end
        end
    end
    table.sort(nodes, function(a, b) return (a.dist or 999) < (b.dist or 999) end)
    return nodes
end

local data = core.player.get_all()
if data and data.name then
    player_name = data.name
end
log("Player: " .. player_name)
log(string.format("Config: range=%dm, rest_hp=%d%%, cooldown=%.1fs", MAX_RANGE, REST_HP, GATHER_COOLDOWN))

while not is_stopped() do
    local hp = conn.get_hp()
    local in_combat = conn.in_combat()

    if in_combat then
        if state ~= "combat" then
            log("In combat - pausing")
            state = "combat"
        end
        _ethy_sleep(TICK_RATE)
        goto continue
    end

    if hp < REST_HP and not in_combat then
        if state ~= "resting" then
            log(string.format("Low HP (%.0f%%) - resting", hp))
            state = "resting"
            stats.rested = stats.rested + 1
            if core.spells.is_ready("Rest") then
                core.spells.cast("Rest")
            end
        end
        _ethy_sleep(3.0)
        goto continue
    end

    if now() - last_gather < GATHER_COOLDOWN then
        _ethy_sleep(0.5)
        goto continue
    end

    local raw = core.gathering.scan_trees()
    local trees = parse_nodes(raw)

    local target = nil
    for _, t in ipairs(trees) do
        if t.dist and t.dist <= MAX_RANGE and t.hidden == 0 and t.spawned == 1 then
            target = t
            break
        end
    end

    if not target then
        if state ~= "scanning" then
            log(string.format("No usable trees within %dm (%d total nearby)", MAX_RANGE, #trees))
            state = "scanning"
        end
        _ethy_sleep(TICK_RATE * 2)
        goto continue
    end

    if target.dist < 4 then
        state = "gathering"
        local result = core.gathering.gather_nearest("tree")
        if result and (result:find("OK") or result:find("GATHER")) then
            stats.gathered = stats.gathered + 1
            log(string.format("#%d Gathered: %s (%.1fm)", stats.gathered, target.name, target.dist))
            last_gather = now()
        else
            log(string.format("Gather attempt on %s: %s", target.name, result or "nil"))
            last_gather = now()
        end
    else
        if state ~= "moving" then
            log(string.format("Moving to %s (%.0fm)", target.name, target.dist))
            state = "moving"
            stats.moved = stats.moved + 1
        end
        core.movement.move_to(target.x, target.y)
    end

    _ethy_sleep(TICK_RATE)
    ::continue::
end

log(string.format("Stopped. Gathered: %d, Moved: %d, Rested: %d", stats.gathered, stats.moved, stats.rested))
