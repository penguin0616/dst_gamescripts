local assets =
{
	Asset("ANIM", "anim/sharkboi_build.zip"),
	Asset("ANIM", "anim/sharkboi_basic.zip"),
	Asset("ANIM", "anim/sharkboi_action.zip"),
	Asset("ANIM", "anim/sharkboi_actions1.zip"),
}

local prefabs =
{
	"sharkboi_iceimpact_fx",
	"sharkboi_iceplow_fx",
	"sharkboi_icespike",
	"sharkboi_icetrail_fx",
	"sharkboi_icetunnel_fx",
	"sharkboi_swipe_fx",
	"splash_green_large",
	"bootleg",
}

local brain = require("brains/sharkboibrain")

SetSharedLootTable("sharkboi",
{
	{ "bootleg", 1 },
	{ "bootleg", 1 },
	{ "bootleg", 0.5 },
})

local FIN_MASS = 99999
local FIN_RADIUS = 0.5

local STANDING_MASS = 1000
local STANDING_RADIUS = 1

local function OnFinModeDirty(inst)
	inst:SetPhysicsRadiusOverride(inst.finmode:value() and FIN_RADIUS or STANDING_RADIUS)
end

local function ChangeRadius(inst, radius)
	inst:SetPhysicsRadiusOverride(radius)
	if inst.sg.mem.isobstaclepassthrough then
		if inst.sg.mem.radius ~= radius then
			inst.sg.mem.radius = radius
			inst.Physics:SetCapsule(radius, 1)
		end
	elseif inst.sg.mem.physicstask == nil then
		if inst.sg.mem.ischaracterpassthrough then
			if inst.sg.mem.radius ~= radius then
				inst.Physics:SetCapsule(STANDING_RADIUS, 1)
				if inst.sg.mem.radius < radius then
					inst.Physics:Teleport(inst.Transform:GetWorldPosition())
				end
				inst.sg.mem.radius = STANDING_RADIUS
			end
		else
			ToggleOffAllObjectCollisions(inst)
			local x, y, z = inst.Transform:GetWorldPosition()
			ToggleOnAllObjectCollisionsAt(inst, x, z)
		end
	end
end

local function OnNewState(inst)
	local dochangemass
	if inst.sg:HasStateTag("digging") then
		if not (inst.sg.lasttags and inst.sg.lasttags["digging"]) then
			inst.Physics:SetMass(0)
		end
	elseif inst.sg.lasttags and inst.sg.lasttags["digging"] then
		if inst.sg:HasStateTag("fin") then
			inst.Physics:SetMass(FIN_MASS)
		else
			inst.Physics:SetMass(STANDING_MASS)
			--stunned out of digging?
			inst.components.timer:StopTimer("standing_dive_cd")
			inst.components.timer:StartTimer("standing_dive_cd", TUNING.SHARKBOI_STANDING_DIVE_CD / 2)
		end
	else
		dochangemass = true
	end

	if inst.sg:HasStateTag("fin") then
		if not inst.finmode:value() then
			inst.finmode:set(true)
			inst.Transform:SetEightFaced()
			inst.DynamicShadow:Enable(false)
			if dochangemass then
				inst.Physics:SetMass(FIN_MASS)
			end
			ChangeRadius(inst, FIN_RADIUS)
			inst.components.health:SetInvincible(true)
			inst.components.combat:RestartCooldown()
			inst.components.locomotor.runspeed = TUNING.SHARKBOI_FINSPEED
		end
	elseif inst.finmode:value() then
		inst.finmode:set(false)
		inst.Transform:SetFourFaced()
		if not inst.sg:HasStateTag("invisible") then
			inst.DynamicShadow:Enable(true)
		end
		if dochangemass then
			inst.Physics:SetMass(STANDING_MASS)
		end
		ChangeRadius(inst, STANDING_RADIUS)
		inst.components.health:SetInvincible(false)
		inst.components.locomotor.runspeed = TUNING.SHARKBOI_RUNSPEED
		inst.components.timer:StopTimer("standing_dive_cd")
		inst.components.timer:StartTimer("standing_dive_cd", TUNING.SHARKBOI_STANDING_DIVE_CD)
	end
end

local function teleport_override_fn(inst)
    local sharkboimanager = TheWorld.components.sharkboimanager
    if sharkboimanager == nil then
        return nil
    end

    return sharkboimanager:FindWalkableOffsetInArena(inst)
end

--------------------------------------------------------------------------

