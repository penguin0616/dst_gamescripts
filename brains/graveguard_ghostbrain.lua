require "behaviours/follow"
require "behaviours/wander"

local GraveGuardBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

local function IsAlive(target)
    return target.entity:IsVisible() and
        target.components.health ~= nil and
        not target.components.health:IsDead()
end

local TARGET_CANT_TAGS = { "INLIMBO", "noauradamage" }
local TARGET_ONEOF_TAGS = { "character", "monster" }

local function GetFollowTarget(ghost)
    local incoming_followtarget = ghost.brain.followtarget
    if incoming_followtarget ~= nil
        and (not incoming_followtarget:IsValid() or
            not incoming_followtarget.entity:IsVisible() or
            incoming_followtarget:IsInLimbo() or
            incoming_followtarget.components.health == nil or
            incoming_followtarget.components.health:IsDead() or
            ghost:GetDistanceSqToInst(incoming_followtarget) > TUNING.GHOST_FOLLOW_DSQ) then

        ghost.brain.followtarget = nil
    end

    if not ghost.brain.followtarget then
        local gx, gy, gz = ghost.Transform:GetWorldPosition()
        local potential_followtargets = TheSim:FindEntities(gx, gy, gz, 10, nil, TARGET_CANT_TAGS, TARGET_ONEOF_TAGS)
        for _, pft in ipairs(potential_followtargets) do
            -- We should only follow living characters.
            if IsAlive(pft) then
                -- If a character is ghost-friendly OR a player, don't immediately target them, unless they're targeting us.
                -- Actively target anybody else.
                local graveguard_friendly = pft.isplayer or pft:HasTag("ghostlyfriend") or pft:HasTag("abigail")
                if graveguard_friendly then
                    if ghost.components.combat:TargetIs(pft) or (pft.components.combat ~= nil and pft.components.combat:TargetIs(ghost)) then
                        ghost.brain.followtarget = pft
                        break
                    end
                else
                    ghost.brain.followtarget = pft
                    break
                end
            end
        end
    end

    return ghost.brain.followtarget
end

function GraveGuardBrain:OnStart()
    local root = PriorityNode(
    {
        WhileNode(function() return GetFollowTarget(self.inst) ~= nil end, "FollowTarget",
            Follow(
                self.inst,
                function()
                    return self.inst.brain.followtarget
                end,
                TUNING.GHOST_RADIUS*.25,
                TUNING.GHOST_RADIUS*.5,
                TUNING.GHOST_RADIUS
            )
        ),
        IfNode(function() return self.inst._despawn_queued end, "Despawn If Asked",
            ActionNode(function() self.inst.sg:GoToState("dissipate") end)
        ),
        SequenceNode{
			ParallelNodeAny{
				WaitNode(TUNING.TOTAL_DAY_TIME),
				Wander(self.inst, function() return self.inst.components.knownlocations:GetLocation("home") end, 7),
			},
            ActionNode(function() self.inst.sg:GoToState("dissipate") end),
        }
    }, 1)

    self.bt = BT(self.inst, root)
end

return GraveGuardBrain