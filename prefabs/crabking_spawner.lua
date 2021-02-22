local prefabs =
{
    "crabking",
}

local CRABKING_SPAWNTIMER = "regen_crabking"

local ZERO = Vector3(0,0,0)
local function zero_spawn_offset(inst)
    if TheWorld.Map:GetPlatformAtPoint(inst.Transform:GetWorldPosition()) then return end
    return ZERO
end

local function OnKilled(inst)
    inst.components.worldsettingstimer:StartTimer(CRABKING_SPAWNTIMER, TUNING.CRABKING_RESPAWN_TIME)
end

local function GenerateNewKing(inst)
    inst.components.childspawner:AddChildrenInside(1)
    inst.components.childspawner:StartSpawning()
end

local function ontimerdone(inst, data)
    if data.name == CRABKING_SPAWNTIMER then
        GenerateNewKing(inst)
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    --[[Non-networked entity]]

    inst:AddTag("CLASSIFIED")
    inst:AddTag("crabking_spawner")

    inst:AddComponent("childspawner")
    inst.components.childspawner.childname = "crabking"
    inst.components.childspawner:SetMaxChildren(1)
    inst.components.childspawner:SetSpawnPeriod(TUNING.CRABKING_SPAWN_TIME, 0)
    inst.components.childspawner.onchildkilledfn = OnKilled
    if TUNING.SPAWN_CRABKING then
        inst.components.childspawner:StartSpawning()
    else
        inst.components.childspawner:StopSpawning()
    end
    inst.components.childspawner:StopRegen()
    inst.components.childspawner.overridespawnlocation = zero_spawn_offset

    inst:AddComponent("worldsettingstimer")
    inst.components.worldsettingstimer:AddTimer(CRABKING_SPAWNTIMER, TUNING.CRABKING_RESPAWN_TIME, TUNING.SPAWN_CRABKING)
    inst:ListenForEvent("timerdone", ontimerdone)

    return inst
end

return Prefab("crabking_spawner", fn, nil, prefabs)