local function UpdatePlayerTargets(inst)
	local toadd = {}
	local toremove = {}
	local x, y, z = inst.Transform:GetWorldPosition()

	for k in pairs(inst.components.grouptargeter:GetTargets()) do
		toremove[k] = true
	end

	local sharkboimanager = TheWorld.components.sharkboimanager
	if sharkboimanager and sharkboimanager:IsPointInArena(inst.Transform:GetWorldPosition()) then
		for i, v in ipairs(AllPlayers) do
			if not (v.components.health:IsDead() or v:HasTag("playerghost")) and
				v.entity:IsVisible() and
				sharkboimanager:IsPointInArena(v.Transform:GetWorldPosition())
			then
				if toremove[v] then
					toremove[v] = nil
				else
					table.insert(toadd, v)
				end
			end
		end
	else
		for i, v in ipairs(FindPlayersInRange(x, y, z, TUNING.SHARKBOI_DEAGGRO_DIST, true)) do
			if toremove[v] then
				toremove[v] = nil
			else
				table.insert(toadd, v)
			end
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
	if not inst.aggro then
		return
	end

	UpdatePlayerTargets(inst)

	local target = inst.components.combat.target
	local inrange = target and inst:IsNear(target, TUNING.SHARKBOI_ATTACK_RANGE + target:GetPhysicsRadius(0))

	if target and target:HasTag("player") then
		local newplayer = inst.components.grouptargeter:TryGetNewTarget()
		return newplayer
			and newplayer:IsNear(inst, inrange and TUNING.SHARKBOI_ATTACK_RANGE + newplayer:GetPhysicsRadius(0) or TUNING.SHARKBOI_KEEP_AGGRO_DIST)
			and newplayer
			or nil,
			true
	end

	local nearplayers = {}
	for k in pairs(inst.components.grouptargeter:GetTargets()) do
		if inst:IsNear(k, inrange and TUNING.SHARKBOI_ATTACK_RANGE + k:GetPhysicsRadius(0) or TUNING.SHARKBOI_AGGRO_DIST) then
			table.insert(nearplayers, k)
		end
	end
	return #nearplayers > 0 and nearplayers[math.random(#nearplayers)] or nil, true
end

local function KeepTargetFn(inst, target)
	if inst.aggro and inst.components.combat:CanTarget(target) then
		local sharkboimanager = TheWorld.components.sharkboimanager
		if sharkboimanager and sharkboimanager:IsPointInArena(inst.Transform:GetWorldPosition()) then
			return sharkboimanager:IsPointInArena(target.Transform:GetWorldPosition())
		end
		return inst:IsNear(target, TUNING.SHARKBOI_DEAGGRO_DIST)
	end
	return false
end

local function StartAggro(inst)
	if not inst.aggro then
		inst.aggro = true
        inst:AddTag("hostile")
		inst.components.timer:StopTimer("standing_dive_cd")
		inst.components.timer:StartTimer("standing_dive_cd", TUNING.SHARKBOI_STANDING_DIVE_CD / 2)
		inst.components.timer:StopTimer("torpedo_cd")
		inst.components.timer:StartTimer("torpedo_cd", TUNING.SHARKBOI_TORPEDO_CD / 2)
	end
end

local function StopAggro(inst)
	if inst.aggro then
		inst.aggro = false
        inst:RemoveTag("hostile")
		inst.components.timer:StopTimer("standing_dive_cd")
		inst.components.timer:StopTimer("torpedo_cd")
	end
end

local function OnAttacked(inst, data)
	if data.attacker and not inst.looted then
		local target = inst.components.combat.target
		if not (target and
				target:HasTag("player") and
				target:IsNear(inst, TUNING.SHARKBOI_ATTACK_RANGE + target:GetPhysicsRadius(0))
		) then
			if inst.components.health.currenthealth > inst.components.health.minhealth then
				StartAggro(inst)
			end
			inst.components.combat:SetTarget(data.attacker)
		end
	end
end

--------------------------------------------------------------------------

local function OnSave(inst, data)
	data.aggro = inst.aggro or nil
	data.looted = inst.looted or nil
end

local function OnLoad(inst, data)
	inst.looted = data and data.looted or false
	if inst.components.health.currenthealth <= inst.components.health.minhealth then
		--defeated
		if inst.looted then
			inst:AddTag("notarget")
		else
			inst.sg:GoToState("defeat_loop")
		end
	elseif data and data.aggro and not inst.looted then
		StartAggro(inst)
	end
end

