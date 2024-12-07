local assets_basic =
{
    Asset("ANIM", "anim/slingshot.zip"),
	Asset("ANIM", "anim/ui_cookpot_1x2.zip"),
}

local assets_ex =
{
	Asset("ANIM", "anim/slingshot.zip"),
	Asset("ANIM", "anim/ui_slingshot_wagpunk.zip"),
	Asset("INV_IMAGE", "slingshot"),
}

local assets_999ex =
{
	Asset("ANIM", "anim/slingshot.zip"),
	Asset("ANIM", "anim/ui_slingshot_wagpunk.zip"),
	Asset("INV_IMAGE", "slingshot"),
}

local assets_2 =
{
	Asset("ANIM", "anim/slingshot.zip"),
	Asset("ANIM", "anim/ui_slingshot_bone.zip"),
	Asset("INV_IMAGE", "slingshot"),
}

local assets_2ex =
{
	Asset("ANIM", "anim/slingshot.zip"),
	Asset("ANIM", "anim/ui_slingshot_gems.zip"),
	Asset("INV_IMAGE", "slingshot"),
}

local prefabs_basic =
{
    "slingshotammo_rock_proj",
	"slingshotmodscontainer",
	"slingshotparts_fx",
}

local prefabs_ex =
{
	"slingshotammo_rock_proj",
	"slingshotmodscontainer",
	"slingshotparts_fx",
	"reticulecharging",
	"reticulelongping",
}

local prefabs_2ex =
{
	"slingshotammo_rock_proj",
	"slingshotmodscontainer",
	"slingshotparts_fx",
	"reticulelong",
	"reticulelongping",
}

local SCRAPBOOK_DEPS =
{
    "slingshotammo_rock",
    "slingshotammo_gold",
    "slingshotammo_marble",
    "slingshotammo_thulecite",
	"slingshotammo_honey",
    "slingshotammo_freeze",
    "slingshotammo_slow",
    "slingshotammo_poop",
    "slingshotammo_stinger",
    "slingshotammo_moonglass",
    "slingshotammo_dreadstone",
    "slingshotammo_gunpowder",
    "slingshotammo_lunarplanthusk",
	"slingshotammo_purebrilliance",
    "slingshotammo_horrorfuel",
	"slingshotammo_gelblob",
    "slingshotammo_scrapfeather",
    "trinket_1",
}

-----------------------------------------------------------------------------------------------------------------------------------------------

local function CreateFollowFx(inst, anim, owner, frame1, frame2)
	local fx = SpawnPrefab("slingshotparts_fx")
	fx.entity:SetParent(owner.entity)
	fx.AnimState:PlayAnimation(anim)
	fx.Follower:FollowSymbol(owner.GUID, "swap_object", 0, 0, 0, true, false, frame1, frame2)
	return fx
end

local function RefreshBand(inst, owner)
	local build, symbol = inst.components.slingshotmods:GetPartBuildAndSymbol("band")
	if symbol then
		if inst.fx then
			for i, v in ipairs(inst.fx) do
				v.AnimState:OverrideSymbol("swap_band_top", build, symbol[1])
				v.AnimState:OverrideSymbol("swap_band_btm", build, symbol[2])
			end
		end
		if owner then
			owner.AnimState:OverrideSymbol("swap_band_btm", build, symbol[2])
		end
		inst.AnimState:OverrideSymbol("swap_band_top", build, symbol[1])
		inst.AnimState:OverrideSymbol("swap_band_btm", build, symbol[2])
	else
		local skin_build = inst:GetSkinBuild()
		if inst.fx then
			if skin_build then
				for i, v in ipairs(inst.fx) do
					v.AnimState:OverrideItemSkinSymbol("swap_band_top", skin_build, "swap_band_top", inst.GUID, "slingshot")
					v.AnimState:OverrideItemSkinSymbol("swap_band_btm", skin_build, "swap_band_btm", inst.GUID, "slingshot")
				end
			else
				for i, v in ipairs(inst.fx) do
					v.AnimState:ClearOverrideSymbol("swap_band_top")
					v.AnimState:ClearOverrideSymbol("swap_band_btm")
				end
			end
		end
		if owner then
			if skin_build then
				owner.AnimState:OverrideItemSkinSymbol("swap_band_btm", skin_build, "swap_band_btm", inst.GUID, "slingshot")
			else
				owner.AnimState:OverrideSymbol("swap_band_btm", "slingshot", "swap_band_btm")
			end
		end
		inst.AnimState:ClearOverrideSymbol("swap_band_top")
		inst.AnimState:ClearOverrideSymbol("swap_band_btm")
	end
