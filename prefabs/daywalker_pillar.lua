local assets =
{
	Asset("ANIM", "anim/daywalker_pillar.zip"),
}

local assets_hole =
{
	Asset("ANIM", "anim/daywalker_hole.zip"),
}

local prefabs =
{
	"marble",
	"dreadstone",
	"daywalker_pillar_hole",
}

SetSharedLootTable("daywalker_pillar",
{
	{ "marble", 0.5 },
	{ "dreadstone", 1 },
	{ "dreadstone", 1 },
	{ "dreadstone", 1 },
	{ "dreadstone", 0.5 },
})

--------------------------------------------------------------------------

local function IsResonating(inst)
	return inst.AnimState:IsCurrentAnimation("pillar_shake")
end

local CHAIN_LEN = 10
local PILLAR_RADIUS = 1.2
local COLLAR_RADIUS = 1.2

local function OnWallUpdate(inst, dt)
	dt = dt * TheSim:GetTimeScale()
	local prisoner = inst.prisoner:value()
	if prisoner ~= nil then
		if inst.vibratespike then
			inst.vibratespike = false
			inst.vibrateamp = 1.2
		elseif IsResonating(inst) then
			inst.vibrateamp = math.max(0.4, inst.vibrateamp - (inst.vibrateamp - 0.4) * 3 * dt)
		else
			inst.vibrateamp = math.max(0, inst.vibrateamp - dt)
		end
		inst.vibratetime = inst.vibratetime + dt

		--no z, just declaring the locals here
		local x1, y1, z1 = TheSim:GetScreenPos(inst.Transform:GetWorldPosition())
		local x2, y2, z2 = TheSim:GetScreenPos(prisoner.Transform:GetWorldPosition())
		local w, h = TheSim:GetWindowSize()
		local dfront = (y2 - y1) * RESOLUTION_Y / h
		local front = dfront > -10

		x1, y1, z1 = inst.AnimState:GetSymbolPosition("swap_shackle")
		x2, y2, z2 = prisoner.AnimState:GetSymbolPosition("swap_shackle")
		if front then
			local theta = TheCamera:GetHeading() * DEGREES
			x2 = x2 + math.cos(theta)
			z2 = z2 + math.sin(theta)
			y2 = y2 + 0.7
		end
		local dx = x2 - x1
		local dy = y2 - y1
		local dz = z2 - z1
		local len = math.sqrt(dx * dx + dz * dz)
		x1 = x1 + dx * PILLAR_RADIUS / len
		z1 = z1 + dz * PILLAR_RADIUS / len
		x2 = x2 - dx * COLLAR_RADIUS / len
		z2 = z2 - dz * COLLAR_RADIUS / len
		dx = x2 - x1
		dy = y2 - y1
		dz = z2 - z1

		len = math.sqrt(dx * dx + dy * dy + dz * dz)
		if front then
			local k = math.clamp(dfront, 0, 100) / 100
			len = len + 1.5 * k * k
		end
		local droopmult = 1 - math.clamp(6 - len, 0, 3) / 3
		droopmult = 1 - droopmult * droopmult

		for i, v in ipairs(inst.chains) do
			local index = i - 1 --0 based
			local droop = CHAIN_LEN / 2
			droop = math.abs(droop - index) / droop
			droop = (1 - droop * droop) * droopmult

			local k = index / CHAIN_LEN
			x2 = x1 + dx * k
			y2 = y1 + dy * k - droop * 1.5
			z2 = z1 + dz * k

			if inst.vibrateamp > 0 then
				y2 = y2 + math.sin(inst.vibratetime * 45 - i) * inst.vibrateamp * math.max(0.1, droop)
			end

			if v.lastx ~= nil then
				--reduced chain lag when rotating camera
				droop = droop * (TheCamera:GetHeadingTarget() == TheCamera:GetHeading() and 0.9 or 0.5)
				k = 1 - droop
				x2 = k * x2 + droop * v.lastx
				y2 = k * y2 + droop * v.lasty
				z2 = k * z2 + droop * v.lastz
			end

			v.lastx, v.lasty, v.lastz = x2, y2, z2
			v.Transform:SetPosition(x2, y2, z2)
			v:Show()

			if index > CHAIN_LEN - 2 then
				k = front and (index - CHAIN_LEN + 2) / 3 or 0
				v.AnimState:SetMultColour(1, 1, 1, 1 - k)
			end
		end
	else
		for i, v in ipairs(inst.chains) do
			v:Hide()
		end
	end
