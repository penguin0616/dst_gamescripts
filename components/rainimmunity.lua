local RainImmunity = Class(function(self, inst)
	self.inst = inst
	self.sources = {}

	self._onremovesource = function(src)
		self.sources[src] = nil
		if next(self.sources) == nil then
			inst:RemoveComponent("rainimmunity")
		end
	end
end)

function RainImmunity:OnRemoveFromEntity()
	self.inst:RemoveTag("rainimmunity")

	for src in pairs(self.sources) do
		if src ~= self.inst then
			self.inst:RemoveEventCallback("onremove", self._onremovesource, src)
		end
	end
end

function RainImmunity:AddSource(src)
	if not self.sources[src] then
		if next(self.sources) == nil then
			self.inst:AddTag("rainimmunity")
		end
		self.sources[src] = true
		if src ~= self.inst then
			self.inst:ListenForEvent("onremove", self._onremovesource, src)
		end
	end
end

function RainImmunity:RemoveSource(src)
	if self.sources[src] then
		if src ~= self.inst then
			self.inst:RemoveEventCallback("onremove", self._onremovesource, src)
		end
		self._onremovesource(src)
	end
end

return RainImmunity
