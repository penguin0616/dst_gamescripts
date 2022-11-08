local ShadowLevel = Class(function(self, inst)
	self.inst = inst
	self.level = 1
	--self.levelfn = nil
end)

function ShadowLevel:SetDefaultLevel(level)
	self.level = level
end

function ShadowLevel:SetLevelFn(fn)
	self.levelfn = fn
end

function ShadowLevel:GetCurrentLevel()
	return self.levelfn ~= nil and self.levelfn(self.inst) or self.level
end

return ShadowLevel
