require "behaviours/doaction"
require "behaviours/leash"
require "behaviours/panic"
require "behaviours/runaway"
require "behaviours/wander"

local AVOID_PLAYER_DIST = 3
local AVOID_PLAYER_DIST_SQ = AVOID_PLAYER_DIST * AVOID_PLAYER_DIST
local AVOID_PLAYER_STOP = 5

local SEE_BAIT_MINDIST = 6
local SEE_BAIT_MAXDIST = 20
local MAX_WANDER_DIST = 16

local CarratBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

local function GetLeader(inst)
    return inst.components.follower and inst.components.follower:GetLeader() or nil
end

local function GetLeaderLocation(inst)
    local leader = GetLeader(inst)
    if leader == nil then
        return nil
    end

    return leader:GetPosition()
end

local function ShouldRunFromScary(other, inst)
    local isplayer = other:HasTag("player")
    if isplayer and GetLeader(inst) == other then
        return false
    end

    local isplayerpet = isplayer and other.components.petleash and other.components.petleash:IsPet(inst)
    return (isplayer or isplayerpet) and TheNet:GetPVPEnabled()
end

local function IsItemEdible(inst, item)
    return inst.components.eater ~= nil and inst.components.eater:CanEat(item) and item.components.bait and not item:HasTag("planted") and
            not (item.components.inventoryitem and item.components.inventoryitem:IsHeld()) and
            item:IsOnPassablePoint() and
            item:GetCurrentPlatform() == inst:GetCurrentPlatform()
end

local FOOD_CANT_TAGS = {"INLIMBO"}

local function GatherFood(inst)
    local leader = GetLeader(inst)
    if leader == nil then
        -- No leader, do not gather.
        return nil
    end

    local px, py, pz = inst.Transform:GetWorldPosition()

    local ents_nearby = TheSim:FindEntities(px, py, pz, SEE_BAIT_MAXDIST + AVOID_PLAYER_DIST, nil, FOOD_CANT_TAGS)

    local foods = nil
    local scaries = nil
    for _, ent in ipairs(ents_nearby) do
        if ent ~= inst and ent ~= leader then
            if ent:HasTag("scarytoprey") then
                if ShouldRunFromScary(ent, inst) then
                    scaries = scaries or {}
                    table.insert(scaries, ent)
                end
            elseif IsItemEdible(leader, ent) and not ent:IsNear(leader, SEE_BAIT_MINDIST) then
                foods = foods or {}
                table.insert(foods, ent)
            end
        end
    end

    if foods == nil then
        return nil
    end

    local target = nil
    if scaries == nil then
        target = foods[1]
    else
        -- We have at least 1 food and at least 1 scary thing in range.
        -- Try to find a food that doesn't come within AVOID_PLAYER_DIST of a scary thing.
        for fi = 1, #foods do
            local food = foods[fi]
            local scary_thing_nearby = false

            for si = 1, #scaries do
                local scary_thing = scaries[si]
                local sq_distance = food:GetDistanceSqToPoint(scary_thing.Transform:GetWorldPosition())
                if sq_distance < AVOID_PLAYER_DIST_SQ then
                    scary_thing_nearby = true
                    break
                end
            end

            if not scary_thing_nearby then
                target = food
                break
            end
        end
    end

    if target then
        if not inst.components.timer:TimerExists("mutantproxy_food_gathering") and not inst.components.inventory:IsFull() then
            local act = BufferedAction(inst, target, ACTIONS.PICKUP)
            act.validfn = function() return not (target.components.inventoryitem and target.components.inventoryitem:IsHeld()) end
            return act
        end
    end
end

local function drop_item_action(inst)
    local leader = GetLeader(inst)
    local item = inst.components.inventory:GetFirstItemInAnySlot() 
    if item then
        if inst.components.timer:TimerExists("mutantproxy_food_gathering") then
            inst.components.timer:SetTimeLeft("mutantproxy_food_gathering", TUNING.WORMWOOD_PET_CARRAT_GATHER_COOLDOWN)
        else
            inst.components.timer:StartTimer("mutantproxy_food_gathering", TUNING.WORMWOOD_PET_CARRAT_GATHER_COOLDOWN)
        end

        local ba = BufferedAction(inst, leader, ACTIONS.DROP, item)
        ba.options.wholestack = true
        return ba
    end
end

local NORMAL_RUNAWAY_DATA = {tags = {"scarytoprey"}, notags = {"carratcrafter"}, fn = ShouldRunFromScary}
function CarratBrain:OnStart()
    local root = PriorityNode(
    {
        WhileNode( function() return (self.inst.components.health ~= nil and self.inst.components.health.takingfiredamage) or (self.inst.components.burnable ~= nil and self.inst.components.burnable:IsBurning()) end, "OnFire",
			Panic(self.inst)),

        WhileNode( function() return self.inst.components.hauntable and self.inst.components.hauntable.panic end, "PanicHaunted",
			Panic(self.inst)),

        RunAway(self.inst, NORMAL_RUNAWAY_DATA, AVOID_PLAYER_DIST, AVOID_PLAYER_STOP),
        DoAction(self.inst, GatherFood, "Gather Food"),
        WhileNode(function() return GetLeader(self.inst) ~= nil end, "Has Leader",
            PriorityNode({
                WhileNode(function() return self.inst.components.inventory:GetFirstItemInAnySlot() ~= nil end, "Has Any Item",
                    DoAction(self.inst, drop_item_action, "Drop Item For Leader", true, 0.5 * TUNING.WORMWOOD_PET_CARRAT_GATHER_COOLDOWN)
                ),
                Leash(self.inst, GetLeaderLocation, MAX_WANDER_DIST, 8, true),
            }, .25)
        ),
        Wander(self.inst, GetLeaderLocation, MAX_WANDER_DIST),
    }, .25)
    self.bt = BT(self.inst, root)
end

return CarratBrain
