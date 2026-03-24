--[[
╔══════════════════════════════════════════════════════════════╗
║       Discord Bot Bridge — In-Game Companion Lookups         ║
║                                                              ║
║  Copy a !command to clipboard (Ctrl+C) from anywhere:        ║
║    !item Iron Sword    !quest Spider    !moon                ║
║    !locate Blacksmith  !patch           !help                ║
║                                                              ║
║  Or use the Settings > Script Menu dropdowns.                ║
║  Completely silent — no CMD/PowerShell windows during play.  ║
╚══════════════════════════════════════════════════════════════╝
]]

local BOT_URL = "http://127.0.0.1:3847"

-- ═══════════════════════════════════════════════════════════
-- Paths
-- ═══════════════════════════════════════════════════════════

local script_dir = "."
do
    local info = debug.getinfo(1, "S")
    if info and info.source then
        local src = info.source:gsub("^@", "")
        script_dir = src:match("^(.*)[/\\]") or "."
    end
end

local VBS_PATH    = script_dir .. "/common/_api/silent_run.vbs"
local PS_WATCHER  = script_dir .. "/common/_api/clip_watcher.ps1"
local TEMP_DIR    = os.getenv("TEMP") or "C:\\Temp"
local CMD_FILE    = TEMP_DIR .. "\\ethy_bot_cmd.txt"
local HTTP_FILE   = TEMP_DIR .. "\\ethy_http_result.txt"

-- ═══════════════════════════════════════════════════════════
-- Silent helpers
-- ═══════════════════════════════════════════════════════════

local function silent_http(endpoint)
    local url = BOT_URL .. endpoint
    local ps_cmd = string.format(
        "(Invoke-WebRequest -Uri '%s' -UseBasicParsing -TimeoutSec 5).Content",
        url:gsub("'", "''")
    )
    local escaped = ps_cmd:gsub('"', '""')
    local cmd = string.format(
        'wscript "%s" "cmd /c powershell -NoProfile -WindowStyle Hidden -Command \\"%s\\" > \\"%s\\" 2>&1"',
        VBS_PATH, escaped, HTTP_FILE
    )
    os.execute(cmd)
    local f = io.open(HTTP_FILE, "r")
    if not f then return nil end
    local text = f:read("*a")
    f:close()
    if not text or text == "" then return nil end
    return text:match("^%s*(.-)%s*$")
end

local function read_cmd_file()
    local f = io.open(CMD_FILE, "r")
    if not f then return nil end
    local text = f:read("*a")
    f:close()
    if not text or text == "" then return nil end
    return text:match("^%s*(.-)%s*$")
end

local function clear_cmd_file()
    os.remove(CMD_FILE)
end

-- ═══════════════════════════════════════════════════════════
-- JSON helpers
-- ═══════════════════════════════════════════════════════════

local function jval(s, key)
    local v = s:match('"' .. key .. '"%s*:%s*"([^"]*)"')
    if v then return v end
    return s:match('"' .. key .. '"%s*:%s*([%d%.%-]+)')
end

