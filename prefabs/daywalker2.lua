local assets =
{
	Asset("ANIM", "anim/daywalker_build.zip"),
	Asset("ANIM", "anim/daywalker_buried.zip"),
	Asset("ANIM", "anim/daywalker_phase2.zip"),
	Asset("ANIM", "anim/daywalker_phase3.zip"),
	Asset("ANIM", "anim/daywalker_defeat.zip"),
	Asset("ANIM", "anim/scrapball.zip"),
}

local buriedfx_assets =
{
	Asset("ANIM", "anim/daywalker_buried.zip"),
}

local prefabs =
{
	"daywalker2_buried_fx",
	"daywalker2_swipe_fx",
	"daywalker2_object_break_fx",
	"daywalker2_spike_break_fx",
	"daywalker2_cannon_break_fx",
	"daywalker2_armor1_break_fx",
	"daywalker2_armor2_break_fx",
	"daywalker2_cloth_break_fx",
	"junkball_fx",
	"alterguardian_laser",
	"alterguardian_laserempty",
	"alterguardian_laserhit",
	"scrap_monoclehat",
	"wagpunk_bits",
	"gears",
}

local brain = require("brains/daywalker2brain")

SetSharedLootTable("daywalker2",
{
	{ "gears",				0.5 },

	{ "wagpunk_bits",		1 },
	{ "wagpunk_bits",		1 },
	{ "wagpunk_bits",		1 },
	{ "wagpunk_bits",		1 },
	{ "wagpunk_bits",		0.5 },

	{ "scrap_monoclehat",	1 },
})

local MASS = 1000

--------------------------------------------------------------------------

local BLINDSPOT = 15

local function UpdateHead(inst)
	if inst.stalking == nil then
		return
	elseif not inst.stalking:IsValid() then
		inst.stalking = nil
		inst.lastfacing = nil
		inst.lastdir1 = nil
		inst.Transform:SetRotation(0)
		inst.Transform:SetFourFaced()
		return
	end

	local parent = inst.entity:GetParent()
	parent.AnimState:MakeFacingDirty()
	local dir1 = parent:GetAngleToPoint(inst.stalking.Transform:GetWorldPosition())
	local camdir = TheCamera:GetHeading()
	local facing = parent.AnimState:GetCurrentFacing()

	dir1 = ReduceAngle(dir1 + camdir)

	if facing == FACING_UP then
		if dir1 > -135 and dir1 < 135 then
			local diff = ReduceAngle(dir1 - 2)
			if math.abs(diff) < BLINDSPOT and facing == inst.lastfacing then
				dir1 = inst.lastdir1
			else
				dir1 = diff > 0 and 135 or -135
			end
		end
	elseif facing == FACING_DOWN then
		if dir1 < -45 or dir1 > 90 then
			local diff = ReduceAngle(dir1 + 178)
			if math.abs(diff) < BLINDSPOT and facing == inst.lastfacing then
				dir1 = inst.lastdir1
			else
				dir1 = diff < 0 and 90 or -45
			end
		end
	elseif facing == FACING_LEFT then
		if dir1 < -45 or dir1 > 135 then
			local diff = ReduceAngle(dir1 + 160)
			if math.abs(diff) < BLINDSPOT and facing == inst.lastfacing then
				dir1 = inst.lastdir1
			else
				dir1 = diff < 0 and 135 or -45
			end
		end
	elseif facing == FACING_RIGHT then
		if dir1 < -135 or dir1 > 45 then
			local diff = ReduceAngle(dir1 - 160)
			if math.abs(diff) < BLINDSPOT and facing == inst.lastfacing then
				dir1 = inst.lastdir1
			else
				dir1 = diff < 0 and 45 or -135
			end
		end
	end

	inst.lastfacing = facing
	inst.lastdir1 = dir1

	inst.Transform:SetRotation(dir1 - camdir - parent.Transform:GetRotation())
	inst.AnimState:MakeFacingDirty()
	local facing1 = inst.AnimState:GetCurrentFacing()
	if facing1 == FACING_UPRIGHT or facing1 == FACING_UPLEFT then
		if facing == FACING_UP then
			inst.AnimState:Hide("side_ear")
			inst.AnimState:Show("back_ear")
		else
			inst.AnimState:Hide("back_ear")
			inst.AnimState:Show("side_ear")
		end
	end
end

