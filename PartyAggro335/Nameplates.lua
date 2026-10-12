-- Original 3.3.5a nameplates are anonymous WorldFrame children, not nameplateN units.
-- Never map mobs by name alone: full-health packs frequently have identical names.
PartyAggro335Nameplates = {}
local Plates = PartyAggro335Nameplates
local function shown(region) return region and region.IsShown and region:IsShown() end
local function objects(frame, method)
    if not frame[method] then return {} end
    return { frame[method](frame) }
end
local function regionType(region, kind)
    return region and region.GetObjectType and region:GetObjectType() == kind
end

function Plates.New(addon)
    return setmetatable({ addon = addon, tracked = {}, lastDiscovery = -10,
        visible = 0, identified = 0, arrows = 0 }, { __index = Plates })
end

function Plates:Identify(frame)
    local regions, children = objects(frame, "GetRegions"), objects(frame, "GetChildren")
    local border = regions[2]
    local texture = border and border.GetTexture and border:GetTexture()
    if type(texture) ~= "string" or not texture:lower():find("nameplate%-border") then return nil end
    if not regionType(regions[7], "FontString") or not children[1]
        or not children[1].GetValue or not children[1].GetMinMaxValues then return nil end
    local data = { frame = frame, glow = regions[1], name = regions[7], highlight = regions[6],
        marker = regions[10], health = children[1], readyAt = GetTime() + 0.15 }
    if frame.HookScript then
        frame:HookScript("OnHide", function()
            data.guid = nil; data.readyAt = GetTime() + 0.15
            if data.arrow then data.arrow:Hide() end
        end)
        frame:HookScript("OnShow", function()
            data.guid = nil; data.readyAt = GetTime() + 0.15
            if data.arrow then data.arrow:Hide() end
        end)
    end
    return data
end

function Plates:Discover(now)
    if not WorldFrame or now - self.lastDiscovery < 1 then return end
    self.lastDiscovery = now
    for _, frame in ipairs(objects(WorldFrame, "GetChildren")) do
        if not self.tracked[frame] then
            local data = self:Identify(frame)
            if data then self.tracked[frame] = data end
        end
    end
end

function Plates:Snapshot(data)
    local minimum, maximum = data.health:GetMinMaxValues()
    local current = data.health:GetValue()
    local marker
    if shown(data.marker) and data.marker.GetTexCoord then
        local u, v = data.marker:GetTexCoord()
        if type(u) == "number" and type(v) == "number" then
            -- The original atlas is 4x4; its first two rows contain the eight icons.
            local column, line = math.floor(u * 4 + 0.5), math.floor(v * 4 + 0.5)
            if column >= 0 and column < 4 and line >= 0 and line < 2
                and math.abs(u - column / 4) < 0.01 and math.abs(v - line / 4) < 0.01 then
                marker = line * 4 + column + 1
            end
        end
    end
    local status
    if shown(data.glow) and data.glow.GetVertexColor and GetThreatStatusColor then
        local r, g, b = data.glow:GetVertexColor()
        for value = 1, 3 do
            local er, eg, eb = GetThreatStatusColor(value)
            if math.abs(r - er) < 0.08 and math.abs(g - eg) < 0.08 and math.abs(b - eb) < 0.08 then
                status = value; break
            end
        end
    end
    return { name = data.name:GetText(), current = current, maximum = maximum, marker = marker,
        status = status, hp = maximum and maximum > 0 and 100 * current / maximum or nil }
end

local function unitMatches(snapshot, unit)
    return type(snapshot.name) == "string" and snapshot.name ~= ""
        and UnitExists(unit) and UnitCanAttack("player", unit) and not UnitIsPlayer(unit)
        and snapshot.name == UnitName(unit) and snapshot.maximum == UnitHealthMax(unit)
        and snapshot.current == UnitHealth(unit)
        and (not snapshot.marker or snapshot.marker == GetRaidTargetIndex(unit))
end

