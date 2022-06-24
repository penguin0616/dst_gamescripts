local assets =
{
    Asset("ANIM", "anim/cannon_aim_range_fx.zip"),
}

local function fn()
    local inst = CreateEntity()

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")
    --[[Non-networked entity]]
    inst.entity:SetCanSleep(false)
    inst.persists = false

    inst.entity:AddTransform()
    inst.entity:AddAnimState()

    inst.AnimState:SetBank("cannon_aim_range_fx")
    inst.AnimState:SetBuild("cannon_aim_range_fx")
    inst.AnimState:PlayAnimation("idle")
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetLayer(LAYER_WORLD_BACKGROUND)
    inst.AnimState:SetSortOrder(10)
    inst.AnimState:SetFinalOffset(1)

    return inst
end

return Prefab("cannon_aim_range_fx", fn, assets)
