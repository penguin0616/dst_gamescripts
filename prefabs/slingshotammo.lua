local SpDamageUtil = require("components/spdamageutil")

local assets =
{
    Asset("ANIM", "anim/slingshotammo.zip"),
}

----------------------------------------------------------------------------------------------------------------------------------------

local AOE_TARGET_MUST_TAGS     = { "_combat", "_health" }
local AOE_TARGET_CANT_TAGS     = { "INLIMBO", "notarget", "noattack", "flight", "invisible", "playerghost", "companion", "player" }
local AOE_TARGET_CANT_TAGS_PVP = { "INLIMBO", "notarget", "noattack", "flight", "invisible", "playerghost" }

----------------------------------------------------------------------------------------------------------------------------------------

-- temp aggro system for the slingshots
local function no_aggro(attacker, target)
	local targets_target = target.components.combat ~= nil and target.components.combat.target or nil
	return targets_target ~= nil and targets_target:IsValid() and targets_target ~= attacker and attacker ~= nil and attacker:IsValid()
			and (GetTime() - target.components.combat.lastwasattackedbytargettime) < 4
			and (targets_target.components.health ~= nil and not targets_target.components.health:IsDead())
end

local function ImpactFx(inst, attacker, target)
    if target ~= nil and target:IsValid() then
		local impactfx = SpawnPrefab(inst.ammo_def.impactfx)
		impactfx.Transform:SetPosition(target.Transform:GetWorldPosition())
    end
end

local function OnAttack(inst, attacker, target)
	if target ~= nil and target:IsValid() and attacker ~= nil and attacker:IsValid() then
		if inst.ammo_def ~= nil and inst.ammo_def.onhit ~= nil then
			inst.ammo_def.onhit(inst, attacker, target)
		end
		ImpactFx(inst, attacker, target)
	end
end

local function OnPreHit(inst, attacker, target)
    if inst.ammo_def ~= nil and inst.ammo_def.onprehit ~= nil then
        inst.ammo_def.onprehit(inst, attacker, target)
    end

    if target ~= nil and target:IsValid() and target.components.combat ~= nil and no_aggro(attacker, target) then
        target.components.combat:SetShouldAvoidAggro(attacker)
	end
end

local function OnHit(inst, attacker, target)
    if target ~= nil and target:IsValid() and target.components.combat ~= nil then
		target.components.combat:RemoveShouldAvoidAggro(attacker)
	end
    inst:Remove()
end

local function NoHoles(pt)
    return not TheWorld.Map:IsPointNearHole(pt)
end

local function SpawnShadowTentacle(inst, attacker, target, pt, starting_angle)
    local offset = FindWalkableOffset(pt, starting_angle, 2, 3, false, true, NoHoles, false, true)
    if offset ~= nil then
        local tentacle = SpawnPrefab("shadowtentacle")
        if tentacle ~= nil then
			tentacle.owner = attacker
            tentacle.Transform:SetPosition(pt.x + offset.x, 0, pt.z + offset.z)
            tentacle.components.combat:SetTarget(target)

			tentacle.SoundEmitter:PlaySound("dontstarve/characters/walter/slingshot/shadowTentacleAttack_1")
			tentacle.SoundEmitter:PlaySound("dontstarve/characters/walter/slingshot/shadowTentacleAttack_2")
        end
    end
end

local function OnHit_Thulecite(inst, attacker, target)
    if math.random() < 0.5 then
        local pt
        if target ~= nil and target:IsValid() then
            pt = target:GetPosition()
        else
            pt = inst:GetPosition()
            target = nil
        end

		local theta = math.random() * TWOPI
		SpawnShadowTentacle(inst, attacker, target, pt, theta)
    end
end

--------------------------------------------------------------------------

local MAX_HONEY_VARIATIONS = 7
local MAX_PICK_INDEX = 3
local HONEY_VAR_POOL = { 1 }
for i = 2, MAX_HONEY_VARIATIONS do
	table.insert(HONEY_VAR_POOL, math.random(i), i)
end

