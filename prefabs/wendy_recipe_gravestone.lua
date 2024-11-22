local prefabs =
{
    "gravestone",
    "wendy_recipe_gravestone_placer",
}

local WENDY_PLACER_SNAP_DISTANCE = 1.0

--
local SKELETON_TAGS = {"skeleton"}
local function wendy_recipe_gravestone_replace(inst)
    local closest_skeleton = FindEntity(inst, WENDY_PLACER_SNAP_DISTANCE, nil, SKELETON_TAGS)
    if closest_skeleton then
        closest_skeleton:Remove()
    end

    SpawnPrefab("attune_out_fx").Transform:SetPosition(inst.Transform:GetWorldPosition())

    local gravestone = ReplacePrefab(inst, "gravestone")
    gravestone.random_stone_choice = math.random(4)
    gravestone.AnimState:PlayAnimation("grave"..gravestone.random_stone_choice.."_place")
end

local function wendy_recipe_gravestone_fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddNetwork()

    inst:AddTag("NOCLICK")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst:DoTaskInTime(0, wendy_recipe_gravestone_replace)

    return inst
end

--
local WENDY_PLACER_SNAP_TAGS = {"skeleton"}
local function wendy_placer_onupdatetransform(inst)
    local ix, iy, iz = inst.Transform:GetWorldPosition()
    local skeletons = TheSim:FindEntities(ix, 0, iz, WENDY_PLACER_SNAP_DISTANCE, WENDY_PLACER_SNAP_TAGS)

    if #skeletons == 0 then
        inst._accept_placement = false
    else
        ix, iy, iz = skeletons[1].Transform:GetWorldPosition()
        inst.Transform:SetPosition(ix, 0, iz)

        inst._accept_placement = true
    end
end

local function wendy_placer_override_build_point(inst)
    -- Gamepad defaults to this behavior, but mouse input normally takes
    -- mouse position over placer position, ignoring the placer snapping
    -- to a nearby moon geyser
    return inst:GetPosition()
end

local function wendy_placer_override_testfn(inst)
    local _
    local mouse_blocked = false
    if inst.components.placer.testfn then
        _, mouse_blocked = inst.components.placer.testfn(inst:GetPosition(), inst:GetRotation())
    end

    return inst._accept_placement, mouse_blocked
end

local function wendy_placer_postinit_fn(inst)
    local placer = inst.components.placer
    placer.onupdatetransform = wendy_placer_onupdatetransform
    placer.override_build_point_fn = wendy_placer_override_build_point
    placer.override_testfn = wendy_placer_override_testfn

    inst._accept_placement = false

    inst.AnimState:Hide("flower")
end

return Prefab("wendy_recipe_gravestone", wendy_recipe_gravestone_fn, nil, prefabs),
    MakePlacer(
        "wendy_recipe_gravestone_placer", "gravestone", "gravestones", "grave1",
        nil, nil, nil, nil, nil, nil, wendy_placer_postinit_fn
    )