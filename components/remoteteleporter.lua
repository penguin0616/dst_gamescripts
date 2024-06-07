local RemoteTeleporter = Class(function(self, inst)
	self.inst = inst
	self.canactivatefn = nil
	self.checkdestinationfn = nil
	self.onstartteleportfn = nil
	self.onteleportedfn = nil
	self.onstopteleportfn = nil
end)

function RemoteTeleporter:SetCanActivateFn(fn)
	self.canactivatefn = fn
end

function RemoteTeleporter:SetCheckDestinationFn(fn)
	self.checkdestinationfn = fn
end

function RemoteTeleporter:SetOnStartTeleportFn(fn)
	self.onstartteleportfn = fn
end

function RemoteTeleporter:SetOnTeleportedFn(fn)
	self.onteleportedfn = fn
end

function RemoteTeleporter:SetOnStopTeleportFn(fn)
	self.onstopteleportfn = fn
end

function RemoteTeleporter:SetItemTeleportRadius(radius)
    self.itemteleportradius = radius
end

function RemoteTeleporter:CanActivate(doer)
	if self.canactivatefn then
		return self.canactivatefn(self.inst, doer)
	end
	return true
end

local ITEM_MUST_TAGS = {"_inventoryitem",}
local ITEM_CANT_TAGS = {"INLIMBO", "FX", "NOCLICK", "DECOR",}
function RemoteTeleporter:Teleport_Internal(from_x, from_z, to_x, to_z, doer)
    if self.itemteleportradius ~= nil then
        local items = TheSim:FindEntities(from_x, 0, from_z, self.itemteleportradius, ITEM_MUST_TAGS, ITEM_CANT_TAGS)
        for _, item in ipairs(items) do
            local ix, iy, iz = item.Transform:GetWorldPosition()
            local dx, dz = ix - from_x, iz - from_z
            if item.Physics then
                item.Physics:Teleport(to_x + dx, 0, to_z + dz)
            else
                item.Transform:SetPosition(to_x + dx, 0, to_z + dz)
            end
        end
    end

    doer.Physics:Teleport(to_x, 0, to_z)
    if self.onteleportedfn then
        self.onteleportedfn(self.inst, doer, true)
    end
end
local TAGS = { "remote_teleport_dest" }
function RemoteTeleporter:Teleport(doer)
	local x, y, z = doer.Transform:GetWorldPosition()
	local physrad = doer:GetPhysicsRadius(0)
	local originx, originz
	local originrangesq = 2 + physrad
	originrangesq = originrangesq * originrangesq

	for i, v in ipairs(TheSim:FindEntities(x, y, z, TUNING.WINONA_TELEBRELLA_TELEPORT_RANGE, TAGS)) do
		if self.checkdestinationfn == nil or self.checkdestinationfn(self.inst, v, doer) then
			local x1, y1, z1 = v.Transform:GetWorldPosition()
			if distsq(x, z, x1, z1) >= originrangesq then
                self:Teleport_Internal(x, z, x1, z1, doer)
				return true
			elseif originx == nil then
				originx, originz = x1, z1
			end
		end
	end
	if originx then
        self:Teleport_Internal(x, z, originx, originz, doer)
		return true
	end
	if self.onteleportedfn then
		self.onteleportedfn(self.inst, doer, false)
	end
	return false, "NODEST"
end

function RemoteTeleporter:OnStartTeleport(doer)
	if self.onstartteleportfn then
		self.onstartteleportfn(self.inst, doer)
	end
end

function RemoteTeleporter:OnTeleportedFn(doer, success)
	if self.onteleportedfn then
		self.onteleportedfn(self.inst, doer, success)
	end
end

function RemoteTeleporter:OnStopTeleport(doer, success)
	if self.onstopteleportfn then
		self.onstopteleportfn(self.inst, doer, success)
	end
end

return RemoteTeleporter
