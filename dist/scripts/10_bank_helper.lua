--[[
  Example 10 — Bank Helper
  Interact with the in-game bank: view inventory, filter bank items,
  search by name/category, and display a live bank overview window.

  Requires: Bank NPC window to be open for container-level queries.
  Inventory queries (INV_ALL) work anytime — items are flagged bank=1
  whether the bank window is open or not.

  API used:
    core.inventory.get_all()           → raw INV_ALL string
    core.inventory.open_containers()   → raw OPEN_CONTAINERS string
    core.send_command("INV_ALL")       → same, via generic pipe
]]

local ethy = require("common/ethy_sdk")
local ui   = core.imgui

ethy.print("=== Bank Helper ===")

-- ═══════════════════════════════════════════════════════════════
--  ITEM PARSER
-- ═══════════════════════════════════════════════════════════════

--- Parse the "key=val|key=val###key=val|..." IPC format into a Lua table.
--- @param raw string  raw IPC response from INV_ALL or OPEN_CONTAINERS
--- @return table[]    array of item tables
local function parse_items(raw)
    if not raw or raw == "NONE" or raw == "" then return {} end

    local items = {}
    for entry in raw:gmatch("[^#]+") do
        entry = entry:match("^%s*(.-)%s*$")
        if entry ~= "" then
            local item = {}
            for k, v in entry:gmatch("([%w_]+)=([^|]*)") do
                -- Convert numeric/boolean values
                if v == "1" or v == "true"  then item[k] = true
                elseif v == "0" or v == "false" then item[k] = false
                else
                    local num = tonumber(v)
                    item[k] = num or v
                end
            end
            if item.uid or item.name then
                items[#items + 1] = item
            end
        end
    end
    return items
end

-- ═══════════════════════════════════════════════════════════════
--  INVENTORY HELPERS
-- ═══════════════════════════════════════════════════════════════

--- Get all inventory items (includes bank-flagged items).
local function get_all_items()
    local raw = core.inventory.get_all()
    return parse_items(raw)
end

--- Get only items currently in the bank.
local function get_bank_items()
    local all = get_all_items()
    local bank = {}
    for _, item in ipairs(all) do
        if item.bank then
            bank[#bank + 1] = item
        end
    end
    return bank
end

--- Get only items in your character inventory (not banked).
local function get_bag_items()
    local all = get_all_items()
    local bag = {}
    for _, item in ipairs(all) do
        if not item.bank and (not item.equip or item.equip == 0) then
            bag[#bag + 1] = item
        end
    end
    return bag
end

--- Get items from any currently open container window (e.g. bank NPC).
local function get_open_container_items()
    local raw = core.inventory.open_containers()
    return parse_items(raw)
end

--- Search items by name substring (case-insensitive).
local function search_items(items, query)
    if not query or query == "" then return items end
    local q = query:lower()
    local results = {}
    for _, item in ipairs(items) do
        local name = (item.name or ""):lower()
        local cat  = (item.cat or ""):lower()
        if name:find(q, 1, true) or cat:find(q, 1, true) then
            results[#results + 1] = item
        end
    end
    return results
end

--- Group items by category.
local function group_by_category(items)
    local groups = {}
    local order = {}
    for _, item in ipairs(items) do
        local cat = item.cat or "Unknown"
        if not groups[cat] then
            groups[cat] = {}
            order[#order + 1] = cat
        end
        groups[cat][#groups[cat] + 1] = item
    end
    table.sort(order)
    return groups, order
end

--- Calculate total stack count across matching items.
local function count_item(items, name)
    local total = 0
    for _, item in ipairs(items) do
        if item.name == name then
            total = total + (item.stack or 1)
        end
    end
    return total
end

-- ═══════════════════════════════════════════════════════════════
--  RARITY COLORS
-- ═══════════════════════════════════════════════════════════════

local RARITY_COLORS = {
    [0] = { 0.65, 0.65, 0.65 },   -- Common (grey)
    [1] = { 0.30, 0.85, 0.30 },   -- Uncommon (green)
    [2] = { 0.30, 0.55, 1.00 },   -- Rare (blue)
    [3] = { 0.70, 0.30, 0.90 },   -- Epic (purple)
    [4] = { 1.00, 0.65, 0.00 },   -- Legendary (orange)
    [5] = { 1.00, 0.20, 0.20 },   -- Mythic (red)
}

local function rarity_color(rarity)
    return RARITY_COLORS[rarity or 0] or RARITY_COLORS[0]
end

-- ═══════════════════════════════════════════════════════════════
--  STATE
-- ═══════════════════════════════════════════════════════════════

local show_window   = false
local tab           = 0          -- 0=Bank, 1=Bags, 2=Open Containers, 3=Search
local search_text   = ""
local cached_items  = {}
local cache_time    = 0
local CACHE_TTL     = 1.0        -- refresh every 1s
local sort_mode     = 0          -- 0=Name, 1=Rarity, 2=Category, 3=Stack

-- ═══════════════════════════════════════════════════════════════
--  SORTING
-- ═══════════════════════════════════════════════════════════════

local SORT_NAMES = { "Name", "Rarity", "Category", "Stack" }

local function sort_items(items, mode)
    local copy = {}
    for i, v in ipairs(items) do copy[i] = v end

    if mode == 0 then
        table.sort(copy, function(a, b) return (a.name or "") < (b.name or "") end)
    elseif mode == 1 then
        table.sort(copy, function(a, b)
            if (a.rarity or 0) ~= (b.rarity or 0) then return (a.rarity or 0) > (b.rarity or 0) end
            return (a.name or "") < (b.name or "")
        end)
    elseif mode == 2 then
        table.sort(copy, function(a, b)
            if (a.cat or "") ~= (b.cat or "") then return (a.cat or "") < (b.cat or "") end
            return (a.name or "") < (b.name or "")
        end)
    elseif mode == 3 then
        table.sort(copy, function(a, b)
            if (a.stack or 1) ~= (b.stack or 1) then return (a.stack or 1) > (b.stack or 1) end
            return (a.name or "") < (b.name or "")
        end)
    end

    return copy
end

-- ═══════════════════════════════════════════════════════════════
--  ITEM LIST RENDERER
-- ═══════════════════════════════════════════════════════════════

local function draw_item_list(items)
    if #items == 0 then
        ui.text_colored(0.5, 0.5, 0.5, "  (no items)")
        return
    end

    -- Sort selector
    sort_mode = ui.combo("Sort##bank", sort_mode, table.concat(SORT_NAMES, "\n"))
    items = sort_items(items, sort_mode)

    ui.separator()
    ui.text_colored(0.6, 0.6, 0.6, string.format("  %d item(s)", #items))
    ui.spacing()

    for _, item in ipairs(items) do
        local c = rarity_color(item.rarity)
        local stack_str = ""
        if (item.stack or 1) > 1 then
            stack_str = string.format(" x%d", item.stack)
        end

        local flags = ""
        if item.noted    then flags = flags .. " [N]" end
        if item.material then flags = flags .. " [M]" end
        if item.quest    then flags = flags .. " [Q]" end

        ui.text_colored(c[1], c[2], c[3],
            string.format("  %s%s%s", item.name or "???", stack_str, flags))

        -- Tooltip-style detail on same line
        if item.cat and item.cat ~= "" then
            ui.same_line()
            ui.text_colored(0.4, 0.4, 0.4, string.format("  [%s]", item.cat))
        end
    end
end

-- ═══════════════════════════════════════════════════════════════
--  SUMMARY STATS
-- ═══════════════════════════════════════════════════════════════

local function draw_summary(items, label)
    local total_stacks = 0
    local unique_count = 0
    local by_cat = {}

    local seen = {}
    for _, item in ipairs(items) do
        total_stacks = total_stacks + (item.stack or 1)
        if not seen[item.name or "?"] then
            unique_count = unique_count + 1
            seen[item.name or "?"] = true
        end
        local cat = item.cat or "Other"
        by_cat[cat] = (by_cat[cat] or 0) + (item.stack or 1)
    end

    ui.text(string.format("  %s: %d slots, %d unique, %d total stacks",
        label, #items, unique_count, total_stacks))
end

-- ═══════════════════════════════════════════════════════════════
--  MAIN WINDOW
-- ═══════════════════════════════════════════════════════════════

local function render_window()
    if not show_window then return end

    ui.set_next_window_size(480, 560)
    local visible, open = ui.begin_window("Bank Helper")

    if not open then
        show_window = false
        ui.end_window()
        return
    end

    local ok, err = pcall(function()
        if not visible then return end

        ui.text_colored(1, 0.85, 0.2, "-- Bank Helper --")
        ui.spacing()

        -- Tab selector
        tab = ui.combo("View##bank", tab, "Bank Items\nBag Items\nOpen Containers\nSearch All")
        ui.spacing()

        -- Refresh cache
        local now = ethy.now()
        if now - cache_time > CACHE_TTL then
            cache_time = now
            cached_items = get_all_items()
        end

        if tab == 0 then
            -- ── Bank Items ──
            local bank = {}
            for _, item in ipairs(cached_items) do
                if item.bank then bank[#bank + 1] = item end
            end
            draw_summary(bank, "Bank")
            ui.spacing()
            draw_item_list(bank)

        elseif tab == 1 then
            -- ── Bag Items ──
            local bag = {}
            for _, item in ipairs(cached_items) do
                if not item.bank and (not item.equip or item.equip == 0) then
                    bag[#bag + 1] = item
                end
            end
            draw_summary(bag, "Bags")
            ui.spacing()
            draw_item_list(bag)

        elseif tab == 2 then
            -- ── Open Container Items ──
            local container_items = get_open_container_items()
            if #container_items == 0 then
                ui.text_colored(0.5, 0.5, 0.5, "  No containers open. Talk to a Bank NPC or open a chest.")
            else
                draw_summary(container_items, "Containers")
                ui.spacing()
                draw_item_list(container_items)
            end

        elseif tab == 3 then
            -- ── Search All ──
            ui.text("Search:")
            ui.same_line()
            local changed
            search_text, changed = ui.input_text("##search_bank", search_text)

            local results = search_items(cached_items, search_text)
            ui.spacing()
            draw_summary(results, "Results")
            ui.spacing()
            draw_item_list(results)
        end

        -- ── Category breakdown (always visible at bottom) ──
        ui.spacing()
        ui.separator()
        if ui.tree_node("Category Breakdown") then
            local view_items
            if tab == 0 then
                view_items = get_bank_items()
            elseif tab == 1 then
                view_items = get_bag_items()
            else
                view_items = cached_items
            end

            local groups, order = group_by_category(view_items)
            for _, cat in ipairs(order) do
                local items = groups[cat]
                ui.text_colored(0.7, 0.9, 1.0,
                    string.format("  %s (%d)", cat, #items))
            end
            ui.tree_pop()
        end
    end)

    ui.end_window()

    if not ok then
        ethy.printf("[BankHelper] UI error: %s", tostring(err))
    end
end

-- ═══════════════════════════════════════════════════════════════
--  CALLBACKS
-- ═══════════════════════════════════════════════════════════════

ethy.on_render(function()
    render_window()
end)

ethy.on_render_menu(function()
    show_window = core.menu.checkbox("bank_show", "Bank Helper", show_window)
end)

-- ═══════════════════════════════════════════════════════════════
--  CONSOLE COMMANDS (available from ethy.print / debug console)
-- ═══════════════════════════════════════════════════════════════

--- Print bank item summary to console.
function _G.bank_summary()
    local items = get_bank_items()
    ethy.printf("[Bank] %d items in bank:", #items)
    for _, item in ipairs(items) do
        local stack = (item.stack or 1) > 1 and (" x" .. item.stack) or ""
        ethy.printf("  %s%s  [%s]", item.name or "?", stack, item.cat or "?")
    end
end

--- Print bag item summary to console.
function _G.bag_summary()
    local items = get_bag_items()
    ethy.printf("[Bags] %d items:", #items)
    for _, item in ipairs(items) do
        local stack = (item.stack or 1) > 1 and (" x" .. item.stack) or ""
        ethy.printf("  %s%s  [%s]", item.name or "?", stack, item.cat or "?")
    end
end

--- Search all items by name.
function _G.bank_find(query)
    local items = search_items(get_all_items(), query)
    ethy.printf("[Search: '%s'] %d matches:", query, #items)
    for _, item in ipairs(items) do
        local loc = item.bank and "BANK" or "BAG"
        local stack = (item.stack or 1) > 1 and (" x" .. item.stack) or ""
        ethy.printf("  [%s] %s%s  [%s]", loc, item.name or "?", stack, item.cat or "?")
    end
end

ethy.print("Bank Helper ready — enable via menu checkbox.")
ethy.print("Console: bank_summary()  bag_summary()  bank_find('ore')")
