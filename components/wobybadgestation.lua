local WobyBadgeStation = Class(function(self, inst)
    self.inst = inst

    self.user = nil

    self.range = 3

    self.onopenfn = nil
    self.onclosefn = nil

    self.onclosepopup = function(doer, data)
        if data.popup == POPUPS.WOBYBADGECUSTOMIZATION then
            self.onclosecustomization(doer, data ~= nil and data.args ~= nil and data.args[1] or nil)
        end
    end

    self.onclosecustomization = function(doer, activebadges)
        if type(activebadges) == "string" then
            if self.user ~= nil and self.user.components.dogtrainer ~= nil then
                self.user.components.dogtrainer:DecodeAndValidateBadgesData(activebadges)
            end
        end

        self:EndCustomization(doer)
    end
end)

function WobyBadgeStation:CanBeginCustomization(doer)
    if doer.components.dogtrainer == nil or not doer.components.dogtrainer:IsEnabled() then
        return false

    elseif self.user == doer or doer.sg == nil or doer.sg:HasStateTag("busy") then
        return false

    elseif self.inst.components.burnable and self.inst.components.burnable:IsBurning() then
        return false, "BURNING"

    elseif self.user ~= nil then
        return false, "INUSE"
    end

    return true
end

function WobyBadgeStation:BeginCustomization(doer)
    if self.user ~= nil then
        return false
    end

    self.user = doer

    self.inst:ListenForEvent("onremove",      self.onclosecustomization, doer)
    self.inst:ListenForEvent("ms_closepopup", self.onclosepopup,         doer)

    doer.sg:GoToState("openwobybadgecustomization")

    self.inst:StartUpdatingComponent(self)

    if self.onopenfn then
        self.onopenfn(self.inst)
    end

    return true
end

function WobyBadgeStation:EndCustomization(doer)
    if self.user ~= doer or doer == nil then
        return
    end

    self.inst:RemoveEventCallback("onremove",      self.onclosecustomization, doer)
    self.inst:RemoveEventCallback("ms_closepopup", self.onclosepopup,         doer)

    self.user = nil

    doer.sg:HandleEvent("ms_endwobybadgecustomization")

    self.inst:StopUpdatingComponent(self)

    if self.onclosefn then
        self.onclosefn(self.inst)
    end
end

function WobyBadgeStation:OnRemoveFromEntity()
    self:EndCustomization(self.user)
end

WobyBadgeStation.OnRemoveEntity = WobyBadgeStation.OnRemoveFromEntity

--------------------------------------------------------------------------
-- Check for auto-closing conditions
--------------------------------------------------------------------------

function WobyBadgeStation:OnUpdate(dt)
    if self.user == nil then
        self.inst:StopUpdatingComponent(self)

    elseif not (self.user:IsNear(self.inst, self.range) and CanEntitySeeTarget(self.user, self.inst)) then
        self:EndCustomization(self.user)
    end
end

return WobyBadgeStation
