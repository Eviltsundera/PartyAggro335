PartyAggro335Addon = {}
local Addon, Core, L = PartyAggro335Addon, PartyAggro335Core, PartyAggro335L
local band = bit.band
local flags = {
    group = bit.bor(COMBATLOG_OBJECT_AFFILIATION_MINE or 1, COMBATLOG_OBJECT_AFFILIATION_PARTY or 2,
        COMBATLOG_OBJECT_AFFILIATION_RAID or 4),
    friendly = COMBATLOG_OBJECT_REACTION_FRIENDLY or 16,
    npcControl = COMBATLOG_OBJECT_CONTROL_NPC or 512,
    types = bit.bor(COMBATLOG_OBJECT_TYPE_NPC or 2048, COMBATLOG_OBJECT_TYPE_PET or 4096,
        COMBATLOG_OBJECT_TYPE_GUARDIAN or 8192),
}
local attackEvents = {
    SWING_DAMAGE = true, SWING_MISSED = true, RANGE_DAMAGE = true, RANGE_MISSED = true,
    SPELL_DAMAGE = true, SPELL_MISSED = true, SPELL_PERIODIC_DAMAGE = true, SPELL_PERIODIC_MISSED = true,
    SPELL_INTERRUPT = true, SPELL_DISPEL = true, SPELL_CAST_START = true, SPELL_CAST_SUCCESS = true,
    DAMAGE_SHIELD = true, DAMAGE_SHIELD_MISSED = true, DAMAGE_SPLIT = true, SPELL_INSTAKILL = true,
}
local deathEvents = { UNIT_DIED = true, UNIT_DESTROYED = true, PARTY_KILL = true }
local function message(value)
    DEFAULT_CHAT_FRAME:AddMessage("|cff88bbffPartyAggro335:|r " .. value)
end
local function defaults()
    return { maxRows = 12, scale = 1, locked = true, hidden = false, arrows = true, arrowSize = 36,
        position = { point = "RIGHT", relativePoint = "RIGHT", x = -25, y = 0 } }
end
local function settings(saved)
    local value = defaults()
    if type(saved) ~= "table" then return value end
    if type(saved.maxRows) == "number" then value.maxRows = math.floor(math.max(5, math.min(30, saved.maxRows))) end
    if type(saved.scale) == "number" then value.scale = math.max(0.6, math.min(1.6, saved.scale)) end
    value.locked, value.hidden = saved.locked ~= false, saved.hidden == true
    value.arrows = saved.arrows ~= false
    if type(saved.arrowSize) == "number" then value.arrowSize = math.max(16, math.min(64, saved.arrowSize)) end
    local anchors = { TOP = true, TOPLEFT = true, TOPRIGHT = true, LEFT = true, CENTER = true,
        RIGHT = true, BOTTOM = true, BOTTOMLEFT = true, BOTTOMRIGHT = true }
    local pos = saved.position
    if type(pos) == "table" and anchors[pos.point] and anchors[pos.relativePoint]
        and type(pos.x) == "number" and type(pos.y) == "number" then
        value.position = { point = pos.point, relativePoint = pos.relativePoint, x = pos.x, y = pos.y }
    end
    return value
end

function Addon:IsEnemy(unitFlags)
    return type(unitFlags) == "number" and band(unitFlags, flags.friendly) == 0
        and band(unitFlags, flags.npcControl) ~= 0 and band(unitFlags, flags.types) ~= 0
end
function Addon:IsGroup(guid, unitFlags)
    return self.groupGUIDs[guid] or (type(unitFlags) == "number" and band(unitFlags, flags.group) ~= 0)
end

