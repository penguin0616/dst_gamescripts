require "behaviours/chaseandattack"
require "behaviours/panic"
require "behaviours/attackwall"
require "behaviours/leash"
require "behaviours/standstill"

local WORK_DIST = 3 --must be greater than physics radii
local LOST_DIST = 60
local RETURN_DIST = 15
local BASE_DIST = 6

local LOST_TIME = 5
local AGGRO_TIME = 6
local PETRIFY_TIME = 3
local PETRIFY_TIME_VAR = 1

local BirdMutantBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
    self._losttime = nil
    self._petrifytime = nil
end)

local function GetSwarmTarget(inst)
    return inst.components.entitytracker:GetEntity("swarmTarget")
end

local function LostSwarmTarget(self)
    local target = GetSwarmTarget(self.inst)
    if target ~= nil and self.inst:IsNear(target, LOST_DIST) then
        self._losttime = nil
        return false
    elseif self._losttime == nil then
        self._losttime = GetTime()
        return false
    end
    return GetTime() - self._losttime > LOST_TIME
end

local function ShouldTargetAttackTarget(inst)
    local target = GetSwarmTarget(inst)
    return target ~= nil
        and target:HasTag("moonstorm_static")
        and GetTime() - inst.components.combat:GetLastAttackedTime() > AGGRO_TIME
end

local function GetSwarmTargetPos(inst)
    local target = GetSwarmTarget(inst)
    return target ~= nil and target:GetPosition() or nil
end

local function CanBirdAttack(inst)
    if inst.components.combat:InCooldown() or inst.sg:HasStateTag("busy") then
        return nil
    end
    local target = GetSwarmTarget(inst)
    if target then
        local dist = inst:GetDistanceSqToInst(target)
        if dist <= inst.components.combat.attackrange *inst.components.combat.attackrange then
            return target
        end
    end
    local x,y,z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x,y,z, inst.components.combat.attackrange)
    local potentials = {}
    for i, ent in ipairs(ents) do
        if ent:HasTag("player") or (ent.components.follower and ent.components.follower:GetLeader() and ent.components.follower:GetLeader():HasTag("player")) then
            table.insert(potentials,ent)
        end
    end
    if #potentials > 0 then
        return potentials[math.random(1,#potentials)]
    end
end

local function AttackTarget(inst)
    local target = CanBirdAttack(inst)
    if target then
        inst.components.combat.target = target
        inst:PushEvent("doattack")
    end
end

local function AttackInvadeTarget(inst)
    --inst:PushEvent("workmoonbase", { invadetarget = GetSwarmTarget(inst) })
end

local BREAKSKELETONS_MUST_TAGS = { "playerskeleton", "HAMMER_workable" }
local function BreakSkeletons(inst)
    local skel = FindEntity(inst, 1.25, nil, BREAKSKELETONS_MUST_TAGS)
    if skel ~= nil then
        skel.components.workable:WorkedBy(inst, 1)
    end
end

local function shouldspit(inst)
	if inst:HasTag("bird_mutant_spitter") then
	    if inst.components.combat.target and inst.components.combat.target:IsValid() and inst:GetDistanceSqToInst(inst.components.combat.target) <= TUNING.MUTANT_BIRD_SPIT_RANGE * TUNING.MUTANT_BIRD_SPIT_RANGE and not inst.components.timer:TimerExists("spit_cooldown") then
	    	return true
	    end
	end
end

local function spit(inst)
	local act = BufferedAction(inst, inst.components.combat.target, ACTIONS.TOSS)
    return act
end

local function shouldwaittospit(inst)
	if inst:HasTag("bird_mutant_spitter") then
	    if inst.components.combat.target and inst.components.combat.target:IsValid() then
	    	if inst:GetDistanceSqToInst(inst.components.combat.target) <= 4*4 then
	    		return true
	    	end
	    end
	end
end

function BirdMutantBrain:OnStart()
    local root = PriorityNode(
    {

        WhileNode(function() return self.inst.components.hauntable ~= nil and self.inst.components.hauntable.panic end, "PanicHaunted", Panic(self.inst)),
        WhileNode(function() return self.inst.components.health.takingfiredamage end, "OnFire", Panic(self.inst)),

        --Teleported away, or moonbase got removed
    --    WhileNode(function() return LostSwarmTarget(self) end, "Lost Target",
    --        ActionNode(function() self.inst.components.health:Kill() end)),

        WhileNode(function() return shouldspit(self.inst) end, "Spit",
        	DoAction(self.inst, spit)),

        IfNode(function() return shouldwaittospit(self.inst) end, "waittospit",
        	StandStill(self.inst)),

        SequenceNode{
            ActionNode(function() BreakSkeletons(self.inst) end),
            AttackWall(self.inst),
            ActionNode(function() self.inst.components.combat:ResetCooldown() end),
        },


        IfNode(function() return CanBirdAttack(self.inst) end, "Attack",
            ActionNode(function() AttackTarget(self.inst) end)),
--[[
        WhileNode(function() return ShouldTargetAttackTarget(self.inst) end, "InvadeTarget",
            PriorityNode({
                ChaseAndAttack(self.inst, 100),
                --Leash(self.inst, function() return GetInvadeTarget(self.inst):GetPosition() end, WORK_DIST, WORK_DIST),
                --ActionNode(function() AttackInvadeTarget(self.inst) end),
                --StandStill(self.inst),
            })),
]]
--        ChaseAndAttack(self.inst, 100),
        IfNode(function() return GetSwarmTargetPos(self.inst) end, "move to target",
            Leash(self.inst, GetSwarmTargetPos, RETURN_DIST, BASE_DIST)),
        IfNode(function() return GetSwarmTargetPos(self.inst) end, "stand near target",
            StandStill(self.inst)),
       -- Wander(self.inst)
        Panic(self.inst),
    }, .25)

    self.bt = BT(self.inst, root)
end

return BirdMutantBrain
