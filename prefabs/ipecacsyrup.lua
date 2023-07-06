local assets =
{
    Asset("ANIM", "anim/ipecacsyrup.zip"),
    Asset("INV_IMAGE", "ipecacsyrup"),
}

local prefabs =
{
    "ipecacsyrup_buff",
    "poop",
}

local function syrup_OnEaten(inst, eater)
    if eater:HasTag("ipecacsusceptible") then
        eater:AddDebuff("ipecacsyrup_buff", "ipecacsyrup_buff")
    end
end

local function fn_syrup()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)
    MakeInventoryFloatable(inst)

    inst.AnimState:SetBank("ipecacsyrup")
    inst.AnimState:SetBuild("ipecacsyrup")
    inst.AnimState:PlayAnimation("idle")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    --
    local edible = inst:AddComponent("edible")
    edible.foodtype = FOODTYPE.VEGGIE
    edible.healthvalue = -TUNING.HEALING_MED
    edible.hungervalue = TUNING.CALORIES_TINY
    --edible.sanityvalue = 0 -- this is the default
    edible:SetOnEatenFn(syrup_OnEaten)

    --
    local stackable = inst:AddComponent("stackable")
    stackable.maxsize = TUNING.STACK_SIZE_LARGEITEM

    --
    inst:AddComponent("tradable")

    --
    inst:AddComponent("inspectable")

    --
    inst:AddComponent("inventoryitem")

    --
    MakeSmallBurnable(inst)
    MakeSmallPropagator(inst)

    --
    MakeHauntableLaunch(inst)

    return inst
end

----
local IPECAC_TICK_TIMERNAME = "pooptick"

local function buff_OnAttached(inst, target)
    inst.entity:SetParent(target.entity)
    inst.Transform:SetPosition(0,0,0)
    inst.components.timer:StartTimer(IPECAC_TICK_TIMERNAME, TUNING.IPECAC_TASK_TIME)

    local stop_fn = function() inst.components.debuff:Stop() end
    inst:ListenForEvent("death", stop_fn, target)
    inst:ListenForEvent("onremove", stop_fn, target)
end

local function buff_OnExtended(inst, target)
    -- Just reset our count. We don't want subsequent uses to stack up.
    inst._tick_count = TUNING.IPECAC_POOP_COUNT
end

local function buff_DoTick(inst)
    if inst._tick_count == 0 then
        inst.components.debuff:Stop()
    else
        inst._tick_count = inst._tick_count - 1
        inst.components.timer:StartTimer(IPECAC_TICK_TIMERNAME, TUNING.IPECAC_TASK_TIME)
    end

    local target = inst.components.debuff.target
    if target then
        SpawnPrefab("poop").Transform:SetPosition(target.Transform:GetWorldPosition())

        target:PushEvent("ipecacpoop")

        local target_combat = target.components.combat
        local target_health = target.components.health

        -- Damage amount is the same as a red mushroom.
        local damage = TUNING.HEALING_MED
        if target_combat then
            target_combat:GetAttacked(inst, damage)
        elseif target_health then
            target_health:DoDelta(-damage, nil, inst.prefab, nil, inst)
        end
    end
end

local function buff_OnTimerDone(inst, data)
    if data.name == IPECAC_TICK_TIMERNAME then
        buff_DoTick(inst)
    end
end

local function buff_OnSave(inst, data)
    data.tick_count = inst._tick_count
end

local function buff_OnLoad(inst, data)
    if data and data.tick_count then
        inst._tick_count = data.tick_count
    end
end

local function fn_buff()
    local inst = CreateEntity()

    if not TheWorld.ismastersim then
        -- Meant for non-clients
        inst:DoTaskInTime(0, inst.Remove)
        return inst
    end

    inst.entity:AddTransform()

    inst._tick_count = TUNING.IPECAC_POOP_COUNT

    --[[Non-networked entity]]
    inst.entity:Hide()
    inst.persists = false

    inst:AddTag("CLASSIFIED")

    --
    local debuff = inst:AddComponent("debuff")
    debuff:SetAttachedFn(buff_OnAttached)
    debuff:SetDetachedFn(inst.Remove)
    debuff:SetExtendedFn(buff_OnExtended)

    --
    inst:AddComponent("timer")
    inst:ListenForEvent("timerdone", buff_OnTimerDone)

    --
    inst.OnSave = buff_OnSave
    inst.OnLoad = buff_OnLoad

    return inst
end

return Prefab("ipecacsyrup", fn_syrup, assets, prefabs),
    Prefab("ipecacsyrup_buff", fn_buff, assets)