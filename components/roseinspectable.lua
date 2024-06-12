local RoseInspectable = Class(function(self, inst)
    self.inst = inst

    --self.onresidueactivatedfn = nil
    --self.onresiduecreatedfn = nil
    --self.canresiduebespawnedbyfn = nil
end)

function RoseInspectable:SetOnResidueActivated(fn)
    self.onresidueactivatedfn = fn
end

function RoseInspectable:SetOnResidueCreated(fn)
    self.onresiduecreatedfn = fn
end

function RoseInspectable:SetCanResidueBeSpawnedBy(fn)
    self.canresiduebespawnedbyfn = fn
end

function RoseInspectable:CanResidueBeSpawnedBy(doer)
    if self.canresiduebespawnedbyfn == nil then
        return true
    end

    return self.canresiduebespawnedbyfn(self.inst, doer)
end

function RoseInspectable:HookupResidue(residueowner, residue)
    if self.onresiduecreatedfn then
        self.onresiduecreatedfn(self.inst, residueowner, residue)
    end
end

function RoseInspectable:DoRoseInspection(doer)
    if self.onresidueactivatedfn then
        self.onresidueactivatedfn(self.inst, doer)
    end
end

return RoseInspectable
