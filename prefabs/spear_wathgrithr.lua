local assets_basic =
{
    Asset("ANIM", "anim/spear_wathgrithr.zip"),
    Asset("ANIM", "anim/swap_spear_wathgrithr.zip"),
}

local assets_lightning =
{
    Asset("ANIM", "anim/spear_wathgrithr_lightning.zip"),
}

local assets_lightning_lunge_fx =
{
    Asset("ANIM", "anim/elec_lunge_fx.zip"),
}

local assets_lightning_fx =
{
    Asset("ANIM", "anim/spear_wathgrithr_lightning.zip"),
}

local prefabs_basic =
{

}

local prefabs_lightning =
{
    "reticuleline",
    "reticulelineping",
    "spear_wathgrithr_lightning_lunge_fx",
    "spear_wathgrithr_lightning_charged",
}

local prefabs_lightning_charged =
{
    "reticuleline",
    "reticulelineping",
    "spear_wathgrithr_lightning_lunge_fx",
    "spear_wathgrithr_lightning_fx",
}

------------------------------------------------------------------------------------------------------------------------

local CHARGE_SOUND_LOOP_NAME = "soundloop"

local function Lightning_CanElectrocuteTarget(inst, target)
    return not (
        target:HasTag("electricdamageimmune") or
        (target.components.inventory ~= nil and target.components.inventory:IsInsulated())
    ) and
        target:GetIsWet()
end

local function OnEquip(inst, owner)
    owner.AnimState:Show("ARM_carry")
    owner.AnimState:Hide("ARM_normal")

    local skin_build = inst:GetSkinBuild()

    if skin_build ~= nil then
        owner:PushEvent("equipskinneditem", inst:GetSkinName())
        owner.AnimState:OverrideItemSkinSymbol("swap_object", skin_build, inst._swapbuild, inst.GUID, inst._swapbuild)
    else
        owner.AnimState:OverrideSymbol("swap_object", inst._swapbuild, inst._swapsymbol)
    end

    inst:ApplySkillsChanges(owner)

    if inst.components.aoetargeting ~= nil and
        inst.components.aoetargeting:IsEnabled() and
        inst.components.rechargeable ~= nil and
        inst.components.rechargeable:GetTimeToCharge() < TUNING.SPEAR_WATHGRITHR_LIGHTNING_LUNGE_COOLDOWN_ONEQUIP
    then
        inst.components.rechargeable:Discharge(TUNING.SPEAR_WATHGRITHR_LIGHTNING_LUNGE_COOLDOWN_ONEQUIP)
    end

    if inst.fx ~= nil then
        inst:SetFxOwner(owner)

        if owner.SoundEmitter ~= nil then
            owner.SoundEmitter:PlaySound("meta3/wigfrid/spear_wathrithr_lightning_charged", CHARGE_SOUND_LOOP_NAME)
        end
    end

end

local function OnUnequip(inst, owner)
    owner.AnimState:ClearOverrideSymbol("swap_object")
    owner.AnimState:Hide("ARM_carry")
    owner.AnimState:Show("ARM_normal")

    local skin_build = inst:GetSkinBuild()
    if skin_build ~= nil then
        owner:PushEvent("unequipskinneditem", inst:GetSkinName())
    end

    inst:RemoveSkillsChanges(owner)

    if inst.fx ~= nil then
        inst:SetFxOwner(nil)

        if owner.SoundEmitter ~= nil then
            owner.SoundEmitter:KillSound(CHARGE_SOUND_LOOP_NAME)
        end
    end
end

------------------------------------------------------------------------------------------------------------------------

local function Lightning_OnAttack(inst, attacker, target)
    if target ~= nil and target:IsValid() and inst:CanElectrocuteTarget(target) and attacker ~= nil and attacker:IsValid() then
        SpawnPrefab("electrichitsparks"):AlignToTarget(target, attacker, true)
    end
end

------------------------------------------------------------------------------------------------------------------------

local function Lightning_SpellFn(inst, doer, pos)
    doer:PushEvent("combat_lunge", { targetpos = pos, weapon = inst })
