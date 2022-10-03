local ErasablePaper = Class(function(self, inst)
    self.inst = inst

    --self.stacksize = 1
	--self.erased_prefab = "papyrus"
end)

function ErasablePaper:DoErase(eraser, doer)
	self.inst:Remove()

	local paper = SpawnPrefab(self.erased_prefab or "papyrus")
	local x, y, z = eraser.Transform:GetWorldPosition()
	paper.Transform:GetWorldPosition()
	if self.stacksize and self.stacksize > 1 and paper.components.stackable then
		paper.components.stackable:SetSize(self.stacksize)
	end

	if doer and doer.components.inventory then
		doer.components.inventory:GiveItem(paper, nil, eraser:GetPosition())
	else
		Launch2(paper, eraser, 2, 0, 1, .5)
	end

	return paper
end

return ErasablePaper