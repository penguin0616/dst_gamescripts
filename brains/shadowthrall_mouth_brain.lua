require("behaviours/chaseandattack")
require("behaviours/wander")

local ShadowThrallMouthBrain = Class(Brain, function(self, inst)
	Brain._ctor(self, inst)
end)

function ShadowThrallMouthBrain:OnStart()
	local root = PriorityNode({
		ChaseAndAttack(self.inst),
		Wander(self.inst, nil, nil, { minwaittime = 4 }),
	}, 0.5)

	self.bt = BT(self.inst, root)
end

return ShadowThrallMouthBrain
