-- Native targeting remains under the client's control. The panel follows target
-- changes by GUID, without protected actions or changes to the user's bindings.
local count = 0
local function eq(actual, expected, name)
    count = count + 1
    assert(actual == expected, name .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local addon, world = PartyAggro335Addon, PartyAggro335TestWorld
local ui, rows = addon.ui, {}
local oldLimit, oldTarget = addon.config.maxRows, world.units.target
addon.config.maxRows = 5
for index = 1, 6 do
    rows[index] = { guid = "selected-" .. index, serial = index, name = "Twin",
        status = index == 2 and "risk" or "lost", percent = 60, hp = 70 }
end
ui:Render(rows, false, true, "selected-2")
eq(ui.rows[1].isCurrent, false, "identical name does not select the wrong mob")
eq(ui.rows[2].selection:IsShown(), true, "current target has a visible border")
eq(ui.rows[2].pointer:IsShown(), true, "current target has a text pointer")
eq(ui.rows[2].threat:GetText(), "60% Под угрозой", "selection preserves threat status")
eq(ui.rows[1].selection:IsShown(), false, "other enemies have no selection border")

ui:UpdateTarget("selected-6")
eq(ui.rows[5].data.guid, "selected-6", "target below row limit stays visible")
eq(ui.rows[5].selection:IsShown(), true, "pinned target is highlighted")
eq(ui.rows[1].data.guid, "selected-1", "highest-priority enemy remains first")
eq(ui.rows[2].pointer:IsShown(), false, "previous target pointer clears")
eq(rows[5].guid, "selected-5", "pinning does not mutate model ordering")
eq(ui.footer:GetText(), string.format(PartyAggro335L.overflow, 1), "overflow remains accurate")

world.units.target = { guid = "selected-3", name = "Twin" }
addon.frame.scripts.OnEvent(addon.frame, "PLAYER_TARGET_CHANGED")
eq(ui.rows[3].selection:IsShown(), true, "target event updates immediately without scan")
eq(ui.rows[5].data.guid, "selected-5", "previously displaced row returns")
eq(ui.rows[5].selection:IsShown(), false, "reused row loses old highlight")

world.units.target = nil
addon.frame.scripts.OnEvent(addon.frame, "PLAYER_TARGET_CHANGED")
local selected = 0
for _, row in ipairs(ui.rows) do if row.isCurrent then selected = selected + 1 end end
eq(selected, 0, "clearing target removes all selections")
ui:UpdateTarget("friendly-or-unlisted")
eq(ui.rows[1].pointer:IsShown(), false, "unlisted target does not highlight by name")

ui:Render({ rows[3], rows[2], rows[1] }, false, true, "selected-2")
eq(ui.rows[2].data.guid, "selected-2", "selection follows identity after sorting")
eq(ui.rows[2].isCurrent, true, "resorted target remains selected")
eq(ui.rows[5].data, nil, "unused row data clears")
eq(ui.rows[5].pointer:IsShown(), false, "unused row pointer clears")
ui:Render({ rows[3] }, false, true, "selected-2")
eq(ui.rows[1].isCurrent, false, "removed target cannot highlight replacement row")

ui:Render(PartyAggro335Core.Preview(), true, true, "selected-2")
eq(ui.rows[1].selection:IsShown(), true, "preview demonstrates a selected row")
ui:UpdateTarget("preview-2")
eq(ui.rows[2].isCurrent, false, "real target changes do not alter demo selection")
ui:Render(rows, false, false, "selected-1")
ui:UpdateTarget("selected-2")
eq(ui.frame:IsShown(), false, "target changes do not reveal a hidden panel")
ui:Render({}, false, true, nil)
eq(ui.empty:IsShown(), true, "empty list renders normally")
eq(ui.rows[1].isCurrent, false, "empty list clears selection")

world.units.target, addon.config.maxRows = oldTarget, oldLimit
print("Current-target scenarios passed: " .. count)
