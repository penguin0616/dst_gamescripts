local assets =
{
	Asset("ANIM", "anim/bearger_mutated_actions_fx.zip"),
}

local function Reverse(inst)
	inst.AnimState:PlayAnimation("atk2")
end

local function MakeFX(name, saturation, lightoverride, facings)
	local function fn()
		local inst = CreateEntity()

		inst.entity:AddTransform()
		inst.entity:AddAnimState()
		inst.entity:AddNetwork()

		inst:AddTag("FX")
		inst:AddTag("NOCLICK")

		if facings == "eight" then
			inst.Transform:SetEightFaced()
		else
			inst.Transform:SetFourFaced()
		end

		inst.AnimState:SetBank("bearger_mutated_actions_fx")
		inst.AnimState:SetBuild("bearger_mutated_actions_fx")
		inst.AnimState:PlayAnimation("atk1")
		inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
		inst.AnimState:SetLayer(LAYER_BACKGROUND)
		inst.AnimState:SetSortOrder(3)
		inst.AnimState:SetSaturation(saturation)
		inst.AnimState:SetLightOverride(lightoverride)

		inst.entity:SetPristine()

		if not TheWorld.ismastersim then
			return inst
		end

		inst.Reverse = Reverse

		inst.persists = false
		inst:ListenForEvent("animover", inst.Remove)

		return inst
	end

	return Prefab(name, fn, assets)
end

return MakeFX("bearger_swipe_fx", 0, 0, "eight"),
	MakeFX("mutatedbearger_swipe_fx", 1, 0.1, "four")
