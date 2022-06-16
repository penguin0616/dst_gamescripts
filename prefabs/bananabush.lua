local assets = 
{
    Asset("ANIM", "anim/bananabush.zip"),
    Asset("MINIMAP_IMAGE", "bananabush"),
}

local prefabs = 
{
    "cave_banana",
    "dug_bananabush"
}

local function set_empty(inst)
    inst.AnimState:PushAnimation("idle_empty")
end

local function grow_empty(inst)
    set_empty(inst)
end

local function set_small(inst)
    inst.AnimState:PlayAnimation("grow_none_to_small")
    inst.AnimState:PushAnimation("idle_small")
end

local function grow_small(inst)
    set_small(inst)
end

local function set_medium(inst)
    inst.AnimState:PlayAnimation("grow_small_to_medium")
    inst.AnimState:PushAnimation("idle_medium")
end

local function grow_medium(inst)
    set_medium(inst)
end

local function set_big(inst)
    if not inst.AnimState:IsCurrentAnimation("idle_big") then
        inst.AnimState:PlayAnimation("grow_medium_to_big")
        inst.AnimState:PushAnimation("idle_big")
        inst.components.pickable:Regen()
    end
end

local function grow_big(inst)
    set_big(inst)
end

local BANANABUSH_GROWTH_STAGES = {
    {
        name = "empty",
        time = function(inst) return TUNING.TOTAL_DAY_TIME end,
        fn = set_empty,
        growfn = grow_empty,
    },
    {
        name = "small",
        time = function(inst) return TUNING.TOTAL_DAY_TIME end,
        fn = set_small,
        growfn = grow_small,
    },
    {
        name = "normal",
        time = function(inst) return TUNING.TOTAL_DAY_TIME end,
        fn = set_medium,
        growfn = grow_medium,
    },
    {
        name = "tall",
        time = function(inst) return TUNING.TOTAL_DAY_TIME end,
        fn = set_big,
        growfn = grow_big,
    },
}

local function OnDig(inst, worker)
    if inst.components.pickable ~= nil and inst.components.lootdropper ~= nil then 
        if inst.components.pickable:IsBarren() then
            inst.components.lootdropper:SpawnLootPrefab("twigs")
            inst.components.lootdropper:SpawnLootPrefab("twigs")
        else
            if inst.components.pickable:CanBePicked() then
                local pt = inst:GetPosition()
                pt.y = pt.y + (inst.components.pickable.dropheight or 0)
                inst.components.lootdropper:SpawnLootPrefab(inst.components.pickable.product, pt)
            end

            inst.components.lootdropper:SpawnLootPrefab("dug_"..inst.prefab)
        end
    end

    inst:Remove()
end

local function OnPicked(inst, picker)
    if inst.components.pickable ~= nil then
        if inst.components.pickable:IsBarren() then
            inst.AnimState:PlayAnimation("idle_to_dead")
            inst.AnimState:PushAnimation("dead", false)
            inst.components.growable:StopGrowing()
        else
            inst.AnimState:PlayAnimation("picked")
            inst.AnimState:PushAnimation("idle_empty")

            inst.components.growable:SetStage(1)
        end
    end
end

local function OnTransplant(inst)
    inst.components.growable:SetStage(1)
    inst.components.growable:StopGrowing()
    inst.AnimState:PlayAnimation("dead")
    inst.components.pickable:MakeBarren()
end

local function MakeEmpty(inst)
    if inst.AnimState:IsCurrentAnimation("dead") then
        inst.AnimState:PlayAnimation("dead_to_idle")
        inst.AnimState:PushAnimation("idle_empty")
        inst.components.growable:StartGrowing()
    else
        set_empty(inst)
    end
end

local function OnRegen(inst)
    inst.components.growable:Resume()
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

    MakeSmallObstaclePhysics(inst, .1)

    inst:AddTag("bush")
    inst:AddTag("plant")

    inst.MiniMapEntity:SetIcon("bananabush.png")

    inst.AnimState:SetBank("bananabush")
    inst.AnimState:SetBuild("bananabush")
    inst.AnimState:PlayAnimation("idle_small", true)

    MakeSnowCoveredPristine(inst)

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    --------------------------------------------------------------------------
    inst:AddComponent("pickable")
    inst.components.pickable.picksound = "dontstarve/wilson/harvest_berries"
    inst.components.pickable.onpickedfn = OnPicked
    inst.components.pickable:SetUp("cave_banana", TUNING.BERRY_REGROW_TIME)
    inst.components.pickable.ontransplantfn = OnTransplant
    inst.components.pickable:SetMakeEmptyFn(MakeEmpty)
    inst.components.pickable:SetOnRegenFn(OnRegen)
    inst.components.pickable:MakeEmpty()

    --------------------------------------------------------------------------
    inst:AddComponent("growable")
    inst.components.growable.stages = BANANABUSH_GROWTH_STAGES
    inst.components.growable:SetStage(1)
    inst.components.growable.loopstages = false
    inst.components.growable.springgrowth = true
    inst.components.growable:StartGrowing()

    --------------------------------------------------------------------------
    if not GetGameModeProperty("disable_transplanting") then
        inst:AddComponent("workable")
        inst.components.workable:SetWorkAction(ACTIONS.DIG)
        inst.components.workable:SetWorkLeft(1)
        inst.components.workable:SetOnFinishCallback(OnDig)
    end

    --------------------------------------------------------------------------
    inst:AddComponent("lootdropper")

    --------------------------------------------------------------------------
    inst:AddComponent("inspectable")

    --------------------------------------------------------------------------
    MakeSnowCovered(inst)
    MakeNoGrowInWinter(inst)

    --------------------------------------------------------------------------
    MakeLargeBurnable(inst)
    MakeMediumPropagator(inst)

    --------------------------------------------------------------------------
    MakeHauntableIgnite(inst)

    return inst
end

return Prefab("bananabush", fn, assets, prefabs)