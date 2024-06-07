require "behaviours/wander"
require "behaviours/runaway"
require "behaviours/doaction"
require "behaviours/panic"
require "behaviours/follow"

local BrainCommon = require "brains/braincommon"

local SEE_PLAYER_DIST     = 5
local SEE_FOOD_DIST       = 10
local MAX_WANDER_DIST     = 15
local MAX_CHASE_TIME      = 10
local MAX_CHASE_DIST      = 20
local RUN_AWAY_DIST       = 5
local STOP_RUN_AWAY_DIST  = 8

local MIN_FOLLOW_DIST     = 3
local MAX_FOLLOW_DIST     = 15

local SEE_THRONE_DISTANCE = 50

local FACETIME_BASE       = 2
local FACETIME_RAND       = 2

local FIND_SHED_RANGE     = 15

local TRADE_DIST = 20

local DIG_TAGS = { "DIG_workable", "tree" }
local DIG_CANT_TAGS = { "carnivalgame_part", "event_trigger", "waxedplant" }

local MermBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

local function GetHealerFn(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local players = FindPlayersInRange(x, y, z, TRADE_DIST, true)
    for _, v in ipairs(players) do
        if (v == inst.components.follower:GetLeader() or v:HasTag("merm")) and inst.components.combat.target ~= v then
            local act = v:GetBufferedAction()    
            if act
            and act.target == inst
            and act.action == ACTIONS.HEAL then
                return v
            end  
        end
    end     
end

local function KeepHealerFn(inst, target)
    if (target == inst.components.follower:GetLeader() or target:HasTag("merm")) and inst.components.combat.target ~= target then
        local act = target:GetBufferedAction()
        if act
        and act.target == inst
        and act.action == ACTIONS.HEAL then
            return true
        end
    end
end

local function GetTraderFn(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local players = FindPlayersInRange(x, y, z, TRADE_DIST, true)
    for _, v in ipairs(players) do
        if inst.components.trader:IsTryingToTradeWithMe(v) then
            return v
        end  
    end     
end

local function KeepTraderFn(inst, target)
    return inst.components.trader:IsTryingToTradeWithMe(target)
end

local function GetFaceTargetFn(inst)
    if inst.components.timer:TimerExists("dontfacetime") then
        return nil
    end
    local shouldface = inst.components.follower.leader or FindClosestPlayerToInst(inst, SEE_PLAYER_DIST, true)
    if shouldface and not inst.components.timer:TimerExists("facetime") then
        inst.components.timer:StartTimer("facetime", FACETIME_BASE + math.random()*FACETIME_RAND)
    end
    return shouldface
end

local function KeepFaceTargetFn(inst, target)
    if inst.components.timer:TimerExists("dontfacetime") then
        return nil
    end
    local keepface = (inst.components.follower.leader and inst.components.follower.leader == target) or (target:IsValid() and inst:IsNear(target, SEE_PLAYER_DIST))
    if not keepface then
        inst.components.timer:StopTimer("facetime")
    end
    return keepface
end

local EATFOOD_MUST_TAGS = { "edible_VEGGIE" }
local EATFOOD_CANOT_TAGS = { "INLIMBO" }
local SCARY_TAGS = { "scarytoprey" }
local function EatFoodAction(inst)
    if inst.sg:HasStateTag("waking") then
        return
    end

    local target = nil

    if inst.components.inventory ~= nil and inst.components.eater ~= nil then
        target = inst.components.inventory:FindItem(function(item) return item:HasTag("moonglass_piece") or inst.components.eater:CanEat(item) end)
    end

    if target == nil and inst.components.follower.leader == nil then
        target = FindEntity(inst, SEE_FOOD_DIST, function(item) return inst.components.eater:CanEat(item) end, EATFOOD_MUST_TAGS, EATFOOD_CANOT_TAGS)
        --check for scary things near the food
        if target ~= nil and (GetClosestInstWithTag(SCARY_TAGS, target, SEE_PLAYER_DIST) ~= nil or not target:IsOnValidGround()) then  -- NOTE this ValidGround check should be removed if merms start swimming
            target = nil
        end
    end
    if target ~= nil then
        local act = BufferedAction(inst, target, ACTIONS.EAT)
        act.validfn = function() return target.components.inventoryitem == nil or target.components.inventoryitem.owner == nil or target.components.inventoryitem.owner == inst end
        return act
    end
end


-----------------------------------------------------------------------------------------------
-- Merm king things
local function IsThroneValid(inst)
    if TheWorld.components.mermkingmanager then
        local throne = TheWorld.components.mermkingmanager:GetThrone(inst)
        return throne ~= nil
            and throne:IsValid()
            and not (throne.components.burnable ~= nil and throne.components.burnable:IsBurning())
            and not throne:HasTag("burnt")
            and TheWorld.components.mermkingmanager:ShouldGoToThrone(inst, throne)
    end

    return false
end

local GOTOTHRONE_TAGS = { "mermthrone" }
local function ShouldGoToThrone(inst)
    local mermkingmanager = TheWorld.components.mermkingmanager
    if not mermkingmanager then
        return false
    end

    local throne = TheWorld.components.mermkingmanager:GetThrone(inst)
        or FindEntity(inst, SEE_THRONE_DISTANCE, nil, GOTOTHRONE_TAGS)

    return throne ~= nil and TheWorld.components.mermkingmanager:ShouldGoToThrone(inst, throne)
end

local function GetThronePosition(inst)
    if TheWorld.components.mermkingmanager then
        local throne = TheWorld.components.mermkingmanager:GetThrone(inst)
        if throne then
            return throne:GetPosition()
        end
    end
end

-----------------------------------------------------------------------------------------------

local TOOLSHED_ONEOF_TAGS = { "merm_toolshed", "merm_toolshed_upgraded" }

local MERM_TOOL_CANT_TAGS  = { "INLIMBO" }
local MERM_TOOL_ONEOF_TAGS = { "merm_tool", "merm_tool_upgraded" }

local function IsHandEquip(item)
    return item.components.equippable ~= nil and item.components.equippable.equipslot == EQUIPSLOTS.HANDS
end

local function NeedsTool(inst)
    local tool = inst.components.inventory ~= nil and inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) or nil

    if tool ~= nil then
        return false

    elseif inst.components.inventory ~= nil then
        tool = inst.components.inventory:FindItem(IsHandEquip)

        if tool ~= nil then
            return false
        end
    end

    return true
end

local function GetClosestToolShed(inst, dist)
    dist = dist or FIND_SHED_RANGE

    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, 0, z, dist, nil, nil, TOOLSHED_ONEOF_TAGS)

    if #ents <= 0 then
        return nil
    end

    local shed = nil

    for _, ent in ipairs(ents) do
        if ent:CanSupply() then
            if ent:HasTag("merm_toolshed_upgraded") then
                return ent -- High priority.
            end

            shed = ent
        end
    end

    return shed