local function CreateHead()
	local inst = CreateEntity()

	inst:AddTag("FX")
	--[[Non-networked entity]]
	if not TheWorld.ismastersim then
		inst.entity:SetCanSleep(false)
	end
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddFollower()

	inst.Transform:SetFourFaced()

	inst.AnimState:SetBank("daywalker")
	inst.AnimState:SetBuild("daywalker_build")
	inst.AnimState:PlayAnimation("head", true)
	--remove nightmare fx
	inst.AnimState:OverrideSymbol("ww_eye_R", "daywalker_build", "ww_eye_R_scar")
	--init swappable scrap equips
	inst.AnimState:OverrideSymbol("swap_eye_R", "daywalker_phase3", "swap_eye_R")

	inst:AddComponent("updatelooper")

	inst.isupdating = false
	inst.stalking = nil
	inst.lastfacing = nil
	inst.lastdir1 = nil

	return inst
end

local function OnStalkingDirty(inst)
	inst.head.stalking = inst._stalking:value() --available to clients
	if inst.head.stalking ~= nil then
		if not inst.head.isupdating then
			inst.head.isupdating = true
			inst.head.components.updatelooper:AddPostUpdateFn(UpdateHead)
		end
		inst.head.Transform:SetEightFaced()
	elseif inst.head.isupdating then
		inst.head.isupdating = false
		inst.head.lastfacing = nil
		inst.head.lastdir1 = nil
		inst.head.components.updatelooper:RemovePostUpdateFn(UpdateHead)
		inst.head.Transform:SetRotation(0)
		inst.head.Transform:SetFourFaced()
	end
end

local function OnHeadTrackingDirty(inst)
	if inst._headtracking:value() then
		if inst.head == nil then
			inst.head = CreateHead()
			inst.head.entity:SetParent(inst.entity)
			inst.head.Follower:FollowSymbol(inst.GUID, "HEAD_follow", nil, nil, nil, true, true)
			inst.highlightchildren = { inst.head }
			inst.head:ListenForEvent("stalkingdirty", OnStalkingDirty, inst)
			OnStalkingDirty(inst)
		end
	elseif inst.head ~= nil then
		inst.head:Remove()
		inst.highlightchildren = nil
	end
end

local function SetHeadTracking(inst, track)
	track = track ~= false
	if inst._headtracking:value() ~= track then
		inst._headtracking:set(track)

		--Dedicated server does not need to spawn the local fx
		if not TheNet:IsDedicated() then
			OnHeadTrackingDirty(inst)
		end
	end
end

--[[local function OnStalkingNewState(inst)
	if inst.sg:HasStateTag("stalking") then
		inst.components.health:StartRegen(TUNING.DAYWALKER_COMBAT_STALKING_HEALTH_REGEN, TUNING.DAYWALKER_COMBAT_HEALTH_REGEN_PERIOD, false)
	else
		inst.components.health:StopRegen()
	end
end]]

local function SetStalking(inst, stalking)
	if stalking and not (inst.hostile and stalking.isplayer) then
		stalking = nil
	end
	if stalking ~= inst._stalking:value() then
		if inst._stalking:value() then
			inst:RemoveEventCallback("onremove", inst._onremovestalking, inst._stalking:value())
			--[[if stalking == nil then
				inst:RemoveEventCallback("newstate", OnStalkingNewState)
				if inst.engaged then
					inst.components.health:StopRegen()
				end
			end
		elseif stalking then
			inst:ListenForEvent("newstate", OnStalkingNewState)]]
		end
		inst._stalking:set(stalking)
		if stalking then
			inst:ListenForEvent("onremove", inst._onremovestalking, stalking)
		end
	end
end

local function GetStalking(inst)
	return inst._stalking:value()
end

local function IsStalking(inst)
	return inst._stalking:value() ~= nil
end

--------------------------------------------------------------------------

