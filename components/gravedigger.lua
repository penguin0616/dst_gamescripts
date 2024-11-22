local GraveDigger = Class(function(self, inst)
    self.inst = inst

    -- self.onused = nil
end)

function GraveDigger:OnUsed(user)
    if self.onused then
        self.onused(self.inst, user)
    end
end

return GraveDigger