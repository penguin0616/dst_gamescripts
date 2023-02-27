local assets =
{
    Asset("ANIM", "anim/torch.zip"),
    Asset("ANIM", "anim/swap_torch.zip"),
    Asset("SOUND", "sound/common.fsb"),
}

local prefabs =
{
    "torchfire",
}

local function DoIgniteSound(inst, owner)
	inst._ignitesoundtask = nil
	(owner ~= nil and owner:IsValid() and owner or inst).SoundEmitter:PlaySound("dontstarve/wilson/torch_swing")
end

local function DoExtinguishSound(inst, owner)
	inst._extinguishsoundtask = nil
	(owner ~= nil and owner:IsValid() and owner or inst).SoundEmitter:PlaySound("dontstarve/common/fireOut")
end

local function PlayIgniteSound(inst, owner, instant, force)
	if inst._extinguishsoundtask ~= nil then
		inst._extinguishsoundtask:Cancel()
		inst._extinguishsoundtask = nil
		if not force then
			return
		end
	end
	if instant then
		if inst._ignitesoundtask ~= nil then
			inst._ignitesoundtask:Cancel()
		end
		DoIgniteSound(inst, owner)
	elseif inst._ignitesoundtask == nil then
		inst._ignitesoundtask = inst:DoTaskInTime(0, DoIgniteSound, owner)
	end
end

local function PlayExtinguishSound(inst, owner, instant, force)
	if inst._ignitesoundtask ~= nil then
		inst._ignitesoundtask:Cancel()
		inst._ignitesoundtask = nil
		if not force then
			return
		end
	end
	if instant then
		if inst._extinguishsoundtask ~= nil then
			inst._extinguishsoundtask:Cancel()
		end
		DoExtinguishSound(inst, owner)
	elseif inst._extinguishsoundtask == nil then
		inst._extinguishsoundtask = inst:DoTaskInTime(0, DoExtinguishSound, owner)
	end
end

local function OnRemoveEntity(inst)
	--Due to timing of unequip on removal, we may have passed CancelAllPendingTasks already.
	if inst._ignitesoundtask ~= nil then
		inst._ignitesoundtask:Cancel()
		inst._ignitesoundtask = nil
	end
	if inst._extinguishsoundtask ~= nil then
		inst._extinguishsoundtask:Cancel()
		inst._extinguishsoundtask = nil
	end
end

local function applyskillbrightness(inst, value)
    if inst.fires then
        for i,fx in ipairs(inst.fires) do
            if fx._light then
                fx._light.Light:SetRadius(fx._light.Light:GetRadius()*value)
            end
        end
    end
end

local function removeskillbrightness(inst, value)
    if inst.fires then
        for i,fx in ipairs(inst.fires) do
            if fx._light then
                fx._light.Light:SetRadius(fx._light.Light:GetRadius()*(1/value))
            end
        end
    end
end

local function applyskillfueleffect(inst,value)
    inst.components.fueled.rate_modifiers:SetModifier(inst, value,"wilsonskill")
end
local function removeskillfueleffect(inst)
    inst.components.fueled.rate_modifiers:RemoveModifier(inst, "wilsonskill")
end

local function getskillfueleffectmodifier(inst, owner)
    if owner.components.skilltreeupdater:IsActivated("wilson_torch_3") then
        return TUNING.SKILLS.WILSON_TORCH_3
    elseif owner.components.skilltreeupdater:IsActivated("wilson_torch_2") then
        return TUNING.SKILLS.WILSON_TORCH_2
    elseif owner.components.skilltreeupdater:IsActivated("wilson_torch_1") then
        return TUNING.SKILLS.WILSON_TORCH_1
    end
end

local function getskillbrightnesseffectmodifier(inst, owner)
    if owner.components.skilltreeupdater:IsActivated("wilson_torch_6") then
        return TUNING.SKILLS.WILSON_TORCH_6
    elseif   owner.components.skilltreeupdater:IsActivated("wilson_torch_5") then
        return TUNING.SKILLS.WILSON_TORCH_5
    elseif   owner.components.skilltreeupdater:IsActivated("wilson_torch_4") then
        return TUNING.SKILLS.WILSON_TORCH_4
    end
end