end

local function Lightning_OnLunged(inst, doer, startingpos, targetpos)
    local fx = SpawnPrefab("spear_wathgrithr_lightning_lunge_fx")
    fx.Transform:SetPosition(targetpos:Get())
    fx.Transform:SetRotation(doer:GetRotation())

    inst.components.rechargeable:Discharge(TUNING.SPEAR_WATHGRITHR_LIGHTNING_LUNGE_COOLDOWN)

    inst._lunge_hit_count = nil
end

local function Lightning_OnLungedHit(inst, doer, target)
    inst._lunge_hit_count = inst._lunge_hit_count or 0

    if inst._lunge_hit_count < TUNING.SPEAR_WATHGRITHR_LIGHTNING_CHARGED_MAX_REPAIRS_PER_LUNGE and
        inst.components.upgradeable == nil and
        doer.IsValidVictim ~= nil and
        doer.IsValidVictim(target)
    then
        inst.components.finiteuses:Repair(TUNING.SPEAR_WATHGRITHR_LIGHTNING_CHARGED_LUNGE_REPAIR_AMOUNT)
        inst._lunge_hit_count = inst._lunge_hit_count + 1
    end
end

local function Lightning_OnDischarged(inst)
    inst.components.aoetargeting:SetEnabled(false)
end

local function Lightning_OnCharged(inst)
    local owner = inst.components.inventoryitem:GetGrandOwner()

    if owner ~= nil and owner.components.skilltreeupdater ~= nil and owner.components.skilltreeupdater:IsActivated("wathgrithr_arsenal_spear_4") then
        inst.components.aoetargeting:SetEnabled(true)
    end
end

------------------------------------------------------------------------------------------------------------------------

local function Lightning_ReticuleTargetFn()
    --Cast range is 8, leave room for error (6.5 lunge)
    return Vector3(ThePlayer.entity:LocalToWorldSpace(6.5, 0, 0))
end

local function Lightning_ReticuleMouseTargetFn(inst, mousepos)
    if mousepos ~= nil then
        local x, y, z = inst.Transform:GetWorldPosition()
        local dx = mousepos.x - x
        local dz = mousepos.z - z
        local l = dx * dx + dz * dz
        if l <= 0 then
            return inst.components.reticule.targetpos
        end
        l = 6.5 / math.sqrt(l)
        return Vector3(x + dx * l, 0, z + dz * l)
    end
end

local function Lightning_ReticuleUpdatePositionFn(inst, pos, reticule, ease, smoothing, dt)
    local x, y, z = inst.Transform:GetWorldPosition()
    reticule.Transform:SetPosition(x, 0, z)
    local rot = -math.atan2(pos.z - z, pos.x - x) / DEGREES
    if ease and dt ~= nil then
        local rot0 = reticule.Transform:GetRotation()
        local drot = rot - rot0
        rot = Lerp((drot > 180 and rot0 + 360) or (drot < -180 and rot0 - 360) or rot0, rot, dt * smoothing)
    end
    reticule.Transform:SetRotation(rot)
end

------------------------------------------------------------------------------------------------------------------------

local function ApplySkillsChanges(inst, owner)
    local _skilltreeupdater = owner.components.skilltreeupdater

    if _skilltreeupdater == nil then
        return
    end

    local skill_level = owner.components.skilltreeupdater:CountSkillTag("inspirationgain")

    if skill_level > 0 and owner.components.singinginspiration ~= nil then
        owner.components.singinginspiration.gainratemultipliers:SetModifier(inst, TUNING.SKILLS.WATHGRITHR.INSPIRATION_GAIN_MULT[skill_level], "arsenal_spear")
    end

    if not inst.is_lightning_spear then
        return
    end

    if inst.components.rechargeable:IsCharged() and _skilltreeupdater:IsActivated("wathgrithr_arsenal_spear_4") then
        inst.components.aoetargeting:SetEnabled(true)
    end
end

