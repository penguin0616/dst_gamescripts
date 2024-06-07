local RoseInspectable = Class(function(self, inst)
    self.inst = inst

    --self.oninspectedfn = nil
    --self.onhookupresiduefn = nil
end)

function RoseInspectable:SetOnRoseInspected(fn)
    self.oninspectedfn = fn
end

function RoseInspectable:SetOnResidueHookup(fn)
    self.onhookupresiduefn = fn
end

function RoseInspectable:HookupResidue(residueowner, residue)
    if self.onhookupresiduefn then
        self.onhookupresiduefn(self.inst, residueowner, residue)
    end
end

function RoseInspectable:DoRoseInspection(doer)
    if self.oninspectedfn then
        self.oninspectedfn(self.inst, doer)
    end
end

return RoseInspectable
