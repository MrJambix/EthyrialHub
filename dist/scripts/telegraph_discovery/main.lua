--[[
╔══════════════════════════════════════════════════════════════╗
║  Telegraph Discovery — Dump SpellPattern / ProgressInfo      ║
║                                                              ║
║  Run this script while a boss is casting a telegraphed       ║
║  spell to dump the unknown class layouts.                    ║
║                                                              ║
║  Results are printed to the log.  Use the "Dump Now" button  ║
║  in the settings window while your target is casting.        ║
║                                                              ║
║  Mode: DLL Plugin                                            ║
╚══════════════════════════════════════════════════════════════╝
]]

local ethy = require("common/ethy_sdk")

local show_win = true
local last_result = "Waiting... target a casting enemy and press Dump."
local class_dumps = {}

local function dump_class(name)
    local r = core.debug.dump_class(name)
    class_dumps[name] = r or "NOT_FOUND"
    ethy.print("[Discovery] " .. name .. ": " .. (r and string.sub(r, 1, 200) or "NOT_FOUND"))
end

local function dump_target_progress()
    local cast = core.targeting.target_casting()
    if not cast or not cast.is_casting then
        last_result = "Target is NOT casting. Wait for a cast."
        return
    end

    last_result = string.format(
        "CASTING: spell=%s  duration=%.2f  elapsed=%.2f  type=%d",
        cast.spell or "?", cast.duration or 0, cast.elapsed or 0, cast.type or -1)

    local dump = core.targeting.target_casting_dump()
    if dump then
        last_result = last_result .. "\n\nRAW DUMP:\n" .. dump
        ethy.print("[Discovery] Target cast dump: " .. dump)
    end
end

local function dump_hitbox_via_target()
    local raw = core.debug.read_field("target EntityModel")
    ethy.print("[Discovery] target.EntityModel => " .. (raw or "nil"))

    local raw2 = core.debug.read_field("target EntityModel.HitboxDisplay")
    ethy.print("[Discovery] target.EntityModel.HitboxDisplay => " .. (raw2 or "nil"))
end

local function on_update()
end

local function render_window()
    if not show_win then return end
    core.imgui.set_next_window_size(520, 500)
    local vis, open = core.imgui.begin_window("Telegraph Discovery")
    if not open then show_win = false; core.imgui.end_window(); return end

    if vis then
        core.imgui.text("=== Class Layout Dumps ===")
        if core.imgui.button("Dump SpellPattern##d1") then dump_class("SpellPattern") end
        core.imgui.same_line()
        if core.imgui.button("Dump ProgressInfo##d2") then dump_class("ProgressInfo") end
        core.imgui.same_line()
        if core.imgui.button("Dump HitboxDisplay##d3") then dump_class("HitboxDisplay") end

        if core.imgui.button("Dump Spell##d4") then dump_class("Spell") end
        core.imgui.same_line()
        if core.imgui.button("Dump LivingEntityModel##d5") then dump_class("LivingEntityModel") end
        core.imgui.same_line()
        if core.imgui.button("Dump EntityModel##d6") then dump_class("EntityModel") end

        core.imgui.separator(); core.imgui.spacing()

        core.imgui.text("=== Live Target Casting ===")
        if core.imgui.button("Dump Target Cast##live") then dump_target_progress() end
        core.imgui.same_line()
        if core.imgui.button("Dump Target Hitbox##hb") then dump_hitbox_via_target() end

        core.imgui.separator(); core.imgui.spacing()

        core.imgui.text("=== Results ===")
        core.imgui.text(last_result)

        core.imgui.separator()
        for name, data in pairs(class_dumps) do
            core.imgui.spacing()
            core.imgui.text("── " .. name .. " ──")
            local lines = {}
            for line in data:gmatch("[^\n]+") do
                table.insert(lines, line)
            end
            for i, line in ipairs(lines) do
                if i <= 40 then core.imgui.text(line) end
            end
            if #lines > 40 then
                core.imgui.text("... (" .. (#lines - 40) .. " more lines, see log)")
            end
        end
    end
    core.imgui.end_window()
end

local function on_render_menu()
    show_win = core.menu.checkbox("disc_win", "Discovery Window", show_win)
end

ethy.on_update(on_update)
ethy.on_render(render_window)
ethy.on_render_menu(on_render_menu)

ethy.print("[Discovery] Telegraph discovery script loaded. Open the window and dump classes.")