local function OnEntitySleep(inst)
	StopAggro(inst)
	if inst.sg:HasAnyStateTag("fin", "digging") then
		inst.sg:GoToState("idle")
	end
	if inst.looted and inst.sleeptask == nil then
		inst.sleeptask = inst:DoTaskInTime(1, inst.Remove)
	end
end

local function OnEntityWake(inst)
	if inst.sleeptask then
		inst.sleeptask:Cancel()
		inst.sleeptask = nil
	end
end

--------------------------------------------------------------------------

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddDynamicShadow()
	inst.entity:AddSoundEmitter()
	inst.entity:AddNetwork()

	inst:SetPhysicsRadiusOverride(STANDING_RADIUS)
	MakeGiantCharacterPhysics(inst, STANDING_MASS, inst.physicsradiusoverride)
	inst.DynamicShadow:SetSize(3.5, 1.5)
	inst.Transform:SetFourFaced()

	inst:AddTag("scarytoprey")
	inst:AddTag("scarytooceanprey")
	inst:AddTag("monster")
	inst:AddTag("animal")
	inst:AddTag("largecreature")
	inst:AddTag("shark")
	inst:AddTag("wet")
	inst:AddTag("epic")
	--inst:AddTag("noepicmusic") --add this when we have custom music!

	inst.no_wet_prefix = true

	--Sneak these into pristine state for optimization
	inst:AddTag("_named")

	inst.AnimState:SetBank("sharkboi")
	inst.AnimState:SetBuild("sharkboi_build")
	inst.AnimState:PlayAnimation("idle", true)

	inst.finmode = net_bool(inst.GUID, "sharkboi.finmode", "finmodedirty")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		inst:ListenForEvent("finmodedirty", OnFinModeDirty)

		return inst
	end

	--Remove these tags so that they can be added properly when replicating components below
	inst:RemoveTag("_named")

	inst:AddComponent("named")
	inst.components.named.possiblenames = STRINGS.SHARKBOINAMES
	inst.components.named:PickNewName()

	inst:AddComponent("inspectable")

	inst:AddComponent("lootdropper")
	inst.components.lootdropper:SetChanceLootTable("sharkboi")
	inst.components.lootdropper.min_speed = 1
	inst.components.lootdropper.max_speed = 3
	inst.components.lootdropper.y_speed = 14
	inst.components.lootdropper.y_speed_variance = 4
	inst.components.lootdropper.spawn_loot_inside_prefab = true

	inst:AddComponent("locomotor")
	inst.components.locomotor.walkspeed = TUNING.SHARKBOI_WALKSPEED
	inst.components.locomotor.runspeed = TUNING.SHARKBOI_RUNSPEED

	inst:AddComponent("health")
	inst.components.health:SetMinHealth(1)
	inst.components.health:SetMaxHealth(TUNING.SHARKBOI_HEALTH)
	--inst.components.health.nofadeout = true

	inst:AddComponent("combat")
	inst.components.combat:SetDefaultDamage(TUNING.SHARKBOI_DAMAGE)
	inst.components.combat:SetAttackPeriod(TUNING.SHARKBOI_ATTACK_PERIOD)
	inst.components.combat.playerdamagepercent = .5
	inst.components.combat:SetRange(TUNING.SHARKBOI_MELEE_RANGE)
	inst.components.combat:SetRetargetFunction(3, RetargetFn)
	inst.components.combat:SetKeepTargetFunction(KeepTargetFn)
	inst.components.combat.hiteffectsymbol = "sharkboi_torso"
	inst.components.combat.battlecryenabled = false
	inst.components.combat.forcefacing = false

	inst:AddComponent("timer")
	inst:AddComponent("grouptargeter")

	local teleportedoverride = inst:AddComponent("teleportedoverride")
    teleportedoverride:SetDestPositionFn(teleport_override_fn)

	MakeLargeFreezableCharacter(inst, "sharkboi_torso")
	inst.components.freezable:SetResistance(4)
	inst.components.freezable.diminishingreturns = true

	inst:SetStateGraph("SGsharkboi")
	inst:SetBrain(brain)

	inst:ListenForEvent("newstate", OnNewState)
	inst:ListenForEvent("attacked", OnAttacked)

	inst.aggro = false
	inst.looted = false
	inst.StopAggro = StopAggro
	inst.OnSave = OnSave
	inst.OnLoad = OnLoad
	inst.OnEntitySleep = OnEntitySleep
	inst.OnEntityWake = OnEntityWake

	return inst
end

return Prefab("sharkboi", fn, assets, prefabs)