end

local function GetClosestToolShedPosition(inst, dist)
    local shed = GetClosestToolShed(inst, dist)

    return shed ~= nil and shed:GetPosition() or nil
end

local function NeedsToolAndFoundTool(inst)
    if not NeedsTool(inst) then
        return false
    end

    return GetClosestToolShed(inst) ~= nil
end

local function CollectTool(inst)
    if not NeedsTool(inst) then
        return
    end

    local shed = GetClosestToolShed(inst, 2.2)

    if shed ~= nil then
        inst:PushEvent("merm_use_building", { target = shed })
    end
end

local function PickupTool(inst)
    if inst.sg:HasStateTag("busy") then
        return nil
    end

    if NeedsTool(inst) then
        local x, y, z = inst.Transform:GetWorldPosition()
        local ents = TheSim:FindEntities(x, 0, z, FIND_SHED_RANGE, nil, MERM_TOOL_CANT_TAGS, MERM_TOOL_ONEOF_TAGS)

        if #ents <= 0 then
            return nil
        end

        local tool = nil

        for _, ent in ipairs(ents) do
            if ent:HasTag("merm_tool_upgraded") then
                return BufferedAction(inst, ent, ACTIONS.PICKUP) -- High priority.
            end

            tool = ent
        end

        return tool ~= nil and BufferedAction(inst, tool, ACTIONS.PICKUP) or nil
    end
end

local function HasDigTool(inst)
    local tool = inst.components.inventory ~= nil and inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) or nil

    return tool ~= nil and tool.components.tool ~= nil and tool.components.tool:CanDoAction(ACTIONS.DIG)
end

---------------------------------------------------------------------------------------------------