local function applytorchskilleffects(inst, data)
    --SKILLTREE CODE
    if data.fuelmod then
        applyskillfueleffect(inst,data.fuelmod)
    end
    if data.brightnessmod then
        applyskillbrightness(inst,data.brightnessmod)
    end
end

local function removetorchskilleffects(inst,brightnessvalue)
    --SKILLTREE CODE
    removeskillbrightness(inst, brightnessvalue)
    removeskillfueleffect(inst)
end

local function onequip(inst, owner)
    inst.components.burnable:Ignite()

    local skin_build = inst:GetSkinBuild()
    if skin_build ~= nil then
        owner:PushEvent("equipskinneditem", inst:GetSkinName())
        owner.AnimState:OverrideItemSkinSymbol("swap_object", skin_build, "swap_torch", inst.GUID, "swap_torch")
    else
        owner.AnimState:OverrideSymbol("swap_object", "swap_torch", "swap_torch")
    end
    owner.AnimState:Show("ARM_carry")
    owner.AnimState:Hide("ARM_normal")

	PlayIgniteSound(inst, owner, true, false)

    if inst.fires == nil then
        inst.fires = {}

        for i, fx_prefab in ipairs(inst:GetSkinName() == nil and { "torchfire" } or SKIN_FX_PREFAB[inst:GetSkinName()] or {}) do
            local fx = SpawnPrefab(fx_prefab)
            fx.entity:SetParent(owner.entity)
            fx.entity:AddFollower()
            fx.Follower:FollowSymbol(owner.GUID, "swap_object", fx.fx_offset_x or 0, fx.fx_offset, 0)
            fx:AttachLightTo(owner)
            if fx.AssignSkinData ~= nil then
                fx:AssignSkinData(inst)
            end

            table.insert(inst.fires, fx)
        end
    end

    applytorchskilleffects(inst, {fuelmod = getskillfueleffectmodifier(inst, owner), brightnessmod = getskillbrightnesseffectmodifier(inst, owner) } )
end

local function onunequip(inst, owner)
    local skin_build = inst:GetSkinBuild()
    if skin_build ~= nil then
        owner:PushEvent("unequipskinneditem", inst:GetSkinName())
    end

    if inst.fires ~= nil then
        for i, fx in ipairs(inst.fires) do
            fx:Remove()
        end
        inst.fires = nil
		PlayExtinguishSound(inst, owner, false, false)
    end

    inst.components.burnable:Extinguish()
    owner.AnimState:Hide("ARM_carry")
    owner.AnimState:Show("ARM_normal")

    removetorchskilleffects(inst, getskillbrightnesseffectmodifier(inst, owner))
end

local function applyskilleffect(inst, skill)
    if skill == "wilson_torch_1" then
        applyskillfueleffect(inst,TUNING.SKILLS.WILSON_TORCH_1)
    elseif skill == "wilson_torch_2" then
        removeskillfueleffect(inst)
        applyskillfueleffect(inst,TUNING.SKILLS.WILSON_TORCH_2)
    elseif skill == "wilson_torch_3" then
        removeskillfueleffect(inst)
        applyskillfueleffect(inst,TUNING.SKILLS.WILSON_TORCH_3)
    end

    if skill == "wilson_torch_4" then
        applyskillbrightness(inst,TUNING.SKILLS.WILSON_TORCH_4)
    elseif skill == "wilson_torch_5" then
        removeskillbrightness(inst,TUNING.SKILLS.WILSON_TORCH_4)
        applyskillbrightness(inst,TUNING.SKILLS.WILSON_TORCH_5)
    elseif skill == "wilson_torch_6" then
        removeskillbrightness(inst,TUNING.SKILLS.WILSON_TORCH_5)
        applyskillbrightness(inst,TUNING.SKILLS.WILSON_TORCH_6)
    end    
end

local function onequiptomodel(inst, owner, from_ground)
    if inst.fires ~= nil then
        for i, fx in ipairs(inst.fires) do
            fx:Remove()
        end
        inst.fires = nil
		PlayExtinguishSound(inst, owner, true, false)
    end

    inst.components.burnable:Extinguish()
end

local function onpocket(inst, owner)
    inst.components.burnable:Extinguish()
end

