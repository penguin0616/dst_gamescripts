local assets =
{
	Asset("ANIM", "anim/armor_dreadstone.zip"),
}

local function OnBlocked(owner)
	owner.SoundEmitter:PlaySound("dontstarve/wilson/hit_marble") --#TODO DREADSTONE SOUND
end

local function onequip(inst, owner)
	local skin_build = inst:GetSkinBuild()
	if skin_build ~= nil then
		owner:PushEvent("equipskinneditem", inst:GetSkinName())
		owner.AnimState:OverrideItemSkinSymbol("swap_body", skin_build, "swap_body", inst.GUID, "armor_dreadstone")
	else
		owner.AnimState:OverrideSymbol("swap_body", "armor_dreadstone", "swap_body")
	end

	inst:ListenForEvent("blocked", OnBlocked, owner)
end

local function onunequip(inst, owner)
	owner.AnimState:ClearOverrideSymbol("swap_body")
	inst:RemoveEventCallback("blocked", OnBlocked, owner)

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

	inst.AnimState:SetBank("armor_dreadstone")
	inst.AnimState:SetBuild("armor_dreadstone")
	inst.AnimState:PlayAnimation("anim")

	inst:AddTag("dreadstone")
	inst:AddTag("shadow_item")

	--shadowlevel (from shadowlevel component) added to pristine state for optimization
	inst:AddTag("shadowlevel")

	inst.foleysound = "dontstarve/movement/foley/marblearmour" --#TODO DREADSTONE SOUND

	local swap_data = { bank = "armor_dreadstone", anim = "anim" }
	MakeInventoryFloatable(inst, "small", 0.2, 0.80, nil, nil, swap_data)

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst:AddComponent("inspectable")

	inst:AddComponent("inventoryitem")

	inst:AddComponent("armor")
	inst.components.armor:InitCondition(TUNING.ARMORDREADSTONE, TUNING.ARMORDREADSTONE_ABSORPTION)

	inst:AddComponent("equippable")
	inst.components.equippable.equipslot = EQUIPSLOTS.BODY
	inst.components.equippable.dapperness = TUNING.CRAZINESS_SMALL
	inst.components.equippable.is_magic_dapperness = true

	inst.components.equippable:SetOnEquip(onequip)
	inst.components.equippable:SetOnUnequip(onunequip)

	inst:AddComponent("shadowlevel")
	inst.components.shadowlevel:SetDefaultLevel(TUNING.ARMORDREADSTONE_SHADOW_LEVEL)

	MakeHauntableLaunch(inst)

	return inst
end

return Prefab("armordreadstone", fn, assets)