end

local function RefreshFrame(inst)
	local build, symbol = inst.components.slingshotmods:GetPartBuildAndSymbol("frame")
	if symbol then
		if inst.fx then
			for i, v in ipairs(inst.fx) do
				v.AnimState:OverrideSymbol("swap_frame", build, symbol)
			end
		end
		inst.AnimState:OverrideSymbol("swap_frame", build, symbol)
	else
		if inst.fx then
			for i, v in ipairs(inst.fx) do
				v.AnimState:ClearOverrideSymbol("swap_frame")
			end
		end
		inst.AnimState:ClearOverrideSymbol("swap_frame")
	end
end

local function RefreshHandle(inst)
	local build, symbol = inst.components.slingshotmods:GetPartBuildAndSymbol("handle")
	if symbol then
		if inst.fx then
			for i, v in ipairs(inst.fx) do
				v.AnimState:OverrideSymbol("swap_handle", build, symbol)
			end
		end
		inst.AnimState:OverrideSymbol("swap_handle", build, symbol)
	else
		if inst.fx then
			for i, v in ipairs(inst.fx) do
				v.AnimState:ClearOverrideSymbol("swap_handle")
			end
		end
		inst.AnimState:ClearOverrideSymbol("swap_handle")
	end
end

local function OnEquip(inst, owner)
	if inst.fx then
		for i, v in ipairs(inst.fx) do
			v:Remove()
		end
	end
	inst.fx =
	{
		CreateFollowFx(inst, "swap_1_to_5", owner, 0, 5),
		CreateFollowFx(inst, "swap_6", owner, 5),
		CreateFollowFx(inst, "swap_7", owner, 6),
		CreateFollowFx(inst, "swap_8", owner, 7),
		CreateFollowFx(inst, "swap_9", owner, 8),
		CreateFollowFx(inst, "swap_17", owner, 16),
	}

    local skin_build = inst:GetSkinBuild()
    if skin_build ~= nil then
        owner:PushEvent("equipskinneditem", inst:GetSkinName())
		for i, v in ipairs(inst.fx) do
			v.AnimState:OverrideItemSkinSymbol("swap_slingshot", skin_build, "swap_slingshot", inst.GUID, "slingshot")
			v.AnimState:OverrideItemSkinSymbol("swap_band_top", skin_build, "swap_band_top", inst.GUID, "slingshot")
			v.AnimState:OverrideItemSkinSymbol("swap_band_btm", skin_build, "swap_band_btm", inst.GUID, "slingshot")
		end
		owner.AnimState:OverrideItemSkinSymbol("swap_band_btm", skin_build, "swap_band_btm", inst.GUID, "slingshot")
	else
		owner.AnimState:OverrideSymbol("swap_band_btm", "slingshot", "swap_band_btm")
    end
	owner.AnimState:OverrideSymbol("swap_object", "slingshot", "swap_empty")
	RefreshBand(inst, owner)
	RefreshFrame(inst)
	RefreshHandle(inst)
    owner.AnimState:Show("ARM_carry")
    owner.AnimState:Hide("ARM_normal")

    if inst.components.container ~= nil then
        inst.components.container:Open(owner)
    end
end

local function OnUnequip(inst, owner)
    owner.AnimState:Hide("ARM_carry")
    owner.AnimState:Show("ARM_normal")
    owner.AnimState:ClearOverrideSymbol("swap_band_btm")

	if inst.fx then
		for i, v in ipairs(inst.fx) do
			v:Remove()
		end
		inst.fx = nil
	end

    local skin_build = inst:GetSkinBuild()
    if skin_build ~= nil then
        owner:PushEvent("unequipskinneditem", inst:GetSkinName())
    end

    if inst.components.container ~= nil then
        inst.components.container:Close()
    end
