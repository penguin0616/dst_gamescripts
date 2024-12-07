require "behaviours/follow"
require "behaviours/wander"
require "behaviours/faceentity"
require "behaviours/panic"
require "behaviours/leash"

local BrainCommon = require "brains/braincommon"

local TARGET_FOLLOW_DIST = 4
local MAX_FOLLOW_DIST = 4.5

local COMBAT_TOO_CLOSE_DIST = 5                 -- distance for find enitities check
local COMBAT_TOO_CLOSE_DIST_SQ = COMBAT_TOO_CLOSE_DIST * COMBAT_TOO_CLOSE_DIST
local COMBAT_SAFE_TO_WATCH_FROM_DIST = 8        -- will run to this distance and watch if was too close
local COMBAT_SAFE_TO_WATCH_FROM_MAX_DIST = 12   -- combat is quite far away now, better catch up
local COMBAT_SAFE_TO_WATCH_FROM_MAX_DIST_SQ = COMBAT_SAFE_TO_WATCH_FROM_MAX_DIST * COMBAT_SAFE_TO_WATCH_FROM_MAX_DIST
local COMBAT_TIMEOUT = 6

local MAX_PLAYFUL_FIND_DIST = 4
local MAX_PLAYFUL_KEEP_DIST_FROM_OWNER = 6
local MAX_DOMINANTTRAIT_PLAYFUL_FIND_DIST = 6
local MAX_DOMINANTTRAIT_PLAYFUL_KEEP_DIST_FROM_OWNER = 9
local PLAYFUL_OFFSET = 2

local function GetOwner(inst)
    return inst.components.follower.leader
end

local function KeepFaceTargetFn(inst, target)
    return inst.components.follower.leader == target
end

local function OwnerIsClose(inst, distance)
    local owner = GetOwner(inst)

    return owner ~= nil and owner:IsNear(inst, distance or MAX_FOLLOW_DIST)
end

local function LoveOwner(inst)
    if inst.sg:HasStateTag("busy") then
        return nil
    end

    local owner = GetOwner(inst)
    return owner ~= nil
        and not owner:HasTag("playerghost")
        and (GetTime() - (inst.sg.mem.prevnuzzletime or 0) > TUNING.CRITTER_NUZZLE_DELAY)
        and math.random() < 0.05
        and BufferedAction(inst, owner, ACTIONS.NUZZLE)
        or nil
end

-------------------------------------------------------------------------------
--  Play With Other Critters
local PLAYMATE_NO_TAGS = {"busy"}
local function PlayWithPlaymate(self)
    self.inst:PushEvent("start_playwithplaymate", {target=self.playfultarget})
end

local function TargetCanPlay(self, target, owner, max_dist_from_owner, is_flier)
	return (target.IsPlayful == nil or target:IsPlayful()) 
			and target:IsNear(owner, max_dist_from_owner) 
			and (is_flier or target:IsOnPassablePoint())
			and (target.components.sleeper == nil or not target.components.sleeper:IsAsleep())
end

local function FindPlaymate(self)
    local owner = GetOwner(self.inst)

    local is_playful = self.inst.components.crittertraits:IsDominantTrait("playful")
    local max_dist_from_owner = is_playful and MAX_DOMINANTTRAIT_PLAYFUL_KEEP_DIST_FROM_OWNER or MAX_PLAYFUL_KEEP_DIST_FROM_OWNER
    local is_flier = self.inst:HasTag("flying")

    local can_play = self.inst:IsPlayful() and self.inst:IsNear(owner, max_dist_from_owner)

    -- Try to keep the current playmate
    if self.playfultarget ~= nil and self.playfultarget:IsValid() and can_play and TargetCanPlay(self, self.playfultarget, owner, max_dist_from_owner, is_flier) then
        return true
    end

    local find_dist = is_playful and MAX_DOMINANTTRAIT_PLAYFUL_FIND_DIST or MAX_PLAYFUL_FIND_DIST

    -- Find a new playmate
    self.playfultarget = can_play and
        not owner.components.locomotor:WantsToMoveForward() and
        FindEntity(self.inst, find_dist,
            function(v)
                return TargetCanPlay(self, v, owner, max_dist_from_owner, is_flier)
            end, nil, PLAYMATE_NO_TAGS, self.inst.playmatetags)
        or nil

    return self.playfultarget ~= nil
end

-------------------------------------------------------------------------------
--  Combat Avoidance

local function _avoidtargetfn(self, target)
    if target == nil or not target:IsValid() then
        return false
    end

    local owner = self.inst.components.follower.leader
    local owner_combat = owner ~= nil and owner.components.combat or nil
    local target_combat = target.components.combat
    if owner_combat == nil or target_combat == nil then
        return false
    elseif target_combat:TargetIs(owner)
        or (target.components.grouptargeter ~= nil and target.components.grouptargeter:IsTargeting(owner)) then
        return true
    end

    local distsq = owner:GetDistanceSqToInst(target)
    if distsq >= COMBAT_SAFE_TO_WATCH_FROM_MAX_DIST_SQ then
        -- Too far
        return false
    elseif distsq < COMBAT_TOO_CLOSE_DIST_SQ and target_combat:HasTarget() then
        -- Too close to any combat
        return true
    end

    -- Is owner in combat with target?
    -- Are owner and target both in any combat?
    local t = GetTime()
    return  (   (owner_combat:IsRecentTarget(target) or target_combat:HasTarget()) and
                math.max(owner_combat.laststartattacktime or 0, owner_combat.lastdoattacktime or 0) + COMBAT_TIMEOUT > t
            ) or
            (   owner_combat.lastattacker == target and
                owner_combat:GetLastAttackedTime() + COMBAT_TIMEOUT > t
            )
