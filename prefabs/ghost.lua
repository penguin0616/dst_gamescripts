local assets =
{
    Asset("ANIM", "anim/player_ghost_withhat.zip"),
    Asset("ANIM", "anim/ghost_build.zip"),
    Asset("SOUND", "sound/ghost.fsb"),
}

local brain = require "brains/ghostbrain"

local function AbleToAcceptTest(inst, item)
    return false, (item:HasTag("reviver") and "GHOSTHEART") or nil
end

local function OnDeath(inst)
    inst.components.aura:Enable(false)
end

local GHOSTLYFRIEND_AURA_SAFE_TAGS = {"abigail", "ghostlyfriend"}
local function AuraTest(inst, target)
    if inst.components.combat:TargetIs(target) or (target.components.combat.target ~= nil and target.components.combat:TargetIs(inst)) then
        return true
    else
        return not target:HasAnyTag(GHOSTLYFRIEND_AURA_SAFE_TAGS)
    end
end

local function OnAttacked(inst, data)
    if not data.attacker then
        inst.components.combat:SetTarget(nil)
    elseif not data.attacker:HasTag("noauradamage") then
        inst.components.combat:SetTarget(data.attacker)
    end
end

local function KeepTargetFn(inst, target)
    if target and inst:GetDistanceSqToInst(target) < TUNING.GHOST_FOLLOW_DSQ then
        return true
    else
        inst.brain.followtarget = nil
        return false
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

    MakeGhostPhysics(inst, .5, .5)

    inst.AnimState:SetBloomEffectHandle("shaders/anim_bloom_ghost.ksh")
    inst.AnimState:SetLightOverride(TUNING.GHOST_LIGHT_OVERRIDE)

    inst.Light:SetIntensity(.6)
    inst.Light:SetRadius(.5)
    inst.Light:SetFalloff(.6)
    inst.Light:Enable(true)
    inst.Light:SetColour(180/255, 195/255, 225/255)

    inst.AnimState:SetBank("ghost")
    inst.AnimState:SetBuild("ghost_build")
    inst.AnimState:PlayAnimation("idle", true)
    --inst.AnimState:SetMultColour(1,1,1,.6)

    inst:AddTag("monster")
    inst:AddTag("hostile")
    inst:AddTag("ghost")
    inst:AddTag("flying")
    inst:AddTag("noauradamage")

    --trader (from trader component) added to pristine state for optimization
    inst:AddTag("trader")

    inst.SoundEmitter:PlaySound("dontstarve/ghost/ghost_howl_LP", "howl")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:SetBrain(brain)

    inst:AddComponent("locomotor")
    inst.components.locomotor.walkspeed = TUNING.GHOST_SPEED
    inst.components.locomotor.runspeed = TUNING.GHOST_SPEED
    inst.components.locomotor.directdrive = true

    inst:SetStateGraph("SGghost")

    inst:AddComponent("sanityaura")
    inst.components.sanityaura.aura = -TUNING.SANITYAURA_MED

    inst:AddComponent("inspectable")

    inst:AddComponent("health")
    inst.components.health:SetMaxHealth(TUNING.GHOST_HEALTH)

    inst:AddComponent("combat")
    inst.components.combat.defaultdamage = TUNING.GHOST_DAMAGE
    inst.components.combat.playerdamagepercent = TUNING.GHOST_DMG_PLAYER_PERCENT
    inst.components.combat:SetKeepTargetFunction(KeepTargetFn)

    inst:AddComponent("aura")
    inst.components.aura.radius = TUNING.GHOST_RADIUS
    inst.components.aura.tickperiod = TUNING.GHOST_DMG_PERIOD
    inst.components.aura.auratestfn = AuraTest

    --Added so you can attempt to give hearts to trigger flavour text when the action fails
    inst:AddComponent("trader")
    inst.components.trader:SetAbleToAcceptTest(AbleToAcceptTest)

    inst:ListenForEvent("death", OnDeath)
    inst:ListenForEvent("attacked", OnAttacked)

    ------------------

    return inst
end

