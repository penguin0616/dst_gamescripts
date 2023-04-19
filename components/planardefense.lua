local SourceModifierList = require("util/sourcemodifierlist")

local PlanarDefense = Class(function(self, inst)
	self.inst = inst
	self.basedefense = 0
	self.externalmultipliers = SourceModifierList(inst)
	self.externalbonuses = SourceModifierList(inst, 0, SourceModifierList.additive)
end)

function PlanarDefense:SetBaseDefense(defense)
	self.basedefense = defense
end

function PlanarDefense:GetBaseDefense()
	return self.basedefense
end

function PlanarDefense:GetDefense()
	return self.basedefense * self.externalmultipliers:Get() + self.externalbonuses:Get()
end

--------------------------------------------------------------------------

function PlanarDefense:AddMultiplier(src, mult, key)
	self.externalmultipliers:SetModifier(src, mult, key)
end

function PlanarDefense:RemoveMultiplier(src, key)
	self.externalmultipliers:RemoveModifier(src, key)
end

function PlanarDefense:GetMultiplier()
	return self.externalmultipliers:Get()
end

--------------------------------------------------------------------------

function PlanarDefense:AddBonus(src, bonus, key)
	self.externalbonuses:SetModifier(src, bonus, key)
end

function PlanarDefense:RemoveBonus(src, key)
	self.externalbonuses:RemoveModifier(src, key)
end

function PlanarDefense:GetBonus()
	return self.externalbonuses:Get()
end

--------------------------------------------------------------------------

function PlanarDefense:OnResistNonPlanarAttack(attacker)
	local fx = SpawnPrefab("planar_resist_fx")
	local radius = self.inst:GetPhysicsRadius(0) + .2 + math.random() * .5
	local x, y, z = self.inst.Transform:GetWorldPosition()
	local theta
	if attacker ~= nil then
		local x1, y1, z1 = attacker.Transform:GetWorldPosition()
		if x ~= x1 or z ~= z1 then
			theta = math.atan2(z - z1, x1 - x) + math.random() * 2 - 1
		end
	end
	if theta == nil then
		theta = math.random() * TWOPI
	end
	fx.Transform:SetPosition(
		x + radius * math.cos(theta),
		math.random(),
		z - radius * math.sin(theta)
	)
end

--------------------------------------------------------------------------

function PlanarDefense:GetDebugString()
	return string.format("Defense=%.2f [%.2fx%.2f+%.2f]", self:GetDefense(), self:GetBaseDefense(), self:GetMultiplier(), self:GetBonus())
end

return PlanarDefense
