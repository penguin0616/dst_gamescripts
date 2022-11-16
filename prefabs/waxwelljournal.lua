local assets =
{
	Asset("ANIM", "anim/book_maxwell.zip"),
	Asset("INV_IMAGE", "waxwelljournal_open"),

	Asset("ATLAS", "images/spell_icons.xml"),
	Asset("IMAGE", "images/spell_icons.tex"),
}

local prefabs =
{
	"shadow_pillar_spell",
	"reticuleaoe",
	"reticuleaoeping",
	"reticuleaoecctarget",

	"shadow_trap",
	"reticuleaoe_1_6",
	"reticuleaoeping_1_6",
	"reticuleaoesummontarget_1",

	"shadowworker",
	"shadowprotector",
	"reticuleaoe_1d2_12",
	"reticuleaoeping_1d2_12",
	"reticuleaoesummontarget_1d2",
}

local function SpellCost(pct)
	return pct * TUNING.LARGE_FUEL * -4
end

local function PillarsSpellFn(inst, doer, pos)
	if inst.components.fueled:IsEmpty() then
		return false, "NO_FUEL"
	end
	local spell = SpawnPrefab("shadow_pillar_spell")
	spell.caster = doer
	spell.item = inst
	local platform = TheWorld.Map:GetPlatformAtPoint(pos.x, pos.z)
	if platform ~= nil then
		spell.entity:SetParent(platform.entity)
		spell.Transform:SetPosition(platform.entity:WorldToLocalSpace(pos:Get()))
	else
		spell.Transform:SetPosition(pos:Get())
	end
	inst.components.fueled:DoDelta(SpellCost(TUNING.WAXWELLJOURNAL_SPELL_COST.SHADOW_PILLARS), doer)
	doer.components.sanity:DoDelta(-TUNING.SANITY_MED)
	return true
end

local function TrapSpellFn(inst, doer, pos)
	if inst.components.fueled:IsEmpty() then
		return false, "NO_FUEL"
	end
	local trap = SpawnPrefab("shadow_trap")
	trap.Transform:SetPosition(pos:Get())
	if TheWorld.Map:GetPlatformAtPoint(pos.x, pos.z) ~= nil then
		trap:RemoveTag("ignorewalkableplatforms")
	end
	inst.components.fueled:DoDelta(SpellCost(TUNING.WAXWELLJOURNAL_SPELL_COST.SHADOW_TRAP), doer)
	doer.components.sanity:DoDelta(-TUNING.SANITY_MED)
	return true
end

local function NotBlocked(pt)
	return not TheWorld.Map:IsGroundTargetBlocked(pt)
end

local function FindSpawnPoints(doer, pos, num, radius)
	local ret = {}
	local theta, delta, attempts
	if num > 1 then
		delta = TWOPI / num
		attempts = 3
		theta = doer:GetAngleToPoint(pos) * DEGREES
		if num == 2 then
			theta = theta + PI * (math.random() < .5 and .5 or -.5)
		else
			theta = theta + PI
			if math.random() < .5 then
				delta = -delta
			end
		end
	else
		theta = 0
		delta = 0
		attempts = 1
		radius = 0
	end
	for i = 1, num do
		local offset = FindWalkableOffset(pos, theta, radius, attempts, false, false, NotBlocked, true, true)
		if offset ~= nil then
			table.insert(ret, Vector3(pos.x + offset.x, 0, pos.z + offset.z))
		end
		theta = theta + delta
	end
	return ret
end

local NUM_MINIONS_PER_SPAWN = 1
local function TrySpawnMinions(prefab, doer, pos)
	if doer.components.petleash ~= nil then
		local spawnpts = FindSpawnPoints(doer, pos, NUM_MINIONS_PER_SPAWN, 1)
		if #spawnpts > 0 then
			for i, v in ipairs(spawnpts) do
				local pet = doer.components.petleash:SpawnPetAt(v.x, 0, v.z, prefab)
				if pet ~= nil then
					if pet.SaveSpawnPoint ~= nil then
						pet:SaveSpawnPoint()
					end
					if #spawnpts > 1 and i <= 3 then
						--restart "spawn" state with specified time multiplier
						pet.sg.statemem.spawn = true
						pet.sg:GoToState("spawn",
							(i == 1 and 1) or
							(i == 2 and .8) or
							.87 + math.random() * .06
						)
					end
				end
			end
			return true
		end
	end
	return false
