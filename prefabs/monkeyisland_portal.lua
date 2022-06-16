local assets =
{
    Asset("ANIM", "anim/monkey_island_portal.zip"),
    Asset("MINIMAP_IMAGE", "monkey_island_portal"),
}

local fx_assets =
{
    Asset("ANIM", "anim/monkey_island_portal_fx.zip"),
}

local prefabs =
{
    "cutgrass",
    "dug_bananabush",
    "dug_monkeytail",
	"lightcrab",
    "monkeyisland_portal_debris",
    "monkeyisland_portal_fxloot",
    "monkeyisland_portal_lootfollowfx",
    "palmcone_seed",
    "powder_monkey",
    "rocks",
    "twigs",
}

local PORTALLOOT_TIMER_NAME = "spawnportalloot_tick"

-- We weight in some FX loot here as well, for some presentation and
-- to break up the spawn of objects with behaviour.
local PORTAL_LOOT_PREFABS =
{
    cutgrass                            = 5.0,
    dug_bananabush                      = "MONKEYISLAND_PORTAL_BANANABUSHWEIGHT",
    dug_monkeytail                      = "MONKEYISLAND_PORTAL_MONKEYTAILWEIGHT",
	lightcrab                           = "MONKEYISLAND_PORTAL_LIGHTCRABWEIGHT",
    monkeyisland_portal_fxloot          = 20.0,
    palmcone_seed                       = "MONKEYISLAND_PORTAL_PALMCONE_SEEDWEIGHT",
    powder_monkey                       = "MONKEYISLAND_PORTAL_POWDERMONKEYWEIGHT",
    rocks                               = 5.0,
    twigs                               = 5.0,
}

local PORTAL_LOOT_FXYOFFSET =
{
    cutgrass        = 0.25,
    dug_bananabush  = 0.40,
    dug_monkeytail  = 0.40,
    lightcrab       = 0.25,
    palmcone_seed   = 0.25,
    powder_monkey   = 1.80,
    rocks           = 0.25,
    twigs           = 0.25,
}

local LOOT_LIGHT_OVERRIDE_AMOUNT = 0.6

--------------------------------------------------------------------------------
-- Follow FX --
--------------------------------------------------------------------------------
local function follow_fx_finish(fx)
    fx.AnimState:PlayAnimation("idle_pst")
    fx:ListenForEvent("animover", fx.Remove)
end

local function followfx_fn()
    local inst = CreateEntity("MonkeyIslandPortalLoot.SpawnFollowFX")

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    inst:AddTag("FX")
    inst:AddTag("NOBLOCK")
    inst:AddTag("NOCLICK")

    inst.AnimState:SetBank("monkey_island_portal_fx")
    inst.AnimState:SetBuild("monkey_island_portal_fx")
    inst.AnimState:PlayAnimation("idle_loop", true)

    inst.AnimState:SetFinalOffset(1)
    inst.AnimState:SetScale(0.65, 0.65)
    inst.AnimState:SetMultColour(0.4, 0.4, 0.4, 0.4)
    inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
    inst.AnimState:SetLightOverride(LOOT_LIGHT_OVERRIDE_AMOUNT)

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false

    inst.fx_len = inst.AnimState:GetCurrentAnimationLength()
    inst:DoTaskInTime(inst.fx_len, follow_fx_finish)

    return inst
end
--------------------------------------------------------------------------------

local function cleanup_outofscope_loot(inst)
    -- If loot has gone invalid or too far away, remove it.
    for i = #inst._loot, 1, -1 do
        local loot = inst._loot[i]
        if loot == nil or not loot:IsValid()
                or not inst:IsNear(loot, TUNING.MONKEYISLAND_PORTAL_LOOTMAXDST) then
            table.remove(inst._loot, i)
        end
    end
end

local VERTICAL_FLING_OFFSET = Vector3(0, 4, 0)
local function spawn_real_loot(inst)
    local portal_pos = inst:GetPosition()
    local fling_pos = portal_pos + VERTICAL_FLING_OFFSET

    -- Rebuild the table here each time in case the tuning variables change.
    local loot_to_test = {}
    for loot_prefab_to_test, chance in pairs(PORTAL_LOOT_PREFABS) do
        if type(chance) == "string" then
            chance = TUNING[chance]
        end
        loot_to_test[loot_prefab_to_test] = chance
    end
    local loot_prefab = weighted_random_choice(loot_to_test)

    local loot_to_drop = SpawnPrefab(loot_prefab)
    if loot_to_drop == nil then
        return nil
    end

    table.insert(inst._loot, loot_to_drop)

    if loot_to_drop.components.embarker == nil then
        inst.components.lootdropper:FlingItem(loot_to_drop, fling_pos)
		if loot_to_drop.sg ~= nil then
			loot_to_drop.sg:GoToState("portal_spawn")
		end
    else
        loot_to_drop.Transform:SetPosition(fling_pos:Get())

        local hopout_offset = FindWalkableOffset(portal_pos, 2*PI*math.random(), 3, nil, true, false)
        if hopout_offset then
            portal_pos = portal_pos + hopout_offset
        end

        loot_to_drop.components.locomotor:StartHopping(portal_pos.x, portal_pos.z)
    end

    return loot_to_drop
