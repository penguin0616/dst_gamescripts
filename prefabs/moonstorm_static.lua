local assets =
{
    Asset("ANIM", "anim/static_ball_contained.zip"),
}

local prefabs =
{
    "moonstorm_static_item",
}

local item_assets =
{
    Asset("ANIM", "anim/static_ball_contained.zip"),
}

local function onattackedfn(inst)
    if inst.AnimState:IsCurrentAnimation("idle") then
        inst.SoundEmitter:PlaySound("moonstorm/common/static_ball_contained/hit")
        inst.AnimState:PlayAnimation("hit", false)
        inst.AnimState:PushAnimation("idle", true)
    end
end

local function ondeath(inst)
    if not inst.experimentcomplete then
        inst.SoundEmitter:KillSound("loop")
        inst.AnimState:PlayAnimation("explode", false)
        inst.SoundEmitter:PlaySound("moonstorm/common/static_ball_contained/explode")

        inst:ListenForEvent("animover", inst.Remove)
    end
end

local function finished_callback(inst)
    local item = SpawnPrefab("moonstorm_static_item")
    item.Transform:SetPosition(inst.Transform:GetWorldPosition())
    inst:Remove()
end
local function finished(inst)
    inst.SoundEmitter:KillSound("loop")
    inst.AnimState:PlayAnimation("finish", false)
    inst.SoundEmitter:PlaySound("moonstorm/common/static_ball_contained/finish")
    inst.experimentcomplete = true
    inst:ListenForEvent("animover", finished_callback)
end

local function stormstopped_callback(inst)
    if TheWorld.net.components.moonstorms and not TheWorld.net.components.moonstorms:IsInMoonstorm(inst) then
        inst.components.health:Kill()
    end
end
local function stormstopped(inst)
    inst:DoTaskInTime(1, stormstopped_callback)
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
	inst.entity:AddDynamicShadow()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

    MakeObstaclePhysics(inst, .2)

    inst.AnimState:SetBuild("static_ball_contained")
    inst.AnimState:SetBank("static_contained")
    inst.AnimState:PlayAnimation("idle", true)

    inst.scrapbook_specialinfo = "MOONSTORMSTATIC"

    inst.DynamicShadow:Enable(true)
    inst.DynamicShadow:SetSize(1, .5)

    inst.Light:SetColour(111/255, 111/255, 227/255)
    inst.Light:SetIntensity(0.75)
    inst.Light:SetFalloff(0.5)
    inst.Light:SetRadius(2)
    inst.Light:Enable(false)

    inst:AddTag("moonstorm_static")
    inst:AddTag("soulless")

    inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")

    inst.persists = false

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end
    inst.finished = finished

    inst:AddComponent("health")
    inst.components.health:SetMaxHealth(TUNING.MOONSTORM_SPARK_HEALTH)
    inst.components.health.nofadeout = true

    inst:AddComponent("combat")
    inst:ListenForEvent("attacked", onattackedfn)
    inst:ListenForEvent("death", ondeath)

    inst.SoundEmitter:PlaySound("moonstorm/common/static_ball_contained/idle_LP","loop")

    inst:ListenForEvent("ms_stormchanged", function(w, data)
        if data ~= nil and data.stormtype == STORM_TYPES.MOONSTORM then
            stormstopped(inst)
        end
    end, TheWorld)

    inst:AddComponent("inspectable")

    return inst
end

-- NOWAG
local WAG_TOOLS = {}
for i = 1, 5 do
    table.insert(WAG_TOOLS, "wagstaff_tool_"..i)
end
local function should_accept_item(inst, item)
    if not inst._needs_tool then
        return false
    end
    local item_prefab = item.prefab
    for _, tool_prefab in pairs(WAG_TOOLS) do
        if item_prefab == tool_prefab then
            return true
        end
    end
    return false
end

local function on_refuse_item(inst, giver, item)
    if giver.components.talker then
        giver.components.talker:Say(GetActionFailString(giver, "GIVE", "BUSY"))
    end
end

local function on_get_item_from_player(inst, giver, item)
    if TheWorld.components.moonstormmanager then
        TheWorld.components.moonstormmanager:foundWaglessTool()
    end
end

local function on_nowag_need_tool(inst)
    inst.AnimState:PlayAnimation("needtool_idle", true)
    inst._needs_tool = true