end

local function OnEquipToModel(inst, owner, from_ground)
    if inst.components.container ~= nil then
        inst.components.container:Close()
    end
end

local function OnProjectileLaunched(inst, attacker, target, proj)
    if attacker ~= nil and attacker.components.rider ~= nil and attacker.components.rider:IsRiding() then
        if proj.SetHighProjectile ~= nil then
            proj:SetHighProjectile()
        end
    end
	if inst.chargedmult and proj.SetChargedMultiplier then
		proj:SetChargedMultiplier(inst.chargedmult)
	end
	if inst.magicamplified and proj.SetMagicAmplified then
		proj:SetMagicAmplified()
	end

	if inst.components.slingshotmods:HasPartName("slingshot_band_mimic") and
		math.random() < TUNING.SLINGSHOT_MOD_FREE_AMMO_CHANCE
	then
		--launched a mimic ammo, so don't deplete real ammo stack
	elseif inst.components.container then
		local ammo_stack = inst.components.container:GetItemInSlot(inst.overrideammoslot or 1)
        local item = inst.components.container:RemoveItem(ammo_stack, false)
        if item ~= nil then
            if item == ammo_stack then
                item:PushEvent("ammounloaded", {slingshot = inst})
            end

            item:Remove()
        end
    end
end

local function OnAmmoLoaded(inst, data)
	if inst.components.weapon and data and data.item and data.slot == 1 then
		inst.components.weapon:SetProjectile(data.item.prefab.."_proj")
		inst:AddTag("ammoloaded")
		data.item:PushEvent("ammoloaded", { slingshot = inst })
    end
end

local function OnAmmoUnloaded(inst, data)
	if inst.components.weapon and data and data.slot == 1 then
		inst.components.weapon:SetProjectile(nil)
		inst:RemoveTag("ammoloaded")
		if data.prev_item then
			data.prev_item:PushEvent("ammounloaded", { slingshot = inst })
		end
	end
end

local function UpdateLinkedItemOwner(inst)
	if not inst.components.slingshotmods:IsLoading() then
		if inst.components.slingshotmods:HasAnyParts() then
			local owner = inst.components.inventoryitem:GetGrandOwner()
			if owner then
				inst.components.linkeditem:LinkToOwnerUserID(owner.userid)
			end
		else
			inst.components.linkeditem:LinkToOwnerUserID(nil)
		end
	end
end

local function OnInstalledPartsChanged(inst, part)
	if part then
		if part.slingshot_slot == "band" then
			RefreshBand(inst, inst.components.equippable:IsEquipped() and inst.components.inventoryitem.owner or nil)
		elseif part.slingshot_slot == "frame" then
			RefreshFrame(inst)
		elseif part.slingshot_slot == "handle" then
			RefreshHandle(inst)
		else
			return --unsupported, shouldn't reach here
		end

		UpdateLinkedItemOwner(inst)
	end
end

local function OnDeconstruct(inst, caster)
	inst.components.slingshotmods:DropAllPartsWithoutUninstalling()
end

-----------------------------------------------------------------------------------------------------------------------------------------------

local function OnStartFloating(inst)
	inst.AnimState:PlayAnimation("float")
end

local function OnStopFloating(inst)
	inst.AnimState:PlayAnimation("idle")
end

local function DisplayNameFn(inst)
	local ownername = inst.components.linkeditem:GetOwnerName()
	return ownername and string.len(ownername) and subfmt(STRINGS.NAMES.SLINGSHOT_FMT, { name = ownername }) or nil
end

local function GetStatus(inst, viewer)
	local owneruserid = inst.components.linkeditem:GetOwnerUserID()
	if owneruserid and owneruserid ~= viewer.userid and viewer:HasTag("slingshot_sharpshooter") then
		--i can use slingshots, but it's not mine
		return "NOT_MINE"
	end
end

-----------------------------------------------------------------------------------------------------------------------------------------------

