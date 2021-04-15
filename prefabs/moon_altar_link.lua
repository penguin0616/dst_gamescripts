local assets =
{
    Asset("ANIM", "anim/moon_geyser.zip"),
}

local contained_assets =
{
    Asset("ANIM", "anim/moon_geyser.zip"),
}

local prefabs =
{
    "moon_altar_link_contained",
    "moonpulse_spawner",
}

local CANT_DESTROY_PREFABS = { moon_altar = true, moon_altar_cosmic = true, moon_altar_astral = true }

local DESTROY_TAGS_ONEOF = { "structure", "tree", "boulder" }

local LAUNCH_ITEMS_TAGS = { "_inventoryitem" }
local LAUNCH_ITEMS_NOTAGS = { "INLIMBO" }

local VALIDATE_AREA_FREQUENCY = 0.25

local ITEM_LAUNCH_SPEED_MULTIPLIER = 1.8
local ITEM_LAUNCH_SPEED_MULTIPLIER_VARIANCE = 2.5

local function startmoonstorms(inst)
    TheWorld:PushEvent("ms_startthemoonstorms")

    inst._has_started_storm = true
    inst._start_moonstorm_task = nil

    if inst._area_clear then
        if not inst:HasTag("can_build_moon_device") then
            inst:AddTag("can_build_moon_device")
        end
    else
        if inst:HasTag("can_build_moon_device") then
            inst:RemoveTag("can_build_moon_device")
        end
    end
end

local function ClearArea(inst)
    local x, y, z = inst.Transform:GetWorldPosition()

    local ents = TheSim:FindEntities(x, y, z, TUNING.MOON_ALTAR_LINK_AREA_CLEAR_RADIUS, nil, nil, DESTROY_TAGS_ONEOF)
    for i, v in ipairs(ents) do
        if v:IsValid() and v.components.workable ~= nil and v.components.workable:CanBeWorked() and not CANT_DESTROY_PREFABS[v.prefab] then
            SpawnPrefab("collapse_small").Transform:SetPosition(v.Transform:GetWorldPosition())
            v.components.workable:Destroy(inst)
        end
    end
end

local function CheckPointValid(x, y, z)
    if TheWorld.Map:IsPassableAtPoint(x, y, z, false, true) and TheWorld.Map:IsAboveGroundAtPoint(x, y, z, false) then
        local ents = TheSim:FindEntities(x, y, z, TUNING.MOON_ALTAR_LINK_AREA_CLEAR_RADIUS, TUNING.MOON_ALTAR_LINK_BLOCK_TAGS)
        return ents == nil or #ents == 0
    end

    return false
end

local function ValidateArea(inst)
    local x, y, z = inst.Transform:GetWorldPosition()

    if CheckPointValid(x, y, z) then
        if not inst._area_clear then
            inst.AnimState:PlayAnimation("stage0_low_to_high")
            inst.AnimState:PushAnimation("stage0_high_idle", true)

            if not inst._has_started_storm and inst._start_moonstorm_task == nil then
                SpawnPrefab("moonpulse_spawner").Transform:SetPosition(x, y, z)

                -- Delay matches third (and biggest) pulse in moonpulse
                inst._start_moonstorm_task = inst:DoTaskInTime(5.04, startmoonstorms)
            end

            inst.SoundEmitter:SetParameter("loop", "intensity", 1)
        end
        
        inst._area_clear = true
    else
        if inst._first_validation then
            inst.AnimState:PlayAnimation("stage0_low_idle", true)

            inst.SoundEmitter:SetParameter("loop", "intensity", 0)
        elseif inst._area_clear then
            inst.AnimState:PlayAnimation("stage0_high_to_low")
            inst.AnimState:PushAnimation("stage0_low_idle", true)

            inst.SoundEmitter:SetParameter("loop", "intensity", 0)
        end

        inst._area_clear = false
    end

    if inst._area_clear and inst._has_started_storm then
        if not inst:HasTag("can_build_moon_device") then
            inst:AddTag("can_build_moon_device")
        end
    else
        if inst:HasTag("can_build_moon_device") then
            inst:RemoveTag("can_build_moon_device")
        end
    end

    inst._first_validation = false
end

local function StopValidateAreaTask(inst)
    if inst._validate_area_task ~= nil then
        inst._validate_area_task:Cancel()
        inst._validate_area_task = nil
    end
end

local function StartValidateAreaTask(inst, initial_delay)
    StopValidateAreaTask(inst)

    inst._validate_area_task = inst:DoPeriodicTask(VALIDATE_AREA_FREQUENCY, ValidateArea, initial_delay or 0)
end

local function OnLinkEstablished(inst, altars)
    if not POPULATING then
        for i, altar in ipairs(altars) do
            inst.components.entitytracker:TrackEntity(altar.prefab, altar)
        end

        inst.AnimState:PlayAnimation("stage0_low_pre")
        local animlength = inst.AnimState:GetCurrentAnimationLength()

        ClearArea(inst)
        StartValidateAreaTask(inst, animlength)

        inst.SoundEmitter:PlaySound("grotto/common/moon_alter/link/start")
        ShakeAllCameras(CAMERASHAKE.VERTICAL, 2.4, .02, .18, inst, 12)
    end
