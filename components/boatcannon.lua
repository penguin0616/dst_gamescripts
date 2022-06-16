local easing = require("easing")

local BoatCannon = Class(function(self, inst)
    self.inst = inst

	self.loadedammo = nil
end)

--[[function BoatCannon:OnSave()
end]]

--[[function BoatCannon:OnLoad(data)
end]]

function BoatCannon:IsAmmoLoaded()
	--return self.loadedammo ~= nil
	return self.inst:HasTag("ammoloaded")
end

function BoatCannon:LoadAmmo(ammo)

	if ammo == nil or not ammo:HasTag("boatcannon_ammo") or not ammo.projectileprefab then
		return false
	end

	self.loadedammo = ammo.projectileprefab
	self.inst:AddTag("ammoloaded")
	self.inst.sg:GoToState("load")
	return true
end

function BoatCannon:Shoot()
	if self.loadedammo == nil or self.loadedammo == nil then
		return
	end

	local x, y, z = self.inst.Transform:GetWorldPosition()
    local projectile = SpawnPrefab(self.loadedammo)
	if projectile == nil then
		self.loadedammo = nil
		return
	end

	local theta = self.inst.Transform:GetRotation()* DEGREES
	local radius = 0.5
	local offset = Vector3(radius * math.cos( theta ), 0, -radius * math.sin( theta ))

    projectile.Transform:SetPosition(x+offset.x, y + 0.6, z+offset.z)

	projectile.shooter = self.inst

	local angle = -self.inst.Transform:GetRotation() * DEGREES
	local distance = 20--TUNING.BOAT.BOATCANNON.POWER
	local speed = 20

	-- Apply direction & power to shot
	local targetpos = Vector3(x + math.cos(angle) * distance, y, z + math.sin(angle) * distance)
	projectile.components.complexprojectile:SetHorizontalSpeed(speed)
    projectile.components.complexprojectile:SetGravity(-40)
    projectile.components.complexprojectile:Launch(targetpos, self.inst, self.inst)

	-- Remove cannon ammo
	self.loadedammo = nil
	self.inst:RemoveTag("ammoloaded")

	-- Add a shot recoil to the boat
	local force_direction = -Vector3(math.cos(angle), 0, math.sin(angle))
	local force = 1
	local boat = self.inst:GetCurrentPlatform()
	if boat ~= nil then
		boat.components.boatphysics:ApplyForce(force_direction.x, force_direction.z, force)
	end
end

return BoatCannon
