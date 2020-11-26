local SymbolSwapData = Class(function(self, inst)
	self.inst = inst

	-- self.build = nil
	-- self.symbol = nil
end)

function SymbolSwapData:SetData(build, symbol)
	self.build = build
	self.symbol = symbol
end

function SymbolSwapData:GetDebugString()
	return string.format("build:%s,  symbol:%s", self.build, self.symbol)
end

return SymbolSwapData
