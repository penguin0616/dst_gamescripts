local function OnReactivate(attacker)
    attacker._shadowdsubmissive_task = nil
	attacker:RemoveTag("shadowdominance_null")
end

local function OnAttacked(inst, data)
    if data ~= nil and data.attacker ~= nil then
        if data.attacker._shadowdsubmissive_task ~= nil then
            data.attacker._shadowdsubmissive_task:Cancel()
		else
			data.attacker:AddTag("shadowdominance_null")
        end
        data.attacker._shadowdsubmissive_task = data.attacker:DoTaskInTime(inst.components.shadowsubmissive.forgetattackertime, OnReactivate)
    end
end

local ShadowSubmissive = Class(function(self, inst)
    self.inst = inst

    self.forgetattackertime = 12

	--V2C: Recommended to explicitly add tag to prefab pristine state
	inst:AddTag("shadowsubmissive")

    inst:ListenForEvent("attacked", OnAttacked)
end)

function ShadowSubmissive:OnRemoveFromEntity()
	inst:RemoveTag("shadowsubmissive")
    self.inst:RemoveEventCallback("attacked", OnAttacked)
end

function ShadowSubmissive:ShouldSubmitToTarget(target)
    return target ~= nil
        and target._shadowdsubmissive_task == nil
        and self:TargetHasDominance(target)
end

function ShadowSubmissive:TargetHasDominance(target)
    return target ~= nil
        and target.components.inventory ~= nil
        and target:IsValid()
        and target.components.inventory:EquipHasTag("shadowdominance")
end

return ShadowSubmissive
