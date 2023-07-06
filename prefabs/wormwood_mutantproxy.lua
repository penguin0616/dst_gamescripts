local assets =
{
    Asset("ANIM", "anim/lunar_transformation.zip")
}

local FINISH_SPAWN_TIMERNAME = "finishspawn"
local SPAWN_LIFETIME = 15*FRAMES

local function onbuilt(inst, data)
    inst.builder = data.builder

    inst:ListenForEvent("onremove", function(_) inst.builder = nil end, inst.builder)
end

local function MakeProxy(product)
    local proxy_prefabs = { product }

    local function finish_spawn(inst)
        local product_instance = SpawnPrefab(product)
        product_instance.Transform:SetPosition(inst.Transform:GetWorldPosition())
        if inst.builder then
            product_instance:PushEvent("spawnedbywormwoodproxy", inst.builder)
        end
    end

    local function timerdone(inst, data)
        if data.name == FINISH_SPAWN_TIMERNAME then
            finish_spawn(inst)
        end
    end

    local function proxy_fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddSoundEmitter()
        inst.entity:AddNetwork()

        inst.AnimState:SetBank("lunar_transformation")
        inst.AnimState:SetBuild("lunar_transformation")
        inst.AnimState:PlayAnimation("transform")
        inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
        inst.AnimState:SetFinalOffset(1)

        inst:SetPhysicsRadiusOverride(2.0) -- For spacing when crafting.

        inst.entity:SetPristine()
        if not TheWorld.ismastersim then
            return inst
        end

        inst:ListenForEvent("timerdone", timerdone)
        inst:ListenForEvent("onbuilt", onbuilt)
        inst:ListenForEvent("animover", inst.Remove)

        local timer = inst:AddComponent("timer")
        timer:StartTimer(FINISH_SPAWN_TIMERNAME, SPAWN_LIFETIME)

        return inst
    end

    return Prefab("wormwood_mutantproxy_"..product, proxy_fn, assets, proxy_prefabs)
end

return MakeProxy("carrat"),
    MakeProxy("lightflier"),
    MakeProxy("fruitdragon")