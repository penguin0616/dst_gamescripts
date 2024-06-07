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
--------------------------------------------------------------------------
local function RosePoint_VineBridge_Check(inst, pt)
    local _world = TheWorld
    local vinebridgemanager = _world.components.vinebridgemanager
    if vinebridgemanager == nil then
        return false
    end

    local _map = _world.Map
    local TILE_SCALE = TILE_SCALE
    local maxlength = TUNING.SKILLS.WINONA.CHARLIE_VINEBRIDGE_LENGTH_TILES

    local sx, sy, sz = pt:Get()
    local on_overhang = false
    if _map:IsOceanTileAtPoint(sx, 0, sz) then
        if not _map:IsVisualGroundAtPoint(sx, 0, sz) then
            -- On water entirely with no ground reference.
            return false
        end
        -- We are on an overhang let the code below know to apply an offset to get off of it.
        on_overhang = true
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


    if on_overhang then
        sx, sz = sx - dx * 0.5, sz - dz * 0.5 -- Move half a tile backwards to go back onto a land tile.
    end

    -- Scan for land.
    local hitland = false
    local spots = {}
    --SpawnPrefab("yellowmooneye").Transform:SetPosition(sx, 0, sz)
    for i = 0, maxlength do -- Intentionally 0 to max to have a + 1 for the end tile cap inclusion.
        sx, sz = sx + dx, sz + dz

        local pt_offseted = Point(sx, 0, sz)
        if _map:IsVisualGroundAtPoint(sx, 0, sz) then
            --SpawnPrefab("bluemooneye").Transform:SetPosition(sx, 0, sz)
            hitland = true
            if not on_overhang and not _map:IsLandTileAtPoint(sx, 0, sz) then -- Hit an edge of the land turf on the other side but only one overhang is acceptable.
                table.insert(spots, pt_offseted)
            end
            break
        end

        if not _map:CanDeployDockAtPoint(pt_offseted, inst) then
            --SpawnPrefab("redmooneye").Transform:SetPosition(sx, 0, sz)
            return false
        end

        table.insert(spots, pt_offseted)
        --SpawnPrefab("greenmooneye").Transform:SetPosition(sx, 0, sz)
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
-- NOTES(JBK): Functions and names for roseinspectableuser:RegisterRosePointContext() which are used in RoseInspectableUser:DoRoseInspectionOnPoint().
-- The order of priority is defined by what is used in the component's registration order.
ROSEPOINT_CONFIGURATIONS = {
    VINEBRIDGE = {
        contextname = "Vine Bridge",
        checkfn = RosePoint_VineBridge_Check,
        callbackfn = RosePoint_VineBridge_Do,
    },
}
--------------------------------------------------------------------------
