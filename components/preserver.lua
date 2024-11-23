local Preserver = Class(function(self, inst)
    self.inst = inst
	self.perish_rate_multiplier = 1
end,
nil)

function Preserver:SetPerishRateMultiplier(rate)
	self.perish_rate_multiplier = rate
end

function Preserver:GetPerishRateMultiplier(item)
	return (self.perish_rate_multiplier == nil and 1)
		    or type(self.perish_rate_multiplier) == "number" and self.perish_rate_multiplier
			or self.perish_rate_multiplier(self.inst, item)
			or 1
end


function Preserver:GetDebugString()
	local s = nil
	if type(self.perish_rate_multiplier) == "number" then
     	s = string.format("perish rate mult = %.2f", self.perish_rate_multiplier)
	else
		s = "perish rate mult = FUNCTION"
	end
    return s
end

return Preserver