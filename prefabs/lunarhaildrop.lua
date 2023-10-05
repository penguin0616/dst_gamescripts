local assets =
{
    Asset("ANIM", "anim/lunarhaildrop.zip"),
}

local function fn()
    local inst = CreateEntity()

    inst:AddTag("FX")
    --[[Non-networked entity]]
    inst.entity:SetCanSleep(false)
    inst.persists = false

    inst.entity:AddTransform()
    inst.entity:AddAnimState()

    inst.AnimState:SetBuild("lunarhaildrop")
    inst.AnimState:SetBank("lunarhaildrop")
    inst.AnimState:PlayAnimation("anim")
    inst.AnimState:PushAnimation("idle")

    inst:DoTaskInTime(3, inst.Remove)

    return inst
end

return Prefab("lunarhaildrop", fn, assets)