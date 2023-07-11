require "behaviours/doaction"
require "behaviours/faceentity"
require "behaviours/leash"
require "behaviours/panic"
require "behaviours/runaway"
require "behaviours/wander"

local AVOID_PLAYER_DIST = 3
local AVOID_PLAYER_DIST_SQ = AVOID_PLAYER_DIST * AVOID_PLAYER_DIST
local AVOID_PLAYER_STOP = 5

local SEE_BAIT_DIST = 20
local MAX_WANDER_DIST = 20

local RACE_WANDER_DURATION = 3.5
local RACE_WANDER_MAX_DIST = 50
local RACE_WANDER_TIMES = {minwalktime=.5, randwalktime=0.25, minwaittime=0.0, randwaittime=0.0}
local RACE_WANDER_DATA = {
	should_run = function(inst) return inst.components.yotc_racestats == nil or inst.components.yotc_racestats:GetSpeedModifier() > 0 end,
	wander_dist = function(inst) return math.max(2, (inst.components.yotc_racecompetitor ~= nil and inst.components.yotc_racecompetitor.next_checkpoint) and (math.sqrt(inst:GetDistanceSqToInst(inst.components.yotc_racecompetitor.next_checkpoint)) - 1) or 50) end,
}

local CarratBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

local function racing_get_checkpoint(inst)
    return inst.components.yotc_racecompetitor ~= nil and inst.components.yotc_racecompetitor.next_checkpoint or nil
end

local function racing_get_checkpoint_pt(inst)

    if inst.components.yotc_racestats == nil or inst.components.yotc_racestats:GetSpeedModifier() == 0 and not inst.components.yotc_racecompetitor.walkspeechdone then
        inst.components.yotc_racecompetitor.walkspeechdone = true
        inst:PushEvent("carrat_error_walking")
    end

	local dest = racing_get_checkpoint(inst)
	return dest ~= nil and dest:GetPosition() or nil
end

local function get_race_direction(inst)
	local dest = racing_get_checkpoint_pt(inst)
    if not dest then
        return nil
    end

	local pt = inst:GetPosition()

	local direction_stat = inst.components.yotc_racestats ~= nil and inst.components.yotc_racestats:GetDirectionModifier() or 0
	local delta_heading = Lerp(TUNING.YOTC_RACER_DIRECTION_BAD, TUNING.YOTC_RACER_DIRECTION_GOOD, direction_stat)

	local dir = dest - pt
	local dist = dir:Length()
	local heading = -math.atan2(dir.z, dir.x)

	local r = math.random() * 2 - 1
	return heading + (r * delta_heading * DEGREES)
end

local function is_racecompetitor(inst)
    return inst.components.yotc_racecompetitor ~= nil
end

local function is_waiting_for_race_to_start(inst)
	return inst.components.yotc_racecompetitor ~= nil and inst.components.yotc_racecompetitor.racestate == "prerace"
end

local function get_trainer(inst)
    return (inst.components.entitytracker ~= nil and inst.components.entitytracker:GetEntity("yotc_trainer")) or nil
end

local function get_nearby_trainer_pt(inst)
    local trainer = get_trainer(inst)
    if trainer ~= nil then
        if inst:IsNear(trainer, TUNING.YOTC_RACER_TRAINER_DIST) then
            return trainer:GetPosition()
        end
    end
    return nil
end

local function edible(inst, item)
    return inst.components.eater ~= nil and inst.components.eater:CanEat(item) and item.components.bait and not item:HasTag("planted") and
            not (item.components.inventoryitem and item.components.inventoryitem:IsHeld()) and
            item:IsOnPassablePoint() and
            item:GetCurrentPlatform() == inst:GetCurrentPlatform()
end

