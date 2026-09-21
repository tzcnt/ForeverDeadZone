-- Run from the addon folder: lua tests/test_deadzone.lua
-- A fake client, just enough of it: range answers, the swing event, macros, timers.
unpack = unpack or table.unpack

local frames, timers, tickers, macros, printed
local now, combat = 0, false
local world = {}          -- what the fake client answers about the target

local methods = {}
-- unknown METHODS (capitalised, like the real API) are no-ops; unknown fields stay nil
methods.__index = function(_, k) return methods[k] or (type(k) == 'string' and k:match('^%u') and function() end) or nil end
local function object() return setmetatable({ events = {}, scripts = {}, shown = true }, methods) end
function methods:SetScript(k, fn) self.scripts[k] = fn end
function methods:RegisterEvent(e) self.events[e] = true end
function methods:CreateTexture() return object() end
function methods:CreateFontString() return object() end
function methods:SetText(t) self.textValue = t end
function methods:SetShown(v) self.shown = v and true or false end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:GetFont() return "font", 11, "" end
function methods:GetCenter() return 500, 300 end
function methods:SetPoint(_, _, _, x, y) self.px, self.py = x, y end
function methods:SetSize(w, h) self.w, self.h = w, h end

CreateFrame = function(_, name) local f = object() frames[#frames + 1] = f if name then _G[name] = f end return f end
C_Timer = {
    After = function(_, fn) timers[#timers + 1] = fn end,
    NewTicker = function(_, fn) tickers[#tickers + 1] = fn return {} end,
}
local function runTimers() local t = timers timers = {} for _, fn in ipairs(t) do fn() end end
local function tick() for _, fn in ipairs(tickers) do fn() end end
GetTime = function() return now end
InCombatLockdown = function() return combat end
UnitClass = function() return "Hunter", world.class or "HUNTER" end
UnitName = function() return "Tester" end
GetRealmName = function() return "Beta" end
UnitExists = function() return world.target ~= nil end
UnitIsDeadOrGhost = function() return false end
UnitCanAttack = function() return world.target == "hostile" end
C_Spell = { IsSpellInRange = function() return world.shoot end }
CheckInteractDistance = function(_, i) if i == 4 then return world.d <= 28 else return world.d <= 8 end end
C_Item = { IsItemInRange = function(id) if world.items then return world.d <= world.items[id] end return nil end }
GetBuildInfo = function() return "1.60.1", "69913", "", 16001 end
SOUNDKIT, STANDARD_TEXT_FONT, SlashCmdList = {}, "font", {}
PlaySound = function() world.sounds = (world.sounds or 0) + 1 end
UIParent = object()
UIParent.GetCenter = function() return 400, 400 end

local function find(name) for i, m in ipairs(macros) do if m.name == name then return i end end return 0 end
local function macroGuard() assert(not combat, "a macro call was made in combat") end
GetMacroIndexByName = function(n) return find(n) end
GetMacroBody = function(i) return macros[i] and macros[i].body end
CreateMacro = function(n, _, body) macroGuard() assert(#n <= 16, "macro name too long") macros[#macros + 1] = { name = n, body = body } return #macros end
EditMacro = function(i, _, _, body) macroGuard() assert(#body <= 255, "macro body too long") macros[i].body = body end
DeleteMacro = function(i) macroGuard() table.remove(macros, i) end

print = function(...) printed[#printed + 1] = table.concat({ ... }, " ") end
local function said(s) for _, l in ipairs(printed) do if l:find(s, 1, true) then return true end end return false end
local function fire(event, ...) for _, f in ipairs(frames) do if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end end end
local function slash(msg) SlashCmdList.FOREVERDEADZONE(msg) runTimers() end

local function session(sv, macrosLate)
    frames, timers, tickers, printed = {}, {}, {}, {}
    ForeverDeadZoneDB, ForeverDeadZoneBar = sv, nil
    assert(loadfile("ForeverDeadZone.lua"))("ForeverDeadZone")
    if not macrosLate then fire("UPDATE_MACROS") end
    fire("PLAYER_LOGIN")
    if macrosLate then fire("UPDATE_MACROS") end
    runTimers()
    return ForeverDeadZoneDB
end
local function caption() tick() return ForeverDeadZoneBar.text.textValue end

-- 1. The four states, from the measured checks alone (no item check answers).
macros, world = {}, { target = "hostile", d = 20, shoot = true }
local db = session(nil)
assert(caption() == "IN RANGE  8-28 yd", caption())
world.d, world.shoot = 32, true
assert(caption() == "IN RANGE  28-35 yd", caption())
world.d, world.shoot = 40, false
assert(caption() == "TOO FAR  > 28 yd", caption())
world.d, world.shoot = 6, false
assert(caption() == "DEAD ZONE  < 8 yd", caption())

-- 2. A main-hand swing means melee is landing; it lapses a swing-and-a-bit later.
now = 100
fire("PLAYER_SWING", 2.0, 0)
assert(caption() == "MELEE  < 8 yd", caption())
fire("PLAYER_SWING", 2.0, 2)                 -- a ranged swing proves nothing about melee
now = 103
assert(caption() == "DEAD ZONE  < 8 yd", "melee should lapse: " .. caption())

-- 3. When item checks answer, the bracket tightens and the 5 yard check decides melee.
world.items = { [42732] = 3, [37727] = 5, [34368] = 8, [32321] = 10, [33069] = 15, [10645] = 20, [24268] = 25,
                [835] = 30, [24269] = 35, [28767] = 40, [23836] = 45 }
world.d, world.shoot = 22, true
assert(caption() == "IN RANGE  20-25 yd", caption())
world.d, world.shoot = 4, false
assert(caption() == "MELEE  3-5 yd", caption())
world.d = 7
assert(caption() == "DEAD ZONE  5-8 yd", caption())
world.items = nil

-- 4. No target, a friendly target, or no ranged weapon: nothing shown, no errors.
world.target = nil
tick() assert(ForeverDeadZoneBar.shown == false, "bar should hide without a target")
world.target = "friendly"
tick() assert(ForeverDeadZoneBar.shown == false, "bar should hide on a friendly target")
world.target, world.shoot = "hostile", nil
tick() assert(ForeverDeadZoneBar.shown == false, "bar should hide when the client will not answer")
world.shoot, world.d = true, 20

-- 5. The warning sound is off unless asked for, and plays on ENTERING the dead zone only.
world.sounds = 0
caption() world.d, world.shoot = 6, false caption()
assert(world.sounds == 0, "sound must default to off")
slash("sound")
world.d, world.shoot = 20, true caption()
world.d, world.shoot = 6, false caption() caption()
assert(world.sounds == 1, "sound should play once per entry, got " .. world.sounds)

-- 6. Settings macro: nothing is written unless the player opts in; a hint says why.
assert(#macros == 0, "a macro appeared without opting in")
assert(said("/dz keep on"), "player was not told settings will be forgotten")
slash("scale 2")
slash("keep on")
assert(#macros == 1 and macros[1].body:match("^/dz store v=1;"), "macro not written")
assert(macros[1].body:find("s=2.00", 1, true), macros[1].body)

-- 7. Restart with EMPTY saved variables (the beta bug): everything comes back.
db = session(nil)
assert(db.scale == 2 and db.sound == true and db.keep == true, "settings were not restored from the macro")
assert(said("restored from your settings macro"), "restore was not announced")
assert(ForeverDeadZoneBar.w == 300, "restored scale was not applied to the bar")

-- 7b. The client may return the body with a trailing newline; it must still be read.
macros[1].body = macros[1].body .. "\n"
db = session(nil)
assert(db.scale == 2 and said("restored from your settings macro"), "a trailing newline broke the restore")
macros[1].body = macros[1].body:gsub("%s+$", "")

-- 8. Macro list arriving AFTER login: restored then, and never overwritten before it is read.
db = session(nil, true)
assert(db.scale == 2, "late macro list: settings lost")
assert(macros[1].body:find("s=2.00", 1, true), "defaults were written over a good macro")

-- 9. A real SavedVariables table wins over the macro.
db = session({ v = 2, x = 5, y = 5, scale = 1, locked = true, sound = false, hideNoTarget = true, distance = true })
assert(db.scale == 1 and not said("restored"), "a loaded save must not be replaced")

-- 10. No macro calls in combat; the write happens when combat ends.
db = session(nil)
combat = true
slash("scale 3")
assert(macros[1].body:find("s=2.00", 1, true), "macro was changed during combat")
combat = false
fire("PLAYER_REGEN_ENABLED")
assert(macros[1].body:find("s=3.00", 1, true), "change was not saved after combat")

-- 11. A hand-edited body is ignored, not applied.
macros[1].body = "/dz store v=1;x=oops"
db = session(nil)
assert(db.scale == 1.5, "a broken macro body must fall back to defaults")

-- 12. Opting out removes the macro.
slash("keep on") slash("keep off")
assert(#macros == 0, "macro should be deleted on opt-out")

-- 13. Not a hunter: the addon does nothing at all.
world.class = "PALADIN"
frames, SlashCmdList = {}, {}
assert(loadfile("ForeverDeadZone.lua"))("ForeverDeadZone")
assert(#frames == 0 and SlashCmdList.FOREVERDEADZONE == nil, "should not load for other classes")

io.write("dead zone: states, melee inference, item brackets, sound, and settings macro checks passed\n")
