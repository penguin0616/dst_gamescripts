local assets =
{
	Asset("ANIM", "anim/sword_lunarplant.zip"),
}

local function onequip(inst, owner)
	local skin_build = inst:GetSkinBuild()
	if skin_build ~= nil then
		owner:PushEvent("equipskinneditem", inst:GetSkinName())
		owner.AnimState:OverrideItemSkinSymbol("swap_object", skin_build, "swap_sword_lunarplant", inst.GUID, "sword_lunarplant")
	else
		owner.AnimState:OverrideSymbol("swap_object", "sword_lunarplant", "swap_sword_lunarplant")
	end
	owner.AnimState:Show("ARM_carry")
	owner.AnimState:Hide("ARM_normal")
end

local function onunequip(inst, owner)
	owner.AnimState:Hide("ARM_carry")
	owner.AnimState:Show("ARM_normal")
	local skin_build = inst:GetSkinBuild()
	if skin_build ~= nil then
		owner:PushEvent("unequipskinneditem", inst:GetSkinName())
	end
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddNetwork()

	MakeInventoryPhysics(inst)

	inst.AnimState:SetBank("sword_lunarplant")
	inst.AnimState:SetBuild("sword_lunarplant")
	inst.AnimState:PlayAnimation("idle", true)
	inst.AnimState:SetSymbolBloom("pb_energy_loop01")
	inst.AnimState:SetSymbolLightOverride("pb_energy_loop01", .5)
	inst.AnimState:SetLightOverride(.1)

	inst:AddTag("sharp")

	--weapon (from weapon component) added to pristine state for optimization
	inst:AddTag("weapon")

	local swap_data = { sym_build = "sword_lunarplant", sym_name = "swap_sword_lunarplant" }
	MakeInventoryFloatable(inst, "med", 0.05, { 1, 0.4, 1 }, true, -17.5, swap_data)

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)

	-------
	inst:AddComponent("finiteuses")
	inst.components.finiteuses:SetMaxUses(TUNING.SWORD_LUNARPLANT_USES)
	inst.components.finiteuses:SetUses(TUNING.SWORD_LUNARPLANT_USES)
	inst.components.finiteuses:SetOnFinished(inst.Remove)

	-------
	inst:AddComponent("weapon")
	inst.components.weapon:SetDamage(TUNING.SWORD_LUNARPLANT_DAMAGE)

	inst:AddComponent("planardamage")
	inst.components.planardamage:SetBaseDamage(TUNING.SWORD_LUNARPLANT_PLANAR_DAMAGE)

	inst:AddComponent("damagetypebonus")
	inst.components.damagetypebonus:AddBonus("shadow_aligned", inst, TUNING.WEAPONS_LUNARPLANT_VS_SHADOW_BONUS)

	inst:AddComponent("inspectable")
	inst:AddComponent("inventoryitem")

	inst:AddComponent("equippable")
	inst.components.equippable:SetOnEquip(onequip)
	inst.components.equippable:SetOnUnequip(onunequip)

	MakeHauntableLaunch(inst)

	return inst
end

return Prefab("sword_lunarplant", fn, assets)
