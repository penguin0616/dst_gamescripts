require "behaviours/wander"
require "behaviours/runaway"
require "behaviours/doaction"
require "behaviours/panic"
require "behaviours/chaseandattack"
require "behaviours/leash"

local MIN_FOLLOW_DIST = 5
local TARGET_FOLLOW_DIST = 7
local MAX_FOLLOW_DIST = 10
 
local RETURN_DIST = 4 
local BASE_DIST = 2

local RUN_AWAY_DIST = 7
local STOP_RUN_AWAY_DIST = 15

local SEE_FOOD_DIST = 10

local MAX_WANDER_DIST = 20

local MAX_CHASE_TIME = 60
local MAX_CHASE_DIST = 40

local TIME_BETWEEN_EATING = 30

local LEASH_RETURN_DIST = 15
local LEASH_MAX_DIST = 20

local NO_LOOTING_TAGS = { "INLIMBO", "catchable", "fire", "irreplaceable", "heavy", "outofreach", "spider" }
local NO_PICKUP_TAGS = deepcopy(NO_LOOTING_TAGS)
table.insert(NO_PICKUP_TAGS, "_container")

local PICKUP_ONEOF_TAGS = { "_inventoryitem", "pickable", "readyforharvest" }

local PowderMonkeyBrain_test = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

local function GetPoop(inst)
    if inst.sg:HasStateTag("busy") then
        return
    end

    local target = FindEntity(inst,
        SEE_FOOD_DIST,
        function(item)
            return item.prefab == "poop"
                and not item:IsNear(inst.components.combat.target, RUN_AWAY_DIST)
                and item:IsOnValidGround()
        end,
        nil,
        NO_PICKUP_TAGS
    )

    return target ~= nil and BufferedAction(inst, target, ACTIONS.PICKUP) or nil
end

local ValidFoodsToPick =
{
    "berries",
    "cave_banana",
    "carrot",
    "red_cap",
    "blue_cap",
    "green_cap",
}

local function ItemIsInList(item, list)
    for k, v in pairs(list) do
        if v == item or k == item then
            return true
        end
    end
end

local function SetCurious(inst)
    inst._curioustask = nil
    inst.curious = true
end

local function EatFoodAction(inst)
    if inst.sg:HasStateTag("busy") or
        (inst.components.eater:TimeSinceLastEating() ~= nil and inst.components.eater:TimeSinceLastEating() < TIME_BETWEEN_EATING) or
        (inst.components.inventory ~= nil and inst.components.inventory:IsFull()) or
        math.random() < .75 then
        return
    elseif inst.components.inventory ~= nil and inst.components.eater ~= nil then
        local target = inst.components.inventory:FindItem(function(item) return inst.components.eater:CanEat(item) end)
        if target ~= nil then
            return BufferedAction(inst, target, ACTIONS.EAT)
        end
    end

    --Get the stuff around you and store it in ents
    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, SEE_FOOD_DIST,
        nil,
        NO_PICKUP_TAGS,
        PICKUP_ONEOF_TAGS)

    --If you're not wearing a hat, look for a hat to wear!
    if inst.components.inventory ~= nil and inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD) == nil then
        for i, item in ipairs(ents) do
            if item.components.equippable ~= nil and
                item.components.equippable.equipslot == EQUIPSLOTS.HEAD and
                item.components.inventoryitem ~= nil and
                item.components.inventoryitem.canbepickedup and
                item:IsOnValidGround() then
                return BufferedAction(inst, item, ACTIONS.PICKUP)
            end
        end
    end

    --Look for food on the ground, pick it up
    for i, item in ipairs(ents) do
        if item:GetTimeAlive() > 8 and
            item.components.inventoryitem ~= nil and
            item.components.inventoryitem.canbepickedup and
            inst.components.eater:CanEat(item) and
            item:IsOnValidGround() then
            return BufferedAction(inst, item, ACTIONS.PICKUP)
        end
    end

    --Look for harvestable items, pick them.
    for i, item in ipairs(ents) do
        if item.components.pickable ~= nil and
            item.components.pickable.caninteractwith and
            item.components.pickable:CanBePicked() and
            (item.prefab == "worm" or ItemIsInList(item.components.pickable.product, ValidFoodsToPick)) then
            return BufferedAction(inst, item, ACTIONS.PICK)
        end
    end

    --Look for crops items, harvest them.
    for i, item in ipairs(ents) do
        if item.components.crop ~= nil and
            item.components.crop:IsReadyForHarvest() then
            return BufferedAction(inst, item, ACTIONS.HARVEST)
        end
    end

    if not inst.curious or inst.components.combat:HasTarget() then
        return
    end

    ---At the very end, look for a random item to pick up and do that.
    for i, item in ipairs(ents) do
        if item.components.inventoryitem ~= nil and
            item.components.inventoryitem.canbepickedup and
            item:IsOnValidGround() then
            inst.curious = false
            if inst._curioustask ~= nil then
                inst._curioustask:Cancel()
            end
            inst._curioustask = inst:DoTaskInTime(10, SetCurious)
            return BufferedAction(inst, item, ACTIONS.PICKUP)
        end
    end