end

local function _CheckMaxSanity(sanity, minionprefab)
	return sanity ~= nil and sanity:GetPenaltyPercent() + (TUNING.SHADOWWAXWELL_SANITY_PENALTY[string.upper(minionprefab)] or 0) * NUM_MINIONS_PER_SPAWN <= TUNING.MAXIMUM_SANITY_PENALTY
end

local function CheckMaxSanity(doer, minionprefab)
	return _CheckMaxSanity(doer.components.sanity, minionprefab)
end

local function ShouldRepeatCastWorker(inst, doer)
	return _CheckMaxSanity(doer.replica.sanity, "shadowworker")
end

local function ShouldRepeatCastProtector(inst, doer)
	return _CheckMaxSanity(doer.replica.sanity, "shadowprotector")
end

local function WorkerSpellFn(inst, doer, pos)
	if inst.components.fueled:IsEmpty() then
		return false, "NO_FUEL"
	elseif not CheckMaxSanity(doer, "shadowworker") then
		return false, "NO_MAX_SANITY"
	elseif TrySpawnMinions("shadowworker", doer, pos) then
		inst.components.fueled:DoDelta(SpellCost(TUNING.WAXWELLJOURNAL_SPELL_COST.SHADOW_WORKER), doer)
		return true
	end
	return false
end

local function ProtectorSpellFn(inst, doer, pos)
	if inst.components.fueled:IsEmpty() then
		return false, "NO_FUEL"
	elseif not CheckMaxSanity(doer, "shadowprotector") then
		return false, "NO_MAX_SANITY"
	elseif TrySpawnMinions("shadowprotector", doer, pos) then
		inst.components.fueled:DoDelta(SpellCost(TUNING.WAXWELLJOURNAL_SPELL_COST.SHADOW_PROTECTOR), doer)
		return true
	end
	return false
end

--[[local function IsTopHat(item)
	return item.prefab == "tophat" and item.components.magiciantool == nil
end

local function TopHatSpellFn(inst, doer)
	if inst.components.fueled:IsEmpty() then
		return false, "NO_FUEL"
	elseif doer.components.inventory ~= nil then
		local tophat = doer.components.inventory:FindItem(IsTopHat)
		if tophat == nil then
			return false, "NO_TOPHAT"
		elseif tophat.ConvertToMagician ~= nil then
			tophat:ConvertToMagician()
			if tophat.components.fueled ~= nil then
				tophat.components.fueled:SetPercent(1)
			end
			local container = tophat.components.inventoryitem:GetContainer()
			if container ~= nil then
				local slot = container:GetItemSlot(tophat)
				container:RemoveItem(tophat, true)
				container:GiveItem(tophat, slot, doer:GetPosition())
			end
			inst.components.fueled:DoDelta(SpellCost(TUNING.WAXWELLJOURNAL_SPELL_COST.SHADOW_TOPHAT), doer)
			doer.components.sanity:DoDelta(-TUNING.SANITY_MED)
			return true
		end
	end
	return false
end]]

--[[local function ReticuleTargetFn()
	local player = ThePlayer
	local ground = TheWorld.Map
	local pos = Vector3()
	--Cast range is 8, leave room for error
	--4 is the aoe range
	for r = 7, 0, -.25 do
		pos.x, pos.y, pos.z = player.entity:LocalToWorldSpace(r, 0, 0)
		if ground:IsPassableAtPoint(pos.x, 0, pos.z) and not ground:IsGroundTargetBlocked(pos) then
			return pos
		end
	end
	return pos
end]]

local function ReticuleTargetAllowWaterFn()
	local player = ThePlayer
	local ground = TheWorld.Map
	local pos = Vector3()
	--Cast range is 8, leave room for error
	--4 is the aoe range
	for r = 7, 0, -.25 do
		pos.x, pos.y, pos.z = player.entity:LocalToWorldSpace(r, 0, 0)
		if ground:IsPassableAtPoint(pos.x, 0, pos.z, true) and not ground:IsGroundTargetBlocked(pos) then
			return pos
		end
	end
	return pos
end

local function StartAOETargeting(inst)
	local playercontroller = ThePlayer.components.playercontroller
	if playercontroller ~= nil then
		playercontroller:StartAOETargetingUsing(inst)
	end
end

