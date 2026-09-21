-- ForeverDeadZone.lua -- hunter range indicator for WoW: Forever (1.60.x, interface 16001).
-- Author: Thunderz
--
-- Forever uses the vanilla rule: Auto Shot reaches 8 to 35 yards. Melee reaches about 5.
-- Between the two is the DEAD ZONE, where a hunter can neither shoot nor swing.
--
-- HOW THE STATE IS WORKED OUT (measured on build 1.60.1.69913, in and out of combat):
--   * C_Spell.IsSpellInRange(Auto Shot, "target") is a plain yes/no, not secret in combat.
--     yes = between 8 and 35 yards.
--   * CheckInteractDistance("target", 4) is the 28 yard "follow" check and answers for
--     hostile targets in combat. With Auto Shot saying no, it tells TOO CLOSE from TOO FAR.
--   * Melee abilities (range 0-0) answer yes at any distance, and Forever's own
--     C_SwingTimer.IsTargetWithinSwingRange answers nil / "not checked" for addons, so
--     neither can find the melee edge. Two things can: a 5 yard item range check when the
--     client answers one, and otherwise the PLAYER_SWING event, fired for every auto
--     attack: a main-hand swing within the last swing-and-a-bit means melee is landing.
--
-- DISTANCE: no call returns the distance to a hostile target. It is bracketed instead, from
-- every "is the target within N yards?" check that answers: Auto Shot's two edges, the
-- interact checks, and item range checks (the item need not be owned). The bar shows the
-- bracket, e.g. "8-28 yd". More answering checks = a tighter bracket. /dz probe lists them.
--
-- SETTINGS: the Forever beta client writes SavedVariables but does not load them again
-- (measured; a Blizzard bug), so position and size would reset every launch. Macros are
-- stored with the account and do load, so /dz keep on copies the few settings into one
-- general macro and reads it back at login. Opt-in, because it uses a macro slot.

local ADDON = ...
if select(2, UnitClass("player")) ~= "HUNTER" then return end

local AUTO_SHOT = 75
local MAIN_HAND = 0                    -- Enum.PlayerSwingType.MainHand
local DEFAULTS = { x = 0, y = -140, locked = true, scale = 1.5, sound = false, hideNoTarget = true, distance = true }

-- Item range checks, as used by LibRangeCheck for hostile targets: yards -> item IDs.
local ITEMS = {
    [3] = { 42732 }, [5] = { 37727 }, [8] = { 34368, 33278 }, [10] = { 32321 }, [15] = { 33069 },
    [20] = { 10645 }, [25] = { 24268, 41509, 31463 }, [30] = { 835, 7734, 34191 },
    [35] = { 24269, 18904 }, [40] = { 28767 }, [45] = { 23836 },
}
-- CheckInteractDistance index -> yards, as measured here: 3 flips with Auto Shot's 8 yard
-- edge, 4 (follow) is 28.
local INTERACT = { [3] = 8, [4] = 28 }

local STATES = {
    ranged = { "IN RANGE",  0.20, 0.80, 0.25 },
    dead   = { "DEAD ZONE", 0.90, 0.15, 0.15 },
    melee  = { "MELEE",     0.25, 0.55, 0.95 },
    far    = { "TOO FAR",   0.45, 0.45, 0.45 },
}

local db, bar, state, label
local lastSwing, swingLength = -100, 0      -- "no swing seen yet" must never look recent
local saveSoon                          -- defined in the settings macro section

local function say(fmt, ...) print("|cffd2621fForever Dead Zone|r: " .. string.format(fmt, ...)) end
local function secret(v) return issecretvalue and issecretvalue(v) end

-- A call that may be refused or return a secret: nil means "cannot tell".
local function ask(fn, ...)
    if not fn then return nil end
    local ok, v = pcall(fn, ...)
    if not ok or secret(v) then return nil end
    if v == 1 then return true elseif v == 0 then return false end
    return v
end

-- Range --------------------------------------------------------------------------------

local itemInRange = C_Item and C_Item.IsItemInRange or IsItemInRange
local function within(yards)
    for _, id in ipairs(ITEMS[yards] or {}) do
        local v = ask(itemInRange, id, "target")
        if v ~= nil then return v end
    end
    return nil
end