end

local function CombatAvoidanceFindEntityCheck(self)
    return function(ent)
            if _avoidtargetfn(self, ent) then
                self.inst:PushEvent("critter_avoidcombat", {avoid=true})
                self.runawayfrom = ent
                return true
            end
            return false
        end
end

local function ValidateCombatAvoidance(self)
    if self.runawayfrom == nil then
        return false
    end

    if not self.runawayfrom:IsValid() then
        self.inst:PushEvent("critter_avoidcombat", {avoid=false})
        self.runawayfrom = nil
        return false
    end

    if not self.inst:IsNear(self.runawayfrom, COMBAT_SAFE_TO_WATCH_FROM_MAX_DIST) then
        return false
    end

    if not _avoidtargetfn(self, self.runawayfrom) then
        self.inst:PushEvent("critter_avoidcombat", {avoid=false})
        self.runawayfrom = nil
        return false
    end

    return true
end

--- Minigames
local function WatchingMinigame(inst)
	return (inst.components.follower.leader ~= nil and inst.components.follower.leader.components.minigame_participator ~= nil) and inst.components.follower.leader.components.minigame_participator:GetMinigame() or nil
end
local function WatchingMinigame_MinDist(inst)
	local minigame = WatchingMinigame(inst)
	return minigame ~= nil and minigame.components.minigame.watchdist_min or 0
end
local function WatchingMinigame_TargetDist(inst)
	local minigame = WatchingMinigame(inst)
	return minigame ~= nil and minigame.components.minigame.watchdist_target or 0
end
local function WatchingMinigame_MaxDist(inst)
	local minigame = WatchingMinigame(inst)
	return minigame ~= nil and minigame.components.minigame.watchdist_max or 0
end

-------------------------------------------------------------------------------

-- Skill tree skills

local function AddTrainingBonus(inst, value, aspect)
    local badge_fmt = string.upper(aspect).."_%d"

    local bonus = 0

    local dogtrainer = inst._playerlink ~= nil and inst._playerlink.components.dogtrainer or nil

    if dogtrainer ~= nil then
        local pct = dogtrainer:GetAspectPercent(aspect)
        local tuning = TUNING.SKILLS.WALTER.WOBY_BADGES

        local badge

        for i=1, NUM_WOBY_TRAINING_ASPECTS_LEVELS do
            badge = badge_fmt:format(i)

            if tuning[badge] ~= nil and dogtrainer:HasBadge(badge) then
                bonus = bonus + tuning[badge] * pct
            end
        end
    end

    return value + bonus
end

local function ShouldDigGround(inst, brain)
    local dogtrainer = inst._playerlink ~= nil and inst._playerlink.components.dogtrainer or nil

    if dogtrainer == nil or not dogtrainer:HasBadgeOfAspect(WOBY_TRAINING_ASPECTS.DIGGING) then
        brain.digging_pos = nil

        return false
    end

    if inst.components.timer:TimerExists("diggingcooldown") then
        brain.digging_pos = nil

        return false
    end

    if inst:GetCurrentPlatform() ~= nil then
        brain.digging_pos = nil

        return false
    end

    return brain.digging_pos ~= nil or OwnerIsClose(inst, 7)
end

local function CanDigPoint(pt)
    return not TheWorld.Map:IsPointNearHole(pt) and TheWorld.Map:CanPlantAtPoint(pt:Get())
end

local function GetDiggingPosition(inst)
    if inst.brain.digging_pos then
        return inst.brain.digging_pos
    end

    local distance = TUNING.SKILLS.WALTER.WOBY_DIGGING_DISTANCE
    local pos = inst:GetPosition()

    local offset = FindWalkableOffset(pos, math.random() * TWOPI, GetRandomMinMax(distance.min, distance.max), 10, nil, nil, CanDigPoint)

    inst.brain.digging_pos = offset ~= nil and (pos + offset) or pos

    if not CanDigPoint(inst.brain.digging_pos) then
        inst.brain.digging_pos = nil
    end

    return inst.brain.digging_pos
end

-----------------------------------------------------------------------------------------------------------------------------------

