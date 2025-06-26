local DEFAULT_MEAT_BUILD = "meat_rack_food"

local WobyRack = Class(function(self, inst)
	self.inst = inst
	self.container = SpawnPrefab("woby_rack_container").components.container
	self.container.inst.entity:SetParent(inst.entity)
	self.container.isexposed = false
	self.enabled = false
	self.dryingpaused = true
	self.dryinginfo = {}
	self.showitemfn = nil
	self.hideitemfn = nil

	inst:ListenForEvent("itemget", function(_, data)
		if data and data.item then
			self:OnGetItem(data.item, data.slot)
		end
	end, self.container.inst)
	inst:ListenForEvent("itemlose", function(_, data)
		if data and data.prev_item then
			self:OnLoseItem(data.prev_item, data.slot)
		end
	end, self.container.inst)
end)

function WobyRack:OnRemoveFromEntity()
	self:DisableDrying()
	self.container:DropEverything()
	self.container.inst:Remove()
end

function WobyRack:GetContainer()
	return self.container
end

function WobyRack:SetShowItemFn(fn)
	self.showitemfn = fn
end

function WobyRack:SetHideItemFn(fn)
	self.hideitemfn = fn
end

function WobyRack:GetItemInSlot(slot)
	local item = self.container:GetItemInSlot(slot)
	if item then
		local build
		if item.components.dryable then
			build = item.components.dryable:GetBuildFile()
		else
			local info = self.dryinginfo[item]
			if info then
				build = info.build
			end
		end
		return item, item.prefab, build or DEFAULT_MEAT_BUILD
	end
end

local function OnIsRaining(self, israining)
	if israining and not self:HasRainImmunity() then
		self:PauseDrying()
	else
		self:ResumeDrying()
	end
end

local function OnRainImmunity(inst)
	local self = inst.components.wobyrack
	self:SetContainerRainImmunity(true)
	self:ResumeDrying()
end

local function OnRainVulnerable(inst)
	local self = inst.components.wobyrack
	if not self:HasRainImmunity() then
		self:SetContainerRainImmunity(false)
		if self:IsExposedToRain() then
			self:PauseDrying()
		end
	end
end

local function OnRiderChanged(inst, data)
	local self = inst.components.wobyrack
	if self._rider then
		inst:RemoveEventCallback("gainrainimmunity", self._onriderrainimmunity, self._rider)
		inst:RemoveEventCallback("loserainimmunity", self._onriderrainvulnerable, self._rider)
	end
	self._rider = data and data.newrider or nil
	if self._rider then
		inst:ListenForEvent("gainrainimmunity", self._onriderrainimmunity, self._rider)
		inst:ListenForEvent("loserainimmunity", self._onriderrainvulnerable, self._rider)
	end

	if self:IsExposedToRain() then
		self:SetContainerRainImmunity(false)
		self:PauseDrying()
	else
		self:SetContainerRainImmunity(self:HasRainImmunity())
		self:ResumeDrying()
	end
end

local function DryingPerishRateFn(inst, item)
	return item and item.components.dryable and 0 or nil
end

function WobyRack:EnableDrying()
	if not self.enabled then
		self.enabled = true
		self.container.isexposed = true
		self.container.inst:AddComponent("preserver")
		self.container.inst.components.preserver:SetPerishRateMultiplier(DryingPerishRateFn)

		self:WatchWorldState("israining", OnIsRaining)
		self.inst:ListenForEvent("gainrainimmunity", OnRainImmunity)
		self.inst:ListenForEvent("loserainimmunity", OnRainVulnerable)
		if self.inst.components.rideable then
			self.inst:ListenForEvent("riderchanged", OnRiderChanged)
			self._onriderrainimmunity = function() OnRainImmunity(self.inst) end
			self._onriderrainvulnerable = function() OnRainVulnerable(self.inst) end
			self._rider = self.inst.components.rideable:GetRider()
			if self._rider then
				self.inst:ListenForEvent("gainrainimmunity", self._onriderrainimmunity, self._rider)
				self.inst:ListenForEvent("loserainimmunity", self._onriderrainvulnerable, self._rider)
			end
		end

		if not self:IsExposedToRain() then
			if self:HasRainImmunity() then
				self:SetContainerRainImmunity(true)
			end
			self:ResumeDrying()
		end
	end
end

