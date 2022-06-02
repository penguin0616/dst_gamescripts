local assets =
{
    Asset("ANIM", "anim/carnival_sparkle_bush.zip"),
}

local prefs = {}

local function PlayAnim(proxy, anim, scale, flip)
    local inst = CreateEntity()

    inst:AddTag("FX")
    --[[Non-networked entity]]
    inst.entity:SetCanSleep(false)
    inst.persists = false

    inst.entity:AddTransform()
    inst.entity:AddAnimState()

    inst.Transform:SetFromProxy(proxy.GUID)

    inst.AnimState:SetBank("carnival_sparkle_bush")
    inst.AnimState:SetBuild("carnival_sparkle_bush")
    local scale = 0.75
    inst.AnimState:SetScale(scale, scale)
    --inst.AnimState:SetMultColour(1, 1, 1, .5)
    inst.AnimState:PlayAnimation("idle", true)
    inst.AnimState:SetFinalOffset(1)
    
    inst:ListenForEvent("onremove", function() inst:Remove() end, proxy )

    proxy.fx_ent = inst
end

local function DisableNetwork(inst) --do we need this?
    inst.Network:SetClassifiedTarget(inst)
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddNetwork()

    inst:AddTag("FX")
    --inst:AddTag("shadowtrail") maybe don't care to track this

    --Dedicated server does not need to spawn the local fx
    if not TheNet:IsDedicated() then
        inst._complete = false
    end

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false
    inst:DoTaskInTime(0, PlayAnim)
    inst:DoTaskInTime(.5, DisableNetwork) --do we need this?
    
    return inst
end

return Prefab("carnival_sparkle_bush", fn, assets, prefs)