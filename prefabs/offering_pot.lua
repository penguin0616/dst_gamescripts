require "prefabutil"

local prefabs =
{
    "collapse_small",
    "offering_pot_upgraded",
    "kelp",
}

local assets =
{
    Asset("ANIM", "anim/offering_pot.zip"),
    Asset("ANIM", "anim/offering_pot_upgraded_build.zip"),
	Asset("ANIM", "anim/ui_chest_2x2.zip"),
}

local NUM_KELPS = 6
local KELP_LAYERS = {}
for i = 1, NUM_KELPS do
    table.insert(KELP_LAYERS, "kelp_"..tostring(i))
end

---------------------------------------------------------------
-- PLACER EFFECTS
local PLACER_SCALE = 1.9

local function OnUpdatePlacerHelper(helperinst)
    if not helperinst.placerinst:IsValid() then
        helperinst.components.updatelooper:RemoveOnUpdateFn(OnUpdatePlacerHelper)
        helperinst.AnimState:SetAddColour(0, 0, 0, 0)
    elseif helperinst:IsNear(helperinst.placerinst, TUNING.WURT_OFFERING_POT_RANGE) then
        helperinst.AnimState:SetAddColour(helperinst.placerinst.AnimState:GetAddColour())
    else
        helperinst.AnimState:SetAddColour(0, 0, 0, 0)
    end
end

local function CreatePlacerRing()
    local inst = CreateEntity()

    --[[Non-networked entity]]
    inst.entity:SetCanSleep(false)
    inst.persists = false

    inst.entity:AddTransform()
    inst.entity:AddAnimState()

    inst:AddTag("CLASSIFIED")
    inst:AddTag("NOCLICK")
    inst:AddTag("placer")


    inst.AnimState:SetBank("winona_battery_placement")
    inst.AnimState:SetBuild("winona_battery_placement")
    inst.AnimState:PlayAnimation("idle")
    inst.AnimState:SetAddColour(0, .2, .5, 0)
    inst.AnimState:SetLightOverride(1)
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetSortOrder(1)
    inst.AnimState:SetScale(PLACER_SCALE, PLACER_SCALE)

    inst.AnimState:Hide("inner")

    return inst
end

local function OnEnableHelper(inst, enabled, recipename, placerinst)
    if enabled then
        inst.helper = CreatePlacerRing()
        inst.helper.entity:SetParent(inst.entity)

        inst.helper:AddComponent("updatelooper")
        inst.helper.components.updatelooper:AddOnUpdateFn(OnUpdatePlacerHelper)
        inst.helper.placerinst = placerinst
        OnUpdatePlacerHelper(inst.helper)

    elseif inst.helper ~= nil then
        inst.helper:Remove()
        inst.helper = nil
    end
end

local function OnStartHelper(inst)--, recipename, placerinst)
    if inst.AnimState:IsCurrentAnimation("place") then
        inst.components.deployhelper:StopHelper()
    end
end

---------------------------------------------------------------------------------------------

local function onhammered(inst)
    inst.components.lootdropper:DropLoot()
    if inst.components.container ~= nil then
        inst.components.container:DropEverything()
    end

    local fx = SpawnPrefab("collapse_small")
    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    fx:SetMaterial("wood")
    inst:Remove()
end

local function onhit(inst, worker, workleft)
    if workleft > 0 and not inst:HasTag("burnt") then
        inst.SoundEmitter:PlaySound("dontstarve/characters/wendy/sisturn/hit")
        inst.AnimState:PlayAnimation("hit")
        inst.AnimState:PushAnimation("idle")

		if inst.components.container ~= nil then
			inst.components.container:DropEverything()
		end
    end
end

local function onbuilt(inst)
    inst.AnimState:PlayAnimation("place")
    inst.AnimState:PushAnimation("idle", false)

    inst.SoundEmitter:PlaySound("meta4/merm_alter/place")
    inst.SoundEmitter:PlaySound("dontstarve/characters/wendy/sisturn/hit")
end

local function countkelp(inst)
	local kelp = #inst.components.container:FindItems(function(item) if item.prefab == "kelp" then return true end end)
	if not kelp or kelp < 1 then
		kelp = 0
	end
	return kelp
end

local function UpdateDecor(inst, data)
    inst.SoundEmitter:PlaySound("meta4/merm_alter/offering_place")

    local count = countkelp(inst)

    for i = 1, NUM_KELPS do
        if i <= count then
            inst.AnimState:Show("kelp_"..i)
        else
            inst.AnimState:Hide("kelp_"..i)
        end
    end

    if not inst:HasTag("burnt") then
		inst.AnimState:PlayAnimation("give")
		inst.AnimState:PushAnimation("idle",true)
	end

	TheWorld:PushEvent("ms_updateofferingpotstate", {inst = inst, count=count})
end

