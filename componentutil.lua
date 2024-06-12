require("components/raindome") --load some global functions defined for this component
require("components/temperatureoverrider") --load some global functions defined for this component

local GroundTiles = require("worldtiledefs")

--require_health being true means an entity is considered "dead" if it lacks the health replica.
function IsEntityDead(inst, require_health)
	local health = inst.replica.health
	if health == nil then
        return require_health == true
    end
	return health:IsDead()
end

function IsEntityDeadOrGhost(inst, require_health)
    if inst:HasTag("playerghost") then
        return true
    end
    return IsEntityDead(inst, require_health)
end

function GetStackSize(inst)
	local stackable = inst.replica.stackable
	return stackable and stackable:StackSize() or 1
end

function HandleDugGround(dug_ground, x, y, z)
    local spawnturf = GroundTiles.turf[dug_ground] or nil
    if spawnturf ~= nil then
        local loot = SpawnPrefab("turf_"..spawnturf.name)
        if loot.components.inventoryitem ~= nil then
			loot.components.inventoryitem:InheritWorldWetnessAtXZ(x, z)
        end
        loot.Transform:SetPosition(x, y, z)
        if loot.Physics ~= nil then
            local angle = math.random() * TWOPI
            loot.Physics:SetVel(2 * math.cos(angle), 10, 2 * math.sin(angle))
        end
    else
        SpawnPrefab("sinkhole_spawn_fx_"..tostring(math.random(3))).Transform:SetPosition(x, y, z)
    end
end

local VIRTUALOCEAN_HASTAGS = {"virtualocean"}
local VIRTUALOCEAN_CANTTAGS = {"INLIMBO"}
function FindVirtualOceanEntity(x, y, z, r)
    local ents = TheSim:FindEntities(x, y, z, r or MAX_PHYSICS_RADIUS, VIRTUALOCEAN_HASTAGS, VIRTUALOCEAN_CANTTAGS)
    for _, ent in ipairs(ents) do
        if ent.Physics ~= nil then
            local radius = ent.Physics:GetRadius()
            local ex, ey, ez = ent.Transform:GetWorldPosition()
            local dx, dz = ex - x, ez - z
            if dx * dx + dz * dz <= radius * radius then
                return ent
            end
        end
    end

    return nil
end

--------------------------------------------------------------------------
--Tags useful for testing against combat targets that you can hit,
--but aren't really considered "alive".

NON_LIFEFORM_TARGET_TAGS =
{
	"structure",
	"wall",
	"balloon",
	"groundspike",
	"smashable",
	"veggie", --stuff like lureplants... not considered life?
}

--Shadows and Gestalts don't have souls.
--NOTE: -Adding "soulless" tag to entities is preferred over expanding this list.
--      -Gestalts should already be using "soulless" tag.
--Lifedrain (batbat) also uses this list.
SOULLESS_TARGET_TAGS = ConcatArrays(
	{
		"soulless",
		"chess",
		"shadow",
		"shadowcreature",
		"shadowminion",
		"shadowchesspiece",
	},
	NON_LIFEFORM_TARGET_TAGS
)

--------------------------------------------------------------------------
function DecayCharlieResidueAndGoOnCooldownIfItExists(inst)
    local roseinspectableuser = inst.components.roseinspectableuser
    if roseinspectableuser == nil then
        return
    end
    roseinspectableuser:ForceDecayResidue()
    roseinspectableuser:GoOnCooldown()
end

local function OnFuelPresentation1(inst, x, z, upgraded)
    --local fx = SpawnPrefab("FIXME(JBK) Add this when ready.")
    --fx.Transform:SetPosition(x, 0, z)
end
local function OnFuelPresentation2(inst, x, z, upgraded)
    local fx = SpawnPrefab(upgraded and "shadow_puff_solid" or "shadow_puff")
    fx.Transform:SetPosition(x, 0, z)
    inst:ReturnToScene()
end
local function OnResidueActivated_Fuel_Internal(inst, doer, odds)
    local skilltreeupdater = doer.components.skilltreeupdater
    local upgraded = skilltreeupdater and skilltreeupdater:IsActivated("winona_charlie_2") and math.random() < odds or nil
    local fuel = SpawnPrefab(upgraded and "horrorfuel" or "nightmarefuel")
    fuel:RemoveFromScene()
    local x, y, z = inst.Transform:GetWorldPosition()
    local radius = inst:GetPhysicsRadius(0)
    if radius > 0 then
        radius = radius + 1.5
    end
    local theta = math.random() * PI2
    x, z = x + math.cos(theta) * radius, z + math.sin(theta) * radius
    fuel.Transform:SetPosition(x, 0, z)
    fuel:DoTaskInTime(1.0, OnFuelPresentation1, x, z, upgraded)
    fuel:DoTaskInTime(1.5, OnFuelPresentation2, x, z, upgraded)
end
local function OnResidueActivated_Fuel(inst, doer)
    OnResidueActivated_Fuel_Internal(inst, doer, TUNING.SKILLS.WINONA.ROSEGLASSES_UPGRADE_CHANCE)
end
local function OnResidueActivated_Fuel_IncreasedHorror(inst, doer)
    OnResidueActivated_Fuel_Internal(inst, doer, TUNING.SKILLS.WINONA.ROSEGLASSES_UPGRADE_CHANCE_INCREASED)
