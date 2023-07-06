local assets =
{
	Asset("ANIM", "anim/shovel_lunarplant.zip"),
}

local prefabs =
{
	"lunarplanttentacle",
}

local function SetBuffEnabled(inst, enabled)
	if enabled then
		if not inst._bonusenabled then
			inst._bonusenabled = true
			inst.components.weapon:SetDamage(inst.base_damage * TUNING.WEAPONS_LUNARPLANT_SETBONUS_DAMAGE_MULT)
			inst.components.planardamage:AddBonus(inst, TUNING.WEAPONS_LUNARPLANT_SETBONUS_PLANAR_DAMAGE, "setbonus")
		end
	elseif inst._bonusenabled then
		inst._bonusenabled = nil
		inst.components.weapon:SetDamage(inst.base_damage)
		inst.components.planardamage:RemoveBonus(inst, "setbonus")
	end
end

local function SetBuffOwner(inst, owner)
	if inst._owner ~= owner then
		if inst._owner ~= nil then
			inst:RemoveEventCallback("equip", inst._onownerequip, inst._owner)
			inst:RemoveEventCallback("unequip", inst._onownerunequip, inst._owner)
			inst._onownerequip = nil
			inst._onownerunequip = nil
			SetBuffEnabled(inst, false)
		end
		inst._owner = owner
		if owner ~= nil then
			inst._onownerequip = function(owner, data)
				if data ~= nil then
					if data.item ~= nil and data.item.prefab == "lunarplanthat" then
						SetBuffEnabled(inst, true)
					elseif data.eslot == EQUIPSLOTS.HEAD then
						SetBuffEnabled(inst, false)
					end
				end
			end
			inst._onownerunequip  = function(owner, data)
				if data ~= nil and data.eslot == EQUIPSLOTS.HEAD then
					SetBuffEnabled(inst, false)
				end
			end
			inst:ListenForEvent("equip", inst._onownerequip, owner)
			inst:ListenForEvent("unequip", inst._onownerunequip, owner)

			local hat = owner.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD)
			if hat ~= nil and hat.prefab == "lunarplanthat" then
				SetBuffEnabled(inst, true)
			end
		end
	end
end

local function onequip(inst, owner)
	local skin_build = inst:GetSkinBuild()
	if skin_build ~= nil then
		owner:PushEvent("equipskinneditem", inst:GetSkinName())
		owner.AnimState:OverrideItemSkinSymbol("swap_object", skin_build, "swap_shovel_lunarplant", inst.GUID, "shovel_lunarplant")
	else
		owner.AnimState:OverrideSymbol("swap_object", "shovel_lunarplant", "swap_shovel_lunarplant")
	end
	owner.AnimState:Show("ARM_carry")
	owner.AnimState:Hide("ARM_normal")
	SetBuffOwner(inst, owner)
end

local function onunequip(inst, owner)
	owner.AnimState:Hide("ARM_carry")
	owner.AnimState:Show("ARM_normal")
	local skin_build = inst:GetSkinBuild()
	if skin_build ~= nil then
		owner:PushEvent("unequipskinneditem", inst:GetSkinName())
	end
	SetBuffOwner(inst, nil)
end

local function SetupEquippable(inst)
	inst:AddComponent("equippable")
	inst.components.equippable:SetOnEquip(onequip)
	inst.components.equippable:SetOnUnequip(onunequip)
end

local function OnBroken(inst)
	if inst.components.equippable ~= nil then
		inst:RemoveComponent("equippable")
		inst.AnimState:PlayAnimation("broken")
	end
end

local function OnRepaired(inst)
	if inst.components.equippable == nil then
		SetupEquippable(inst)
		inst.AnimState:PlayAnimation("idle")
	end
end

local function PushIdleLoop(inst)
	if inst.components.finiteuses:GetUses() <= 0 then
		inst.AnimState:PlayAnimation("broken")
	end
end

local function OnStopFloating(inst)
	inst:DoTaskInTime(0, PushIdleLoop) --#V2C: #HACK restore the looping anim, timing issues
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddNetwork()

	MakeInventoryPhysics(inst)

	inst.AnimState:SetBank("shovel_lunarplant")
	inst.AnimState:SetBuild("shovel_lunarplant")
	inst.AnimState:PlayAnimation("idle")

	--tool (from tool component) added to pristine state for optimization
	inst:AddTag("tool")

	--weapon (from weapon component) added to pristine state for optimization
	inst:AddTag("weapon")

	local swap_data = { sym_build = "shovel_lunarplant", sym_name = "swap_shovel_lunarplant" }
	MakeInventoryFloatable(inst, "med", 0.05, { 0.8, 0.4, 0.8 }, true, 7, swap_data)

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	-----
	local tool = inst:AddComponent("tool")
	tool:SetAction(ACTIONS.DIG)
    inst:AddInherentAction(ACTIONS.TILL)
    inst:AddComponent("farmtiller")

	-------
	local finiteuses = inst:AddComponent("finiteuses")
	finiteuses:SetMaxUses(TUNING.SHOVEL_LUNARPLANT_USES)
	finiteuses:SetUses(TUNING.SHOVEL_LUNARPLANT_USES)
	finiteuses:SetConsumption(ACTIONS.DIG, 1)
	finiteuses:SetConsumption(ACTIONS.TILL, 1)

	-------
	inst.base_damage = TUNING.SHOVEL_LUNARPLANT_DAMAGE
	local weapon = inst:AddComponent("weapon")
	weapon:SetDamage(inst.base_damage)

	local planardamage = inst:AddComponent("planardamage")
	planardamage:SetBaseDamage(TUNING.SHOVEL_LUNARPLANT_PLANAR_DAMAGE)

	local damagetypebonus = inst:AddComponent("damagetypebonus")
	damagetypebonus:AddBonus("shadow_aligned", inst, TUNING.WEAPONS_LUNARPLANT_VS_SHADOW_BONUS)

	inst:AddComponent("inspectable")
	inst:AddComponent("inventoryitem")

	SetupEquippable(inst)
	inst:ListenForEvent("floater_stopfloating", OnStopFloating)

	inst:AddComponent("lunarplant_tentacle_weapon")

	MakeForgeRepairable(inst, FORGEMATERIALS.LUNARPLANT, OnBroken, OnRepaired)
	MakeHauntableLaunch(inst)

	return inst
end

return Prefab("shovel_lunarplant", fn, assets, prefabs)
