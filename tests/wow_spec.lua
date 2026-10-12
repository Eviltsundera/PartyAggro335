-- Mock only original 3.3.5a API. Unsupported modern calls cannot silently pass.
local count = 0
local function eq(actual, expected, name)
    count = count + 1
    assert(actual == expected, name .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function twoBits(a, b, isOr)
    local result, power = 0, 1
    while a > 0 or b > 0 do
        local left, right = a % 2, b % 2
        if (isOr and (left == 1 or right == 1)) or (not isOr and left == 1 and right == 1) then result = result + power end
        a, b, power = math.floor(a / 2), math.floor(b / 2), power * 2
    end
    return result
end
bit = { band = function(a, b) return twoBits(a, b, false) end,
    bor = function(...)
        local result = 0
        for index = 1, select("#", ...) do result = twoBits(result, select(index, ...), true) end
        return result
    end }
local Frame = {}; Frame.__index = Frame
local noopMethods = { "SetClampedToScreen", "SetMovable", "EnableMouse", "RegisterForDrag",
    "SetFrameStrata", "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor", "SetFont",
    "SetJustifyH", "SetTextColor", "SetAllPoints", "StartMoving", "StopMovingOrSizing", "SetOwner", "SetFrameLevel" }
for _, name in ipairs(noopMethods) do Frame[name] = function() end end
function Frame:SetWidth(v) self.width = v end
function Frame:SetHeight(v) self.height = v end
function Frame:SetScale(v) self.scale = v end
function Frame:SetText(v) self.text = v end
function Frame:SetTexture(...) self.color = { ... }; if type((...)) == "string" then self.texture = (...) end end
function Frame:GetTexture() return self.texture end
function Frame:SetVertexColor(...) self.vertex = { ... } end
function Frame:GetVertexColor() return unpack(self.vertex or { 1, 1, 1, 1 }) end
function Frame:SetTexCoord(...) self.coords = { ... } end
function Frame:GetTexCoord() return unpack(self.coords or { 0, 0, 0, 1, 1, 0, 1, 1 }) end
function Frame:GetText() return self.text end
function Frame:GetChildren() return unpack(self.children or {}) end
function Frame:GetRegions() return unpack(self.regions or {}) end
function Frame:GetObjectType() return self.kind end
function Frame:GetAlpha() return self.alpha or 1 end
function Frame:GetFrameLevel() return 1 end
function Frame:GetMinMaxValues() return self.minimum or 0, self.maximum or 100 end
function Frame:GetValue() return self.value or 100 end
function Frame:IsShown() return self.visible ~= false end
function Frame:HookScript(name, callback)
    self.hooks = self.hooks or {}; self.hooks[name] = self.hooks[name] or {}
    table.insert(self.hooks[name], callback)
end
function Frame:SetPoint(...) self.point = { ... } end
function Frame:GetPoint() return unpack(self.point or { "RIGHT", UIParent, "RIGHT", -25, 0 }) end
function Frame:ClearAllPoints() self.point = nil end
function Frame:RegisterEvent(event) self.events[event] = true end
function Frame:SetScript(name, callback) self.scripts[name] = callback end
function Frame:Show()
    local previous = self.visible; self.visible = true
    if previous == false and self.hooks then for _, hook in ipairs(self.hooks.OnShow or {}) do hook(self) end end
end
function Frame:Hide()
    local previous = self.visible; self.visible = false
    if previous ~= false and self.hooks then for _, hook in ipairs(self.hooks.OnHide or {}) do hook(self) end end
end
function Frame:AddLine(value) self.lines[#self.lines + 1] = value end
function Frame:CreateFontString() return CreateFrame("FontString") end
function Frame:CreateTexture() return CreateFrame("Texture") end
function CreateFrame(kind, name)
    local frame = setmetatable({ kind = kind, scripts = {}, events = {}, lines = {} }, Frame)
    if name then _G[name] = frame end
    return frame
end
UIParent = CreateFrame("Frame")
GameTooltip = CreateFrame("Tooltip")
local messages = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, value) messages[#messages + 1] = value end }
SlashCmdList = {}
local now, raidCount, partyCount, guidLookup = 100, 0, 2, false
local units, threats = {}, {}
local PLAYER, HEALER, DPS, A, B, C = "player-guid", "healer-guid", "dps-guid", "0xF130000001", "0xF130000002", "0xF130000003"
units.player = { guid = PLAYER, name = "Tank", player = true, combat = true }
units.party1 = { guid = HEALER, name = "Healer", player = true, combat = true }
units.party2 = { guid = DPS, name = "DPS", player = true, combat = true }
units.target = { guid = A, name = "Twin", enemy = true, combat = true, hp = 750, maxhp = 1000 }
units.targettarget = units.party1
units.playertarget = units.target
units.playertargettarget = units.targettarget
units.party2target = { guid = B, name = "Twin", enemy = true, combat = true, hp = 500, maxhp = 1000 }
units.party2targettarget = units.player
units.mouseover = { guid = "neutral", name = "Unpulled", enemy = true, combat = false, hp = 100, maxhp = 100 }
threats[A] = { [PLAYER] = { false, 0, 60, 66, 660 }, [HEALER] = { true, 3, 100, 100, 1000 } }
threats[B] = { [PLAYER] = { true, 2, 100, 100, 1000 } }
function GetTime() return now end
function GetLocale() return "ruRU" end
function GetBuildInfo() return "3.3.5", "12340", "", 30300 end
function GetNumRaidMembers() return raidCount end
function GetNumPartyMembers() return partyCount end
function UnitGUID(unit) return units[unit] and units[unit].guid end
function UnitName(unit) return units[unit] and units[unit].name end
function UnitExists(unit) return units[unit] ~= nil end
function UnitIsPlayer(unit) return units[unit] and units[unit].player end
function UnitCanAttack(_, unit) return units[unit] and units[unit].enemy end
function UnitAffectingCombat(unit) return units[unit] and units[unit].combat end
function UnitIsDead(unit) return units[unit] and units[unit].dead end
function UnitHealth(unit) return units[unit] and units[unit].hp or 0 end
function UnitHealthMax(unit) return units[unit] and units[unit].maxhp or 0 end
function GetRaidTargetIndex(unit) return unit == "target" and 8 or nil end
function GetThreatStatusColor(status)
    if status == 1 then return 1, 1, 0 elseif status == 2 then return 1, 0.6, 0 elseif status == 3 then return 1, 0, 0 end
    return 0.69, 0.69, 0.69
end
function UnitDetailedThreatSituation(unit, reference)
    local guid = UnitGUID(reference)
    if not guid then
        if not guidLookup then error("GUID lookup unsupported in this mock client") end
        guid = reference
    end
    local value = threats[guid] and threats[guid][UnitGUID(unit)]
    if value then return unpack(value) end
end
PartyAggro335DB = { maxRows = "bad", scale = "bad", position = { point = "NOT_AN_ANCHOR" } }
dofile(PROJECT_ROOT .. "/PartyAggro335/Locale.lua")
dofile(PROJECT_ROOT .. "/PartyAggro335/Core.lua")
dofile(PROJECT_ROOT .. "/PartyAggro335/UI.lua")
dofile(PROJECT_ROOT .. "/PartyAggro335/Nameplates.lua")
dofile(PROJECT_ROOT .. "/PartyAggro335/Main.lua")
local addon = PartyAggro335Addon
local function event(name, ...) addon.frame.scripts.OnEvent(addon.frame, name, ...) end
event("ADDON_LOADED", "OtherAddon")
eq(addon.model, nil, "only initialize for our addon")
event("ADDON_LOADED", "PartyAggro335")
eq(addon.config.maxRows, 12, "malformed SavedVariables defaults")
eq(addon.config.position.point, "RIGHT", "malformed anchor defaults")
eq(addon.frame.events.COMBAT_LOG_EVENT_UNFILTERED, true, "legacy CLEU registered")
eq(SLASH_PARTYAGGRO3351, "/pa", "slash command registered")
addon:Scan(now)
local rows = addon.model:Rows(now, PLAYER)
eq(#rows, 2, "discover different group targets")
eq(rows[1].guid, A, "problematic mob first")
eq(rows[1].targetName, "Healer", "live target read")
eq(rows[1].percent, 60, "native threat through unit token")
eq(rows[2].status, "risk", "status 2 highlighted")
eq(addon.model.enemies.neutral, nil, "do not add unpulled mouseover")
units.mouseover.combat = true
addon:Scan(now)
eq(addon.model.enemies.neutral, nil, "mouseover at outsider combat is not group engagement")
eq(addon.ui.frame.visible, true, "automatically show in combat")
eq(addon.ui.rows[1].enemy.text:find("#1", 1, true) ~= nil, true, "UI duplicate label")
eq(addon.ui.rows[1].threat.text, "60% Не на тебе", "Russian UI status")
local enemyFlags, groupFlags, outsiderFlags = 8 + 64 + 512 + 2048, 2 + 16 + 256 + 1024, 8 + 16 + 256 + 1024
event("COMBAT_LOG_EVENT_UNFILTERED", 5000, "SWING_DAMAGE", C, "Caster", enemyFlags, HEALER, "Healer", groupFlags, 150)
addon:Scan(now)
local c = addon.model.enemies[C]
eq(c ~= nil, true, "old eight-argument CLEU parsed")
local function rowFor(guid)
    for _, value in ipairs(addon.model:Rows(now, PLAYER)) do if value.guid == guid then return value end end
end
eq(rowFor(C).targetSource, "melee", "observed melee target marked approximate")
eq(rowFor(C).percent, nil, "unknown GUID threat not invented")
eq(rowFor(C).status, "lost", "recent healer hit provides approximate off-player status")
eq(rowFor(C).threatSource, "melee", "observed status does not pretend to be native threat")
event("COMBAT_LOG_EVENT_UNFILTERED", 5001, "SWING_DAMAGE", "outsider-mob", "Outsider fight", enemyFlags,
    "outsider-player", "Stranger", outsiderFlags, 100)
eq(addon.model.enemies["outsider-mob"], nil, "exclude unrelated fight")
event("COMBAT_LOG_EVENT_UNFILTERED", 5002, "SPELL_AURA_APPLIED", HEALER, "Healer", groupFlags,
    "buff-mob", "Not attacked", enemyFlags, 123, "Buff", 1, "BUFF")
eq(addon.model.enemies["buff-mob"], nil, "buff does not establish combat")
event("COMBAT_LOG_EVENT_UNFILTERED", 5003, "SPELL_AURA_APPLIED", DPS, "DPS", groupFlags,
    "cc-mob", "Crowd controlled", enemyFlags, 456, "Fear", 1, "DEBUFF")
eq(addon.model.enemies["cc-mob"] ~= nil, true, "debuff records engaged enemy")
event("COMBAT_LOG_EVENT_UNFILTERED", 5004, "SPELL_DAMAGE", C, "Caster", enemyFlags, DPS, "DPS", groupFlags,
    789, "Area damage", 4, 100)
eq(rowFor(C).targetName, "Healer", "AoE damage does not invent current target")
guidLookup = true
threats[C] = { [PLAYER] = { true, 3, 100, 100, 2000 } }
addon:Scan(now)
eq(rowFor(C).status, "safe", "optional native GUID query works when available")
eq(rowFor(C).targetSource, "threat", "threat-derived target marked inferred")
guidLookup = false
threats[A] = nil
addon:Scan(now)
eq(rowFor(A).status, "lost", "live healer target highlighted without percentage")
eq(rowFor(A).percent, nil, "live target does not fabricate zero percent")
event("COMBAT_LOG_EVENT_UNFILTERED", 5005, "UNIT_DIED", nil, nil, 0, C, "Caster", enemyFlags)
eq(addon.model.enemies[C], nil, "death removes combat-log enemy")
units.party2target.dead = true
addon:Scan(now)
eq(addon.model.enemies[B], nil, "dead unit token does not re-add enemy")
addon:Command("rows 99")
eq(addon.config.maxRows, 12, "reject oversized row request")
addon:Command("rows 5")
eq(addon.config.maxRows, 5, "rows setting")
addon:Command("scale 1.2")
eq(addon.ui.frame.scale, 1.2, "scale UI applied")
addon:Command("hide")
eq(addon.ui.frame.visible, false, "hide persists in combat")
addon:Command("test")
eq(addon.ui.frame.visible, true, "demo shows even when previously hidden")
eq(addon.ui.rows[3].threat.text, "? Нет данных", "demo unknown display")
addon.ui.rows[3].scripts.OnEnter()
eq(GameTooltip.visible, true, "row tooltip works")
addon.ui.rows[3].scripts.OnLeave()
eq(GameTooltip.visible, false, "row tooltip closes")
addon:Command("unlock")
addon.ui.frame.scripts.OnDragStop()
eq(type(PartyAggro335DB.position.x), "number", "position saved")
addon:Command("lock"); addon:Command("test")
units.player.combat, units.party1.combat, units.party2.combat, units.target.combat = false, false, false, false
now = 106
addon:Scan(now)
eq(#addon.model:Rows(now, PLAYER), 0, "clean up after group combat ends")
eq(addon.ui.frame.visible, false, "auto-hide after combat")
addon:Command("reset")
eq(PartyAggro335DB.scale, 1, "reset settings global")
addon:Command("test")
eq(addon.ui.settings, PartyAggro335DB, "UI follows new settings object")
units.raid1, units.raid2 = units.player, units.party1
raidCount = 2
addon:RefreshGroup()
eq(addon.groupGUIDs[PLAYER], true, "raid player membership")
local matches = 0
for _, unit in ipairs(addon.groupUnits) do if UnitGUID(unit) == PLAYER then matches = matches + 1 end end
eq(matches, 1, "deduplicate player in raid roster")
event("PLAYER_ENTERING_WORLD")
eq(#addon.model:Rows(now, PLAYER), 0, "zone entry clears enemy history")
print("WoW API and UI scenarios passed: " .. count)
PartyAggro335TestWorld = { units = units, SetTime = function(value) now = value end, GetTime = function() return now end }
