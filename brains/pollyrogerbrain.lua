require "behaviours/follow"
require "behaviours/wander"
require "behaviours/faceentity"
require "behaviours/panic"
require "behaviours/standstill"


local MIN_FOLLOW_DIST = 0
local MAX_FOLLOW_DIST = 8
local TARGET_FOLLOW_DIST = 6

local MAX_WANDER_DIST = 3

local PICKUP_RANGE = 15

local STOP_RUN_DIST = 10
local SEE_MONSTER_DIST = 5
local AVOID_MONSTER_DIST = 3
local AVOID_MONSTER_STOP = 6

local PICKUP_MUST_HAVE = { "_inventoryitem" }
local PICKUP_MUST_NOT_HAVE = { "INLIMBO", "NOCLICK", "knockbackdelayinteraction", "catchable", "fire", "minesprung", "mineactive", "spider" ,"trap" }

local MATCH_MIN_FOLLOW_DIST = 2
local MATCH_TARGET_FOLLOW_DIST = 2
local MATCH_MAX_FOLLOW_DIST = 7

local function PickUpAction(inst)

    if not inst.readytogather then
        return
    end

    if inst.components.inventory:IsFull() then
        return nil
    end

    local target = nil

    local leader = inst.components.follower and inst.components.follower.leader
    if leader then
        local x,y,z = leader.Transform:GetWorldPosition()
        local ents = TheSim:FindEntities(x, y, z, PICKUP_RANGE, PICKUP_MUST_HAVE, PICKUP_MUST_NOT_HAVE)
        if #ents >0 then
            for i=#ents,1,-1 do
                local ent = ents[i]
                if  not ent.components.inventoryitem or
                    not ent.components.inventoryitem.canbepickedup or
                    not ent.components.inventoryitem.cangoincontainer or
                    ent.components.inventoryitem:IsHeld() or
                    leader.components.inventory:CanAcceptCount(ent, 1) <= 0 then
                
                    table.remove(ents,i)
                end
            end
        end
        if #ents > 0 then
            target = ents[#ents]
        end
    end

    return target ~= nil and BufferedAction(inst, target, ACTIONS.PICKUP) or nil
end

local function GiveAction(inst)

    local leader = inst.components.follower and inst.components.follower.leader

    local item = inst.components.inventory:GetItemInSlot(1)
   
    return leader ~= nil and item ~= nil and BufferedAction(inst, leader, ACTIONS.GIVE, item ) or nil
end

local function closetoleader(inst)
    if inst.sg:HasStateTag("busy") then
        return nil
    end
    local leader = inst.components.follower and inst.components.follower.leader
    if leader and leader:GetDistanceSqToInst(inst) < PICKUP_RANGE * PICKUP_RANGE then
        return true
    end
end


local PollyRogerBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

function PollyRogerBrain:OnStart()
    local root =
    PriorityNode(
    {

        WhileNode( function() return not self.inst.sg:HasStateTag("busy") and not self.inst.flyaway end, "NO BRAIN WHEN BUSY",
            PriorityNode({
                WhileNode( function() return self.inst.components.hauntable and self.inst.components.hauntable.panic end, "PanicHaunted", Panic(self.inst)),
                WhileNode( function() return self.inst.components.health.takingfiredamage end, "OnFire", Panic(self.inst)),
                RunAway(self.inst, "hostile", AVOID_MONSTER_DIST, AVOID_MONSTER_STOP),
                RunAway(self.inst, "hostile", SEE_MONSTER_DIST, STOP_RUN_DIST, nil, true),
                WhileNode( function() return closetoleader(self.inst) end, "Stayclose",
                    PriorityNode({
                        DoAction(self.inst, PickUpAction, nil, true),
                        DoAction(self.inst, GiveAction, nil, true),
                    },.25)),
                Follow(self.inst, function() return self.inst.components.follower.leader end, MIN_FOLLOW_DIST, TARGET_FOLLOW_DIST, MAX_FOLLOW_DIST),
                StandStill(self.inst),
            }, .25)
        ),
    }, .25)
    self.bt = BT(self.inst, root)
end

return PollyRogerBrain