local function RemoveSkillsChanges(inst, owner)
    if owner.components.singinginspiration ~= nil then
        owner.components.singinginspiration.gainratemultipliers:RemoveModifier(inst, "arsenal_spear")
    end

    if not inst.is_lightning_spear then
        return
    end

    inst.components.aoetargeting:SetEnabled(false)
end

------------------------------------------------------------------------------------------------------------------------

local function Lightning_CanBeUpgrated(inst, item)
    return not inst.components.equippable:IsEquipped()
end

local function Lightning_OnUpgrated(inst, upgrader, item)
    local spear = SpawnPrefab("spear_wathgrithr_lightning_charged")

    spear.components.rechargeable:Discharge(TUNING.SPEAR_WATHGRITHR_LIGHTNING_LUNGE_COOLDOWN)
    spear.components.rechargeable:SetPercent(inst.components.rechargeable:GetPercent())

    spear.components.finiteuses:SetPercent(inst.components.finiteuses:GetPercent())

    local container = inst.components.inventoryitem:GetContainer()
    if container ~= nil then
        local slot = inst.components.inventoryitem:GetSlotNum()
        inst:Remove()
        container:GiveItem(spear, slot)
    else
        local x, y, z = inst.Transform:GetWorldPosition()
        inst:Remove()
        spear.Transform:SetPosition(x, y, z)
    end
end

------------------------------------------------------------------------------------------------------------------------

local function LightningCharged_SetFxOwner(inst, owner)
    if inst._fxowner ~= nil and inst._fxowner.components.colouradder ~= nil then
        inst._fxowner.components.colouradder:DetachChild(inst.fx)
    end
    inst._fxowner = owner
    if owner ~= nil then
        inst.fx.entity:SetParent(owner.entity)
        inst.fx.Follower:FollowSymbol(owner.GUID, "swap_object", nil, nil, nil, true)
        inst.fx.components.highlightchild:SetOwner(owner)
        if owner.components.colouradder ~= nil then
            owner.components.colouradder:AttachChild(inst.fx)
        end
    else
        inst.fx.entity:SetParent(inst.entity)
        --For floating
        inst.fx.Follower:FollowSymbol(inst.GUID, "swap_spear", nil, nil, nil, true)
        inst.fx.components.highlightchild:SetOwner(inst)
    end
end

local function PushIdleLoop(inst)
	inst.AnimState:PushAnimation("idle_loop")
end

local function LightningCharged_OnStopFloating(inst)
    inst.fx.AnimState:SetFrame(0)
    inst:DoTaskInTime(0, PushIdleLoop) --#V2C: #HACK restore the looping anim, timing issues.
end

local function LightningCharged_OnEntityWake(inst)
    if inst:IsInLimbo() or inst:IsAsleep() then
        return
    end

    if not inst.SoundEmitter:PlayingSound(CHARGE_SOUND_LOOP_NAME) then
        inst.SoundEmitter:PlaySound("meta3/wigfrid/spear_wathrithr_lightning_charged", CHARGE_SOUND_LOOP_NAME)
    end
end

local function LightningCharged_OnEntitySleep(inst)
    inst.SoundEmitter:KillSound(CHARGE_SOUND_LOOP_NAME)
end

------------------------------------------------------------------------------------------------------------------------

local function CommonFn(data)
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank(data.bank)
    inst.AnimState:SetBuild(data.build)
    inst.AnimState:PlayAnimation("idle")

    inst:AddTag("sharp")
    inst:AddTag("pointy")
    inst:AddTag("battlespear")

    -- weapon (from weapon component) added to pristine state for optimization.
    inst:AddTag("weapon")

    MakeInventoryFloatable(inst, "med", 0.1, {0.7, 0.5, 0.7}, true, -9, { sym_build = data.swapbuild, sym_name = data.swapsymbol })

    if data.commonfn ~= nil then
        data.commonfn(inst)
    end

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst._swapbuild  = data.swapbuild
    inst._swapsymbol = data.swapsymbol

    inst.ApplySkillsChanges  = ApplySkillsChanges
    inst.RemoveSkillsChanges = RemoveSkillsChanges

    inst:AddComponent("inspectable")
    inst:AddComponent("inventoryitem")

    inst:AddComponent("weapon")
    inst.components.weapon:SetDamage(data.damage)

    if data.planardamage ~= nil then
        inst:AddComponent("planardamage")
        inst.components.planardamage:SetBaseDamage(data.planardamage)
    end

    inst:AddComponent("finiteuses")
    inst.components.finiteuses:SetMaxUses(data.uses)
    inst.components.finiteuses:SetUses(data.uses)
    inst.components.finiteuses:SetOnFinished(inst.Remove)

    inst:AddComponent("equippable")
    inst.components.equippable:SetOnEquip(OnEquip)
    inst.components.equippable:SetOnUnequip(OnUnequip)

    MakeHauntableLaunch(inst)

    if data.postinitfn ~= nil then
        data.postinitfn(inst)
    end

    return inst
