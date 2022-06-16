local BoatRingData = Class(function(self, inst)
    self.inst = inst

    self.rotationdirection = net_tinybyte(inst.GUID, "boatringdata._rotatedir") -- [0..7]
    self:SetRotationDirection(0) -- Need to initialize this or else GetRotationDirection() will return -1 by default

    self.radius = net_float(inst.GUID, "boatringdata._radius")
    self.segments = net_smallbyte(inst.GUID, "boatringdata._segments") -- [0..63]
end)

function BoatRingData:OnSave()
    local data =
    {
        rotationdirection = self:GetRotationDirection(),
    }

    return data
end

function BoatRingData:OnLoad(data)
    if data ~= nil then
        self:SetRotationDirection(data.rotationdirection or 0)
    end
end

function BoatRingData:IsRotating()
    return self.rotationdirection:value() - 1 ~= 0 -- offset by 1, since GetRotationDirection() will return 0
end

function BoatRingData:GetRotationDirection()
    local value = self.rotationdirection:value()
    -- Return as -1, 0, or 1
    return value - 1
end

function BoatRingData:SetRotationDirection(dir)
    -- Dir is -1, 0, or 1 and rotationdirection is a tinybyte. Offset to save it as 0, 1, or 2
    self.rotationdirection:set(dir + 1)
end

function BoatRingData:GetRadius()
    return self.radius:value()
end

function BoatRingData:SetRadius(radius)
    self.radius:set(radius)
end

function BoatRingData:GetNumSegments()
    return self.segments:value()
end

function BoatRingData:SetNumSegments(segments)
    self.segments:set(segments)
end

return BoatRingData
