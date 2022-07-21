local Book = Class(function(self, inst)
    self.inst = inst
end)

function Book:SetOnPeruse(fn)
	self.onperuse = fn
end

function Book:SetOnRead(fn)
	self.onread = fn
end

function Book:SetReadSanity(sanity)
	self.read_sanity = sanity
end

function Book:SetPeruseSanity(sanity)
	self.peruse_sanity = sanity
end

function Book:SetFx(fx)
	self.fx = fx
end

function Book:ConsumeUse()
	if self.inst.components.finiteuses then
		self.inst.components.finiteuses:Use(1)
	end
end

function Book:Interact(fn, reader)
	local success = true
	local reason
	if fn then
		success, reason = fn(self.inst, reader)
		if success then
			self:ConsumeUse()
		end
	end

	return success, reason
end

function Book:OnPeruse(reader)
	local success = self:Interact(self.onperuse, reader)
	if success and reader.components.sanity then
		reader.components.sanity:DoDelta(self.peruse_sanity or 0)
	end

	return success
end

function Book:OnRead(reader)
	local success, reason = self:Interact(self.onread, reader)
	if success and reader.components.sanity then
		if self.fx then
			local fx = SpawnPrefab(self.fx)
			fx.Transform:SetPosition(reader.Transform:GetWorldPosition())
		end

		reader.components.sanity:DoDelta( (self.read_sanity or 0) * reader.components.reader:GetSanityPenaltyMultiplier() )
	end

	return success, reason
end

return Book