local function SetEquip(inst, action, item, uses)
	if action == "swing" then
		if item then
			inst.AnimState:Hide("ARM_NORMAL")
			inst.AnimState:Show("ARM_CARRY")
			inst.canswing = true
			inst.equipswing = item
			inst.numswings = TUNING.DAYWALKER2_ITEM_USES
		else
			inst.AnimState:Hide("ARM_CARRY")
			inst.AnimState:Show("ARM_NORMAL")
			inst.canswing = false
			inst.equipswing = nil
			inst.numswings = nil
		end
	elseif action == "tackle" then
		if item then
			inst.AnimState:ShowSymbol("swap_armupper")
			inst.cantackle = true
			inst.equiptackle = item
			inst.numtackles = TUNING.DAYWALKER2_ITEM_USES
		else
			inst.AnimState:HideSymbol("swap_armupper")
			inst.cantackle = false
			inst.equiptackle = nil
			inst.numtackles = nil
		end
	elseif action == "cannon" then
		if item then
			inst.AnimState:ShowSymbol("swap_armlower")
			inst.components.combat:SetRange(TUNING.DAYWALKER2_CANNON_ATTACK_RANGE)
			inst.cancannon = true
			inst.equipcannon = item
			inst.numcannons = TUNING.DAYWALKER2_ITEM_USES
		else
			inst.AnimState:HideSymbol("swap_armlower")
			inst.components.combat:SetRange(TUNING.DAYWALKER2_ATTACK_RANGE)
			inst.cancannon = false
			inst.equipcannon = nil
			inst.numcannons = nil
		end
	end
	if item then
		inst.lastequip = item
	end
end

local function OnItemUsed(inst, action)
	if action == "swing" then
		if inst.numswings then
			inst.numswings = inst.numswings - 1
			return inst.numswings > 0
		end
	elseif action == "tackle" then
		if inst.numtackles then
			inst.numtackles = inst.numtackles - 1
			return inst.numtackles > 0
		end
	elseif action == "cannon" then
		if inst.numcannons then
			inst.numcannons = inst.numcannons - 1
			return inst.numcannons > 0
		end
	end
	return false
end

local function DropItem(inst, action)
	local item, angleoffset
	if action == "swing" then
		item = inst.equipswing
		angleoffset = -(70 + math.random() * 20)
	elseif action == "tackle" then
		item = inst.equiptackle
		angleoffset = 70 + math.random() * 20
	elseif action == "cannon" then
		item = inst.equipcannon
		angleoffset = 70 + math.random() * 20
	end

	inst:SetEquip(action, nil)

	if item then
		local fx = SpawnPrefab("daywalker2_"..item.."_break_fx")
		local rot = inst.Transform:GetRotation() + angleoffset
		fx.Transform:SetRotation(rot)
		local x, y, z = inst.Transform:GetWorldPosition()
		rot = rot * DEGREES
		fx.Transform:SetPosition(x + math.cos(rot) * 2, y, z - math.sin(rot) * 2)

		inst.SoundEmitter:PlaySound("dontstarve/wilson/use_break")
	end
end

--------------------------------------------------------------------------

local DESPAWN_TIME = 60 * 4

--#V2C: kinda silly, but this was just to have it so PHASES[0] exists, but
--      will also be excluded from ipairs and #PHASES...
local PHASES =
{
	[0] = {
		hp = 1,
		fn = function(inst)
			inst.canmultiwield = false
		end,
	},
	--
	[1] = {
		hp = 0.75,
		fn = function(inst)
			if inst.hostile then
				inst.canmultiwield = true
			end
		end,
	},
}

--------------------------------------------------------------------------

local function UpdatePlayerTargets(inst)
	local toadd = {}
	local toremove = {}
	local x, y, z
	local range
	local junk = inst.components.entitytracker:GetEntity("junk")
	if junk then
		x, y, z = junk.Transform:GetWorldPosition()
		range = TUNING.DAYWALKER2_DEAGGRO_DIST_FROM_JUNK
	else
		x, y, z = inst.Transform:GetWorldPosition()
		range = TUNING.DAYWALKER_DEAGGRO_DIST
	end

	for k in pairs(inst.components.grouptargeter:GetTargets()) do
		toremove[k] = true
	end
	for i, v in ipairs(FindPlayersInRange(x, y, z, range, true)) do
		if toremove[v] then
			toremove[v] = nil
		else
			table.insert(toadd, v)
		end
	end

	for k in pairs(toremove) do
		inst.components.grouptargeter:RemoveTarget(k)
	end
	for i, v in ipairs(toadd) do
		inst.components.grouptargeter:AddTarget(v)
	end
end