end

local LINK_VARS = { "1", "2", "3", "4" }
local function GetNextLinkVar()
	local var = table.remove(LINK_VARS, math.random(2))
	table.insert(LINK_VARS, var)
	return var
end

local function CreateChainLink()
	local inst = CreateEntity()

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")
	--[[Non-networked entity]]
	inst.entity:SetCanSleep(false)
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst.AnimState:SetBank("daywalker_pillar")
	inst.AnimState:SetBuild("daywalker_pillar")
	inst.variation = GetNextLinkVar()
	inst.AnimState:PlayAnimation("link_"..inst.variation, true)
	inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)

	local scale = .785
	inst.AnimState:SetScale(scale, scale)

	inst:Hide()

	return inst
end

local function CreateChainBracket()
	local inst = CreateEntity()

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")
	--[[Non-networked entity]]
	inst.entity:SetCanSleep(false)
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddFollower()

	inst.AnimState:SetBank("daywalker_pillar")
	inst.AnimState:SetBuild("daywalker_pillar")
	inst.AnimState:PlayAnimation("chain_idle", true)
	inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)

	return inst
end

local function OnRestartVibrate(inst)
	inst.vibratespike = true
end

local function SpawnChains(inst)
	if inst.chains == nil then
		inst.chainbracket = CreateChainBracket()
		inst.chainbracket.entity:SetParent(inst.entity)
		inst.chainbracket.Follower:FollowSymbol(inst.GUID, "swap_shackle", nil, nil, nil, true)
		inst.chains = {}
		for i = 0, CHAIN_LEN do
			table.insert(inst.chains, CreateChainLink())
		end
		inst.vibratetime = 0
		inst.vibrateamp = 0
		inst.vibratespike = false
		inst:ListenForEvent("daywalker_pillar.restartvibrate", OnRestartVibrate)
		inst:AddComponent("updatelooper")
		inst.components.updatelooper:AddOnWallUpdateFn(OnWallUpdate)
	end
end

local function RemoveChains(inst, broken)
	if inst.chainbracket ~= nil then
		if broken then
			local x, y, z = inst.chainbracket.Transform:GetWorldPosition()
			inst.chainbracket.Follower:StopFollowing()
			inst.chainbracket.entity:SetParent(nil)
			inst.chainbracket.Transform:SetPosition(x, y, z)
			inst.chainbracket.AnimState:PlayAnimation("chain_break")
			inst.chainbracket:ListenForEvent("animover", inst.chainbracket.Remove)
		else
			inst.chainbracket:Remove()
		end
		inst.chainbracket = nil
	end
	if inst.chains ~= nil then
		if broken then
			for i, v in ipairs(inst.chains) do
				local x, y, z = v.Transform:GetWorldPosition()
				v.entity:SetParent(nil)
				v.Transform:SetPosition(x, y, z)
				v.AnimState:PlayAnimation("link_break_"..v.variation)
				v:ListenForEvent("animover", v.Remove)
			end
		else
			for i, v in ipairs(inst.chains) do
				v:Remove()
			end
		end
		inst.chains = nil
		inst.vibratetime = nil
		inst.vibrateamp = nil
		inst.vibratespike = nil
		inst:RemoveEventCallback("daywalker_pillar.restartvibrate", OnRestartVibrate)
		inst:RemoveComponent("updatelooper")
	end
end

local function OnSleepTask(inst)
	inst.sleeptask = nil
	RemoveChains(inst)
end

local function OnEntitySleep(inst)
	if inst.chains ~= nil and inst.sleeptask == nil then
		inst.sleeptask = inst:DoTaskInTime(1, OnSleepTask)
	end
end

local function OnEntityWake(inst)
	if inst.sleeptask ~= nil then
		inst.sleeptask:Cancel()
		inst.sleeptask = nil
	else
		SpawnChains(inst)
	end
end

