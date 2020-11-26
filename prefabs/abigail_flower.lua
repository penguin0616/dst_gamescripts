local assets =
{
    Asset("ANIM", "anim/abigail_flower.zip"),
    Asset("ANIM", "anim/abigail_flower_rework.zip"),

	Asset("INV_IMAGE", "abigail_flower_level0"),
	Asset("INV_IMAGE", "abigail_flower_level2"),
	Asset("INV_IMAGE", "abigail_flower_level3"),
	
    Asset("INV_IMAGE", "abigail_flower_old"),		-- deprecated, left in for mods
    Asset("INV_IMAGE", "abigail_flower2"),			-- deprecated, left in for mods
    Asset("INV_IMAGE", "abigail_flower_haunted"),	-- deprecated, left in for mods
    Asset("INV_IMAGE", "abigail_flower_wilted"),	-- deprecated, left in for mods
}

local prefabs =
{
}

local function UpdateInventoryActions(inst)
	inst:PushEvent("inventoryitem_updatetooltip")
end

local function UpdateInventoryIcon(inst, player, level)
	if inst._playerlink ~= player then
		if inst._playerlink ~= nil then
			inst:RemoveEventCallback("ghostlybond_level_change", inst._updateinventoryiconfn, inst._playerlink)
		end

		if player ~= nil and player.components.ghostlybond ~= nil then
			inst._playerlink = player
			inst:ListenForEvent("ghostlybond_level_change", inst._updateinventoryiconfn, inst._playerlink)

			UpdateInventoryActions(inst)
			if inst._inventoryactionstask == nil then
				inst._inventoryactionstask = inst:DoPeriodicTask(0.1, UpdateInventoryActions)
			end
		else
			inst._playerlink = nil

			if inst._inventoryactionstask ~= nil then
				inst._inventoryactionstask:Cancel()
				inst._inventoryactionstask = nil
			end
		end
	end

	level = level or (player ~= nil and player.components.ghostlybond ~= nil) and player.components.ghostlybond.bondlevel or 0
	if level == 1 then
		inst.components.inventoryitem:ChangeImageName((inst:GetSkinName() or "abigail_flower"))
	else
		inst.components.inventoryitem:ChangeImageName((inst:GetSkinName() or "abigail_flower") .. "_level" .. tostring(level or 0))
	end
	inst._bond_level = level
end

local function UpdateGroundAnimation(inst)
	local x, y, z = inst.Transform:GetWorldPosition()
    local players = {}
	if not POPULATING then
		for i, v in ipairs(AllPlayers) do
			if v:HasTag("ghostlyfriend") and not v.replica.health:IsDead() and not v:HasTag("playerghost") and v.components.ghostlybond ~= nil and v.entity:IsVisible() and (v.sg == nil or not v.sg:HasStateTag("ghostbuild")) then
				local dist = v:GetDistanceSqToPoint(x, y, z)
				if dist < TUNING.ABIGAIL_FLOWER_PROX_DIST then
					table.insert(players, {player = v, dist = dist})
				end
			end
		end
	end    

	if #players > 1 then
		table.sort(players, function(a, b) return a.dist < b.dist end)
	end

	local level = players[1] ~= nil and players[1].player.components.ghostlybond.bondlevel or 0
	if inst._bond_level ~= level then
		if inst._bond_level == 0 then
			inst.AnimState:PlayAnimation("level"..level.."_pre")
			inst.AnimState:PushAnimation("level"..level.."_loop", true)
			inst.SoundEmitter:PlaySound("dontstarve/characters/wendy/abigail/haunted_flower_LP", "floating")
		elseif inst._bond_level > 0 and level == 0 then
			inst.AnimState:PlayAnimation("level"..inst._bond_level.."_pst")
			inst.AnimState:PushAnimation("level0_loop", true)
            inst.SoundEmitter:KillSound("floating")
		else
			inst.AnimState:PlayAnimation("level"..level.."_loop", true)
			inst.SoundEmitter:PlaySound("dontstarve/characters/wendy/abigail/haunted_flower_LP", "floating")
		end
	end

	inst._bond_level = level
end

local function UnlinkFromPlayer(inst)
	if inst._playerlink ~= nil then
		inst:RemoveEventCallback("ghostlybond_level_change", inst._updateinventoryiconfn, inst._playerlink)
		inst._playerlink = nil
	end

	if inst._inventoryactionstask ~= nil then
		inst._inventoryactionstask:Cancel()
		inst._inventoryactionstask = nil
	end
end

local function topocket(inst, owner)
	if inst._incontainer ~= nil then
		inst:RemoveEventCallback("onopen", inst._oncontaineropenedfn, inst._incontainer)
		inst:RemoveEventCallback("onclose", inst._oncontainerclosedfn, inst._incontainer)
		inst._incontainer = nil
	end

	owner = owner or inst.components.inventoryitem:GetGrandOwner()
	if owner.components.container ~= nil then
		inst._incontainer = owner
		inst:ListenForEvent("onopen", inst._oncontaineropenedfn, inst._incontainer)
		inst:ListenForEvent("onclose", inst._oncontainerclosedfn, inst._incontainer)

		owner = owner.components.container.opener
	end
	UpdateInventoryIcon(inst, owner)

	if inst._ongroundupdatetask ~= nil then
		inst._ongroundupdatetask:Cancel()
		inst._ongroundupdatetask = nil
	end
end

local function toground(inst)
	UnlinkFromPlayer(inst)

	if inst._incontainer ~= nil then
	    inst:RemoveEventCallback("onopen", inst._oncontaineropenedfn, inst._incontainer)
	    inst:RemoveEventCallback("onclose", inst._oncontainerclosedfn, inst._incontainer)
		inst._incontainer = nil
	end

	inst._bond_level = -1 -- to force the animation to update
	UpdateGroundAnimation(inst)
	if inst._ongroundupdatetask == nil then
		inst._ongroundupdatetask = inst:DoPeriodicTask(0.5, UpdateGroundAnimation)
	end