function Addon:RefreshGroup()
    self.groupGUIDs, self.groupUnits, self.scanUnits = {}, {}, {}
    local function member(unit)
        local guid = UnitGUID(unit)
        if guid and not self.groupGUIDs[guid] then
            self.groupGUIDs[guid] = true
            self.groupUnits[#self.groupUnits + 1] = unit
        end
        self.scanUnits[#self.scanUnits + 1] = unit .. "target"
    end
    member("player"); member("pet")
    local raid = GetNumRaidMembers()
    if raid > 0 then
        for index = 1, raid do member("raid" .. index); member("raidpet" .. index) end
    else
        for index = 1, GetNumPartyMembers() do member("party" .. index); member("partypet" .. index) end
    end
    local extra = { "target", "targettarget", "focus", "focustarget", "mouseover", "mouseovertarget",
        "boss1", "boss2", "boss3", "boss4" }
    for _, unit in ipairs(extra) do self.scanUnits[#self.scanUnits + 1] = unit end
    self.playerGUID = UnitGUID("player")
end

function Addon:GroupInCombat()
    for _, unit in ipairs(self.groupUnits) do if UnitAffectingCombat(unit) then return true end end
    return false
end

-- Original 3.3.5a CLEU has eight base args (no hideCaster or raidFlags).
function Addon:CombatLog(timestamp, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
    if deathEvents[event] then self.model:Remove(dstGUID); return end
    local aggression = attackEvents[event]
    if event == "SPELL_AURA_APPLIED" or event == "SPELL_AURA_REFRESH" then
        aggression = select(4, ...) == "DEBUFF"
    end
    if not aggression then return end
    local now = GetTime()
    if self:IsEnemy(srcFlags) and self:IsGroup(dstGUID, dstFlags) then
        local enemy = self.model:Touch(srcGUID, srcName, now)
        if enemy and (event == "SWING_DAMAGE" or event == "SWING_MISSED") then
            self.model:SetMeleeVictim(srcGUID, dstGUID, dstName, now)
        end
        self.lastCombatActivity = now
    elseif self:IsGroup(srcGUID, srcFlags) and self:IsEnemy(dstFlags) then
        self.model:Touch(dstGUID, dstName, now)
        if event == "SPELL_INSTAKILL" then self.model:Remove(dstGUID) end
        self.lastCombatActivity = now
    end
end

local function detailed(unit, reference)
    -- GUID lookup is opportunistic; some old clients/servers only resolve unit tokens.
    local ok, tanking, status, percent, rawPercent, value = pcall(UnitDetailedThreatSituation, unit, reference)
    if not ok or type(status) ~= "number" or status < 0 or status > 3 then return nil end
    return { isTanking = tanking == true or tanking == 1, status = status,
        percent = type(percent) == "number" and percent or nil, rawPercent = rawPercent, value = value }
end

function Addon:EngagedWithGroup(unit, guid)
    if self.model.enemies[guid] then return true end
    local victimGUID = UnitGUID(unit .. "target")
    if victimGUID and self.groupGUIDs[victimGUID] then return true end
    if detailed("player", unit) then return true end
    for _, groupUnit in ipairs(self.groupUnits) do
        if UnitAffectingCombat(groupUnit) and detailed(groupUnit, unit) then return true end
    end
    return false
end

function Addon:Scan(now)
    local units, active = {}, self:GroupInCombat()
    for _, unit in ipairs(self.scanUnits) do
        if UnitExists(unit) and UnitCanAttack("player", unit) and not UnitIsPlayer(unit) then
            local guid = UnitGUID(unit)
            if guid and UnitIsDead(unit) then
                self.model:Remove(guid)
            elseif guid and self:EngagedWithGroup(unit, guid)
                and (UnitAffectingCombat(unit) or (active and self.model.enemies[guid])) then
                self.model:Touch(guid, UnitName(unit), now)
                -- Prefer a token with a currently resolvable target.
                if not units[guid] or UnitExists(unit .. "target") then units[guid] = unit end
            end
        end
    end
    for guid, enemy in pairs(self.model.enemies) do
        local unit = units[guid]
        local observation = {}
        local reference = unit or guid
        observation.threat = detailed("player", reference)
        if not observation.threat and unit then observation.threat = detailed("player", guid) end
        if unit then
            local health, maximum = UnitHealth(unit), UnitHealthMax(unit)
            if maximum and maximum > 0 then observation.hp = 100 * health / maximum end
            observation.marker = GetRaidTargetIndex(unit)
            if UnitExists(unit .. "target") then
                observation.targetGUID = UnitGUID(unit .. "target")
                observation.targetName = UnitName(unit .. "target")
                observation.targetSource = "target"
                observation.targetInGroup = self.groupGUIDs[observation.targetGUID] == true
            end
        end
        if not observation.targetGUID then
            if observation.threat and observation.threat.isTanking then
                observation.targetGUID, observation.targetName = self.playerGUID, UnitName("player")
                observation.targetSource = "threat"
            else
                for _, groupUnit in ipairs(self.groupUnits) do
                    local threat = detailed(groupUnit, reference)
                    if threat and threat.isTanking then
                        observation.targetGUID, observation.targetName = UnitGUID(groupUnit), UnitName(groupUnit)
                        observation.targetSource = "threat"
                        break
                    end
                end
            end
        end
        self.model:SetObservation(guid, observation, now)
    end
    self.model:Prune(now)
    if active then self.lastCombatActivity = now end
    if not active and now - self.lastCombatActivity > 5 then self.model:Clear() end
    if self.plates then self.plates:Update(now, units) end
    local rows = self.preview and Core.Preview() or self.model:Rows(now, self.playerGUID)
    self.ui:Render(rows, self.preview, not self.config.hidden and
        (self.preview or not self.config.locked or active or #rows > 0), UnitGUID("target"))
end

function Addon:Command(input)
    local command, argument = (input or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = command:lower()
    if command == "show" then self.config.hidden = false; self.config.locked = false
    elseif command == "hide" then self.config.hidden = true
    elseif command == "lock" then self.config.locked = true; message(L.locked)
    elseif command == "unlock" then self.config.locked = false; self.config.hidden = false; message(L.unlocked)
    elseif command == "test" then
        self.preview = not self.preview; self.config.hidden = false
        message(self.preview and L.demoOn or L.demoOff)
    elseif command == "clear" then self.model:Clear(); message(L.cleared)
    elseif command == "arrows" then
        local action, value = argument:match("^(%S+)%s*(.-)$")
        if action == "on" then self.config.arrows = true; self.plates.test = false; message(L.arrowsOn)
        elseif action == "off" then self.config.arrows = false; self.plates.test = false; message(L.arrowsOff)
        elseif action == "test" then self.config.arrows = true; self.plates.test = not self.plates.test; message(L.arrowsTest)
        elseif action == "size" and tonumber(value) and tonumber(value) >= 16 and tonumber(value) <= 64 then self.config.arrowSize = tonumber(value); message(L.saved)
        else message(L.arrowsHelp) end
    elseif command == "debug" then
        local data, exact, inferred = self.model:Rows(GetTime(), self.playerGUID), 0, 0
        for _, row in ipairs(data) do
            if row.hasThreat then exact = exact + 1 end
            if row.targetSource == "melee" then inferred = inferred + 1 end
        end
        message(string.format(L.debug, #data, exact, inferred, self.plates.visible, self.plates.identified, self.plates.arrows))
    elseif command == "reset" then
        self.config = defaults(); PartyAggro335DB = self.config; self.ui.settings = self.config
        self.ui.Apply(); message(L.reset)
    elseif command == "rows" then
        local value = tonumber(argument)
        if not value or value < 5 or value > 30 or value ~= math.floor(value) then message(L.badRows); return end
        self.config.maxRows = value; message(L.saved)
    elseif command == "scale" then
        local value = tonumber(argument)
        if not value or value < 0.6 or value > 1.6 then message(L.badScale); return end
        self.config.scale = value; self.ui.Apply(); message(L.saved)
    else message(L.help) end
    self:Scan(GetTime())
end

function Addon:Init()
    self.config = settings(PartyAggro335DB); PartyAggro335DB = self.config
    self.model = Core.New(); self.lastCombatActivity = GetTime() - 6
    self:RefreshGroup()
    self.ui = PartyAggro335UI.New(self.config)
    self.plates = PartyAggro335Nameplates.New(self)
    SLASH_PARTYAGGRO3351 = "/pa"; SLASH_PARTYAGGRO3352 = "/partyaggro"
    SlashCmdList.PARTYAGGRO335 = function(input) self:Command(input) end
    local events = { "COMBAT_LOG_EVENT_UNFILTERED", "PARTY_MEMBERS_CHANGED", "RAID_ROSTER_UPDATE",
        "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT",
        "PLAYER_FOCUS_CHANGED", "UNIT_TARGET", "UNIT_THREAT_LIST_UPDATE", "UNIT_THREAT_SITUATION_UPDATE",
        "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }
    for _, event in ipairs(events) do self.frame:RegisterEvent(event) end
    local elapsed = 0
    self.frame:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed >= 0.25 then elapsed = 0; self:Scan(GetTime()) end
    end)
    if select(4, GetBuildInfo()) ~= 30300 then message(L.wrongClient) end
    message(L.ready)
end

Addon.frame = CreateFrame("Frame")
Addon.frame:RegisterEvent("ADDON_LOADED")
Addon.frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if (...) == "PartyAggro335" and not Addon.model then Addon:Init() end
        return
    end
    if not Addon.model then return end
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then Addon:CombatLog(...)
    elseif event == "PLAYER_TARGET_CHANGED" then Addon.ui:UpdateTarget(UnitGUID("target"))
    elseif event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then Addon:RefreshGroup()
    elseif event == "PLAYER_ENTERING_WORLD" then
        Addon.model:Clear(); Addon:RefreshGroup(); Addon.lastCombatActivity = GetTime() - 6
    end
end)
