local assets =
{
}

local prefabs =
{
	"cookiecutter",
}

local function DoReleaseAllChildren(inst)
	inst.components.childspawner:ReleaseAllChildren()
end

local function OnEntitySleep(inst)
	if inst.releasechildrentask ~= nil then
		inst.releasechildrentask:Cancel()
		inst.releasechildrentask = nil
	end
end

local function OnEntityWake(inst)
	if inst.releasechildrentask ~= nil then
		inst.releasechildrentask:Cancel()
	end
	inst.releasechildrentask = inst:DoTaskInTime(0.1, DoReleaseAllChildren)
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()

    --[[Non-networked entity]]
    inst:AddTag("CLASSIFIED")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("childspawner")
    inst.components.childspawner:SetRegenPeriod(TUNING.COOKIECUTTER_SPAWNER.REGEN_TIME)
    inst.components.childspawner:SetSpawnPeriod(TUNING.COOKIECUTTER_SPAWNER.RELEASE_TIME)
    inst.components.childspawner:SetMaxChildren(TUNING.COOKIECUTTER_SPAWNER.MAX_CHILDREN)
    inst.components.childspawner:StartRegen()
	inst.components.childspawner.spawnradius = {min = 2, max = TUNING.COOKIECUTTER.WANDER_DIST}
	inst.components.childspawner.childname = "cookiecutter"
	inst.components.childspawner.wateronly = true
	inst.components.childspawner:StartSpawning()

    inst.OnEntitySleep = OnEntitySleep
    inst.OnEntityWake = OnEntityWake

    return inst
end


return Prefab("cookiecutter_spawner", fn, assets, prefabs)