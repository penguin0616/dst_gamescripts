local MakePlayerCharacter = require("prefabs/player_common")

local assets =
{
    Asset("SCRIPT", "scripts/prefabs/player_common.lua"),
    Asset("ANIM", "anim/beard.zip"),
    Asset("ANIM", "anim/ui_beard_3x1.zip"),
    Asset("ANIM", "anim/ui_beard_2x1.zip"),
    Asset("ANIM", "anim/ui_beard_1x1.zip"),
}

local prefabs =
{
    "beardhair",
    "beard_sack_1",
    "beard_sack_2",
    "beard_sack_3",
}

local start_inv = {}
for k, v in pairs(TUNING.GAMEMODE_STARTING_ITEMS) do
	start_inv[string.lower(k)] = v.WILSON
end

prefabs = FlattenTree({ prefabs, start_inv }, true)

local function GetPointSpecialActions(inst, pos, useitem, right)
	if right then
		if useitem == nil then
			local inventory = inst.replica.inventory
			if inventory ~= nil then
				useitem = inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
			end
		end
		if useitem ~= nil and useitem:HasTag("special_action_toss") and inst.components.skilltreeupdater:IsActivated("wilson_torch_7") then
			return { ACTIONS.TOSS }
		end
	end
	return {}
end

local function ReticuleTargetFn()
	local player = ThePlayer
	local ground = TheWorld.Map
	local pos = Vector3()
	--Toss range is 8
	for r = 6.5, 1, -.25 do
		pos.x, pos.y, pos.z = player.entity:LocalToWorldSpace(r, 0, 0)
		if ground:IsPassableAtPoint(pos:Get()) and not ground:IsGroundTargetBlocked(pos) then
			return pos
		end
	end
	pos.x, pos.y, pos.z = player.Transform:GetWorldPosition()
	return pos
end

local function OnSetOwner(inst)
	if inst.components.playeractionpicker ~= nil then
		inst.components.playeractionpicker.pointspecialactionsfn = GetPointSpecialActions
	end
end

local function common_postinit(inst)
    if TheNet:GetServerGameMode() == "quagmire" then
        inst:AddTag("quagmire_foodie")
        inst:AddTag("quagmire_potmaster")
        inst:AddTag("quagmire_shopper")
    end
    
    --bearded (from beard component) added to pristine state for optimization
    inst:AddTag("bearded")

	inst:AddComponent("reticule")
	inst.components.reticule.targetfn = ReticuleTargetFn
	inst.components.reticule.ease = true

	inst:ListenForEvent("setowner", OnSetOwner)
end

local function OnResetBeard(inst)
    inst.AnimState:ClearOverrideSymbol("beard")
end

--tune the beard economy...
local BEARD_DAYS =           { 4, 8, 16 }
local BEARD_DAYS_SKILL_I =   { 3, 7, 15 }
local BEARD_DAYS_SKILL_II =  { 3, 6, 13 }
local BEARD_DAYS_SKILL_III = { 2, 5, 11 }

local BEARD_BITS = { 
                    TUNING.WILSON_BEARD_BITS.LEVEL1, 
                    TUNING.WILSON_BEARD_BITS.LEVEL2,
                    TUNING.WILSON_BEARD_BITS.LEVEL3,
                }

local function OnGrowShortBeard(inst, skinname)
    if skinname == nil then
        inst.AnimState:OverrideSymbol("beard", "beard", "beard_short")
    else
        inst.AnimState:OverrideSkinSymbol("beard", skinname, "beard_short" )
    end
    inst.components.beard.bits = BEARD_BITS[1]
end

local function OnGrowMediumBeard(inst, skinname)
    if skinname == nil then
        inst.AnimState:OverrideSymbol("beard", "beard", "beard_medium")
    else
        inst.AnimState:OverrideSkinSymbol("beard", skinname, "beard_medium" )
    end
    inst.components.beard.bits = BEARD_BITS[2]
end

local function OnGrowLongBeard(inst, skinname)
    if skinname == nil then
        inst.AnimState:OverrideSymbol("beard", "beard", "beard_long")
    else
        inst.AnimState:OverrideSkinSymbol("beard", skinname, "beard_long" )
    end
    inst.components.beard.bits = BEARD_BITS[3]
end

local function skills_upgradebeardspeed(inst)
    if inst.components.skilltreeupdater:IsActivated("wilson_beard_6") then
        local data = BEARD_DAYS_SKILL_III
        inst.components.beard:UpdateCallbackTimes(data)
    elseif inst.components.skilltreeupdater:IsActivated("wilson_beard_5") then
        local data = BEARD_DAYS_SKILL_II
        inst.components.beard:UpdateCallbackTimes(data)
    elseif inst.components.skilltreeupdater:IsActivated("wilson_beard_4") then
        local data = BEARD_DAYS_SKILL_I
        inst.components.beard:UpdateCallbackTimes(data)
    end
end

local function EmptyBeard(inst)
    local beard_sack = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.BEARD)
    if beard_sack then
        beard_sack.components.container:DropEverything()
        beard_sack:Remove()
    end
end

local function openbeardsack(inst)
    local beard_sack = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.BEARD)
    print(beard_sack.prefab)
    beard_sack.components.container:Open(inst)
end

local function master_postinit(inst)
    inst.starting_inventory = start_inv[TheNet:GetServerGameMode()] or start_inv.default

    inst.components.foodaffinity:AddPrefabAffinity("baconeggs", TUNING.AFFINITY_15_CALORIES_HUGE)

    inst:AddComponent("beard")
    inst.components.beard.onreset = OnResetBeard
    inst.components.beard.prize = "beardhair"
    inst.components.beard.is_skinnable = true
    inst.components.beard:AddCallback(BEARD_DAYS[1], OnGrowShortBeard)
    inst.components.beard:AddCallback(BEARD_DAYS[2], OnGrowMediumBeard)
    inst.components.beard:AddCallback(BEARD_DAYS[3], OnGrowLongBeard)

    inst.skills_upgradebeardspeed = skills_upgradebeardspeed


    inst.EmptyBeard = EmptyBeard
    inst:ListenForEvent("death", EmptyBeard)
    inst:ListenForEvent("onremove", EmptyBeard)
    --inst:DoTaskInTime(0,openbeardsack)

    if TheNet:GetServerGameMode() == "lavaarena" then
        event_server_data("lavaarena", "prefabs/wilson").master_postinit(inst)
    end
end

return MakePlayerCharacter("wilson", prefabs, assets, common_postinit, master_postinit)