local function jarray(s, key)
    local arr = s:match('"' .. key .. '"%s*:%s*%[(.-)%]')
    if not arr then return {} end
    local out = {}
    for obj in arr:gmatch("{(.-)}") do out[#out + 1] = obj end
    return out
end

local function say(msg) print("[Bot] " .. msg) end

-- ═══════════════════════════════════════════════════════════
-- Lookups (only spawn a process when YOU trigger a search)
-- ═══════════════════════════════════════════════════════════

local function do_item(query)
    say("Looking up: " .. query)
    local raw = silent_http("/api/game/item?name=" .. query:gsub(" ", "%%20"))
    if not raw then say("Bot not reachable — run: npm start"); return end
    if raw:find('"error"') then say("Not found: " .. query); return end
    for i, obj in ipairs(jarray(raw, "items")) do
        if i > 3 then break end
        say(string.format("  [%d] %s — %s (%s)",
            i, jval(obj,"name") or "?", jval(obj,"category") or "", jval(obj,"rarity") or ""))
    end
end

local function do_quest(query)
    say("Looking up quest: " .. query)
    local raw = silent_http("/api/game/quest?name=" .. query:gsub(" ", "%%20"))
    if not raw then say("Bot not reachable"); return end
    if raw:find('"error"') then say("No quests: " .. query); return end
    for i, obj in ipairs(jarray(raw, "quests")) do
        if i > 3 then break end
        say(string.format("  [%d] %s (Lv.%s) %s",
            i, jval(obj,"title") or "?", jval(obj,"level") or "?", jval(obj,"location") or ""))
    end
end

local function do_locate(query)
    say("Searching map: " .. query)
    local raw = silent_http("/api/game/locate?name=" .. query:gsub(" ", "%%20"))
    if not raw then say("Bot not reachable"); return end
    local locs = jarray(raw, "locations")
    if #locs == 0 then say("No locations for: " .. query); return end
    for i, obj in ipairs(locs) do
        if i > 3 then break end
        say(string.format("  [%d] %s — %s",
            i, jval(obj,"title") or "?", (jval(obj,"description") or ""):sub(1,80)))
    end
end

local function do_moon()
    local raw = silent_http("/api/game/moon")
    if not raw then say("Bot not reachable"); return end
    say(string.format("  Moon: %s | Day %s, %s:%s (%s)",
        jval(raw,"moon") or "?", jval(raw,"day") or "?",
        jval(raw,"hour") or "?", jval(raw,"minute") or "?",
        jval(raw,"daytime") == "true" and "Daytime" or "Night"))
    say(string.format("  Next: %s in %s", jval(raw,"nextMoon") or "?", jval(raw,"nextMoonIn") or "?"))
end

local function do_patch()
    local raw = silent_http("/api/game/patchnotes")
    if not raw then say("Bot not reachable"); return end
    local notes = jarray(raw, "notes")
    if #notes == 0 then say("No patch notes"); return end
    for i, obj in ipairs(notes) do
        if i > 2 then break end
        say(string.format("  [%d] %s", i, jval(obj,"title") or jval(obj,"name") or "?"))
    end
end

-- ═══════════════════════════════════════════════════════════
-- Command dispatcher
-- ═══════════════════════════════════════════════════════════

local function dispatch(text)
    if not text or text:sub(1, 1) ~= "!" then return false end
    local cmd_name, args = text:sub(2):match("^(%S+)%s*(.*)")
    if not cmd_name then return false end
    cmd_name = cmd_name:lower()
    print("")
    if cmd_name == "item" then
        if args ~= "" then say("=== Item: " .. args .. " ==="); do_item(args) else say("Usage: !item <name>") end
    elseif cmd_name == "quest" then
        if args ~= "" then say("=== Quest: " .. args .. " ==="); do_quest(args) else say("Usage: !quest <name>") end
    elseif cmd_name == "locate" or cmd_name == "find" or cmd_name == "map" then
        if args ~= "" then say("=== Map: " .. args .. " ==="); do_locate(args) else say("Usage: !locate <name>") end
    elseif cmd_name == "moon" or cmd_name == "time" then
        say("=== Moon / Game Time ==="); do_moon()
    elseif cmd_name == "patch" or cmd_name == "notes" then
        say("=== Patch Notes ==="); do_patch()
    elseif cmd_name == "help" then
        say("!item <name> | !quest <name> | !locate <name> | !moon | !patch")
    else
        say("Unknown: !" .. cmd_name .. " — try !help")
    end
    return true
end

-- ═══════════════════════════════════════════════════════════
-- Startup — launch ONE background clipboard watcher
-- ═══════════════════════════════════════════════════════════

print("╔══════════════════════════════════════════════════╗")
print("║  Discord Bot Bridge — EthyrialCompanion          ║")
print("╚══════════════════════════════════════════════════╝")

clear_cmd_file()

say("Starting silent clipboard watcher...")
local watcher_cmd = string.format(
    'wscript "%s" "powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File \\"%s\\""',
    VBS_PATH, PS_WATCHER
)
os.execute(watcher_cmd)
say("Clipboard watcher running (hidden).")

say("Checking bot...")
local ping = silent_http("/api/game/ping")
if ping and ping:find("ok") then
    say("Connected to EthyCompanion!")
else
    say("WARNING: Bot not running. Start: npm start")
end

say("")
say("HOW TO USE:")
say("  1. Type a command anywhere: !item Iron Sword")
say("  2. Select it and Ctrl+C")
say("  3. Result appears here — no windows, no interruption")
say("  Commands: !item  !quest  !locate  !moon  !patch  !help")
print("")

-- ═══════════════════════════════════════════════════════════
-- Presets
-- ═══════════════════════════════════════════════════════════

local PRESETS = {
    "Iron Sword", "Healing Potion", "Spiritwood", "Blacksmith",
    "Copper Vein", "Spider", "Wolf", "Guardian", "Enchanting",
    "Rinthistle", "Ranger", "Companion", "Gold Vein", "Mana Ash",
}
local MODES = { "Item", "Quest", "Map Location" }

-- ═══════════════════════════════════════════════════════════
-- Main loop — just reads a file, no process spawning
-- ═══════════════════════════════════════════════════════════

local last_cmd     = ""
local preset_idx   = 0
local search_mode  = 0

while not is_stopped() do

    -- ── Check command file (just a file read, zero cost) ──
    local cmd = read_cmd_file()
    if cmd and cmd ~= "" and cmd ~= last_cmd then
        last_cmd = cmd
        clear_cmd_file()
        dispatch(cmd)
    end

    -- ── Menu (Settings > Script Menu) ──
    search_mode = core.menu.combobox("bot_mode",   "Lookup Type",  MODES, search_mode)
    preset_idx  = core.menu.combobox("bot_preset", "Search Term",  PRESETS, preset_idx)

    local go_search = core.menu.checkbox("bot_go_search", ">>> Run Search <<<", false)
    local go_moon   = core.menu.checkbox("bot_go_moon",   ">>> Moon / Time <<<", false)

    if go_search then
        core.menu.set_checkbox("bot_go_search", false)
        local term = PRESETS[preset_idx + 1] or "Iron Sword"
        if search_mode == 0 then say("=== Item: " .. term .. " ==="); do_item(term)
        elseif search_mode == 1 then say("=== Quest: " .. term .. " ==="); do_quest(term)
        elseif search_mode == 2 then say("=== Map: " .. term .. " ==="); do_locate(term) end
    end

    if go_moon then
        core.menu.set_checkbox("bot_go_moon", false)
        say("=== Moon / Game Time ==="); do_moon()
    end

    _ethy_sleep(0.3)
end

-- Kill the background watcher on exit
os.execute(string.format('wscript "%s" "taskkill /f /fi \\"WINDOWTITLE eq clip_watcher\\" >nul 2>&1"', VBS_PATH))
print("[Bot] Bridge stopped.")
