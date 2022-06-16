local BoatMagnetBeacon = Class(function(self, inst)
    self.inst = inst
	self.boat = nil
    self.magnet = nil
    self.turnedoff = false
    self.ispickedup = false
    self.prev_guid = nil
    self.hasloaded = false

	self.OnBoatRemoved = function() self.boat = nil end
    self.OnBoatDeath = function() self:OnDeath() end

    self.OnMagnetRemoved = function()
        self:UnpairWithMagnet()
    end

	self._setup_boat_task = self.inst:DoTaskInTime(0, function()
        self:SetBoat(self.inst:GetCurrentPlatform())
		self._setup_boat_task = nil
    end)
end)

function BoatMagnetBeacon:OnSave()
    local data = {
        turnedoff = self.turnedoff,
        ispickedup = self.ispickedup,
        prev_guid = self.magnet ~= nil and self.magnet.GUID or self.prev_guid,

        hasloaded = self.hasloaded,
    }
    return data
end

function BoatMagnetBeacon:OnLoad(data)
    if data == nil then
        return
    end

    self.turnedoff = data.turnedoff
    self.ispickedup = data.ispickedup
    self.prev_guid = data.prev_guid

    self.hasloaded = data.hasloaded

    if self.ispickedup then
        -- Hack to prevent beacons in inventory from connecting to the boat twice on load (not sure why this happens...)
        if not self.hasloaded then
            self.hasloaded = true
        else
            TheWorld:PushEvent("oninvboatbeaconloaded", { guid = data.prev_guid, inst = self.inst } )
            self.hasloaded = false
        end
    end

    if self.turnedoff then
        self.inst:AddTag("turnedoff")
    end
end

function BoatMagnetBeacon:LoadPostPass(newents, data)
    if not self.ispickedup then
        local magnet = self.inst.components.entitytracker and self.inst.components.entitytracker:GetEntity("boat_magnet") or nil
        if magnet ~= nil and magnet.components.boatmagnet ~= nil then
            magnet.components.boatmagnet:PairWithBeacon(self.inst)
        end
    end
end
function BoatMagnetBeacon:OnRemoveFromEntity()
	if self._setup_boat_task ~= nil then
		self._setup_boat_task:Cancel()
	end
end

function BoatMagnetBeacon:OnRemoveEntity()
    if self ~= nil then
        self:SetBoat(nil)
    end
end

function BoatMagnetBeacon:GetBoat()
    -- If not placed on a boat, check to see if the entity carrying it is on a boat
    local owner = self.inst.entity:GetParent()
    if owner == nil then
        local boat = self.inst:GetCurrentPlatform()
        if boat and boat:HasTag("boat") then
            self.boat = boat -- Update the boat if it's different from what's saved
            return boat
        else
            return nil
        end
    end

    local boat = owner:GetCurrentPlatform()
    if boat and boat:HasTag("boat") then
        return boat
    end

    self.boat = nil -- Update the boat if it's different from what's saved
    return nil
end

function BoatMagnetBeacon:SetBoat(boat)
	if boat == self.boat then return end

	if self.boat ~= nil then
        self.inst:RemoveEventCallback("onremove", self.OnBoatRemoved, boat)
        self.inst:RemoveEventCallback("death", self.OnBoatDeath, boat)
    end

    self.boat = boat

    if boat ~= nil then
        self.inst:ListenForEvent("onremove", self.OnBoatRemoved, boat)
        self.inst:ListenForEvent("death", self.OnBoatDeath, boat)
    end
end

function BoatMagnetBeacon:OnDeath()
	if self.inst:IsValid() then
	    --self.inst.SoundEmitter:KillSound("boat_movement")
        self:SetBoat(nil)
	end
end

function BoatMagnetBeacon:PairedMagnet()
    return self.magnet
end

function BoatMagnetBeacon:PairWithMagnet(magnet)
    self.magnet = magnet
    if magnet ~= nil then
        self.inst.components.entitytracker:TrackEntity(magnet.prefab, magnet)
    end

    self.inst:ListenForEvent("onremove", self.OnMagnetRemoved, magnet)
    self.inst:ListenForEvent("death", self.OnMagnetRemoved, magnet)

    if self.turnedoff then
        self.inst.components.inventoryitem:ChangeImageName("boat_magnet_beacon")
        self.inst:AddTag("turnedoff")
    else
        self.inst.components.inventoryitem:ChangeImageName("boat_magnet_beacon_on")
    end
    self.inst.sg:GoToState("activate")

    self.inst:AddTag("paired")
end

function BoatMagnetBeacon:UnpairWithMagnet()
    if self.magnet ~= nil then
        self.inst.components.entitytracker:ForgetEntity(self.magnet.prefab)
    end

    self.inst:RemoveEventCallback("onremove", self.OnMagnetRemoved, self.magnet)
    self.inst:RemoveEventCallback("death", self.OnMagnetRemoved, self.magnet)

    self.magnet = nil
    self.turnedoff = false
    self.inst.components.inventoryitem:ChangeImageName("boat_magnet_beacon")
    self.inst.sg:GoToState("deactivate")

    self.inst:RemoveTag("turnedoff")
    self.inst:RemoveTag("paired")
end

function BoatMagnetBeacon:IsTurnedOff()
    return self.turnedoff
end

function BoatMagnetBeacon:TurnOnBeacon()
    self.turnedoff = false

    if self.inst.components.inventoryitem then
        self.inst.components.inventoryitem:ChangeImageName("boat_magnet_beacon_on")
    end

    self.inst.sg:GoToState("activate")
    self.inst:PushEvent("onturnon")

    self.inst:RemoveTag("turnedoff")
end

function BoatMagnetBeacon:TurnOffBeacon()
    self.turnedoff = true

    if self.inst.components.inventoryitem then
        self.inst.components.inventoryitem:ChangeImageName("boat_magnet_beacon")
    end

    self.inst.sg:GoToState("deactivate")
    self.inst:PushEvent("onturnoff")

    self.inst:AddTag("turnedoff")
end

function BoatMagnetBeacon:IsPickedUp()
    return self.ispickedup
end

function BoatMagnetBeacon:SetIsPickedUp(pickedup)
    self.ispickedup = pickedup
    self.boat = not pickedup and self:GetBoat() or nil
end

return BoatMagnetBeacon
