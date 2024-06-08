local MakePlayerCharacter = require("prefabs/player_common")

local assets =
{
    Asset("SCRIPT", "scripts/prefabs/player_common.lua"),
    Asset("SOUND", "sound/winona.fsb"),
    Asset("ANIM", "anim/player_idles_winona.zip"),
	Asset("ANIM", "anim/winona_remotecast.zip"),
	Asset("ANIM", "anim/player_mount_winona_remotecast.zip"),
	Asset("ANIM", "anim/winona_death.zip"),
	Asset("ANIM", "anim/winona_teleport.zip"),
    Asset("SCRIPT", "scripts/prefabs/skilltree_winona.lua"),
}

local prefabs = {
    "inspectaclesbox", -- NOTES(JBK): From inspectaclesparticipant component.
	"inspectaclesbox2",
	"charlieresidue", -- From roseinspectableuser component.
	"flower_rose",
	"rose_petals_fx",
}

local start_inv = {}
for k, v in pairs(TUNING.GAMEMODE_STARTING_ITEMS) do
    start_inv[string.lower(k)] = v.WINONA
end

prefabs = FlattenTree({prefabs, start_inv}, true)

local function GetPointSpecialActions(inst, pos, useitem, right, usereticulepos)
	if right then
		if useitem == nil then
			local inventory = inst.replica.inventory
			if inventory ~= nil then
				useitem = inventory:GetEquippedItem(EQUIPSLOTS.HEAD)
			end
		end
		if useitem and
			useitem.prefab == "roseglasseshat" and
			useitem:HasTag("closeinspector")
		then
			--match ReticuleTargetFn
			if usereticulepos then
				local pos2 = Vector3()
				for r = 2.5, 1, -.25 do
					pos2.x, pos2.y, pos2.z = inst.entity:LocalToWorldSpace(r, 0, 0)
					if CLOSEINSPECTORUTIL.IsValidPos(inst, pos2) then
						return { ACTIONS.LOOKAT }, pos2
					end
				end
			end

			--default, input pos is just the player's position
			if CLOSEINSPECTORUTIL.IsValidPos(inst, pos) then
				return { ACTIONS.LOOKAT }
			end
		end
	end
	return {}
end

local function ReticuleTargetFn()
	local player = ThePlayer
	local ground = TheWorld.Map
	local pos = Vector3()
	for r = 2.5, 1, -.25 do
		pos.x, pos.y, pos.z = player.entity:LocalToWorldSpace(r, 0, 0)
		if CLOSEINSPECTORUTIL.IsValidPos(player, pos) then
			return pos
		end
	end
	pos.x, pos.y, pos.z = player.Transform:GetWorldPosition()
	return pos
end

local function OnSetOwner(inst)
	if inst.components.playeractionpicker then
		inst.components.playeractionpicker.pointspecialactionsfn = GetPointSpecialActions
	end
end

local function OnDeactivateSkill(inst, data)
	if data then
		if data.skill == "winona_wagstaff_2" then
			inst.components.builder:RemoveRecipe("winona_teleport_pad")
			inst.components.builder:RemoveRecipe("winona_telebrella")
		elseif data.skill == "winona_wagstaff_1" then
			inst.components.builder:RemoveRecipe("winona_storage_robot")
		end
	end
end

local function OnSave(inst, data)
	data.charlie_vinesave = inst.charlie_vinesave
end

local function OnPreLoad(inst, data, ents)
	inst.charlie_vinesave = data.charlie_vinesave or inst.charlie_vinesave
end

local function OnLoad(inst, data, ents)
	if not inst.components.health:IsDead() then
		inst.charlie_vinesave = nil
	end
end

local function common_postinit(inst)
    inst:AddTag("handyperson")
	inst:AddTag("basicengineer") --tag for non-portable machines so we can forget these when we unlock portable recipes
    inst:AddTag("fastbuilder")
    inst:AddTag("hungrybuilder")

    if TheNet:GetServerGameMode() == "quagmire" then
        inst:AddTag("quagmire_fasthands")
        inst:AddTag("quagmire_shopper")
    end

    inst:AddComponent("inspectaclesparticipant")

	inst:AddComponent("reticule")
	inst.components.reticule.targetfn = ReticuleTargetFn
	inst.components.reticule.ease = true

	inst:ListenForEvent("setowner", OnSetOwner)
end

local function master_postinit(inst)
    inst.starting_inventory = start_inv[TheNet:GetServerGameMode()] or start_inv.default

    inst.components.health:SetMaxHealth(TUNING.WENDY_HEALTH)
    inst.components.hunger:SetMax(TUNING.WENDY_HUNGER)
    inst.components.sanity:SetMax(TUNING.WENDY_SANITY)

    inst.components.foodaffinity:AddPrefabAffinity("vegstinger", TUNING.AFFINITY_15_CALORIES_MED)

    inst.customidleanim = "idle_winona"

    inst.components.grue:SetResistance(1)

    if TheNet:GetServerGameMode() == "lavaarena" then
        event_server_data("lavaarena", "prefabs/winona").master_postinit(inst)
    else
        inst:AddComponent("roseinspectableuser")

		inst:ListenForEvent("ondeactivateskill_server", OnDeactivateSkill)

		inst.OnSave = OnSave
		inst.OnPreLoad = OnPreLoad
		inst.OnLoad = OnLoad
    end
end

return MakePlayerCharacter("winona", prefabs, assets, common_postinit, master_postinit)