end
function MakeRoseTarget_CreateFuel(inst)
    local roseinspectable = inst:AddComponent("roseinspectable")
    roseinspectable:SetOnResidueActivated(OnResidueActivated_Fuel)
end
function MakeRoseTarget_CreateFuel_IncreasedHorror(inst)
    local roseinspectable = inst:AddComponent("roseinspectable")
    roseinspectable:SetOnResidueActivated(OnResidueActivated_Fuel_IncreasedHorror)
end
--------------------------------------------------------------------------
local function RosePoint_VineBridge_Check(inst, pt)
    local _world = TheWorld
    if _world.ismastersim then
        local vinebridgemanager = _world.components.vinebridgemanager
        if vinebridgemanager == nil then
            return false
        end
    end

    local _map = _world.Map
    local TILE_SCALE = TILE_SCALE
    local maxlength = TUNING.SKILLS.WINONA.CHARLIE_VINEBRIDGE_LENGTH_TILES

    local sx, sy, sz = pt:Get()
    if _map:IsOceanTileAtPoint(sx, 0, sz) then
        -- We want the player to be fully on land to initiate this.
        return false
    end

    -- Get direction vector from the player instance because it is the most context sensitive for directionality.
    local dirx, _, dirz = inst.Transform:GetWorldPosition()
    local dx, dz = sx - dirx, sz - dirz

    -- Convert floating precision to horizontal and vertical we do not need to worry about dist being zero because we are modifying the values here to always have a magnitude.
    if math.abs(dx) > math.abs(dz) then
        -- Horizontal.
        dx = dx < 0 and -TILE_SCALE or TILE_SCALE
        dz = 0
    else
        -- Vertical.
        dx = 0
        dz = dz < 0 and -TILE_SCALE or TILE_SCALE
    end

    -- Center start to center of tile.
    sx, sy, sz = _map:GetTileCenterPoint(sx, sy, sz)

    -- Scan for land.
    local hitland = false
    local spots = {}
    for i = 0, maxlength do -- Intentionally 0 to max to have a + 1 for the end tile cap inclusion.
        sx, sz = sx + dx, sz + dz

        local pt_offseted = Point(sx, 0, sz)
        if _map:IsLandTileAtPoint(sx, 0, sz) then
            hitland = true
            break
        end

        if not _map:CanDeployDockAtPoint(pt_offseted, inst) then
            return false
        end

        table.insert(spots, pt_offseted)
    end

    if not hitland or spots[1] == nil then
        return false
    end

    return true, spots
end
local function RosePoint_VineBridge_Do(inst, pt, spots)
    local vinebridgemanager = TheWorld.components.vinebridgemanager
    local duration = TUNING.VINEBRIDGE_DURATION
    local breakdata = {}
    local spawndata = {
        base_time = 0.5,
        random_time = 0.0,
    }
    for i, spot in ipairs(spots) do
        spawndata.base_time = 0.25 * i
        vinebridgemanager:QueueCreateVineBridgeAtPoint(spot.x, spot.y, spot.z, spawndata)
        breakdata.fxtime = duration + 0.25 * i
        breakdata.destroytime = breakdata.fxtime + 70 * FRAMES
        vinebridgemanager:QueueDestroyForVineBridgeAtPoint(spot.x, spot.y, spot.z, breakdata)
    end
    return true
end
-- NOTES(JBK): Functions and names for CLOSEINSPECTORUTIL checks.
-- The order of priority is defined by what is present in this table use the contextname to table.insert new ones.
ROSEPOINT_CONFIGURATIONS = {
    {
        contextname = "Vine Bridge",
        checkfn = RosePoint_VineBridge_Check,
        callbackfn = RosePoint_VineBridge_Do,
    },
}
--------------------------------------------------------------------------
--closeinspector

CLOSEINSPECTORUTIL = {}

CLOSEINSPECTORUTIL.IsValidTarget = function(doer, target)
    if TheWorld.ismastersim then
        return not (
            (target.Physics and target.Physics:GetMass() ~= 0) or
            target.components.locomotor or
            target.components.inventoryitem or
            target:HasTag("character")
        )
    else
        return not (
            (target.Physics and target.Physics:GetMass() ~= 0) or
            target:HasTag("locomotor") or
            target.replica.inventoryitem or
            target:HasTag("character")
        )
    end
end

CLOSEINSPECTORUTIL.IsValidPos = function(doer, pos)
    for _, config in ipairs(ROSEPOINT_CONFIGURATIONS) do
        if config.checkfn(doer, pos) then
            return true
        end
    end

    return false
end

CLOSEINSPECTORUTIL.CanCloseInspect = function(doer, targetorpos)
    local inventory
    if TheWorld.ismastersim then
        inventory = doer and doer.components.inventory or nil
    else
        inventory = doer and doer.replica.inventory or nil
    end
    if inventory and inventory:EquipHasTag("closeinspector") then
        if targetorpos:is_a(EntityScript) then
            if not targetorpos:IsValid() then
                return false
            end
            return CLOSEINSPECTORUTIL.IsValidTarget(doer, targetorpos)
        else
            return CLOSEINSPECTORUTIL.IsValidPos(doer, targetorpos)
        end
    end

    return false
end

--------------------------------------------------------------------------