end

local function OnLinkBroken(inst, altars)
    inst.persists = false

    StopValidateAreaTask(inst)

    if inst.AnimState:IsCurrentAnimation("stage0_high_idle") then
        inst.AnimState:PushAnimation("stage0_high_to_low")
        inst.AnimState:PushAnimation("stage0_low_pst", false)
    elseif inst.AnimState:IsCurrentAnimation("stage0_high_to_low") then
        inst.AnimState:PushAnimation("stage0_low_pst", false)
    else
        inst.AnimState:PlayAnimation("stage0_low_pst", false)
    end

    inst.SoundEmitter:PlaySound("grotto/common/moon_alter/link/start")
    
    inst:ListenForEvent("animqueueover", inst.Remove)
end

local function OnEntitySleep(inst)
    StopValidateAreaTask(inst)

    inst._has_been_in_entity_sleep = true

    inst.SoundEmitter:KillSound("loop")
end

local function OnEntityWake(inst)
    if inst.persists and inst._has_been_in_entity_sleep then
        StartValidateAreaTask(inst)
    end

    inst.SoundEmitter:PlaySound("grotto/common/moon_alter/link/LP", "loop")
    inst.SoundEmitter:SetParameter("loop", "intensity", 0)
end

local function OnSave(inst, data)
    data.has_started_storm = inst._has_started_storm and true or nil
end

local function OnLoad(inst, data)
    if data ~= nil and data.has_started_storm then
        inst._has_started_storm = true
    end
end

local function OnLoadPostPass(inst)
    local moon_altar = inst.components.entitytracker:GetEntity("moon_altar")
    local moon_altar_cosmic = inst.components.entitytracker:GetEntity("moon_altar_cosmic")
    local moon_altar_astral = inst.components.entitytracker:GetEntity("moon_altar_astral")

    if moon_altar ~= nil and moon_altar_cosmic ~= nil and moon_altar_astral ~= nil then
        local x, _, z = inst.Transform:GetWorldPosition()

        local min_distance_valid = true
        local altars = { moon_altar, moon_altar_cosmic, moon_altar_astral }
        for i, v in ipairs(altars) do
            local tx, _, tz = v.Transform:GetWorldPosition()
            if VecUtil_LengthSq(tx - x, tz - z) < TUNING.MOON_ALTAR_LINK_ALTAR_MIN_RADIUS_SQ then
                min_distance_valid = false
            end
        end
    
        if min_distance_valid and CheckPointValid(x, 0, z) then
            inst.components.moonaltarlink:EstablishLink({ moon_altar, moon_altar_cosmic, moon_altar_astral })
        else
            inst:Remove()
        end
    else
        inst:Remove()
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()
    
    inst.AnimState:SetBuild("moon_geyser")
    inst.AnimState:SetBank("moon_altar_geyser")
    inst.AnimState:PlayAnimation("stage0_low_idle", true)

    inst.AnimState:SetLightOverride(1)
    -- inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")

    -- inst.entity:AddDynamicShadow()
    -- inst.DynamicShadow:SetSize(2.4, 1)
    
    -- inst:AddTag("FX")
    -- inst:AddTag("NOCLICK")
    -- inst:AddTag("DECOR")
    inst:AddTag("NOBLOCK")

    inst:AddTag("moon_altar_link")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst._area_clear = false
    inst._first_validation = true
    inst._has_been_in_entity_sleep = false
    inst._has_started_storm = false
    -- inst._start_moonstorm_task = nil

    inst:AddComponent("inspectable")

    inst:AddComponent("entitytracker")

    inst:AddComponent("moonaltarlink")
    inst.components.moonaltarlink.onlinkfn = OnLinkEstablished
    inst.components.moonaltarlink.onlinkbrokenfn = OnLinkBroken

    inst.OnEntitySleep = OnEntitySleep
    inst.OnEntityWake = OnEntityWake
    
    inst.OnLoadPostPass = OnLoadPostPass

    return inst
end

local function contained_set_stage(inst, stage)
    inst._stage = stage

    inst.AnimState:PlayAnimation("stage"..stage.."_idle_pre", false)
    inst.AnimState:PushAnimation("stage"..stage.."_idle", true)
end

local function contained_fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()
    
    inst.AnimState:SetBuild("moon_geyser")
    inst.AnimState:SetBank("moon_altar_geyser")
    inst.AnimState:PlayAnimation("stage1_idle", true)

    inst.AnimState:SetLightOverride(1)
    -- inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
    
    inst:AddTag("FX")
    inst:AddTag("NOCLICK")
    inst:AddTag("NOBLOCK")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false

    inst._stage = 1
    inst._set_stage_fn = contained_set_stage

    return inst
end

return Prefab("moon_altar_link", fn, assets, prefabs),
    Prefab("moon_altar_link_contained", contained_fn, contained_assets)
