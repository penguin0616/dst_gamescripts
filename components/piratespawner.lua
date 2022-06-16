    --------------------------------------------------------------------------
--[[ Pirate Spawner class definition ]]
--------------------------------------------------------------------------

return Class(function(self, inst)

assert(TheWorld.ismastersim, "Pirate Spawner should not exist on client")

--------------------------------------------------------------------------
--[[ Dependencies ]]
--------------------------------------------------------------------------

local SourceModifierList = require("util/sourcemodifierlist")

--------------------------------------------------------------------------
--[[ Constants ]]
--------------------------------------------------------------------------

local function stashloot(inst)

    local ps = TheWorld.components.piratespawner
    if ps then
        local stash = ps:GetCurrentStash()
        if inst.components.inventoryitem then
            if not inst:HasTag("personal_possession") then
                table.insert(stash.loot,inst)
                inst:RemoveFromScene()
            else
                inst:Remove()
            end 
        elseif inst.components.inventory then
            for k,v in pairs(inst.components.inventory.itemslots) do

                if not v:HasTag("personal_possession") then
                    local item = inst.components.inventory:RemoveItemBySlot(k)
                    table.insert(stash.loot,item)
                else
                    v:Remove()
                end
            end
        end
    end
end

local function setpirateboat(boat)

    boat:AddComponent("boatcrew")

    boat:AddComponent("vanish_on_sleep")
    boat.components.vanish_on_sleep.vanishfn = function(inst)
        --local ents = boat.components.walkableplatform:GetEntitiesOnPlatform()
        local x,y,z = inst.Transform:GetWorldPosition()
        local ents = TheSim:FindEntities(x,y,z, inst.components.walkableplatform.platform_radius)
        for i=#ents,1,-1 do
            stashloot(ents[i])
            ents[i]:Remove()
        end
    end
end

local function forgetmonkey(monkey)
    if TheWorld.components.piratespawner then
        local ps = TheWorld.components.piratespawner
        for b=#ps.shipdatas, 1,-1 do
            local shipdata = ps.shipdatas[b]
            if shipdata.captain and shipdata.captain == monkey then
                shipdata.captain = nil
            else
                for i=#shipdata.crew, 1,-1 do
                    if shipdata.crew[i] == monkey then
                        table.remove(shipdata.crew,i)
                        break
                    end
                end
            end
            if #shipdata.crew <= 0 and shipdata.captain == nil then
                table.remove(ps.shipdatas,b)
            end
        end        
    end
end

local function remembermonkey(monkey)
    monkey:ListenForEvent("onremove", forgetmonkey)
end

local function setcaptain(captain,boat)
    remembermonkey(captain)
    captain:AddComponent("crewmember")
    boat.components.boatcrew:AddMember(captain,true)
end

local function setcrewmember(monkey,boat)
    remembermonkey(monkey)
    monkey:AddComponent("crewmember")
    monkey.components.crewmember.leavecrewfn = function()
        if monkey.tinkertarget then
            monkey.ClearTinkerTarget(monkey)
        end
    end
    boat.components.boatcrew:AddMember(monkey)
end

local RANGE = 40 -- distance from player to spawn the flotsam.  should be 5 more than wanted
local SHORTRANGE = 5 -- radius that must be clear for flotsam to appear

local function spawnpirateship(pt)
    local shipdata = {}

    -- SPAWN BOAT
    local boat = SpawnPrefab("boat_pirate")
    shipdata.boat = boat
    boat.Transform:SetPosition(pt.x,pt.y,pt.z)
    setpirateboat(boat)

    local mast = SpawnPrefab("pirate_flag_pole")
    mast.Transform:SetPosition(pt.x,pt.y,pt.z)

    -- SPAWN CAPTAIN
    local captain = SpawnPrefab("prime_mate")
    captain.Transform:SetPosition(pt.x,pt.y,pt.z)
    setcaptain(captain,boat)
    shipdata.captain = captain
    for i=1,2 do
        local item = SpawnPrefab("treegrowthsolution")
        item:AddTag("personal_possession")
        captain.components.inventory:GiveItem(item)
    end

    local oar = SpawnPrefab("oar_monkey")
    oar:AddTag("personal_possession")
    captain.components.inventory:GiveItem(oar)
    captain.components.inventory:Equip(oar)

    local hat = SpawnPrefab("monkey_mediumhat")
    hat:AddTag("personal_possession")
    captain.components.inventory:GiveItem(hat)
    captain.components.inventory:Equip(hat)

    local map = SpawnPrefab("stash_map")
    map:AddTag("personal_possession")    
    captain.components.inventory:GiveItem(map)

    --SPAWN MONKEYS
    local monkeys = 4
    shipdata.crew = {}
    for i=1,monkeys do
        local monkey = SpawnPrefab("powder_monkey")
        table.insert(shipdata.crew,monkey)        
        monkey.Transform:SetPosition(pt.x,pt.y,pt.z)
        setcrewmember(monkey,boat)

        local cutless = SpawnPrefab("cutless")
        cutless:AddTag("personal_possession")
        monkey.components.inventory:GiveItem(cutless)
        monkey.components.inventory:Equip(cutless)
        

        local hat = SpawnPrefab("monkey_smallhat")
        hat:AddTag("personal_possession")
        monkey.components.inventory:GiveItem(hat)
        monkey.components.inventory:Equip(hat)
    end

    local players = FindPlayersInRange(pt.x, pt.y, pt.z,  RANGE, true)
    for i,player in ipairs(players)do
        player.components.talker:Say(  GetString(player, "ANNOUNCE_PIRATES_ARRIVE") )
        player.SoundEmitter:PlaySound("dontstarve/creatures/deerclops/taunt_howl")
    end

    return shipdata
end

local LIFESPAN = {	base = TUNING.TOTAL_DAY_TIME *3,
					varriance = TUNING.TOTAL_DAY_TIME }


local function getnextmonkeytime()
    return math.random() * TUNING.PIRATESPAWNER_BASEPIRATECHANCE
end
--------------------------------------------------------------------------
--[[ Member variables ]]
--------------------------------------------------------------------------

--Public
self.inst = inst

--Private
local _activeplayers = {}
local _scheduledtask = nil
local _worldstate = TheWorld.state
local _map = TheWorld.Map
local _minspawndelay = TUNING.PIRATE_SPAWN_DELAY.min
local _maxspawndelay = TUNING.PIRATE_SPAWN_DELAY.max
local _updating = false
local _maxpirates = 1
local _timescale = 1
local _current_stash = nil

local zones ={
    { -- INNER
        max = TUNING.PIRATESPAWNER.INNER.MAX,
        maxtime = TUNING.PIRATESPAWNER.INNER.TIME,
        chance = TUNING.PIRATESPAWNER.INNER.CHANCE,
        weight = TUNING.PIRATESPAWNER.INNER.WEIGHT,
    },
    { -- MID
        max = TUNING.PIRATESPAWNER.MID.MAX,
        maxtime = TUNING.PIRATESPAWNER.MID.TIME,
        chance = TUNING.PIRATESPAWNER.MID.CHANCE,
        weight = TUNING.PIRATESPAWNER.MID.WEIGHT,
    },
    { -- OUTTER
        max = TUNING.PIRATESPAWNER.OUTTER.MAX,
        maxtime = TUNING.PIRATESPAWNER.OUTTER.TIME,
        chance = TUNING.PIRATESPAWNER.OUTTER.CHANCE,
        weight = TUNING.PIRATESPAWNER.OUTTER.WEIGHT,
    },
}
local _nextpiratechance = getnextmonkeytime()
local _lasttic_players = {}

self.shipdatas = {}

self.SwapData = {}
self._savedata = {}

self.queen = nil

self.inst:DoTaskInTime(0,function()
    for k,v in pairs(Ents) do
        if v.prefab == "monkeyqueen" then
            self.queen = v
            self.inst:ListenForEvent("onremove", function() self.queen = nil end, self.queen)
            break
        end
    end

    if TUNING.PIRATE_RAIDS_ENABLED and self.queen then
        self.inst:StartUpdatingComponent(self)
    end
end)

--------------------------------------------------------------------------
--[[ Private member functions ]]
--------------------------------------------------------------------------

local SPAWNPOINT_1_ONEOF_TAGS = {"player"}
local SPAWNPOINT_2_ONEOF_TAGS = {"INLIMBO", "fx"}
local function GetSpawnPoint(platform)
    local pt = Vector3(platform.Transform:GetWorldPosition())
    if TheWorld.has_ocean then
        local function TestSpawnPoint(offset)
            local spawnpoint_x, spawnpoint_y, spawnpoint_z = (pt + offset):Get()
            return _map:IsSurroundedByWater(spawnpoint_x, spawnpoint_y, spawnpoint_z, TUNING.MAX_WALKABLE_PLATFORM_RADIUS) and
                   #TheSim:FindEntities(spawnpoint_x, spawnpoint_y, spawnpoint_z, RANGE-SHORTRANGE, nil, nil, SPAWNPOINT_1_ONEOF_TAGS) <= 0 and
                   #TheSim:FindEntities(spawnpoint_x, spawnpoint_y, spawnpoint_z, SHORTRANGE, nil, SPAWNPOINT_2_ONEOF_TAGS) <= 0
        end

        local theta = math.random() * 2 * PI
        local radius = RANGE
        local resultoffset = FindValidPositionByFan(theta, radius, 12, TestSpawnPoint)

        if resultoffset ~= nil then
            return pt + resultoffset
        end
    end
end

local function SpawnPiratesForPlayer(player)
    print("SPAWNING PIRATED FOR PLAYER",player.GUID)

    local spawnedPirates = false
    local boat =  player:GetCurrentPlatform()
    if boat then       
        local spawnpoint = GetSpawnPoint(boat)

        if spawnpoint ~= nil then
            spawnedPirates = true
            local shipdata = spawnpirateship(spawnpoint)

            self:SaveShipData(shipdata)
        end
    end

    return spawnedPirates
end

--------------------------------------------------------------------------
--[[ Private event handlers ]]
--------------------------------------------------------------------------

local function OnPlayerJoined(src, player)
    for i, v in ipairs(_activeplayers) do
        if v == player then
            return
        end
    end
    table.insert(_activeplayers, player)
end

local function OnPlayerLeft(src, player)
    for i, v in ipairs(_activeplayers) do
        if v == player then
            table.remove(_activeplayers, i)
            return
        end
    end
end

local function OnPlayerReplaced(src, newplayer)
    assert(self.SwapData,"No SwapData present")
    assert(self.SwapData[newplayer.userid],"No SwapData for current userid")

    local player = self.SwapData[newplayer.userid].oldplayer
    player:SwapAllCharacteristics(newplayer, self.SwapData[newplayer.userid].equippedslots or nil,self.SwapData[newplayer.userid].activeitem or nil )

    newplayer:LoadForReroll(self._savedata[newplayer.userid]) -- apply the saved stuff from the old player
    self._savedata[newplayer.userid] = nil

    self.SwapData[newplayer.userid] = {oldprefab = player.prefab, skin_base = self.SwapData[newplayer.userid].skin_base, skin_base_monkey = self.SwapData[newplayer.userid].skin_base_monkey  }

    if player.prefab ~= "wonkey" and newplayer.prefab == "wonkey" then
        newplayer.sg:GoToState("changetomonkey_pst")
    elseif player.prefab == "wonkey" and newplayer.prefab ~= "wonkey" then
        newplayer.sg:GoToState("changefrommonkey_pst")
    end

    TheWorld:PushEvent("player_changed_to_monkey", {player=newplayer})
end

--------------------------------------------------------------------------
--[[ Initialization ]]
--------------------------------------------------------------------------

--Initialize variables
for i, v in ipairs(AllPlayers) do
    table.insert(_activeplayers, v)
end

--Register events
inst:ListenForEvent("ms_playerjoined", OnPlayerJoined)
inst:ListenForEvent("ms_playerleft", OnPlayerLeft)

inst:ListenForEvent("ms_seamlesscharacterspawned", OnPlayerReplaced)

--------------------------------------------------------------------------
--[[ Post initialization ]]
--------------------------------------------------------------------------

--------------------------------------------------------------------------
--[[ Public getters and setters ]]
--------------------------------------------------------------------------

--------------------------------------------------------------------------
--[[ Public member functions ]]
--------------------------------------------------------------------------
function self:FindStashLocation()
    local locationOK = false
    local pt = Vector3(0,0,0)
    local offset = Vector3(0,0,0)

    while locationOK == false do
        local ids = {}
        for node, i in pairs(TheWorld.topology.nodes)do
            local ct = TheWorld.topology.nodes[node].cent
            if TheWorld.Map:IsVisualGroundAtPoint(ct[1], 0, ct[2]) then
                table.insert(ids,node)
            end
        end

        local randnode =  TheWorld.topology.nodes[ids[math.random(1,#ids)]]
        pt = Vector3(randnode.cent[1],0,randnode.cent[2])
        local theta = math.random()* 2 * PI
        local radius = 4 
        offset = Vector3(radius * math.cos( theta ), 0, -radius * math.sin( theta ))

        while  TheWorld.Map:IsVisualGroundAtPoint(pt.x, 0, pt.z) == true do
            pt = pt + offset
        end

        local players = FindPlayersInRange( pt.x, pt.y, pt.z, 40, true )
        if #players == 0  then
            locationOK = true
        end
    end

    return pt - (offset *2)
end

function self:StashLoot(ent)
    stashloot(ent)
end

local function generateloot(stash)
    local function additem(name)
        local item = SpawnPrefab(name)
        item.Transform:SetPosition(stash.Transform:GetWorldPosition())
        item:RemoveFromScene()
        table.insert(stash.loot,item)
    end

    local lootlist = {}

    for i=1,3 do
        if math.random() < 0.3 then
            table.insert(lootlist,"goldnugget")
        end
    end

    if math.random() < 0.5 then
        for i=3,6 do
            if math.random() < 0.3 then
                table.insert(lootlist,"meat_dried")
            end
        end  
    end

    if math.random() < 0.5 then
        for i=1,3 do
            if math.random() < 0.3 then
                table.insert(lootlist,"bananajuice")
            end
        end  
    end

    if math.random() < 0.2 then
        if math.random() < 0.2 then
            table.insert(lootlist,"shovel")
        else
            table.insert(lootlist,"goldenshovel")
        end
    end

    if math.random() < 0.5 then
        table.insert(lootlist,"pirate_flag_pole_blueprint")    
    end
    if math.random() < 0.5 then
        table.insert(lootlist,"polly_rogershat_blueprint")    
    end


    for i,loot in ipairs(lootlist)do
        additem(loot)
    end
end


function self:GetCurrentStash()
    if not _current_stash then
        local pt = self:FindStashLocation()
        _current_stash = SpawnPrefab("pirate_stash")
        _current_stash.Transform:SetPosition(pt.x,0,pt.z)

        generateloot(_current_stash)
    end
    return _current_stash
end

function self:ClearCurrentStash()
    if _current_stash then    
        _current_stash = nil
    end
end

function self:SpawnPirates(pt)
    local shipdata = spawnpirateship(pt)
    self:SaveShipData(shipdata)
end

--self.ScheduleSpawn = ScheduleSpawn

function self:DoMonkeyChange(player, returnFromMonkey)
    --assert(self.SwapData[player.userid],"No Swapdata for userid")
    assert(not returnFromMonkey or self.SwapData[player.userid].oldprefab,"No SwapData of old prefab to return to")
    
    local prefab = "wonkey"

    if returnFromMonkey then
        prefab = self.SwapData[player.userid].oldprefab
    end

    local equippedslots = {}
    if player.components.inventory then
        for k,v in pairs(player.components.inventory.equipslots) do
            table.insert(equippedslots,v)
        end
    end

    local ents = player.components.inventory:FindItems(function(item) return item:HasTag("cursed") end)
    for i,ent in ipairs(ents)do
        ent:RemoveTag("applied_curse")
        ent.components.curseditem.cursed_target = nil
        ent:StopUpdatingComponent(ent.components.curseditem)
    end

    player:PushEvent("ms_playerreroll") -- remove stuff the old character might have had in the world.
    self._savedata[player.userid] = player:SaveForReroll() -- save some stuff.
    --self.SwapData[player.userid] = {oldplayer = player, equippedslots = equippedslots, activeitem = player.components.inventory.activeitem, clothing_body = clothing_body}
    if player.components.inventory.activeitem then
        player.components.inventory:DropActiveItem()
    end
 
    local clothing = player.components.skinner:GetClothing()
    local skin_base = clothing.base

    if returnFromMonkey then
        skin_base = self.SwapData[player.userid] and self.SwapData[player.userid].skin_base or skin_base
    else
        skin_base = self.SwapData[player.userid] and self.SwapData[player.userid].skin_base_monkey or skin_base
    end

    local clothing_body = clothing.body
    local clothing_hand = clothing.hand
    local clothing_legs = clothing.legs
    local clothing_feet = clothing.feet
    
    self.SwapData[player.userid] = {oldplayer = player, equippedslots = equippedslots, activeitem = player.components.inventory.activeitem}
    
    if returnFromMonkey then    
        self.SwapData[player.userid].skin_base_monkey = skin_base
    else
        self.SwapData[player.userid].skin_base = skin_base
    end
    TheNet:SpawnSeamlessPlayerReplacement(player.userid, prefab, skin_base, clothing_body, clothing_hand, clothing_legs, clothing_feet)
end

local GRACETIME = 10

function self:OnUpdate(dt)

    local mindist = math.huge

    for i, v in ipairs(_activeplayers) do
        if not v.components.health:IsDead() and not TheWorld.Map:IsVisualGroundAtPoint(v.Transform:GetWorldPosition()) then
            if not _lasttic_players[v] then
                _lasttic_players[v] = {time=0, dist=math.huge} 
            else
                if _lasttic_players[v].time < GRACETIME then
                    _lasttic_players[v].time = _lasttic_players[v].time + dt
                end
                if _lasttic_players[v].time > GRACETIME then
                    _lasttic_players[v].dist = self.queen:GetDistanceSqToInst(v)
                    if _lasttic_players[v].dist < mindist then
                        mindist = _lasttic_players[v].dist
                    end
                end
            end
        else
            if _lasttic_players[v] then
                _lasttic_players[v] = nil
            end
        end
    end

    for i,band in ipairs(zones) do
        if band.max * band.max > mindist then
            _nextpiratechance = _nextpiratechance - (dt * band.weight)

            if _nextpiratechance <= 0 then
                local weights = {}
                local total = 0
                for char, i in pairs(_lasttic_players) do
                    for t,zone in ipairs(zones) do
                        if zone.max * zone.max > i.dist then
                            table.insert(weights,{char = char, weight = zone.weight, chance = zone.chance}) 
                            total = total + zone.weight
                            break
                        end
                    end
                end

                local choice = math.random(1,total)
                local count = 0
                for i,data in ipairs(weights) do
                    count = count + data.weight
                    if count >= choice then
                        if math.random() < data.chance * TUNING.PIRATE_RAIDS_CHANCE_MODIFIER then
                            SpawnPiratesForPlayer(data.char)
                        end
                        break
                    end
                end

                _nextpiratechance = getnextmonkeytime()
            end
            
            break
        end
    end

    local members = {}
    for i, ship in ipairs(self.shipdatas) do
        if ship.captain then
            table.insert(members,ship.captain)
        end
        for i,crew in ipairs(ship.crew)do
            table.insert(members,crew)
        end
    end

    for i, v in ipairs(_activeplayers) do
        local pirates_near = false
        for i,member in ipairs(members) do
            if member:IsValid() and not member.components.health:IsDead() then
                if v:GetDistanceSqToInst(member) < 40*40 then
                    pirates_near = true
                end
            end
        end
        if pirates_near then
            if not v.piratesnear then
                v.piratesnear = true
                v._piratemusicstate:set(true)
            end
        else
            if v.piratesnear then
                v._piratemusicstate:set(false)
            end
            v.piratesnear = nil
        end
    end
end

--------------------------------------------------------------------------
--[[ Save/Load ]]
--------------------------------------------------------------------------

function self:SaveShipData(shipdata)
    table.insert(self.shipdatas,shipdata)
end

function self:RemoveShipData(ship)
    local id = nil
    for i,set in ipairs(self.shipdatas)do
        if set.boat == ship then
            id = i
            break
        end
    end
    if id then
        table.remove(self.shipdatas,id)
    end
end

function self:OnSave()
    local data =
    {
        maxpirates = _maxpirates,
        minspawndelay = _minspawndelay,
        maxspawndelay = _maxspawndelay,
        nextpiratechance = _nextpiratechance,
    }
    local ents = {}
    data.shipdatas ={}

    for k,v in ipairs(self.shipdatas) do
        local shipdata = {}
        if v.boat:IsValid() then
            shipdata.boat = v.boat.GUID
            table.insert(ents, v.boat.GUID)
        end
        
        if v.captain and v.captain:IsValid() then
            shipdata.captain = v.captain.GUID
            table.insert(ents, v.captain.GUID)
        end

        shipdata.crew = {}
        for i,crew in ipairs(v.crew)do
            if crew:IsValid() then
                table.insert(shipdata.crew,crew.GUID)
                table.insert(ents, crew.GUID)
            end
        end
        table.insert(data.shipdatas,shipdata)
    end
    data._scheduledtask = GetTaskRemaining(_scheduledtask)

    data.playerdata = self._savedata
    data.swapdata = self.SwapData

    return data,ents
end

function self:OnLoad(data)
    _maxpirates = data.maxpirates or TUNING.PIRATE_SPAWN_MAX
    _nextpiratechance = data.nextpiratechance or getnextmonkeytime()
    if data.playerdata then
        self._savedata = data.playerdata
    end
    if data.swapdata then
        self.SwapData = data.swapdata
    end
end

function self:LoadPostPass(newents, savedata)
    if savedata and savedata.shipdatas then
        for k,v in ipairs(savedata.shipdatas) do
            local shipdata = {}
            if v.boat then
                local boat = newents[v.boat].entity
                if boat then
                    shipdata.boat = boat
                    setpirateboat(boat)
                end
            end
            if v.captain then
                local captain = newents[v.captain].entity
                
                if captain then
                    shipdata.captain = captain
                    setcaptain(captain,shipdata.boat)
                end
            end
            shipdata.crew = {}
            for i,crew in ipairs(v.crew) do
                local crewmember = newents[crew].entity
                if crewmember then
                    table.insert(shipdata.crew,crewmember)
                    setcrewmember(crewmember,shipdata.boat)
                end
            end
            self:SaveShipData(shipdata)
        end
    end
end

--------------------------------------------------------------------------
--[[ Debug ]]
--------------------------------------------------------------------------

function self:GetDebugString()

end

end)
