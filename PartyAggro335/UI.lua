PartyAggro335UI = {}
local UI, L = PartyAggro335UI, PartyAggro335L
local colors = { safe = { 0.25, 0.9, 0.45 }, risk = { 1, 0.75, 0.15 },
    lost = { 1, 0.28, 0.25 }, unknown = { 0.65, 0.7, 0.75 } }
local labels = { safe = L.safe, risk = L.risk, lost = L.lost, unknown = L.unknown }
local function text(value) return tostring(value or "?"):gsub("|", "||") end
local function label(parent, width, x, y, size)
    local font = parent:CreateFontString(nil, "OVERLAY")
    font:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size or 12)
    font:SetJustifyH("LEFT"); font:SetWidth(width); font:SetHeight(18)
    font:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    return font
end

function UI.New(settings)
    local self = { settings = settings, rows = {} }
    local frame = CreateFrame("Frame", "PartyAggro335Panel", UIParent)
    self.frame = frame
    frame:SetWidth(530); frame:SetHeight(110); frame:SetClampedToScreen(true)
    frame:SetMovable(true); frame:EnableMouse(true); frame:RegisterForDrag("LeftButton")
    frame:SetFrameStrata("MEDIUM")
    frame:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16,
        edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    frame:SetBackdropColor(0.035, 0.045, 0.06, 0.91)
    frame:SetBackdropBorderColor(0.35, 0.43, 0.53, 1)
    frame:SetScript("OnDragStart", function() if not self.settings.locked then frame:StartMoving() end end)
    frame:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        local point, _, relativePoint, x, y = frame:GetPoint(1)
        self.settings.position = { point = point, relativePoint = relativePoint, x = x, y = y }
    end)
    self.title = label(frame, 460, 12, -8, 13)
    self.title:SetText(L.title)
    self.title:SetTextColor(0.65, 0.82, 1)
    label(frame, 183, 12, -33):SetText(L.mob)
    label(frame, 132, 199, -33):SetText(L.target)
    label(frame, 145, 335, -33):SetText(L.threat)
    label(frame, 40, 485, -33):SetText(L.hp)
    self.empty = label(frame, 500, 12, -58)
    self.empty:SetText(L.empty)
    self.footer = label(frame, 505, 12, -88, 10)
    self.footer:SetTextColor(0.65, 0.7, 0.76)
    self.Apply = function()
        frame:SetScale(self.settings.scale)
        frame:ClearAllPoints()
        local pos = self.settings.position
        frame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
    end
    self.Apply()
    frame:Hide()

    function self:MakeRow(index)
        local row = CreateFrame("Frame", nil, frame)
        row:SetWidth(506); row:SetHeight(22)
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -55 - (index - 1) * 23)
        row:EnableMouse(true)
        row.background = row:CreateTexture(nil, "BACKGROUND")
        row.background:SetAllPoints(row)
        row.selection = CreateFrame("Frame", nil, row)
        row.selection:SetAllPoints(row)
        row.selection:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 8 })
        row.selection:SetBackdropBorderColor(1, 0.82, 0.2, 1)
        row.selection:Hide()
        row.pointer = label(row, 12, 2, -2)
        row.pointer:SetText(">"); row.pointer:SetTextColor(1, 0.82, 0.2)
        row.pointer:Hide()
        row.enemy = label(row, 171, 12, -2)
        row.victim = label(row, 132, 187, -2)
        row.threat = label(row, 145, 323, -2)
        row.health = label(row, 40, 473, -2)
        row:SetScript("OnEnter", function()
            local data = row.data
            if not data then return end
            GameTooltip:SetOwner(row, "ANCHOR_LEFT")
            GameTooltip:AddLine(text(data.name) .. " #" .. data.serial, 1, 1, 1)
            if row.isCurrent then GameTooltip:AddLine(L.currentTarget, 1, 0.82, 0.2) end
            GameTooltip:AddLine(L.tooltip, 0.7, 0.75, 0.8, true)
            GameTooltip:AddLine("GUID: " .. text(data.guid), 0.7, 0.75, 0.8, true)
            local sources = { target = L.actual, threat = L.leader, melee = L.melee }
            if data.targetSource then GameTooltip:AddLine(sources[data.targetSource] or L.missing, 0.85, 0.8, 0.55, true) end
            local threatSources = { plate = L.plate, melee = L.observed }
            GameTooltip:AddLine(threatSources[data.threatSource] or (not data.hasThreat and L.missing or L.percent), 0.7, 0.75, 0.8, true)
            if data.stale then GameTooltip:AddLine(L.old, 0.85, 0.65, 0.4) end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        self.rows[index] = row
        return row
    end

    function self:Render(data, preview, visible, currentGUID)
        self.data, self.preview, self.visible = data, preview, visible
        if not visible then frame:Hide(); return end
        frame:Show()
        self.title:SetText(L.title .. (preview and (" — " .. L.preview) or ""))
        local count = math.min(#data, self.settings.maxRows)
        local selectedGUID = preview and data[1] and data[1].guid or currentGUID
        local selectedIndex
        if selectedGUID then
            for index, value in ipairs(data) do
                if value.guid == selectedGUID then selectedIndex = index; break end
            end
        end
        for index = 1, count do
            -- Keep the selected enemy visible even when it is below the row limit.
            -- Leave the model's threat ordering and GUID identities untouched.
            local dataIndex = index
            if index == count and selectedIndex and selectedIndex > count then dataIndex = selectedIndex end
            local value = data[dataIndex]
            local row = self.rows[index] or self:MakeRow(index)
            row.data = value
            row.isCurrent = selectedGUID ~= nil and value.guid == selectedGUID
            if row.isCurrent then row.selection:Show(); row.pointer:Show()
            else row.selection:Hide(); row.pointer:Hide() end
            local color = colors[value.status] or colors.unknown
            row.background:SetTexture(color[1], color[2], color[3], index % 2 == 0 and 0.11 or 0.18)
            local marker = ""
            if value.marker and value.marker >= 1 and value.marker <= 8 then
                marker = string.format("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%d:14|t ", value.marker)
            end
            row.enemy:SetText(marker .. text(value.name) .. " #" .. value.serial)
            if row.isCurrent then row.enemy:SetTextColor(1, 0.86, 0.3)
            else row.enemy:SetTextColor(0.92, 0.94, 0.98) end
            local inferred = value.targetSource and value.targetSource ~= "target"
            row.victim:SetText((inferred and "~" or "") .. text(value.targetName))
            row.victim:SetTextColor(0.9, 0.9, 0.92)
            local percent = value.percent and string.format("%.0f%% ", value.percent) or "? "
            row.threat:SetText(percent .. (value.threatSource == "melee" and "~" or "") .. labels[value.status])
            row.threat:SetTextColor(color[1], color[2], color[3])
            row.health:SetText(value.hp and string.format("%.0f%%", value.hp) or "?")
            row.health:SetTextColor(0.75, 0.8, 0.86)
            row:Show()
        end
        for index = count + 1, #self.rows do
            local row = self.rows[index]
            row:Hide(); row.data = nil; row.isCurrent = false
            row.selection:Hide(); row.pointer:Hide()
        end
        if count == 0 then self.empty:Show() else self.empty:Hide() end
        local height = 82 + math.max(1, count) * 23
        frame:SetHeight(height)
        self.footer:ClearAllPoints(); self.footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 7)
        self.footer:SetText(#data > count and string.format(L.overflow, #data - count) or L.limited)
    end

    function self:UpdateTarget(guid)
        -- Target changes (including native Tab) should not wait for the scan timer.
        if self.data then self:Render(self.data, self.preview, self.visible, guid) end
    end
    return self
end