local function onattack(weapon, attacker, target)
    --target may be killed or removed in combat damage phase
    if target ~= nil and target:IsValid() and target.components.burnable ~= nil and math.random() < TUNING.TORCH_ATTACK_IGNITE_PERCENT * target.components.burnable.flammability then
        target.components.burnable:Ignite(nil, attacker)
    end
end

local function onupdatefueledraining(inst)
    local owner = inst.components.inventoryitem ~= nil and inst.components.inventoryitem.owner or nil
    inst.components.fueled.rate =
        owner ~= nil and
        owner.components.sheltered ~= nil and
        owner.components.sheltered.sheltered and
        (inst._fuelratemult or 1) or
        (1 + TUNING.TORCH_RAIN_RATE * TheWorld.state.precipitationrate) * (inst._fuelratemult or 1)
end

local function onisraining(inst, israining)
    if inst.components.fueled ~= nil then
        if israining then
            inst.components.fueled:SetUpdateFn(onupdatefueledraining)
            onupdatefueledraining(inst)
        else
            inst.components.fueled:SetUpdateFn()
            inst.components.fueled.rate = inst._fuelratemult or 1
        end
    end
end

local function onfuelchange(newsection, oldsection, inst)
    if newsection <= 0 then
        --when we burn out
        if inst.components.burnable ~= nil then
            inst.components.burnable:Extinguish()
        end
		local owner = inst.components.inventoryitem ~= nil and inst.components.inventoryitem.owner or nil
		if owner ~= nil then
			local equippable = inst.components.equippable
			if equippable ~= nil and equippable:IsEquipped() then
                local data =
                {
                    prefab = inst.prefab,
                    equipslot = equippable.equipslot,
                    announce = "ANNOUNCE_TORCH_OUT",
                }
				PlayExtinguishSound(inst, owner, true, false)
                owner:PushEvent("itemranout", data)
            end
			inst:Remove()
		elseif inst.fires ~= nil then
			for i, fx in ipairs(inst.fires) do
				fx:Remove()
			end
			inst.fires = nil
			PlayExtinguishSound(inst, nil, true, false)
			inst.persists = false
			inst:AddTag("NOCLICK")
			ErodeAway(inst)
		else
			--Shouldn't reach here
			inst:Remove()
        end
    end
end

local function SetFuelRateMult(inst, mult)
    mult = mult ~= 1 and mult or nil

    if inst._fuelratemult ~= mult then
        inst._fuelratemult = mult
        onisraining(inst, TheWorld.state.israining)
    end
end

local function IgniteTossed(inst)
	inst.components.burnable:Ignite()

	if inst.fires == nil then
		inst.fires = {}

		for i, fx_prefab in ipairs(inst:GetSkinName() == nil and { "torchfire" } or SKIN_FX_PREFAB[inst:GetSkinName()] or {}) do
			local fx = SpawnPrefab(fx_prefab)
			fx.entity:SetParent(inst.entity)
			fx.entity:AddFollower()
			fx.Follower:FollowSymbol(inst.GUID, "swap_torch", fx.fx_offset_x or 0, fx.fx_offset, 0)
			fx:AttachLightTo(inst)
			if fx.AssignSkinData ~= nil then
				fx:AssignSkinData(inst)
			end

			table.insert(inst.fires, fx)
		end
	end
    if inst.thrower then
        applytorchskilleffects(inst, {fuelmod = inst.thrower.fuelmod, brightnessmod = inst.thrower.brightnessmod } )
    end
end

local function OnThrown(inst, thrower)
    inst.thrower = thrower and {fuelmod = getskillfueleffectmodifier(inst, thrower), brightnessmod = getskillbrightnesseffectmodifier(inst, thrower) } or nil
	inst.AnimState:PlayAnimation("spin_loop", true)
	PlayIgniteSound(inst, nil, true, true)
	IgniteTossed(inst)
	inst.components.inventoryitem.canbepickedup = false
end

local function OnHit(inst)
	inst.AnimState:PlayAnimation("land")
	inst.components.inventoryitem.canbepickedup = true
end

local function RemoveThrower(inst)
    if inst.thrower then
        removetorchskilleffects(inst,inst.thrower.brightnessmod)
        inst.thrower=nil 
    end
end

local function OnPickedUp(inst)
    RemoveThrower(inst)
end

