require "behaviours/doaction"
require "behaviours/faceentity"
require "behaviours/leash"
require "behaviours/wander"

-----------------------------------------------------------------------------------------

local WX78ScannerBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

-----------------------------------------------------------------------------------------

local function GetLeaderPosition(inst)
    return (inst.components.follower and inst.components.follower.leader and inst.components.follower.leader:GetPosition())
        or inst:GetPosition()
end

-----------------------------------------------------------------------------------------

local TARGET_FOLLOW, MAX_TARGET_FOLLOW = 0.1, 2.0

-- If the scantarget's physics radius pushes our dist above this, clamp to this.
-- Clip a hair below the actual scan distance to avoid stop/start wonkiness.
local HIGHEST_ADJUSTED_MAXFOLLOWDIST = TUNING.WX78_SCANNER_SCANDIST - 0.05

local function GetScanTarget(inst)
    return (not inst.sg:HasStateTag("scanned") and inst.components.entitytracker:GetEntity("scantarget"))
        or nil
end

local function GetTargetScanFollowDistance(inst)
    local target = GetScanTarget(inst)
    return (target ~= nil and (target:GetPhysicsRadius(0) + TARGET_FOLLOW))
        or TARGET_FOLLOW
end

local function GetMaxScanFollowDistance(inst)
    local target = GetScanTarget(inst)
    return (target ~= nil and math.min(HIGHEST_ADJUSTED_MAXFOLLOWDIST, target:GetPhysicsRadius(0) + MAX_TARGET_FOLLOW))
        or MAX_TARGET_FOLLOW
end

local function GetScanTargetLocation(inst)
    local target = GetScanTarget(inst)
    return (target ~= nil and target:GetPosition()) or inst:GetPosition()
end

local function KeepFacingScanTarget(inst, target)
    -- If the target is no longer valid, it should have been dropped out of our entitytracker.
    return GetScanTarget(inst) ~= nil
end

-----------------------------------------------------------------------------------------

function WX78ScannerBrain:OnStart()
    local root = PriorityNode({
        WhileNode(function() return GetScanTarget(self.inst) == nil end, "No Scan Target",
            LoopNode{
                DoAction(self.inst, self.inst.TryFindTarget, "Try To Scan Something", false, 3),
                ConditionWaitNode(function() return self.inst:GetBufferedAction() == nil end),
            }
        ),
        WhileNode(function() return GetScanTarget(self.inst) ~= nil end, "Has Scan Target",
            PriorityNode({
                Leash(self.inst, GetScanTargetLocation, GetMaxScanFollowDistance, GetTargetScanFollowDistance),
                FaceEntity(self.inst, GetScanTarget, KeepFacingScanTarget),
            }, 1)
        ),

        Leash(self.inst, GetLeaderPosition, 3, 1.5),
        StandStill(self.inst),
    }, 1)

    self.bt = BT(self.inst, root)
end

return WX78ScannerBrain