local function OnChainsDirty(inst)
	if inst.enablechains:value() then
		if TheWorld.ismastersim then
			inst.OnEntitySleep = OnEntitySleep
			inst.OnEntityWake = OnEntityWake
			if not inst:IsAsleep() then
				SpawnChains(inst)
			end
		else
			SpawnChains(inst)
		end
	else
		RemoveChains(inst, true)
		if TheWorld.ismastersim then
			if inst.sleeptask ~= nil then
				inst.sleeptask:Cancel()
				inst.sleeptask = nil
			end
			inst.OnEntitySleep = nil
			inst.OnEntityWake = nil
		end
	end
end

local function EnableChains(inst, enable)
	enable = enable ~= false
	if enable ~= inst.enablechains:value() then
		inst.enablechains:set(enable)

		--Dedicated server does not need to spawn the local fx
		if not TheNet:IsDedicated() then
			OnChainsDirty(inst)
		end
	end
end

local function SetPrisoner(inst, prisoner)
	local old = inst.prisoner:value()
	if prisoner ~= old then
		if old ~= nil then
			inst.components.entitytracker:ForgetEntity("prisoner")
			inst:RemoveEventCallback("daywalkerchainbreak", inst._onchainbreak, old)
			inst:RemoveEventCallback("onremove", inst._onremoveprisoner, old)
		end
		inst.prisoner:set(prisoner)
		EnableChains(inst, prisoner ~= nil)
		if prisoner ~= nil then
			inst.components.entitytracker:TrackEntity("prisoner", prisoner)
			inst:ListenForEvent("daywalkerchainbreak", inst._onchainbreak, prisoner)
			inst:ListenForEvent("onremove", inst._onremoveprisoner, prisoner)
			if prisoner.MakeChained ~= nil then
				prisoner:MakeChained()
			end
		end
	end
end

local function GetPrisoner(inst)
	return inst.prisoner:value()
end

--------------------------------------------------------------------------

local function SpawnDebris(inst, anim, layer)
	local fx = CreateEntity()

	fx:AddTag("FX")
	fx:AddTag("NOCLICK")
	--[[Non-networked entity]]
	fx.entity:SetCanSleep(false)
	fx.persists = false

	fx.entity:AddTransform()
	fx.entity:AddAnimState()
	fx.entity:AddSoundEmitter()

	fx.AnimState:SetBank("daywalker_pillar")
	fx.AnimState:SetBuild("daywalker_pillar")
	fx.AnimState:PlayAnimation(anim)
	fx.AnimState:SetFinalOffset(layer)

	fx:ListenForEvent("animover", fx.Remove)

	fx.Transform:SetPosition(inst.Transform:GetWorldPosition())

	return fx
end

local function OnDebrisDirty(inst)
	if inst.debris:value() == 0 then
		local rnd = math.random(2)
		SpawnDebris(inst, "debris_small_"..(rnd == 1 and "a" or "b"), -1)
		inst:DoTaskInTime((2 + math.random(3)) * FRAMES, SpawnDebris, "debris_small_"..(rnd == 2 and "a" or "b"), -1)
	else
		local anim =
			(inst.debris:value() == 1 and "debris_low") or
			(inst.debris:value() == 2 and "debris_med") or
			nil

		if anim ~= nil then
			SpawnDebris(inst, anim, 1).SoundEmitter:PlaySound("daywalker/pillar/hit")
		end
	end
end

local function UpdateBuild(inst, workleft)
	if math.floor(workleft) <= 1 then
		if inst.level ~= "lowest" then
			local dlevel = (inst.level == "full" and 3) or (inst.level == "med" and 2) or (inst.level == "low" and 1) or 0
			inst.level = "lowest"
			inst.AnimState:OverrideSymbol("pillar_full", "daywalker_pillar", "pillar_lowest")
			inst:AddTag("worker_recoil")
			return true, dlevel
		end
	elseif workleft <= 4 then
		if inst.level ~= "low" then
			local dlevel = (inst.level == "full" and 2) or (inst.level == "med" and 1) or 0
			inst.level = "low"
			inst.AnimState:OverrideSymbol("pillar_full", "daywalker_pillar", "pillar_low")
			inst:RemoveTag("worker_recoil")
			return true, dlevel
		end
	elseif workleft <= 7 then
		if inst.level ~= "med" then
			local dlevel = inst.level == "full" and 1 or 0
			inst.level = "med"
			inst.AnimState:OverrideSymbol("pillar_full", "daywalker_pillar", "pillar_med")
			inst:RemoveTag("worker_recoil")
			return true, dlevel
		end
	end
	return false, 0
