require "prefabutil"

-- In the anim file, '1' is the highest tier, '3' the lowest (0 means it's destroyed...)
local ANIM_THRESHOLDS =
{
    0.67,
    0.33,
    0,
}

local function getanimthreshold(inst, percent)
    for i, v in ipairs(ANIM_THRESHOLDS) do
        if percent >= v then
            return i
        end
    end
    return #ANIM_THRESHOLDS
end

local function onhealthchange(inst, old_percent, new_percent)
    if inst.sg:HasStateTag("dead") then
        return
    end

    -- Play transition animation from one damaged state to another
    local oldindex = getanimthreshold(inst, old_percent)
    local newindex = getanimthreshold(inst, new_percent)
    if new_percent <= 0 then
        inst.sg:GoToState("death")
    elseif oldindex ~= newindex then
        if newindex > oldindex then
            inst.sg:GoToState("changegrade", {index = oldindex, newindex = newindex})
        else
            inst.sg:GoToState("changegrade", {index = newindex, newindex = newindex, isupgrade = true})
        end
    end
end

local function keeptargetfn()
    return false
end

local function onsave(inst, data)
    if inst:HasTag("burnt") or (inst.components.burnable ~= nil and inst.components.burnable:IsBurning()) then
        data.burnt = true
    end
end

local function onload(inst, data)

    if data.burnt and inst.components.burnable ~= nil and inst.components.burnable.onburnt ~= nil then
        inst.components.burnable.onburnt(inst)
    end

    if inst.components.health then
        local healthpercent = inst.components.health:GetPercent()
        local stateindex = getanimthreshold(inst, healthpercent)
        inst.sg:GoToState("idle", { index = stateindex })
    end
end

local function onremove(inst)
end

local PLAYER_TAGS = { "player" }
local function ValidRepairFn(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    if TheWorld.Map:IsAboveGroundAtPoint(x, y, z) then
        return true
    end

    if TheWorld.Map:IsVisualGroundAtPoint(x,y,z) then
        for i, v in ipairs(TheSim:FindEntities(x, 0, z, 1, PLAYER_TAGS)) do
            if v ~= inst and
            v.entity:IsVisible() and
            v.components.placer == nil and
            v.entity:GetParent() == nil then
                local px, _, pz = v.Transform:GetWorldPosition()
                if math.floor(x) == math.floor(px) and math.floor(z) == math.floor(pz) then
                    return false
                end
            end
        end
    end
    return true
end

local function IsPointOnBoatEdge(pt, inst)
    local boat = TheWorld.Map:GetPlatformAtPoint(pt.x,pt.z)

    -- If we're not standing on a boat, try to get the closest boat position via FindEntities()
    if boat == nil then
        local BOAT_MUST_TAGS = { "boat" }
        local boats = TheSim:FindEntities(pt.x, 0, pt.z, TUNING.BOAT.RADIUS, BOAT_MUST_TAGS)
        if #boats <= 0 then
            return false
        end
        boat = GetClosest(inst, boats)
    end

    -- Check the outside rim to see if no objects are there
    local boatpos = boat:GetPosition()
    local radius = boat.components.boatringdata and boat.components.boatringdata:GetRadius() + 0.25 or 0 --  Need to look a little outside of the boat edge here
    local boatsegments = boat.components.boatringdata and boat.components.boatringdata:GetNumSegments()
    local boatangle = boat.Transform:GetRotation()

    local snap_point = GetCircleEdgeSnapTransform(boatsegments, radius, boatpos, pt, boatangle)
    return boat ~= nil and boat:HasTag("boat")
        and TheWorld.Map:IsDeployPointClear(snap_point, inst, inst.replica.inventoryitem ~= nil and inst.replica.inventoryitem:DeploySpacingRadius() or DEPLOYSPACING_RADIUS[DEPLOYSPACING.DEFAULT])
end

local function CanDeployAtBoatEdge(inst, pt, mouseover, deployer, rot)
    return ((mouseover ~= nil and mouseover:HasTag("boat")) or IsPointOnBoatEdge(pt, inst))
end

local function SnapToBoatEdge(inst, override_pt)
    local pt = override_pt or inst:GetPosition()
    local boat = TheWorld.Map:GetPlatformAtPoint(pt.x,pt.z)

    if boat == nil then
        return
    end

    local boatpos = boat:GetPosition()
    local radius = boat.components.boatringdata and boat.components.boatringdata:GetRadius() - 0.1 or 0
    local boatsegments = boat.components.boatringdata and boat.components.boatringdata:GetNumSegments() or 0
    local boatangle = boat.Transform:GetRotation()

    local snap_point, snap_angle = GetCircleEdgeSnapTransform(boatsegments, radius, boatpos, pt, boatangle)
    if snap_point ~= nil then
        inst.Transform:SetPosition(snap_point.x, 0, snap_point.z)
        inst.Transform:SetRotation(-snap_angle + 90) -- Need to offset snap_angle here to make the object show in the correct orientation
    else
        -- point is outside of radius; set original position
        inst.Transform:SetPosition(pt:Get())
    end
end

function MakeBumperType(data)

    local assets =
    {
        Asset("ANIM", "anim/boat_bumper.zip"), -- Anim file (and build for kelp bumper)
    }

    -- Default is kelp, so no need to load a build anim for it
    local buildname = data.name ~= nil and data.name ~= "kelp" and "boat_bumper_" .. data.name or "boat_bumper"
    if buildname ~= "boat_bumper" then
        table.insert(assets, Asset("ANIM", "anim/" .. buildname .. ".zip"))
    end

    local prefabs =
    {
        "collapse_small",
    }

    local function onbuilt(inst, data) -- builder, pos, rot, deployable
        if data == nil then
            return
        end

        inst.sg:GoToState("place")
        local boat = TheWorld.Map:GetPlatformAtPoint(data.pos.x, data.pos.z)

        -- If clicked point isn't on a boat, try to get the closest boat via FindEntities()
        if boat == nil then
            local BOAT_MUST_TAGS = { "boat" }
            local boats = TheSim:FindEntities(data.pos.x, 0, data.pos.z, TUNING.BOAT.RADIUS, BOAT_MUST_TAGS)
            if boats ~= nil then
                boat = GetClosest(inst, boats)
            end
        end

        if boat ~= nil then

            SnapToBoatEdge(inst, data.pos)
            inst.boat = boat

            boat.components.boatring:AddBumper(inst)
        end

        if data.buildsound ~= nil then
            inst.SoundEmitter:PlaySound(data.buildsound)
        end
    end

    local function onhammered(inst, worker)
        if data.maxloots ~= nil and data.loot ~= nil then
            local num_loots = math.max(1, math.floor(data.maxloots * inst.components.health:GetPercent()))
            for i = 1, num_loots do
                inst.components.lootdropper:SpawnLootPrefab(data.loot)
            end
        end

        local fx = SpawnPrefab("collapse_small")
        fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
        if data.material ~= nil then
            fx:SetMaterial(data.material)
        end

        inst:Remove()
    end

    local function onhit(inst)
        if data.material ~= nil then
            --inst.SoundEmitter:PlaySound("dontstarve/common/destroy_"..data.material)
        end

        local healthpercent = inst.components.health:GetPercent()
        if healthpercent > 0 then
            local animindex = getanimthreshold(inst, healthpercent)
            inst.sg:GoToState("hit", {index = animindex})
        end
    end

    local function ondeath(inst)
        -- Remove bumper from list of boat bumpers
        if inst.boat ~= nil then
            inst.boat.components.boatring:RemoveBumper(inst)
        end
    end

    local function onrepaired(inst)
        if data.buildsound ~= nil then
            inst.SoundEmitter:PlaySound(data.buildsound)
        end
    end

    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddSoundEmitter()
        inst.entity:AddNetwork()

        inst.Transform:SetNoFaced()

        inst:AddTag("boatbumper")
        inst:AddTag("mustforceattack")
        inst:AddTag("noauradamage")

        inst.AnimState:SetBank("boat_bumper")
        inst.AnimState:SetBuild(buildname)
        inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
        inst.AnimState:SetLayer(LAYER_WORLD_BACKGROUND)
        inst.AnimState:SetSortOrder(ANIM_SORT_ORDER.OCEAN_BOAT_BUMPERS)

        for i, v in ipairs(data.tags) do
            inst:AddTag(v)
        end

        MakeSnowCoveredPristine(inst)

        inst.OnRemoveEntity = onremove

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("inspectable")
        inst:AddComponent("lootdropper")
        inst:AddComponent("savedrotation")

        inst:AddComponent("repairable")
        inst.components.repairable.repairmaterial = data.material
        inst.components.repairable.onrepaired = onrepaired
        inst.components.repairable.testvalidrepairfn = ValidRepairFn

        inst:AddComponent("combat")
        inst.components.combat:SetKeepTargetFunction(keeptargetfn)
        inst.components.combat.onhitfn = onhit

        inst:ListenForEvent("onbuilt", onbuilt)
        inst:ListenForEvent("boatcollision", onhit)
        inst:ListenForEvent("death", ondeath)

        inst:AddComponent("health")
        inst.components.health:SetMaxHealth(data.maxhealth)
        inst.components.health.ondelta = onhealthchange
        inst.components.health.nofadeout = true
        inst.components.health.canheal = false

        if data.flammable then
            MakeMediumBurnable(inst)
            MakeLargePropagator(inst)
            inst.components.burnable.flammability = .5
            inst.components.burnable.nocharring = true

            --lame!
            if data.name == "kelp" then
                inst.components.propagator.flashpoint = 30 + math.random() * 10
            end
        else
            inst.components.health.fire_damage_scale = 0
        end

        inst:AddComponent("workable")
        inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
        inst.components.workable:SetWorkLeft(data.name == MATERIALS.MOONROCK and TUNING.MOONROCKWALL_WORK or 3)
        inst.components.workable:SetOnFinishCallback(onhammered)
        inst.components.workable:SetOnWorkCallback(onhit)

        MakeHauntableWork(inst)

        inst:SetStateGraph("SGboatbumper")
        inst.sg.mem.bumpertype = data.name -- For determining which FX name to play, which is dependant on the bumper type

        inst.OnSave = onsave
        inst.OnLoad = onload

        MakeSnowCovered(inst)

        return inst
    end

    local function setup_boat_placer(inst)
        inst.components.placer.snap_to_boat_edge = true
        inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
        inst.AnimState:SetLayer(LAYER_WORLD_BACKGROUND)
        inst.AnimState:SetSortOrder(ANIM_SORT_ORDER.OCEAN_BOAT_BUMPERS)
    end

    return Prefab("boat_bumper_"..data.name, fn, assets, prefabs),
        MakeDeployableKitItem("boat_bumper_"..data.name.."_kit", "boat_bumper_"..data.name, "boat_bumper", buildname, "idle", assets, nil, {"boat_accessory"}, {fuelvalue = TUNING.LARGE_FUEL}, { deploymode = DEPLOYMODE.CUSTOM, deployspacing = DEPLOYSPACING.MEDIUM, custom_candeploy_fn = CanDeployAtBoatEdge }, TUNING.STACK_SIZE_MEDITEM),
        MakePlacer("boat_bumper_"..data.name.."_kit_placer", "boat_bumper", buildname, "idle_1", false, false, false, nil, nil, "eight", setup_boat_placer)
end

local boatbumperprefabs = {}

local boatbumperdata =
{
    { name = "kelp",     material = MATERIALS.KELP,   tags = { "kelp" },      loot = "kelp",                  maxloots = 2, maxhealth = TUNING.BOAT.BUMPERS.KELP.HEALTH,     flammable = true, buildsound = "dontstarve/common/place_structure_wood"  },
    { name = "shell",    material = MATERIALS.SHELL,  tags = { "shell" },     loot = "slurtle_shellpieces",   maxloots = 2, maxhealth = TUNING.BOAT.BUMPERS.SHELL.HEALTH,    flammable = true, buildsound = "dontstarve/common/place_structure_stone"  },
}
for i, v in ipairs(boatbumperdata) do
    local boatbumper, item, placer = MakeBumperType(v)
    table.insert(boatbumperprefabs, boatbumper)
    table.insert(boatbumperprefabs, item)
    table.insert(boatbumperprefabs, placer)
end

return unpack(boatbumperprefabs)

