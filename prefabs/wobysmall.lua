local brain = require("brains/wobysmallbrain")

local WAKE_TO_FOLLOW_DISTANCE = 6
local SLEEP_NEAR_LEADER_DISTANCE = 5

local HUNGRY_PERISH_PERCENT = 0.5 -- matches stale tag
local STARVING_PERISH_PERCENT = 0.2 -- matches spoiked tag

local function IsLeaderSleeping(inst)
    return inst.components.follower.leader and inst.components.follower.leader:HasTag("sleeping")
end

local function IsLeaderTellingStory(inst)
    local leader = inst.components.follower.leader
    return leader and leader.components.storyteller and leader.components.storyteller:IsTellingStory()
end

local function ShouldWakeUp(inst)
    return not (IsLeaderSleeping(inst) or IsLeaderTellingStory(inst)) or not inst.components.follower:IsNearLeader(WAKE_TO_FOLLOW_DISTANCE)
end

local function ShouldSleep(inst)
    return (IsLeaderSleeping(inst) or IsLeaderTellingStory(inst)) and inst.components.follower:IsNearLeader(SLEEP_NEAR_LEADER_DISTANCE)
end

-------------------------------------------------------------------------------
local function GetPeepChance(inst)
    local hunger_percent = inst.components.hunger:GetPercent()
    if hunger_percent <= 0 then
        return 0.01
    end

    return 0
end

local function IsAffectionate(inst)
    return true
end

local function IsPlayful(inst)
	return true
end

local function IsSuperCute(inst)
	return true
end

local assets =
{
    Asset("ANIM", "anim/pupington_build.zip"),
    Asset("ANIM", "anim/pupington_basic.zip"),
    Asset("ANIM", "anim/pupington_emotes.zip"),
    Asset("ANIM", "anim/pupington_traits.zip"),
    Asset("ANIM", "anim/pupington_jump.zip"),
    Asset("ANIM", "anim/pupington_action.zip"),

    Asset("ANIM", "anim/pupington_woby_build.zip"),
    Asset("ANIM", "anim/pupington_transform.zip"),
    Asset("ANIM", "anim/woby_big_build.zip"),

    Asset("ANIM", "anim/ui_woby_3x3.zip"),
}

local prefabs = {}

local function LinkToPlayer(inst, player)
    inst._playerlink = player
    inst.components.follower:SetLeader(player)

    inst:ListenForEvent("onremove", inst._onlostplayerlink, player)
    inst:ListenForEvent("performaction", inst._onplayeraction, player)
end

local function OnPlayerLinkDespawn(inst, forcedrop)
	if inst.components.container ~= nil then
		inst.components.container:Close()
		inst.components.container.canbeopened = false

		if forcedrop or GetGameModeProperty("drop_everything_on_despawn") then
			inst.components.container:DropEverything()
		else
			inst.components.container:DropEverythingWithTag("irreplaceable")
		end
	end

	if inst.components.drownable ~= nil then
		inst.components.drownable.enabled = false
	end

	local fx = SpawnPrefab(inst.spawnfx)
	fx.entity:SetParent(inst.entity)

	inst.components.colourtweener:StartTween({ 0, 0, 0, 1 }, 13 * FRAMES, inst.Remove)

	if not inst.sg:HasStateTag("busy") then
		inst.sg:GoToState("despawn")
	end
end

local function FinishTransformation(inst)
    local items = inst.components.container:RemoveAllItems()
	local player = inst._playerlink
    local new_woby = ReplacePrefab(inst, "wobybig")

    for i,v in ipairs(items) do
        new_woby.components.container:GiveItem(v)
    end

	if player ~= nil then
		new_woby:LinkToPlayer(player)
	    player:OnWobyTransformed(new_woby)
	end
end

local function OnOpen(inst)
end

local function OnClose(inst)
end

local function OnStarving(inst)
    -- Critters don't have the health component, so we override the starvefn to prevent a crash
end

local function TriggerTransformation(inst)
    if inst.sg.currentstate.name ~= "transform" then
        inst.persists = false

        if inst.components.container:IsOpen() then
            inst.components.container:Close()
        end

        inst:AddTag("NOCLICK")
        inst:PushEvent("transform")
    end
end

local function OnHungerDelta(inst, data)
    if data.newpercent >= 0.95 then
        TriggerTransformation(inst)
    end
end

----------------------------------------------------------------------------------------------------------------------

-- TODO(DiogoW): Adjust these chances...