local ICON_SCALE = .6
local ICON_RADIUS = 50
local SPELLBOOK_RADIUS = 100
local SPELLBOOK_FOCUS_RADIUS = SPELLBOOK_RADIUS + 2
local SPELLS =
{
	{
		label = STRINGS.SPELLS.SHADOW_WORKER,
		onselect = function(inst)
			inst.components.spellbook:SetSpellName(STRINGS.SPELLS.SHADOW_WORKER)
			inst.components.aoetargeting:SetDeployRadius(0)
			inst.components.aoetargeting:SetShouldRepeatCastFn(ShouldRepeatCastWorker)
			inst.components.aoetargeting.reticule.reticuleprefab = "reticuleaoe_1d2_12"
			inst.components.aoetargeting.reticule.pingprefab = "reticuleaoeping_1d2_12"
			if TheWorld.ismastersim then
				inst.components.aoetargeting:SetTargetFX("reticuleaoesummontarget_1d2")
				inst.components.aoespell:SetSpellFn(WorkerSpellFn)
				inst.components.spellbook:SetSpellFn(nil)
			end
		end,
		execute = StartAOETargeting,
		atlas = "images/spell_icons.xml",
		normal = "shadow_worker.tex",
		widget_scale = ICON_SCALE,
		hit_radius = ICON_RADIUS,
	},
	{
		label = STRINGS.SPELLS.SHADOW_PROTECTOR,
		onselect = function(inst)
			inst.components.spellbook:SetSpellName(STRINGS.SPELLS.SHADOW_PROTECTOR)
			inst.components.aoetargeting:SetDeployRadius(0)
			inst.components.aoetargeting:SetShouldRepeatCastFn(ShouldRepeatCastProtector)
			inst.components.aoetargeting.reticule.reticuleprefab = "reticuleaoe_1d2_12"
			inst.components.aoetargeting.reticule.pingprefab = "reticuleaoeping_1d2_12"
			if TheWorld.ismastersim then
				inst.components.aoetargeting:SetTargetFX("reticuleaoesummontarget_1d2")
				inst.components.aoespell:SetSpellFn(ProtectorSpellFn)
				inst.components.spellbook:SetSpellFn(nil)
			end
		end,
		execute = StartAOETargeting,
		atlas = "images/spell_icons.xml",
		normal = "shadow_protector.tex",
		widget_scale = ICON_SCALE,
		hit_radius = ICON_RADIUS,
	},
	{
		label = STRINGS.SPELLS.SHADOW_TRAP,
		onselect = function(inst)
			inst.components.spellbook:SetSpellName(STRINGS.SPELLS.SHADOW_TRAP)
			inst.components.aoetargeting:SetDeployRadius(1)
			inst.components.aoetargeting:SetShouldRepeatCastFn(nil)
			inst.components.aoetargeting.reticule.reticuleprefab = "reticuleaoe_1_6"
			inst.components.aoetargeting.reticule.pingprefab = "reticuleaoeping_1_6"
			if TheWorld.ismastersim then
				inst.components.aoetargeting:SetTargetFX("reticuleaoesummontarget_1")
				inst.components.aoespell:SetSpellFn(TrapSpellFn)
				inst.components.spellbook:SetSpellFn(nil)
			end
		end,
		execute = StartAOETargeting,
		atlas = "images/spell_icons.xml",
		normal = "shadow_trap.tex",
		widget_scale = ICON_SCALE,
		hit_radius = ICON_RADIUS,
	},
	{
		label = STRINGS.SPELLS.SHADOW_PILLARS,
		onselect = function(inst)
			inst.components.spellbook:SetSpellName(STRINGS.SPELLS.SHADOW_PILLARS)
			inst.components.aoetargeting:SetDeployRadius(0)
			inst.components.aoetargeting:SetShouldRepeatCastFn(nil)
			inst.components.aoetargeting.reticule.reticuleprefab = "reticuleaoe"
			inst.components.aoetargeting.reticule.pingprefab = "reticuleaoeping"
			if TheWorld.ismastersim then
				inst.components.aoetargeting:SetTargetFX("reticuleaoecctarget")
				inst.components.aoespell:SetSpellFn(PillarsSpellFn)
				inst.components.spellbook:SetSpellFn(nil)
			end
		end,
		execute = StartAOETargeting,
		atlas = "images/spell_icons.xml",
		normal = "shadow_pillars.tex",
		widget_scale = ICON_SCALE,
		hit_radius = ICON_RADIUS,
	},
	--[[{
		label = STRINGS.SPELLS.SHADOW_TOPHAT,
		onselect = function(inst)
			inst.components.spellbook:SetSpellName(STRINGS.SPELLS.SHADOW_TOPHAT)
			if TheWorld.ismastersim then
				inst.components.aoespell:SetSpellFn(nil)
				inst.components.spellbook:SetSpellFn(TopHatSpellFn)
			end
		end,
		execute = function(inst)
			local inventory = ThePlayer.replica.inventory
			if inventory ~= nil then
				inventory:CastSpellBookFromInv(inst)
			end
		end,
		atlas = "images/spell_icons.xml",
		normal = "shadow_tophat.tex",
		widget_scale = ICON_SCALE,
		hit_radius = ICON_RADIUS,
	},]]
}

