-- Pure Lua 5.1 model. No WoW API calls; all times use the caller's monotonic clock.
PartyAggro335Core = {}
local Core = PartyAggro335Core
local Model = {}
Model.__index = Model
local priority = { lost = 1, risk = 2, unknown = 3, safe = 4 }

function Core.New(options)
    options = options or {}
    return setmetatable({ enemies = {}, serial = 0, maxEnemies = options.maxEnemies or 128,
        ttl = options.ttl or 25, snapshotTTL = options.snapshotTTL or 1,
        victimTTL = options.victimTTL or 2.5 }, Model)
end

function Core.ValidGUID(guid)
    return type(guid) == "string" and guid ~= "" and guid ~= "0x0000000000000000"
end

function Model:Touch(guid, name, now)
    if not Core.ValidGUID(guid) then return nil end
    local enemy = self.enemies[guid]
    if not enemy then
        local count, oldest = 0, nil
        for _, value in pairs(self.enemies) do
            count = count + 1
            if not oldest or value.lastSeen < oldest.lastSeen then oldest = value end
        end
        if count >= self.maxEnemies and oldest then self.enemies[oldest.guid] = nil end
        self.serial = self.serial + 1
        enemy = { guid = guid, serial = self.serial }
        self.enemies[guid] = enemy
    end
    enemy.name = (type(name) == "string" and name ~= "") and name or enemy.name or "?"
    enemy.lastSeen = now
    return enemy
end

function Model:Remove(guid) self.enemies[guid] = nil end
function Model:Clear() self.enemies = {}; self.serial = 0 end

function Model:SetObservation(guid, observation, now)
    local enemy = self.enemies[guid]
    if enemy then
        enemy.observation = observation
        enemy.observedAt = now
    end
end

function Model:SetMeleeVictim(guid, victimGUID, name, now)
    local enemy = self.enemies[guid]
    if enemy and Core.ValidGUID(victimGUID) then
        enemy.meleeVictim = { guid = victimGUID, name = name or "?", at = now }
    end
end

function Model:Prune(now)
    for guid, enemy in pairs(self.enemies) do
        if now - enemy.lastSeen > self.ttl then self.enemies[guid] = nil end
    end
end

function Model:Rows(now, playerGUID)
    local rows = {}
    for _, enemy in pairs(self.enemies) do
        local row = { guid = enemy.guid, serial = enemy.serial, name = enemy.name,
            status = "unknown", lastSeen = enemy.lastSeen }
        local observation = enemy.observation
        if observation and now - enemy.observedAt <= self.snapshotTTL then
            row.hp, row.marker = observation.hp, observation.marker
            row.targetName, row.targetGUID = observation.targetName, observation.targetGUID
            row.targetSource = observation.targetSource
            local threat = observation.threat
            row.hasThreat = threat ~= nil
            if threat and type(threat.status) == "number" then
                row.percent = type(threat.percent) == "number" and threat.percent or nil
                if threat.isTanking or threat.status >= 2 then
                    row.status = threat.status == 2 and "risk" or "safe"
                else
                    row.status = "lost"
                end
            elseif observation.targetSource == "target" and observation.targetInGroup
                and observation.targetGUID ~= playerGUID then
                row.status = "lost"
            end
        end
        -- A melee victim is an observation, never a fabricated threat percentage.
        if not row.targetGUID and enemy.meleeVictim and now - enemy.meleeVictim.at <= self.victimTTL then
            row.targetGUID = enemy.meleeVictim.guid
            row.targetName = enemy.meleeVictim.name
            row.targetSource = "melee"
        end
        row.stale = now - enemy.lastSeen > 8
        rows[#rows + 1] = row
    end
    table.sort(rows, function(a, b)
        if priority[a.status] ~= priority[b.status] then return priority[a.status] < priority[b.status] end
        return a.serial < b.serial
    end)
    return rows
end

function Core.Preview()
    return {
        { guid = "preview-1", serial = 1, name = "Enemy / Моб", status = "lost", percent = 64,
          hp = 82, targetName = "Healer", targetGUID = "preview-healer", targetSource = "target", marker = 8 },
        { guid = "preview-2", serial = 2, name = "Enemy / Моб", status = "risk", percent = 100,
          hp = 71, targetName = "You", targetGUID = "preview-player", targetSource = "target" },
        { guid = "preview-3", serial = 3, name = "Caster / Заклинатель", status = "unknown",
          targetName = "DPS", targetSource = "melee", targetGUID = "preview-dps" },
        { guid = "preview-4", serial = 4, name = "Enemy / Моб", status = "safe", percent = 100,
          hp = 55, targetName = "You", targetGUID = "preview-player", targetSource = "threat" },
    }
end