end

local function BasicSpearFn()
    return CommonFn({
        bank = "spear_wathgrithr",
        build = "swap_spear_wathgrithr",
        swapbuild  = "swap_spear_wathgrithr",
        swapsymbol = "swap_spear_wathgrithr",
        damage = TUNING.WATHGRITHR_SPEAR_DAMAGE,
        planardamage = nil,
        uses   = TUNING.WATHGRITHR_SPEAR_USES,
    })
end

local function LightningSpearCommonFn_Base(inst)
    -- aoeweapon_lunge (from aoeweapon_lunge component) added to pristine state for optimization.
    inst:AddTag("aoeweapon_lunge")

    -- rechargeable (from rechargeable component) added to pristine state for optimization.
    inst:AddTag("rechargeable")

    inst:AddComponent("aoetargeting")
    inst.components.aoetargeting:SetAllowRiding(false)
    inst.components.aoetargeting.reticule.reticuleprefab = "reticuleline"
    inst.components.aoetargeting.reticule.pingprefab = "reticulelineping"
    inst.components.aoetargeting.reticule.targetfn = Lightning_ReticuleTargetFn
    inst.components.aoetargeting.reticule.mousetargetfn = Lightning_ReticuleMouseTargetFn
    inst.components.aoetargeting.reticule.updatepositionfn = Lightning_ReticuleUpdatePositionFn
    inst.components.aoetargeting.reticule.validcolour = { 1, .75, 0, 1 }
    inst.components.aoetargeting.reticule.invalidcolour = { .5, 0, 0, 1 }
    inst.components.aoetargeting.reticule.ease = true
    inst.components.aoetargeting.reticule.mouseenabled = true
end

local function LightningSpearCommonFn_Normal(inst)
    LightningSpearCommonFn_Base(inst)
end

local function LightningSpearCommonFn_Charged(inst)
    LightningSpearCommonFn_Base(inst)

    inst.entity:AddSoundEmitter()

    inst.AnimState:PlayAnimation("idle_loop", true)

    inst.AnimState:SetSymbolBloom("bolt_b")
    inst.AnimState:SetSymbolBloom("bolt_c")
    inst.AnimState:SetSymbolBloom("bolt_f")
    inst.AnimState:SetSymbolLightOverride("bolt_b", .5)
    inst.AnimState:SetSymbolLightOverride("bolt_c", .5)
    inst.AnimState:SetSymbolLightOverride("bolt_f", .5)
    inst.AnimState:SetSymbolLightOverride("glow", .25)
    inst.AnimState:SetLightOverride(.1)
end

