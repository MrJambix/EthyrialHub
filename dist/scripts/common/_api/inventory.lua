-- ═══════════════════════════════════════════════════════════════
--  core.inventory — Inventory API
-- ═══════════════════════════════════════════════════════════════

local inv = {}

function inv.get_all()
    return _cmd("INV_ALL")
end

function inv.get_count()
    return tonumber(_cmd("INV_COUNT")) or 0
end

function inv.equipped()
    return _cmd("EQUIPPED")
end

function inv.use_item(uid)
    return _cmd("USE_ITEM " .. uid)
end

function inv.equip_item(uid)
    return _cmd("EQUIP_ITEM " .. uid)
end

function inv.unequip_slot(slot)
    return _cmd("UNEQUIP_SLOT " .. slot)
end

function inv.loot_all()
    return _cmd("LOOT_ALL")
end

function inv.loot_window_count()
    return tonumber(_cmd("LOOT_WINDOW_COUNT")) or 0
end

function inv.open_containers()
    return _cmd("OPEN_CONTAINERS")
end

function inv.open_containers_count()
    return tonumber(_cmd("OPEN_CONTAINERS_COUNT")) or 0
end

-- ── Parsed helpers ──

function inv.get_equipped()
    return _parse_lines(_cmd("EQUIPPED"))
end

function inv.get_items()
    return _parse_lines(_cmd("INV_ALL"))
end

return inv