-- WENDY DECORATED GRAVE GUARD GHOST
local guardbrain = require "brains/graveguard_ghostbrain"

local function GuardAuraTest(inst, target)
    if inst.components.combat:TargetIs(target) or (target.components.combat.target ~= nil and target.components.combat:TargetIs(inst)) then
        return true
    else
        return not target:HasAnyTag(GHOSTLYFRIEND_AURA_SAFE_TAGS)
    end
end

local function GuardKeepTargetFn(inst, target)
    if target and inst:GetDistanceSqToInst(target) < TUNING.GHOST_FOLLOW_DSQ then
        return true
    else
        inst.brain.followtarget = nil
        return false
    end
end

local function link_to_gravestone(inst, gravestone)
    inst.UnlinkFromGravestone = function()
		if gravestone:IsValid() then
			gravestone:RemoveEventCallback("onremove", inst.UnlinkFromGravestone, inst)
			gravestone.ghost = nil
		end
        inst.UnlinkFromGravestone = nil
    end

    gravestone:ListenForEvent("onremove", inst.UnlinkFromGravestone, inst)

    inst.components.knownlocations:RememberLocation("home", gravestone:GetPosition(), true)
end

local function graveguard_fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

    MakeGhostPhysics(inst, .5, .5)

    inst.AnimState:SetBloomEffectHandle("shaders/anim_bloom_ghost.ksh")
    inst.AnimState:SetLightOverride(TUNING.GHOST_LIGHT_OVERRIDE)
    inst.AnimState:SetMultColour(176/255, 240/255, 247/255, 1)
    inst.AnimState:SetBank("ghost")
    inst.AnimState:SetBuild("ghost_build")
    inst.AnimState:PlayAnimation("idle", true)

    inst.Light:SetIntensity(.6)
    inst.Light:SetRadius(.5)
    inst.Light:SetFalloff(.6)
    inst.Light:Enable(true)
    inst.Light:SetColour(180/255, 195/255, 225/255)

    inst:AddTag("monster")
    inst:AddTag("hostile")
    inst:AddTag("ghost")
    inst:AddTag("flying")
    inst:AddTag("noauradamage")

    --trader (from trader component) added to pristine state for optimization
    inst:AddTag("trader")

    inst.SoundEmitter:PlaySound("dontstarve/ghost/ghost_howl_LP", "howl")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    --
    local aura = inst:AddComponent("aura")
    aura.radius = TUNING.GHOST_RADIUS
    aura.tickperiod = TUNING.GHOST_DMG_PERIOD
    aura.auratestfn = GuardAuraTest

    --
    local combat = inst:AddComponent("combat")
    combat.defaultdamage = TUNING.GHOST_DAMAGE
    combat.playerdamagepercent = TUNING.GHOST_DMG_PLAYER_PERCENT
    combat:SetKeepTargetFunction(GuardKeepTargetFn)

    --
    local health = inst:AddComponent("health")
    health:SetMaxHealth(TUNING.GHOST_HEALTH)

    --
    local inspectable = inst:AddComponent("inspectable")
    inspectable:SetNameOverride("ghost")

    --
    inst:AddComponent("knownlocations")

    --
    local locomotor = inst:AddComponent("locomotor")
    locomotor.walkspeed = TUNING.GHOST_SPEED
    locomotor.runspeed = TUNING.GHOST_SPEED
    locomotor.directdrive = true

    --
    local sanityaura = inst:AddComponent("sanityaura")
    sanityaura.aura = -TUNING.SANITYAURA_MED

    --Added so you can attempt to give hearts to trigger flavour text when the action fails
    local trader = inst:AddComponent("trader")
    trader:SetAbleToAcceptTest(AbleToAcceptTest)

    --
    inst:SetBrain(guardbrain)
    inst:SetStateGraph("SGghost")

    --
    inst:ListenForEvent("death", OnDeath)
    inst:ListenForEvent("attacked", OnAttacked)

    inst.LinkToHome = link_to_gravestone

    --
    inst.persists = false

    return inst
end

return Prefab("ghost", fn, assets),
    Prefab("graveguard_ghost", graveguard_fn, assets)
