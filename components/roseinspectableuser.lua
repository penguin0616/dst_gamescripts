local RoseInspectableUser = Class(function(self, inst)
    self.inst = inst

    self.cooldowntime = TUNING.SKILLS.WINONA.ROSEGLASSES_COOLDOWNTIME
    --self.cooldowntask = nil
end)

function RoseInspectableUser:OnRemoveFromEntity()
    if self.cooldowntask ~= nil then
        self.cooldowntask:Cancel()
        self.cooldowntask = nil
    end
end

--------------------------------------------------

function RoseInspectableUser:SetCooldownTime(cooldowntime)
    self.cooldowntime = cooldowntime
end

function RoseInspectableUser:GoOnCooldown()
    if self.cooldowntask ~= nil then
        self.cooldowntask:Cancel()
        self.cooldowntask = nil
    end
    if self.cooldowntime ~= nil then
        self.cooldowntask = self.inst:DoTaskInTime(self.cooldowntime, self.OnCooldown_Bridge)
    end
end

--------------------------------------------------

function RoseInspectableUser:OnCharlieResidueActivated(residue)
    if residue ~= self.residue then
        return
    end

    if self.target ~= nil then
        local roseinspectable = self.target.components.roseinspectable
        if roseinspectable ~= nil then
            roseinspectable:DoRoseInspection(self.inst)
            self:GoOnCooldown()
        end
        self.target = nil
    else
        if self:DoRoseInspectionOnPoint() then
            self:GoOnCooldown()
        end
        self.point = nil
    end
end

--------------------------------------------------

function RoseInspectableUser:SetRoseInpectionOnTarget(target)
    self.target = target
    self.point = nil

    self:SpawnResidue()
    if self.target.components.roseinspectable then
        self.target.components.roseinspectable:HookupResidue(self.inst, self.residue)
    end
    self.residue:ListenForEvent("onremove", function() self:ForceDecayResidue() end, self.target)
end

function RoseInspectableUser:SetRoseInpectionOnPoint(point)
    self.target = nil
    self.point = point

    self:SpawnResidue()
end

--------------------------------------------------

function RoseInspectableUser:ForceDecayResidue()
    if self.residue then
        self.inst:RemoveEventCallback("onremove", self.residue._onresidueremoved, self.residue)
        self.residue:Decay()
    end
end

function RoseInspectableUser:SpawnResidue()
    self:ForceDecayResidue()

    local residue = SpawnPrefab("charlieresidue")
    self.residue = residue
    self.residue._onresidueremoved = function()
        self.residue = nil
    end
    self.inst:ListenForEvent("onremove", self.residue._onresidueremoved, self.residue)
    self.residue:SetFXOwner(self.inst) -- Handles the self.inst's onremove event.
    local x, y, z
    local theta = math.random() * PI2
    if self.target then
        x, y, z = self.target.Transform:GetWorldPosition()
        self.residue:SetTarget(self.target)
    else
        x, y, z = self.point:Get()
    end
    self.residue.Transform:SetPosition(x, y, z)
end

--------------------------------------------------

function RoseInspectableUser:DoRoseInspectionOnPoint()
    for _, config in ipairs(ROSEPOINT_CONFIGURATIONS) do
        local success, data = config.checkfn(self.inst, self.point)
        if success then
            config.callbackfn(self.inst, self.point, data)
            return true
        end
    end

    return false
end

--------------------------------------------------

function RoseInspectableUser:DoQuip(reason)
    if self.quipcooldowntime ~= nil and self.quipcooldowntime > GetTime() then
        return
    end
    if self.inst.components.talker then
        self.quipcooldowntime = GetTime() + 4 + math.random()
        self.inst.components.talker:Say(GetString(self.inst, reason))
    end
end

RoseInspectableUser.InvalidTags = {"_inventoryitem", "locomotor", "lunar_aligned", "notroseinspectable"}

function RoseInspectableUser:TryToDoRoseInspectionOnTarget(target)
    if self:IsInCooldown() then
        return false, "ROSEGLASSES_COOLDOWN"
    end

    if target.prefab ~= "charlieresidue" then
        if target.Physics and target.Physics:GetMass() ~= 0 then
            return false, "ROSEGLASSES_INVALID"
        end

        if target.components.roseinspectable == nil or not target.components.roseinspectable:CanResidueBeSpawnedBy(self.inst) then
            return false, "ROSEGLASSES_INVALID"
        end

        if target:HasAnyTag(self.InvalidTags) then
            return false, "ROSEGLASSES_INVALID"
        end

        self:SetRoseInpectionOnTarget(target)
    end

    self:DoQuip("ANNOUNCE_ROSEGLASSES")
    return true
end

function RoseInspectableUser:TryToDoRoseInspectionOnPoint(pt)
    if self:IsInCooldown() then
        return false, "ROSEGLASSES_COOLDOWN"
    end

    self:SetRoseInpectionOnPoint(pt)

    self:DoQuip("ANNOUNCE_ROSEGLASSES")
    return true
end

--------------------------------------------------

RoseInspectableUser.OnCooldown_Bridge = function(inst)
    local self = inst.components.roseinspectableuser
    self:OnCooldown()
end
function RoseInspectableUser:OnCooldown()
    self.cooldowntask = nil
end

function RoseInspectableUser:IsInCooldown()
    return self.cooldowntask ~= nil
end

--------------------------------------------------

function RoseInspectableUser:OnSave()
    local data = {}

    local timeleft = GetTaskRemaining(self.cooldowntask)
    if timeleft > 0 then
        data.cooldown = timeleft
    end

    return data
end

function RoseInspectableUser:OnLoad(data)
    if data == nil then
        return
    end

    if data.cooldown ~= nil then
        self.cooldowntask = self.inst:DoTaskInTime(data.cooldown, self.OnCooldown_Bridge)
    end
end

function RoseInspectableUser:LongUpdate(dt)
    if self.cooldowntask ~= nil then
        local remaining = GetTaskRemaining(self.cooldowntask) - dt
        self.cooldowntask:Cancel()
        if remaining > 0 then
            self.cooldowntask = self.inst:DoTaskInTime(remaining, self.OnCooldown_Bridge)
        else
            self.cooldowntask = nil
        end
    end
end

--------------------------------------------------

function RoseInspectableUser:GetDebugString()
    return string.format("Target: %s, Cooldown: %.1f", self.target and tostring(self.target) or self.point and tostring(self.point) or "N/A", GetTaskRemaining(self.cooldowntask))
end

return RoseInspectableUser
