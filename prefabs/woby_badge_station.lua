require "prefabutil"

local assets =
{
    Asset("ANIM", "anim/woby_badge_station.zip"),
}

local prefabs =
{
    "collapse_small",
}

local function OnHammered(inst)
    inst.components.lootdropper:DropLoot()

    local fx = SpawnPrefab("collapse_small")
    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    fx:SetMaterial("wood")

    inst:Remove()
end

local function OnHit(inst)
    if not inst:HasTag("burnt") then
        inst.AnimState:PlayAnimation("hit")
        inst.AnimState:PushAnimation("idle", false)
    end
end

local function OnBuilt(inst)
    inst.AnimState:PlayAnimation("place")
    inst.AnimState:PushAnimation("idle", false)

    inst.SoundEmitter:PlaySound("meta5/walter/badge_station_build")
end

local function OnBurnt(inst)
    DefaultBurntStructureFn(inst)

    inst:RemoveComponent("wobybadgestation")
end

local function OnSave(inst, data)
    if inst.components.burnable ~= nil and inst.components.burnable:IsBurning() or inst:HasTag("burnt") then
        data.burnt = true
    end
end

local function OnLoad(inst, data)
    if data ~= nil and data.burnt and inst.components.burnable ~= nil then
        inst.components.burnable.onburnt(inst)
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

	inst:SetDeploySmartRadius(DEPLOYSPACING_RADIUS[DEPLOYSPACING.DEFAULT] / 2)
    MakeObstaclePhysics(inst, 0.4)

    inst:AddTag("structure")
    inst:AddTag("wobybadgestation")

    inst.MiniMapEntity:SetIcon("woby_badge_station.png")

    inst.AnimState:SetBank("woby_badge_station")
    inst.AnimState:SetBuild("woby_badge_station")
    inst.AnimState:PlayAnimation("idle")

    MakeSnowCoveredPristine(inst)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.OnBuiltFn = OnBuilt

    inst:AddComponent("inspectable")
    inst:AddComponent("lootdropper")
    inst:AddComponent("wobybadgestation")

    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
    inst.components.workable:SetWorkLeft(4)
    inst.components.workable:SetOnFinishCallback(OnHammered)
    inst.components.workable:SetOnWorkCallback(OnHit)

    inst.OnSave = OnSave
    inst.OnLoad = OnLoad

    MakeMediumBurnable(inst, nil, nil, true)
    MakeMediumPropagator(inst)

    inst.components.burnable:SetOnBurntFn(OnBurnt)

    MakeSnowCovered(inst)
    MakeHauntableWork(inst)

    return inst
end

return
    Prefab("woby_badge_station", fn, assets, prefabs),
    MakePlacer("woby_badge_station_placer", "woby_badge_station", "woby_badge_station", "idle")
