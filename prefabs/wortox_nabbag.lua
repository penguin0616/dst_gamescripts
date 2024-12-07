local assets = {
    Asset("ANIM", "anim/wortox_nabbag.zip"),
    Asset("ANIM", "anim/swap_wortox_nabbag.zip"),
    Asset("INV_IMAGE", "wortox_nabbag_medium"),
    Asset("INV_IMAGE", "wortox_nabbag_full"),
}
local prefabs = {
    "wortox_nabbag_body",
}

local BUCKET_NAMES = {
    "_empty",
    "_medium",
    "_full",
}
local BUCKET_SIZE = #BUCKET_NAMES

local function UpdateStats(inst, percent, souls)
    -- Make the sizes into buckets.
    local bucket = math.clamp(math.ceil(percent * BUCKET_SIZE), 1, BUCKET_SIZE)
    inst.nabbag_size = BUCKET_NAMES[bucket]
    -- Scale percent to be percent of bucket.
    percent = (bucket - 1) / (BUCKET_SIZE - 1)

    local owner = inst.components.inventoryitem.owner
    if inst.components.weapon then
        local maxdamage = TUNING.SKILLS.WORTOX.NABBAG_DAMAGE_MAX
        local mindamage = TUNING.SKILLS.WORTOX.NABBAG_DAMAGE_MIN
        local damage = (maxdamage - mindamage) * percent + mindamage
        if owner and owner.components.skilltreeupdater and owner.components.skilltreeupdater:IsActivated("wortox_souljar_3") then
            local souls_max = TUNING.SKILLS.WORTOX.SOUL_DAMAGE_MAX_SOULS
            local damage_percent = math.min(souls, souls_max) / souls_max
            damage = damage * (1 + (TUNING.SKILLS.WORTOX.SOUL_DAMAGE_NABBAG_BONUS_MULT - 1) * damage_percent)
        end
        inst.components.weapon:SetDamage(damage)
        inst.components.weapon.attackwearmultipliers:SetModifier(inst, percent)
    end

    if inst.wortox_nabbag_body ~= nil then
        local currentframe = inst.wortox_nabbag_body.AnimState:GetCurrentAnimationFrame() - 1
        inst.wortox_nabbag_body.AnimState:PlayAnimation("idle_body" .. inst.nabbag_size, true)
        inst.wortox_nabbag_body.AnimState:SetFrame(currentframe)
        if inst.wortox_nabbag_body.hiding then
            if owner then
                owner.AnimState:OverrideSymbol("swap_object", "swap_wortox_nabbag", "swap_wortox_nabbag" .. inst.nabbag_size)
            end
        end
    end
    if inst.nabbag_size == "_empty" then
        inst.components.inventoryitem:ChangeImageName(nil) -- Default image name is the prefab name itself as a network optimization.
    else
        inst.components.inventoryitem:ChangeImageName("wortox_nabbag" .. inst.nabbag_size)
    end
end

local function OnInventoryStateChanged_Internal(inst, owner)
    if owner.components.inventory == nil then
        inst:UpdateStats(0, 0)
        return
    end

    local souls = 0
    local count = 0
    owner.components.inventory:ForEachItemSlot(function(item)
        count = count + 1
        if item.prefab == "wortox_soul" then
            souls = souls + (item.components.stackable and item.components.stackable:StackSize() or 1)
        elseif item.prefab == "wortox_souljar" then
            souls = souls + item.soulcount
        end
    end)
    local activeitem = owner.components.inventory:GetActiveItem()
    if activeitem then
        if activeitem.prefab == "wortox_soul" then
            souls = souls + (activeitem.components.stackable and activeitem.components.stackable:StackSize() or 1)
        elseif activeitem.prefab == "wortox_souljar" then
            souls = souls + activeitem.soulcount
        end
    end
    local maxslots = owner.components.inventory:GetNumSlots()
    local percent = maxslots == 0 and 0 or count / maxslots
    inst:UpdateStats(percent, souls)
end

local function ToggleOverrideSymbols(inst, owner)
    if owner.sg == nil or (owner.sg:HasStateTag("nodangle")
            or (owner.components.rider ~= nil and owner.components.rider:IsRiding()
                and not owner.sg:HasStateTag("forcedangle"))) then
        owner.AnimState:OverrideSymbol("swap_object", "swap_wortox_nabbag", "swap_wortox_nabbag" .. inst.nabbag_size)
        inst.wortox_nabbag_body.hiding = true
        inst.wortox_nabbag_body:Hide()
    else
        owner.AnimState:OverrideSymbol("swap_object", "swap_wortox_nabbag", "swap_wortox_nabbag_rope")
        inst.wortox_nabbag_body.hiding = nil
        inst.wortox_nabbag_body:Show()
    end
end
local function OnRemove_Body(wortox_nabbag_body)
    wortox_nabbag_body.wortox_nabbag.wortox_nabbag_body = nil