local function DoPickUpAction(inst)
    local dogtrainer = inst._playerlink ~= nil and inst._playerlink.components.dogtrainer or nil

    if dogtrainer == nil or not dogtrainer:HasBadgeOfAspect(WOBY_TRAINING_ASPECTS.FETCHING) then
        return
    end

    if inst.components.timer:TimerExists("fetchingcooldown") then
        return
    end

    if inst.components.container:IsEmpty() then
        return
    end

    ------------------------------------------------------------------------

    local distance = AddTrainingBonus(inst, TUNING.SKILLS.WALTER.WOBY_FETCHING_ASSIST_DISTANCE, WOBY_TRAINING_ASPECTS.FETCHING)


    local onlytheseprefabs = {}
    local items = inst.components.container:GetAllItems()

    for i, item in ipairs(items) do
        if not (item.components.stackable == nil or item.components.stackable:IsFull()) then
            onlytheseprefabs[item.prefab] = true
        end
    end

    local item, pickable = FindPickupableItem(inst._playerlink, distance, true, inst:GetPosition(), nil, onlytheseprefabs, false, inst)

    if item == nil then
        item, pickable = FindPickupableItem(inst._playerlink, distance, true, nil, nil, onlytheseprefabs, false, inst)
    end

    if item == nil then
        return nil
    end

    if item ~= nil then
        return BufferedAction(inst, item, ACTIONS.WOBY_PICKUP)
    end
end

-------------------------------------------------------------------------------

local function IsTryingToPerformAction(inst, performer, action)
    local act = performer.components.locomotor.bufferedaction--performer:GetBufferedAction()
    return act ~= nil and act.target == inst and act.action == action
end

local function TryingToInteractWithWoby(inst, performer)
    local interactions = { ACTIONS.FEED, ACTIONS.RUMMAGE, ACTIONS.STORE }
    for _, action in ipairs(interactions) do
        if IsTryingToPerformAction(inst, performer, action) then
            return true
        end
    end

    if inst.components.container:IsOpenedBy(performer) then
        return true
    end

    return false
end

local function GetWalterInteractionFn(inst)
   local leader = inst.components.follower ~= nil and inst.components.follower.leader
    if leader ~= nil and TryingToInteractWithWoby(inst, leader) then
        return leader
    end

    return nil
end

local function KeepGenericInteractionFn(inst, target)
    return TryingToInteractWithWoby(inst, target)
end

-------------------------------------------------------------------------------

--  Brain

local WobySmallBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

function WobySmallBrain:OnStart()
	local watch_game = WhileNode( function() return WatchingMinigame(self.inst) end, "Watching Game",
        PriorityNode{
				Follow(self.inst, WatchingMinigame, WatchingMinigame_MinDist, WatchingMinigame_TargetDist, WatchingMinigame_MaxDist),
				RunAway(self.inst, "minigame_participator", 5, 7),
				FaceEntity(self.inst, WatchingMinigame, WatchingMinigame ),
        }, 0.1)

    local main_nodes = PriorityNode{
        watch_game,
        -- Combat Avoidance
        PriorityNode{
            RunAway(self.inst, {tags={"_combat", "_health"}, notags={"wall", "INLIMBO"}, fn=CombatAvoidanceFindEntityCheck(self)}, COMBAT_TOO_CLOSE_DIST, COMBAT_SAFE_TO_WATCH_FROM_DIST),
            WhileNode( function() return ValidateCombatAvoidance(self) end, "Is Near Combat",
                FaceEntity(self.inst, GetOwner, KeepFaceTargetFn)),
        },

        FaceEntity(self.inst, GetWalterInteractionFn, KeepGenericInteractionFn),

        DoAction(self.inst, DoPickUpAction, "Do Pick Up act"),

        WhileNode(function() return ShouldDigGround(self.inst, self) end, "Dig Ground",
            PriorityNode({
                FailIfSuccessDecorator(Leash(self.inst, GetDiggingPosition, 1.5, 1, true)),
                ActionNode(function()
                    if self.digging_pos ~= nil then
                        self.inst:PushEvent("dig_ground")
                    end
                end),
            }, 0.5)
        ),
        WhileNode(function() return FindPlaymate(self) end, "Playful",
            SequenceNode{
                WaitNode(6),
                PriorityNode{
                    Leash(self.inst, function() return self.playfultarget:GetPosition() end, PLAYFUL_OFFSET, PLAYFUL_OFFSET),
                    ActionNode(function() PlayWithPlaymate(self) end),
                    StandStill(self.inst),
                },
            }),
        Follow(self.inst, function() return self.inst.components.follower.leader end, 0, TARGET_FOLLOW_DIST, MAX_FOLLOW_DIST),
        FailIfRunningDecorator(FaceEntity(self.inst, GetOwner, KeepFaceTargetFn)),
        WhileNode(function() return OwnerIsClose(self.inst) and self.inst:IsAffectionate() end, "Affection",
            SequenceNode{
                WaitNode(4),
                DoAction(self.inst, LoveOwner),
            }),
        StandStill(self.inst),
    }

    local root = PriorityNode({
        WhileNode(
            function()
                return not self.inst.sg:HasStateTag("jumping")
            end,
            "<busy state guard>",
            PriorityNode({
                WhileNode(function() return GetOwner(self.inst) ~= nil end, "Has Owner", main_nodes),
                StandStill(self.inst),
            }, .25)
        ),
    }, .25)

    self.bt = BT(self.inst, root)
end

return WobySmallBrain
