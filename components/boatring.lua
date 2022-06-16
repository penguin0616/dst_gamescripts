local BoatRing = Class(function(self, inst)
    self.inst = inst
    self.rotate_speed = 0.5
    self.max_rotate_speed = 2

    self.boatbumpers = {}

    self.rotators = {}
    self.onrotationchanged = function(inst, direction)
        if direction == nil then
            return
        end

        for i, rotator in ipairs(self.rotators) do
            if direction ~= 0 then
                rotator.inst.sg.mem.direction = direction
                rotator.inst.sg:GoToState("on")
            else
                rotator.inst.sg:GoToState("off")
            end
        end
    end

    self:StartUpdating()

    self.inst:ListenForEvent("onignite", function() self:OnIgnite() end)
    self.inst:ListenForEvent("death", function() self:OnDeath() end)
    self.inst:ListenForEvent("rotationdirchanged", self.onrotationchanged)
end)

function BoatRing:GetRadius()
    return self.inst.components.boatringdata and self.inst.components.boatringdata:GetRadius() or 0
end

function BoatRing:GetNumSegments()
    return self.inst.components.boatringdata and self.inst.components.boatringdata:GetNumSegments() or 0
end

function BoatRing:AddBumper(bumper)
    table.insert(self.boatbumpers, bumper)
end

function BoatRing:RemoveBumper(bumper)
    table.removearrayvalue(self.boatbumpers, bumper)
end

function BoatRing:AddRotator(rotator)
    table.insert(self.rotators, rotator)
end

function BoatRing:RemoveRotator(rotator)
    table.removearrayvalue(self.rotators, rotator)
end

function BoatRing:GetBumperAtPoint(x, z)
    -- Search through all bumpers until we find one that's covering (x, z)
    local boatposition = self.inst:GetPosition()
    local boatsegments = self.inst.components.boatringdata and self.inst.components.boatringdata:GetNumSegments() or 0

    for i, bumper in ipairs(self.boatbumpers) do
        local forward = bumper:GetPosition() - boatposition

        local segmentwidth = (boatsegments > 0 and 360 / boatsegments or 360) / RADIANS
        local testpos = Vector3(x, 0, z)
        if IsWithinAngle(boatposition, forward, segmentwidth, testpos) then
            return bumper
        end
    end
end

function BoatRing:OnDeath()
    self.inst.SoundEmitter:KillSound("boat_movement")
end

function BoatRing:OnUpdate(dt)
    -- Rotate the actual boat
    local isrotating = self.inst.components.boatringdata and self.inst.components.boatringdata:IsRotating() or false
    if isrotating then
        local angle = self.inst.Transform:GetRotation()

        -- If no rotators but still rotating, set the num rotators to 1 to simulate a malfunctioning boat
        local numrotators = #self.rotators == 0 and isrotating and 1 or #self.rotators
        local speed = math.min(numrotators * self.rotate_speed, self.max_rotate_speed)
        angle = (angle + speed * self.inst.components.boatringdata:GetRotationDirection() % 360)
        if angle < 0 then
            angle = angle + 360
        end
        self.inst.Transform:SetRotation(angle)
    end
end

function BoatRing:StartUpdating()
    self.inst:StartUpdatingComponent(self)
end

function BoatRing:StopUpdating()
    self.inst:StopUpdatingComponent(self)
end

--[[function BoatRing:OnEntitySleep()
end]]

return BoatRing
