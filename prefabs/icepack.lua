local assets =
{
    Asset("ANIM", "anim/swap_icepack.zip"),
    Asset("ANIM", "anim/ui_backpack_2x4.zip"),
}

local prefabs =
{

}

local function onequip(inst, owner)
    owner.AnimState:OverrideSymbol("swap_body", "swap_icepack", "backpack")
    owner.AnimState:OverrideSymbol("swap_body", "swap_icepack", "swap_body")
    inst.components.container:Open(owner)
end

local function onunequip(inst, owner)
    owner.AnimState:ClearOverrideSymbol("swap_body")
    owner.AnimState:ClearOverrideSymbol("backpack")
    inst.components.container:Close(owner)
end

local function onequiptomodel(inst, owner)
    inst.components.container:Close(owner)
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

    inst.MiniMapEntity:SetIcon("icepack.png")

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("icepack")
    inst.AnimState:SetBuild("swap_icepack")
    inst.AnimState:PlayAnimation("anim")

    inst:AddTag("backpack")
    inst:AddTag("fridge")
    inst:AddTag("nocool")

    inst.foleysound = "dontstarve/movement/foley/backpack"

    MakeInventoryFloatable(inst, "small", 0.15)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.cangoincontainer = false

    inst:AddComponent("equippable")
    inst.components.equippable.equipslot = EQUIPSLOTS.BODY
    inst.components.equippable:SetOnEquip(onequip)
    inst.components.equippable:SetOnUnequip(onunequip)
    inst.components.equippable:SetOnEquipToModel(onequiptomodel)

    inst:AddComponent("container")
    inst.components.container:WidgetSetup("icepack")

    MakeHauntableLaunchAndDropFirstItem(inst)

    return inst
end

return Prefab("icepack", fn, assets, prefabs)
