local MakePlayerCharacter = require("prefabs/player_common")

local assets =
{
    Asset("SCRIPT", "scripts/prefabs/player_common.lua"),
    Asset("SOUND", "sound/maxwell.fsb"),
    Asset("ANIM", "anim/swap_books.zip"),
	Asset("ANIM", "anim/waxwell_tophat.zip"),
	Asset("ANIM", "anim/player_idles_waxwell.zip"),
}

local prefabs =
{
    "waxwell_shadowstriker",
    "shadowdancer",
	"book_fx",
	"book_fx_mount",
	"waxwell_book_fx",
	"waxwell_book_fx_mount",
	"waxwell_shadow_book_fx",
	"waxwell_shadow_book_fx_mount",
}

local start_inv = {}
for k, v in pairs(TUNING.GAMEMODE_STARTING_ITEMS) do
	start_inv[string.lower(k)] = v.WAXWELL
end

prefabs = FlattenTree({ prefabs, start_inv }, true)

local function KillPet(pet)
	if pet.components.health:IsInvincible() then
		--reschedule
		pet._killtask = pet:DoTaskInTime(.5, KillPet)
	else
		pet.components.health:Kill()
	end
end

local function OnSpawnPet(inst, pet)
    if pet:HasTag("shadowminion") then
        if not (inst.components.health:IsDead() or inst:HasTag("playerghost")) then
			--if not inst.components.builder.freebuildmode then
	            inst.components.sanity:AddSanityPenalty(pet, TUNING.SHADOWWAXWELL_SANITY_PENALTY[string.upper(pet.prefab)])
			--end
            inst:ListenForEvent("onremove", inst._onpetlost, pet)
            pet.components.skinner:CopySkinsFromPlayer(inst)
        elseif pet._killtask == nil then
            pet._killtask = pet:DoTaskInTime(math.random(), KillPet)
        end
    elseif inst._OnSpawnPet ~= nil then
        inst:_OnSpawnPet(pet)
    end
end

local function OnDespawnPet(inst, pet)
    if pet:HasTag("shadowminion") then
		if pet.sg ~= nil then
			pet.sg:GoToState("quickdespawn")
		else
			pet:Remove()
		end
    elseif inst._OnDespawnPet ~= nil then
        inst:_OnDespawnPet(pet)
    end
end

local function ReskinPet(pet, player, nofx)
    pet._dressuptask = nil
    if player:IsValid() then
        if not nofx then
            local x, y, z = pet.Transform:GetWorldPosition()
            local fx = SpawnPrefab("slurper_respawn")
            fx.Transform:SetPosition(x, y, z)
        end
        pet.components.skinner:CopySkinsFromPlayer(player)
    end
end

local function OnSkinsChanged(inst, data)
    for k, v in pairs(inst.components.petleash:GetPets()) do
        if v:HasTag("shadowminion") then
            if v._dressuptask ~= nil then
                v._dressuptask:Cancel()
                v._dressuptask = nil
            end
            if data and data.nofx then
                ReskinPet(v, inst, data.nofx)
            else
                v._dressuptask = v:DoTaskInTime(math.random()*0.5 + 0.25, ReskinPet, inst)
            end
        end
    end
end

local function OnDeath(inst)
    for k, v in pairs(inst.components.petleash:GetPets()) do
        if v:HasTag("shadowminion") and v._killtask == nil then
            v._killtask = v:DoTaskInTime(math.random(), KillPet)
        end
    end
end

local function OnReroll(inst)
    local todespawn = {}
    for k, v in pairs(inst.components.petleash:GetPets()) do
        if v:HasTag("shadowminion") then
            table.insert(todespawn, v)
        end
    end
    for i, v in ipairs(todespawn) do
        inst.components.petleash:DespawnPet(v)
    end
end

