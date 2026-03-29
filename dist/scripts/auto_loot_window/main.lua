local ethy = require("common/ethy_sdk")
local ui = core.imgui

ethy.print("=== Auto Loot Window loaded ===")
ethy.print("  Window-only mode — no corpse interaction")

local POLL_FAST     = 0.05
local POLL_IDLE     = 0.20
local LOOT_COOLDOWN = 0.10
local GOLD_POLL     = 1.0
local INV_SNAPSHOT_COOLDOWN = 0.5

local last_tick      = 0
local last_loot      = 0
local last_gold_tick = 0
local last_snapshot  = 0
local show_window    = true

local start_gold   = nil
local start_time   = nil
local current_gold = 0

local stats = { looted = 0, windows = 0 }

local inv_before    = {}
local items_gained  = {}
local items_sorted  = {}
local items_dirty   = false

local function log(msg, ...)
    ethy.printf("[LootWindow] " .. msg, ...)
end

local function split_currency(raw_gold)
    raw_gold = math.floor(raw_gold)
    local gold   = math.floor(raw_gold / 10000)
    local silver = math.floor((raw_gold % 10000) / 100)
    local copper = raw_gold % 100
    return gold, silver, copper
end

local function format_currency(raw_gold)
    local g, s, c = split_currency(raw_gold)
    local parts = {}
    if g > 0 then parts[#parts + 1] = g .. "g" end
    if s > 0 or g > 0 then parts[#parts + 1] = s .. "s" end
    parts[#parts + 1] = c .. "c"
    return table.concat(parts, " ")
end

local function format_time(seconds)
    seconds = math.floor(seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    if h > 0 then
        return string.format("%dh %02dm %02ds", h, m, s)
    elseif m > 0 then
        return string.format("%dm %02ds", m, s)
    end
    return string.format("%ds", s)
end

local function read_gold()
    local ok, val = pcall(core.player.gold)
    if ok and val then return tonumber(val) or 0 end
    return 0
end

local function is_safe()
    local hp = core.player.hp()
    if not hp or hp <= 0 then return false end
    if core.player.frozen() then return false end
    return true
end

local function snapshot_inventory()
    local snap = {}
    local ok, inv = pcall(core.inventory.get_items)
    if not ok or not inv then return snap end
    for _, item in ipairs(inv) do
        local name = item.name
        if name and name ~= "" then
            local count = item.stack or 1
            snap[name] = (snap[name] or 0) + count
        end
    end
    return snap
end

local function diff_inventory(before, after)
    local new_items = {}
    for name, count in pairs(after) do
        local prev = before[name] or 0
        if count > prev then
            new_items[name] = count - prev
        end
    end
    return new_items
end

local function rebuild_sorted()
    items_sorted = {}
    for name, qty in pairs(items_gained) do
        items_sorted[#items_sorted + 1] = { name = name, qty = qty }
    end
    table.sort(items_sorted, function(a, b)
        if a.qty ~= b.qty then return a.qty > b.qty end
        return a.name < b.name
    end)
    items_dirty = false
end

local function record_gains(new_items)
    for name, qty in pairs(new_items) do
        items_gained[name] = (items_gained[name] or 0) + qty
        log("  +%d  %s", qty, name)
    end
    items_dirty = true
end

local function get_loot_count()
    local ok, count = pcall(core.inventory.loot_window_count)
    if ok and count and count > 0 then return count end
    local raw = core.send_command("LOOT_WINDOW_COUNT")
    return tonumber(raw) or 0
end

local function try_loot()
    local count = get_loot_count()
    if count <= 0 then return false end

    inv_before = snapshot_inventory()

    local result = core.inventory.loot_all()
    stats.windows = stats.windows + 1
    stats.looted  = stats.looted + count
    log("Looted %d item(s) -> %s  (total windows: %d, items: %d)",
        count, tostring(result), stats.windows, stats.looted)

    ethy.after(INV_SNAPSHOT_COOLDOWN, function()
        local inv_after = snapshot_inventory()
        local new_items = diff_inventory(inv_before, inv_after)
        if next(new_items) then
            record_gains(new_items)
        end
    end)

    return true
end

local function tick()
    local now = ethy.now()

    if not start_time then
        start_time = now
        start_gold = read_gold()
        current_gold = start_gold
        log("Session started — initial gold: %s (%d raw)", format_currency(start_gold), start_gold)
    end

    if now - last_gold_tick >= GOLD_POLL then
        last_gold_tick = now
        current_gold = read_gold()
    end

    if now - last_loot < LOOT_COOLDOWN then return end

    local poll = (now - last_loot < 1.0) and POLL_FAST or POLL_IDLE
    if now - last_tick < poll then return end
    last_tick = now

    if not is_safe() then return end

    if try_loot() then
        last_loot = now
        current_gold = read_gold()
        last_gold_tick = now
    end
end

local function render_window()
    if not show_window then return end

    if items_dirty then rebuild_sorted() end

    local item_count = #items_sorted

    ui.set_next_window_size(260, 300)
    ui.set_next_window_pos(10, 10)
    local visible, open = ui.begin_window("Loot Window")

    if not open then
        show_window = false
        ui.end_window()
        return
    end

    local draw_ok, draw_err = pcall(function()
        if not visible then return end
        local elapsed = start_time and (ethy.now() - start_time) or 0
        local gained  = start_gold and (current_gold - start_gold) or 0
        if gained < 0 then gained = 0 end

        local per_hour = (elapsed > 10) and (gained / elapsed * 3600) or 0

        -- Compact summary line
        ui.text_colored(1.0, 0.85, 0.0, format_currency(gained))
        ui.same_line()
        ui.text(string.format("(%s/hr)  %s", format_currency(per_hour), format_time(elapsed)))
        ui.text(string.format("Windows: %d  Items: %d", stats.windows, stats.looted))
        ui.separator()

        -- Items
        ui.text_colored(0.7, 0.9, 1.0, string.format("Items (%d)", item_count))
        if item_count > 0 then
            for i, entry in ipairs(items_sorted) do
                if i > 15 then
                    ui.text_colored(0.5, 0.5, 0.5,
                        string.format("  +%d more", item_count - 15))
                    break
                end
                ui.text(string.format("  x%-3d %s", entry.qty, entry.name))
            end
        end

        if ui.button("Reset##lw") then
            start_gold    = current_gold
            start_time    = ethy.now()
            stats.looted  = 0
            stats.windows = 0
            items_gained  = {}
            items_sorted  = {}
            items_dirty   = false
            log("Stats reset")
        end
    end)

    ui.end_window()

    if not draw_ok then
        log("Window UI error: %s", tostring(draw_err))
    end
end

ethy.on_update(function()
    tick()
end)

ethy.on_render(function()
    render_window()
end)

ethy.print("Auto Loot Window ready — watching for loot windows.")