local function GoHomeAction(inst)
    if inst.components.combat.target ~= nil then
        return
    end

    local home = inst.components.homeseeker ~= nil and inst.components.homeseeker.home or nil

    return home ~= nil
        and home:IsValid()
        and not (home.components.burnable ~= nil and home.components.burnable:IsBurning())
        and not home:HasTag("burnt")
        and BufferedAction(inst, home, ACTIONS.GOHOME)
        or nil
end

local function ShouldGoHome(inst)
    if not TheWorld.state.isday or (inst.components.follower ~= nil and inst.components.follower.leader ~= nil) then
        return false
    end

    -- One merm should stay outside.
    local home = inst.components.homeseeker ~= nil and inst.components.homeseeker.home or nil

    return home == nil
        or home.components.childspawner == nil
        or home.components.childspawner:CountChildrenOutside() > 1
end

local function IsHomeOnFire(inst)
    return inst.components.homeseeker
        and inst.components.homeseeker.home
        and inst.components.homeseeker.home.components.burnable
        and inst.components.homeseeker.home.components.burnable:IsBurning()
end

local function GetNoLeaderHomePos(inst)
    if inst.components.follower and inst.components.follower.leader ~= nil then
        return nil
    else
        return inst.components.knownlocations:GetLocation("home")
    end
end

local function CurrentContestTarget(inst)
    local stage = inst.npc_stage
    return stage.current_contest_target or stage
end

local function MarkPost(inst)
    if inst.yotb_post_to_mark ~= nil then
        return BufferedAction(inst, inst.yotb_post_to_mark, ACTIONS.MARK)
    end
end

local function CollectPrize(inst)
    if inst.yotb_prize_to_collect ~= nil then
        local x,y,z = inst.yotb_prize_to_collect.Transform:GetWorldPosition()
        if y < 0.1 and y > -0.1 and not inst.yotb_prize_to_collect:HasTag("INLIMBO") then
            return BufferedAction(inst, inst.yotb_prize_to_collect, ACTIONS.PICKUP)
        end
    end
end

local function TargetFollowDistFn(inst)
    local loyalty = inst.components.follower ~= nil and inst.components.follower:GetLoyaltyPercent() or 0.5
    local boatmod = inst:GetCurrentPlatform() ~= nil and 0.2 or 1.0
    -- As loyalty rises the further out the follower will potentially stay back.
    -- If on a boat lower max range.
    -- Randomize the range from min to max with the bias modulation.
    return (MAX_FOLLOW_DIST - MIN_FOLLOW_DIST) * (1.0 - loyalty) * boatmod * math.random() + MIN_FOLLOW_DIST
end