local function MakeSlingshot(name, assets, prefabs, common_postinit, master_postinit)
	local function fn()
		local inst = CreateEntity()

		inst.entity:AddTransform()
		inst.entity:AddAnimState()
		inst.entity:AddSoundEmitter()
		inst.entity:AddNetwork()

		MakeInventoryPhysics(inst)

		inst.AnimState:SetBank("slingshot")
		inst.AnimState:SetBuild("slingshot")
		inst.AnimState:PlayAnimation("idle")

		inst:AddTag("rangedweapon")
		inst:AddTag("slingshot")

		--weapon (from weapon component) added to pristine state for optimization
		inst:AddTag("weapon")

		inst:AddComponent("slingshotmods")
        inst:AddComponent("linkeditem")
		inst:AddComponent("clientpickupsoundsuppressor")

		inst.displaynamefn = DisplayNameFn

		MakeInventoryFloatable(inst, "med", 0.07, { 0.53, 0.5, 0.5 })

		if common_postinit then
			common_postinit(inst)
		end

		inst.entity:SetPristine()

		if not TheWorld.ismastersim then
			return inst
		end

		inst.scrapbook_adddeps = SCRAPBOOK_DEPS
		inst.scrapbook_weapondamage = { TUNING.SLINGSHOT_AMMO_DAMAGE_ROCKS, TUNING.SLINGSHOT_AMMO_DAMAGE_MAX }

		inst:AddComponent("inspectable")
		inst.components.inspectable.getstatus = GetStatus

		inst:AddComponent("inventoryitem")

		inst.components.linkeditem:SetEquippableRestrictedToOwner(true)

		inst:AddComponent("equippable")
		inst.components.equippable.restrictedtag = "slingshot_sharpshooter"
		inst.components.equippable:SetOnEquip(OnEquip)
		inst.components.equippable:SetOnUnequip(OnUnequip)
		inst.components.equippable:SetOnEquipToModel(OnEquipToModel)

		inst:AddComponent("weapon")
		inst.components.weapon:SetDamage(0)
		inst.components.weapon:SetRange(TUNING.SLINGSHOT_DISTANCE, TUNING.SLINGSHOT_DISTANCE_MAX)
		inst.components.weapon:SetOnProjectileLaunched(OnProjectileLaunched)
		inst.components.weapon:SetProjectile(nil)
		inst.components.weapon:SetProjectileOffset(1)

		inst:AddComponent("container")
		inst.components.container:WidgetSetup(name)
		inst.components.container.canbeopened = false
		inst.components.container.stay_open_on_hide = true
		inst:ListenForEvent("itemget", OnAmmoLoaded)
		inst:ListenForEvent("itemlose", OnAmmoUnloaded)

		inst:ListenForEvent("containerinstalleditem", OnInstalledPartsChanged)
		inst:ListenForEvent("containeruninstalleditem", OnInstalledPartsChanged)
		inst:ListenForEvent("installreplacedslingshot", UpdateLinkedItemOwner)
		inst:ListenForEvent("ondeconstructstructure", OnDeconstruct)

		MakeSmallBurnable(inst, TUNING.SMALL_BURNTIME)
		MakeSmallPropagator(inst)
		MakeHauntableLaunch(inst)

		inst:ListenForEvent("floater_startfloating", OnStartFloating)
		inst:ListenForEvent("floater_stopfloating", OnStopFloating)

		if master_postinit then
			master_postinit(inst)
		end

		return inst
	end

	return Prefab(name, fn, assets, prefabs)
end

--------------------------------------------------------------------------
--reticule and targeting function shared by slingshotex and slingshot2ex

local function ReticuleTargetFn()
	return Vector3(ThePlayer.entity:LocalToWorldSpace(6.5, 0, 0))
end

local function ReticuleMouseTargetFn(inst, mousepos)
	if mousepos ~= nil then
		local x, y, z = inst.Transform:GetWorldPosition()
		local dx = mousepos.x - x
		local dz = mousepos.z - z
		local l = dx * dx + dz * dz
		if l <= 0 then
			return inst.components.reticule.targetpos
		end
		l = 6.5 / math.sqrt(l)
		return Vector3(x + dx * l, 0, z + dz * l)
	end