local function LightningSpearPostInitFn_Base(inst)
    inst.scrapbook_weapondamage = { TUNING.SPEAR_WATHGRITHR_LIGHTNING_DAMAGE, TUNING.SPEAR_WATHGRITHR_LIGHTNING_DAMAGE * (1 + TUNING.SPEAR_WATHGRITHR_LIGHTNING_WET_DAMAGE_MULT) }

    inst.CanElectrocuteTarget = Lightning_CanElectrocuteTarget

    inst.is_lightning_spear = true

    inst.components.weapon:SetOnAttack(Lightning_OnAttack)
    inst.components.weapon:SetElectric(1, TUNING.SPEAR_WATHGRITHR_LIGHTNING_WET_DAMAGE_MULT)

    inst.components.aoetargeting:SetEnabled(false)

    inst:AddComponent("aoeweapon_lunge")
    inst.components.aoeweapon_lunge:SetDamage(TUNING.SPEAR_WATHGRITHR_LIGHTNING_LUNGE_DAMAGE)
    inst.components.aoeweapon_lunge:SetSound("meta3/wigfrid/spear_lighting_lunge")
    inst.components.aoeweapon_lunge:SetSideRange(1)
    inst.components.aoeweapon_lunge:SetOnLungedFn(Lightning_OnLunged)
    inst.components.aoeweapon_lunge:SetOnHitFn(Lightning_OnLungedHit)
    inst.components.aoeweapon_lunge:SetStimuli("electric")
    inst.components.aoeweapon_lunge:SetWorkActions()
    inst.components.aoeweapon_lunge:SetTags()

    inst:AddComponent("aoespell")
    inst.components.aoespell:SetSpellFn(Lightning_SpellFn)

    inst:AddComponent("rechargeable")
    inst.components.rechargeable:SetOnDischargedFn(Lightning_OnDischarged)
    inst.components.rechargeable:SetOnChargedFn(Lightning_OnCharged)
end

local function LightningSpearPostInitFn_Normal(inst)
    LightningSpearPostInitFn_Base(inst)

    inst:AddComponent("upgradeable")
    inst.components.upgradeable.upgradetype = UPGRADETYPES.SPEAR_LIGHTNING
    inst.components.upgradeable:SetOnUpgradeFn(Lightning_OnUpgrated)
    inst.components.upgradeable:SetCanUpgradeFn(Lightning_CanBeUpgrated)
end

local SPEAR_LIGHTNING_CHARGED_SWAP_DATA = { sym_build = "spear_wathgrithr_lightning", sym_name = "swap_spear_wathgrithr_lightning", bank = "spear_wathgrithr_lightning", anim = "idle_loop" }

local function LightningSpearPostInitFn_Charged(inst)
    LightningSpearPostInitFn_Base(inst)

    inst.SetFxOwner = LightningCharged_SetFxOwner
    inst.OnStopFloating = LightningCharged_OnStopFloating

    local frame = math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1

    inst.AnimState:SetFrame(frame)
    inst.fx = SpawnPrefab("spear_wathgrithr_lightning_fx")
    inst.fx.AnimState:SetFrame(frame)

    inst:ListenForEvent("floater_stopfloating", inst.OnStopFloating)

    inst:SetFxOwner(nil)

    inst.components.inspectable:SetNameOverride("spear_wathgrithr_lightning")

    inst.components.equippable.restrictedtag = UPGRADETYPES.SPEAR_LIGHTNING.."_upgradeuser"
    inst.components.equippable.walkspeedmult = TUNING.SPEAR_WATHGRITHR_LIGHTNING_CHARGED_SPEED_MULT

    inst.components.floater:SetSwapData(SPEAR_LIGHTNING_CHARGED_SWAP_DATA)

    inst.OnEntityWake  = LightningCharged_OnEntityWake
    inst.OnEntitySleep = LightningCharged_OnEntitySleep

    inst:ListenForEvent("exitlimbo", inst.OnEntityWake)
    inst:ListenForEvent("enterlimbo", inst.OnEntitySleep)
end

local function LightningSpearFn()
    return CommonFn({
        bank = "spear_wathgrithr_lightning",
        build = "spear_wathgrithr_lightning",
        swapbuild  = "spear_wathgrithr_lightning",
        swapsymbol = "swap_spear_wathgrithr_lightning",
        damage = TUNING.SPEAR_WATHGRITHR_LIGHTNING_DAMAGE,
        planardamage = nil,
        uses = TUNING.SPEAR_WATHGRITHR_LIGHTNING_USES,
        commonfn   = LightningSpearCommonFn_Normal,
        postinitfn = LightningSpearPostInitFn_Normal,
    })
end