local function RetargetFn(inst)
	UpdatePlayerTargets(inst)

	local target = inst.components.combat.target
	local inrange = target and inst:IsNear(target, TUNING.DAYWALKER_ATTACK_RANGE + target:GetPhysicsRadius(0))

	if target and target.isplayer then
		local newplayer = inst.components.grouptargeter:TryGetNewTarget()
		return newplayer
			and newplayer:IsNear(inst, inrange and TUNING.DAYWALKER_ATTACK_RANGE + newplayer:GetPhysicsRadius(0) or TUNING.DAYWALKER_KEEP_AGGRO_DIST)
			and newplayer
			or nil,
			true
	end

	local nearplayers = {}
	for k in pairs(inst.components.grouptargeter:GetTargets()) do
		if inst:IsNear(k, inrange and TUNING.DAYWALKER_ATTACK_RANGE + k:GetPhysicsRadius(0) or TUNING.DAYWALKER_AGGRO_DIST) then
			table.insert(nearplayers, k)
		end
	end
	return #nearplayers > 0 and nearplayers[math.random(#nearplayers)] or nil, true
end

local function KeepTargetFn(inst, target)
	if inst.defeated or not inst.components.combat:CanTarget(target) then
		return false
	end
	local junk = inst.components.entitytracker:GetEntity("junk")
	if junk then
		return target:IsNear(junk, TUNING.DAYWALKER2_DEAGGRO_DIST_FROM_JUNK)
	end
	return target:IsNear(inst, TUNING.DAYWALKER_DEAGGRO_DIST)
end

local function OnAttacked(inst, data)
	if data.attacker then
		local target = inst.components.combat.target
		if not (target and
				target.isplayer and
				target:IsNear(inst, TUNING.DAYWALKER_ATTACK_RANGE + target:GetPhysicsRadius(0)))
		then
			inst.components.combat:SetTarget(data.attacker)
		end
	end
end

local function OnNewTarget(inst, data)
	if data.target then
		if not inst.hostile then
			inst.hostile = true
			inst:AddTag("hostile")
			inst.components.combat:SetRetargetFunction(3, RetargetFn)
		end
		inst:SetEngaged(true)
		if inst:IsStalking() then
			inst:SetStalking(data.target)
		end
	end
end

local function SetEngaged(inst, engaged)
	if inst.engaged ~= engaged and (engaged ~= nil) == inst.hostile then
		inst.engaged = engaged
		if engaged then
			inst.components.health:StopRegen()
			inst:StartAttackCooldown()
			if not inst.components.timer:TimerExists("roar_cd") then
				inst:PushEvent("roar", { target = inst.components.combat.target })
			end
		else
			inst:SetStalking(nil)
			if engaged == false then
				inst.components.health:StartRegen(TUNING.DAYWALKER_HEALTH_REGEN, 1)
			else--if engaged == nil then
				inst.components.health:StopRegen()
			end
			inst.components.combat:ResetCooldown()
			inst.components.combat:DropTarget()
		end
	end
end

local function StartAttackCooldown(inst)
	inst.components.combat:SetAttackPeriod(GetRandomMinMax(TUNING.DAYWALKER2_ATTACK_PERIOD.min, TUNING.DAYWALKER2_ATTACK_PERIOD.max))
	inst.components.combat:RestartCooldown()
end

local function OnMinHealth(inst)
	if not POPULATING then
		inst:MakeDefeated()
	end
end

local function OnDespawnTimer(inst, data)
	if data ~= nil and data.name == "despawn" then
		if inst:IsAsleep() then
			inst:Remove()
		else
			inst.components.talker:IgnoreAll("despawn")
			inst.components.despawnfader:FadeOut()
			inst.DynamicShadow:Enable(false)
		end
	end
end

--------------------------------------------------------------------------

