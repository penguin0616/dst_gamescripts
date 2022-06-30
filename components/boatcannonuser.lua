local function OnCannonDirty(inst)
	inst.components.boatcannonuser:OnCannonChanged()
end

local BoatCannonUser = Class(function(self, inst)
	self.inst = inst

	--Local aiming variables (DO NOT USE IN SERVER CODE)
	self.aim_range_fx = nil
	self.aiming_cannon = nil
	self.task = nil

	--Network variables
	self._cannon = net_entity(inst.GUID, "boatcannonuser._cannon", "cannondirty")

	if TheWorld.ismastersim then
		--Server only
		self.cannon_remove_callback = function()
			self._cannon:set(nil)
			self:CancelAimingStateInternal()
		end
	else
		--Client only
		inst:ListenForEvent("cannondirty", OnCannonDirty)
	end
end)

--------------------------------------------------------------------------
--Client & Server

local function CalculateBaseAimAngle(inst, cannon)
	local x, y, z = inst.Transform:GetWorldPosition()
	return 180 - GetAngleFromBoat(cannon, x, z) * RADIANS
end

function BoatCannonUser:GetCannon()
	return self._cannon:value()
end

function BoatCannonUser:GetAimPos()
	return self.aimingcannon ~= nil and self.aimingcannon.components.reticule ~= nil and self.aimingcannon.components.reticule.targetpos or nil
end

function BoatCannonUser:GetReticule()
	return self.aimingcannon ~= nil and self.aimingcannon.components.reticule or nil
end

local function DoStartAiming(inst, self, cannon)
	self.task = nil

	if not cannon:IsValid() then
		return
	end

	if cannon.components.reticule ~= nil then
		cannon.components.reticule:CreateReticule()
	end

	self.aim_range_fx = SpawnPrefab("cannon_aoe_range_fx")
	self.aim_range_fx.entity:SetParent(cannon.entity)
end

function BoatCannonUser:OnCannonChanged()
	--Only show aiming for local player
	if self.inst ~= ThePlayer then
		return
	end

	local cannon = self._cannon:value()

	if self.aimingcannon ~= nil then
		if self.task ~= nil then
			self.task:Cancel()
			self.task = nil
		else
			self.aim_range_fx:Remove()
			self.aim_range_fx = nil

			if self.aimingcannon.components.reticule ~= nil then
				self.aimingcannon.components.reticule:DestroyReticule()
			end
		end
	end

	if cannon ~= nil then
		print("Start aiming", cannon)
		--Delay to wait make sure cannon rotation gets set first
		self.task = self.inst:DoTaskInTime(0, DoStartAiming, self, cannon)
	else
		print("Stop aiming cannon")
	end

	self.aimingcannon = cannon
end

--[[function BoatCannonUser:OnWallUpdate(dt)
	-- Point towards the action point
	local cannon = self._cannon:value()
	local base_aim_angle = CalculateBaseAimAngle(self.inst, cannon)
	--local base_aim_facing = Vector3(math.cos(-base_aim_angle * DEGREES), 0 , math.sin(-base_aim_angle * DEGREES))

	--self.aimpos = TheInput:GetWorldPosition()
	--if self.aimpos ~= nil and IsWithinAngle(cannon:GetPosition(), base_aim_facing, TUNING.BOAT.BOATCANNON.AIM_ANGLE_WIDTH, self.aimpos) then

		--TODO: can't set rotation like this. need to think about how to network this.
		--local angle = GetAngleFromBoat(cannon, self.aimpos.x, self.aimpos.z) * RADIANS
		--cannon.Transform:SetRotation(-angle)

	--end

	local actualangle = cannon.Transform:GetRotation()
	local angledelta = actualangle - base_aim_angle
	self.aim_range_fx.Transform:SetRotation(-angledelta)
end]]

--------------------------------------------------------------------------
--Master Sim

function BoatCannonUser:SetCannon(cannon)
	assert(TheWorld.ismastersim)
	if self._cannon:value() == cannon then
		return
	end

	local prev_cannon = self._cannon:value()
	self._cannon:set(cannon)

	if prev_cannon ~= nil then
		self.inst:RemoveEventCallback("onremove", self.cannon_remove_callback, prev_cannon)

		if prev_cannon.components.boatcannon ~= nil then
			prev_cannon.components.boatcannon:StopAiming()
		end

		if cannon == nil then
			self:CancelAimingStateInternal()
		end
	end

	if cannon ~= nil then
		self.inst:ListenForEvent("onremove", self.cannon_remove_callback, cannon)

		if cannon.components.boatcannon ~= nil then
			cannon.components.boatcannon:StartAiming(self.inst)
		end

		cannon.Transform:SetRotation(CalculateBaseAimAngle(self.inst, cannon))
	end

	self:OnCannonChanged()
end

function BoatCannonUser:CancelAimingStateInternal()
	assert(TheWorld.ismastersim)
	if self.inst.sg:HasStateTag("is_using_cannon") then
		self.inst.sg:GoToState("aim_cannon_pst")
	end
end

return BoatCannonUser
