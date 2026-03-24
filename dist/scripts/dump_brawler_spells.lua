--[[
    Brawler Spell Dump — Captures all spell data + buff info for Brawler rotation building.
    Run while connected as Brawler. Output goes to the Hub log.
]]

print("=== BRAWLER SPELL DUMP ===")
print("")

-- Dump all spells
local raw_spells = conn.send_command("SPELLS_ALL")
print("[SPELLS_ALL raw]")
if raw_spells and raw_spells ~= "" and raw_spells ~= "NONE" then
    for entry in raw_spells:gmatch("[^#]+") do
        entry = entry:match("^%s*(.-)%s*$")
        if entry ~= "" then
            print("  " .. entry)
        end
    end
else
    print("  (no spells returned)")
end

print("")

-- Dump each spell's detailed info
print("[INDIVIDUAL SPELL INFO]")
if raw_spells and raw_spells ~= "NONE" then
    for entry in raw_spells:gmatch("[^#]+") do
        local name = entry:match("name=([^|]+)")
        if name then
            local info = conn.send_command("SPELL_INFO " .. name)
            print("  " .. name .. " => " .. (info or "nil"))
            local cd = conn.send_command("SPELL_CD " .. name)
            local ready = conn.send_command("SPELL_READY " .. name)
            print("    cd=" .. (cd or "?") .. "  ready=" .. (ready or "?"))
        end
    end
end

print("")

-- Dump player buffs (look for Martial Combo and other Brawler buffs)
print("[CURRENT BUFFS]")
local buffs = conn.send_command("PLAYER_BUFFS")
if buffs and buffs ~= "" and buffs ~= "NONE" then
    for entry in buffs:gmatch("[^#]+") do
        entry = entry:match("^%s*(.-)%s*$")
        if entry ~= "" then
            print("  " .. entry)
        end
    end
else
    print("  (no buffs active)")
end

print("")

-- Dump player class info
print("[PLAYER INFO]")
print("  Class: " .. conn.send_command("PLAYER_JOB"))
print("  All: " .. conn.send_command("PLAYER_ALL"))

print("")

-- Dump movement data (has attack speed info)
print("[MOVEMENT / SPEED DATA]")
print("  " .. conn.send_command("PLAYER_MOVEMENT"))

print("")
print("=== DUMP COMPLETE ===")
print("Copy the Log tab contents and share for rotation building.")
