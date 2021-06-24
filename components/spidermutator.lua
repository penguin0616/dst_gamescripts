local SpiderMutator = Class(function(self, inst)
    self.inst = inst
end)

function SpiderMutator:SetMutationTarget(target)
    self.mutation_target = target
end

function SpiderMutator:CanMutate(spider)
    return spider.prefab ~= self.mutation_target
end

function SpiderMutator:Mutate(spider, skip_event)
    spider.mutation_target = self.mutation_target
    
    if not skip_event then
    	spider:PushEvent("mutate")
    end

    if self.inst.components.stackable then
    	self.inst.components.stackable:Get():Remove()
    else
    	self.inst:Remove()
    end
end

return SpiderMutator