local function gather_food_action(inst)
    if not inst or not inst:IsValid() then
        return nil
    end

    local px, py, pz = inst.Transform:GetWorldPosition()

    local ents_nearby = TheSim:FindEntities(px, py, pz, SEE_BAIT_DIST + AVOID_PLAYER_DIST)

    local foods = {}
    local scaries = {}
    for _, ent in ipairs(ents_nearby) do
        if ent ~= inst and ent.entity:IsVisible() and ent:IsValid() then
            if ent:HasTag("scarytoprey") and not ent:HasTag("carratcrafter") and ent ~= inst._creator then
                table.insert(scaries, ent)
            elseif edible(inst, ent) and (inst._creator == nil or not (inst._creator:IsValid() and ent:IsNear(inst._creator, 5))) then
                table.insert(foods, ent)
            end
        end
    end

    if #foods == 0 then
        return nil
    end

    local target = nil
    if #scaries == 0 then
        target = foods[1]
    else
        -- We have at least 1 food and at least 1 scary thing in range.
        -- Try to find a food that doesn't come within AVOID_PLAYER_DIST of a scary thing.
        for fi = 1, #foods do
            local food = foods[fi]
            local scary_thing_nearby = false

            for si = 1, #scaries do
                local scary_thing = scaries[si]
                if scary_thing ~= nil and scary_thing:IsValid() and scary_thing.Transform ~= nil then
                    local sq_distance = food:GetDistanceSqToPoint(scary_thing.Transform:GetWorldPosition())
                    if sq_distance < AVOID_PLAYER_DIST_SQ then
                        scary_thing_nearby = true
                        break
                    end
                end
            end

            if not scary_thing_nearby then
                target = food
                break
            end
        end
    end

    if target then
        local act
        if inst._creator and inst._creator:IsValid() then -- If we were spawned, don't eat things! It's not nice.
            if not inst.components.timer:TimerExists("mutantproxy_food_gathering") and not inst.components.inventory:IsFull() then
                act = BufferedAction(inst, target, ACTIONS.PICKUP)
            end
        else
            act = BufferedAction(inst, target, ACTIONS.EAT)
        end

        if act then
            act.validfn = function() return not (target.components.inventoryitem and target.components.inventoryitem:IsHeld()) end
            return act
        end
    end
end

local function drop_item_action(inst)
    local creator = inst._creator
    local item = inst.components.inventory:GetFirstItemInAnySlot() 
    if item then
        if inst.components.timer:TimerExists("mutantproxy_food_gathering") then
            inst.components.timer:SetTimeLeft("mutantproxy_food_gathering", TUNING.WORMWOOD_CARRAT_GATHER_COOLDOWN)
        else
            inst.components.timer:StartTimer("mutantproxy_food_gathering", TUNING.WORMWOOD_CARRAT_GATHER_COOLDOWN)
        end

        local ba = BufferedAction(inst, creator, ACTIONS.DROP, item)
        ba.options.wholestack = true
        return ba
    end
end

local BEEFALO_MUST_TAGS = {"beefalo"}
local BEEFALO_CANT_TAGS = {"baby","HasCarrat"}

local function returntobeefalo(inst)
    if inst.beefalo_carrat then
        local target = nil

        local x,y,z = inst.Transform:GetWorldPosition()
        local ents = TheSim:FindEntities(x, y, z, 20, BEEFALO_MUST_TAGS, BEEFALO_CANT_TAGS)
        if #ents > 0 then
            target = ents[1]
        end
        if target then
            return BufferedAction(inst, target, ACTIONS.GOHOME)
        end
    end
end

local function GetCreatorLocation(inst)
    if inst._creator ~= nil and inst._creator:IsValid() and inst:IsNear(inst._creator, 35) then
        return inst._creator:GetPosition()
    else
        return nil
    end
end

local function not_my_creator(other, inst)
    return (other ~= nil) and (other ~= inst._creator)
end