local function PickHoney()
	local rand = table.remove(HONEY_VAR_POOL, math.random(MAX_PICK_INDEX))
	table.insert(HONEY_VAR_POOL, rand)
	return rand
end

local function TrySpawnHoney(target, min_scale, max_scale, duration)
	local x, y, z = target.Transform:GetWorldPosition()
	if TheWorld.Map:IsPassableAtPoint(x, 0, z) then
		local fx = SpawnPrefab("honey_trail")
		fx.Transform:SetPosition(x, 0, z) -- NOTES(JBK): This must be before SetVariation is called!
		fx:SetVariation(PickHoney(), GetRandomMinMax(min_scale, max_scale), duration + math.random() * .5)
	elseif TheWorld.has_ocean then
		SpawnPrefab("ocean_splash_ripple"..tostring(math.random(2))).Transform:SetPosition(x, 0, z)
	end
end

local function OnUpdate_Honey(target, t0)
	local elapsed = GetTime() - t0
	if elapsed < TUNING.SLINGSHOT_AMMO_HONEY_DURATION then
		local k = 1 - elapsed / TUNING.SLINGSHOT_AMMO_HONEY_DURATION
		k = k * k * 0.6 + 0.3
		TrySpawnHoney(target, k, k + 0.2, 2)
	else
		target._slingshot_honeytask:Cancel()
		target._slingshot_honeytask = nil
		target:RemoveTag("honey_ammo_afflicted")
		if target.components.locomotor then
			target.components.locomotor:RemoveExternalSpeedMultiplier(target, "honey_ammo_afflicted")
		end
		target:PushEvent("stop_honey_ammo_afflicted")
	end
end

local function OnHit_Honey(inst, attacker, target)
	if target and target:IsValid() then
		local pushstartevent
		if target._slingshot_honeytask then
			target._slingshot_honeytask:Cancel()
		else
			target:AddTag("honey_ammo_afflicted")
			if target.components.locomotor and not target:HasAnyTag("flying", "playerghost") then
				target.components.locomotor:SetExternalSpeedMultiplier(target, "honey_ammo_afflicted", TUNING.BEEQUEEN_HONEYTRAIL_SPEED_PENALTY)
			end
			pushstartevent = true
		end
		target._slingshot_honeytask = target:DoPeriodicTask(1, OnUpdate_Honey, 0.43, GetTime())

		if not no_aggro(attacker, target) and target.components.combat then
			target:PushEvent("attacked", { attacker = attacker, damage = 0, weapon = inst })
		end

		if pushstartevent then
			target:PushEvent("start_honey_ammo_afflicted")
		end
	end
end

--------------------------------------------------------------------------

local function onloadammo_ice(inst, data)
	if data ~= nil and data.slingshot then
		data.slingshot:AddTag("extinguisher")
	end
end

local function onunloadammo_ice(inst, data)
	if data ~= nil and data.slingshot then
		data.slingshot:RemoveTag("extinguisher")
	end
end

local function OnHit_Ice(inst, attacker, target)
    if target.components.sleeper ~= nil and target.components.sleeper:IsAsleep() then
        target.components.sleeper:WakeUp()
    end

    if target.components.burnable ~= nil then
        if target.components.burnable:IsBurning() then
            target.components.burnable:Extinguish()
        elseif target.components.burnable:IsSmoldering() then
            target.components.burnable:SmotherSmolder()
        end
    end

    if target.components.freezable ~= nil then
        target.components.freezable:AddColdness(TUNING.SLINGSHOT_AMMO_FREEZE_COLDNESS)
        target.components.freezable:SpawnShatterFX()
    else
        local fx = SpawnPrefab("shatter")
        fx.Transform:SetPosition(target.Transform:GetWorldPosition())
        fx.components.shatterfx:SetLevel(2)
    end

    if not no_aggro(attacker, target) and target.components.combat ~= nil then
        target.components.combat:SuggestTarget(attacker)
    end
end

--------------------------------------------------------------------------

