local defs = {}

-----------------------------------------------------------------------------------------------------------------------------------------------
--Bands
-----------------------------------------------------------------------------------------------------------------------------------------------

defs["slingshot_band_pigskin"] =
{
	slot = "band",
	anim = "idle_pigskin",
	swap_symbol = { "swap_band_top_pigskin", "swap_band_btm_pigskin" },
	skill = "walter_slingshot_modding",
}

local function SetRange(slingshot, bonus)
	slingshot.components.weapon:SetRange(TUNING.SLINGSHOT_DISTANCE + bonus, TUNING.SLINGSHOT_DISTANCE_MAX + bonus)
end

defs.slingshot_band_pigskin.oninstalledfn = function(inst, slingshot)
	SetRange(slingshot, TUNING.SLINGSHOT_MOD_BONUS_RANGE_1)
end

defs.slingshot_band_pigskin.onuninstalledfn = function(inst, slingshot)
	SetRange(slingshot, 0)
end

-----------------------------------------------------------------------------------------------------------------------------------------------

defs["slingshot_band_tentacle"] =
{
	slot = "band",
	anim = "idle_tentacle",
	swap_symbol = { "swap_band_top_tentacle", "swap_band_btm_tentacle" },
	skill = "walter_slingshot_band_tentacle",
}

defs.slingshot_band_tentacle.oninstalledfn = function(inst, slingshot)
	SetRange(slingshot, TUNING.SLINGSHOT_MOD_BONUS_RANGE_2)
end

defs.slingshot_band_tentacle.onuninstalledfn = defs.slingshot_band_pigskin.onuninstalledfn

-----------------------------------------------------------------------------------------------------------------------------------------------

defs["slingshot_band_mimic"] =
{
	slot = "band",
	anim = "idle_mimic",
	swap_symbol = { "swap_band_top_mimic", "swap_band_btm_mimic" },
	skill = "walter_slingshot_band_tentacle",
}

defs.slingshot_band_mimic.oninstalledfn = defs.slingshot_band_tentacle.oninstalledfn
defs.slingshot_band_mimic.onuninstalledfn = defs.slingshot_band_tentacle.onuninstalledfn


-----------------------------------------------------------------------------------------------------------------------------------------------
--Frames
-----------------------------------------------------------------------------------------------------------------------------------------------

local function ReturnAmmoToOwner(slingshot, slot, owner)
	if owner then
		local owner_container = owner.components.inventory or owner.components.container
		local pos = owner:GetPosition()
		while true do
			local ammo = slingshot.components.container:RemoveItemBySlot(slot, true)
			if ammo == nil then
				break
			end
			owner_container:GiveItem(ammo, nil, pos)
		end
	else
		slingshot.components.container:DropItemBySlot(slot)
	end
end

local function MoveAmmoStack(slingshot, slot, newslingshot, newslot)
	local ammo
	if newslingshot.components.container.infinitestacksize then
		slingshot.components.container.ignoreoverstacked = true
		ammo = slingshot.components.container:RemoveItemBySlot(slot)
		slingshot.components.container.ignoreoverstacked = false
	else
		ammo = slingshot.components.container:RemoveItemBySlot(slot, true)
	end
	if ammo then
		if newslingshot.components.container:GiveItem(ammo, newslot) then
			return true
		end
		slingshot.components.container:GiveItem(ammo, slot)
	end
	return false
end

local function TransferAmmo(slingshot, new)
	local numslots = slingshot.components.container:GetNumSlots()
	local newnumslots = new.components.container:GetNumSlots()
	local owner = slingshot.components.inventoryitem:GetGrandOwner()
	for i = 1, numslots do
		while MoveAmmoStack(slingshot, i, new) do end
		ReturnAmmoToOwner(slingshot, i, owner)
	end
end

local function ReplaceSlingshot(slingshot, newprefab)
	local new = SpawnPrefab(newprefab)
	slingshot.components.slingshotmods:TransferPartsTo(new.components.slingshotmods)

	TransferAmmo(slingshot, new)

	local container = slingshot.components.inventoryitem:GetContainer()
	if container then
		local slot = slingshot.components.inventoryitem:GetSlotNum()
		slingshot:Remove()

		if new.components.clientpickupsoundsuppressor then
			new.components.clientpickupsoundsuppressor:IgnoreNextPickupSound()
		end

		local temp = container.ignoresound
		container.ignoresound = true
		container:GiveItem(new, slot)
		container.ignoresound = temp
	else
		local x, y, z = slingshot.Transform:GetWorldPosition()
		slingshot:Remove()
		new.Transform:SetPosition(x, y, z)
	end

	new:PushEvent("installreplacedslingshot")
end

-----------------------------------------------------------------------------------------------------------------------------------------------

