--[[
╔══════════════════════════════════════════════════════════════╗
║        Target Level Logger                                   ║
║                                                              ║
║  Select a mob in-game — prints its level, name, HP, and      ║
║  classification tags to the Hub log each time you switch.    ║
║  Stop the script from the dashboard when done.               ║
╚══════════════════════════════════════════════════════════════╝
]]

local POLL_RATE = 1.0  -- seconds between checks
local SEP = string.rep("═", 50)
local last_uid = nil

print(SEP)
print("  Target Level Logger")
print("  Select a mob to see its level info.")
print(SEP)

while not is_stopped() do
    local target = core.world.get_monsterdex_target()

    if not target then
        if last_uid then
            print("[Level] No target selected.")
            last_uid = nil
        end
    else
        local uid   = target.uid   or "?"
        local name  = target.name  or "Unknown"
        local level = target.level or "0"
        local hpPct = tonumber(target.hp)    or 0
        local maxhp = tonumber(target.max_hp) or 0
        local dist  = target.dist  or "?"
        local boss  = target.boss  == "1"
        local elite = target.elite == "1"
        local rare  = target.rare  == "1"

        local curHp = math.floor(hpPct * maxhp)
        local hpStr = string.format("%d / %d  (%d%%)", curHp, maxhp, math.floor(hpPct * 100))

        local tags = {}
        if boss  then tags[#tags + 1] = "BOSS"  end
        if elite then tags[#tags + 1] = "ELITE" end
        if rare  then tags[#tags + 1] = "RARE"  end
        local tag_str = #tags > 0 and (" [" .. table.concat(tags, ", ") .. "]") or ""

        if tostring(uid) ~= tostring(last_uid) then
            print(SEP)
            print("[Level] Target: " .. name .. tag_str)
            print("[Level]   Level : " .. level)
            print("[Level]   HP    : " .. hpStr)
            print("[Level]   Dist  : " .. dist)
            print("[Level]   UID   : " .. uid)
            last_uid = tostring(uid)
        end
    end

    _ethy_sleep(POLL_RATE)
end

print("[Level] Script stopped.")