local function OnHit_Speed(inst, attacker, target)
	local debuffkey = inst.prefab

	if target ~= nil and target:IsValid() and target.components.locomotor ~= nil then
		if target._slingshot_speedmulttask ~= nil then
			target._slingshot_speedmulttask:Cancel()
		end
		target._slingshot_speedmulttask = target:DoTaskInTime(TUNING.SLINGSHOT_AMMO_MOVESPEED_DURATION, function(i) i.components.locomotor:RemoveExternalSpeedMultiplier(i, debuffkey) i._slingshot_speedmulttask = nil end)

		target.components.locomotor:SetExternalSpeedMultiplier(target, debuffkey, TUNING.SLINGSHOT_AMMO_MOVESPEED_MULT)
	end
end

local function OnHit_Distraction(inst, attacker, target)
	if target ~= nil and target:IsValid() and target.components.combat ~= nil then
		local targets_target = target.components.combat.target
		if targets_target == nil or targets_target == attacker then
            target.components.combat:SetShouldAvoidAggro(attacker)
			target:PushEvent("attacked", { attacker = attacker, damage = 0, weapon = inst })
            target.components.combat:RemoveShouldAvoidAggro(attacker)

			if not target:HasTag("epic") then
				target.components.combat:DropTarget()
			end
		end
	end
end

local AOE_RADIUS_PADDING = 3

local function DoAOEDamage(inst, attacker, target, damage, radius)
    local x, y, z = target.Transform:GetWorldPosition()

    local combat = attacker ~= nil and attacker.components.combat or nil

    if combat == nil then
        return
    end

    local _ignorehitrange = combat.ignorehitrange

    combat.ignorehitrange = true

    for i, v in ipairs(TheSim:FindEntities(x, y, z, radius + AOE_RADIUS_PADDING, AOE_TARGET_MUST_TAGS, TheNet:GetPVPEnabled() and AOE_TARGET_CANT_TAGS_PVP or AOE_TARGET_CANT_TAGS)) do
        if v ~= target and
            v:IsValid() and not v:IsInLimbo() and
            not (v.components.health ~= nil and v.components.health:IsDead()) and
            not attacker.components.combat:IsAlly(v)
        then
            local range = radius + v:GetPhysicsRadius(0)

            if v:GetDistanceSqToPoint(x, y, z) < range * range then
                local spdmg = SpDamageUtil.CollectSpDamage(inst)

                v.components.combat:GetAttacked(attacker, damage, inst, inst.components.projectile.stimuli, spdmg)
            end
        end
    end

    combat.ignorehitrange = _ignorehitrange
end

local function OnHit_Stinger(inst, attacker, target)
    DoAOEDamage(inst, attacker, target, TUNING.SLINGSHOT_AMMO_DAMAGE_STINGER_AOE, TUNING.SLINGSHOT_AMMO_RANGE_STINGER_AOE)
end

local function OnHit_MoonGlass(inst, attacker, target)
    DoAOEDamage(inst, attacker, target, TUNING.SLINGSHOT_AMMO_DAMAGE_MOONGLASS_AOE, TUNING.SLINGSHOT_AMMO_RANGE_MOONGLASS_AOE)
end

--------------------------------------------------------------------------

local function TrySpawnGelBlob(target)
	local x, y, z = target.Transform:GetWorldPosition()
	if TheWorld.Map:IsPassableAtPoint(x, 0, z) then
		local blob = SpawnPrefab("gelblob_small_fx")
		blob.Transform:SetPosition(x, 0, z)
		blob:SetLifespan(TUNING.SLINGSHOT_AMMO_GELBLOB_DURATION)
		blob:ReleaseFromAmmoAfflicted()
		return blob
	elseif TheWorld.has_ocean then
		SpawnPrefab("ocean_splash_ripple"..tostring(math.random(2))).Transform:SetPosition(x, 0, z)
	end
end

local function OnRemoveTarget_GelBlob(target)
	if target._slingshot_gelblob.blob and target._slingshot_gelblob.blob:IsValid() then
		target._slingshot_gelblob.blob:KillFX()
		target._slingshot_gelblob.blob = nil
	end
