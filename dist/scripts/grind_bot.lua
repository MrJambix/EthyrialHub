-- grind_bot.lua
-- Auto-grind: targets nearest, kills it, loots, rests, repeats.

local TICK_RATE = 0.5
local REST_HP = 70
local REST_MP = 60

local stats = { kills = 0, loots = 0 }
local was_in_combat = false

print("Grind bot started.")
print("Make sure you are in a grinding area with mobs nearby.")

conn.send_command("DO_BUFF")

while not is_stopped() do
    local hp = conn.get_hp()
    local mp = conn.get_mp()
    local in_combat = conn.in_combat()

    if in_combat then
        if not was_in_combat then
            was_in_combat = true
        end

        if not conn.has_target() then
            conn.target_nearest()
        end

        conn.send_command("DO_ROTATION")

    else
        if was_in_combat then
            stats.kills = stats.kills + 1
            was_in_combat = false

            -- Try to loot
            local loot_result = conn.send_command("LOOT_ALL")
            if loot_result:find("OK") then
                stats.loots = stats.loots + 1
            end

            print(string.format("Kill #%d (Loots: %d)", stats.kills, stats.loots))

            -- Rest if needed
            if hp < REST_HP or mp < REST_MP then
                print("Resting...")
                conn.send_command("DO_RECOVER hp_target=90 mp_target=80 timeout=30")
            end

            -- Re-buff
            conn.send_command("DO_BUFF")
        end

        -- Find next target
        if not conn.has_target() then
            conn.target_nearest()
            if conn.has_target() then
                conn.send_command("DO_PULL")
            end
        end
    end

    local sleep_ms = math.floor(TICK_RATE * 1000)
    conn.send_command("SLEEP " .. sleep_ms)
end

print(string.format("Grind stopped. Kills: %d, Loots: %d", stats.kills, stats.loots))