local DIGGING_REWARDS =
{
    LOCATIONS =
    {
        FOREST =
        {
            cutgrass = 1,
            twigs = 1,
            petals = 1,
            silk = 1,
            rope = 1,
            seeds = 1,
            purplegem = 1,
            bluegem = 1,
            redgem = 1,
            orangegem = 1,
            yellowgem = 1,
            greengem = 1,
            trinket_6 = 1,
            trinket_4 = 1,
            cutreeds = 1,
            feather_crow = 1,
            feather_robin = 1,
            feather_canary = 1,
            trinket_3 = 1,
            beefalowool = 1,
            butterflywings = 1,
            berries = 1,
            blueprint = 1,
            petals_evil = 1,
            trinket_8 = 1,
            houndstooth = 1,
            stinger = 1,
            gears = 1,
            boneshard = 1,
            coontail = 1,
            transistor = 1,
            charcoal = 1,
            flint = 1,
            goldnugget = 1,
            nitre = 1,
            log = 1,
            rocks = 1,
            marble = 1,
            pinecone = 1,
            wagpunk_bits = 1,
            spidergland = 1,
            steelwool = 1,
            shovel = 1,
            panflute = 1,
            pickaxe = 1,
            axe = 1,
            twiggy_nut = 1,
            carrot = 1,
            bird_egg = 1,
            smallmeat = 1,
            rottenegg = 1,
        },

        CAVES = {
            cutgrass = 1,
            twigs = 1,
            silk = 1,
            rope = 1,
            purplegem = 1,
            bluegem = 1,
            redgem = 1,
            orangegem = 1,
            yellowgem = 1,
            greengem = 1,
            trinket_6 = 1,
            trinket_4 = 1,
            trinket_3 = 1,
            blueprint = 1,
            trinket_8 = 1,
            gears = 1,
            boneshard = 1,
            transistor = 1,
            charcoal = 1,
            flint = 1,
            goldnugget = 1,
            nitre = 1,
            log = 1,
            rocks = 1,
            marble = 1,
            pinecone = 1,
            wagpunk_bits = 1,
            spidergland = 1,
            shovel = 1,
            panflute = 1,
            pickaxe = 1,
            axe = 1,

            snurtle_shellpieces = 1,
            thulecite = 1,
            thulecite_pieces = 1,
            slurtleslime = 1,
            multitool_axe_pickaxe = 1,
            foliage = 1,
            batwing = 1,
            manrabbit_tail = 1,
            blue_cap = 1,
            red_cap = 1,
            green_cap = 1,
            wormlight = 1,
            cutlichen = 1,
        },
    },

    SEASONS =
    {
        [SEASONS.AUTUMN] =
        {
            furtuft = 1,
        },

        [SEASONS.WINTER] =
        {
            feather_robin_winter = 1,
            beard_hair = 1,
            walrus_tusk = 1,
        },

        [SEASONS.SPRING] =
        {
            goose_feather = 1,
            lureplantbulb = 1,
            lightninggoathorn = 1,
        },

        [SEASONS.SUMMER] =
        {

        },
    },
}

local function GetDiggingReward(inst)
    local tuning = TUNING.SKILLS.WALTER.WOBY_DIGGING_LOOT_CHANCE
    local chance = tuning.min

    local dogtrainer = inst._playerlink ~= nil and inst._playerlink.components.dogtrainer or nil

    if dogtrainer ~= nil then
        local pct = dogtrainer:GetAspectPercent(WOBY_TRAINING_ASPECTS.DIGGING)

        chance = tuning.min + (tuning.max - tuning.min) * pct
    end

    if math.random() > chance then
        return -- No reward!
    end

    local location = DIGGING_REWARDS.LOCATIONS[string.upper(TheWorld.worldprefab)] or DIGGING_REWARDS.LOCATIONS.FOREST
    local season = not TheWorld:HasTag("cave") and DIGGING_REWARDS.SEASONS[TheWorld.state.season] or nil -- No season related loot for caves.

    local choices = season ~= nil and MergeMaps(location, season) or location

    return weighted_random_choice(choices)
end

local function SpawnDiggingReward(inst)
    local reward = inst:GetDiggingReward()

    if reward == nil then
        return
    end

    reward = SpawnPrefab(reward)

    if reward == nil then
        return
    end

    reward.Transform:SetPosition(inst.Transform:GetWorldPosition())

    Launch(reward, inst, 1)

    return reward
end

