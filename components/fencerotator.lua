local FenceRotator = Class(function(self, inst)
    self.inst = inst
end)

function FenceRotator:Rotate(target, delta)
    if target == nil then
        return
    end

    local angle = target.Transform:GetRotation()
    target.Transform:SetRotation(angle + (delta or TUNING.FENCE_DEFAULT_ROTATION))

    self.inst:PushEvent("fencerotated")

    SpawnPrefab("fence_rotator_fx").Transform:SetPosition(target.Transform:GetWorldPosition())
end

return FenceRotator