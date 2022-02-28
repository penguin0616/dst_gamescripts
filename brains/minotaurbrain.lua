require "behaviours/standstill"
require "behaviours/runaway"
require "behaviours/doaction"
require "behaviours/panic"
require "behaviours/chaseandram"

local START_FACE_DIST = 14
local KEEP_FACE_DIST = 16
local GO_HOME_DIST = 40
local MAX_CHASE_TIME = 5
local MAX_CHARGE_DIST = 25
local CHASE_GIVEUP_DIST = 10
local RUN_AWAY_DIST = 5
local STOP_RUN_AWAY_DIST = 15

local MAX_JUMP_ATTACK_RANGE = 15

local MinotaurBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

local function GoHomeAction(inst)
    if inst.components.combat.target ~= nil then
        return
    end
    local homePos = inst.components.knownlocations:GetLocation("home")
    return homePos ~= nil
        and BufferedAction(inst, nil, ACTIONS.WALKTO, nil, homePos, nil, .2)
        or nil
end

local function GetFaceTargetFn(inst)
    local homePos = inst.components.knownlocations:GetLocation("home")
    if homePos ~= nil and inst:GetDistanceSqToPoint(homePos:Get()) > GO_HOME_DIST * GO_HOME_DIST then
        return
    end
    local target = FindClosestPlayerToInst(inst, START_FACE_DIST, true)
    return target ~= nil and not target:HasTag("notarget") and target or nil
end

local function KeepFaceTargetFn(inst, target)
    local homePos = inst.components.knownlocations:GetLocation("home")
    return (homePos == nil or
            inst:GetDistanceSqToPoint(homePos:Get()) <= GO_HOME_DIST * GO_HOME_DIST)
        and not target:HasTag("notarget")
        and inst:IsNear(target, KEEP_FACE_DIST)
end

local function ShouldGoHome(inst)
    local homePos = inst.components.knownlocations:GetLocation("home")
    if homePos == nil then
        return false
    end
    local dist_sq = inst:GetDistanceSqToPoint(homePos:Get())
    return dist_sq > GO_HOME_DIST * GO_HOME_DIST
        or (dist_sq > CHASE_GIVEUP_DIST * CHASE_GIVEUP_DIST and
            inst.components.combat.target == nil)
end

local PILLAR_HASTAG = {"quake_on_charge"}

local function shouldjumpattack(inst)
    if inst.components.health:GetPercent() > 0.6 then
        return false
    end

    if inst.sg:HasStateTag("busy") or inst.sg:HasStateTag("running") then
        return false
    end

    if inst.components.timer:TimerExists("stunned") then
        return false
    end        

    if inst.components.combat.target then
        local target = inst.components.combat.target
        if target then
            if target:IsValid() then
                local x,y,z = inst.Transform:GetWorldPosition()
                local ents = TheSim:FindEntities(x,y,z,  MAX_JUMP_ATTACK_RANGE, PILLAR_HASTAG)
                
                local targetdist = inst:GetDistanceSqToInst(target)

                if #ents > 0 then
                    for i,ent in ipairs(ents)do
                        local dist = inst:GetDistanceSqToInst(ent)
                        local p1 = Vector3(ent.Transform:GetWorldPosition())
                        local p2 = Vector3(target.Transform:GetWorldPosition())
                        if dist < targetdist then
                            local diff = anglediff(inst:GetAngleToPoint(p1), inst:GetAngleToPoint(p2) )
                            if diff < 90 then
                                return false
                            end
                        end
                    end
                end

                local combatrange = inst.components.combat:CalcAttackRangeSq(target)
                
                if targetdist > combatrange and targetdist < MAX_JUMP_ATTACK_RANGE * MAX_JUMP_ATTACK_RANGE then
                    return true
                end
            end
        end
    end
    return false
end

local function dojumpAttack(inst)
    if inst.components.combat.target and not inst.sg:HasStateTag("leapattack") then
        local target = inst.components.combat.target
        inst:FacePoint(target.Transform:GetWorldPosition())
        inst:PushEvent("doleapattack", {target=target})
    end
end

local function closetopillar(inst)
    local x,y,z = inst.Transform:GetWorldPosition()
      
    local ents = TheSim:FindEntities(x,y,z, 4, PILLAR_HASTAG)
    if #ents > 0 then
        return true
    end
end

function MinotaurBrain:OnStart()

    local root = PriorityNode(
    {
        WhileNode( function() return not self.inst.sg:HasStateTag("leapattack") end, "not jumping",
            PriorityNode{             
                WhileNode(function() return shouldjumpattack(self.inst) end, "JumpAttack", 
                    DoAction(self.inst, function() return dojumpAttack(self.inst) end, "jump", true)),

                WhileNode(function() return self.inst.components.combat.target ~= nil 
                                    and (self.inst.sg:HasStateTag("running") or not self.inst.components.combat.target:IsNear(self.inst, 5)) 
                                    and not self.inst.sg:HasStateTag("leapattack") 
                                    and not closetopillar(self.inst)
                             end, "RamAttack", 
                    ChaseAndRam(self.inst, MAX_CHASE_TIME, CHASE_GIVEUP_DIST, MAX_CHARGE_DIST)),

                ChaseAndAttack(self.inst, 3, 10, nil, nil, true ),

                WhileNode(function() return self.inst.components.combat.target ~= nil and self.inst.components.combat:InCooldown() end, "Rest",
                    StandStill(self.inst)),
                WhileNode(function() return self.inst.components.hauntable ~= nil and self.inst.components.hauntable.panic end, "PanicHaunted", Panic(self.inst)),
                WhileNode(function() return self.inst.components.health.takingfiredamage end, "OnFire", Panic(self.inst)),
                WhileNode(function() return ShouldGoHome(self.inst) end, "ShouldGoHome",
                    DoAction(self.inst, GoHomeAction, "Go Home", false)),
                FaceEntity(self.inst, GetFaceTargetFn, KeepFaceTargetFn),
                StandStill(self.inst)
        }, 1)
    }, .25)

    self.bt = BT(self.inst, root)
end

return MinotaurBrain
