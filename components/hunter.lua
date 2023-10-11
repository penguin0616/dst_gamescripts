--------------------------------------------------------------------------
--[[ Hunter class definition ]]
--------------------------------------------------------------------------

return Class(function(self, inst)

assert(TheWorld.ismastersim, "Hunter should not exist on client")

--------------------------------------------------------------------------
--[[ Dependencies ]]
--------------------------------------------------------------------------

local SourceModifierList = require("util/sourcemodifierlist")

--------------------------------------------------------------------------
--[[ Constants ]]
--------------------------------------------------------------------------

local HUNT_UPDATE = 2

local MIN_TRACKS = 6
local MAX_TRACKS = 12

local FORK_ANGLE_MIN = PI / 10
local FORK_ANGLE_MAX = PI / 14

local FORK_PRINTS_ANGLE_DEVIATION = PI / 7

--------------------------------------------------------------------------
--[[ Member variables ]]
--------------------------------------------------------------------------

--Public
self.inst = inst

-- Private
local _activeplayers = {}
local _activehunts = {}
local _wargshrines = SourceModifierList(inst, false, SourceModifierList.boolean)

--------------------------------------------------------------------------
--[[ Private member functions ]]
--------------------------------------------------------------------------

local OnUpdateHunt
local ResetHunt

local function IsLunarPortalActive()
    return TheWorld.components.riftspawner ~= nil and TheWorld.components.riftspawner:IsLunarPortalActive()
end

local function GetMaxHunts()
    return #_activeplayers
end

local function GetAlternateBeastChance(hunt)
    local day = TheWorld.state.cycles
    local chance = Lerp(TUNING.HUNT_ALTERNATE_BEAST_CHANCE_MIN, TUNING.HUNT_ALTERNATE_BEAST_CHANCE_MAX, day/100)
    return math.clamp(chance, TUNING.HUNT_ALTERNATE_BEAST_CHANCE_MIN, TUNING.HUNT_ALTERNATE_BEAST_CHANCE_MAX)
end

local function RemoveDirt(hunt)
    if hunt.lastdirt ~= nil then
        inst:RemoveEventCallback("onremove", hunt.lastdirt._ondirtremove, hunt.lastdirt)
        hunt.lastdirt:Remove()
        hunt.lastdirt = nil
    end
end

local function RemoveDirtFork(hunt)
    if hunt.lastdirt_fork ~= nil then
        inst:RemoveEventCallback("onremove", hunt.lastdirt_fork._ondirtremove, hunt.lastdirt_fork)
        hunt.lastdirt_fork:Remove()
        hunt.lastdirt_fork = nil
        hunt.direction_fork = nil
    end
end

local function StopHunt(hunt)
    RemoveDirt(hunt)
    RemoveDirtFork(hunt)

    if hunt.hunttask ~= nil then
        hunt.hunttask:Cancel()
        hunt.hunttask = nil
    end

    hunt.investigatedfork = nil
    hunt.score = 0
end

local function BeginHunt(hunt)
    hunt.hunttask = inst:DoPeriodicTask(HUNT_UPDATE, OnUpdateHunt, nil, hunt)
end

local function StopCooldown(hunt)
    if hunt.cooldowntask ~= nil then
        hunt.cooldowntask:Cancel()
        hunt.cooldowntask = nil
        hunt.cooldowntime = nil
    end
end

local function OnCooldownEnd(inst, hunt)
    StopCooldown(hunt) -- clean up references
    StopHunt(hunt)

    BeginHunt(hunt)
end

local function RemoveHunt(hunt)
    StopHunt(hunt)
    for i,v in ipairs(_activehunts) do
        if v == hunt then
            table.remove(_activehunts, i)
            return
        end
    end
end

local function StartCooldown(inst, hunt, cooldown)
    cooldown = cooldown or TUNING.HUNT_COOLDOWN + TUNING.HUNT_COOLDOWNDEVIATION * (math.random() * 2 - 1)

    StopHunt(hunt)
    StopCooldown(hunt)

    if #_activehunts > GetMaxHunts() then
        RemoveHunt(hunt)
        return
    end

    if cooldown and cooldown > 0 then
        hunt.activeplayer = nil
        hunt.lastdirt = nil
        hunt.lastdirttime = nil
        hunt.lastdirt_fork = nil
        hunt.direction_fork = nil

        hunt.cooldowntask = inst:DoTaskInTime(cooldown, OnCooldownEnd, hunt)
        hunt.cooldowntime = GetTime() + cooldown
    end
end

local function CreateNewHunt()
    -- Given the way hunt is used, it should really be its own class now
    return {
        lastdirt = nil,
        direction = nil,
        lastdirt_fork = nil,
        activeplayer = nil,
        investigatedfork = nil,
        score = 0,
    }
end

local function StartHunt(cooldown)
    local hunt = CreateNewHunt()
    table.insert(_activehunts, hunt)
    inst:DoTaskInTime(0, StartCooldown, hunt, cooldown or TUNING.HUNT_COOLDOWN + TUNING.HUNT_COOLDOWNDEVIATION * (math.random() * 2 - 1))
    return hunt
end

local function GetSpawnPoint(pt, direction, radius, hunt)
    if direction then
        local offset = Vector3(radius * math.cos( direction ), 0, -radius * math.sin( direction ))
        local spawn_point = pt + offset
        --print(string.format("Hunter:GetSpawnPoint RESULT %s, %2.2f", tostring(spawn_point), direction/DEGREES))
        return spawn_point
    end
end

local function SpawnBat(inst)
    local pos = FindNearbyLand(inst:GetPosition(), 2)
    if pos ~= nil then
        local bat = SpawnPrefab("bat")
        bat.Transform:SetPosition(pos:Get())
        bat:PushEvent("fly_back")
    end
end

local function SpawnDirtAt(pt, hunt)
    local dirt = SpawnPrefab("dirtpile")
    dirt.Transform:SetPosition(pt:Get())
    return dirt
end

local function SpawnClawTracksForDirt(dirt, direction)
    dirt.AnimState:PlayAnimation("idle_pile_tooth")
    local x, y, z = dirt.Transform:GetWorldPosition()

    local total_tracks = math.random(2, 4)
    for i = 1, total_tracks do
        local newdirection = direction + (math.random() * 2 - 1) * FORK_PRINTS_ANGLE_DEVIATION - PI/2
        local radius = math.random() + i * 2
        local dx, dz = radius * math.sin(newdirection), radius * math.cos(newdirection)

        if TheWorld.Map:IsAboveGroundAtPoint(x + dx, y, z + dz) then
            local track = SpawnPrefab("animal_track")
            -- NOTES(JBK): The alpha set here is working but it makes the art too background dependent relative to the other tracks.
            --track:SetBaseAlpha(1 - radius / 13) -- (total_tracks max) * 2 + 1 + (fudge factor)
            track.Transform:SetPosition(x + dx, y, z + dz)
            track.Transform:SetRotation(newdirection/DEGREES)
            track.AnimState:PlayAnimation("clawed" .. math.random(1, 3))
        end
    end
end

local function SpawnDirt(pt, hunt)
    local spawn_pt = GetSpawnPoint(pt, hunt.direction, TUNING.HUNT_SPAWN_DIST, hunt)
    if spawn_pt ~= nil then
        local dirt = SpawnDirtAt(spawn_pt, hunt)
        if hunt.investigatedfork then
            SpawnClawTracksForDirt(dirt, hunt.direction)
        end
        if hunt.lastdirttime ~= nil and hunt.trackspawned > 1 then
            hunt.score = hunt.score + (GetTime() - hunt.lastdirttime)
        end
        hunt.lastdirt = dirt
        hunt.lastdirttime = GetTime()
        
        if hunt.ambush_track_num ~= nil and hunt.ambush_track_num == hunt.trackspawned then
            local day = TheWorld.state.cycles
            local num_bats = math.min(3 + math.floor(day/35), 6)
            for i = 1, num_bats do
                dirt:DoTaskInTime(0.2 * i + math.random() * 0.3, SpawnBat)
            end
            hunt.ambush_track_num = nil
        end
        
        local function ondirtremove()
            hunt.lastdirt = nil
            hunt.lastdirt_fork = nil
            hunt.direction_fork = nil
            ResetHunt(hunt)
        end
        dirt._ondirtremove = ondirtremove
        inst:ListenForEvent("onremove", dirt._ondirtremove, dirt)

        -- NOTES(JBK): Does not matter if fork is a success or failure it is only bonus if it succeeds.
        spawn_pt = GetSpawnPoint(pt, hunt.direction_fork, TUNING.HUNT_SPAWN_DIST, hunt)
        if spawn_pt ~= nil then
            local dirt_fork = SpawnDirtAt(spawn_pt, hunt)
            if not hunt.investigatedfork then
                SpawnClawTracksForDirt(dirt_fork, hunt.direction_fork)
            end
            hunt.lastdirt_fork = dirt_fork

            dirt_fork._ondirtremove = ondirtremove
            inst:ListenForEvent("onremove", dirt_fork._ondirtremove, dirt_fork)
        end

        return true
    end

    return false
end

local function GetRunAngle(pt, angle, radius)
    local offset, result_angle = FindWalkableOffset(pt, angle, radius, 14, true)
    return result_angle
end

local function GetNextSpawnAngle(pt, direction, radius, attempts)
    local base_angle = direction or math.random() * 2 * PI

    if attempts == 1 then
        -- NOTES(JBK): Only check if the point is above land here do not fan out the checks we want fixed deviation angles precalculated to direction.
        local dx, dz = radius * math.cos(base_angle), -radius * math.sin(base_angle)
        return TheWorld.Map:IsAboveGroundAtPoint(pt.x + dx, pt.y, pt.z + dz) and base_angle or nil
    end

    local deviation = (math.random() * 2 - 1) * TUNING.TRACK_ANGLE_DEVIATION * DEGREES

    local start_angle = base_angle + deviation
    --print(string.format("   original: %2.2f, deviation: %2.2f, starting angle: %2.2f", base_angle/DEGREES, deviation/DEGREES, start_angle/DEGREES))

    return GetRunAngle(pt, start_angle, radius)
end

local function StartDirt(hunt, position)
    RemoveDirt(hunt)
    RemoveDirtFork(hunt)

    local pt = position

    hunt.numtrackstospawn = math.random(MIN_TRACKS, MAX_TRACKS)

    local lunarportalactive = IsLunarPortalActive()
    if not lunarportalactive and math.random() <= GetAlternateBeastChance(hunt) then
        hunt.fork_track_num = math.random(math.floor(hunt.numtrackstospawn / 2), hunt.numtrackstospawn - 2)
    end

    if IsSpecialEventActive(SPECIAL_EVENTS.HALLOWED_NIGHTS) then
		hunt.ambush_track_num = math.random(math.floor(hunt.numtrackstospawn/2), hunt.numtrackstospawn-1)
	end

    hunt.trackspawned = 0
    hunt.score = 0
    hunt.direction = GetNextSpawnAngle(pt, nil, TUNING.HUNT_SPAWN_DIST)
    if hunt.direction ~= nil then
        -- it's ok if this spawn fails, because we'll keep trying every HUNT_UPDATE
        local spawnRelativeTo = pt
        SpawnDirt(spawnRelativeTo, hunt)
        if lunarportalactive then
            hunt.investigatedfork = true
        end
    end
end

-- are we too close to the last dirtpile of a hunt?
local function IsNearHunt(player)
    for i,hunt in ipairs(_activehunts) do
        if hunt.lastdirt ~= nil and player:IsNear(hunt.lastdirt, TUNING.MIN_JOINED_HUNT_DISTANCE) then
            return true
        end
    end
    return false
end

local function IsEligible(player)
	local area = player.components.areaaware
	return TheWorld.Map:IsVisualGroundAtPoint(player.Transform:GetWorldPosition())
			and area:GetCurrentArea() ~= nil
			and not area:CurrentlyInTag("nohunt")
			and not area:CurrentlyInTag("moonhunt")
end

-- something went unrecoverably wrong, try again after a brief pause
ResetHunt = function(hunt, washedaway)
    if hunt.activeplayer ~= nil then
        hunt.activeplayer:PushEvent("huntlosttrail", { washedaway = washedaway })
    end

    StartCooldown(inst, hunt, TUNING.HUNT_RESET_TIME)
end

-- Don't be tricked by the name. This is not called every frame
OnUpdateHunt = function(inst, hunt)
    if hunt.lastdirttime ~= nil then
        if hunt.trackspawned >= 1 then
            local wet = TheWorld.state.wetness > 15 or TheWorld.state.israining

            local lastdirttime = GetTime() - hunt.lastdirttime
            local maxtime = (wet and 0.75 or 1.25) * TUNING.SEG_TIME
            if lastdirttime > maxtime then

                -- check if the player is currently active in any other hunts
                local playerIsInOtherHunt = false
                for i,v in ipairs(_activehunts) do
                    if v ~= hunt and v.activeplayer and hunt.activeplayer then
                        if v.activeplayer == hunt.activeplayer then
                            playerIsInOtherHunt = true
                        end
                    end
                end

                -- if the player is still active in another hunt then end this one quietly
                if playerIsInOtherHunt then
                    StartCooldown(inst, hunt)
                else
                    ResetHunt(hunt, wet) --Wash the tracks away but only if the player has seen at least 1 track
                end

                return
            end
        end
    end

    if hunt.lastdirt == nil then
        -- pick a player that is available, meaning, not being the active participant in a hunt
        local huntingPlayers = {}
        for i,v in ipairs(_activehunts) do
            if v.activeplayer then
                huntingPlayers[v.activeplayer] = true
            end
        end

        local eligiblePlayers = {}
        for i,v in ipairs(_activeplayers) do
            if not huntingPlayers[v] and not IsNearHunt(v) and IsEligible(v) then
                table.insert(eligiblePlayers, v)
            end
        end
        if #eligiblePlayers == 0 then
            -- Maybe next time?
            return
        end
        local player = eligiblePlayers[math.random(1,#eligiblePlayers)]
        --print("Start hunt for player",player)
        local position = player:GetPosition()
        StartDirt(hunt, position)
    else
        -- if no player near enough, then give up this hunt and start a new one
        local x, y, z = hunt.lastdirt.Transform:GetWorldPosition()

        if not IsAnyPlayerInRange(x, y, z, TUNING.MAX_DIRT_DISTANCE) then
            -- try again rather soon
            StartCooldown(inst, hunt, .1)
        end
    end
end

local ALTERNATE_BEASTS = {"warg", "spat"}
local function GetHuntedBeast(hunt, spawn_pt)
    if self:IsWargShrineActive() then
        return "claywarg"
    end

    -- NOTES(JBK): Very high priority for goats with all of the random elements in play.
    if TheWorld.state.isspring and TheWorld.state.israining and TheWorld.Map:FindVisualNodeAtPoint(spawn_pt.x, spawn_pt.y, spawn_pt.z, "sandstorm") then
        return "lightninggoat"
    end

    if hunt.investigatedfork and IsLunarPortalActive() then
        return "warg"
    end

    if hunt.investigatedfork or math.random() <= GetAlternateBeastChance(hunt) then
        return GetRandomItem(ALTERNATE_BEASTS)
    end

    if TheWorld.state.iswinter then
        return "koalefant_winter"
    end

    return "koalefant_summer"
end

local function SpawnHuntedBeast(hunt, pt)
    local spawn_pt = GetSpawnPoint(pt, hunt.direction, TUNING.HUNT_SPAWN_DIST, hunt)
    if spawn_pt == nil then
        return false
    end

    local seconds_per_node = hunt.score / (hunt.numtrackstospawn - 1)
    local score_unclamped = (TUNING.HUNT_SCORE_TIME_PER_NODE_MAX - seconds_per_node) / (TUNING.HUNT_SCORE_TIME_PER_NODE_MAX - TUNING.HUNT_SCORE_TIME_PER_NODE)
    hunt.score = math.clamp(score_unclamped, 0, 1)
    local beastprefab = GetHuntedBeast(hunt, spawn_pt)
    local huntedbeast = SpawnPrefab(beastprefab)
    huntedbeast.Physics:Teleport(spawn_pt:Get())
    -- NOTES(JBK): Let each prefab handle the isfork in the event specifically.
    huntedbeast:PushEvent("spawnedforhunt", {beast = beastprefab, pt = spawn_pt, isfork = hunt.investigatedfork, iswrongfork = hunt.iswrongfork, score = hunt.score})

    return true
end

local function TryToSpawnFork(spawn_pt, hunt, tries)
    local spawn_dist = TUNING.HUNT_SPAWN_DIST
    for i = 1, tries do
        local deviation = (FORK_ANGLE_MAX - FORK_ANGLE_MIN) * math.random() + FORK_ANGLE_MIN
        if math.random() < 0.5 then -- NOTES(JBK): Remove deviation bias to a specific direction.
            deviation = -deviation
        end
        local fork_angle = GetNextSpawnAngle(spawn_pt, hunt.direction + deviation, spawn_dist, 1) or  -- + deviation
                           GetNextSpawnAngle(spawn_pt, hunt.direction - deviation, spawn_dist, 1)     -- - deviation
        if fork_angle ~= nil then
            hunt.direction_fork = fork_angle
            return true
        end
    end
    return false
end

local function SpawnTrack(spawn_pt, hunt)
    if spawn_pt then
        local next_angle = GetNextSpawnAngle(spawn_pt, hunt.direction, TUNING.HUNT_SPAWN_DIST)
        if next_angle ~= nil then
            hunt.direction = next_angle
            hunt.trackspawned = hunt.trackspawned + 1

            if hunt.fork_track_num and hunt.trackspawned >= hunt.fork_track_num then
                TryToSpawnFork(spawn_pt, hunt, 5) -- NOTES(JBK): If this fails the fork will not appear try another hunt!
            end

            local track = SpawnPrefab("animal_track")
            track.Transform:SetPosition(spawn_pt:Get())
            track.Transform:SetRotation(hunt.direction/DEGREES - 90)
            return track
        end
    end

    return nil
end

--------------------------------------------------------------------------
--[[ Private event handlers ]]
--------------------------------------------------------------------------

local function KickOffHunt()
    -- schedule start of a new hunt
    if #_activehunts < GetMaxHunts() then
        StartHunt()
    end
end

local function OnPlayerJoined(src, player)
    for i,v in ipairs(_activeplayers) do
        if v == player then
            return
        end
    end
    table.insert(_activeplayers, player)
    -- one hunt per player.
    KickOffHunt()
end

local function OnPlayerLeft(src, player)
    for i,v in ipairs(_activeplayers) do
        if v == player then
            table.remove(_activeplayers, i)
            return
        end
    end
end

local function OnWargShrineActivated(src, shrine)
    _wargshrines:SetModifier(shrine, true)
end

local function OnWargShrineDeactivated(src, shrine)
    _wargshrines:RemoveModifier(shrine)
end

--------------------------------------------------------------------------
--[[ Initialization ]]
--------------------------------------------------------------------------

for i, v in ipairs(AllPlayers) do
    OnPlayerJoined(self, v)
end

inst:ListenForEvent("ms_playerjoined", OnPlayerJoined, TheWorld)
inst:ListenForEvent("ms_playerleft", OnPlayerLeft, TheWorld)
inst:ListenForEvent("wargshrineactivated", OnWargShrineActivated, TheWorld)
inst:ListenForEvent("wargshrinedeactivated", OnWargShrineDeactivated, TheWorld)

--------------------------------------------------------------------------
--[[ Public member functions ]]
--------------------------------------------------------------------------

-- if anything fails during this step, it's basically unrecoverable, since we only have this one chance
-- to spawn whatever we need to spawn.  if that fails, we need to restart the whole process from the beginning
-- and hope we end up in a better place
function self:OnDirtInvestigated(pt, doer)
    local hunt = nil
    -- find the hunt this pile belongs to
    for i, v in ipairs(_activehunts) do
        local islastdirt = v.lastdirt ~= nil and v.lastdirt:GetPosition() == pt
        local islastdirt_fork = v.lastdirt_fork ~= nil and v.lastdirt_fork:GetPosition() == pt
        if islastdirt or islastdirt_fork then
            hunt = v
            if islastdirt then
                inst:RemoveEventCallback("onremove", hunt.lastdirt._ondirtremove, hunt.lastdirt)
                RemoveDirtFork(hunt)
                if not hunt.investigatedfork and hunt.fork_track_num and hunt.trackspawned == hunt.fork_track_num then
                    -- The player investigated a non-fork and there was a fork clear forks from this path entirely.
                    hunt.fork_track_num = nil
                    doer:PushEvent("huntavoidfork")
                end
            else -- islastdirt_fork
                inst:RemoveEventCallback("onremove", hunt.lastdirt_fork._ondirtremove, hunt.lastdirt_fork)
                RemoveDirt(hunt)
                -- Set the fork to the original and modify rates.
                hunt.lastdirt = hunt.lastdirt_fork
                hunt.lastdirt_fork = nil
                hunt.direction_fork = nil
                if hunt.investigatedfork then
                    -- The player investigated a fork and then went for a non-fork mark this as a wrong path.
                    hunt.iswrongfork = true
                    doer:PushEvent("huntwrongfork")
                else
                    hunt.investigatedfork = true
                    doer:PushEvent("huntstartfork")
                end
            end
            break
        end
    end

    if hunt == nil then
        -- we should probably do something intelligent here.
        --print("yikes, no matching hunt found for investigated dirtpile")
        return
    end

    hunt.activeplayer = doer

    if hunt.numtrackstospawn ~= nil and hunt.numtrackstospawn > 0 then
        local track = SpawnTrack(pt, hunt)
        if track then
            if hunt.trackspawned < hunt.numtrackstospawn then
                if not SpawnDirt(pt, hunt) then
                    ResetHunt(hunt)
                end
            elseif hunt.trackspawned == hunt.numtrackstospawn then
                if SpawnHuntedBeast(hunt, pt) then
                    if hunt.investigatedfork and not hunt.iswrongfork and not IsLunarPortalActive() then
                        doer:PushEvent("huntsuccessfulfork")
                    else
                        doer:PushEvent("huntbeastnearby")
                    end
                    StartCooldown(inst, hunt)
                else
                    ResetHunt(hunt)
                end
            end
        else
            ResetHunt(hunt)
        end
    end
end

function self:IsWargShrineActive()
    return _wargshrines:Get() and IsSpecialEventActive(SPECIAL_EVENTS.YOTV)
end

--------------------------------------------------------------------------
--[[ Update ]]
--------------------------------------------------------------------------

function self:LongUpdate(dt)
    for i,hunt in ipairs(_activehunts) do
        if hunt.cooldowntask ~= nil and hunt.cooldowntime ~= nil then
            hunt.cooldowntask:Cancel()
            hunt.cooldowntask = nil
            hunt.cooldowntime = hunt.cooldowntime - dt
            hunt.cooldowntask = inst:DoTaskInTime(hunt.cooldowntime - GetTime(), OnCooldownEnd, hunt)
        end
    end
end

--------------------------------------------------------------------------
--[[ Debug ]]
--------------------------------------------------------------------------

function self:DebugForceHunt()
    if #_activehunts >= GetMaxHunts() then
        local hunt = _activehunts[1]
        StopHunt(hunt)
        StopCooldown(hunt)
        RemoveHunt(hunt)
    end
    StartHunt(0.1)
end

function self:GetDebugString()
    local str = ""
    for i, hunt in ipairs(_activehunts) do
        str = str.." Cooldown: ".. (hunt.cooldowntime and string.format("%2.2f", math.max(1, hunt.cooldowntime - GetTime())) or "-")
		if hunt.trackspawned ~= nil then
			str = str .. " Track # " .. tostring(hunt.trackspawned) .. "/" .. tostring(hunt.numtrackstospawn) .. (hunt.fork_track_num ~= nil and (" fork at " .. tostring(hunt.fork_track_num)) or "") .. (hunt.ambush_track_num ~= nil and (" ambush at " .. tostring(hunt.ambush_track_num)) or "")
		end
        if not hunt.lastdirt then
            str = str.." No last dirt."
            --str = str.." Distance: ".. (playerdata.distance and string.format("%2.2f", playerdata.distance) or "-")
            --str = str.."/"..tostring(TUNING.MIN_HUNT_DISTANCE)
        else
            str = str.." Dirt."
            --str = str.." Distance: ".. (playerdata.distance and string.format("%2.2f", playerdata.distance) or "-")
            --str = str.."/"..tostring(TUNING.MAX_DIRT_DISTANCE)
        end
        str = str .. (hunt.lastdirt_fork and " Fork." or " No fork.")
        str = str .. (hunt.investigatedfork and " Fork investigated." or "")
        str = str .. (hunt.iswrongfork and " WRONG Fork!" or "")
        str = str .. "Score: " .. hunt.score
    end
    return str
end

end)