local function OnPlayerAction(inst, data)
    inst._lastleaderaction = data.action -- Used in the brain!
end

----------------------------------------------------------------------------------------------------------------------

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddDynamicShadow()
    inst.entity:AddNetwork()

    inst.DynamicShadow:SetSize(1, .33)
    inst.Transform:SetFourFaced()

    inst.AnimState:SetBank("pupington")
    inst.AnimState:SetBuild("pupington_woby_build")
    inst.AnimState:PlayAnimation("idle_loop")

    -- FIXME(DiogoW): it might be better to just have these in the pupington_action file.
    inst.AnimState:OverrideSymbol("dirt_base", "mole_build", "dirt_base")
    inst.AnimState:OverrideSymbol("wormmovefx", "mole_build", "wormmovefx")
    inst.AnimState:OverrideSymbol("hill", "mole_build", "hill")

    MakeCharacterPhysics(inst, 1, .5)

    -- critters dont really go do entitysleep as it triggers a teleport to near the owner, so no point in hitting the physics engine.
	inst.Physics:SetDontRemoveOnSleep(true)

    inst:AddTag("critter")
    inst:AddTag("fedbyall")
    inst:AddTag("companion")
    inst:AddTag("notraptrigger")
    inst:AddTag("noauradamage")
    inst:AddTag("small_livestock")
    inst:AddTag("noabandon")
    inst:AddTag("NOBLOCK")

    inst:AddComponent("spawnfader")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

	inst.favoritefood = "monsterlasagna"

    inst.GetPeepChance = GetPeepChance
    inst.IsAffectionate = IsAffectionate
    inst.IsSuperCute = IsSuperCute
    inst.IsPlayful = IsPlayful

	inst.playmatetags = {"critter"}

    inst:AddComponent("inspectable")

    inst:AddComponent("follower")
    inst.components.follower:KeepLeaderOnAttacked()
    inst.components.follower.keepdeadleader = true
    inst.components.follower.keepleaderduringminigame = true

    inst:AddComponent("knownlocations")

    inst:AddComponent("sleeper")
    inst.components.sleeper:SetResistance(3)
    inst.components.sleeper.testperiod = GetRandomWithVariance(6, 2)
    inst.components.sleeper:SetSleepTest(ShouldSleep)
    inst.components.sleeper:SetWakeTest(ShouldWakeUp)

    inst:AddComponent("eater")
    inst.components.eater:SetDiet({ FOODTYPE.MONSTER }, { FOODTYPE.MONSTER })

    inst:AddComponent("hunger")
    inst.components.hunger:SetMax(TUNING.WOBY_SMALL_HUNGER)
    inst.components.hunger:SetRate(TUNING.WOBY_SMALL_HUNGER_RATE)
    inst.components.hunger:SetOverrideStarveFn(OnStarving)
    inst.components.hunger:SetPercent(0)

    inst:AddComponent("locomotor")
    inst.components.locomotor:EnableGroundSpeedMultiplier(true)
    inst.components.locomotor:SetTriggersCreep(false)
    inst.components.locomotor.softstop = true
    inst.components.locomotor.walkspeed = TUNING.CRITTER_WALK_SPEED

    inst.components.locomotor:SetAllowPlatformHopping(true)

    inst:AddComponent("embarker")
    inst.components.embarker.embark_speed = inst.components.locomotor.walkspeed
    inst:AddComponent("drownable")

	inst:AddComponent("colourtweener")

    inst:AddComponent("crittertraits")
    inst:AddComponent("timer")

    inst:AddComponent("container")
    inst.components.container:WidgetSetup("wobysmall")
    inst.components.container.onopenfn = OnOpen
    inst.components.container.onclosefn = OnClose

    inst:SetBrain(brain)
    inst:SetStateGraph("SGwobysmall")

    inst:ListenForEvent("hungerdelta", OnHungerDelta)

    inst.LinkToPlayer = LinkToPlayer
	inst.OnPlayerLinkDespawn = OnPlayerLinkDespawn
	inst._onlostplayerlink = function(player) inst._playerlink = nil end
	inst._onplayeraction = function(player, data) OnPlayerAction(inst, data) end

    inst.FinishTransformation = FinishTransformation
    inst.GetDiggingReward = GetDiggingReward
    inst.SpawnDiggingReward = SpawnDiggingReward

    inst.persists = false

	inst.spawnfx = "spawn_fx_small"

    return inst
end

return Prefab("wobysmall", fn, assets, prefabs)