local SHADOWCREATURE_MUST_TAGS = { "shadowcreature", "_combat", "locomotor" }
local SHADOWCREATURE_CANT_TAGS = { "INLIMBO", "notaunt" }
local function OnReadFn(inst, book)
    if inst.components.sanity:IsInsane() then
        
        local x,y,z = inst.Transform:GetWorldPosition()
        local ents = TheSim:FindEntities(x, y, z, 16, SHADOWCREATURE_MUST_TAGS, SHADOWCREATURE_CANT_TAGS)

        if #ents < TUNING.BOOK_MAX_SHADOWCREATURES then
            TheWorld.components.shadowcreaturespawner:SpawnShadowCreature(inst)
        end
    end
end

local function OnLoad(inst)
	--NOTE: Doing this outside of magician component, because we need to wait for inventory to load as well
	inst.components.magician:StopUsing()
    OnSkinsChanged(inst, {nofx = true})
end

local function GetEquippableDapperness(owner, equippable)
	local dapperness = equippable:GetDapperness(owner, owner.components.sanity.no_moisture_penalty)
	return equippable.inst:HasTag("shadow_item")
		and dapperness * TUNING.WAXWELL_SHADOW_ITEM_RESISTANCE
		or dapperness
end

local function common_postinit(inst)
    inst:AddTag("shadowmagic")
    inst:AddTag("dappereffects")

    inst.AnimState:AddOverrideBuild("player_idles_waxwell")

    if TheNet:GetServerGameMode() == "quagmire" then
        inst:AddTag("quagmire_shopper")
    end

	--magician (from magician component) added to pristine state for optimization
	inst:AddTag("magician")

    --reader (from reader component) added to pristine state for optimization
    inst:AddTag("reader")
end

local function master_postinit(inst)
    inst.starting_inventory = start_inv[TheNet:GetServerGameMode()] or start_inv.default

	inst.customidlestate = "waxwell_funnyidle"

	inst:AddComponent("magician")

    inst:AddComponent("reader")
    inst.components.reader:SetSanityPenaltyMultiplier(TUNING.MAXWELL_READING_SANITY_MULT)
    inst.components.reader:SetOnReadFn(OnReadFn)

    if inst.components.petleash ~= nil then
        inst._OnSpawnPet = inst.components.petleash.onspawnfn
        inst._OnDespawnPet = inst.components.petleash.ondespawnfn
        inst.components.petleash:SetMaxPets(math.huge)
    else
        inst:AddComponent("petleash")
        inst.components.petleash:SetMaxPets(math.huge)
    end
    inst.components.petleash:SetOnSpawnFn(OnSpawnPet)
    inst.components.petleash:SetOnDespawnFn(OnDespawnPet)
    inst:ListenForEvent("onskinschanged", OnSkinsChanged) -- Fashion Shadows.

    inst.components.hunger:SetMax(TUNING.WAXWELL_HUNGER)
    inst.components.sanity:SetMax(TUNING.WAXWELL_SANITY)
    inst.components.sanity.dapperness = TUNING.DAPPERNESS_LARGE
	inst.components.sanity.get_equippable_dappernessfn = GetEquippableDapperness
    inst.components.health:SetMaxHealth(TUNING.WAXWELL_HEALTH)
    inst.soundsname = "maxwell"

    inst.components.foodaffinity:AddPrefabAffinity("lobsterdinner", TUNING.AFFINITY_15_CALORIES_LARGE)

    inst._onpetlost = function(pet) inst.components.sanity:RemoveSanityPenalty(pet) end

    inst:ListenForEvent("death", OnDeath)
    inst:ListenForEvent("ms_becameghost", OnDeath)
    inst:ListenForEvent("ms_playerreroll", OnReroll)

    if TheNet:GetServerGameMode() == "lavaarena" then
        event_server_data("lavaarena", "prefabs/waxwell").master_postinit(inst)
    elseif TheNet:GetServerGameMode() == "quagmire" then
        event_server_data("quagmire", "prefabs/waxwell").master_postinit(inst)
    end

	inst.OnLoad = OnLoad
end

return MakePlayerCharacter("waxwell", prefabs, assets, common_postinit, master_postinit)
