local GelBlobSpawner = Class(function(self, inst)
    local _world = TheWorld
    assert(_world.ismastersim, "GelBlobSpawner should not exist on the client")

    self.inst = inst

    self.enabled = false

    self.spawnpoints = {}

    self.gelblobs = {}
    self.gelblobcount = 0
    self.blobbedspawners = {}
    self.MIN_GELBLOBS_PER_SPAWNER = TUNING.MIN_GELBLOBS_PER_SPAWNER
    self.MAX_GELBLOBS_PER_SPAWNER = TUNING.MAX_GELBLOBS_PER_SPAWNER
    self.MAX_GELBLOBS_TOTAL_IN_WORLD = TUNING.MAX_GELBLOBS_TOTAL_IN_WORLD
    self.MIN_GELBLOB_DIST_FROM_EACHOTHER_SQ = TUNING.MIN_GELBLOB_DIST_FROM_EACHOTHER * TUNING.MIN_GELBLOB_DIST_FROM_EACHOTHER
    self.MAX_GELBLOB_DIST_FROM_SPAWNER = TUNING.MAX_GELBLOB_DIST_FROM_SPAWNER
    self.MIN_GELBLOB_SPAWN_DELAY = TUNING.MIN_GELBLOB_SPAWN_DELAY
    self.VARIANCE_GELBLOB_SPAWN_DELAY = TUNING.VARIANCE_GELBLOB_SPAWN_DELAY

    self.logictickaccumulator = 0
    self.LOGIC_TICK_TIME = 1

    if TUNING.SPAWN_GELBLOBS then
        inst:ListenForEvent("ms_registergelblobspawningground", function(inst, spawnpoint)
            self:TryToRegisterSpawningPoint(spawnpoint)
        end)

        local function UpdateState()
            local riftspawner = _world.components.riftspawner
            if riftspawner and riftspawner:IsShadowPortalActive() then
                self:StartGelBlobs()
            else
                self:StopGelBlobs()
            end
        end
        inst:ListenForEvent("ms_riftaddedtopool", UpdateState, _world)
        inst:ListenForEvent("ms_riftremovedfrompool", UpdateState, _world)
    end
end)

function GelBlobSpawner:UnregisterGelBlobSpawningPoint(spawnpoint)
    table.removearrayvalue(self.spawnpoints, spawnpoint)
end

function GelBlobSpawner:RegisterGelBlobSpawningPoint(spawnpoint)
    -- NOTES(JBK): This should not be called directly it exists for mods to get access to it.
    table.insert(self.spawnpoints, spawnpoint)
    self.inst:ListenForEvent("onremove", function() self:UnregisterGelBlobSpawningPoint(spawnpoint) end, spawnpoint)
end

function GelBlobSpawner:TryToRegisterSpawningPoint(spawnpoint)
    if table.contains(self.spawnpoints, spawnpoint) then
        return false
    end

    self:RegisterGelBlobSpawningPoint(spawnpoint)
    return true
end

-- Functionality.

function GelBlobSpawner:GetGelBlobCount()
    return self.gelblobcount
end

function GelBlobSpawner:WatchGelBlob(gelblob, spawner)
    self.gelblobcount = self.gelblobcount + 1
    self.gelblobs[gelblob] = spawner
    self.blobbedspawners[spawner] = true
    self.inst:ListenForEvent("onremove", function()
        local oldspawner = self.gelblobs[gelblob]
        self.gelblobs[gelblob] = nil
        self.gelblobcount = self.gelblobcount - 1
        local stillhasspawner = false
        for gelblob, spawner in pairs(self.gelblobs) do
            if spawner == oldspawner then
                stillhasspawner = true
                break
            end
        end
        if not stillhasspawner then
            self.blobbedspawners[oldspawner] = nil
        end
    end, gelblob)
end

function GelBlobSpawner:StartGelBlobs()
    if self.enabled then
        return
    end

    self.enabled = true
    self.inst:StartUpdatingComponent(self)
end

function GelBlobSpawner:StopGelBlobs()
    self.enabled = false
end

function GelBlobSpawner:IsGelBlobbed(spawner)
    return self.blobbedspawners[spawner]
end

GelBlobSpawner.SafeToSpawnCheck = function(pt)
    return TheWorld.Map:IsPassableAtPoint(pt:Get()) and TheWorld.Map:IsDeployPointClear(pt, nil, 2)