local function MakeBuried(inst, junk)
	if not (inst.buried or inst.defeated) then
		inst.buried = true
		inst.hostile = false
		inst.persists = false
		inst.sg:GoToState("transition")
		inst:RemoveEventCallback("attacked", OnAttacked)
		inst:RemoveEventCallback("newcombattarget", OnNewTarget)
		inst:RemoveEventCallback("minhealth", OnMinHealth)
		inst.components.timer:StopTimer("despawn")
		inst.components.combat:DropTarget()
		inst.components.combat:SetRetargetFunction(nil)
		inst.components.talker:ShutUp()
		inst.components.locomotor:Stop()
		inst.components.health:SetInvincible(true)
		inst.components.sanityaura.aura = -TUNING.SANITYAURA_LARGE
		inst:RemoveTag("hostile")
		inst:AddTag("notarget")
		inst:AddTag("noteleport")
		inst.AnimState:Hide("junk_top")
		inst.AnimState:Hide("junk_mid")
		inst.AnimState:Hide("junk_back")
		inst.Transform:SetEightFaced()
		inst.Physics:SetActive(false)
		PHASES[0].fn(inst)
		inst:SetBrain(nil)
		inst:SetHeadTracking(false)
		inst:SetStalking(nil)
		inst:SetEngaged(nil)

		if inst.junkfx == nil then
			inst.junkfx = {}
			for i, v in ipairs({ "junk_top", "junk_mid", "junk_back" }) do
				local fx = SpawnPrefab("daywalker2_buried_fx")
				fx.entity:SetParent(junk.entity)
				if junk.prefab == "junk_pile_big" and junk.highlightchildren then
					table.insert(junk.highlightchildren, fx)
				end
				fx.AnimState:Show(v)
				if i == 1 then
					fx.AnimState:SetSortWorldOffset(0, 0.1, 0) --top layer mouseover priority
				end
				fx.Follower:FollowSymbol(inst.GUID, "follow_"..v, 0, 0, 0, true)
				table.insert(inst.junkfx, fx)
			end
		end

		inst.components.entitytracker:TrackEntity("junk", junk)
		inst._onremovejunk = function() inst:Remove() end
		inst:ListenForEvent("onremove", inst._onremovejunk, junk)

		inst:SetStateGraph("SGdaywalker2_buried") --after junkfx spawned
	end
end

local function MakeFreed(inst)
	if inst.buried then
		inst.buried = nil
		inst.persists = true
		inst.sg:GoToState("transition")
		inst:ListenForEvent("attacked", OnAttacked)
		inst:ListenForEvent("newcombattarget", OnNewTarget)
		inst:ListenForEvent("minhealth", OnMinHealth)
		inst.components.timer:StopTimer("despawn")
		inst.components.talker:ShutUp()
		inst.components.health:SetInvincible(false)
		inst.components.sanityaura.aura = -TUNING.SANITYAURA_HUGE
		inst:RemoveTag("notarget")
		inst:RemoveTag("noteleport")
		inst.AnimState:Show("junk_top")
		inst.AnimState:Show("junk_mid")
		inst.AnimState:Show("junk_back")
		inst.Transform:SetFourFaced()
		inst.Physics:SetActive(true)
		inst:SetStateGraph("SGdaywalker2")
		inst.sg:GoToState("emerge")
		if not inst.components.health:IsHurt() then
			PHASES[0].fn(inst)
		end
		inst:SetBrain(brain)
		if inst.brain == nil and not inst:IsAsleep() then
			inst:RestartBrain()
		end

		if inst.junkfx then
			for i, v in ipairs(inst.junkfx) do
				v:Remove()
			end
			inst.junkfx = nil
		end

		if inst._onremovejunk then
			local junk = inst.components.entitytracker:GetEntity("junk")
			inst:RemoveEventCallback("onremove", inst._onremovejunk, junk)
			inst._onremovejunk = nil
		end
	end
end

local function MakeDefeated(inst)
	if not (inst.buried or inst.defated) and inst.hostile then
		inst.defeated = true
		inst.hostile = false
		inst:RemoveEventCallback("attacked", OnAttacked)
		inst:RemoveEventCallback("newcombattarget", OnNewTarget)
		inst:RemoveEventCallback("minhealth", OnMinHealth)
		inst:ListenForEvent("timerdone", OnDespawnTimer)
		if not inst.components.timer:TimerExists("despawn") then
			inst.components.timer:StartTimer("despawn", DESPAWN_TIME, not inst.looted)
		end
		inst.components.combat:DropTarget()
		inst.components.combat:SetRetargetFunction(nil)
		inst.components.sanityaura.aura = -TUNING.SANITYAURA_MED
		inst:RemoveTag("hostile")
		inst:SetBrain(nil)
		inst:SetHeadTracking(false)
		inst:SetStalking(nil)
		inst:SetEngaged(nil)
	end
end

--------------------------------------------------------------------------

local function GetStatus(inst)
	return (inst.buried and "BURIED")
		or (inst.hostile and "HOSTILE")
		or nil
end

