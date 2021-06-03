Approach = Class(BehaviourNode, function(self, inst, target, dist, canrun)
    BehaviourNode._ctor(self, "Approach")
    self.inst = inst
    self.target = target

	if type(dist) == "function" then
		self.dist_fn = dist
		self.dist = nil
	else
	    self.dist = dist
	end

    self.canrun = canrun ~= false
    self.currenttarget = nil
end)

function Approach:GetTarget()
    local target = FunctionOrValue(self.target, self.inst)
    return target ~= nil and target:IsValid() and target or nil
end

function Approach:EvaluateDistances() -- this is run once per follow target
	if self.dist_fn ~= nil then
		self.dist = self.dist_fn(self.inst)
	end
end

function Follow:DBString()
    local dist =
        self.currenttarget ~= nil and
        self.currenttarget:IsValid() and
        math.sqrt(self.currenttarget:GetDistanceSqToInst(self.inst)) or 0
    return string.format("%s, (%2.2f) ", tostring(self.currenttarget), dist)
end

local function _distsq(inst, targ)
    local x, y, z = inst.Transform:GetWorldPosition()
    local x1, y1, z1 = targ.Transform:GetWorldPosition()
    local dx = x1 - x
    local dy = y1 - y
    local dz = z1 - z
    --Note: Currently, this is 3D including y-component
    return dx * dx + dy * dy + dz * dz, Vector3(x1, y1, z1)
end

function Approach:AreDifferentPlatforms(my_x, my_z, target_x, target_z)
    if self.inst.components.locomotor.allow_platform_hopping then
        local map = TheWorld.Map
        return map:GetPlatformAtPoint(my_x, my_z) ~= map:GetPlatformAtPoint(target_x, target_z)
    end
    return false
end

function Approach:Visit()
    --cached in case we need to use this multiple times
    local dist_sq, target_pos, on_different_platforms

    if self.status == READY then
		local prev_target = self.currenttarget
        self.currenttarget = self:GetTarget()
        if self.currenttarget ~= nil then
            dist_sq, target_pos = _distsq(self.inst, self.currenttarget)

			if prev_target ~= self.currenttarget then
				self:EvaluateDistances()
			end

            local my_x, my_y, my_z = self.inst.Transform:GetWorldPosition()
            local target_x, target_y, target_z = self.currenttarget.Transform:GetWorldPosition()

            on_different_platforms = self:AreDifferentPlatforms(my_x, my_z, target_x, target_z)

            if on_different_platforms or dist_sq > self.dist * self.dist then
                self.status = RUNNING
            else
                self.status = SUCCESS
            end
        else
            self.status = FAILED
        end
    end

    if self.status == RUNNING then
        if self.currenttarget == nil
            or not self.currenttarget:IsValid()
            or (self.currenttarget.components.health ~= nil and
                self.currenttarget.components.health:IsDead()) then
            self.status = FAILED
            self.inst.components.locomotor:Stop()
            return
        end

        local my_x, my_y, my_z = self.inst.Transform:GetWorldPosition()
        local target_x, target_y, target_z = self.currenttarget.Transform:GetWorldPosition()

        if dist_sq == nil then
            dist_sq, target_pos = _distsq(self.inst, self.currenttarget)
            on_different_platforms = self:AreDifferentPlatforms(my_x, my_z, target_x, target_z)
        end

        if not on_different_platforms and dist_sq < self.dist * self.dist then
            self.status = SUCCESS
            return
        end


        if self.canrun and (on_different_platforms or dist_sq > self.dist * self.dist or self.inst.sg:HasStateTag("running")) then
            self.inst.components.locomotor:GoToPoint(target_pos, nil, true)
        else
            self.inst.components.locomotor:GoToPoint(target_pos)
        end

        self:Sleep(.25)
    end
end
