local assets =
{
	Asset("ANIM", "anim/shadow_thrall_mouth.zip"),
}

local prefabs =
{
	"voidcloth",
	"horrorfuel",
	"nightmarefuel",
	"shadowthrall_mouth_dupe_fx",
}

local brain = require("brains/shadowthrall_mouth_brain")

SetSharedLootTable("shadowthrall_mouth",
{
	{ "voidcloth",		1.00 },
	{ "voidcloth",		1.00 },
	{ "voidcloth",		1.00 },
	{ "voidcloth",		0.33 },
	{ "horrorfuel",		1.00 },
	{ "horrorfuel",		0.50 },
	{ "nightmarefuel",	1.00 },
	{ "nightmarefuel",	1.00 },
	{ "nightmarefuel",	0.67 },
})

local MASS = 50
local PHYSICS_RADIUS = 0.75

local function DisplayNameFn(inst)
	return ThePlayer and ThePlayer:HasTag("player_shadow_aligned") and STRINGS.NAMES.SHADOWTHRALL_MOUTH_ALLEGIANCE or nil
end

local function OnNewState(inst)
	if inst.sg:HasStateTag("stealth") then
		if not inst._stealth then
			inst._stealth = true
			inst.Transform:SetNoFaced()
			inst.AnimState:SetLightOverride(1)
			inst.DynamicShadow:Enable(false)
			RemovePhysicsColliders(inst)
			inst.components.health:SetInvincible(true)
			inst.components.combat.battlecryenabled = false
			inst.components.combat:SetAttackPeriod(TUNING.SHADOWTHRALL_MOUTH_STEALTH_ATTACK_PERIOD)
			inst.components.combat:SetRange(TUNING.SHADOWTHRALL_MOUTH_STEALTH_ATTACK_RANGE)
		end
	elseif inst._stealth then
		inst._stealth = nil
		inst.Transform:SetSixFaced()
		inst.AnimState:SetLightOverride(0)
		inst.DynamicShadow:Enable(true)
		ChangeToCharacterPhysics(inst)
		inst.components.health:SetInvincible(false)
		inst.components.combat.battlecryenabled = true
		inst.components.combat:SetAttackPeriod(TUNING.SHADOWTHRALL_MOUTH_ATTACK_PERIOD)
		inst.components.combat:SetRange(TUNING.SHADOWTHRALL_MOUTH_ATTACK_RANGE)
	end
end

local function RetargetFn(inst)
	local x, y, z = inst.Transform:GetWorldPosition()
	local target = inst.components.combat.target
	if target then
		local range = TUNING.SHADOWTHRALL_MOUTH_STEALTH_ATTACK_RANGE
		if target.isplayer and target:GetDistanceSqToPoint(x, y, z) < range * range then
			--Keep target
			return
		end
	end

	--V2C: WARNING: FindClosestPlayerInRange returns 2 values, which
	--              we don't want to return as our 2nd return value.  
	local player--[[, rangesq]] = FindClosestPlayerInRange(x, y, z, TUNING.SHADOWTHRALL_AGGRO_RANGE, true)
	return player
end

local function KeepTargetFn(inst, target)
	return inst.components.combat:CanTarget(target)
		and inst:IsNear(target, TUNING.SHADOWTHRALL_DEAGGRO_RANGE)
end

local _all_stealth_bite_targets = {}

local function TryRegisterStealthBiteTarget(inst, target)
	if inst._stealth_bite_target == nil and target and target:IsValid() and _all_stealth_bite_targets[target] == nil then
		inst._stealth_bite_target = target
		_all_stealth_bite_targets[target] = true
		return true
	end
	return false
end

local function ClearStealthBiteTarget(inst)
	if inst._stealth_bite_target then
		_all_stealth_bite_targets[inst._stealth_bite_target] = nil
		inst._stealth_bite_target = nil
	end
end