local function OnSave(inst, data)
	data.hostile = inst.hostile or nil
	data.looted = inst.looted or nil
	if inst.canswing then
		data.numswings = inst.numswings
		data.equipswing = inst.equipswing
	end
	if inst.cantackle then
		data.numtackles = inst.numtackles
		data.equiptackle = inst.equiptackle
	end
	if inst.cancannon then
		data.numcannons = inst.numcannons
		data.equipcannon = inst.equipcannon
	end
end

local function OnLoad(inst, data)
	local healthpct = inst.components.health:GetPercent()
	for i = #PHASES, 1, -1 do
		local v = PHASES[i]
		if healthpct <= v.hp then
			v.fn(inst)
			break
		end
	end

	if inst.components.timer:TimerExists("despawn") then
		inst:MakeDefeated()
		if data and data.looted then
			inst.looted = true
			inst.sg:GoToState("defeat_idle_pre")
		else
			inst.components.timer:PauseTimer("despawn")
			inst.components.timer:SetTimeLeft("despawn", DESPAWN_TIME)
			inst.sg:GoToState("defeat")
		end
	elseif data.hostile then
		inst.hostile = true
		inst:AddTag("hostile")
		inst.components.combat:SetRetargetFunction(3, RetargetFn)
	end

	if inst.hostile or (inst.defeated and not inst.looted) then
		if data.numswings and data.numswings > 0 then
			inst:SetEquip("swing", data.equipswing, data.numswings)
		end
		if data.numtackles and data.numtackles > 0 then
			inst:SetEquip("tackle", data.equiptackle, data.numtackles)
		end
		if data.numcannons and data.numcannons > 0 then
			inst:SetEquip("cannon", data.equipcannon, data.numcannons)
		end
	end
end

local function OnEntitySleep(inst)
	if inst.looted then
		if inst._despawntask == nil then
			inst._despawntask = inst:DoTaskInTime(1, inst.Remove)
		end
	elseif inst.hostile then
		inst:SetEngaged(false)
	end
end

local function OnEntityWake(inst)
	if inst._despawntask ~= nil then
		inst._despawntask:Cancel()
		inst._despawntask = nil
	end
end

local function OnTalk(inst)
	if not inst.sg:HasStateTag("notalksound") then
		inst.SoundEmitter:PlaySound("daywalker/voice/speak_short")
	end
end

local function teleport_override_fn(inst)
	--[[if not inst.hostile then
		--Stay within prison; or, backup is just don't go too far
		local pos = inst.components.knownlocations:GetLocation("prison") or inst:GetPosition()
		local offset = FindWalkableOffset(pos, TWOPI * math.random(), 4, 8, true, false)
		return offset ~= nil and pos + offset or pos
	end

	--Go back to prison if it is still there, otherwise anywhere (return nil for default behvaiour)
	local pos = inst.components.knownlocations:GetLocation("prison")
	if pos ~= nil then
		local offset = FindWalkableOffset(pos, TWOPI * math.random(), 4, 8, true, false)
		return offset ~= nil and pos + offset or pos
	end]]
end

--------------------------------------------------------------------------

local function PushMusic(inst)
	if ThePlayer == nil or not inst:HasTag("hostile") then
		inst._playingmusic = false
	elseif ThePlayer:IsNear(inst, inst._playingmusic and 40 or 20) then
		inst._playingmusic = true
		ThePlayer:PushEvent("triggeredevent", { name = "daywalker" })
	elseif inst._playingmusic and not ThePlayer:IsNear(inst, 50) then
		inst._playingmusic = false
	end
end

--------------------------------------------------------------------------

-- NOTES(DiogoW): @V2C, please keep this updated :)
local scrapbook_overridedata = {
	{ "ww_armlower_base", "daywalker_build", "ww_armlower_base_nored" },
	{ "ww_eye_R",         "daywalker_build", "ww_eye_R_scar"          },
}

local function TEMP_JUNK_EVENT(inst) -- FIXME(JBK): Temporary respawning routine for beta.
    local junk = inst.components.entitytracker:GetEntity("junk")
    if junk ~= nil then
        junk:WatchForDaywalkerRemove(inst)
    end