end

local function OnLootingCooldown(inst)
    inst._canlootcheststask = nil
    inst.canlootchests = true
end

local function GetFaceTargetFn(inst)
    return inst.components.combat.target
end

local function KeepFaceTargetFn(inst, target)
    return target == inst.components.combat.target
end

local function findmaxwanderdistfn(inst)
    local dist = MAX_WANDER_DIST
    local boat = inst:GetCurrentPlatform()
    if boat then
        dist = boat.components.walkableplatform and boat.components.walkableplatform.platform_radius -0.3 or dist
    end
    return dist
end

local function findwanderpointfn(inst)
    local loc = inst.components.knownlocations:GetLocation("home")
    local boat = inst:GetCurrentPlatform()
    if boat then
        loc = Vector3(boat.Transform:GetWorldPosition())
    end
    return loc
end

local function rowboat(inst)

    local pos = inst.rowpos

    local boat = inst:GetCurrentPlatform() == inst.components.crewmember.boat and inst:GetCurrentPlatform()
    if boat and not pos then
        local radius = boat.components.walkableplatform.platform_radius - 0.25 
        pos = Vector3(boat.Transform:GetWorldPosition())

        local offset = FindWalkableOffset(pos, math.random()*2*PI, radius, 12, false,false,nil,false,true)
        if offset then
            pos = pos + offset
        end
    end
    if pos and boat then
        inst.rowpos = pos
        return BufferedAction(inst, nil, ACTIONS.ROW, nil, pos)
 --   else
 --       inst.rowpos = nil
    end
end

local function removemonkey(inst)
    local item = inst.stealitem
    if item then
        item:RemoveTag("piratemonkeyloot")
        item:RemoveEventCallback("onremove", removemonkey, inst)
    end
end

local function inventoryfull(inst)
    if #inst.components.inventory.itemslots >= 4 then
        return true
    end
end

local ITEM_MUST = {"_inventoryitem"}
local ITEM_MUSTNOT = {"INLIMBO", "piratemonkeyloot"}
local function shouldsteal(inst)

    if inventoryfull(inst) then
        return nil
    end

    local x,y,z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, 10, ITEM_MUST,ITEM_MUSTNOT)

    if #ents > 0 then
        for i=#ents,1,-1 do
            if ents[i]:IsOnWater() then
                table.remove(ents,i)
            end
        end
    end

    if #ents > 0 then
--        local item = #ents[1]
--        item:AddTag("piratemonkeyloot")
--        inst.stealitem = item
--        item:ListenForEvent("onremove", removemonkey, inst)

        return true
    end
end

local function reversemastcheck(ent)
    if ent.components.mast and ent.components.mast.inverted and ent:HasTag("saillowered") and  not ent:HasTag("sail_transitioning") then
        return true
    end
end

local function mastcheck(ent)
    if ent.components.mast and ent:HasTag("sailraised") and not ent.components.mast.inverted then --and ent:HasTag("sailraised") and not ent:HasTag("sail_transitioning") then
        return true
    end