end

local function OnEndVibrate(inst)
	inst.vibrate_task = nil
	local daywalker = inst.prisoner:value()
	if daywalker ~= nil and daywalker.CountPillars ~= nil then
		local resonating, idle = daywalker:CountPillars()
		if resonating ~= 0 and idle == 0 then
			--All resonating!
			return
		end
	end
	inst.AnimState:PlayAnimation("idle")
	inst.SoundEmitter:KillSound("vibrate_loop")
	inst.SoundEmitter:KillSound("chain_vibrate_loop")
end

local function OnWorked(inst, worker, workleft, numworks)
	if workleft <= 0 and worker ~= nil and worker.prefab == "daywalker_sinkhole" then
		return
	end
	inst.AnimState:PlayAnimation("hit")
	inst.AnimState:PushAnimation("idle")
	if workleft < 1 then
		workleft = 1
		inst.components.workable:SetWorkLeft(1)
	end
	local changed, dlevel = UpdateBuild(inst, workleft)
	if changed then
		for i = 1, dlevel do
			inst.components.lootdropper:SpawnLootPrefab("marble")
		end
		inst.debris:set(inst.level == "med" and 2 or 1)
	else
		inst.debris:set(0)
	end
	--Dedicated server does not need to spawn the local fx
	if not (TheNet:IsDedicated() or inst:IsAsleep()) then
		OnDebrisDirty(inst)
	end
	inst.SoundEmitter:KillSound("vibrate_loop")
	inst.SoundEmitter:KillSound("chain_vibrate_loop")
	if workleft <= 1 and not changed and worker ~= nil and worker:HasTag("player") then
		local mult =
			worker.components.workmultiplier ~= nil and
			worker.components.workmultiplier:GetMultiplier(ACTIONS.MINE) or
			1
		if numworks > mult and not worker:HasTag("weremoose") then
			local prisoner = inst.prisoner:value()
			if prisoner ~= nil then
				inst.AnimState:PlayAnimation("pillar_shake", true)
				local num = 1
				if prisoner.CountPillars ~= nil then
					num = prisoner:CountPillars()
				end
				inst.SoundEmitter:PlaySound("daywalker/pillar/chain_rattle_"..tostring(math.min(3, num)), "vibrate_loop")
				inst.SoundEmitter:PlaySound("daywalker/pillar/chain_shake_lp", "chain_vibrate_loop")
				if inst.vibrate_task ~= nil then
					inst.vibrate_task:Cancel()
				end
				inst.vibrate_task = inst:DoTaskInTime(6, OnEndVibrate)
				inst.restartvibrate:push()

				prisoner:PushEvent("pillarvibrating")
			end
		else
			worker:PushEvent("tooltooweak", { workaction = ACTIONS.MINE })
		end
	end
end

local function OnDestroyed(inst)
	inst.hole.Transform:SetPosition(inst.hole.Transform:GetWorldPosition())
	inst.hole.entity:SetParent(nil)
	inst.hole.persists = false
	ErodeAway(inst.hole)
	ErodeAway(inst)
end

local function OnWorkFinished(inst, worker)
	if inst.persists then
		inst.persists = false
		inst.components.lootdropper:DropLoot(inst:GetPosition())
		inst.AnimState:PlayAnimation("pillar_fall")
		inst.SoundEmitter:PlaySound("daywalker/pillar/destroy")
		inst:ListenForEvent("animover", OnDestroyed)
		inst:AddTag("NOCLICK")
	end
end

local function OnWorkLoad(inst)
	if inst.components.workable.workleft < 1 then
		inst.components.workable:SetWorkLeft(1)
	end
	UpdateBuild(inst, inst.components.workable.workleft)
end

local function OnCollided(inst, other)
	inst.SoundEmitter:PlaySound("daywalker/pillar/hit")
	OnWorked(inst, other, inst.components.workable.workleft, 0)
end

--------------------------------------------------------------------------

local function GetStatus(inst)
	return inst.level == "lowest" and "EXPOSED" or nil
end

