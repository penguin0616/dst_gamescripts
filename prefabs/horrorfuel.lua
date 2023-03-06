local assets =
{
	Asset("ANIM", "anim/horrorfuel.zip"),
}

local function CreateCore()
	local inst = CreateEntity()

	inst:AddTag("FX")
	--[[Non-networked entity]]
	--inst.entity:SetCanSleep(false)
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst.AnimState:SetBank("horrorfuel")
	inst.AnimState:SetBuild("horrorfuel")
	inst.AnimState:PlayAnimation("middle_loop", true)
	inst.AnimState:SetLightOverride(0.3)
	inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)
	inst.AnimState:SetFinalOffset(1)

	return inst
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddNetwork()

	MakeInventoryPhysics(inst)

	inst.AnimState:SetBank("horrorfuel")
	inst.AnimState:SetBuild("horrorfuel")
	inst.AnimState:PlayAnimation("idle_loop", true)
	inst.AnimState:SetMultColour(1, 1, 1, 0.5)
	inst.AnimState:UsePointFiltering(true)

	--waterproofer (from waterproofer component) added to pristine state for optimization
	inst:AddTag("waterproofer")

	MakeInventoryFloatable(inst)

	--Dedicated server does not need to spawn the local fx
	if not TheNet:IsDedicated() then
		inst.core = CreateCore()
		inst.core.entity:SetParent(inst.entity)
	end

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)

	inst:AddComponent("stackable")
	inst.components.stackable.maxsize = TUNING.STACK_SIZE_SMALLITEM
	inst:AddComponent("inspectable")
	inst:AddComponent("fuel")
	inst.components.fuel.fueltype = FUELTYPE.NIGHTMARE
	inst.components.fuel.fuelvalue = TUNING.LARGE_FUEL * 2
	inst:AddComponent("repairer")
	inst.components.repairer.repairmaterial = MATERIALS.NIGHTMARE
	inst.components.repairer.finiteusesrepairvalue = TUNING.NIGHTMAREFUEL_FINITEUSESREPAIRVALUE

	inst:AddComponent("waterproofer")
	inst.components.waterproofer:SetEffectiveness(0)

	MakeHauntableLaunch(inst)

	inst:AddComponent("inventoryitem")

	return inst
end

return Prefab("horrorfuel", fn, assets)
