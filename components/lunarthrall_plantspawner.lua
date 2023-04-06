
local SCREEN_RANGE = 30

local TIME_UNIT = TUNING.SEG_TIME*8

local PERIODIC_TIME = TUNING.TOTAL_DAY_TIME *2

local function getrifts()
    local rifts = TheWorld.components.riftspawner and TheWorld.components.riftspawner:GetRiftsOfType("lunarrift_portal")
    if rifts then
        for i=#rifts,1,-1 do
            local rift = rifts[i]
            if not rift:IsValid() then
                rifts[i] = nil
            end
        end
    end
    if rifts and #rifts <= 0 then
        rifts = nil
    end
    return rifts
end

local function releasethrall(world, target)
    local self = TheWorld.components.lunarthrall_plantspawner
    local rift = self.currentrift and self.currentrift:IsValid() and self.currentrift or nil

    if rift then
        local spawnfromrift = false
        for i, player in ipairs(AllPlayers)do
            if rift:GetDistanceSqToInst(player) < SCREEN_RANGE * SCREEN_RANGE then
                --SPAWN THRALL FROM RIFT
                self:SpawnGestalt(target, rift)
                spawnfromrift = true
            end
        end

        if not spawnfromrift then
            --FIND TARGET on or offscreen?
            self:InvadeTarget(target)
        end
    end
