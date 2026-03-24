-- heal_rotation.lua
-- Healer rotation: keeps party alive, weaves DPS when safe.

local TICK_RATE = 0.3
local HEAL_HP = 70
local EMERGENCY_HP = 25
local REST_HP = 80

local stats = { heals = 0, casts = 0 }

local cls = conn.send_command("DETECT_CLASS")
print("Heal rotation started - Class: " .. cls)

conn.send_command("DO_BUFF")

while not is_stopped() do
    local hp = conn.get_hp()
    local mp = conn.get_mp()
    local in_combat = conn.in_combat()

    if not in_combat then
        if hp < 90 or mp < 80 then
            if mp < 80 then
                conn.send_command("CAST_BY_NAME Leyline Meditation")
            elseif hp < 90 then
                conn.send_command("CAST_BY_NAME Rest")
            end
        end
    else
        -- Check for party members in critical condition
        local critical = conn.send_command("GET_PARTY_BELOW " .. EMERGENCY_HP)
        if critical ~= "NONE" and critical ~= "" then
            conn.send_command("DO_SHIELD_PARTY")
            conn.send_command("DO_HEAL_PARTY")
            stats.heals = stats.heals + 1
        else
            local hurt = conn.send_command("GET_PARTY_BELOW " .. HEAL_HP)
            if hurt ~= "NONE" and hurt ~= "" then
                conn.send_command("DO_HEAL_PARTY")
                stats.heals = stats.heals + 1
            else
                -- Self-heal if needed
                if hp < HEAL_HP then
                    conn.send_command("DO_HEAL_TARGET")
                    stats.heals = stats.heals + 1
                else
                    -- Safe to DPS weave
                    conn.send_command("DO_BUFF")
                    local r = conn.send_command("DO_DPS_WEAVE")
                    if r:find("OK") then
                        stats.casts = stats.casts + 1
                    end
                end
            end
        end
    end

    local sleep_ms = math.floor(TICK_RATE * 1000)
    conn.send_command("SLEEP " .. sleep_ms)
end

print(string.format("Heal rotation stopped. Heals: %d, Casts: %d", stats.heals, stats.casts))