end

local function OnUpdate_GelBlob(target)
	local data = target._slingshot_gelblob
	local elapsed = GetTime() - data.t0
	if elapsed < TUNING.SLINGSHOT_AMMO_GELBLOB_DURATION then
		if data.blob then
			if not data.blob:IsValid() then
				data.blob = nil
				data.wasafflicted = false
			elseif data.start or (data.wasafflicted and data.blob._targets[target] == nil) then
				data.blob:KillFX(true)
				data.blob = nil
				data.wasafflicted = false
			end
		end
		if data.blob == nil then
			data.blob = TrySpawnGelBlob(target)
		end
		if not data.wasafflicted and data.blob and data.blob._targets[target] then
			data.wasafflicted = true
		end
		data.start = nil
	else
		if data.blob then
			data.blob:KillFX(true)
			data.blob = nil
		end
		data.task:Cancel()
		target._slingshot_gelblob = nil
		target:RemoveTag("gelblob_ammo_afflicted")
		target:RemoveEventCallback("onremove", OnRemoveTarget_GelBlob)
		target:PushEvent("stop_gelblob_ammo_afflicted")
	end
end

local function OnHit_GelBlob(inst, attacker, target)
	if target and target:IsValid() then
		local pushstartevent
		if target._slingshot_gelblob then
			target._slingshot_gelblob.task:Cancel()
		else
			target:AddTag("gelblob_ammo_afflicted")
			target:ListenForEvent("onremove", OnRemoveTarget_GelBlob)
			target._slingshot_gelblob = {}
			pushstartevent = true
		end
		target._slingshot_gelblob.start = true
		target._slingshot_gelblob.t0 = GetTime()
		target._slingshot_gelblob.task = target:DoPeriodicTask(0, OnUpdate_GelBlob, 0.43)

		if not no_aggro(attacker, target) and target.components.combat then
			target:PushEvent("attacked", { attacker = attacker, damage = 0, weapon = inst })
		end

		if pushstartevent then
			target:PushEvent("start_gelblob_ammo_afflicted")
		end
	end
end

local function InvMasterPostInit_Gelblob(inst)
    MakeCraftingMaterialRecycler(inst, { gelblob_bottle = "messagebottleempty" })
end

--------------------------------------------------------------------------

local function OnPreHit_Scrapfeather(inst, attacker, target)
    inst.components.weapon:SetElectric(1, TUNING.SLINGSHOT_AMMO_SCRAPFEATHER_WET_DAMAGE_MULT)
end

local function OnHit_Scrapfeather(inst, attacker, target)
    if not (target ~= nil and target:IsValid() and attacker ~= nil and attacker:IsValid()) then
        return
    end

    if not (
        target:HasTag("electricdamageimmune") or
        (target.components.inventory ~= nil and target.components.inventory:IsInsulated())
    ) and
        target:GetIsWet()
    then
        SpawnPrefab("electrichitsparks"):AlignToTarget(target, attacker, true)
    end
end

--------------------------------------------------------------------------

local function OnHit_Gunpowder(inst, owner, target, attacker)
    for i, v in ipairs(AllPlayers) do
        local distSq = v:GetDistanceSqToInst(target)
        local k = math.max(0, math.min(1, distSq / 400))
        local intensity = k * 0.75 * (k - 2) + 0.75
        if intensity > 0 then
            v:ShakeCamera(CAMERASHAKE.FULL, .7, .02, intensity / 2)
        end
    end

    local fx = SpawnPrefab("explode_small")

    if fx ~= nil then
        fx.Transform:SetPosition(target.Transform:GetWorldPosition())
    end
end

local function OnLaunch_Gunpowder(inst, owner, target, attacker)
    inst.SoundEmitter:PlaySound("meta5/walter/ammo_gunpowder_shoot")

    --attacker:PushEvent("knockback", { knocker = target, radius = 1.25, strengthmult = 1.25, forcelanded = true })
end

--------------------------------------------------------------------------

local function OnMiss(inst, owner, target)
    inst:Remove()
end

