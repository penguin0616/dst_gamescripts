local assets =
{
	Asset("ANIM", "anim/staff_lunarplant.zip"),
}

local prefabs =
{
	"brilliance_projectile_fx",
}

local function onequip(inst, owner)
	local skin_build = inst:GetSkinBuild()
	if skin_build ~= nil then
		owner:PushEvent("equipskinneditem", inst:GetSkinName())
		owner.AnimState:OverrideItemSkinSymbol("swap_object", skin_build, "swap_staff_lunarplant", inst.GUID, "staff_lunarplant")
	else
		owner.AnimState:OverrideSymbol("swap_object", "staff_lunarplant", "swap_staff_lunarplant")
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

local function OnAttack(inst, attacker, target, skipsanity)
	if inst.skin_sound then
		attacker.SoundEmitter:PlaySound(inst.skin_sound)
	end

	if not target:IsValid() then
		--target killed or removed in combat damage phase
		return
	end

	if target.components.sleeper ~= nil and target.components.sleeper:IsAsleep() then
		target.components.sleeper:WakeUp()
	end
	if target.components.combat ~= nil then
		target.components.combat:SuggestTarget(attacker)
	end
	target:PushEvent("attacked", { attacker = attacker, damage = 0, weapon = inst })
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddNetwork()

	MakeInventoryPhysics(inst)

	inst.AnimState:SetBank("staff_lunarplant")
	inst.AnimState:SetBuild("staff_lunarplant")
	inst.AnimState:PlayAnimation("idle")

	inst:AddTag("rangedweapon")

	--weapon (from weapon component) added to pristine state for optimization
	inst:AddTag("weapon")

	inst.projectiledelay = FRAMES

	local swap_data = { sym_build = "staff_lunarplant", sym_name = "swap_staff_lunarplant" }
	MakeInventoryFloatable(inst, "med", 0.1, { 0.9, 0.4, 0.9 }, true, -13, swap_data)

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	-------
	inst:AddComponent("finiteuses")
	inst.components.finiteuses:SetMaxUses(TUNING.STAFF_LUNARPLANT_USES)
	inst.components.finiteuses:SetUses(TUNING.STAFF_LUNARPLANT_USES)
	inst.components.finiteuses:SetOnFinished(inst.Remove)

	inst:AddComponent("weapon")
	inst.components.weapon:SetDamage(0)
	inst.components.weapon:SetRange(8, 10)
	inst.components.weapon:SetOnAttack(OnAttack)
	inst.components.weapon:SetProjectile("brilliance_projectile_fx")

	inst:AddComponent("planardamage")
	inst.components.planardamage:SetBaseDamage(TUNING.STAFF_LUNARPLANT_PLANAR_DAMAGE)

	inst:AddComponent("damagetypebonus")
	inst.components.damagetypebonus:AddBonus("shadow_aligned", inst, TUNING.STAFF_LUNARPLANT_VS_SHADOW_BONUS)

	inst:AddComponent("inspectable")
	inst:AddComponent("inventoryitem")

	inst:AddComponent("equippable")
	inst.components.equippable:SetOnEquip(onequip)
	inst.components.equippable:SetOnUnequip(onunequip)

	MakeHauntableLaunch(inst)

	return inst
end

return Prefab("staff_lunarplant", fn, assets, prefabs)