end
local function on_nowag_need_tool_over(inst)
    inst.AnimState:PlayAnimation("idle", true)
    inst._needs_tool = nil
end

local function on_nowag_activated(inst)
    if TheWorld.components.moonstormmanager then
        TheWorld.components.moonstormmanager:beginNoWagstaffDefence()
        inst.AnimState:PlayAnimation("pregame_pst", false)
        inst.AnimState:PushAnimation("idle", true)
        return true
    else
        ErodeAway(inst)
        return false
    end
end

local function nowag_fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
	inst.entity:AddDynamicShadow()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

    MakeObstaclePhysics(inst, .2)

    inst.AnimState:SetBuild("static_ball_contained")
    inst.AnimState:SetBank("static_contained")
    inst.AnimState:PlayAnimation("pregame_idle", true)

    inst.scrapbook_specialinfo = "MOONSTORMSTATIC"

    inst.DynamicShadow:Enable(true)
    inst.DynamicShadow:SetSize(1, .5)

    inst.Light:SetColour(111/255, 111/255, 227/255)
    inst.Light:SetIntensity(0.75)
    inst.Light:SetFalloff(0.5)
    inst.Light:SetRadius(2)
    inst.Light:Enable(false)

    inst:AddTag("moonstorm_static")
    inst:AddTag("soulless")

    inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end
    inst.finished = finished

    inst:AddComponent("health")
    inst.components.health:SetMaxHealth(TUNING.MOONSTORM_SPARK_HEALTH)
    inst.components.health.nofadeout = true

    inst:AddComponent("combat")
    inst:ListenForEvent("attacked", onattackedfn)
    inst:ListenForEvent("death", ondeath)

    inst.SoundEmitter:PlaySound("moonstorm/common/static_ball_contained/idle_LP","loop")

    inst:ListenForEvent("ms_stormchanged", function(w, data)
        if data ~= nil and data.stormtype == STORM_TYPES.MOONSTORM then
            stormstopped(inst)
        end
    end, TheWorld)

    inst:AddComponent("inspectable")
    inst.components.inspectable.nameoverride = "MOONSTORM_STATIC"

    inst:AddComponent("trader")
    inst.components.trader:SetAcceptTest(should_accept_item)
    inst.components.trader:SetOnRefuse(on_refuse_item)
    inst.components.trader.onaccept = on_get_item_from_player

	inst:AddComponent("activatable")
    inst.components.activatable.OnActivate = on_nowag_activated
    inst.components.activatable.inactive = true

    inst:ListenForEvent("need_tool", on_nowag_need_tool)
    inst:ListenForEvent("need_tool_over", on_nowag_need_tool_over)

    inst.persists = false

    return inst
end

-- ITEM
local IDLE_SOUND_LOOP_NAME = "loop"

local function OnEntityWake(inst)
    if inst:IsInLimbo() or inst:IsAsleep() then
        return
    end

    if not inst.SoundEmitter:PlayingSound(IDLE_SOUND_LOOP_NAME) then
        inst.SoundEmitter:PlaySound("moonstorm/common/static_ball_contained/finished_idle_LP", IDLE_SOUND_LOOP_NAME)
    end
end

local function OnEntitySleep(inst)
    inst.SoundEmitter:KillSound(IDLE_SOUND_LOOP_NAME)
end

local function itemfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("static_contained")
    inst.AnimState:SetBuild("static_ball_contained")
    inst.AnimState:PlayAnimation("finish_idle", true)

    inst:AddTag("moonstorm_static")

    MakeInventoryFloatable(inst, "med", 0.05, 0.68)

    inst.scrapbook_anim = "finish_idle"

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("tradable")
    inst:AddComponent("inspectable")
    inst:AddComponent("inventoryitem")

    inst:AddComponent("upgrader")
    inst.components.upgrader.upgradetype = UPGRADETYPES.SPEAR_LIGHTNING

    inst.OnEntityWake  = OnEntityWake
    inst.OnEntitySleep = OnEntitySleep

    inst:ListenForEvent("exitlimbo", inst.OnEntityWake)
    inst:ListenForEvent("enterlimbo", inst.OnEntitySleep)

    return inst
end

return Prefab("moonstorm_static", fn, assets, prefabs),
    Prefab("moonstorm_static_nowag", nowag_fn, assets, prefabs),
    Prefab("moonstorm_static_item", itemfn, item_assets)