function Plates:Bind(visible, units)
    -- Prefer explicit raid icons, the actual highlighted mouseover, or the single
    -- unfaded target. Health matching is accepted only if both sides are unique.
    for _, data in ipairs(visible) do
        local snapshot = data.snapshot
        local candidate, count = nil, 0
        if snapshot.marker then
            for guid, unit in pairs(units) do
                if GetRaidTargetIndex(unit) == snapshot.marker and snapshot.name == UnitName(unit) then
                    candidate, count = guid, count + 1
                end
            end
        end
        if count == 1 then data.guid = candidate end
    end
    local function pointUnit(unit, predicate)
        local guid = UnitGUID(unit)
        if not guid or (not self.addon.model.enemies[guid] and not self.test) then return end
        local match, count = nil, 0
        for _, data in ipairs(visible) do
            if predicate(data) and unitMatches(data.snapshot, unit) then match, count = data, count + 1 end
        end
        if count == 1 then match.guid = guid end
    end
    pointUnit("mouseover", function(data) return shown(data.highlight) end)
    pointUnit("target", function(data) return data.frame.GetAlpha and data.frame:GetAlpha() == 1 end)
    for _, data in ipairs(visible) do
        if not data.guid then
            local candidate, count = nil, 0
            for guid, unit in pairs(units) do
                if unitMatches(data.snapshot, unit) then candidate, count = guid, count + 1 end
            end
            if count == 1 then
                local plateCount = 0
                for _, other in ipairs(visible) do
                    if unitMatches(other.snapshot, units[candidate]) then plateCount = plateCount + 1 end
                end
                if plateCount == 1 then data.guid = candidate end
            end
        end
        if data.guid and self.addon.model.enemies[data.guid] and data.snapshot.name ~= self.addon.model.enemies[data.guid].name then
            data.guid = nil
        end
    end
    -- Competing bindings are ambiguous; do not choose whichever was iterated last.
    local owners, duplicates = {}, {}
    for _, data in ipairs(visible) do
        if data.guid then
            if owners[data.guid] then duplicates[data.guid] = true else owners[data.guid] = data end
        end
    end
    for _, data in ipairs(visible) do if duplicates[data.guid] then data.guid = nil end end
end

function Plates:Arrow(data, visible, approximate)
    if not data.arrow and visible then
        data.arrow = CreateFrame("Frame", nil, data.frame)
        data.arrow:EnableMouse(false)
        if data.frame.GetFrameLevel then data.arrow:SetFrameLevel(data.frame:GetFrameLevel() + 15) end
        data.texture = data.arrow:CreateTexture(nil, "OVERLAY")
        data.texture:SetAllPoints(data.arrow)
        data.texture:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
    end
    if not data.arrow then return end
    if not visible then data.arrow:Hide(); return end
    local size = self.addon.config.arrowSize
    data.arrow:SetWidth(size); data.arrow:SetHeight(size)
    data.arrow:ClearAllPoints()
    data.arrow:SetPoint("BOTTOM", data.health, "TOP", 0, 25)
    if approximate then data.texture:SetVertexColor(1, 0.72, 0.15, 1)
    else data.texture:SetVertexColor(1, 0.18, 0.12, 1) end
    data.arrow:Show()
end

function Plates:Update(now, units)
    self:Discover(now)
    local visible = {}
    self.visible, self.identified, self.arrows = 0, 0, 0
    for frame, data in pairs(self.tracked) do
        if frame:IsShown() and now >= data.readyAt then
            data.snapshot = self:Snapshot(data)
            visible[#visible + 1] = data
        else self:Arrow(data, false) end
    end
    self:Bind(visible, units)
    for _, data in ipairs(visible) do
        self.visible = self.visible + 1
        if data.guid and self.addon.model.enemies[data.guid] then
            self.identified = self.identified + 1
            self.addon.model:SetPlateObservation(data.guid, { hp = data.snapshot.hp, status = data.snapshot.status }, now)
        end
    end
    local rowsByGUID = {}
    for _, row in ipairs(self.addon.model:Rows(now, self.addon.playerGUID)) do rowsByGUID[row.guid] = row end
    for _, data in ipairs(visible) do
        local row = data.guid and rowsByGUID[data.guid]
        local test = self.test and data.guid == UnitGUID("target")
        local arrow = self.addon.config.arrows and (test or (row and row.offYou == true))
        -- A current native tanking glow contradicts old melee evidence.
        if not test and row and row.offYouSource == "melee" and data.snapshot.status and data.snapshot.status >= 2 then arrow = false end
        self:Arrow(data, arrow, row and row.offYouSource == "melee")
        if arrow then self.arrows = self.arrows + 1 end
    end
end