local function getstatus(inst)
	local num_decor = inst.components.container ~= nil and inst.components.container:NumItems() or 0
	local num_slots = inst.components.container ~= nil and inst.components.container.numslots or 1
	return num_decor >= num_slots and "LOTS_OF_KELP"
			or num_decor > 0 and "SOME_KELP"
			or nil
end

local function OnSave(inst, data)
	if inst:HasTag("burnt") or (inst.components.burnable ~= nil and inst.components.burnable:IsBurning()) then
		data.burnt = true
	end
end

local function OnLoad(inst, data)
	if data ~= nil and data.burnt and inst.components.burnable ~= nil then
		inst.components.burnable.onburnt(inst)
	end
end

local function onremove(inst)
	TheWorld:PushEvent("ms_updateofferingpotstate", {inst = inst, count=0})
end

local function common_pre_mastersim(inst)
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
	inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

    MakeObstaclePhysics(inst, .5)

    inst:AddTag("structure")
    inst:AddTag("offering_pot")

    inst.AnimState:SetBank("offering_pot")
    inst.AnimState:SetBuild("offering_pot")
    inst.AnimState:PlayAnimation("idle")
	for _, v in ipairs(KELP_LAYERS) do
		inst.AnimState:Hide(v)
	end

	inst.MiniMapEntity:SetIcon("offering_pot.png")

    MakeSnowCoveredPristine(inst)

    --Dedicated server does not need deployhelper
    if not TheNet:IsDedicated() then
        local deployhelper = inst:AddComponent("deployhelper")
        deployhelper:AddRecipeFilter("mermhouse_crafted")
        deployhelper:AddRecipeFilter("mermwatchtower")
        deployhelper.onenablehelper = OnEnableHelper
        deployhelper.onstarthelper = OnStartHelper
    end

    return inst
end

local function common_pst_mastersim(inst)
    inst:AddComponent("inspectable")
	inst.components.inspectable.getstatus = getstatus

    inst:AddComponent("lootdropper")

    local workable = inst:AddComponent("workable")
    workable:SetWorkAction(ACTIONS.HAMMER)
    workable:SetWorkLeft(4)
    workable:SetOnFinishCallback(onhammered)
    workable:SetOnWorkCallback(onhit)

    MakeSmallBurnable(inst, nil, nil, true)
    MakeSmallPropagator(inst)
    MakeHauntableWork(inst)
    MakeSnowCovered(inst)

    inst:ListenForEvent("itemget", UpdateDecor)
    inst:ListenForEvent("itemlose", UpdateDecor)
    inst:ListenForEvent("onbuilt", onbuilt)
    inst:ListenForEvent("onremove", onremove)

	inst.OnSave = OnSave
	inst.OnLoad = OnLoad

	return inst
end

local function fn()
    local inst = CreateEntity()

    inst = common_pre_mastersim(inst)

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

	inst = common_pst_mastersim(inst)

	inst:AddComponent("container")
    inst.components.container:WidgetSetup("offering_pot")

    return inst
end

local function upgradedfn()
    local inst = CreateEntity()

    inst = common_pre_mastersim(inst)
    inst.AnimState:SetBuild("offering_pot_upgraded_build")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

	inst = common_pst_mastersim(inst)

	inst:AddComponent("container")
    inst.components.container:WidgetSetup("offering_pot_upgraded")

    return inst
end

local function placer_postinit_fn(inst)
	inst.AnimState:Hide("inner")

    local inner = CreateEntity()

    --[[Non-networked entity]]
    inner.entity:SetCanSleep(false)
    inner.persists = false

    inner.entity:AddTransform()
    inner.entity:AddAnimState()

    inner:AddTag("CLASSIFIED")
    inner:AddTag("NOCLICK")
    inner:AddTag("placer")

    inner.AnimState:SetBank("winona_battery_placement")
    inner.AnimState:SetBuild("winona_battery_placement")
    inner.AnimState:PlayAnimation("idle")
    inner.AnimState:SetLightOverride(1)
	inner.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
	inner.AnimState:Hide("inner")

    inner.entity:SetParent(inst.entity)
    inst.components.placer:LinkEntity(inner)

	local inner_radius_scale = PLACER_SCALE --recipe ~= nil and recipe.min_spacing ~= nil and (recipe.min_spacing / 2.2) or 1 -- roughly lines up size of animation with blocking radius
    inner.AnimState:SetScale(inner_radius_scale, inner_radius_scale)
end

return Prefab("offering_pot", fn, assets, prefabs),
       MakePlacer("offering_pot_placer", "offering_pot", "offering_pot", "placer", nil, nil, nil, nil, nil, nil, placer_postinit_fn),
       Prefab("offering_pot_upgraded", upgradedfn, assets, prefabs),
       MakePlacer("offering_pot_upgraded_placer", "offering_pot", "offering_pot_upgraded_build", "placer", nil, nil, nil, nil, nil, nil, placer_postinit_fn)
