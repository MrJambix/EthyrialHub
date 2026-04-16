-- ── Engine ────────────────────────────────────────────────────────────
local E = {
    modules = {},
    _events = {},
    _prev   = {},
    DF      = { profile = {} },
    media   = {},
}

function E:NewModule(name)
    local m = { _name = name, _parent = self }
    self.modules[name] = m
    return m
end

function E:GetModule(name)
    return self.modules[name]
end

function E:RegisterEvent(event, fn)
    local list = self._events[event]
    if not list then
        list = {}
        self._events[event] = list
    end
    list[#list + 1] = fn
end

function E:Fire(event, ...)
    local list = self._events[event]
    if not list then return end
    for i = 1, #list do
        local ok, err = pcall(list[i], ...)
        if not ok then
            core.log_error("[Example] event " .. event .. " handler: " .. tostring(err))
        end
    end
end

function E:Log(msg)
    core.log("[Example] " .. tostring(msg))
end

-- ── Defaults / profile ────────────────────────────────────────────────
-- Everything user-tweakable lives in E.db. ElvUI calls this SavedVariables;
-- we persist it to disk via core.profile_read/write after a drag.
E.DF.profile = {
    unitframes = {
        player = {
            x       = -420,  -- offset from screen center
            y       = -260,
            width   = 260,
            height  = 46,
            barGap  = 2,
            nameSize = 14,
            hpSize   = 12,
        },
    },
}

-- ── Profile persistence ───────────────────────────────────────────────
-- We do not depend on a JSON library — the profile is hand-serialized as a
-- tiny key=value format so it's trivial to round-trip without dependencies.
-- Only the mover-relevant fields (x, y) are persisted for now; the rest of
-- the table comes from E.DF.profile so default changes propagate on reload.
local PROFILE_NAME = "example_addon"

local function deep_copy(t)
    local out = {}
    for k, v in pairs(t) do
        if type(v) == "table" then out[k] = deep_copy(v) else out[k] = v end
    end
    return out
end

function E:SaveProfile()
    local db = self.db.unitframes.player
    local blob = string.format("player.x=%d\nplayer.y=%d\n",
        math.floor(db.x + 0.5), math.floor(db.y + 0.5))
    local ok = core.profile_write(PROFILE_NAME, blob)
    if ok then self:Log("profile saved") else self:Log("profile save FAILED") end
end

function E:LoadProfile()
    local blob = core.profile_read(PROFILE_NAME)
    if not blob then return false end
    local db = self.db.unitframes.player
    for line in string.gmatch(blob, "[^\r\n]+") do
        local key, val = string.match(line, "([^=]+)=(.+)")
        if key == "player.x" then db.x = tonumber(val) or db.x end
        if key == "player.y" then db.y = tonumber(val) or db.y end
    end
    self:Log(string.format("profile loaded (x=%d y=%d)", db.x, db.y))
    return true
end

E.db = deep_copy(E.DF.profile)
E:LoadProfile()

-- ── Media ─────────────────────────────────────────────────────────────
E.media = {
    bgColor    = {0.05, 0.05, 0.05, 0.85},
    bgCombat   = {0.18, 0.02, 0.02, 0.92},
    borderDark = {0.00, 0.00, 0.00, 1.00},
    hpFull     = {0.10, 0.70, 0.25, 1.00},
    hpMid      = {0.85, 0.75, 0.10, 1.00},
    hpLow      = {0.80, 0.12, 0.12, 1.00},
    textColor  = {1.00, 1.00, 1.00, 1.00},
    textDim    = {0.75, 0.75, 0.75, 1.00},
}

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function hp_color(pct)
    local lo, mid, hi = E.media.hpLow, E.media.hpMid, E.media.hpFull
    if pct >= 50 then
        local t = (pct - 50) / 50
        return lerp(mid[1], hi[1], t), lerp(mid[2], hi[2], t),
               lerp(mid[3], hi[3], t), 1
    else
        local t = pct / 50
        return lerp(lo[1], mid[1], t), lerp(lo[2], mid[2], t),
               lerp(lo[3], mid[3], t), 1
    end
end

-- ── UnitFrames module ─────────────────────────────────────────────────
local UF = E:NewModule("UnitFrames")

-- Panels can't nest in the Unity bridge, so background / fill / border all
-- live at root and we recompute their screen positions ourselves. Text,
-- however, CAN parent to a panel — name/hp texts use local coords.

function UF:Construct_Background(frame)
    local db = frame.db
    local c = E.media.bgColor
    frame.bg = {
        handle = game.ui.panel(db.x, db.y, db.width, db.height,
                               c[1], c[2], c[3], c[4]),
        x = db.x, y = db.y, w = db.width, h = db.height,
    }
end

function UF:Construct_HealthBar(frame)
    local db  = frame.db
    local gap = db.barGap
    local w   = db.width - gap * 2
    local h   = db.height - gap * 2 - db.nameSize - 2
    local x   = db.x  -- centered — fill is recomputed in Update_HealthBar
    local y   = db.y - (db.nameSize + 2) / 2
    local r, g, b, a = hp_color(100)
    frame.hp = {
        handle  = game.ui.panel(x, y, w, h, r, g, b, a),
        maxW    = w,
        h       = h,
        baseX   = x,
        y       = y,
        pct     = 100,
    }
end

function UF:Construct_NameText(frame)
    local db = frame.db
    local c  = E.media.textColor
    -- Local coords relative to bg panel center. Name sits at the top.
    local y = -(db.height / 2) + (db.nameSize / 2) + 2
    frame.nameText = {
        handle = game.ui.text(frame.bg.handle,
                              0, y, db.width - 8, db.nameSize,
                              db.nameSize,
                              c[1], c[2], c[3], c[4],
                              "Player"),
    }
end

function UF:Construct_HPText(frame)
    local db = frame.db
    local c  = E.media.textColor
    local y = (db.nameSize / 2) + 1
    frame.hpText = {
        handle = game.ui.text(frame.bg.handle,
                              0, y, db.width - 8, db.hpSize,
                              db.hpSize,
                              c[1], c[2], c[3], c[4],
                              "- / -"),
    }
end

function UF:Construct_PlayerFrame()
    local frame = {
        unit = "player",
        db   = E.db.unitframes.player,
    }
    self:Construct_Background(frame)
    self:Construct_HealthBar(frame)
    self:Construct_NameText(frame)
    self:Construct_HPText(frame)

    -- Make the background panel draggable. The health bar is a sibling (panels
    -- can't nest in the Unity bridge), so it follows via db.x/db.y sync in the
    -- tick loop — see UF:SyncDragged() below.
    game.ui.set_movable(frame.bg.handle, true)

    self.player = frame
    E:Log("player frame constructed")
    return frame
end

-- Called each tick to read back the bg panel's current anchoredPosition
-- (which the DLL-side mover poll rewrote if the user is dragging) and
-- propagate it to db.x/db.y so the health bar follows. Debounces a profile
-- save 1s after drag ends.
local _dragLastMoveMs = 0
local _dragDirty      = false

function UF:SyncDragged()
    local frame = self.player
    if not frame then return end
    local x, y, ok = game.ui.get_pos(frame.bg.handle)
    if not ok then return end
    local db = frame.db
    if x ~= db.x or y ~= db.y then
        db.x = x
        db.y = y
        frame.bg.x = x
        frame.bg.y = y
        -- Recompute hp fill base position so it tracks the new center.
        frame.hp.baseX = x
        frame.hp.y     = y - (db.nameSize + 2) / 2
        -- Force a redraw of size/pos this tick.
        frame.hp.pct = -1
        _dragLastMoveMs = core.time_ms()
        _dragDirty = true
    elseif _dragDirty and (core.time_ms() - _dragLastMoveMs) > 800 then
        _dragDirty = false
        E:SaveProfile()
    end
end

function UF:Update_HealthBar(frame, pct)
    local hp = frame.hp
    if hp.pct == pct then return end
    hp.pct = pct
    local newW = math.max(1, math.floor(hp.maxW * (pct / 100)))
    -- Shrink from the left: keep left edge fixed, so x offset moves left by
    -- (maxW - newW)/2 relative to the bar's original centered position.
    local shift = (hp.maxW - newW) / 2
    game.ui.set_size(hp.handle, newW, hp.h)
    game.ui.set_pos(hp.handle, hp.baseX - shift, hp.y)
    local r, g, b, a = hp_color(pct)
    game.ui.set_color(hp.handle, r, g, b, a)
end

function UF:Update_Background(frame, in_combat)
    local c = in_combat and E.media.bgCombat or E.media.bgColor
    game.ui.set_color(frame.bg.handle, c[1], c[2], c[3], c[4])
end

function UF:Update_PlayerFrame(p)
    local frame = self.player
    if not frame then return end

    local name = p.name or "Player"
    game.ui.set_text(frame.nameText.handle, name)

    local pct    = p.hp or 0       -- Hub gives percent 0-100
    local maxHp  = p.max_hp or 0
    local curHp  = math.floor(pct * maxHp / 100 + 0.5)
    game.ui.set_text(frame.hpText.handle,
        string.format("%d / %d  (%.0f%%)", curHp, maxHp, pct))

    self:Update_HealthBar(frame, pct)
    self:Update_Background(frame, p.in_combat and true or false)
end

-- ── Bootstrap ─────────────────────────────────────────────────────────
E:Log("loading ElvUI-shaped scaffolding")

if not game.ui.init() then
    core.log_error("[Example] game.ui.init() failed — aborting")
    return
end

-- Clear any leftovers from a previous reload so construct is clean.
game.ui.destroy_all()

UF:Construct_PlayerFrame()

-- ── Tick loop — synthesize events from state diff, drive Update_PlayerFrame ──
core.register_on_update_callback(function()
    -- Pull back the bg panel's current pos (moved by the DLL mover poll if the
    -- user is dragging). Must run before Update_PlayerFrame so the health bar
    -- reflects the new center this frame.
    UF:SyncDragged()

    local p = game.raw.player()
    if not p then return end

    if E._prev.in_combat ~= p.in_combat then
        E._prev.in_combat = p.in_combat
        E:Fire(p.in_combat and "PLAYER_REGEN_DISABLED" or "PLAYER_REGEN_ENABLED", p)
    end

    if p.hp and E._prev.hp and (E._prev.hp - p.hp) > 15 then
        E:Fire("UNIT_HEALTH_BIG_DROP", p, E._prev.hp - p.hp)
    end
    E._prev.hp = p.hp

    UF:Update_PlayerFrame(p)
end)

-- ── Event handlers (mirrors ElvUI's E:RegisterEvent style) ───────────
E:RegisterEvent("PLAYER_REGEN_DISABLED", function() E:Log("entering combat") end)
E:RegisterEvent("PLAYER_REGEN_ENABLED",  function() E:Log("leaving combat")  end)
E:RegisterEvent("UNIT_HEALTH_BIG_DROP",  function(_, delta)
    E:Log(string.format("hp drop %.0f", delta))
end)