local function OnUpdateSkillshot(inst)
    local x, y, z = inst.Transform:GetWorldPosition()

    local attacker = inst._attacker

    if not (attacker ~= nil and attacker.components.combat ~= nil and attacker:IsValid()) then
        return
    end

    for i, v in ipairs(TheSim:FindEntities(x, y, z, 4, AOE_TARGET_MUST_TAGS, TheNet:GetPVPEnabled() and AOE_TARGET_CANT_TAGS_PVP or AOE_TARGET_CANT_TAGS)) do
        local range = v:GetPhysicsRadius(.5) + inst.components.projectile.hitdist

        if v:GetDistanceSqToPoint(x, y, z) < range * range and
            attacker.components.combat:CanTarget(v) and
            v.components.combat:CanBeAttacked(attacker) and
            not attacker.components.combat:IsAlly(v)
        then
            inst.components.projectile:Hit(v)

            break
        end
    end
end

local function OnThrown(inst, owner, target, attacker)
    if inst.ammo_def ~= nil and inst.ammo_def.onlaunch ~= nil then
        inst.ammo_def.onlaunch(inst, owner, target, attacker)
    end

    if not target:HasTag("CLASSIFIED") then
        return -- Not a fake target.
    end

    inst._attacker = attacker

    inst.components.projectile:SetHitDist(.7)

    inst:AddComponent("updatelooper")
    inst.components.updatelooper:AddOnUpdateFn(OnUpdateSkillshot)
end

local function SetHighProjectile(inst)
    inst.AnimState:PlayAnimation("spin_loop_mount")
    inst.AnimState:PushAnimation("spin_loop")
end

local function SetChargedMultiplier(inst, mult)
	local damagemult = 1 + (TUNING.SLINGSHOT_MAX_CHARGE_DAMAGE_MULT - 1) * mult
	local speedmult = 1 + (TUNING.SLINGSHOT_MAX_CHARGE_SPEED_MULT - 1) * mult

	local dmg = inst.components.weapon.damage
	if dmg and  dmg > 0 then
		inst.components.weapon:SetDamage(dmg * damagemult)
	end
	if inst.components.planardamage then
		inst.components.planardamage:AddMultiplier(inst, mult, "chargedattack")
	end

	inst.components.projectile:SetSpeed(inst.components.projectile.speed * speedmult)
end

local function projectile_fn(ammo_def)
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst.Transform:SetFourFaced()

    MakeProjectilePhysics(inst)

    inst.AnimState:SetBank("slingshotammo")
    inst.AnimState:SetBuild("slingshotammo")
    inst.AnimState:PlayAnimation("spin_loop", true)
	if ammo_def.symbol ~= nil then
		inst.AnimState:OverrideSymbol("rock", "slingshotammo", ammo_def.symbol)
	end

    --projectile (from projectile component) added to pristine state for optimization
    inst:AddTag("projectile")

	if ammo_def.tags then
		for _, tag in pairs(ammo_def.tags) do
			inst:AddTag(tag)
		end
	end

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.SetHighProjectile = SetHighProjectile
	inst.SetChargedMultiplier = SetChargedMultiplier

    inst.persists = false

	inst.ammo_def = ammo_def

	if ammo_def.planar then
		inst:AddComponent("planardamage")
		inst.components.planardamage:SetBaseDamage(ammo_def.planar)
	end

	if ammo_def.damagetypebonus then
		inst:AddComponent("damagetypebonus")
		for k, v in pairs(ammo_def.damagetypebonus) do
			inst.components.damagetypebonus:AddBonus(k, inst, v)
		end
	end

	inst:AddComponent("weapon")
	inst.components.weapon:SetDamage(ammo_def.damage)
	inst.components.weapon:SetOnAttack(OnAttack)

    inst:AddComponent("projectile")
    inst.components.projectile:SetSpeed(25)
    inst.components.projectile:SetHoming(false)
    inst.components.projectile:SetHitDist(1.5)
    inst.components.projectile:SetOnPreHitFn(OnPreHit)
    inst.components.projectile:SetOnHitFn(OnHit)
    inst.components.projectile:SetOnMissFn(OnMiss)
    inst.components.projectile:SetOnThrownFn(OnThrown)
    inst.components.projectile.range = 30
	inst.components.projectile.has_damage_set = true

    return inst
