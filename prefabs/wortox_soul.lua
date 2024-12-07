local wortox_soul_common = require("prefabs/wortox_soul_common")

local assets =
{
    Asset("ANIM", "anim/wortox_soul_ball.zip"),
    Asset("SCRIPT", "scripts/prefabs/wortox_soul_common.lua"),
}

local prefabs =
{
    "wortox_soul_heal_fx",
}

local SCALE = .8

local function topocket(inst)
    inst.persists = true
    if inst._task ~= nil then
        inst._task:Cancel()
        inst._task = nil
    end
end

local function KillSoul_FromPocket_Bursted(inst)
    inst.soul_heal_mult = (inst.soul_heal_mult or 0) + TUNING.SKILLS.WORTOX.WORTOX_SOULPROTECTOR_3_MULT
    inst.soul_bursting = true
    inst.AnimState:PlayAnimation("idle_small_pst")
    inst:ListenForEvent("animover", inst.Remove)
    inst.SoundEmitter:PlaySound("dontstarve/characters/wortox/soul/spawn", nil, .5)
    wortox_soul_common.DoHeal(inst)
end
local function KillSoul_FromPocket(inst)
    if inst.soul_doburst then
        inst.AnimState:PlayAnimation("burst")
        inst.AnimState:PushAnimation("idle_small_loop", true)
        local delay = TUNING.SKILLS.WORTOX.WORTOX_SOULPROTECTOR_3_DELAY
        if inst.soul_doburst_faster then
            delay = delay + TUNING.SKILLS.WORTOX.WORTOX_SOULPROTECTOR_4_DELAY
        end
        inst:DoTaskInTime(delay, KillSoul_FromPocket_Bursted)
    else
        inst.AnimState:PlayAnimation("idle_pst")
        inst:ListenForEvent("animover", inst.Remove)
    end
    inst.SoundEmitter:PlaySound("dontstarve/characters/wortox/soul/spawn", nil, .5)
    wortox_soul_common.DoHeal(inst)
end

local function toground(inst)
    inst.persists = false
    if inst._task == nil then
        inst._task = inst:DoTaskInTime(.4 + math.random() * .7, KillSoul_FromPocket) -- NOTES(JBK): This is 1.1 max keep it in sync with "[WST]"
    end
    if inst.AnimState:IsCurrentAnimation("idle_loop") then
		inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)
    end
end

local function MakeSmallVisual(inst)
    inst.persists = false
    if inst._task ~= nil then
        inst._task:Cancel()
        inst._task = nil
    end
    inst.SoundEmitter:PlaySound("dontstarve/characters/wortox/soul/spawn", nil, .5)
    inst.AnimState:PlayAnimation("idle_small_pst")
    inst:ListenForEvent("animover", inst.Remove)
end

local SOUL_TAGS = { "soul" }
local function OnDropped(inst)
    if inst.components.stackable ~= nil and inst.components.stackable:IsStack() then
        local x, y, z = inst.Transform:GetWorldPosition()
        local num = 10 - #TheSim:FindEntities(x, y, z, 4, SOUL_TAGS)
        if num > 0 then
            for i = 1, math.min(num, inst.components.stackable:StackSize()) do
                local soul = inst.components.stackable:Get()
                soul.Physics:Teleport(x, y, z)
                soul.components.inventoryitem:OnDropped(true)
            end
        end
    end
end

local function OnCharged(inst)
    inst:RemoveTag("nosouljar")
end

local function OnDischarged(inst)
    inst:AddTag("nosouljar")
end

local function ModifyStats(inst, owner)
    local skilltreeupdater = owner.components.skilltreeupdater
    if skilltreeupdater then
        if skilltreeupdater:IsActivated("wortox_soulprotector_1") then
            inst.soul_heal_range_modifier = (inst.soul_heal_range_modifier or 0) + TUNING.SKILLS.WORTOX.WORTOX_SOULPROTECTOR_1_RANGE
            if skilltreeupdater:IsActivated("wortox_soulprotector_2") then
                inst.soul_heal_range_modifier = inst.soul_heal_range_modifier + TUNING.SKILLS.WORTOX.WORTOX_SOULPROTECTOR_2_RANGE
            end
        end
        if skilltreeupdater:IsActivated("wortox_soulprotector_3") then
            inst.soul_doburst = true
        end
        if skilltreeupdater:IsActivated("wortox_soulprotector_4") then
            inst.soul_doburst_faster = true
            inst.soul_heal_player_efficient = true
        end
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)
    RemovePhysicsColliders(inst)

    inst.AnimState:SetBank("wortox_soul_ball")
    inst.AnimState:SetBuild("wortox_soul_ball")
    inst.AnimState:PlayAnimation("idle_loop", true)
    inst.AnimState:SetScale(SCALE, SCALE)

    inst:AddTag("nosteal")
    inst:AddTag("NOCLICK")

    --souleater (from soul component) added to pristine state for optimization
    inst:AddTag("soul")

    -- Tag rechargeable (from rechargeable component) added to pristine state for optimization.
    inst:AddTag("rechargeable")
    -- Optional tag to control if the item is not a "cooldown until" meter but a "bonus while" meter.
    inst:AddTag("rechargeable_bonus")
	--waterproofer (from waterproofer component) added to pristine state for optimization
	inst:AddTag("waterproofer")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.canbepickedup = false
    inst.components.inventoryitem.canonlygoinpocketorpocketcontainers = true
    inst.components.inventoryitem:SetOnDroppedFn(OnDropped)

    inst:AddComponent("stackable")
    inst.components.stackable.maxsize = TUNING.STACK_SIZE_SMALLITEM
    inst.components.stackable.forcedropsingle = true

    inst:AddComponent("rechargeable")
    inst.components.rechargeable:SetOnChargedFn(OnCharged)
    inst.components.rechargeable:SetOnDischargedFn(OnDischarged)

    inst:AddComponent("inspectable")
    inst:AddComponent("soul")

	inst:AddComponent("waterproofer")
	inst.components.waterproofer:SetEffectiveness(0)

    inst:ListenForEvent("onputininventory", topocket)
    inst:ListenForEvent("ondropped", toground)
    inst._task = nil
    toground(inst)

    inst.ModifyStats = ModifyStats
    inst.MakeSmallVisual = MakeSmallVisual

    return inst
end

if TheSim then -- updateprefabs guard
    SetDesiredMaxTakeCountFunction("wortox_soul", function(player, inventory, container_item, container)
        local max_count = TUNING.WORTOX_MAX_SOULS -- NOTES(JBK): Keep this logic the same in counts in wortox. [WSCCF]
        if player and player.components.skilltreeupdater and player.components.skilltreeupdater:IsActivated("wortox_souljar_2") and player.replica.inventory then
            local souljars = 0
            for slot = 1, player.replica.inventory:GetNumSlots() do
                local item = player.replica.inventory:GetItemInSlot(slot)
                if item and item.prefab == "wortox_souljar" then
                    souljars = souljars + 1
                end
            end
            local activeitem = player.replica.inventory:GetActiveItem()
            if activeitem and activeitem.prefab == "wortox_souljar" then
                souljars = souljars + 1
            end
            max_count = max_count + souljars * TUNING.SKILLS.WORTOX.FILLED_SOULJAR_SOULCAP_INCREASE_PER
        end
        local has, count = inventory:Has("wortox_soul", 0, false)
        return math.max(max_count - count, 0)
    end)
end

return Prefab("wortox_soul", fn, assets, prefabs)