local function OnRemoveEntity(inst)
	inst.dupe:Remove()
	ClearStealthBiteTarget(inst)
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddDynamicShadow()
	inst.entity:AddNetwork()

	inst:SetPhysicsRadiusOverride(PHYSICS_RADIUS)
	MakeCharacterPhysics(inst, MASS, inst.physicsradiusoverride)
	inst.DynamicShadow:SetSize(2, 1)
	inst.Transform:SetSixFaced()

	inst:AddTag("monster")
	inst:AddTag("hostile")
	inst:AddTag("scarytoprey")
	inst:AddTag("shadowthrall")
	inst:AddTag("shadow_aligned")

	inst.AnimState:SetBank("shadow_thrall_mouth")
	inst.AnimState:SetBuild("shadow_thrall_mouth")
	inst.AnimState:PlayAnimation("idle", true)
	inst.scrapbook_anim ="scrapbook"

	inst.displaynamefn = DisplayNameFn

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst.dupe = SpawnPrefab("shadowthrall_mouth_dupe_fx")
	inst.dupe:RemoveFromScene()
	inst.dupe.main = inst

	inst:AddComponent("inspectable")

	inst:AddComponent("sanityaura")
	inst.components.sanityaura.aura = -TUNING.SANITYAURA_MED

	inst:AddComponent("locomotor")
	inst.components.locomotor.walkspeed = TUNING.SHADOWTHRALL_MOUTH_WALKSPEED

	inst:AddComponent("health")
	inst.components.health:SetMaxHealth(TUNING.SHADOWTHRALL_MOUTH_HEALTH)
	inst.components.health.nofadeout = true

	inst:AddComponent("combat")
	inst.components.combat:SetDefaultDamage(TUNING.SHADOWTHRALL_MOUTH_BITE_DAMAGE)
	inst.components.combat:SetAttackPeriod(TUNING.SHADOWTHRALL_MOUTH_ATTACK_PERIOD)
	inst.components.combat:SetRange(TUNING.SHADOWTHRALL_MOUTH_ATTACK_RANGE)
	inst.components.combat:SetRetargetFunction(3, RetargetFn)
	inst.components.combat:SetKeepTargetFunction(KeepTargetFn)
	inst.components.combat.forcefacing = false
	inst.components.combat.hiteffectsymbol = "head_base"

	inst:AddComponent("timer")

	inst:AddComponent("planarentity")
	inst:AddComponent("planardamage")
	inst.components.planardamage:SetBaseDamage(TUNING.SHADOWTHRALL_MOUTH_BITE_PLANAR_DAMAGE)

	inst:AddComponent("lootdropper")
	inst.components.lootdropper:SetChanceLootTable("shadowthrall_mouth")
	--inst.components.lootdropper.GetWintersFeastOrnaments = GetWintersFeastOrnaments
	inst.components.lootdropper.y_speed = 4
	inst.components.lootdropper.y_speed_variance = 3
	inst.components.lootdropper.spawn_loot_inside_prefab = true

	inst:AddComponent("colouradder")
	inst.components.colouradder:AttachChild(inst.dupe)

	inst:AddComponent("bloomer")
	inst.components.bloomer:AttachChild(inst.dupe)

	inst:AddComponent("knownlocations")
	inst:AddComponent("entitytracker")

	inst:SetStateGraph("SGshadowthrall_mouth")
	inst:SetBrain(brain)

	inst:ListenForEvent("newstate", OnNewState)

	inst._stealth_bite_target = nil
	inst.TryRegisterStealthBiteTarget = TryRegisterStealthBiteTarget
	inst.ClearStealthBiteTarget = ClearStealthBiteTarget
	inst.OnRemoveEntity = OnRemoveEntity

	return inst
end

local function dupe_OnAnimOver(inst)
	if inst.main then
		inst.main:PushEvent("dupe_animover")
	end
end

local function dupefxfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddDynamicShadow()
	inst.entity:AddNetwork()

	inst.entity:AddPhysics()
	inst.Physics:SetMass(MASS)
	inst.Physics:SetFriction(0)
	inst.Physics:SetDamping(5)
	inst.Physics:SetCollisionGroup(COLLISION.CHARACTERS)
	inst.Physics:ClearCollisionMask()
	inst.Physics:CollidesWith(COLLISION.GROUND)
	inst.Physics:SetCapsule(PHYSICS_RADIUS, 1)

	inst.DynamicShadow:SetSize(2, 1)

	inst.Transform:SetSixFaced()

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")

	inst.AnimState:SetBank("shadow_thrall_mouth")
	inst.AnimState:SetBuild("shadow_thrall_mouth")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst.persists = false

	inst:AddComponent("colouradder")
	inst:AddComponent("bloomer")

	inst:ListenForEvent("animover", dupe_OnAnimOver)

	return inst
end

return Prefab("shadowthrall_mouth", fn, assets, prefabs),
	Prefab("shadowthrall_mouth_dupe_fx", dupefxfn, assets)