end

local function inv_fn(ammo_def)
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetRayTestOnBB(true)
    inst.AnimState:SetBank("slingshotammo")
    inst.AnimState:SetBuild("slingshotammo")
    inst.AnimState:PlayAnimation("idle")
	if ammo_def.symbol ~= nil then
		inst.AnimState:OverrideSymbol("rock", "slingshotammo", ammo_def.symbol)
        inst.scrapbook_overridedata = {"rock", "slingshotammo", ammo_def.symbol}
	end

    inst:AddTag("molebait")
	inst:AddTag("slingshotammo")
	inst:AddTag("reloaditem_ammo")

	inst.REQUIRED_SKILL = ammo_def.skill

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

	inst:AddComponent("reloaditem")

    inst:AddComponent("edible")
    inst.components.edible.foodtype = FOODTYPE.ELEMENTAL
    inst.components.edible.hungervalue = 1
    inst:AddComponent("tradable")

    inst:AddComponent("stackable")
    inst.components.stackable.maxsize = TUNING.STACK_SIZE_TINYITEM

    inst:AddComponent("inspectable")

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem:SetSinks(true)

    inst:AddComponent("bait")
    MakeHauntableLaunch(inst)

	if ammo_def.fuelvalue ~= nil then
		inst:AddComponent("fuel")
		inst.components.fuel.fuelvalue = ammo_def.fuelvalue
	end

	if ammo_def.onloadammo ~= nil and ammo_def.onunloadammo ~= nil then
		inst:ListenForEvent("ammoloaded", ammo_def.onloadammo)
		inst:ListenForEvent("ammounloaded", ammo_def.onunloadammo)
		inst:ListenForEvent("onremove", ammo_def.onunloadammo)
	end

    if ammo_def.inv_master_postinit ~= nil then
        ammo_def.inv_master_postinit(inst, ammo_def)
    end

    return inst
end

