local assets =
{
    Asset("ANIM", "anim/armor_bramble.zip"),
}

local prefabs =
{
    "bramblefx_armor",
}

local function OnCooldown(inst)
    inst._cdtask = nil
end

local function DoThorns(inst, owner)
    --V2C: tiny CD to limit chain reactions
    inst._cdtask = inst:DoTaskInTime(.3, OnCooldown)

    inst._hitcount = 0

    if owner.components.skilltreeupdater:IsActivated("wormwood_allegiance_lunar_plant_gear_1") then
        SpawnPrefab("bramblefx_armor_upgrade"):SetFXOwner(owner)
    else
        SpawnPrefab("bramblefx_armor"):SetFXOwner(owner)
    end

    if owner.SoundEmitter ~= nil then
        owner.SoundEmitter:PlaySound("dontstarve/common/together/armor/cactus")
    end
end

local function OnBlocked(owner, data, inst)
    if inst._cdtask == nil and data ~= nil and not data.redirected then
        DoThorns(inst, owner)
    end
end

local function OnAttackOther(owner, data, inst)
    if inst._cdtask == nil and checknumber(inst._hitcount) then
        inst._hitcount = inst._hitcount + 1

        if inst._hitcount >= TUNING.WORMWOOD_ARMOR_BRAMBLE_RELEASE_SPIKES_HITCOUNT then
            DoThorns(inst, owner)
        end
    end
end

local function onequip(inst, owner)
    if owner.components.skilltreeupdater:IsActivated("wormwood_allegiance_lunar_plant_gear_1") then
        inst:bramble_upgrade(owner)
    end

    local skin_build = inst:GetSkinBuild()
    if skin_build ~= nil then
        owner:PushEvent("equipskinneditem", inst:GetSkinName())
        owner.AnimState:OverrideItemSkinSymbol("swap_body", skin_build, "swap_body", inst.GUID, "armor_bramble")
    else
		owner.AnimState:OverrideSymbol("swap_body", "armor_bramble", "swap_body")
    end

    inst:ListenForEvent("blocked", inst._onblocked, owner)
    inst:ListenForEvent("attacked", inst._onblocked, owner)

    inst._hitcount = 0

    if owner.components.skilltreeupdater ~= nil and owner.components.skilltreeupdater:IsActivated("wormwood_armor_bramble") then
        inst:ListenForEvent("onattackother", inst._onattackother, owner)
    end    
end

local function onunequip(inst, owner)
    inst:bramble_downgrade(owner)

    owner.AnimState:ClearOverrideSymbol("swap_body")

    inst:RemoveEventCallback("blocked", inst._onblocked, owner)
    inst:RemoveEventCallback("attacked", inst._onblocked, owner)
    inst:RemoveEventCallback("onattackother", inst._onattackother, owner)

    inst._hitcount = nil

    local skin_build = inst:GetSkinBuild()
    if skin_build ~= nil then
        owner:PushEvent("unequipskinneditem", inst:GetSkinName())
    end
end

local function bramble_downgrade(inst,owner)
    if owner then
        owner.AnimState:ClearSymbolBloom("swap_body")
    end
    inst.components.planardefense:SetBaseDefense(0)
end
local function bramble_upgrade(inst,owner)
    inst.components.planardefense:SetBaseDefense(TUNING.ARMORBRAMBLE_PLANAR_UPGRADE)
    owner.AnimState:SetSymbolBloom("swap_body")
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst:AddTag("bramble_resistant")

    inst.AnimState:SetBank("armor_bramble")
    inst.AnimState:SetBuild("armor_bramble")
    inst.AnimState:PlayAnimation("anim")

    inst.scrapbook_specialinfo = "ARMORBRAMBLE"
    inst.scrapbook_damage = TUNING.ARMORBRAMBLE_DMG

    inst.foleysound = "dontstarve/movement/foley/cactus_armor"

    MakeInventoryFloatable(inst)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst._hitcount = nil

    inst:AddComponent("inspectable")
    inst:AddComponent("inventoryitem")

    inst:AddComponent("fuel")
    inst.components.fuel.fuelvalue = TUNING.LARGE_FUEL

    MakeSmallBurnable(inst, TUNING.SMALL_BURNTIME)
    MakeSmallPropagator(inst)

    inst:AddComponent("armor")
    inst.components.armor:InitCondition(TUNING.ARMORBRAMBLE, TUNING.ARMORBRAMBLE_ABSORPTION)
    inst.components.armor:AddWeakness("beaver", TUNING.BEAVER_WOOD_DAMAGE)

    inst:AddComponent("planardefense")
    inst.components.planardefense:SetBaseDefense(0)

    inst:AddComponent("equippable")
    inst.components.equippable.equipslot = EQUIPSLOTS.BODY

    inst.components.equippable:SetOnEquip(onequip)
    inst.components.equippable:SetOnUnequip(onunequip)

    MakeHauntableLaunch(inst)

    inst._onblocked      = function(owner, data)     OnBlocked(owner, data, inst) end
    inst._onattackother  = function(owner, data) OnAttackOther(owner, data, inst) end
    inst.bramble_upgrade = bramble_upgrade
    inst.bramble_downgrade = bramble_downgrade

    inst:ListenForEvent( "onremove", function()
            local owner = inst.components.inventoryitem.owner
            if owner then
                inst:bramble_downgrade(owner)
            end
        end, inst )

    return inst
end

return Prefab("armor_bramble", fn, assets, prefabs)
