local assets =
{
    Asset("ANIM", "anim/armor_flowerdress.zip"),
}

-- Equippable
local function on_blocked(owner)
    owner.SoundEmitter:PlaySound("aqol/new_test/vegetation_grassy")
end

local function onequip(inst, owner)
    local skin_build = inst:GetSkinBuild()
    if skin_build ~= nil then
        owner:PushEvent("equipskinneditem", inst:GetSkinName())
        owner.AnimState:OverrideItemSkinSymbol("swap_body", skin_build, "swap_body", inst.GUID, "armor_flowerdress")
    else
		owner.AnimState:OverrideSymbol("swap_body", "armor_flowerdress", "swap_body")
    end
    owner:AddTag("ghostlybond_redirect")
    inst:ListenForEvent("blocked", on_blocked, owner)
end

local function onunequip(inst, owner)
    owner.AnimState:ClearOverrideSymbol("swap_body")
    inst:RemoveEventCallback("blocked", on_blocked, owner)
    owner:RemoveTag("ghostlybond_redirect")
    local skin_build = inst:GetSkinBuild()
    if skin_build ~= nil then
        owner:PushEvent("unequipskinneditem", inst:GetSkinName())
    end
end

--
local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("armor_flowerdress")
    inst.AnimState:SetBuild("armor_flowerdress")
    inst.AnimState:PlayAnimation("anim")    

    inst:AddTag("show_spoilage")

    inst.foleysound = "dontstarve/movement/foley/grassarmour"

    local swap_data = {bank = "armor_flowerdress", anim = "anim"}
    MakeInventoryFloatable(inst, "small", 0.2, 0.80, nil, nil, swap_data)

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    --
    local equippable = inst:AddComponent("equippable")
    equippable.equipslot = EQUIPSLOTS.BODY
    equippable.walkspeedmult = 0.85
    equippable:SetOnEquip(onequip)
    equippable:SetOnUnequip(onunequip)

    --
    inst:AddComponent("perishable")
    inst.components.perishable:SetPerishTime(TUNING.PERISH_MED)
    inst.components.perishable:StartPerishing()
    inst.components.perishable:SetOnPerishFn(inst.Remove)
    --

    inst:AddComponent("forcecompostable")
    inst.components.forcecompostable.green = true

    --
    inst:AddComponent("inspectable")

    --
    inst:AddComponent("inventoryitem")

    --
    MakeHauntableLaunch(inst)

    --
    return inst
end

return Prefab("armor_flowerdress", fn, assets)