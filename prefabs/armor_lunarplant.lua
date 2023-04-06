local assets =
{
	Asset("ANIM", "anim/armor_lunarplant.zip"),
}

local function OnBlocked(owner)
	owner.SoundEmitter:PlaySound("dontstarve/common/together/armor/cactus")
end

local function GetSetBonusEquip(inst, owner)
	local hat = owner.components.inventory ~= nil and owner.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD) or nil
	return hat ~= nil and hat.prefab == "lunarplanthat" and hat or nil
end

local function onequip(inst, owner)
	local skin_build = inst:GetSkinBuild()
	if skin_build ~= nil then
		owner:PushEvent("equipskinneditem", inst:GetSkinName())
		owner.AnimState:OverrideItemSkinSymbol("swap_body", skin_build, "swap_body", inst.GUID, "armor_lunarplant")
	else
		owner.AnimState:OverrideSymbol("swap_body", "armor_lunarplant", "swap_body")
	end

	inst:ListenForEvent("blocked", OnBlocked, owner)

	local hat = GetSetBonusEquip(inst, owner)
	if hat ~= nil then
		inst.components.damagetyperesist:AddResist("lunar_aligned", inst, TUNING.ARMOR_LUNARPLANT_SETBONUS_LUNAR_RESIST, "setbonus")
		hat.components.damagetyperesist:AddResist("lunar_aligned", hat, TUNING.ARMOR_LUNARPLANT_SETBONUS_LUNAR_RESIST, "setbonus")
		if owner.components.damagetypebonus ~= nil then
			owner.components.damagetypebonus:AddBonus("shadow_aligned", owner, TUNING.ARMOR_LUNARPLANT_SETBONUS_VS_SHADOW_BONUS, "lunarplant_setbonus")
		end
	end
end

local function onunequip(inst, owner)
	owner.AnimState:ClearOverrideSymbol("swap_body")
	inst:RemoveEventCallback("blocked", OnBlocked, owner)

	local skin_build = inst:GetSkinBuild()
	if skin_build ~= nil then
		owner:PushEvent("unequipskinneditem", inst:GetSkinName())
	end

	local hat = GetSetBonusEquip(inst, owner)
	if hat ~= nil then
		hat.components.damagetyperesist:RemoveResist("lunar_aligned", hat, "setbonus")
	end
	inst.components.damagetyperesist:RemoveResist("lunar_aligned", inst, "setbonus")
	if owner.components.damagetypebonus ~= nil then
		owner.components.damagetypebonus:RemoveBonus("shadow_aligned", owner, "lunarplant_setbonus")
	end
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddNetwork()

	MakeInventoryPhysics(inst)

	inst.AnimState:SetBank("armor_lunarplant")
	inst.AnimState:SetBuild("armor_lunarplant")
	inst.AnimState:PlayAnimation("anim")

	inst.foleysound = "dontstarve/movement/foley/cactus_armor"

	local swap_data = { bank = "armor_lunarplant", anim = "anim" }
	MakeInventoryFloatable(inst, "small", 0.2, 0.80, nil, nil, swap_data)

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst:AddComponent("inspectable")
	inst:AddComponent("inventoryitem")

	inst:AddComponent("armor")
	inst.components.armor:InitCondition(TUNING.ARMOR_LUNARPLANT, TUNING.ARMOR_LUNARPLANT_ABSORPTION)

	inst:AddComponent("planardefense")
	inst.components.planardefense:SetBaseDefense(TUNING.ARMOR_LUNARPLANT_PLANAR_DEF)

	inst:AddComponent("equippable")
	inst.components.equippable.equipslot = EQUIPSLOTS.BODY
	inst.components.equippable:SetOnEquip(onequip)
	inst.components.equippable:SetOnUnequip(onunequip)

	inst:AddComponent("damagetyperesist")
	inst.components.damagetyperesist:AddResist("lunar_aligned", inst, TUNING.ARMOR_LUNARPLANT_LUNAR_RESIST)

	MakeHauntableLaunch(inst)

	return inst
end

return Prefab("armor_lunarplant", fn, assets)
