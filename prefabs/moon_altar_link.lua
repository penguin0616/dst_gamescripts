local assets =
{
    Asset("ANIM", "anim/moon_altar_link.zip"),
}

local CANT_DESTROY_PREFABS = { moon_altar = true, moon_altar_cosmic = true, moon_altar_astral = true }

local DESTROY_TAGS_ONEOF = { "structure", "tree", "boulder" }

local BLOCK_AREA_TAGS = { "antlion_sinkhole_blocker" }

local LAUNCH_ITEMS_TAGS = { "_inventoryitem" }
local LAUNCH_ITEMS_NOTAGS = { "INLIMBO" }

local AREA_CLEAR_RADIUS = 6
local AREA_VALIDATE_RADIUS = 4
local VALIDATE_AREA_FREQUENCY = 0.25

local ITEM_LAUNCH_SPEED_MULTIPLIER = 1.8
local ITEM_LAUNCH_SPEED_MULTIPLIER_VARIANCE = 2.5

local function ClearArea(inst)
    local x, y, z = inst.Transform:GetWorldPosition()

    local ents = TheSim:FindEntities(x, y, z, AREA_CLEAR_RADIUS, nil, nil, DESTROY_TAGS_ONEOF)
    for i, v in ipairs(ents) do
        if v:IsValid() and v.components.workable ~= nil and v.components.workable:CanBeWorked() and not CANT_DESTROY_PREFABS[v.prefab] then
            SpawnPrefab("collapse_small").Transform:SetPosition(v.Transform:GetWorldPosition())
            v.components.workable:Destroy(inst)
        end
    end
end

local function ValidateArea(inst)
    local x, y, z = inst.Transform:GetWorldPosition()

    if TheWorld.Map:IsPassableAtPoint(x, y, z, false, true)
        and FindEntity(inst, AREA_VALIDATE_RADIUS, nil, BLOCK_AREA_TAGS) == nil then
            
        if not inst._area_clear then
            inst.AnimState:PlayAnimation("low_to_high")
            inst.AnimState:PushAnimation("high_idle", true)

            inst.SoundEmitter:SetParameter("loop", "intensity", 1)
        end
        
        inst._area_clear = true
    else
        if inst._first_validation then
            inst.AnimState:PlayAnimation("low_idle", true)

            inst.SoundEmitter:SetParameter("loop", "intensity", 0)
        elseif inst._area_clear then
            inst.AnimState:PlayAnimation("high_to_low")
            inst.AnimState:PushAnimation("low_idle", true)

            inst.SoundEmitter:SetParameter("loop", "intensity", 0)
        end

        inst._area_clear = false
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

        inst.AnimState:PlayAnimation("low_pre")
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

    if inst.AnimState:IsCurrentAnimation("high_idle") then
        inst.AnimState:PushAnimation("high_to_low")
        inst.AnimState:PushAnimation("low_pst", false)
    elseif inst.AnimState:IsCurrentAnimation("high_to_low") then
        inst.AnimState:PushAnimation("low_pst", false)
    else
        inst.AnimState:PlayAnimation("low_pst", false)
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

local function OnLoadPostPass(inst)
    local moon_altar = inst.components.entitytracker:GetEntity("moon_altar")
    local moon_altar_cosmic = inst.components.entitytracker:GetEntity("moon_altar_cosmic")
    local moon_altar_astral = inst.components.entitytracker:GetEntity("moon_altar_astral")

    if moon_altar ~= nil and moon_altar_cosmic ~= nil and moon_altar_astral ~= nil then
        inst.components.moonaltarlink:EstablishLink({ moon_altar, moon_altar_cosmic, moon_altar_astral })
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
    
    inst.AnimState:SetBuild("moon_altar_link")
    inst.AnimState:SetBank("moon_altar_link")
    inst.AnimState:PlayAnimation("low_idle")

    inst.AnimState:SetLightOverride(1)
    -- inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")

    inst.entity:AddDynamicShadow()
    inst.DynamicShadow:SetSize(2.4, 1)
    
    -- inst:AddTag("FX")
    -- inst:AddTag("NOCLICK")
    -- inst:AddTag("DECOR")
    inst:AddTag("NOBLOCK")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst._area_clear = false
    inst._first_validation = true
    inst._has_been_in_entity_sleep = false

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

return Prefab("moon_altar_link", fn, assets)
