local assets = {
    Asset("ANIM", "anim/rabbitkinghorn.zip"),
}

local prefabs = {
    "rabbitkinghorn_chest",
}

local CANT_TAGS = {"INLIMBO", "NOCLICK", "FX"}
local function NoEnts(pt)
    local x, y, z = pt:Get()
    local ents = TheSim:FindEntities(x, y, z, MAX_PHYSICS_RADIUS, nil, CANT_TAGS)
    for _, ent in ipairs(ents) do
        local radius = ent:GetPhysicsRadius(0)
        if ent:GetDistanceSqToPoint(x, y, z) < radius * radius then
            return false
        end
    end
    return true
end
local function NoHolesNoInvisibleTiles(pt)
    local tile = TheWorld.Map:GetTileAtPoint(pt:Get())
    if GROUND_INVISIBLETILES[tile] then
        return false
    end

    return not TheWorld.Map:IsPointNearHole(pt)
end

local function ChestReturnPresentation(rabbitkinghorn_chest)
    rabbitkinghorn_chest:ReturnToScene()
end
local function OnPlayed(inst, musician)
    local x, y, z = musician.Transform:GetWorldPosition()
    local minradius = musician:GetPhysicsRadius(0) + 2
    for r = 4, 1, -1 do
        local offset = FindWalkableOffset(Vector3(x, y, z), math.random() * TWOPI, r + minradius + math.random(), 8, false, false, NoEnts, false, false)
        if offset then
            x, z = offset.x + x, offset.z + z
            break
        end
    end
    local rabbitkinghorn_chest = SpawnPrefab("rabbitkinghorn_chest")
    rabbitkinghorn_chest.Transform:SetPosition(x, y, z)
    rabbitkinghorn_chest:RemoveFromScene()
    rabbitkinghorn_chest:DoTaskInTime(1.3, ChestReturnPresentation)
end

local function OnHeard(inst, musician, instrument)
    if inst.components.farmplanttendable ~= nil then
        inst.components.farmplanttendable:TendTo(musician)
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst:AddTag("horn")

    inst.AnimState:SetBank("rabbitkinghorn")
    inst.AnimState:SetBuild("rabbitkinghorn")
    inst.AnimState:PlayAnimation("idle")

    --tool (from tool component) added to pristine state for optimization
    inst:AddTag("tool")

    MakeInventoryFloatable(inst, "small", 0.05, 0.8)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")
    local instrument = inst:AddComponent("instrument")
    instrument:SetRange(TUNING.RABBITKINGHORN_RANGE)
    instrument:SetOnHeardFn(OnHeard)
    instrument:SetOnPlayedFn(OnPlayed)
    instrument:SetAssetOverrides("rabbitkinghorn", "rabbitkinghorn01") -- FIXME(JBK): Sounds.

    inst:AddComponent("tool")
    inst.components.tool:SetAction(ACTIONS.PLAY)

    inst:AddComponent("finiteuses")
    inst.components.finiteuses:SetMaxUses(TUNING.RABBITKINGHORN_USES)
    inst.components.finiteuses:SetUses(TUNING.RABBITKINGHORN_USES)
    inst.components.finiteuses:SetOnFinished(inst.Remove)
    inst.components.finiteuses:SetConsumption(ACTIONS.PLAY, 1)

    inst:AddComponent("inventoryitem")

    MakeHauntableLaunch(inst)

    --inst:ListenForEvent("floater_startfloating", function(inst) inst.AnimState:PlayAnimation("float") end)
    --inst:ListenForEvent("floater_stopfloating", function(inst) inst.AnimState:PlayAnimation("idle") end)

    return inst
end

return Prefab("rabbitkinghorn", fn, assets, prefabs)