local function OnOpenSpellBook(inst)
	local inventoryitem = inst.replica.inventoryitem
	if inventoryitem ~= nil then
		inventoryitem:OverrideImage("waxwelljournal_open")
	end
end

local function OnCloseSpellBook(inst)
	local inventoryitem = inst.replica.inventoryitem
	if inventoryitem ~= nil then
		inventoryitem:OverrideImage(nil)
	end
end

local function GetStatus(inst, viewer)
	return inst.components.fueled:IsEmpty()
		and inst.components.spellbook:CanBeUsedBy(viewer)
		and "NEEDSFUEL"
		or nil
end

local function OnTakeFuel(inst)
	inst.SoundEmitter:PlaySound("dontstarve/common/nightmareAddFuel")
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddNetwork()

	MakeInventoryPhysics(inst)

	inst.AnimState:SetBank("book_maxwell")
	inst.AnimState:SetBuild("book_maxwell")
	inst.AnimState:PlayAnimation("idle")

	inst:AddTag("book")
	inst:AddTag("shadowmagic")

	MakeInventoryFloatable(inst, "med", nil, 0.75)

	inst:AddComponent("spellbook")
	inst.components.spellbook:SetRequiredTag("shadowmagic")
	inst.components.spellbook:SetRadius(SPELLBOOK_RADIUS)
	inst.components.spellbook:SetFocusRadius(SPELLBOOK_FOCUS_RADIUS)
	inst.components.spellbook:SetItems(SPELLS)
	inst.components.spellbook:SetOnOpenFn(OnOpenSpellBook)
	inst.components.spellbook:SetOnCloseFn(OnCloseSpellBook)
	inst.components.spellbook.opensound = "dontstarve/common/together/book_maxwell/use"
	inst.components.spellbook.closesound = "dontstarve/common/together/book_maxwell/close"
	--inst.components.spellbook.executesound = "dontstarve/common/together/book_maxwell/close"

	inst:AddComponent("aoetargeting")
	inst.components.aoetargeting:SetAllowWater(true)
	inst.components.aoetargeting.reticule.targetfn = ReticuleTargetAllowWaterFn
	inst.components.aoetargeting.reticule.validcolour = { 1, .75, 0, 1 }
	inst.components.aoetargeting.reticule.invalidcolour = { .5, 0, 0, 1 }
	inst.components.aoetargeting.reticule.ease = true
	inst.components.aoetargeting.reticule.mouseenabled = true
	inst.components.aoetargeting.reticule.twinstickmode = 1
	inst.components.aoetargeting.reticule.twinstickrange = 8

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst.swap_build = "book_maxwell"

	inst:AddComponent("inspectable")
	inst.components.inspectable.getstatus = GetStatus

	inst:AddComponent("inventoryitem")

	inst:AddComponent("fueled")
	inst.components.fueled.accepting = true
	inst.components.fueled.fueltype = FUELTYPE.NIGHTMARE
	inst.components.fueled:SetTakeFuelFn(OnTakeFuel)
	inst.components.fueled:InitializeFuelLevel(TUNING.LARGE_FUEL * 4)

	inst:AddComponent("fuel")
	inst.components.fuel.fuelvalue = TUNING.MED_FUEL

	inst:AddComponent("aoespell")

	MakeSmallBurnable(inst, TUNING.MED_BURNTIME)
	MakeSmallPropagator(inst)
	MakeHauntableLaunch(inst)

	inst.castsound = "maxwell_rework/shadow_magic/cast" 
	
	return inst
end

return Prefab("waxwelljournal", fn, assets, prefabs)
