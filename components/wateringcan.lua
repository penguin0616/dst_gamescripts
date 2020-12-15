local function DefaultCanUse(inst)
    if inst.components.finiteuses ~= nil then
        local canuse = inst.components.finiteuses:GetUses() > 0
        if canuse then
            return true
        else
            return false, "OUT_OF_WATER"
        end
    end

    return true
end

local function AddMoistureToGround(inst, x, y, z)
    TheWorld.components.farming_manager:AddSoilMoistureAtPoint(x, 0, z, inst.components.wateringcan.water_amount)
end

local WateringCan = Class(function(self, inst)
    self.inst = inst

    self.canusefn = DefaultCanUse
    self.ondepletefn = nil
    self.water_amount = 25
end)

function WateringCan:Deplete()
    if self.ondepletefn ~= nil then
        self.ondepletefn(self.inst)
    end
end

function WateringCan:WaterGround(x, y, z)
    AddMoistureToGround(self.inst, x, y, z)

    self:Deplete()
end

function WateringCan:WaterTarget(target)
    if target ~= nil and target:IsValid() then
        if target.components.burnable ~= nil then
            if target.components.burnable:IsBurning() then
                target.components.burnable:Extinguish()
            elseif target.components.burnable:IsSmoldering() then
                target.components.burnable:SmotherSmolder()
            end
        end

        local x, y, z = target.Transform:GetWorldPosition()
        AddMoistureToGround(self.inst, x, y, z)

        self:Deplete()
    end
end

function WateringCan:CanUse()
    if self.canusefn ~= nil then
        local canuse, reason = self.canusefn(self.inst)
        return canuse, reason
    end

    return true
end

return WateringCan
