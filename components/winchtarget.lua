local WinchTarget = Class(function(self, inst)
    self.inst = inst

    self.depth = -1 -- -1: use ocean depth value at point

    self.salvagefn = nil

    self.inst:AddTag("winchtarget")
end)

function WinchTarget:OnRemoveFromEntity()
    self.inst:RemoveTag("winchtarget")
end

function WinchTarget:SetSalvageFn(fn)
    self.salvagefn = fn
end

function WinchTarget:Salvage()
    return self.salvagefn ~= nil and self.salvagefn(self.inst) or nil
end

function WinchTarget:GetSunkenObject()
    return self.inst.components.inventory ~= nil and self.inst.components.inventory:GetItemInSlot(1)
end

return WinchTarget