end
local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddDynamicShadow()
	inst.entity:AddNetwork()

	inst.Transform:SetFourFaced()
	--inst.Transform:SetSixFaced() --V2C: TwoFaced has a built in rot offset hack for stationary objects
	inst:SetPhysicsRadiusOverride(1.3)
	MakeGiantCharacterPhysics(inst, MASS, inst.physicsradiusoverride)

	inst:AddTag("epic")
	inst:AddTag("noepicmusic")
	inst:AddTag("monster")
	--inst:AddTag("hostile")
	inst:AddTag("scarytoprey")
	inst:AddTag("largecreature")
	inst:AddTag("junkmob")
	--inst:AddTag("lunar_aligned")

	inst.AnimState:SetBank("daywalker")
	inst.AnimState:SetBuild("daywalker_build")
	inst.AnimState:PlayAnimation("idle", true)
	--remove nightmare fx
	inst.AnimState:HideSymbol("ww_armlower_red")
	inst.AnimState:OverrideSymbol("ww_armlower_base", "daywalker_build", "ww_armlower_base_nored")
	inst.AnimState:OverrideSymbol("ww_eye_R", "daywalker_build", "ww_eye_R_scar")
	--init swappable scrap equips
	inst.AnimState:Hide("ARM_CARRY")
	inst.AnimState:HideSymbol("swap_armupper")
	inst.AnimState:HideSymbol("swap_armlower")
	inst.AnimState:OverrideSymbol("scrap_debris", "scrapball", "scrap_debris")
	inst.AnimState:AddOverrideBuild("daywalker_phase3")
	inst.AnimState:AddOverrideBuild("daywalker_buried")

	inst.DynamicShadow:SetSize(3.5, 1.5)

	inst:AddComponent("talker")
	inst.components.talker.fontsize = 40
	inst.components.talker.font = TALKINGFONT
	inst.components.talker.colour = Vector3(238 / 255, 69 / 255, 105 / 255)
	inst.components.talker.offset = Vector3(0, -400, 0)
	inst.components.talker.symbol = "ww_hunch"
	inst.components.talker:MakeChatter()

	inst._headtracking = net_bool(inst.GUID, "daywalker._headtracking", "headtrackingdirty")
	inst._stalking = net_entity(inst.GUID, "daywalker._stalking", "stalkingdirty")

	inst:AddComponent("despawnfader")

	inst.entity:SetPristine()

	--Dedicated server does not need to trigger music
	--Dedicated server does not need to spawn the local fx
	if not TheNet:IsDedicated() then
		inst._playingmusic = false
		inst:DoPeriodicTask(1, PushMusic, 0)
	end

	if not TheWorld.ismastersim then
		inst:ListenForEvent("headtrackingdirty", OnHeadTrackingDirty)

		return inst
	end

	inst.scrapbook_anim = "scrapbook"
	inst.scrapbook_overridebuild = "daywalker_phase3"
	inst.scrapbook_overridedata = scrapbook_overridedata

	inst.footstep = "qol1/daywalker_scrappy/step"

	inst.components.talker.ontalk = OnTalk

	inst:AddComponent("entitytracker")

	inst:AddComponent("inspectable")
	inst.components.inspectable.getstatus = GetStatus

	inst:AddComponent("locomotor")
	inst.components.locomotor.walkspeed = TUNING.DAYWALKER_WALKSPEED
	inst.components.locomotor.runspeed = TUNING.DAYWALKER_RUNSPEED

	inst:AddComponent("health")
	inst.components.health:SetMinHealth(1)
	inst.components.health:SetMaxHealth(TUNING.DAYWALKER_HEALTH)
	--inst.components.health.nofadeout = true

	inst:AddComponent("combat")
	inst.components.combat:SetDefaultDamage(TUNING.DAYWALKER_DAMAGE)
	inst.components.combat:SetAttackPeriod(TUNING.DAYWALKER2_ATTACK_PERIOD.min)
	inst.components.combat.playerdamagepercent = .5
	inst.components.combat.externaldamagetakenmultipliers:SetModifier(inst, TUNING.DAYWALKER2_DAMAGE_TAKEN_MULT, "junkarmor")
	inst.components.combat:SetRange(TUNING.DAYWALKER2_ATTACK_RANGE)
	inst.components.combat:SetKeepTargetFunction(KeepTargetFn)
	inst.components.combat.hiteffectsymbol = "ww_body"
	inst.components.combat.battlecryenabled = false
	inst.components.combat.forcefacing = false

	inst:AddComponent("colouradder")
	inst:AddComponent("bloomer")

	inst:AddComponent("healthtrigger")
	for i, v in pairs(PHASES) do
		inst.components.healthtrigger:AddTrigger(v.hp, v.fn)
	end

	inst:AddComponent("knownlocations")
	inst:AddComponent("grouptargeter")
	inst:AddComponent("timer")
	inst:AddComponent("explosiveresist")

	inst:AddComponent("sanityaura")
	inst.components.sanityaura.aura = -TUNING.SANITYAURA_HUGE

	inst:AddComponent("epicscare")
	inst.components.epicscare:SetRange(TUNING.DAYWALKER_EPICSCARE_RANGE)

	inst:AddComponent("lootdropper")
	inst.components.lootdropper:SetChanceLootTable("daywalker2")
	inst.components.lootdropper.min_speed = 1
	inst.components.lootdropper.max_speed = 3
	inst.components.lootdropper.y_speed = 14
	inst.components.lootdropper.y_speed_variance = 4
	inst.components.lootdropper.spawn_loot_inside_prefab = true

	inst:AddComponent("teleportedoverride")
	inst.components.teleportedoverride:SetDestPositionFn(teleport_override_fn)

	inst.hit_recovery = TUNING.DAYWALKER_HIT_RECOVERY

	inst:ListenForEvent("attacked", OnAttacked)
	inst:ListenForEvent("newcombattarget", OnNewTarget)
	inst:ListenForEvent("minhealth", OnMinHealth)

	inst.engaged = nil
	inst.defeated = false
	inst.looted = false
	inst._trampledelays = {}

	--ability unlocks
	inst.autostalk = true
	inst.canthrow = true
	inst.canswing = false
	inst.cantackle = false
	inst.cancannon = false
	inst.canmultiwield = false

	inst._onremovestalking = function(stalking) inst._stalking:set(nil) end

	inst.MakeBuried = MakeBuried
	inst.MakeFreed = MakeFreed
	inst.MakeDefeated = MakeDefeated
	inst.SetEngaged = SetEngaged
	inst.StartAttackCooldown = StartAttackCooldown
	inst.SetHeadTracking = SetHeadTracking
	inst.SetStalking = SetStalking
	inst.GetStalking = GetStalking
	inst.IsStalking = IsStalking
	inst.SetEquip = SetEquip
	inst.OnItemUsed = OnItemUsed
	inst.DropItem = DropItem
	inst.OnSave = OnSave
	inst.OnLoad = OnLoad
	inst.OnEntitySleep = OnEntitySleep
	inst.OnEntityWake = OnEntityWake

	inst:SetStateGraph("SGdaywalker2")
	inst:SetBrain(brain)
	inst:SetEngaged(false)

    inst:DoTaskInTime(0, TEMP_JUNK_EVENT) -- FIXME(JBK): Temporary respawning routine for beta.

	return inst
