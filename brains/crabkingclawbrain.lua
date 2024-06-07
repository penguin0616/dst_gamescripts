require "behaviours/chaseandattack"
require "behaviours/runaway"
require "behaviours/wander"
require "behaviours/doaction"
require "behaviours/attackwall"
require "behaviours/panic"
require "behaviours/minperiod"
require "behaviours/leash"
require "behaviours/standandattack"
require "behaviours/leashandavoid"

local WAMDER_DIST = 2
local LEASH_DIST = 18
local TARGET_LEASH_DIST = 6
local CREABKING_RADIUS = 5.5

local function findavoidanceobjectfn(inst)
    if inst.crabking then
        return inst.crabking
    end
end

local function ShouldAttack(self)
    if self.inst.components.combat:InCooldown() then
        return 
    end
    local target = self.inst.components.combat.target
    if not target then
        return nil
    end

    local x, y, z = self.inst.Transform:GetWorldPosition()
    local tx, ty, tz = target.Transform:GetWorldPosition()
    local range = self.inst.components.combat.attackrange

    if VecUtil_LengthSq(x - tx, z - tz) > range * range then
        return false
    end

    return true
end

local CrabkingClawBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

function CrabkingClawBrain:OnStart()
    local root = PriorityNode(
    {

        WhileNode(function() return ShouldAttack(self) end, nil, StandAndAttack(self.inst)),
        --Leash(self.inst, function() return self.inst.components.knownlocations:GetLocation("spawnpoint") end, LEASH_DIST*2, LEASH_DIST, false),


        LeashAndAvoid(self.inst, findavoidanceobjectfn, CREABKING_RADIUS,  function() return self.inst.components.combat.target and Vector3(self.inst.components.combat.target.Transform:GetWorldPosition())  end, LEASH_DIST, 5, false),

        LeashAndAvoid(self.inst, findavoidanceobjectfn, CREABKING_RADIUS, function() return self.inst.components.combat.target and Vector3(self.inst.components.combat.target.Transform:GetWorldPosition())  end, TARGET_LEASH_DIST, 5, false),
        Wander(self.inst, function() return self.inst.components.knownlocations:GetLocation("spawnpoint") end, WAMDER_DIST,
            {
                minwalktime=0.5,
                randwalktime=0.5,
                minwaittime=1,
                randwaittime=5,
            }
        )

    }, 0.2)

    self.bt = BT(self.inst, root)
end

function CrabkingClawBrain:OnInitializationComplete()
    self.inst.components.knownlocations:RememberLocation("spawnpoint", Point(self.inst.Transform:GetWorldPosition()))
end

return CrabkingClawBrain
