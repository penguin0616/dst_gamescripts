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

function RemoteTeleporter:Teleport(doer)
    local winonateleportpadmanager = TheWorld.components.winonateleportpadmanager
    local targets = winonateleportpadmanager and winonateleportpadmanager:GetAllWinonaTeleportPads() or nil
    if targets ~= nil then
        local exclude_radius_sq = doer:GetPhysicsRadius(0) + TUNING.SKILLS.WINONA.TELEPAD_DETECTION_RADIUS
        exclude_radius_sq = exclude_radius_sq * exclude_radius_sq

        local x, y, z = doer.Transform:GetWorldPosition()
        local closest_outofcamera, closest_outofcameradsq, closest_outofcamerax, closest_outofcameraz
        local furthest_incamera, furthest_incameradsq, furthest_incamerax, furthest_incameraz
        for target, _ in pairs(targets) do
            if self.checkdestinationfn == nil or self.checkdestinationfn(self.inst, target, doer) then
                local x1, y1, z1 = target.Transform:GetWorldPosition()
                local dsq = distsq(x, z, x1, z1)
                if dsq > exclude_radius_sq then
                    if closest_outofcameradsq == nil or dsq < closest_outofcameradsq then
                        closest_outofcamera = target
                        closest_outofcameradsq = dsq
                        closest_outofcamerax, closest_outofcameraz = x1, z1
                    end
                else
                    if furthest_incameradsq == nil or dsq > furthest_incameradsq then
                        furthest_incamera = target
                        furthest_incameradsq = dsq
                        furthest_incamerax, furthest_incameraz = x1, z1
                    end
                end
            end
        end

        if closest_outofcamera ~= nil then
            self:Teleport_Internal(x, z, closest_outofcamerax, closest_outofcameraz, doer)
            return true
        end
        if furthest_incamera ~= nil then
            self:Teleport_Internal(x, z, furthest_incamerax, furthest_incameraz, doer)
            return true
        end
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