end
local function OnEquip(inst, owner)
    owner.AnimState:Show("ARM_carry")
    owner.AnimState:Hide("ARM_normal")

    if inst.wortox_nabbag_body ~= nil then
        inst.wortox_nabbag_body:Remove()
    end
    inst.wortox_nabbag_body = SpawnPrefab("wortox_nabbag_body")
    inst.wortox_nabbag_body.wortox_nabbag = inst
    inst:ListenForEvent("onremove", OnRemove_Body, inst.wortox_nabbag_body)

    inst.wortox_nabbag_body.AnimState:PlayAnimation("idle_body" .. inst.nabbag_size, true)
    inst.wortox_nabbag_body.AnimState:SetFrame(inst.AnimState:GetCurrentAnimationFrame() - 1)
    inst.wortox_nabbag_body.entity:SetParent(owner.entity)
    inst.wortox_nabbag_body.entity:AddFollower()
    inst.wortox_nabbag_body.Follower:FollowSymbol(owner.GUID, "swap_object", 54, -182, 0)
    inst.wortox_nabbag_body:ListenForEvent("newstate", function(owner, data)
        ToggleOverrideSymbols(inst, owner)
    end, owner)

    ToggleOverrideSymbols(inst, owner)

    inst:ListenForEvent("itemget", inst.OnInventoryStateChanged, owner)
    inst:ListenForEvent("itemlose", inst.OnInventoryStateChanged, owner)

    inst.OnInventoryStateChanged(owner)
end

local function OnUnequip(inst, owner)
    if inst.wortox_nabbag_body ~= nil then
        if inst.wortox_nabbag_body.entity:IsVisible() then
            -- For animating when the item is being put away.
            owner.AnimState:OverrideSymbol("swap_object", "swap_wortox_nabbag", "swap_wortox_nabbag" .. inst.nabbag_size)
        end
        inst.wortox_nabbag_body:Remove()
    end
    owner.AnimState:Hide("ARM_carry")
    owner.AnimState:Show("ARM_normal")

    inst:RemoveEventCallback("itemget", inst.OnInventoryStateChanged, owner)
    inst:RemoveEventCallback("itemlose", inst.OnInventoryStateChanged, owner)

    inst:UpdateStats(0, 0)
end

local function DoLoadCheckForPlayers(inst)
    if inst.components.inventoryitem and inst.components.inventoryitem.owner and inst.components.equippable and inst.components.equippable:IsEquipped() then
        inst.OnInventoryStateChanged(inst.components.inventoryitem.owner)
    end
end

local function OnUsesFinished(inst)
    if inst.components.inventoryitem.owner ~= nil then
        inst.components.inventoryitem.owner:PushEvent("toolbroke", { tool = inst })
    end

    inst:Remove()
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("wortox_nabbag")
    inst.AnimState:SetBuild("wortox_nabbag")
    inst.AnimState:PlayAnimation("idle_empty")

    --nabbag (from nabbag component) added to pristine state for optimization
    inst:AddTag("nabbag")
    --weapon (from weapon component) added to pristine state for optimization
    inst:AddTag("weapon")

    local swap_data = {sym_build = "swap_wortox_nabbag_empty"}
    MakeInventoryFloatable(inst, "med", 0.09, {0.9, 0.4, 0.9}, false, -14.5, swap_data)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("nabbag")

    local weapon = inst:AddComponent("weapon")
    weapon:SetDamage(TUNING.SKILLS.WORTOX.NABBAG_DAMAGE_MIN)
    weapon.attackwearmultipliers:SetModifier(inst, 0)

    local finiteuses = inst:AddComponent("finiteuses")
    finiteuses:SetMaxUses(TUNING.SKILLS.WORTOX.NABBAG_USES)
    finiteuses:SetUses(TUNING.SKILLS.WORTOX.NABBAG_USES)
    finiteuses:SetOnFinished(OnUsesFinished)

    inst:AddComponent("inspectable")

    inst:AddComponent("inventoryitem")

    local equippable = inst:AddComponent("equippable")
    equippable:SetOnEquip(OnEquip)
    equippable:SetOnUnequip(OnUnequip)
    equippable.restrictedtag = "nabbaguser"

    local fuel = inst:AddComponent("fuel")
    fuel.fuelvalue = TUNING.SMALL_FUEL

    MakeHauntableLaunch(inst)

    inst.nabbag_size = "_empty"
    inst.OnInventoryStateChanged = function(owner)
        OnInventoryStateChanged_Internal(inst, owner)
    end
    inst.UpdateStats = UpdateStats

    inst:DoTaskInTime(0, DoLoadCheckForPlayers) -- Delay for player load unload load cycle.

    return inst
end

local function bodyfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    inst.AnimState:SetBank("wortox_nabbag")
    inst.AnimState:SetBuild("wortox_nabbag")
    inst.AnimState:PlayAnimation("idle_body_empty", true)
    inst.AnimState:SetFinalOffset(1)

    inst:AddTag("FX")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false

    return inst
end

return Prefab("wortox_nabbag", fn, assets, prefabs),
    Prefab("wortox_nabbag_body", bodyfn, assets)