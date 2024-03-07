require("behaviours/chaseandattack")
require("behaviours/faceentity")
require("behaviours/leash")
require("behaviours/standstill")
require("behaviours/wander")

local Daywalker2Brain = Class(Brain, function(self, inst)
	Brain._ctor(self, inst)
	self.lastjunk = nil
end)

local function GetJunk(inst)
	return inst.components.entitytracker:GetEntity("junk")
end

local function GetJunkPos(inst)
	local junk = GetJunk(inst)
	return junk and junk:GetPosition() or nil
end

local function GetTarget(inst)
	return inst.components.combat.target
end

local function GetTargetPos(inst)
	local target = inst.components.combat.target
	return target and target:GetPosition() or nil
end

local function IsTarget(inst, target)
	return inst.components.combat:TargetIs(target)
end

local function ShouldRunToJunk(inst)
	return inst.components.combat:HasTarget()
end

local SWING_ITEMS = { "object" }
local TACKLE_ITEMS = { "spike" }
local CANNON_ITEMS = { "cannon" }
local _temp = {}

local function GetCurrentJunkLoot(inst, ignorerange)
	local junk = GetJunk(inst)
	if junk then
		--Has no equip, or can multiwield and isn't fully equipped yet
		if not (inst.canswing or inst.cantackle or inst.cancannon) or
			(	inst.canmultiwield and
				not (inst.canswing and inst.cantackle and (inst.cancannon or not junk.hascannon)) and
				not inst.components.timer:TimerExists("multiwield")
			)
		then
			local n = 0
			if not inst.canswing then
				for i = 1, #SWING_ITEMS do
					n = n + 1
					_temp[n] = SWING_ITEMS[i]
				end
			end
			if not inst.cantackle then
				for i = 1, #TACKLE_ITEMS do
					n = n + 1
					_temp[n] = TACKLE_ITEMS[i]
				end
			end
			if not inst.cancannon and junk.hascannon then
				for i = 1, #CANNON_ITEMS do
					n = n + 1
					_temp[n] = CANNON_ITEMS[i]
				end
			end
			if inst.lastequip and n > 1 then
				for i = 1, n do
					if _temp[i] == inst.lastequip then
						_temp[i] = _temp[n]
						n = n - 1
						break
					end
				end
			end
			return junk, _temp[math.random(n)]
		elseif inst.canthrow then
			local target = inst.components.combat.target
			if target then
				if not ignorerange then
					local threshold = inst:IsNear(target, 12) and 20 or 16
					if target:IsNear(junk, threshold) then
						return
					end
				end
				return junk, "ball"
			end
		end
	end
end

local function MaxTargetLeashDist(inst)
	local target = inst.components.combat.target
	return 4 + (target and target:GetPhysicsRadius(0) or 0)
end

local function MinTargetLeashDist(inst)
	local target = inst.components.combat.target
	return 3 + (target and target:GetPhysicsRadius(0) or 0)
end

local function LeashShouldRun(inst)
	if inst.sg:HasStateTag("running") then
		return true
	end
	if inst.canswing or inst.cancannon then
		local target = inst.components.combat.target
		if target then
			local cd = inst.components.combat:GetCooldown()
			return cd <= 0.5 and not inst:IsNear(target, 6)
		end
	elseif inst.cantackle then
		local target = inst.components.combat.target
		return target and not (inst.components.combat:InCooldown() or inst:IsNear(target, TUNING.DAYWALKER2_TACKLE_RANGE + 2))
	end
	return false
end

--Once we've decided to go rummage, stick to the decision unless target gets too close
local function ShouldRummage(inst, self)
	if not inst.components.combat:HasTarget() then
		self.cachedrummage = false
		return false
	end
	local junk, loot = GetCurrentJunkLoot(inst, false)
	if loot then
		self.cachedrummage = loot == "ball" and not inst.sg:HasStateTag("busy")
		return true
	end
	if self.cachedrummage then
		if inst.sg:HasStateTag("busy") then
			self.cachedrummage = false
		elseif inst.canswing or inst.cancannon or inst.cantackle then
			local target = inst.components.combat.target
			if target and not inst.components.combat:InCooldown() and inst:IsNear(target, 6) then
				self.cachedrummage = false
			end
		end
	end
	return self.cachedrummage
end

local function ShouldStalk(inst)
	local target = inst.components.combat.target
	if target then
		if inst.canswing or inst.cancannon then
			return inst.components.combat:InCooldown()
		elseif inst.cantackle then
			return true
		end
	end
	return false
end

local function ShouldChase(inst)
	return (inst.canswing or inst.cancannon) and not inst.components.combat:InCooldown()
end

local function ShouldTackle(inst)
	if inst.cantackle then
		local target = inst.components.combat.target
		return target and inst:IsNear(target, TUNING.DAYWALKER2_TACKLE_RANGE)
	end
end

function Daywalker2Brain:OnStart()
	local root = PriorityNode({
		WhileNode(
			function()
				return not self.inst.sg:HasStateTag("jumping")
			end,
			"<busy state guard>",
			PriorityNode({
				WhileNode(function() return ShouldRummage(self.inst, self) end, "Rummage",
					PriorityNode({
						FailIfSuccessDecorator(Leash(self.inst, GetJunkPos, 5.5, 5, ShouldRunToJunk)),
						ActionNode(function()
							local junk, loot = GetCurrentJunkLoot(self.inst, true)
							if loot then
								self.inst:PushEvent("rummage", { junk = junk, loot = loot })
							end
						end),
					}, 0.5)),

				--When in cooldown, or if can only tackle
				WhileNode(function() return ShouldStalk(self.inst) end, "Stalking",
					PriorityNode({
						ConditionNode(function()
							if not (self.inst.canswing or self.inst.cancannon or self.inst.components.combat:InCooldown()) and ShouldTackle(self.inst) then
								self.inst:PushEvent("tackle", self.inst.components.combat.target)
								return true
							end
						end, "HighPriorityTackle"),
						FailIfSuccessDecorator(Leash(self.inst, GetTargetPos, MaxTargetLeashDist, MinTargetLeashDist, LeashShouldRun)),
						NotDecorator(ActionNode(function()
							if self.inst.components.combat:GetCooldown() < 0.5 then
								self.inst.components.combat:ResetCooldown()
							end
						end)),
						--Note: rechecking ShouldStalk because we may have reset cooldown,
						--      in which case we want it to immediately move to next node.
						IfNode(function() return ShouldStalk(self.inst) end, "ReachedTargetEarly",
							PriorityNode({
								WhileNode(function() return self.inst:IsStalking() end, "StationaryStalking",
									StandStill(self.inst)), --let head tracking do it's thing, don't want flippy body
								WhileNode(function() return not self.inst:IsStalking() end, "StationaryNoStalking",
									FaceEntity(self.inst, GetTarget, IsTarget)),
							}, 0.5)),
					}, 0.5)),

				--When ready to attack with weapon (or optionally tackle)
				WhileNode(function() return ShouldChase(self.inst) end, "Chasing",
					ParallelNode{
						ChaseAndAttack(self.inst),
						ConditionWaitNode(function()
							if ShouldTackle(self.inst) then
								self.inst:PushEvent("tackle", self.inst.components.combat.target)
								return true
							end
						end, "LowPriorityTackle"),
					}),

				Wander(self.inst, GetJunkPos, 8),
			}, 0.5)),
	}, 0.5)

	self.bt = BT(self.inst, root)
end

return Daywalker2Brain
