local SLINGSHOTPART_DEFS = require("prefabs/slingshotpart_defs")

local assets =
{
	band =
	{
		Asset("SCRIPT", "scripts/prefabs/slingshotpart_defs.lua"),
		Asset("ANIM", "anim/slingshot_bands.zip"),
	},
	frame =
	{
		Asset("SCRIPT", "scripts/prefabs/slingshotpart_defs.lua"),
		Asset("ANIM", "anim/slingshot_frames.zip"),
	},
	handle =
	{
		Asset("SCRIPT", "scripts/prefabs/slingshotpart_defs.lua"),
		Asset("ANIM", "anim/slingshot_handles.zip"),
	},
}

local function ValidContainer(inst, containerinst)
	return containerinst.prefab == "slingshotmodscontainer"
end

local function MakePart(name, def)
	local function fn()
		local inst = CreateEntity()

		inst.entity:AddTransform()
		inst.entity:AddAnimState()
		inst.entity:AddNetwork()

		MakeInventoryPhysics(inst)

		local bankbuild

		if def.slot == "band" then
			bankbuild = "slingshot_bands"
			inst:AddTag("slingshot_band")
			MakeInventoryFloatable(inst, "small", 0.14, { 0.9, 0.93, 1 })
		elseif def.slot == "frame" then
			bankbuild = "slingshot_frames"
			inst:AddTag("slingshot_frame")
			MakeInventoryFloatable(inst, "small", 0.17, { 1.1, 1, 1 })
		elseif def.slot == "handle" then
			bankbuild = "slingshot_handles"
			inst:AddTag("slingshot_handle")
			MakeInventoryFloatable(inst, "small", 0.19, { 0.9, 1, 1 })
		end

		inst.AnimState:SetBank(bankbuild)
		inst.AnimState:SetBuild(bankbuild)
		inst.AnimState:PlayAnimation(def.anim)

		inst:AddComponent("containerinstallableitem")
		inst.components.containerinstallableitem:SetValidContainerFn(ValidContainer)

		inst:AddComponent("clientpickupsoundsuppressor")

		inst.REQUIRED_SKILL = def.skill

		inst.entity:SetPristine()

		if not TheWorld.ismastersim then
			return inst
		end

		inst.slingshot_slot = def.slot
		inst.swap_build = bankbuild
		inst.swap_symbol = def.swap_symbol

		inst:AddComponent("inspectable")
		inst:AddComponent("inventoryitem")

		inst.components.containerinstallableitem:SetInstalledFn(def.oninstalledfn)
		inst.components.containerinstallableitem:SetUninstalledFn(def.onuninstalledfn)
		inst.components.containerinstallableitem:SetUseDeferredUninstall(def.usedeferreduninstall)

		return inst
	end

	return Prefab(name, fn, assets[def.slot], def.prefabs)
end

local ret = {}
for k, v in pairs(SLINGSHOTPART_DEFS) do
	table.insert(ret, MakePart(k, v))
end
return unpack(ret)