end

local function OnEntitySleep(inst)
	if inst._ongroundupdatetask ~= nil then
		inst._ongroundupdatetask:Cancel()
		inst._ongroundupdatetask = nil
	end
end

local function OnEntityWake(inst)
	if not inst.inlimbo and inst._ongroundupdatetask == nil then
		inst._ongroundupdatetask = inst:DoPeriodicTask(0.5, UpdateGroundAnimation, math.random()*0.5)
	end
end

local function GetElixirTarget(inst, doer, elixir)
	return (doer ~= nil and doer.components.ghostlybond ~= nil) and doer.components.ghostlybond.ghost or nil
end

local function getstatus(inst)
	return inst._bond_level == 3 and "LEVEL3"
		or inst._bond_level == 2 and "LEVEL2"
		or inst._bond_level == 1 and "LEVEL1"
		or nil
end

local function OnSkinIDDirty(inst)
	inst.skin_id = inst.flower_skin_id:value()
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

    inst.AnimState:SetBank("abigail_flower_rework")
    inst.AnimState:SetBuild("abigail_flower_rework")
    inst.AnimState:PlayAnimation("level0_loop")
    MakeInventoryPhysics(inst)

    inst.MiniMapEntity:SetIcon("abigail_flower.png")

    MakeInventoryFloatable(inst, "small", 0.15, 0.9)

	inst:AddTag("abigail_flower")
	inst:AddTag("give_dolongaction")
	inst:AddTag("ghostlyelixirable") -- for ghostlyelixirable component

	inst.entity:SetPristine()
	
    inst.flower_skin_id = net_hash(inst.GUID, "abi_flower_skin_id", "abiflowerskiniddirty")
	inst:ListenForEvent("abiflowerskiniddirty", OnSkinIDDirty)

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inventoryitem")
    inst:AddComponent("lootdropper")

    inst:AddComponent("inspectable")
    inst.components.inspectable.getstatus = getstatus

	inst:AddComponent("summoningitem")

	inst:AddComponent("ghostlyelixirable")
	inst.components.ghostlyelixirable.overrideapplytotargetfn = GetElixirTarget

    MakeSmallBurnable(inst, TUNING.SMALL_BURNTIME)
	inst.components.burnable.fxdata = {}
    inst.components.burnable:AddBurnFX("campfirefire", Vector3(0, 0, 0))
	

    MakeSmallPropagator(inst)
    MakeHauntableLaunch(inst)

	inst._updateinventoryiconfn = function(player, data) UpdateInventoryIcon(inst, player, data.level) end
	inst._oncontaineropenedfn = function(container, data) UpdateInventoryIcon(inst, data.doer) end
	inst._oncontainerclosedfn = function(container, data) UnlinkFromPlayer(inst) end

    inst:ListenForEvent("onputininventory", topocket)
    inst:ListenForEvent("ondropped", toground)

    inst.OnEntitySleep = OnEntitySleep
    inst.OnEntityWake = OnEntityWake

	inst._ongroundupdatetask = inst:DoPeriodicTask(0.5, UpdateGroundAnimation, math.random()*0.5)
	UpdateInventoryIcon(inst, nil, 0)

    return inst
end


local assets_summonfx =
{
    Asset("ANIM", "anim/wendy_channel_flower.zip"),
    Asset("ANIM", "anim/wendy_mount_channel_flower.zip"),
}

local assets_unsummonfx =
{
    Asset("ANIM", "anim/wendy_recall_flower.zip"),
    Asset("ANIM", "anim/wendy_mount_recall_flower.zip"),
}

local assets_levelupfx =
{
    Asset("ANIM", "anim/abigail_flower_change.zip"),
}

local function AlignToTarget(inst)
	local parent = inst.entity:GetParent()
	if parent ~= nil then
	    inst.Transform:SetRotation(parent.Transform:GetRotation())
	end
end

local function MakeSummonFX(anim, use_anim_for_build, is_mounted)
    return function()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()

        inst:AddTag("FX")

		if is_mounted then
	        inst.Transform:SetSixFaced()
		else
	        inst.Transform:SetFourFaced()
		end

	
        inst.AnimState:SetBank(anim)
		if use_anim_for_build then
	        inst.AnimState:SetBuild(anim)
	        inst.AnimState:OverrideSymbol("flower", "abigail_flower_rework", "flower")
		else
	        inst.AnimState:SetBuild("abigail_flower_rework")
		end
        inst.AnimState:PlayAnimation(anim)

		if is_mounted then
			inst:AddComponent("updatelooper")
			inst.components.updatelooper:AddOnWallUpdateFn(AlignToTarget)
		end

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst.persists = false

        --Anim is padded with extra blank frames at the end
        inst:ListenForEvent("animover", inst.Remove)

        return inst
    end
end

return Prefab("abigail_flower", fn, assets, prefabs),
	Prefab("abigailsummonfx", MakeSummonFX("wendy_channel_flower", true, false), assets_summonfx),
    Prefab("abigailsummonfx_mount", MakeSummonFX("wendy_mount_channel_flower", true, true), assets_summonfx),
	Prefab("abigailunsummonfx", MakeSummonFX("wendy_recall_flower", false, false), assets_unsummonfx),
    Prefab("abigailunsummonfx_mount", MakeSummonFX("wendy_mount_recall_flower", false, true), assets_unsummonfx),
	Prefab("abigaillevelupfx", MakeSummonFX("abigail_flower_change", false, false), assets_levelupfx)