-- lowest and highest the distance can be, from every check that answers
local function bracket(shoot)
    local lo, hi = 0, nil
    local function know(yards, inside)
        if inside == nil then return end
        if inside then if not hi or yards < hi then hi = yards end
        elseif yards > lo then lo = yards end
    end
    for yards in pairs(ITEMS) do know(yards, within(yards)) end
    for index, yards in pairs(INTERACT) do know(yards, ask(CheckInteractDistance, "target", index)) end
    if shoot == true then
        if lo < 8 then lo = 8 end
        if not hi or hi > 35 then hi = 35 end
    end
    if hi and lo > hi then return nil end          -- checks disagree: say nothing rather than guess
    return lo, hi
end

local function currentState()
    if not UnitExists("target") or UnitIsDeadOrGhost("target") then return nil end
    if not ask(UnitCanAttack, "player", "target") then return nil end
    local shoot = ask(C_Spell.IsSpellInRange, AUTO_SHOT, "target")
    if shoot == nil then return nil end                 -- no ranged weapon, or the client will not say
    local lo, hi = bracket(shoot)
    local text
    if db.distance and lo then
        text = hi and (lo == 0 and ("< " .. hi .. " yd") or (lo .. "-" .. hi .. " yd")) or ("> " .. lo .. " yd")
    end
    if shoot then return "ranged", text end
    local near = ask(CheckInteractDistance, "target", 4)
    if near == nil then return nil end
    if not near then return "far", text end
    local melee = within(5)                              -- exact, when the client answers it
    if melee == nil then melee = GetTime() - lastSwing < swingLength + 0.5 end
    return melee and "melee" or "dead", text
end

-- The bar ------------------------------------------------------------------------------

local function show(new, text)
    local caption = new and (STATES[new][1] .. (text and ("  " .. text) or "")) or nil
    if new == state and caption == label then return end
    local was = state
    state, label = new, caption
    if not new then
        bar:SetShown(not db.hideNoTarget or not db.locked)
        bar.text:SetText(db.locked and "" or "Dead Zone (drag me)")
        bar.fill:SetColorTexture(0.15, 0.15, 0.15, 0.8)
        return
    end
    local s = STATES[new]
    bar:Show()
    bar.text:SetText(caption)
    bar.fill:SetColorTexture(s[2], s[3], s[4], 0.9)
    if new == "dead" and was and was ~= "dead" and db.sound and PlaySound and SOUNDKIT then
        PlaySound(SOUNDKIT.RAID_WARNING or 8959, "Master")
    end
end

local function redraw() state = false show(currentState()) end

-- Sized by hand rather than SetScale: a scaled frame reports its position in its own
-- units, which made a dragged bar jump when it was dropped.
local function resize()
    bar:SetSize(150 * db.scale, 22 * db.scale)
    local font = bar.text:GetFont()
    bar.text:SetFont(font or STANDARD_TEXT_FONT, math.floor(11 * db.scale + 0.5), "OUTLINE")
end

local function place()
    bar:ClearAllPoints()
    bar:SetPoint("CENTER", UIParent, "CENTER", db.x, db.y)
end

local function build()
    bar = CreateFrame("Frame", "ForeverDeadZoneBar", UIParent)
    bar:SetMovable(true)
    bar:SetClampedToScreen(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function(self)
        if db.locked then return end
        self.moving = true
        self:StartMoving()
    end)
    bar:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self.moving = nil
        local x, y = self:GetCenter()
        local px, py = UIParent:GetCenter()
        if x and px then db.x, db.y = x - px, y - py end
        place()
        saveSoon()
    end)
    local edge = bar:CreateTexture(nil, "BACKGROUND")
    edge:SetAllPoints()
    edge:SetColorTexture(0, 0, 0, 0.9)
    bar.fill = bar:CreateTexture(nil, "ARTWORK")
    bar.fill:SetPoint("TOPLEFT", 1, -1)
    bar.fill:SetPoint("BOTTOMRIGHT", -1, 1)
    bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bar.text:SetPoint("CENTER")
    bar.text:SetTextColor(1, 1, 1)
    bar:EnableMouse(not db.locked)
    resize()
    place()
    redraw()
end

local function applyAll()
    bar:EnableMouse(not db.locked)
    resize()
    place()
    redraw()
end

-- Settings macro -----------------------------------------------------------------------
-- Rules, each learned the hard way on this client:
--   * never write before the macro has been read, or defaults overwrite a good copy;
--   * the macro list arrives from the server AFTER login: wait for UPDATE_MACROS;
--   * no macro calls in combat;
--   * a SavedVariables table that did load always wins (the day Blizzard fixes this).