function WobyRack:DisableDrying()
	if self.enabled then
		self.enabled = false
		self.container.isexposed = false
		self.container.inst:RemoveComponent("preserver")

		self:StopWatchingWorldState("israining", OnIsRaining)
		self.inst:RemoveEventCallback("gainrainimmunity", OnRainImmunity)
		self.inst:RemoveEventCallback("loserainimmunity", OnRainVulnerable)
		self.inst:RemoveEventCallback("riderchanged", OnRiderChanged)
		if self._rider then
			self.inst:RemoveEventCallback("gainrainimmunity", self._onriderrainimmunity, self._rider)
			self.inst:RemoveEventCallback("loserainimmunity", self._onriderrainvulnerable, self._rider)
		end

		self:SetContainerRainImmunity(false)
		self:PauseDrying()
	end
end

local function OnDoneDrying(inst, self, item)
	self.dryinginfo[item] = nil
	local slot = self.container:GetItemSlot(item)
	local product = item.components.dryable and item.components.dryable:GetProduct() or nil
	if slot and product then
		product = SpawnPrefab(product)
		if product then
			local build = item.components.dryable:GetDriedBuildFile() or DEFAULT_MEAT_BUILD
			if product.components.inventoryitem then
				product.components.inventoryitem:InheritMoisture(item.components.inventoryitem:GetMoisture(), item.components.inventoryitem:IsWet())
			end
			item:Remove()
			print("WobyRack: Done drying", product.prefab)
			self.container:GiveItem(product, slot)
			local info = self.dryinginfo[product]
			if info == nil then --just making sure it's not another dryable item
				if build ~= DEFAULT_MEAT_BUILD then
					self.dryinginfo[product] = { build = build }
				end
				if self.showitemfn then
					self.showitemfn(self.inst, slot, product.prefab, build)
				end
			end
			return product --returned for LongUpdate
		end
	end
end

local function ForgetItem(item)
	item:RemoveEventCallback("stacksizechange", ForgetItem)
	item:RemoveEventCallback("ondropped", ForgetItem)
	item.wobyrack_drytime = nil
end

function WobyRack:OnGetItem(item, slot)
	local resumedrytime = item.wobyrack_drytime
	if resumedrytime then
		ForgetItem(item)
	end
	if item.wobyrack_lastinfo then
		item.wobyrack_lastinfo:Cancel()
		item.wobyrack_lastinfo = nil
	end
	local info = self.dryinginfo[item]
	if info == nil then
		if item.components.dryable then
			local product = item.components.dryable:GetProduct()
			local drytime = item.components.dryable:GetDryTime()
			if resumedrytime then
				drytime = math.min(math.max(10, resumedrytime), drytime)
			end
			if product and drytime then
				info = {}
				self.dryinginfo[item] = info
				if self.dryingpaused then
					print("WobyRack: Start drying (paused)", item, drytime)
					info.drytime = drytime
				else
					print("WobyRack: Start drying", item, drytime)
					info.task = self.inst:DoTaskInTime(drytime, OnDoneDrying, self, item)
				end
			end
			if slot and self.showitemfn then
				self.showitemfn(self.inst, slot, item.prefab, item.components.dryable:GetBuildFile() or DEFAULT_MEAT_BUILD)
			end
		elseif slot and self.showitemfn then
			self.showitemfn(self.inst, slot, item.prefab, DEFAULT_MEAT_BUILD)
		end
	end
end

local function ClearWobyRackLastInfo(item)
	item.wobyrack_lastinfo = nil
end

function WobyRack:OnLoseItem(item, slot)
	local info = self.dryinginfo[item]
	if info then
		if info.task or info.drytime then
			print("WobyRack: Stop drying", item)
			if item:IsValid() and item.wobyrack_drytime == nil then
				item.wobyrack_drytime = info.drytime or GetTaskRemaining(info.task)
				item:ListenForEvent("stacksizechange", ForgetItem)
				item:ListenForEvent("ondropped", ForgetItem)
			end
			if info.task then
				info.task:Cancel()
			end
		end
		self.dryinginfo[item] = nil
	end
	if slot then
		if item:IsValid() then
			--V2C: -allow failed "Move" between containers to put us back instead of dropping -for servers!
			--     -see (containers.lua, itemtestfn)
			--     -this matches client behaviour that would not even initiate the move at all if it wasn't
			--      able to find a valid destination.
			if item.wobyrack_lastinfo then
				item.wobyrack_lastinfo:Cancel()
			end
			item.wobyrack_lastinfo = item:DoStaticTaskInTime(0, ClearWobyRackLastInfo)
			item.wobyrack_lastinfo.container = self.container
			item.wobyrack_lastinfo.slot = slot
		end
		if self.hideitemfn then
			self.hideitemfn(self.inst, slot)
		end
	end
end

function WobyRack:IsExposedToRain()
	return TheWorld.state.israining and not self:HasRainImmunity()
end

