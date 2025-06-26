local assets =
{
    Asset("ANIM", "anim/flotationcushion.zip"),
    Asset("INV_IMAGE", "flotationcushion"),
}

local prefabs =
{
    "flotationcushion_pop",
}

local function onpreventdrowningdamagefn(inst)
    local pop = SpawnPrefab("flotationcushion_pop")
    pop.Transform:SetPosition(inst.Transform:GetWorldPosition())

    inst:Remove()
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("flotationcushion")
    inst.AnimState:SetBuild("flotationcushion")
    inst.AnimState:PlayAnimation("idle")

	MakeInventoryFloatable(inst, "small", 0.1, { 1.1, 1, 1.1 })

	inst:AddTag("cattoy")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    --
	local flotationdevice = inst:AddComponent("flotationdevice")
	flotationdevice.onpreventdrowningdamagefn = onpreventdrowningdamagefn

    --
    inst:AddComponent("inspectable")

    --
    inst:AddComponent("inventoryitem")

    return inst
end

return Prefab("flotationcushion", fn, assets, prefabs)
