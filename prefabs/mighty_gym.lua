require "prefabutil"

local assets =
{
    Asset("ANIM", "anim/mighty_gym.zip"),
    Asset("ANIM", "anim/fx_wolfgang.zip"),
    Asset("MINIMAP_IMAGE", "mighty_gym"),
}

local prefabs =
{
    "mighty_gym_bell",
    "mighty_gym_bell_fail_fx",
    "mighty_gym_bell_succeed_fx",
    "mighty_gym_bell_perfect_fx",
    "potatosack"    
}

-----------------------------------------------------------------------

local function onhammered(inst, worker)
    if inst.components.burnable ~= nil and inst.components.burnable:IsBurning() then
        inst.components.burnable:Extinguish()
    end
    inst.components.lootdropper:DropLoot()
    local fx = SpawnPrefab("collapse_big")
    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    fx:SetMaterial("wood")
    inst:Remove()
end

local function onhit(inst, worker)
    if not inst:HasTag("burnt") then
        inst.AnimState:PlayAnimation("hit")
        inst.AnimState:PushAnimation("idle_empty", true)
        inst.components.mightygym:UnloadWeight()
    end
end

local function onbuilt(inst)
    for i=1, 2 do
        local potatosack = SpawnPrefab("potatosack")
        inst.components.mightygym:LoadWeight(potatosack)
    end
    inst.AnimState:PlayAnimation("place")
    inst.SoundEmitter:PlaySound("wolfgang2/common/gym/place")
end

local function onburnt(inst)
    inst:RemoveComponent("heavyobstacleusetarget")
    inst.components.mightygym:UnloadWeight()
end

local function OnUseHeavy(inst, doer, heavy_item)
    if heavy_item == nil then
		return
	end

	doer.components.inventory:RemoveItem(heavy_item)
	inst.components.mightygym:LoadWeight(heavy_item)

	return true
end

--------------------------------------------------

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

    inst.MiniMapEntity:SetIcon("mighty_gym.png")

    MakeObstaclePhysics(inst, 1)

    inst:AddTag("structure")
    inst:AddTag("gym")

    inst.use_heavy_obstacle_string_key = "LOAD_GYM"

    inst.AnimState:SetBank("mighty_gym")
    inst.AnimState:SetBuild("wolfgang") --doesn't  actually matter since we'll be applying the base symbols with SetSkinsOnAnim.
    inst.AnimState:AddOverrideBuild("mighty_gym")
    inst.AnimState:OverrideSymbol("fx_star", "fx_wolfgang", "fx_star")
    inst.AnimState:OverrideSymbol("fx_star_part", "fx_wolfgang", "fx_star_part")

    inst.AnimState:PlayAnimation("idle_empty", true)

    MakeSnowCoveredPristine(inst)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:SetStateGraph("SGmighty_gym")

    inst:AddComponent("inspectable")
    inst:AddComponent("lootdropper")
    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
    inst.components.workable:SetWorkLeft(4)
    inst.components.workable:SetOnFinishCallback(onhammered)
    inst.components.workable:SetOnWorkCallback(onhit)

    inst:AddComponent("mightygym")
    inst.gymweight = net_smallbyte(inst.GUID, "mighty_gym.weight", "weightdirty")

    inst:AddComponent("heavyobstacleusetarget")
	inst.components.heavyobstacleusetarget.on_use_fn = OnUseHeavy

    inst:AddComponent("inventory")
	inst.components.inventory.ignorescangoincontainer = true
	inst.components.inventory.maxslots = 2

    inst:ListenForEvent("onbuilt", onbuilt)
    inst:ListenForEvent("onburnt", onburnt)

    MakeLargeBurnable(inst, nil, nil, true)
    MakeMediumPropagator(inst)
    MakeHauntableWork(inst)

    return inst
end

local function ding(inst, success)
    local pos = Vector3(inst.AnimState:GetSymbolPosition("meter",0,0,0))
    local fx = SpawnPrefab("mighty_gym_bell_"..success.."_fx")
    fx.Transform:SetPosition(pos.x,pos.y,pos.z)
end

local function bell_fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()
    inst.entity:AddSoundEmitter()

    inst:AddTag("NOCLICK")
    inst:AddTag("FX")

    inst.AnimState:SetBank("mighty_gym")
    inst.AnimState:SetBuild("mighty_gym")
    inst.AnimState:PlayAnimation("meter_move")
    inst.AnimState:SetPercent("meter_move", 0)
    inst.AnimState:SetFinalOffset(2)
    
    inst.ding = ding

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    return inst
end

return Prefab("mighty_gym", fn, assets, prefabs),
       Prefab("mighty_gym_bell", bell_fn, assets),
       MakePlacer("mighty_gym_placer", "mighty_gym", "mighty_gym", "idle_empty")