defs["slingshot_frame_bone"] =
{
	slot = "frame",
	anim = "idle_bone",
	swap_symbol = "swap_frame_bone",
	usedeferreduninstall = true,
	prefabs = { "slingshot", "slingshot2" },
	skill = "walter_slingshot_modding",
}

defs.slingshot_frame_bone.oninstalledfn = function(inst, slingshot)
	if slingshot.prefab ~= "slingshot2" then
		ReplaceSlingshot(slingshot, "slingshot2")
	end
end

defs.slingshot_frame_bone.onuninstalledfn = function(inst, slingshot)
	if slingshot.prefab == "slingshot2" and not slingshot.components.slingshotmods:HasPartName("slingshot_frame_bone") then
		ReplaceSlingshot(slingshot, "slingshot")
	end
end

-----------------------------------------------------------------------------------------------------------------------------------------------

defs["slingshot_frame_gems"] =
{
	slot = "frame",
	anim = "idle_gems",
	swap_symbol = "swap_frame_gems",
	usedeferreduninstall = true,
	prefabs = { "slingshot", "slingshot2ex" },
	skill = "walter_slingshot_frame_gems",
}

defs.slingshot_frame_gems.oninstalledfn = function(inst, slingshot)
	if slingshot.prefab ~= "slingshot2ex" then
		ReplaceSlingshot(slingshot, "slingshot2ex")
	end
end

defs.slingshot_frame_gems.onuninstalledfn = function(inst, slingshot)
	if slingshot.prefab == "slingshot2ex" and not slingshot.components.slingshotmods:HasPartName("slingshot_frame_gems") then
		ReplaceSlingshot(slingshot, "slingshot")
	end
end

-----------------------------------------------------------------------------------------------------------------------------------------------

defs["slingshot_frame_wagpunk"] =
{
	slot = "frame",
	anim = "idle_wagpunk",
	swap_symbol = "swap_frame_wagpunk",
	usedeferreduninstall = true,
	prefabs = { "slingshot", "slingshotex" },
	skill = "walter_slingshot_frame_wagpunk",
}

defs.slingshot_frame_wagpunk.oninstalledfn = function(inst, slingshot)
	if slingshot.prefab ~= "slingshotex" then
		ReplaceSlingshot(slingshot, "slingshotex")
	end
end

defs.slingshot_frame_wagpunk.onuninstalledfn = function(inst, slingshot)
	if slingshot.prefab == "slingshotex" and not slingshot.components.slingshotmods:HasPartName("slingshot_frame_wagpunk") then
		ReplaceSlingshot(slingshot, "slingshot")
	end
end

-----------------------------------------------------------------------------------------------------------------------------------------------
--Handles
-----------------------------------------------------------------------------------------------------------------------------------------------

defs["slingshot_handle_sticky"] =
{
	slot = "handle",
	anim = "idle_goop",
	swap_symbol = "swap_handle_goop",
	usedeferreduninstall = true,
	skill = "walter_slingshot_handle_sticky",
}

local function handle_sticky_onequipped(slingshot, data)
	slingshot:AddTag("nosteal")
end

local function handle_stick_onunequipped(slingshot, data)
	slingshot:RemoveTag("nosteal")
end

defs.slingshot_handle_sticky.oninstalledfn = function(inst, slingshot)
	if not slingshot._hasstickyhandle then
		slingshot._hasstickyhandle = true
		slingshot:ListenForEvent("equipped", handle_sticky_onequipped)
		slingshot:ListenForEvent("unequipped", handle_stick_onunequipped)
		if slingshot.components.equippable:IsEquipped() then
			slingshot:AddTag("nosteal")
		end
	end
end

defs.slingshot_handle_sticky.onuninstalledfn = function(inst, slingshot)
	if slingshot._hasstickyhandle and not slingshot.components.slingshotmods:HasPartName("slingshot_handle_sticky") then
		slingshot._hasstickyhandle = nil
		slingshot:RemoveEventCallback("equipped", handle_sticky_onequipped)
		slingshot:RemoveEventCallback("unequipped", handle_stick_onunequipped)
		if slingshot.components.equippable:IsEquipped() then
			slingshot:RemoveTag("nosteal")
		end
	end
end

-----------------------------------------------------------------------------------------------------------------------------------------------

defs["slingshot_handle_silk"] =
{
	slot = "handle",
	anim = "idle_silk",
	swap_symbol = "swap_handle_silk",
	skill = "walter_slingshot_modding",
}

-----------------------------------------------------------------------------------------------------------------------------------------------

defs["slingshot_handle_voidcloth"] =
{
	slot = "handle",
	anim = "idle_voidcloth",
	swap_symbol = "swap_handle_voidcloth",
	skill = "walter_slingshot_handle_voidcloth",
}

-----------------------------------------------------------------------------------------------------------------------------------------------

return defs