end

local function spawn_fx_loot(inst)
    local loot_fx = SpawnPrefab("monkeyisland_portal_fxloot")

    inst.components.lootdropper:FlingItem(loot_fx, inst:GetPosition() + VERTICAL_FLING_OFFSET)

    return loot_fx
end

local function reset_attach_target_after_light(inst)
    inst.AnimState:SetLightOverride(0)
    inst:RemoveTag("outofreach")
end

local function attach_light_fx(attach_target)
    local spawn_fx = SpawnPrefab("monkeyisland_portal_lootfollowfx")
    spawn_fx.Transform:SetPosition(0, PORTAL_LOOT_FXYOFFSET[attach_target.prefab] or 0, 0)
    attach_target:AddChild(spawn_fx)
    if spawn_fx.fx_len then
        attach_target:AddTag("outofreach")
        attach_target.AnimState:SetLightOverride(LOOT_LIGHT_OVERRIDE_AMOUNT)
        attach_target:DoTaskInTime(spawn_fx.fx_len, reset_attach_target_after_light)
    end
end

local function try_portal_spawn(inst)
    cleanup_outofscope_loot(inst)

    local loot_to_drop = (#inst._loot < TUNING.MONKEYISLAND_PORTAL_MAXLOOT and spawn_real_loot(inst))
        or spawn_fx_loot(inst)

    if loot_to_drop ~= nil then
        inst.SoundEmitter:PlaySound("dontstarve/common/deathpoof")
        attach_light_fx(loot_to_drop)
    end
end

--------------------------------------------------------------------------------

local function on_portal_save(inst, data)
    if inst._loot ~= nil and #inst._loot > 0 then
        data.loot = {}
        for _, loot_item in ipairs(inst._loot) do
            table.insert(data.loot, loot_item.GUID)
        end
    end

    return data.loot
end

local function on_portal_loadpostpass(inst, ents, data)
    if data ~= nil and data.loot ~= nil then
        for _, loot_guid in ipairs(data.loot) do
            if ents[loot_guid] ~= nil and ents[loot_guid].entity ~= nil then
                table.insert(inst._loot, ents[loot_guid].entity)
            end
        end
    end
end

--------------------------------------------------------------------------------

local function on_portal_sleep(inst)
    if TUNING.MONKEYISLAND_PORTAL_ENABLED then
        inst.components.timer:PauseTimer(PORTALLOOT_TIMER_NAME)
    end
end

local function on_portal_wake(inst)
    if TUNING.MONKEYISLAND_PORTAL_ENABLED then
        inst.components.timer:ResumeTimer(PORTALLOOT_TIMER_NAME)
    end
end

local function on_timer_done(inst, data)
    if data.name == PORTALLOOT_TIMER_NAME then
        if TUNING.MONKEYISLAND_PORTAL_ENABLED then
            try_portal_spawn(inst)

            -- The portal loot timer is repeating!
            inst.components.timer:StartTimer(PORTALLOOT_TIMER_NAME, TUNING.MONKEYISLAND_PORTAL_SPEWTIME)
        end
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

    inst.MiniMapEntity:SetIcon("monkey_island_portal.png")
    inst.MiniMapEntity:SetPriority(1)

    inst.AnimState:SetBank ("monkey_island_portal")
    inst.AnimState:SetBuild("monkey_island_portal")
    inst.AnimState:PlayAnimation("out_idle", true)

    inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
    inst.AnimState:SetLightOverride(1)

    inst.Light:SetIntensity(.7)
    inst.Light:SetRadius(5)
    inst.Light:SetFalloff(.8)
    inst.Light:SetColour(98/255, 18/255, 227/255)
    inst.Light:Enable(true)

    inst:AddTag("ignorewalkableplatforms")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst._loot = {}

    ----------------------------------------------------------
    inst:AddComponent("inspectable")

    ----------------------------------------------------------
    inst:AddComponent("lootdropper")
    inst.components.lootdropper.min_speed = 4
    inst.components.lootdropper.max_speed = 6
    inst.components.lootdropper.y_speed_variance = 2

    ----------------------------------------------------------
    inst:AddComponent("timer")

    ----------------------------------------------------------
    inst:ListenForEvent("timerdone", on_timer_done)

    ----------------------------------------------------------
    if TUNING.MONKEYISLAND_PORTAL_ENABLED then
        inst.components.timer:StartTimer(PORTALLOOT_TIMER_NAME, TUNING.MONKEYISLAND_PORTAL_SPEWTIME)
    end

    ----------------------------------------------------------
    inst.OnSave = on_portal_save
    inst.OnLoadPostPass = on_portal_loadpostpass
    inst.OnEntitySleep = on_portal_sleep
    inst.OnEntityWake = on_portal_wake

	inst.Test = try_portal_spawn

    return inst
end


return Prefab("monkeyisland_portal", fn, assets, prefabs),
    Prefab("monkeyisland_portal_lootfollowfx", followfx_fn, fx_assets)