end
local PLANT_MUST = {"lunarthrall_plant"}
local function SpawnThralls()
    local self = TheWorld.components.lunarthrall_plantspawner
    if self.waves_to_release and self.waves_to_release > 0 then
        print("self.waves_to_release",self.waves_to_release)
        self.currentrift.SoundEmitter:PlaySound("monkeyisland/portal/buildup_burst")
        self.inst:DoTaskInTime(4,function()
            
            if self._nextspawn then
                self._nextspawn:Cancel()
                self._nextspawn = nil
            end

            if self.waves_to_release and self.waves_to_release > 0 then
                self.waves_to_release = self.waves_to_release - 1

                if self.waves_to_release <= 0 then
                    if self._spawntask then
                        self._spawntask:Cancel()
                        self._spawntask = nil
                    end
                    self.waves_to_release = nil

                    -- MAKE PORTAL GO AWAY
                    if self.currentrift then
                        self.inst:DoTaskInTime(10,function()
                            self.currentrift:PushEvent("finish_rift")
                            self.currentrift = nil
                        end)
                    end
                end

                -- find herd to infest
                local plants = {}

                local herd = self:FindHerd()
                if not herd then
                    -- MAYBE FIND SOME WILD PLANTS?
                    local patch = self:FindWildPatch()
                    if #patch > 0 then
                        for i,member in ipairs(patch)do
                            table.insert(plants,member)
                        end
                    else
                        --"NOTHING FOUND THIS TIME"
                        return
                    end
                else
                    --"ALL PLANTS IN HERD"
                    for member, bool in pairs(herd.components.herd.members)do
                        table.insert(plants,member)
                    end
                end

                local targets = {}
                local SPACE = 3
                while #plants > 0 do
                    local random = math.random(1,#plants)
                    local plant = plants[random]
                    if plant then
                        local eligable = true

                        if eligable then
                            local x,y,z = plant.Transform:GetWorldPosition()
                            local ents = TheSim:FindEntities(x,y,z, SPACE, PLANT_MUST)
                            if #ents > 0 then
                                eligable = false
                            end
                        end

                        if eligable and #targets > 0 then
                            for t,target in ipairs(targets)do
                                if target:GetDistanceSqToInst(plant) < SPACE*SPACE then
                                    eligable = false
                                    break
                                end
                            end
                        end

                        if eligable then
                            table.insert(targets,plant)
                        end
                    end
                    table.remove(plants,random)
                end

                for i,target  in ipairs(targets)do
                    local task = self.inst:DoTaskInTime(math.random()*2, releasethrall, target)
                    self.spawntasks[task] = true
                end
            end
        end)
    end
end

local function setTimeForPoralRelease()
    --print("SET NEXT SPAWN")
    local self = TheWorld.components.lunarthrall_plantspawner
    local rifts = getrifts()
    if rifts and #rifts > 0 then
        self._nextspawn = self.inst:DoTaskInTime(TIME_UNIT + (math.random()*TIME_UNIT) - (TIME_UNIT/2),  SpawnThralls )

    
        if self._spawntask then
            self._spawntask:Cancel()
            self._spawntask = nil
        end
          
        self._spawntask = self.inst:DoTaskInTime(PERIODIC_TIME, setTimeForPoralRelease)
    end
end


local function OnLunarRiftReachedMaxSize(source, rift)
    --print("MAX SIZE REACHED")

    local self = TheWorld.components.lunarthrall_plantspawner
    if not self.currentrift then
        self.currentrift = rift
    end
    if not self.waves_to_release then
        self.waves_to_release = 3 + math.random(1,3)
    end    
    if not self._spawntask then
        self._spawntask = self.inst:DoTaskInTime(PERIODIC_TIME, setTimeForPoralRelease)
    end
    setTimeForPoralRelease()
    
end

local function herdremoved(plantherd)
    local self = TheWorld.components.lunarthrall_plantspawner
    for i, herd in ipairs(self.plantherds)do
        if herd == plantherd then
            table.remove(self.plantherds, i)
            break
        end
    end
end

local function OnPlantHerdSpawned(source, plantherd)
    local self = TheWorld.components.lunarthrall_plantspawner
    table.insert(self.plantherds,plantherd)
    self.inst:ListenForEvent("onremove", herdremoved, plantherd)
end

local function OnLunarPortalRemoved(source,portal)
    local self = TheWorld.components.lunarthrall_plantspawner
    if portal == self.currentrift then
        if self._spawntask then
            self._spawntask:Cancel()
            self._spawntask = nil
        end
    
        if self._nextspawn then
            self._nextspawn:Cancel()
            self._nextspawn = nil
        end
        
        self.waves_to_release = nil
        self.currentrift = nil
    end
end
local Lunarthrall_plantspawner = Class(function(self, inst)
    self.inst = inst
    self.waves_to_release = nil
    self.plantherds = {}
    self.spawntasks = {}
    self.currentrift = nil
    self.inst:ListenForEvent("ms_lunarrift_maxsize", OnLunarRiftReachedMaxSize)
    self.inst:ListenForEvent("plantherdspawned", OnPlantHerdSpawned)
    self.inst:ListenForEvent("ms_lunarportal_removed", OnLunarPortalRemoved)
end)

function Lunarthrall_plantspawner:MoveGestaltToPlant(thrall)
    local target = thrall.plant_target

    local pos = target and Vector3(target.Transform:GetWorldPosition()) or nil

    if not pos then
        thrall:Remove()
        return
    end

    local SCREEN_DIST = 30
    local function POSisVisible(pos)
        local inview = false
        for i,player in ipairs(AllPlayers)do
            if player:GetDistanceSqToPoint(pos) < SCREEN_DIST*SCREEN_DIST then
                inview = true
                break
            end
        end
        return inview
    end

    local theta = math.random()*2*PI
    local radius = SCREEN_DIST
    local loop = 0
    while POSisVisible(pos) do
        local offset = Vector3(radius * math.cos( theta ), 0, -radius * math.sin( theta ))
        pos = Vector3(target.Transform:GetWorldPosition()) + offset
        theta = theta + (PI/8)
        loop = loop + 1
        if loop > 16 then
            loop = 0
            radius = radius + 5
        end
    end
    
    if not POSisVisible(pos) then
        --spawn offscreen of players and head to target

        if not thrall then
            thrall = SpawnPrefab("lunarthrall_plant_gestalt")
        end
        thrall.plant_target = target
        thrall.Transform:SetPosition(pos.x,pos.y,pos.z)
    end
end

function Lunarthrall_plantspawner:SpawnGestalt(target, rift)
    if rift then
        --spawn from portal
        rift.SoundEmitter:PlaySound("monkeyisland/portal/spit_item")
        local thrall = SpawnPrefab("lunarthrall_plant_gestalt")
        thrall.Transform:SetPosition(rift.Transform:GetWorldPosition())
        thrall.plant_target = target
        thrall:Spawn()
    else

        local pos = Vector3(target.Transform:GetWorldPosition())
        local SCREEN_DIST = 30

        local function POSisVisible(pos)
            local inview = false
            for i,player in ipairs(AllPlayers)do
                if player:GetDistanceSqToPoint(pos) < SCREEN_DIST*SCREEN_DIST then
                    inview = true
                    break
                end
            end
            return inview
        end

        local theta = math.random()*2*PI
        local radius = SCREEN_DIST
        local loop = 0
        while POSisVisible(pos) do
            local offset = Vector3(radius * math.cos( theta ), 0, -radius * math.sin( theta ))
            pos = Vector3(target.Transform:GetWorldPosition()) + offset
            theta = theta + (PI/8)
            loop = loop + 1
            if loop > 16 then
                loop = 0
                radius = radius + 5
            end
        end
        
        if not POSisVisible(pos) then
            --spawn offscreen of players and head to target

            local thrall = SpawnPrefab("lunarthrall_plant_gestalt")
            thrall.plant_target = target
            thrall.Transform:SetPosition(pos.x,pos.y,pos.z)
        end
    end
end

function Lunarthrall_plantspawner:SpawnPlant(target)
    local moonplant = SpawnPrefab("lunarthrall_plant")
    moonplant:infest(target)
    moonplant:playSpawnAnimation()
end

local function caninfest(target)
    local caninfest = true
    if target.lunarthrall_plant then
        caninfest = false
    end
    return caninfest
end

local PLANTS_MUST = {"plant"}
function Lunarthrall_plantspawner:FindWildPatch()
    local tries = {}
    
    while #tries < 10 do
        local plants = {}
        local pt = TheWorld.Map:FindRandomPointOnLand(40)
        if pt then
            -- LOOK FOR PLANTS 
            local ents = TheSim:FindEntities(pt.x,pt.y,pt.z, 20, PLANTS_MUST)
            for i, ent in ipairs(ents)do
                if not ent.lunarthrall_plant and 
                    (ent.prefab == "berrybush" or
                     ent.prefab == "berrybush2" or
                     ent.prefab == "berrybush_juicy" or
                     ent.prefab == "sapling" or
                     ent.prefab == "grass") then
                        table.insert(plants,ent)
                end
            end
        end
        table.insert(tries,plants)
    end

    local top = 0
    local choice = nil
    for i,try in ipairs(tries)do
        if #try > top then
            choice = i
            top = #try
        end
    end
    if choice then
        return tries[choice]
    end
end

function Lunarthrall_plantspawner:FindHerd()
    local choices = {}
    for i, herd in ipairs(self.plantherds)do
        table.insert(choices,herd)
    end

    local num = 0
    local choice = nil
    for i, herd in ipairs(choices)do
        local count = 0
        for member, i in pairs(herd.components.herd.members) do
            if not member.lunarthrall_plant and 
                (not member.components.witherable or not member.components.witherable:IsWithered()) then
                count = count +1
            end
        end
        if count > num then
            choice = herd
            num = count
        end
    end

    if choice then
        return choice
    end
end

function Lunarthrall_plantspawner:FindPlant()
    local plant = nil

    local choices = {}

    for i, herd in ipairs(self.plantherds)do
        local plants = herd.components.herd.members
        for plant,p in pairs(plants)do
            if caninfest(plant) then
                table.insert(choices,plant)
            end
        end
    end

    if #choices > 0 then
        local plant = choices[math.random(1,#choices)]
        return plant
    end
end


function Lunarthrall_plantspawner:InvadeTarget(target)

    if target and target:IsValid() then
        local visible = nil
        for i, player in ipairs(AllPlayers)do
            if target:GetDistanceSqToInst(player) < SCREEN_RANGE * SCREEN_RANGE then
                visible = true
            end
        end
       
        if visible then
            self:SpawnGestalt(target) -- spawn gestalt to invate on screen
        else
            self:SpawnPlant(target)--Invade Plant offscreen
        end
    end

end

function Lunarthrall_plantspawner:OnSave()

    local refs = {}
    if self.currentrift then
        table.insert(refs, self.currentrift.GUID)
    end

    return {
        waves_to_release = self.waves_to_release,
        spawntask = self._spawntask and  GetTaskRemaining(self._spawntask) or nil,
        nextspawn = self._nextspawn and GetTaskRemaining(self._nextspawn) or nil,
        currentrift = self.currentrift and self.currentrift.GUID or nil
    }, refs
end

function Lunarthrall_plantspawner:OnLoad(data)
    if data and data.waves_to_release then
        self.waves_to_release = data.waves_to_release
    end
end

function Lunarthrall_plantspawner:LoadPostPass(newents, data)
    if data and data.currentrift then
        self.currentrift = newents[data.currentrift] and newents[data.currentrift].entity or nil
    end    
    if self._spawntask then
        self._spawntask:Cancel()
        self._spawntask = nil
    end
    if self._nextspawn then
        self._nextspawn:Cancel()
        self._nextspawn = nil
    end
    if data and data.spawntask then
        self._spawntask = self.inst:DoTaskInTime(data.spawntask, setTimeForPoralRelease)
    end
    if data and data.nextspawn then
        self._nextspawn = self.inst:DoTaskInTime(data.nextspawn, SpawnThralls)
    end
end

function Lunarthrall_plantspawner:GetDebugString()
    local s = ""
        s = s .. string.format("Waves remaining: %s", tostring(self.waves_to_release) or "NONE") .. " | " 
        s = s .. string.format("Next Wave: %s", self._spawntask and tostring(GetTaskRemaining(self._spawntask)) or "NONE") .. " | "
        s = s .. string.format("Spawn Wave in: %s", self._nextspawn and tostring(GetTaskRemaining(self._nextspawn)) or "NONE") .. " | "

    return s
end

function Lunarthrall_plantspawner:LongUpdate(dt)

    if self._nextspawn then 
        local time = GetTaskRemaining(self._nextspawn)
        self._nextspawn:Cancel()
        self._nextspawn= nil
        self._nextspawn = self.inst:DoTaskInTime(math.max(0.1,time-dt), SpawnThralls)
    end  

    if self._spawntask then 
        local time = GetTaskRemaining(self._spawntask)
        self._spawntask:Cancel()
        self._spawntask= nil
        self._spawntask = self.inst:DoTaskInTime(math.max(0.1,time-dt), setTimeForPoralRelease)
    end    
end

function Lunarthrall_plantspawner:setHerdsOnPlantable(plantable)
    plantable:AddComponent("knownlocations")
    plantable:AddComponent("herdmember")
    plantable.components.herdmember:SetHerdPrefab("domesticplantherd")
end

return Lunarthrall_plantspawner