local RACE_RUNAWAY_DATA = {tags = {"scarytoprey"}, notags = {"character", "carratcrafter"}, fn = not_my_creator}
local NORMAL_RUNAWAY_DATA = {tags = {"scarytoprey"}, notags = {"carratcrafter"}, fn = not_my_creator}
function CarratBrain:OnStart()
    local race_brain = WhileNode( function() return is_racecompetitor(self.inst) end, "Is Racing",
        PriorityNode({
			RunAway(self.inst, RACE_RUNAWAY_DATA, AVOID_PLAYER_DIST, AVOID_PLAYER_STOP, nil, nil, true),

			WhileNode( function() return is_waiting_for_race_to_start(self.inst) end, "Pre-Race",
                PriorityNode({
                    Leash(self.inst, racing_get_checkpoint_pt, 2.5, 1.5, true),
                    FaceEntity(self.inst, racing_get_checkpoint, racing_get_checkpoint),
					StandStill(self.inst),
                }, 0.1)
            ),
			WhileNode( function() return self.inst.components.yotc_racecompetitor ~= nil and self.inst.components.yotc_racecompetitor.racestate == "postrace" end, "Post-Race",
                PriorityNode({
					Leash(self.inst, racing_get_checkpoint_pt, 2.5, 1.25, true),
					FaceEntity(self.inst, get_trainer, get_trainer),
					StandStill(self.inst),
                }, 0.1)
            ),
			WhileNode( function() return self.inst.components.yotc_racecompetitor ~= nil and self.inst.components.yotc_racecompetitor.racestate == "raceover" end, "Race-Over",
                PriorityNode({
                    Leash(self.inst, get_nearby_trainer_pt, 2.5, 1.25, true),
                    IfNode(function() return get_nearby_trainer_pt(self.inst) == nil end, "Trainer Is Not Nearby",
                        Leash(self.inst, racing_get_checkpoint_pt, 2.5, 1.25, true)
                    ),
                    FaceEntity(self.inst, get_trainer, get_trainer),
					StandStill(self.inst),
                }, 0.1)
            ),
			WhileNode( function() return self.inst.components.yotc_racecompetitor ~= nil and self.inst.components.yotc_racecompetitor.racestate == "racing" end, "Racing",
                PriorityNode({
					WhileNode( function() return self.inst.components.yotc_racecompetitor ~= nil and self.inst.components.yotc_racecompetitor:IsStartingLate() end, "PanicRaceStart",
						Panic(self.inst)),
					Wander(self.inst, function() return racing_get_checkpoint_pt(self.inst) end, RACE_WANDER_MAX_DIST, RACE_WANDER_TIMES, get_race_direction, nil, nil, RACE_WANDER_DATA)
                }, 0.1)
            ),
            -- Rest of race behaviour
        }, 0.1)
    )

    local root = PriorityNode(
    {
        WhileNode( function() return (self.inst.components.health ~= nil and self.inst.components.health.takingfiredamage) or (self.inst.components.burnable ~= nil and self.inst.components.burnable:IsBurning()) end, "OnFire",
			Panic(self.inst)),

        race_brain,

        WhileNode( function() return self.inst.components.hauntable and self.inst.components.hauntable.panic end, "PanicHaunted",
			Panic(self.inst)),

        RunAway(self.inst, NORMAL_RUNAWAY_DATA, AVOID_PLAYER_DIST, AVOID_PLAYER_STOP),
        DoAction(self.inst, gather_food_action, "gather food"),
        WhileNode(function() return self.inst._creator ~= nil end, "Has Creator",
            PriorityNode({
                WhileNode(function() return self.inst.components.inventory:GetFirstItemInAnySlot() ~= nil end, "Has Any Item",
                    DoAction(self.inst, drop_item_action, "Drop Item For Creator", true, 0.5*TUNING.WORMWOOD_CARRAT_GATHER_COOLDOWN)
                ),
                Leash(self.inst, GetCreatorLocation, 40, 8, true),
            }, .25)
        ),
        DoAction(self.inst, returntobeefalo, "go home"),
        Wander(self.inst, GetCreatorLocation, MAX_WANDER_DIST),
    }, .25)
    self.bt = BT(self.inst, root)
end

return CarratBrain