end
function GelBlobSpawner:SpawnGelBlobFromSpawner(spawner, player)
    if self:IsGelBlobbed(spawner) then
        return false
    end

    local spawncount = math.random(self.MIN_GELBLOBS_PER_SPAWNER, self.MAX_GELBLOBS_PER_SPAWNER)
    if self:GetGelBlobCount() + spawncount > self.MAX_GELBLOBS_TOTAL_IN_WORLD then
        return false
    end

    player = player or spawner -- If player is not passed let us bias it towards the spawner instead.

    local spawnedatleastone = false
    local x, y, z = spawner.Transform:GetWorldPosition()
    local pt = Vector3(x, 0, z)
    local px, py, pz = player.Transform:GetWorldPosition()
    local ppt = Vector3(px, 0, pz)
    local offsets = {}
    for i = 1, spawncount do
        local offset
        local radius = self.MAX_GELBLOB_DIST_FROM_SPAWNER * math.sqrt(math.random())
        for attempt = 1, 3 do
            offset = FindWalkableOffset(pt, math.random() * TWOPI, radius, 8, true, true, self.SafeToSpawnCheck, false, false)
            if offset then
                local playeroffset = FindWalkableOffset(ppt, math.random() * TWOPI, 4, 4, true, true, self.SafeToSpawnCheck, false, false)
                if playeroffset then
                    offset = (offset + playeroffset) * 0.5
                end
                local keepoffset = true
                for _, oldoffset in ipairs(offsets) do
                    if oldoffset:DistSq(offset) < self.MIN_GELBLOB_DIST_FROM_EACHOTHER_SQ then
                        keepoffset = false
                        break
                    end
                end
                if keepoffset then
                    table.insert(offsets, offset)
                    local gelblob = SpawnPrefab("gelblob")
                    gelblob.Transform:SetPosition(x + offset.x, 0, z + offset.z)
                    gelblob.sg:GoToState("spawndelay", self.MIN_GELBLOB_SPAWN_DELAY + math.random() * self.VARIANCE_GELBLOB_SPAWN_DELAY)
                    self:WatchGelBlob(gelblob, spawner)
                    spawnedatleastone = true
                    break
                end
            end
        end
    end

    return spawnedatleastone
end

local GELBLOBSPAWNER_MUST_TAGS = {"gelblobspawningground"}
function GelBlobSpawner:TrySpawningGelBlobs()
    for _, player in ipairs(AllPlayers) do
        if not player.components.health:IsDead() and not player:HasTag("playerghost") then
            local x, y, z = player.Transform:GetWorldPosition()
            local spawners = TheSim:FindEntities(x, y, z, self.MAX_GELBLOB_DIST_FROM_SPAWNER, GELBLOBSPAWNER_MUST_TAGS)
            for _, spawner in ipairs(spawners) do
                if self:SpawnGelBlobFromSpawner(spawner, player) then
                    break
                end
            end
        end
    end
end

function GelBlobSpawner:TryRemovingGelBlobs()
    local gelblob = next(self.gelblobs)
	gelblob.components.health:Kill()
end

function GelBlobSpawner:CheckGelBlobs()
    local count = self:GetGelBlobCount()
    if self.enabled then
        if count < self.MAX_GELBLOBS_TOTAL_IN_WORLD then
            self:TrySpawningGelBlobs()
        end
    else
        if count > 0 then
            self:TryRemovingGelBlobs()
        else
            self.inst:StopUpdatingComponent(self)
        end
    end
end

function GelBlobSpawner:OnUpdate(dt)
    self.logictickaccumulator = self.logictickaccumulator + dt
    if self.logictickaccumulator > self.LOGIC_TICK_TIME then
        self.logictickaccumulator = 0
        self:CheckGelBlobs()
    end
end

-- Save/Load/Debug.

function GelBlobSpawner:OnSave()
    local data, ents

    if next(self.gelblobs) then
        data = {
            spawners = {},
            gelblobs = {},
        }
        ents = {}
        for gelblob, spawner in pairs(self.gelblobs) do
            table.insert(data.gelblobs, {gelblob = gelblob.GUID, spawner = spawner.GUID})
            table.insert(ents, gelblob.GUID)
            table.insert(ents, spawner.GUID)
        end
    end

    return data, ents
end

function GelBlobSpawner:LoadPostPass(newents, savedata)
    if savedata.gelblobs then
        for _, gelblobs in ipairs(savedata.gelblobs) do
            local gelblob, spawner
            if newents[gelblobs.gelblob] then
                gelblob = newents[gelblobs.gelblob].entity
            end
            if newents[gelblobs.spawner] then
                spawner = newents[gelblobs.spawner].entity
            end
            if gelblob then
                self:WatchGelBlob(gelblob, spawner or gelblob)
            end
        end
    end
end

function GelBlobSpawner:GetDebugString()
    return string.format("SpawnPoints: %d, GelBlobs: %d/%d", #self.spawnpoints, self.gelblobcount, self.MAX_GELBLOBS_TOTAL_IN_WORLD)
end

return GelBlobSpawner