local keep = { hadSV = false, ready = false, macrosSeen = false, dirty = false, note = "nothing written yet" }

local function macroName()
    local who = tostring(UnitName("player") or "") .. "-" .. tostring(GetRealmName and GetRealmName() or "")
    local h = 5381
    for c = 1, #who do h = (h * 33 + who:byte(c)) % 2147483647 end
    return string.format("FDZ%08x", h)             -- hashed: any alphabet, within the 16 character limit
end

local function macroAPI()
    return CreateMacro and EditMacro and DeleteMacro and GetMacroBody and GetMacroIndexByName and true or false
end

local function encode()
    return string.format("v=1;x=%.1f;y=%.1f;s=%.2f;f=%d%d%d%d", db.x, db.y, db.scale,
        db.locked and 1 or 0, db.sound and 1 or 0, db.hideNoTarget and 1 or 0, db.distance and 1 or 0)
end

local function decode(s)
    local x, y, sc, f = s:match("^v=1;x=(-?[%d%.]+);y=(-?[%d%.]+);s=([%d%.]+);f=([01][01][01][01])$")
    x, y, sc = tonumber(x), tonumber(y), tonumber(sc)
    if not (x and y and sc) then return false end
    db.x, db.y, db.scale = x, y, math.max(0.5, math.min(4, sc))
    db.locked, db.sound = f:sub(1, 1) == "1", f:sub(2, 2) == "1"
    db.hideNoTarget, db.distance = f:sub(3, 3) == "1", f:sub(4, 4) == "1"
    return true
end

local function readMacro()
    if not macroAPI() then return nil end
    local index = GetMacroIndexByName(macroName())
    if not index or index == 0 then return nil end
    return (GetMacroBody(index) or ""):match("^/dz store (.+)$")
end

local function writeMacro()
    keep.dirty = false
    if not (db and db.keep and keep.ready) then return end
    if not macroAPI() then keep.note = "this client has no macro API" return end
    if InCombatLockdown() then keep.afterCombat = true return end
    local body, name = "/dz store " .. encode(), macroName()
    local index = GetMacroIndexByName(name)
    local ok
    if index and index > 0 then
        ok = pcall(EditMacro, index, name, nil, body)
    else
        ok = pcall(CreateMacro, name, "INV_Misc_Gear_01", body, nil)      -- nil = a general macro
        ok = ok and (GetMacroIndexByName(name) or 0) > 0
    end
    keep.note = ok and "saved in macro " .. name or "could not write the macro (no free general macro slot?)"
    if not ok then say(keep.note) end
end

saveSoon = function()
    if keep.dirty then return end
    keep.dirty = true
    C_Timer.After(1, writeMacro)
end

-- final = the macro list has certainly loaded, so "no macro" is an answer, not "not yet".
local function loadKept(final)
    if keep.ready then return end
    local stored = readMacro()
    if stored then
        db.keep = true                                   -- the macro existing is the opt-in
        if not keep.hadSV and decode(stored) then
            keep.restored = true
            if bar then applyAll() end
            say("the client did not load saved settings (beta bug), so they were restored from your settings macro.")
        end
    end
    if stored or final then
        keep.ready = true
        if final and not stored and not keep.hadSV and not db.keep then
            local iface = select(4, GetBuildInfo())
            if type(iface) == "number" and iface >= 16000 and iface < 20000 then
                say("heads up: the beta client forgets addon settings when the game restarts. /dz keep on stores this bar's position and options in a macro.")
            end
        end
    end
end

-- Events -------------------------------------------------------------------------------

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("UPDATE_MACROS")          -- from file load, so an early firing is not missed
ev:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        keep.hadSV = type(ForeverDeadZoneDB) == "table" and next(ForeverDeadZoneDB) ~= nil
        ForeverDeadZoneDB = ForeverDeadZoneDB or {}
        db = ForeverDeadZoneDB
        -- 0.1.0 shipped with the sound on and a small bar: move those saves to the new defaults once.
        if db.locked ~= nil and not db.v then db.sound, db.scale = false, DEFAULTS.scale end
        db.v = 2
        for k, v in pairs(DEFAULTS) do if db[k] == nil then db[k] = v end end
        build()
        loadKept(keep.macrosSeen)
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        pcall(self.RegisterEvent, self, "PLAYER_SWING")           -- Forever only
        -- UPDATE_MACROS says when the list has arrived; the timer covers a client where it never fires.
        if not keep.ready then C_Timer.After(15, function() loadKept(true) end) end
        -- Range has no event an addon can rely on here, so poll. Never while being dragged.
        C_Timer.NewTicker(0.1, function() if not bar.moving then show(currentState()) end end)
    elseif event == "UPDATE_MACROS" then
        keep.macrosSeen = true
        if db then loadKept(true) end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if keep.afterCombat then keep.afterCombat = nil writeMacro() end
    elseif event == "PLAYER_SWING" then
        local length, weapon = ...
        if weapon == MAIN_HAND and not secret(length) and type(length) == "number" then
            lastSwing, swingLength = GetTime(), length
        end
    end