end

local function ReticuleUpdatePositionFn(inst, pos, reticule, ease, smoothing, dt)
	local x, y, z = inst.Transform:GetWorldPosition()
	reticule.Transform:SetPosition(x, 0, z)
	local rot = -math.atan2(pos.z - z, pos.x - x) / DEGREES
	if ease and dt ~= nil then
		local rot0 = reticule.Transform:GetRotation()
		local drot = rot - rot0
		rot = Lerp((drot > 180 and rot0 + 360) or (drot < -180 and rot0 - 360) or rot0, rot, dt * smoothing)
	end
	reticule.Transform:SetRotation(rot)
end

local function CreateTarget()
	local inst = CreateEntity()

	inst:AddTag("CLASSIFIED")
	--[[Non-networked entity]]
	inst.persists = false

	inst.entity:AddTransform()

	inst:DoTaskInTime(3, inst.Remove)

	return inst
end

local TARGET_RANGE = 30

--------------------------------------------------------------------------

local function slingshotex_RefreshChargeTicks(inst, reticule, ticks)
	if reticule.SetChargeScale then
		local scale = math.min(1, ticks * FRAMES / TUNING.SLINGSHOT_MAX_CHARGE_TIME)
		reticule:SetChargeScale(scale)
	end
end

local function slingshotex_common_postinit(inst)
	inst:SetPrefabNameOverride("slingshot")

	inst:AddComponent("aoecharging")
	inst.components.aoecharging.reticuleprefab = "reticulecharging"
	inst.components.aoecharging.pingprefab = "reticulelongping"
	inst.components.aoecharging:SetRefreshChargeTicksFn(slingshotex_RefreshChargeTicks)
end

local function slingshotex_OnChargedAttack(inst, doer, ticks)
	if inst.components.weapon.projectile then
		local x, y, z = doer.Transform:GetWorldPosition()
		local angle = doer.Transform:GetRotation() * DEGREES
		local target = CreateTarget()
		target.Transform:SetPosition(x + math.cos(angle) * TARGET_RANGE, 0, z - math.sin(angle) * TARGET_RANGE)

		local k = math.min(1, ticks * FRAMES / TUNING.SLINGSHOT_MAX_CHARGE_TIME)
		inst.chargedmult = k * k
		inst.components.weapon:LaunchProjectile(doer, target)
		inst.chargedmult = nil
	end
end

local function slingshotex_RefreshAttunedSkills(inst, owner)
	if owner and inst.components.slingshotmods:CheckRequiredSkillsForPlayer(owner) then
		inst.components.aoecharging:SetEnabled(inst.components.weapon.projectile ~= nil)
	else
		inst.components.aoecharging:SetEnabled(false)
	end
end

--NOTE: this runs separately from the common OnAmmoLoaded/OnAmmoUnloaded handlers
local function slingshotex_CheckChargeAmmo(inst, data)
	slingshotex_RefreshAttunedSkills(inst, inst._owner)
end

local function slingshotex_WatchSkillRefresh(inst, owner)
	if inst._owner then
		inst:RemoveEventCallback("onactivateskill_server", inst._onskillrefresh, inst._owner)
		inst:RemoveEventCallback("ondeactivateskill_server", inst._onskillrefresh, inst._owner)
		inst:RemoveEventCallback("itemget", slingshotex_CheckChargeAmmo)
		inst:RemoveEventCallback("itemlose", slingshotex_CheckChargeAmmo)
	end
	inst._owner = owner
	if owner then
		inst:ListenForEvent("onactivateskill_server", inst._onskillrefresh, owner)
		inst:ListenForEvent("ondeactivateskill_server", inst._onskillrefresh, owner)
		inst:ListenForEvent("itemget", slingshotex_CheckChargeAmmo)
		inst:ListenForEvent("itemlose", slingshotex_CheckChargeAmmo)
	end
end

