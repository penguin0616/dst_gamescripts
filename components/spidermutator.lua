local SpiderMutator = Class(function(self, inst)
    self.inst = inst
end)

function SpiderMutator:SetMutationTarget(target)
    self.mutation_target = target
end

function SpiderMutator:CanMutate(spider)
    return spider.prefab ~= self.mutation_target
end

function SpiderMutator:Mutate(spider, skip_event, giver)
    local owner = spider.components.inventoryitem.owner
    if owner ~= nil then
    	local new_spider = SpawnPrefab(self.mutation_target)
    	local slot = owner.components.inventory:GetItemSlot(spider)

    	owner.components.inventory:RemoveItem(spider)
    	spider:Remove()

    	owner.components.inventory:GiveItem(new_spider, slot)
    else	
	    spider.mutation_target = self.mutation_target
		spider.mutator_giver = giver

	    if not skip_event then
	    	spider:PushEvent("mutate")
	    end
    end


    if self.inst.components.stackable then
    	self.inst.components.stackable:Get():Remove()
    else
    	self.inst:Remove()
    end
end

return SpiderMutator