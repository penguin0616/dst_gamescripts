require("behaviours/chaseandattack")
require("behaviours/faceentity")
require("behaviours/leash")
require("behaviours/wander")

local SharkboiBrain = Class(Brain, function(self, inst)
	Brain._ctor(self, inst)
end)

local function GetTarget(inst)
	return inst.components.combat.target
end

local function IsTarget(inst, target)
	return inst.components.combat:TargetIs(target)
end

local function GetTargetPos(inst)
	local target = GetTarget(inst)
	return target and target:GetPosition() or nil
end

function SharkboiBrain:OnStart()
	local root = PriorityNode({
		WhileNode(
			function()
				return not self.inst.sg:HasStateTag("jumping")
			end,
			"<busy state guard>",
			PriorityNode({
				WhileNode(function() return self.inst.components.combat:InCooldown() end, "Chase",
					PriorityNode({
						FailIfSuccessDecorator(
							Leash(self.inst, GetTargetPos, TUNING.SHARKBOI_MELEE_RANGE, 3, true)),
						FaceEntity(self.inst, GetTarget, IsTarget),
					}, 0.5)),
				ParallelNode{
					ConditionWaitNode(function()
						local target = self.inst.components.combat.target
						if target and not self.inst.components.combat:InCooldown() and
							self.inst:IsNear(target, TUNING.SHARKBOI_ATTACK_RANGE + target:GetPhysicsRadius(0))
						then
							self.inst.components.combat.ignorehitrange = true
							self.inst.components.combat:TryAttack(target)
							self.inst.components.combat.ignorehitrange = false
						end
						return false
					end),
					ChaseAndAttack(self.inst),
				},
				Wander(self.inst),
			}, 0.5)),
	}, 0.5)

	self.bt = BT(self.inst, root)
end

return SharkboiBrain