end

local function anchorcheck(ent)    
    if ent.components.anchor and ent:HasTag("anchor_raised") and not ent:HasTag("anchor_transitioning") then
        return true
    end
end

local DOTINKER_MUST_HAVE = {"structure"}
local function Dotinker(inst)

    if  inst.components.timer and inst.components.timer:TimerExists("reactiondelay") then
        return nil
    end

    local platform = inst:GetCurrentPlatform()
    local bc = inst.components.crewmember.boat and inst.components.crewmember.boat.components.boatcrew or nil
    local target = nil
    if platform and platform.components.hull and platform ~= inst.components.crewmember.boat and bc then      
       
        local x,y,z = platform.Transform:GetWorldPosition()
        local ents = TheSim:FindEntities(x, y, z, platform.components.hull:GetRadius(),DOTINKER_MUST_HAVE)

        if #ents > 0 then
            for i=#ents,1,-1 do

                local ent = ents[i]
                local keep = false

                if mastcheck(ent) or anchorcheck(ent) or reversemastcheck(ent) then
                    keep = true
                end

                if bc:checktinkertarget(ent) and keep == true then
                    keep = false
                end

                if not keep then
                    table.remove(ents,i)
                end                
            end
        end
        if #ents > 0 then
            target = ents[1]
        end
    end
    if target then
        inst.tinkertarget = target
        bc:reserveinkertarget(target)
        if anchorcheck(target) then
            return BufferedAction(inst, target, ACTIONS.LOWER_ANCHOR)
        end
        if reversemastcheck(target) then
            return BufferedAction(inst, target, ACTIONS.RAISE_SAIL)
        end        
        if mastcheck(target) then
            return BufferedAction(inst, target, ACTIONS.HAMMER)
        end
    end
end


local RETARGET_MUST_TAGS = { "_combat" }
local RETARGET_CANT_TAGS = { "playerghost" }
local RETARGET_ONEOF_TAGS = { "character", "monster" }

local function StealAction(inst)
    --local item = inst.stealitem
    local item = nil
    local x,y,z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, 10, ITEM_MUST,ITEM_MUSTNOT)

    if #ents > 0 then
        for i=#ents,1,-1 do
            if ents[i]:IsOnWater() then
                table.remove(ents,i)
            end
        end
    end

    if #ents > 0 then
        item = ents[1]
    end

    if item then
        return BufferedAction(inst, item, ACTIONS.PICKUP)
    else
        -- NOTING TO PICK UP.. LOOK FOR LOOTABLE TARGET
        local target = FindEntity(
                inst,
                20,
                function(guy)
                    return inst.components.combat:CanTarget(guy)
                end,
                RETARGET_MUST_TAGS, --see entityreplica.lua
                RETARGET_CANT_TAGS,
                RETARGET_ONEOF_TAGS
            )

        if target then
            isnt.components.combat:SetTarget(target)
        end
    end
end

local function ShouldRunFn(inst)
    local platform = inst:GetCurrentPlatform()
    if platform ~= inst.components.crewmember.boat then
        local bc = inst.components.crewmember.boat and inst.components.crewmember.boat.components.boatcrew or nil
        if bc and bc.status == "retreat" then        
            return true
        end
    end
end

local function dorunaway(inst)

end

local function shouldattack(inst)
    local bc = inst.components.crewmember.boat and inst.components.crewmember.boat.components.boatcrew or nil
    if bc and bc.status == "retreat" and inst.components.combat.target then
        if inst.components.combat.target:GetCurrentPlatform() ~= inst:GetCurrentPlatform() then
            return false
        end
    end
    return true
end

function PowderMonkeyBrain_test:OnStart()

    local root = PriorityNode(
    {
        Wander(self.inst, function() return findwanderpointfn(self.inst) end, function() return findmaxwanderdistfn(self.inst) end, {minwalktime=0.2,randwalktime=.8,minwaittime=1,randwaittime=5})
    }, .25)
    self.bt = BT(self.inst, root)
end

return PowderMonkeyBrain_test