end

--------------------------------------------------------------------------

local function buriedfx_OnRemoveEntity(inst)
	local parent = inst.entity:GetParent()
	if parent and parent.highlightchildren then
		table.removearrayvalue(parent.highlightchildren, inst)
	end
end

local function buriedfx_OnEntityReplicated(inst)
	local parent = inst.entity:GetParent()
	if parent and parent.prefab == "junk_pile_big" then
		table.insert(parent.highlightchildren, inst)
	end
end

local function buriedfx_fn()
	local inst = CreateEntity()

	--V2C: speecial =) must be the 1st tag added b4 AnimState component
	inst:AddTag("can_offset_sort_pos")

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddFollower()
	inst.entity:AddNetwork()

	inst.Transform:SetEightFaced()

	inst.AnimState:SetBank("daywalker")
	inst.AnimState:SetBuild("daywalker_buried")
	inst.AnimState:PlayAnimation("buried_hold_full", true)
	inst.AnimState:Hide("junk_top")
	inst.AnimState:Hide("junk_mid")
	inst.AnimState:Hide("junk_back")

	inst:AddTag("FX")

	inst.entity:SetPristine()

	inst.OnRemoveEntity = buriedfx_OnRemoveEntity

	if not TheWorld.ismastersim then
		inst.OnEntityReplicated = buriedfx_OnEntityReplicated

		return inst
	end

	inst.persists = false

	return inst
end

--------------------------------------------------------------------------

return Prefab("daywalker2", fn, assets, prefabs),
	Prefab("daywalker2_buried_fx", buriedfx_fn, buriedfx_assets)