function MermBrain:OnStart()
    local in_contest = WhileNode( function() return self.inst:HasTag("NPC_contestant") end, "In contest",
        PriorityNode({
                DoAction(self.inst, CollectPrize, "collect prize", true ),
                DoAction(self.inst, MarkPost, "mark post", true ),
            WhileNode( function() return self.inst.components.timer and self.inst.components.timer:TimerExists("contest_panic") end, "Panic Contest",
                ChattyNode(self.inst, "MERM_TALK_CONTEST_PANIC",
                    Panic(self.inst))),
            ChattyNode(self.inst, "MERM_TALK_CONTEST_OOOH",
                FaceEntity(self.inst, CurrentContestTarget, CurrentContestTarget ), 5, 15),
        }, 0.1))


    local root = PriorityNode(
    {
        IfNode(function() return TheWorld.components.mermkingmanager and TheWorld.components.mermkingmanager.king end, "Panic, With King",
            BrainCommon.PanicWhenScared(self.inst, .25, "MERM_TALK_PANICBOSS_KING")),
        IfNode(function() return not TheWorld.components.mermkingmanager or not TheWorld.components.mermkingmanager.king end, "Panic, With No King",
            BrainCommon.PanicWhenScared(self.inst, .25, "MERM_TALK_PANICBOSS")),
		BrainCommon.PanicTrigger(self.inst),

        ChattyNode(self.inst, "MERM_TALK_GET_HEALED", 
            FaceEntity(self.inst, GetHealerFn, KeepHealerFn)),

        DoAction(self.inst, PickupTool, "collect tool", true ),

        IfNode(function() return NeedsToolAndFoundTool(self.inst) end, "needs a tool",
            PriorityNode({
                Leash(self.inst, GetClosestToolShedPosition , 2.1, 2, true),
                DoAction(self.inst, CollectTool, "collect tool", true ),
            }, 0.25)),

        WhileNode(function() return self.inst.components.combat.target == nil or not self.inst.components.combat:InCooldown() end, "Attack Momentarily",
            ChaseAndAttack(self.inst, SpringCombatMod(MAX_CHASE_TIME), SpringCombatMod(MAX_CHASE_DIST))),
        WhileNode(function() return self.inst.components.combat.target ~= nil and self.inst.components.combat:InCooldown() end, "Dodge",
            RunAway(self.inst, function() return self.inst.components.combat.target end, RUN_AWAY_DIST, STOP_RUN_AWAY_DIST)),

        in_contest,

        ChattyNode(self.inst, "MERM_TALK_FIND_FOOD",
            DoAction(self.inst, EatFoodAction, "Eat Food")), -- NOTES(JBK): Leave this above throne task so the Merm eats the food given.

        WhileNode(function() return ShouldGoToThrone(self.inst) and self.inst.components.combat.target == nil end, "Should Go To Throne",
            PriorityNode({
                Leash(self.inst, GetThronePosition, 0.2, 0.2, true),
                IfNode(function() return IsThroneValid(self.inst) end, "Is Throne Valid",
                    ActionNode(function() self.inst:PushEvent("onarrivedatthrone") end)
                ),
            }, .25)),

        WhileNode(function() return HasDigTool(self.inst) end, "dig stump with tool",
            BrainCommon.NodeAssistLeaderDoAction(self, {
                action = "CHOP", -- Required.
                chatterstring = "MERM_TALK_HELP_CHOP_WOOD",
                starter = function(inst,finddist)
                            local target = FindEntity(inst, finddist, nil, DIG_TAGS, DIG_CANT_TAGS)
                            return inst.stump_target or target or nil
                        end,
                keepgoing = function(inst, leaderdist, finddist)
                            return inst.stump_target ~= nil
                                or (inst.components.follower.leader ~= nil and
                                    inst:IsNear(inst.components.follower.leader, leaderdist))
                        end,
                finder = function(inst, leaderdist, finddist)
                            local target = FindEntity(inst, finddist, nil, DIG_TAGS, DIG_CANT_TAGS)
                            if target == nil and inst.components.follower.leader ~= nil then
                                target = FindEntity(inst.components.follower.leader, finddist, nil, DIG_TAGS, DIG_CANT_TAGS)
                            end
                            if target ~= nil then
                                if inst.stump_target ~= nil then
                                    target = inst.stump_target
                                    inst.stump_target = nil
                                end

                                return BufferedAction(inst, target, ACTIONS.DIG)
                            end
                        end,
            })),

        BrainCommon.NodeAssistLeaderDoAction(self, {
            action = "CHOP", -- Required.
            chatterstring = "MERM_TALK_HELP_CHOP_WOOD",
        }),

        BrainCommon.NodeAssistLeaderDoAction(self, {
            action = "MINE", -- Required.
            chatterstring = "MERM_TALK_HELP_MINE_ROCK",
        }),

        ChattyNode(self.inst, "MERM_TALK_FIND_FOOD", -- TODO(JBK): MERM_TALK_ATTEMPT_TRADE
            FaceEntity(self.inst, GetTraderFn, KeepTraderFn)),

        ChattyNode(self.inst, "MERM_TALK_FOLLOWWILSON",
		    Follow(self.inst, function() return self.inst.components.follower.leader end, MIN_FOLLOW_DIST, TargetFollowDistFn, MAX_FOLLOW_DIST, nil, true)),

        IfNode(function() return self.inst.components.follower.leader ~= nil end, "Has A Leader",
            ChattyNode(self.inst, "MERM_TALK_FOLLOWWILSON",
                FaceEntity(self.inst, GetFaceTargetFn, KeepFaceTargetFn ))),

        WhileNode( function() return IsHomeOnFire(self.inst) end, "Home On Fire", Panic(self.inst)),

        WhileNode(function() return ShouldGoHome(self.inst) end, "Should Go Home",
            DoAction(self.inst, GoHomeAction, "Go Home", true)),

        FaceEntity(self.inst, GetFaceTargetFn, KeepFaceTargetFn),
        Wander(self.inst, GetNoLeaderHomePos, MAX_WANDER_DIST),
    }, .25)

    self.bt = BT(self.inst, root)
end

return MermBrain
