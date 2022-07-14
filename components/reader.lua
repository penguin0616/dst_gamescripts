local Reader = Class(function(self, inst)
    self.inst = inst

    inst:AddTag("reader")
end)

function Reader:OnRemoveFromEntity()
    self.inst:RemoveTag("reader")
end

function Reader:SetAspiringBookworm(bookworm)
	if bookworm then
		self.inst:AddTag("aspiring_bookworm")
	else
		self.inst:RemoveTag("aspiring_bookworm")
	end

	self.aspiring_bookworm = bookworm
end

function Reader:SetOnReadFn(fn)
	self.onread = fn
end

function Reader:Read(book)
	if book.components.book then
		if self.aspiring_bookworm then
			return book.components.book:OnPeruse(self.inst)
		else
			local success, reason = book.components.book:OnRead(self.inst)
			
			if success and self.onread then
				self.onread(self.inst, book)
			end
			
			return success, reason
		end
	end
end

return Reader