end)

-- Slash --------------------------------------------------------------------------------

SLASH_FOREVERDEADZONE1, SLASH_FOREVERDEADZONE2 = "/deadzone", "/dz"
SlashCmdList.FOREVERDEADZONE = function(msg)
    local cmd, rest = (msg or ""):match("^(%S*)%s*(.-)$")
    cmd = cmd:lower()
    if cmd == "unlock" or cmd == "lock" then
        db.locked = cmd == "lock"
        bar:EnableMouse(not db.locked)
        redraw()
        saveSoon()
        say(db.locked and "locked." or "unlocked: drag the bar, then /dz lock.")
    elseif cmd == "scale" and tonumber(rest) then
        db.scale = math.max(0.5, math.min(4, tonumber(rest)))
        resize()
        saveSoon()
        say("scale %.2f", db.scale)
    elseif cmd == "sound" then
        db.sound = not db.sound
        saveSoon()
        say("dead zone warning sound %s.", db.sound and "on" or "off")
    elseif cmd == "distance" then
        db.distance = not db.distance
        redraw()
        saveSoon()
        say("distance %s.", db.distance and "shown" or "hidden")
    elseif cmd == "always" then
        db.hideNoTarget = not db.hideNoTarget
        redraw()
        saveSoon()
        say(db.hideNoTarget and "hidden without an attackable target." or "always shown.")
    elseif cmd == "reset" then
        db.x, db.y, db.scale = DEFAULTS.x, DEFAULTS.y, DEFAULTS.scale
        resize()
        place()
        saveSoon()
        say("position and scale reset.")
    elseif cmd == "keep" then
        local want = rest:lower()
        if want == "on" then
            db.keep = true
            if not keep.ready then say("still waiting for the macro list; it will be saved in a moment.") end
            saveSoon()
            say("settings will be kept in one general macro (%s).", macroName())
        elseif want == "off" then
            db.keep = false
            if InCombatLockdown() then say("leave combat first, then /dz keep off again.") return end
            local index = macroAPI() and GetMacroIndexByName(macroName())
            if index and index > 0 then pcall(DeleteMacro, index) end
            keep.note = "off; macro removed"
            say("settings macro removed.")
        else
            say("settings macro: %s. Saved settings this login %s. %s", db.keep and "ON" or "off",
                keep.hadSV and "LOADED normally" or "were EMPTY (beta bug)", keep.note)
            say("/dz keep on | off")
        end
    elseif cmd == "store" then
        say("this macro holds your Forever Dead Zone settings. It is read at login; there is no need to click it.")
    elseif cmd == "probe" then
        if not UnitExists("target") then say("target something attackable first.") return end
        local parts, yards = {}, {}
        for y in pairs(ITEMS) do yards[#yards + 1] = y end
        table.sort(yards)
        for _, y in ipairs(yards) do parts[#parts + 1] = y .. "=" .. tostring(within(y)) end
        say("item checks (yards=inside?): %s", table.concat(parts, "  "))
        say("interact 8yd=%s 28yd=%s | auto shot=%s | combat=%s", tostring(ask(CheckInteractDistance, "target", 3)),
            tostring(ask(CheckInteractDistance, "target", 4)), tostring(ask(C_Spell.IsSpellInRange, AUTO_SHOT, "target")),
            tostring(InCombatLockdown()))
    else
        say("/dz unlock | lock    move the bar")
        say("/dz scale <0.5-4>    size (default 1.5)")
        say("/dz distance         show or hide the distance bracket")
        say("/dz sound            warning sound when you enter the dead zone (default off)")
        say("/dz always           show the bar even with no target")
        say("/dz keep on | off    keep these settings in a macro (the beta client forgets them otherwise)")
        say("/dz reset            back to the default spot and size")
        say("/dz probe            which range checks this client answers for your target")
        say("green = can shoot (8-35 yd), red = dead zone, blue = melee, grey = too far.")
    end
end