local function OnLoadPostPass(inst)--, ents, data)
	local prisoner = inst.components.entitytracker:GetEntity("prisoner")
	if prisoner ~= nil then
		inst:SetPrisoner(prisoner)
	else
		prisoner = inst.components.entitytracker:GetEntity("freed")
		if prisoner ~= nil then
			inst:ListenForEvent("onremove", inst._onremoveprisoner, prisoner)
		else
			inst:Remove()
		end
	end
end

--------------------------------------------------------------------------

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddNetwork()

	inst:AddTag("daywalker_pillar")
	inst:AddTag("event_trigger")

	MakeObstaclePhysics(inst, .95)
	inst.Physics:CollidesWith(COLLISION.OBSTACLES) --for ocean to block boats

	inst.AnimState:SetBank("daywalker_pillar")
	inst.AnimState:SetBuild("daywalker_pillar")
	inst.AnimState:PlayAnimation("idle", true)

	inst.enablechains = net_bool(inst.GUID, "daywalker_pillar.enablechains", "chainsdirty")
	inst.prisoner = net_entity(inst.GUID, "daywalker_pillar.prisoner")
	inst.debris = net_tinybyte(inst.GUID, "daywalker_pillar.debris", "debrisdirty")
	inst.restartvibrate = net_event(inst.GUID, "daywalker_pillar.restartvibrate")

	inst.OnRemoveEntity = RemoveChains

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		inst:ListenForEvent("chainsdirty", OnChainsDirty)
		inst:DoTaskInTime(0, inst.ListenForEvent, "debrisdirty", OnDebrisDirty)

		return inst
	end

	inst.hole = SpawnPrefab("daywalker_pillar_hole")
	inst.hole.entity:SetParent(inst.entity)
	inst.hole.persists = false

	inst.level = "full"

	inst:AddComponent("inspectable")
	inst.components.inspectable.getstatus = GetStatus

	inst:AddComponent("workable")
	inst.components.workable:SetWorkAction(ACTIONS.MINE)
	inst.components.workable:SetWorkLeft(TUNING.DAYWALKER_PILLAR_MINE)
	inst.components.workable:SetOnWorkCallback(OnWorked)
	inst.components.workable:SetOnFinishCallback(OnWorkFinished)
	inst.components.workable:SetOnLoadFn(OnWorkLoad)
	inst.components.workable.savestate = true

	inst:AddComponent("lootdropper")
	inst.components.lootdropper:SetChanceLootTable("daywalker_pillar")

	inst:AddComponent("entitytracker")

	inst._onremoveprisoner = function(daywalker)
		if not inst:IsAsleep() then
			SpawnPrefab("shadow_despawn").Transform:SetPosition(inst.Transform:GetWorldPosition())
		end
		inst:Remove()
	end

	inst._onchainbreak = function(daywalker)
		inst:SetPrisoner(nil)
		inst.SoundEmitter:KillSound("vibrate_loop")
		inst.SoundEmitter:KillSound("chain_vibrate_loop")
		inst.AnimState:PlayAnimation("hit")
		inst.AnimState:PushAnimation("idle")
		if inst.vibrate_task ~= nil then
			inst.vibrate_task:Cancel()
			inst.vibrate_task = nil
		end

		inst.components.entitytracker:TrackEntity("freed", daywalker)
		inst:ListenForEvent("onremove", inst._onremoveprisoner, daywalker)
	end

	inst.SetPrisoner = SetPrisoner
	inst.GetPrisoner = GetPrisoner
	inst.IsResonating = IsResonating
	inst.OnCollided = OnCollided
	inst.OnLoadPostPass = OnLoadPostPass

	return inst
end

--------------------------------------------------------------------------

local function fn_hole()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddNetwork()

	--inst:AddTag("FX")
	inst:AddTag("decor")
	inst:AddTag("NOCLICK")

	inst.AnimState:SetBank("daywalker_hole")
	inst.AnimState:SetBuild("daywalker_hole")
	inst.AnimState:PlayAnimation("ground_1")
	inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
	inst.AnimState:SetLayer(LAYER_BACKGROUND)
	inst.AnimState:SetSortOrder(3)

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	return inst
end

--------------------------------------------------------------------------

return Prefab("daywalker_pillar", fn, assets, prefabs),
	Prefab("daywalker_pillar_hole", fn_hole, assets_hole)