local function LightningSpearChargedFn()
    return CommonFn({
        bank = "spear_wathgrithr_lightning",
        build = "spear_wathgrithr_lightning",
        swapbuild  = "spear_wathgrithr_lightning",
        swapsymbol = "swap_spear_wathgrithr_lightning",
        damage = TUNING.SPEAR_WATHGRITHR_LIGHTNING_CHARGED_DAMAGE,
        planardamage = TUNING.SPEAR_WATHGRITHR_LIGHTNING_CHARGED_PLANAR_DAMAGE,
        uses = TUNING.SPEAR_WATHGRITHR_LIGHTNING_CHARGED_USES,
        commonfn   = LightningSpearCommonFn_Charged,
        postinitfn = LightningSpearPostInitFn_Charged,
    })
end

------------------------------------------------------------------------------------------------------------------------

local function FX_OnUpdate(inst, dt)
    inst.Light:SetIntensity(inst.i)
    inst.i = inst.i - dt * 2
    if inst.i <= 0 then
        if inst.killfx then
            inst:Remove()
        else
            inst.task:Cancel()
            inst.task = nil
        end
    end
end

local function FX_OnAnimOver(inst)
    if inst.task == nil then
        inst:Remove()
    else
        inst:RemoveEventCallback("animover", FX_OnAnimOver)
        inst.killfx = true
    end
end

local function LungueTrailFxFn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()
    inst.entity:AddLight()

    inst.Light:Enable(true)
    inst.Light:SetRadius(3.5)
    inst.Light:SetFalloff(1.5)
    inst.Light:SetIntensity(.9)
    inst.Light:SetColour(237/255, 237/255, 209/255)

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")

    inst.Transform:SetEightFaced()

    inst.AnimState:SetBank("elec_lunge_fx")
    inst.AnimState:SetBuild("elec_lunge_fx")
    inst.AnimState:PlayAnimation("fx")

    inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
    inst.AnimState:SetLightOverride(1)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    local scale = GetRandomMinMax(1.4, 1.7)
    inst.Transform:SetScale(scale, scale, scale)

    inst.persists = false

    local dt = 1 / 20

    inst.i = .9
    inst.task = inst:DoPeriodicTask(dt, FX_OnUpdate, nil, dt)

    inst:ListenForEvent("animover", FX_OnAnimOver)

    return inst
end

------------------------------------------------------------------------------------------------------------------------

local function FxFn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddFollower()
    inst.entity:AddNetwork()

    inst:AddTag("FX")

    inst.AnimState:SetBank("spear_wathgrithr_lightning")
    inst.AnimState:SetBuild("spear_wathgrithr_lightning")
    inst.AnimState:PlayAnimation("swap_loop", true)

    inst.AnimState:SetSymbolBloom("bolt_b")
    inst.AnimState:SetSymbolBloom("bolt_c")
    inst.AnimState:SetSymbolBloom("bolt_f")
    inst.AnimState:SetSymbolLightOverride("bolt_b", .5)
    inst.AnimState:SetSymbolLightOverride("bolt_c", .5)
    inst.AnimState:SetSymbolLightOverride("bolt_f", .5)
    inst.AnimState:SetSymbolLightOverride("glow", .25)
    inst.AnimState:SetLightOverride(.1)

    inst:AddComponent("highlightchild")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("colouradder")

    inst.persists = false

    return inst
end

------------------------------------------------------------------------------------------------------------------------


return
        Prefab("spear_wathgrithr",                      BasicSpearFn,            assets_basic,                  prefabs_basic             ),
        Prefab("spear_wathgrithr_lightning",            LightningSpearFn,        assets_lightning,              prefabs_lightning         ),
        Prefab("spear_wathgrithr_lightning_charged",    LightningSpearChargedFn, assets_lightning,              prefabs_lightning_charged ),
        Prefab("spear_wathgrithr_lightning_lunge_fx",   LungueTrailFxFn,         assets_lightning_lunge_fx                               ),
        Prefab("spear_wathgrithr_lightning_fx",         FxFn,                    assets_lightning_fx                                      )