-- NOTE(DiogoW): Add an entry to SCRAPBOOK_DEPS table in prefabs/slingshot.lua when adding a new ammo.
local ammo =
{
	{
		name = "slingshotammo_rock",
		damage = TUNING.SLINGSHOT_AMMO_DAMAGE_ROCKS,
	},
    {
        name = "slingshotammo_gold",
		symbol = "gold",
        damage = TUNING.SLINGSHOT_AMMO_DAMAGE_GOLD,
    },
	{
		name = "slingshotammo_marble",
		symbol = "marble",
		damage = TUNING.SLINGSHOT_AMMO_DAMAGE_MARBLE,
	},
	{
		name = "slingshotammo_thulecite", -- chance to spawn a Shadow Tentacle
		symbol = "thulecite",
		onhit = OnHit_Thulecite,
		damage = TUNING.SLINGSHOT_AMMO_DAMAGE_THULECITE,
	},
	{
		name = "slingshotammo_honey",
		symbol = "honey",
		onhit = OnHit_Honey,
		damage = nil,
		skill = "walter_slingshot_ammo_honey",
	},
    {
        name = "slingshotammo_freeze",
		symbol = "freeze",
        onhit = OnHit_Ice,
		tags = { "extinguisher" },
		onloadammo = onloadammo_ice,
		onunloadammo = onunloadammo_ice,
        damage = nil,
    },
    {
        name = "slingshotammo_slow",
		symbol = "slow",
        onhit = OnHit_Speed,
        damage = TUNING.SLINGSHOT_AMMO_DAMAGE_SLOW,
    },
    {
        name = "slingshotammo_poop", -- distraction (drop target, note: hostile creatures will probably retarget you very shortly after)
		symbol = "poop",
        onhit = OnHit_Distraction,
        damage = nil,
		fuelvalue = TUNING.MED_FUEL / 10, -- 1/10th the value of using poop
    },
    {
        name = "slingshotammo_moonglass",
		symbol = "moonglass",
        onhit = OnHit_MoonGlass,
        damage = TUNING.SLINGSHOT_AMMO_DAMAGE_MOONGLASS,
		skill = "walter_slingshot_ammo_moonglass",
    },
    {
        name = "slingshotammo_moonglasscharged",
		symbol = "moonglasscharged",
        onhit = OnHit_MoonGlass,
        damage = TUNING.SLINGSHOT_AMMO_DAMAGE_MOONGLASS,
		skill = "walter_slingshot_ammo_moonglasscharged",
    },
    {
        name = "slingshotammo_dreadstone",
		symbol = "dreadstone",
		damage = TUNING.SLINGSHOT_AMMO_DAMAGE_DREADSTONE,
		planar = TUNING.SLINGSHOT_AMMO_PLANAR_DREADSTONE,
		damagetypebonus = { ["lunar_aligned"] = TUNING.SLINGSHOT_AMMO_DREADSTONE_VS_LUNAR_BONUS },
		skill = "walter_slingshot_ammo_dreadstone",
    },
    {
        name = "slingshotammo_gunpowder",
		symbol = "gunpowder",
        onlaunch = OnLaunch_Gunpowder,
        onhit = OnHit_Gunpowder,
        damage = TUNING.SLINGSHOT_AMMO_DAMAGE_GUNPOWDER,
		skill = "walter_slingshot_ammo_gunpowder",
    },
    {
        name = "slingshotammo_lunarplanthusk",
		symbol = "lunarplanthusk",
		damage = TUNING.SLINGSHOT_AMMO_DAMAGE_LUNARPLANTHUSK,
		planar = TUNING.SLINGSHOT_AMMO_PLANAR_LUNARPLANTHUSK,
		damagetypebonus = { ["shadow_aligned"] = TUNING.SLINGSHOT_AMMO_LUNARPLANTHUSK_VS_SHADOW_BONUS },
		skill = "walter_allegiance_lunar",
    },
    {
		name = "slingshotammo_purebrilliance",
		symbol = "purebrilliance",
		--TODO
		skill = "walter_allegiance_lunar",
    },
    {
        name = "slingshotammo_purehorror",
		symbol = "purehorror",
		--TODO
		skill = "walter_allegiance_shadow",
    },
	{
		name = "slingshotammo_gelblob",
		symbol = "gelblob",
		onhit = OnHit_GelBlob,
        inv_master_postinit = InvMasterPostInit_Gelblob,
		damage = nil,
		skill = "walter_allegiance_shadow",
	},
    {
        name = "slingshotammo_scrapfeather",
		symbol = "scrapfeather",
        onprehit = OnPreHit_Scrapfeather,
        onhit = OnHit_Scrapfeather,
        damage = TUNING.SLINGSHOT_AMMO_DAMAGE_SCRAPFEATHER,
		skill = "walter_slingshot_ammo_scrapfeather",
    },
    {
        name = "slingshotammo_stinger",
		symbol = "stinger",
        onhit = OnHit_Stinger,
        damage = TUNING.SLINGSHOT_AMMO_DAMAGE_STINGER,
		skill = "walter_slingshot_ammo_stinger",
    },
    {
        name = "trinket_1",
		no_inv_item = true,
		symbol = "trinket_1",
		damage = TUNING.SLINGSHOT_AMMO_DAMAGE_TRINKET_1,
    },
}

local ammo_prefabs = {}

local function AddAmmoPrefab(name, data, fn, prefabs)
    table.insert(ammo_prefabs, Prefab(name, function() return fn(data) end, assets, prefabs))
end

for _, data in ipairs(ammo) do
    data.impactfx = "slingshotammo_hitfx_" .. (data.symbol or "rock")

    if not data.no_inv_item then
        AddAmmoPrefab(data.name, data, inv_fn, { data.name.."_proj" })
    end

    AddAmmoPrefab(data.name.."_proj", data, projectile_fn, { "shatter", data.impactfx })
end

return unpack(ammo_prefabs)