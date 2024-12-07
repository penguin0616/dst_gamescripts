local assets =
{
	Asset("ANIM", "anim/slingshot_mod_kit.zip"),
}

local function ResetInUse(inst)
	inst.components.useabletargeteditem:StopUsingItem()
end

local function OnUsed(inst, target, user)
	if target.components.linkeditem and target.components.linkeditem:IsEquippableRestrictedToOwner() then
		local owneruserid = target.components.linkeditem:GetOwnerUserID()
		if owneruserid and (user and user.userid) ~= owneruserid then
			return false, "NOT_MINE"
		end
	end

	if target.components.slingshotmods and target.components.slingshotmods:Open(user) then
		--We don't need to lock this item as "inuse"
		inst:DoStaticTaskInTime(0, ResetInUse)
		return true
	end
	return false
end

local function UseableTargetedItem_ValidTarget(inst, target, doer)
	--component exists on clients
	return target.components.slingshotmods and target.components.slingshotmods:CanBeOpenedBy(doer)
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddNetwork()

	inst.AnimState:SetBank("slingshot_mod_kit")
	inst.AnimState:SetBuild("slingshot_mod_kit")
	inst.AnimState:PlayAnimation("idle")

	inst:AddTag("slingshotmodkit")

	--useabletargeteditem_mounted (from useabletargeteditem component) added to pristine state for optimization
	inst:AddTag("useabletargeteditem_mounted")

	MakeInventoryPhysics(inst)
	MakeInventoryFloatable(inst, "med", nil, 0.65)

	inst.UseableTargetedItem_ValidTarget = UseableTargetedItem_ValidTarget

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst:AddComponent("inspectable")
	inst:AddComponent("inventoryitem")

	inst:AddComponent("useabletargeteditem")
	inst.components.useabletargeteditem:SetOnUseFn(OnUsed)
	inst.components.useabletargeteditem:SetUseableMounted(true)

	MakeSmallBurnable(inst, TUNING.SMALL_BURNTIME)
	MakeSmallPropagator(inst)
	MakeHauntableLaunch(inst)

	return inst
end

return Prefab("slingshotmodkit", fn, assets)