local function slingshotex_OnEquipped(inst, data)
	local owner = data and data.owner or nil
	slingshotex_WatchSkillRefresh(inst, owner)
	slingshotex_RefreshAttunedSkills(inst, owner)
end

local function slingshotex_OnUnequipped(inst, data)
	slingshotex_WatchSkillRefresh(inst, nil)
	slingshotex_RefreshAttunedSkills(inst, nil)
end

local function slingshotex_master_postinit(inst)
	inst.components.inventoryitem:ChangeImageName("slingshot")

	inst.components.aoecharging:SetOnChargedAttackFn(slingshotex_OnChargedAttack)
	inst.components.aoecharging:SetEnabled(false)

	--NOTE: these run separately from the common OnEquip/OnUnequip handlers
	inst:ListenForEvent("equipped", slingshotex_OnEquipped)
	inst:ListenForEvent("unequipped", slingshotex_OnUnequipped)

	inst._onskillrefresh = function(owner) slingshotex_RefreshAttunedSkills(inst, owner) end
end

--------------------------------------------------------------------------

local function slingshot999ex_master_postinit(inst)
	slingshotex_master_postinit(inst)
	inst.components.container:EnableInfiniteStackSize(true)
end

--------------------------------------------------------------------------

local function slingshot2_common_postinit(inst)
	inst:SetPrefabNameOverride("slingshot")
end

local function slingshot2_OnProjectileLaunched(inst, attacker, target, proj)
	OnProjectileLaunched(inst, attacker, target, proj)

	if inst.components.container:GetItemInSlot(1) == nil then
		local ammo = inst.components.container:RemoveItemBySlot(2, true)
		if ammo then
			inst.components.container:GiveItem(ammo, 1)
		end
	end
end

local function slingshot2_master_postinit(inst)
	inst.components.inventoryitem:ChangeImageName("slingshot")
	inst.components.weapon:SetOnProjectileLaunched(slingshot2_OnProjectileLaunched)
end

--------------------------------------------------------------------------

local function slingshot2ex_common_postinit(inst)
	inst:SetPrefabNameOverride("slingshot")

	inst:AddComponent("aoetargeting")
	inst.components.aoetargeting:SetAlwaysValid(true)
	inst.components.aoetargeting.reticule.reticuleprefab = "reticulelong"
	inst.components.aoetargeting.reticule.pingprefab = "reticulelongping"
	inst.components.aoetargeting.reticule.targetfn = ReticuleTargetFn
	inst.components.aoetargeting.reticule.mousetargetfn = ReticuleMouseTargetFn
	inst.components.aoetargeting.reticule.updatepositionfn = ReticuleUpdatePositionFn
	inst.components.aoetargeting.reticule.validcolour = { 1, .75, 0, 1 }
	inst.components.aoetargeting.reticule.invalidcolour = { .5, 0, 0, 1 }
	inst.components.aoetargeting.reticule.ease = true
	inst.components.aoetargeting.reticule.mouseenabled = true
end

local function slingshot2ex_SpellFn(inst, doer, pos)
	local specialammo = inst.components.container:GetItemInSlot(2)
	if specialammo then
		local oldammo = inst.components.container:GetItemInSlot(1)
		if oldammo then
			oldammo:PushEvent("ammounloaded", { slingshot = inst })
		end
		inst.components.weapon:SetProjectile(specialammo.prefab.."_proj")
		specialammo:PushEvent("ammoloaded", { slingshot = inst })

		local x, y, z = doer.Transform:GetWorldPosition()
		local angle = pos.x == x and pos.z == z and doer.Transform:GetRotation() * DEGREES or math.atan2(z - pos.z, pos.x - x)
		local target = CreateTarget()
		target.Transform:SetPosition(x + math.cos(angle) * TARGET_RANGE, 0, z - math.sin(angle) * TARGET_RANGE)

		inst.overrideammoslot = 2
		inst.magicamplified = true
		inst.components.weapon:LaunchProjectile(doer, target)
		inst.magicamplified = nil
		inst.overrideammoslot = nil

		if specialammo:IsValid() then
			specialammo:PushEvent("ammounloaded", { slingshot = inst })
		end
		if oldammo then
			inst.components.weapon:SetProjectile(oldammo.prefab.."_proj")
			oldammo:PushEvent("ammoloaded", { slingshot = inst })
		else
			inst.components.weapon:SetProjectile(nil)
		end
	end
