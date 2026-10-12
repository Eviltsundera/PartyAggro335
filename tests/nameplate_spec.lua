local count = 0
local function eq(actual, expected, name)
    count = count + 1
    assert(actual == expected, name .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local world, addon = PartyAggro335TestWorld, PartyAggro335Addon
local function makePlate(name, current, maximum, alpha)
    local frame = CreateFrame("Frame")
    frame.alpha = alpha
    frame.regions = {}
    for index = 1, 11 do frame.regions[index] = CreateFrame(index == 7 and "FontString" or "Texture") end
    frame.regions[2]:SetTexture("Interface\\Tooltips\\Nameplate-Border")
    frame.regions[7]:SetText(name)
    frame.regions[1]:Hide(); frame.regions[6]:Hide(); frame.regions[10]:Hide()
    local health = CreateFrame("StatusBar")
    health.value, health.maximum = current, maximum
    frame.children = { health }
    return frame
end
WorldFrame = CreateFrame("Frame")
world.SetTime(200)
local a, b, c = "arrow-mob-a", "arrow-mob-b", "arrow-mob-c"
local player, healer = UnitGUID("player"), UnitGUID("party1")
world.units.target = { guid = a, name = "Twin", hp = 100, maxhp = 100, enemy = true }
world.units.focus = { guid = b, name = "Twin", hp = 100, maxhp = 100, enemy = true }
world.units.mouseover = nil
addon.model:Clear(); addon.config.arrows = true; addon.config.arrowSize = 36
addon.model:Touch(a, "Twin", 200); addon.model:Touch(b, "Twin", 200)
addon.model:SetObservation(a, { targetGUID = healer, targetName = "Healer", targetSource = "target", targetInGroup = true }, 200)
addon.model:SetObservation(b, { threat = { status = 3, isTanking = true, percent = 100 },
    targetGUID = player, targetName = "Tank", targetSource = "target", targetInGroup = true }, 200)
local first, second = makePlate("Twin", 100, 100, 1), makePlate("Twin", 100, 100, 1)
WorldFrame.children = { first, second, CreateFrame("Frame") }
local plates = PartyAggro335Nameplates.New(addon)
local known = { [a] = "target", [b] = "focus" }
plates:Update(200, known)
eq(plates.visible, 0, "wait for recycled native regions to initialize")
world.SetTime(200.2); plates:Update(200.2, known)
eq(plates.visible, 2, "recognize original native nameplates only")
eq(plates.identified, 0, "identical names and health never choose an arbitrary mob")
eq(plates.arrows, 0, "ambiguous plate never gets a misleading arrow")
first.regions[10]:SetTexCoord(0.75, 0.5, 0.75, 1, 1, 0.5, 1, 1)
first.regions[10]:Show(); plates:Update(200.25, known)
eq(plates.tracked[first].guid, a, "existing raid marker disambiguates identical mobs")
eq(plates.tracked[second].guid, nil, "unmarked ambiguous twin stays unidentified")
first.regions[10]:Hide()
second.alpha = 0.5
world.units.mouseover = world.units.focus
second.regions[6]:Show()
plates:Update(200.3, known)
eq(plates.identified, 2, "target alpha and actual mouseover disambiguate twins")
eq(plates.tracked[first].guid, a, "selected plate GUID")
eq(plates.tracked[second].guid, b, "mouseover plate GUID")
eq(plates.arrows, 1, "only enemy targeting healer gets arrow")
eq(plates.tracked[first].arrow.visible, true, "off-tank pointer shown")
eq(plates.tracked[second].arrow, nil, "no pointer allocated for safe mob")
eq(plates.tracked[first].texture.texture, "Interface\\Buttons\\Arrow-Down-Up", "built-in 3.3.5 arrow texture")
eq(plates.tracked[first].texture.vertex[2], 0.18, "current evidence uses red pointer")
addon.config.arrows = false; plates:Update(200.4, known)
eq(plates.arrows, 0, "arrows switch off")
eq(plates.tracked[first].arrow.visible, false, "existing pointer hidden")
addon.config.arrows = true
addon.model:SetObservation(a, {}, 200.5)
first.regions[1]:Show(); first.regions[1]:SetVertexColor(1, 1, 0, 1)
plates:Update(200.5, known)
local function rowFor(guid, now)
    for _, row in ipairs(addon.model:Rows(now, player)) do if row.guid == guid then return row end end
end
eq(rowFor(a, 200.5).status, "lost", "native yellow glow supplies coarse off-tank status")
eq(rowFor(a, 200.5).threatSource, "plate", "coarse status source explicit")
eq(rowFor(a, 200.5).percent, nil, "native glow never fabricates exact percentages")
eq(rowFor(a, 200.5).hp, 100, "identified native plate supplies current health")
first.regions[1]:SetVertexColor(1, 0.6, 0, 1); plates:Update(200.6, known)
eq(rowFor(a, 200.6).status, "risk", "orange native glow interpreted as insecure tanking")
first.regions[1]:SetVertexColor(1, 0, 0, 1); plates:Update(200.7, known)
eq(rowFor(a, 200.7).status, "safe", "red native glow interpreted as player tanking")
first.regions[1]:SetVertexColor(0.1, 0.5, 1, 1); plates:Update(200.8, known)
eq(rowFor(a, 200.8).status, "unknown", "custom/unsupported glow colors are not guessed")
first.regions[1]:Hide()
addon.model:SetMeleeVictim(a, healer, "Healer", 200.8)
plates:Update(200.9, known)
eq(plates.tracked[first].texture.vertex[2], 0.72, "recent melee evidence uses amber pointer")
first.regions[1]:Show(); first.regions[1]:SetVertexColor(1, 0, 0, 1)
plates:Update(201, known)
eq(plates.arrows, 0, "current tanking glow prevents old melee warning")
first:Hide()
eq(plates.tracked[first].guid, nil, "hide clears recycled GUID")
eq(plates.tracked[first].arrow.visible, false, "hide clears pointer")
first.regions[7]:SetText("Unrelated new mob"); first:Show()
world.SetTime(201.2); plates:Update(201.2, known)
eq(plates.tracked[first].guid, nil, "reused frame never inherits old mob identity")
eq(plates.tracked[first].arrow.visible, false, "reused frame never inherits old mob pointer")
addon.model:Remove(b); plates:Update(201.3, known)
eq(plates.arrows, 0, "dead mob no longer has pointer")
-- Current target can be previewed out of combat without adding fake group enemies.
first.regions[7]:SetText("Twin"); first.regions[1]:Hide()
addon.model:Clear()
plates.test = true; plates:Update(201.4, {})
eq(plates.arrows, 1, "explicit arrow preview targets only selected native plate")
plates.test = false; plates:Update(201.5, {})
eq(plates.arrows, 0, "ending preview removes pointer")
print("Nameplate scenarios passed: " .. count)
