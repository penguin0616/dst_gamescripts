local assets =
{
    Asset("ANIM", "anim/grass.zip"),
    Asset("ANIM", "anim/reeds_monkeytails.zip"),
    Asset("SOUND", "sound/common.fsb"),
    Asset("MINIMAP_IMAGE", "monkeytails"),
}

local prefabs =
{
    "cutreeds",
}

local function onpickedfn(inst)
    inst.SoundEmitter:PlaySound("dontstarve/wilson/pickup_reeds")
    inst.AnimState:PlayAnimation("picking")
    inst.AnimState:PushAnimation("picked")
end

local function onregenfn(inst)
    inst.AnimState:PlayAnimation("grow")
    inst.AnimState:PushAnimation("idle", true)
end

local function makeemptyfn(inst)
    inst.AnimState:PlayAnimation("picked")
end

local function makebarrenfn(inst, wasempty)
    if not POPULATING and inst.components.witherable ~= nil and inst.components.witherable:IsWithered() then
        inst.AnimState:PlayAnimation((wasempty and "empty_to_dead") or "full_to_dead")
        inst.AnimState:PushAnimation("idle_dead", false)
    else
        inst.AnimState:PlayAnimation("idle_dead")
    end
end

local function ontransplantfn(inst)
    inst.components.pickable:MakeBarren()
end

local function fn()
    local inst = CreateEntity()
    
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

    inst.MiniMapEntity:SetIcon("monkeytails.png")
    
    inst:AddTag("plant")
    inst:AddTag("silviculture") -- for silviculture book

    --witherable (from witherable component) added to pristine state for optimization
    inst:AddTag("witherable")
    
    inst.AnimState:SetBank("grass")
    inst.AnimState:SetBuild("reeds_monkeytails")
    inst.AnimState:PlayAnimation("idle", true)
    
    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    ------------------------------------------------------------------------
    inst.AnimState:SetTime(math.random() * 2)
    local color = 0.75 + math.random() * 0.25
    inst.AnimState:SetMultColour(color, color, color, 1)

    ------------------------------------------------------------------------
    inst:AddComponent("pickable")
    inst.components.pickable.picksound = "dontstarve/wilson/pickup_reeds"
    inst.components.pickable:SetUp("cutreeds", TUNING.REEDS_REGROW_TIME)
    inst.components.pickable.onregenfn = onregenfn
    inst.components.pickable.onpickedfn = onpickedfn
    inst.components.pickable.makeemptyfn = makeemptyfn

    inst.components.pickable.makebarrenfn = makebarrenfn
    inst.components.pickable.max_cycles = 20
    inst.components.pickable.cycles_left = 20
    inst.components.pickable.ontransplantfn = ontransplantfn

    ------------------------------------------------------------------------
    inst:AddComponent("witherable")

    ------------------------------------------------------------------------
    inst:AddComponent("inspectable")

    ------------------------------------------------------------------------
    inst:AddComponent("fuel")
    inst.components.fuel.fuelvalue = TUNING.SMALL_FUEL

    ------------------------------------------------------------------------
    MakeSmallBurnable(inst, TUNING.SMALL_FUEL)
    MakeSmallPropagator(inst)

    ------------------------------------------------------------------------
    MakeNoGrowInWinter(inst)

    ------------------------------------------------------------------------
    MakeHauntableIgnite(inst)
    
    return inst
end

return Prefab("monkeytail", fn, assets, prefabs)