end

local function slingshot2ex_RefreshAttunedSkills(inst, owner)
	if owner and inst.components.slingshotmods:CheckRequiredSkillsForPlayer(owner) then
		inst.components.aoetargeting:SetEnabled(inst.components.container:GetItemInSlot(2) ~= nil)
	else
		inst.components.aoetargeting:SetEnabled(false)
	end
end

--NOTE: this runs separately from the common OnAmmoLoaded/OnAmmoUnloaded handlers
local function slingshot2ex_CheckSpecialAmmo(inst, _)
	slingshot2ex_RefreshAttunedSkills(inst, inst._owner)
end

local function slingshot2ex_WatchSkillRefresh(inst, owner)
	if inst._owner then
		inst:RemoveEventCallback("onactivateskill_server", inst._onskillrefresh, inst._owner)
		inst:RemoveEventCallback("ondeactivateskill_server", inst._onskillrefresh, inst._owner)
		inst:RemoveEventCallback("itemget", slingshot2ex_CheckSpecialAmmo)
		inst:RemoveEventCallback("itemlose", slingshot2ex_CheckSpecialAmmo)
	end
	inst._owner = owner
	if owner then
		inst:ListenForEvent("onactivateskill_server", inst._onskillrefresh, owner)
		inst:ListenForEvent("ondeactivateskill_server", inst._onskillrefresh, owner)
		inst:ListenForEvent("itemget", slingshot2ex_CheckSpecialAmmo)
		inst:ListenForEvent("itemlose", slingshot2ex_CheckSpecialAmmo)
	end
end

local function slingshot2ex_OnEquipped(inst, data)
	local owner = data and data.owner or nil
	slingshot2ex_WatchSkillRefresh(inst, owner)
	slingshot2ex_RefreshAttunedSkills(inst, owner)
end

local function slingshot2ex_OnUnequipped(inst, data)
	slingshot2ex_WatchSkillRefresh(inst, nil)
	slingshot2ex_RefreshAttunedSkills(inst, nil)
end

local function slingshot2ex_master_postinit(inst)
	inst.components.inventoryitem:ChangeImageName("slingshot")

	inst:AddComponent("aoespell")
	inst.components.aoespell:SetSpellFn(slingshot2ex_SpellFn)

	inst.components.aoetargeting:SetEnabled(false)

	--NOTE: these run separately from the common OnEquip/OnUnequip handlers
	inst:ListenForEvent("equipped", slingshot2ex_OnEquipped)
	inst:ListenForEvent("unequipped", slingshot2ex_OnUnequipped)

	inst._onskillrefresh = function(owner) slingshot2ex_RefreshAttunedSkills(inst, owner) end
end

--------------------------------------------------------------------------

local function partsfxfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddFollower()
	inst.entity:AddNetwork()

	inst:AddTag("FX")

	inst.AnimState:SetBank("slingshot")
	inst.AnimState:SetBuild("slingshot")
	inst.AnimState:PlayAnimation("swap_1_to_5")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst.persists = false

	return inst
end

--------------------------------------------------------------------------

return MakeSlingshot("slingshot",	assets_basic,	prefabs_basic),
	MakeSlingshot("slingshotex",	assets_ex,		prefabs_ex,		slingshotex_common_postinit,	slingshotex_master_postinit),
	MakeSlingshot("slingshot999ex",	assets_999ex,	prefabs_ex,		slingshotex_common_postinit,	slingshot999ex_master_postinit),
	MakeSlingshot("slingshot2",		assets_2,		prefabs_basic,	slingshot2_common_postinit,		slingshot2_master_postinit),
	MakeSlingshot("slingshot2ex",	assets_2ex,		prefabs_2ex,	slingshot2ex_common_postinit,	slingshot2ex_master_postinit),
	Prefab("slingshotparts_fx", partsfxfn)
