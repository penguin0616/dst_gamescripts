local assets =
{
	Asset("ANIM", "anim/brilliance_projectile_fx.zip"),
}

local function PlayAnimAndRemove(inst, anim)
	inst.AnimState:PlayAnimation(anim)
	if not inst.removing then
		inst.removing = true
		inst:ListenForEvent("animover", inst.Remove)
	end
end

local function PushColour(inst, r, g, b)
	if inst.target:IsValid() then
		if inst.target.components.colouradder ~= nil then
			inst.target.components.colouradder:PushColour(inst, r, g, b, 0)
		else
			inst.target.AnimState:SetAddColour(r, g, b, 0)
		end
	end
end

local function PopColour(inst)
	inst.OnRemoveEntity = nil
	if inst.target:IsValid() then
		if inst.target.components.colouradder ~= nil then
			inst.target.components.colouradder:PopColour(inst)
		else
			inst.target.AnimState:SetAddColour(0, 0, 0, 0)
		end
	end
end

local function OnHit(inst, attacker, target)
	inst:RemoveComponent("projectile")
	if target:IsValid() then
		local radius = target:GetPhysicsRadius(0) + .2
		local x1, y1, z1 = target.Transform:GetWorldPosition()
		local x, y, z = inst.Transform:GetWorldPosition()
		if x ~= x1 or z ~= z1 then
			local dx = x - x1
			local dz = z - z1
			local k = radius / math.sqrt(dx * dx + dz * dz)
			x1 = x1 + dx * k
			z1 = z1 + dz * k
		end
		inst.Physics:Teleport(
			x1 + GetRandomMinMax(-.2, .2),
			GetRandomMinMax(.1, .3),
			z1 + GetRandomMinMax(-.2, .2)
		)
		inst.target = target
		PushColour(inst, .1, .1, .1)
		inst:DoTaskInTime(4 * FRAMES, PushColour, .075, .075, .075)
		inst:DoTaskInTime(7 * FRAMES, PushColour, .05, .05, .05)
		inst:DoTaskInTime(9 * FRAMES, PushColour, .025, .025, .025)
		inst:DoTaskInTime(10 * FRAMES, PopColour)
		inst.OnRemoveEntity = PopColour
	end
	inst.Physics:SetActive(false)
	PlayAnimAndRemove(inst, "blast"..tostring(math.random(2)))
end

local function OnMiss(inst, attacker, target)
	if not inst.AnimState:IsCurrentAnimation("disappear") then
		PlayAnimAndRemove(inst, "disappear")
	end
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddPhysics()
	inst.entity:AddNetwork()

	MakeInventoryPhysics(inst)
	RemovePhysicsColliders(inst)

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")

	inst.AnimState:SetBank("brilliance_projectile_fx")
	inst.AnimState:SetBuild("brilliance_projectile_fx")
	inst.AnimState:PlayAnimation("idle_loop", true)
	inst.AnimState:SetSymbolMultColour("light_bar", 1, 1, 1, .5)
	inst.AnimState:SetSymbolBloom("light_bar")
	inst.AnimState:SetSymbolBloom("lightbeam2")
	inst.AnimState:SetSymbolBloom("moon_glow")
	inst.AnimState:SetSymbolBloom("lunar_ring")
	inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
	inst.AnimState:SetLightOverride(.5)

	--projectile (from projectile component) added to pristine state for optimization
	inst:AddTag("projectile")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst:AddComponent("projectile")
	inst.components.projectile:SetSpeed(15)
	inst.components.projectile:SetRange(25)
	inst.components.projectile:SetOnHitFn(OnHit)
	inst.components.projectile:SetOnMissFn(OnMiss)

	inst.persists = false

	return inst
end

return Prefab("brilliance_projectile_fx", fn, assets)