function WobyRack:HasRainImmunity()
	return self.inst.components.rainimmunity ~= nil or (self._rider ~= nil and self._rider.components.rainimmunity ~= nil)
end

function WobyRack:SetContainerRainImmunity(isimmune)
	if isimmune then
		if not self.container.inst.components.rainimmunity then
			self.container.inst:AddComponent("rainimmunity")
		end
		self.container.inst.components.rainimmunity:AddSource(self.inst)
	elseif self.container.inst.components.rainimmunity then
		self.container.inst.components.rainimmunity:RemoveSource(self.inst)
	end
end

function WobyRack:PauseDrying()
	if not self.dryingpaused then
		self.dryingpaused = true
		print("WobyRack: Drying paused")
		for item, info in pairs(self.dryinginfo) do
			if info.task then
				info.drytime = GetTaskRemaining(info.task)
				print("WobyRack: --", item, info.drytime)
				info.task:Cancel()
				info.task = nil
			end
		end
	end
end

function WobyRack:ResumeDrying()
	if self.dryingpaused then
		self.dryingpaused = false
		print("WobyRack: Drying resumed")
		for item, info in pairs(self.dryinginfo) do
			if info.drytime then
				print("WobyRack: --", item, info.drytime)
				info.task = self.inst:DoTaskInTime(info.drytime, OnDoneDrying, self, item)
				info.drytime = nil
			end
		end
	end
end

function WobyRack:LongUpdate(dt)
	if self.enabled then
		local todone = {}
		for item, info in pairs(self.dryinginfo) do
			if info.task then
				local t = GetTaskRemaining(info.task)
				info.task:Cancel()
				if t > dt then
					info.task = self.inst:DoTaskInTime(t - dt, OnDoneDrying, self, item)
				else
					table.insert(todone, { item = item, dt = dt - t })
				end
			elseif info.drytime then
				if info.drytime > dt then
					info.drytime = info.drytime - dt
				else
					table.insert(todone, { item = item, dt = dt - info.drytime })
				end
			end
		end
		for i, v in ipairs(todone) do
			local product = OnDoneDrying(self.inst, self, v.item)
			if product and v.dt > 0 then
				product:LongUpdate(v.dt)
			end
		end
	end
end

function WobyRack:OnSave()
	if not self.container:IsEmpty() then
		local contents, refs = self.container.inst:GetPersistData()
		local info = {}
		for k, v in pairs(self.dryinginfo) do
			local slot = self.container:GetItemSlot(k)
			if slot then
				info[slot] =
					(v.task and math.floor(GetTaskRemaining(v.task))) or
					(v.drytime and math.floor(v.drytime)) or
					v.build
			end
		end
		return { contents = contents, info = next(info) and info or nil }, refs
	end
end

function WobyRack:OnLoad(data, newents)
	if data.contents then
		self.container.inst:SetPersistData(data.contents, newents)
		if data.info then
			for k, v in pairs(data.info) do
				local item = self.container:GetItemInSlot(k)
				if item then
					local info = self.dryinginfo[item]
					if type(v) == "number" then
						if info then
							if info.task then
								info.task:Cancel()
								info.task = self.inst:DoTaskInTime(v, OnDoneDrying, self, item)
								print("WobyRack: Restart drying", item, v)
							elseif info.drytime then
								info.drytime = v
								print("WobyRack: Restart drying (paused)", item, v)
							end
						end
					elseif info == nil then
						self.dryinginfo[item] = { build = v }
						if self.showitemfn then
							self.showitemfn(self.inst, k, item.prefab, v)
						end
					end
				end
			end
		end
	end
end

function WobyRack:GetDryingInfoSnapshot()
	local info = {}
	for k, v in pairs(self.dryinginfo) do
		info[k] =
			(v.task and GetTaskRemaining(v.task)) or
			(v.drytime and v.drytime) or
			v.build
	end
	return next(info) and info or nil
end

function WobyRack:ApplyDryingInfoSnapshot(snapshot)
	for k, v in pairs(snapshot) do
		local info = self.dryinginfo[k]
		if type(v) == "number" then
			if info then
				if info.task then
					info.task:Cancel()
					info.task = self.inst:DoTaskInTime(v, OnDoneDrying, self, k)
					print("WobyRack: Restart drying", k, v)
				elseif info.drytime then
					info.drytime = v
					print("WobyRack: Restart drying (paused)", k, v)
				end
			end
		elseif info == nil then
			local slot = self.container:GetItemSlot(k)
			if slot then
				self.dryinginfo[k] = { build = v }
				if self.showitemfn then
					self.showitemfn(self.inst, slot, k.prefab, v)
				end
			end
		end
	end
end

return WobyRack
