local SPAWNPOINT_NAME = "spawnpoint"
local SPAWNPOINT_LOCAL_NAME = "spawnpoint_local"

local function GetSpawnPoint(inst)
    local local_pos = inst.components.knownlocations:GetLocation(SPAWNPOINT_LOCAL_NAME)
    if local_pos ~= nil then
        local platform = inst:GetCurrentPlatform()
        if platform ~= nil then
            return Vector3(platform.entity:LocalToWorldSpace(local_pos:Get()))
        end
    end
    return inst.components.knownlocations:GetLocation(SPAWNPOINT_NAME) or inst:GetPosition()
end

local function UpdateSpawnPoint(inst, dont_overwrite)
    if dont_overwrite and (inst.components.knownlocations == nil or inst.components.knownlocations:GetLocation(SPAWNPOINT_NAME) ~= nil) then
        return
    end

    if inst:IsOnPassablePoint() then
        local x, y, z = inst.Transform:GetWorldPosition()
        local pos = Vector3(x, 0, z)

        local platform = inst:GetCurrentPlatform()

        if platform ~= nil then
            local local_pos = Vector3(platform.entity:WorldToLocalSpace(x, 0, z))

            inst.components.knownlocations:RememberLocation(SPAWNPOINT_LOCAL_NAME, local_pos, dont_overwrite)
        else
            inst.components.knownlocations:ForgetLocation(SPAWNPOINT_LOCAL_NAME)
        end

        if x == 0 and z == 0 then
            -- Make sure something is dirty for sure.
            inst._originx:set_local(0)
        end
        inst._originx:set(x)
        inst._originz:set(z)

        inst.components.knownlocations:RememberLocation(SPAWNPOINT_NAME, pos, dont_overwrite)
    end
end

function UpdateSpawnPointOnLoad(inst)
    local x, y, z
    local pos = inst.components.knownlocations:GetLocation(SPAWNPOINT_NAME)
    if pos then
        x, y, z = pos:Get()
    else
        x, y, z = inst.Transform:GetWorldPosition()
    end

    if x == 0 and z == 0 then
        -- Make sure something is dirty for sure.
        inst._originx:set_local(0)
    end
    inst._originx:set(x)
    inst._originz:set(z)

    return pos ~= nil
end

function ClearSpawnPoint(inst)
    inst.components.knownlocations:ForgetLocation(SPAWNPOINT_NAME)
    inst.components.knownlocations:ForgetLocation(SPAWNPOINT_LOCAL_NAME)
end

---------------------------------------------------------------------------------------------------

local CONTAINER_MUST_TAGS = { "_container" }
local CONTAINER_CANT_TAGS = { "portablestorage", "FX", "NOCLICK", "DECOR", "INLIMBO" }

local ALLOWED_CONTAINER_TYPES = { "chest", "pack" }

local function FindContainerWithItem(inst, item, count)
    count = count or 0
    local x, y, z = GetSpawnPoint(inst):Get()

    local stack_maxsize = item.components.stackable ~= nil and item.components.stackable.maxsize or 1

    local ents = TheSim:FindEntities(x, y, z, TUNING.STORAGE_ROBOT_WORK_RADIUS, CONTAINER_MUST_TAGS, CONTAINER_CANT_TAGS)

    local function SamePrefabAndSkin(ent)
        return ent.prefab == item.prefab and ent.skinname == item.skinname
    end

    for i, ent in ipairs(ents) do
        if ent.components.container ~= nil and
            table.contains(ALLOWED_CONTAINER_TYPES, ent.components.container.type) and
            ent.components.container.canbeopened and
            ent.components.container:HasItemThatMatches(SamePrefabAndSkin, 1) and
            ent.components.container:CanAcceptCount(item, stack_maxsize) > count and
            ent:IsOnPassablePoint() and
            ent:GetCurrentPlatform() == inst:GetCurrentPlatform()
        then
            return ent
        end
    end
end

local function FindItemToPickupAndStore_filter(inst, item, match_item)
    -- Ignore ourself and other storage robots.
    if item:HasTag("storagerobot") then
        return
    end

    if not (item.components.inventoryitem ~= nil and
        item.components.inventoryitem.canbepickedup and
        item.components.inventoryitem.cangoincontainer and
        not item.components.inventoryitem:IsHeld())
    then
        return
    end

    if not item:IsOnPassablePoint() or item:GetCurrentPlatform() ~= inst:GetCurrentPlatform() then
        return
    end

    if inst.brain ~= nil and inst.brain:ShouldIgnoreItem(item) then
        return
    end

    if match_item ~= nil and not (item.prefab == match_item.prefab and item.skinname == match_item.skinname) then
        return
    end

    if item.components.bait ~= nil and item.components.bait.trap ~= nil then -- Do not steal baits.
        return
    end

    if item.components.trap ~= nil then
        return
    end

    -- Checks how many of this item we have.
    local function SamePrefabAndSkin(ent)
        return ent.prefab == item.prefab and ent.skinname == item.skinname
    end
    local _, count = inst.components.inventory:HasItemThatMatches(SamePrefabAndSkin, 1)

    local container = FindContainerWithItem(inst, item, count)

    if not container then
        return
    end

    return item, container
end

local PICKUP_MUST_TAGS =
{
    "_inventoryitem"
}

local PICKUP_CANT_TAGS =
{
    "INLIMBO", "NOCLICK", "irreplaceable", "knockbackdelayinteraction",
    "event_trigger", "mineactive", "catchable", "fire", "spider", "cursed",
    "heavy", "outofreach",
}

local function FindItemToPickupAndStore(inst, match_item)
    local x, y, z    = inst.Transform:GetWorldPosition()
    local sx, xy, sz = GetSpawnPoint(inst):Get()

    local ents = TheSim:FindEntities(x, y, z, TUNING.STORAGE_ROBOT_WORK_RADIUS, PICKUP_MUST_TAGS, PICKUP_CANT_TAGS)

    for i, ent in ipairs(ents) do
        if ent:GetDistanceSqToPoint(sx, xy, sz) <= TUNING.STORAGE_ROBOT_WORK_RADIUS * TUNING.STORAGE_ROBOT_WORK_RADIUS then
            local item, container = FindItemToPickupAndStore_filter(inst, ent, match_item)

            if item ~= nil then
                return item, container
            end
        end
    end
end

---------------------------------------------------------------------------------------------------

return
{
    GetSpawnPoint = GetSpawnPoint,
    UpdateSpawnPoint = UpdateSpawnPoint,
    UpdateSpawnPointOnLoad = UpdateSpawnPointOnLoad,
    ClearSpawnPoint = ClearSpawnPoint,
    FindContainerWithItem = FindContainerWithItem,
    FindItemToPickupAndStore = FindItemToPickupAndStore,
}
