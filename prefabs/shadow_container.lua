local assets =
{
	Asset("ANIM", "anim/ui_portal_shadow_3x4.zip"),
}

local function OnAnyOpenStorage(inst, data)
	if inst.components.container.opencount > 1 then
		--multiple users, make it global to all players now
		inst.Network:SetClassifiedTarget(nil)
	else
		--just one user, only network to that player
		inst.Network:SetClassifiedTarget(data.doer)
	end
end

local function OnAnyCloseStorage(inst, data)
	local opencount = inst.components.container.opencount
	if opencount == 0 then
		--all closed, disable networking
		inst.Network:SetClassifiedTarget(inst)
	elseif opencount == 1 then
		--only one user remaining, only network to that player
		local opener = next(inst.components.container.openlist)
		inst.Network:SetClassifiedTarget(opener)
	end
end

local function fn()
	local inst = CreateEntity()

	if TheWorld.ismastersim then
		inst.entity:AddTransform() --So we can save
	end
	inst.entity:AddNetwork()
	inst.entity:AddServerNonSleepable()
	inst.entity:SetCanSleep(false)
	inst.entity:Hide()
	inst:AddTag("CLASSIFIED")

	inst:AddTag("spoiler")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst.Network:SetClassifiedTarget(inst)

	inst:AddComponent("container")
	inst.components.container:WidgetSetup("shadow_container")
	inst.components.container.skipclosesnd = true
	inst.components.container.skipopensnd = true
	inst.components.container.skipautoclose = true
	inst.components.container.onanyopenfn = OnAnyOpenStorage
	inst.components.container.onanyclosefn = OnAnyCloseStorage

	local count = 0
	inst:ListenForEvent("ms_shadow_container_ping", function(world, proxy)
		if proxy ~= nil and proxy.components.container_proxy ~= nil then
			proxy.components.container_proxy:SetMaster(inst)
			count = count + 1
		end
	end, TheWorld)
	inst:ListenForEvent("ms_detach_container_proxy", function(inst, proxy)
		count = count - 1
		if count == 0 and inst.components.container:IsEmpty() then
			inst:Remove()
		end
	end)

	return inst
end

return Prefab("shadow_container", fn, assets)