local function OnPutInInventory(inst, owner)
    RemoveThrower(inst)
	inst.AnimState:PlayAnimation("idle")

	if inst.fires ~= nil then
		for i, fx in ipairs(inst.fires) do
			fx:Remove()
		end
		inst.fires = nil
		PlayExtinguishSound(inst, owner, false, false)
	end

	inst.components.burnable:Extinguish()
end

local function OnSave(inst, data)
	if inst.components.burnable:IsBurning() and not inst.components.inventoryitem:IsHeld() then
		data.lit = true
	end

    if inst.thrower then
        data.thrower = inst.thrower
    end
end

local function OnLoad(inst, data)
	if data ~= nil and data.lit and not inst.components.inventoryitem:IsHeld() then
		inst.AnimState:PlayAnimation("land")
		IgniteTossed(inst)
	end
    if data~= nil and data.thrower then
        inst.thrower = data.thrower
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("torch")
    inst.AnimState:SetBuild("swap_torch")
    inst.AnimState:PlayAnimation("idle")

    inst:AddTag("wildfireprotected")

    --lighter (from lighter component) added to pristine state for optimization
    inst:AddTag("lighter")

    --waterproofer (from waterproofer component) added to pristine state for optimization
    inst:AddTag("waterproofer")

    --weapon (from weapon component) added to pristine state for optimization
    inst:AddTag("weapon")

	--projectile (from complexprojectile component) added to pristine state for optimization
	inst:AddTag("projectile")

	--Only get TOSS action via PointSpecialActions
    inst:AddTag("special_action_toss")
	inst:AddTag("keep_equip_toss")

	MakeInventoryFloatable(inst, "med", nil, 0.68)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("weapon")
    inst.components.weapon:SetDamage(TUNING.TORCH_DAMAGE)
    inst.components.weapon:SetOnAttack(onattack)

    -----------------------------------
    inst:AddComponent("lighter")
    -----------------------------------

    inst:AddComponent("inventoryitem")
	inst.components.inventoryitem:SetOnPutInInventoryFn(OnPutInInventory)
    inst.components.inventoryitem:SetOnPickupFn(OnPickedUp)

    -----------------------------------

    inst:AddComponent("equippable")
    inst.components.equippable:SetOnPocket(onpocket)
    inst.components.equippable:SetOnEquip(onequip)
    inst.components.equippable:SetOnUnequip(onunequip)
    inst.components.equippable:SetOnEquipToModel(onequiptomodel)

	-----------------------------------

	inst:AddComponent("complexprojectile")
	inst.components.complexprojectile:SetHorizontalSpeed(15)
	inst.components.complexprojectile:SetGravity(-35)
	inst.components.complexprojectile:SetLaunchOffset(Vector3(.25, 1, 0))
	inst.components.complexprojectile:SetOnLaunch(OnThrown)
	inst.components.complexprojectile:SetOnHit(OnHit)

    -----------------------------------

    inst:AddComponent("waterproofer")
    inst.components.waterproofer:SetEffectiveness(TUNING.WATERPROOFNESS_SMALL)

    -----------------------------------

    inst:AddComponent("inspectable")

    -----------------------------------

    inst:AddComponent("burnable")
    inst.components.burnable.canlight = false
    inst.components.burnable.fxprefab = nil

    -----------------------------------

    inst:AddComponent("fueled")
    inst.components.fueled:SetSectionCallback(onfuelchange)
    inst.components.fueled:InitializeFuelLevel(TUNING.TORCH_FUEL)
    inst.components.fueled:SetDepletedFn(inst.Remove)
    inst.components.fueled:SetFirstPeriod(TUNING.TURNON_FUELED_CONSUMPTION, TUNING.TURNON_FULL_FUELED_CONSUMPTION)

    inst.applyskilleffect = applyskilleffect

    inst:WatchWorldState("israining", onisraining)
    onisraining(inst, TheWorld.state.israining)

    inst._fuelratemult = nil
    inst.SetFuelRateMult = SetFuelRateMult

    MakeHauntableLaunch(inst)



	inst.OnSave = OnSave
	inst.OnLoad = OnLoad
	inst.OnRemoveEntity = OnRemoveEntity

    return inst
end

return Prefab("torch", fn, assets, prefabs)
