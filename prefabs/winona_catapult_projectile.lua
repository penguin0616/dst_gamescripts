local assets =
{
    Asset("ANIM", "anim/winona_catapult_projectile.zip"),
}

local prefabs =
{
	"trap_vines",
}

local ELEMENTS = { "shadow", "lunar", "hybrid" }
local ELEMENT_ID = table.invert(ELEMENTS)

local NO_TAGS_PVP = { "INLIMBO", "ghost", "playerghost", "FX", "NOCLICK", "DECOR", "notarget", "companion", "shadowminion" }
local NO_TAGS = { "player" }
for i, v in ipairs(NO_TAGS_PVP) do
    table.insert(NO_TAGS, v)
end
local COMBAT_TAGS = { "_combat" }
local AOE_RANGE_PADDING = 3

local function ResetDamage(inst, attacker)
	attacker.components.combat:SetDefaultDamage(TUNING.WINONA_CATAPULT_DAMAGE)
	attacker.components.planardamage:SetBaseDamage(0)
	attacker.components.damagetypebonus:RemoveBonus("shadow_aligned", inst)
	attacker.components.damagetypebonus:RemoveBonus("lunar_aligned", inst)
end

local function ConfigureElementalDamage(inst, attacker, element)
	if element then
		if inst.mega then
			attacker.components.combat:SetDefaultDamage(0)
			attacker.components.planardamage:SetBaseDamage(TUNING.WINONA_CATAPULT_MEGA_PLANAR_DAMAGE)
		elseif element == "hybrid" then
			attacker.components.combat:SetDefaultDamage(TUNING.WINONA_CATAPULT_HYBRID_NON_PLANAR_DAMAGE)
			attacker.components.planardamage:SetBaseDamage(TUNING.WINONA_CATAPULT_HYBRID_PLANAR_DAMAGE)
		else
			attacker.components.combat:SetDefaultDamage(TUNING.WINONA_CATAPULT_NON_PLANAR_DAMAGE)
			attacker.components.planardamage:SetBaseDamage(TUNING.WINONA_CATAPULT_PLANAR_DAMAGE)
		end

		if element == "lunar" or element == "hybrid" then
			attacker.components.damagetypebonus:AddBonus("shadow_aligned", inst, TUNING.WINONA_CATAPULT_DAMAGETYPE_MULT)
		end
		if element == "shadow" or element == "hybrid" then
			attacker.components.damagetypebonus:AddBonus("lunar_aligned", inst, TUNING.WINONA_CATAPULT_DAMAGETYPE_MULT)
		end
	end
end

local function DoAOEAttack(inst, x, z, attacker, element)
	if attacker and attacker.components.combat and attacker:IsValid() then
		attacker.components.combat.ignorehitrange = true
		ConfigureElementalDamage(inst, attacker, element)
	else
		attacker = nil
	end
	inst.components.combat.ignorehitrange = true
	ConfigureElementalDamage(inst, inst, element)

	local hit = false
	for i, v in ipairs(TheSim:FindEntities(x, 0, z, inst.AOE_RADIUS + AOE_RANGE_PADDING, COMBAT_TAGS, TheNet:GetPVPEnabled() and NO_TAGS_PVP or NO_TAGS)) do
		if v:IsValid() and
			v.entity:IsVisible() and
			v:GetDistanceSqToPoint(x, 0, z) < inst.components.combat:CalcHitRangeSq(v) and
			inst.components.combat:CanTarget(v)
		then
			if attacker and not (v.components.combat.target and v.components.combat.target:HasTag("player")) then
				--if target is not targeting a player, then use the catapult as attacker to draw aggro
				attacker.components.combat:DoAttack(v)
			else
				inst.components.combat:DoAttack(v)
			end
			hit = true
		end
	end

	if attacker then
		attacker.components.combat.ignorehitrange = false
		ResetDamage(inst, attacker)
	end
	inst.components.combat.ignorehitrange = false
	--ResetDamage(inst, inst) -- don't need, we're gonna be deleted

	inst.SoundEmitter:PlaySound("dontstarve/common/together/catapult/rock_hit", nil, hit and .5 or nil)
end

--------------------------------------------------------------------------

local WORK_RADIUS_PADDING = 0.5
local COLLAPSIBLE_WORK_ACTIONS =
{
	CHOP = true,
	DIG = true,
	HAMMER = true,
	MINE = true,
}
local COLLAPSIBLE_TAGS = { "NPC_workable" }
for k, v in pairs(COLLAPSIBLE_WORK_ACTIONS) do
	table.insert(COLLAPSIBLE_TAGS, k.."_workable")
end

local NON_COLLAPSIBLE_TAGS = { "FX", --[["NOCLICK",]] "DECOR", "INLIMBO", "structure", "wall" }

local function DoAOEWork(inst, x, z)
	for i, v in ipairs(TheSim:FindEntities(x, 0, z, inst.AOE_RADIUS + WORK_RADIUS_PADDING, nil, NON_COLLAPSIBLE_TAGS, COLLAPSIBLE_TAGS)) do
		if v:IsValid() and not v:IsInLimbo() then
			local isworkable = false
			if v.components.workable then
				local work_action = v.components.workable:GetWorkAction()
				--V2C: nil action for NPC_workable (e.g. campfires)
				--     allow digging spawners (e.g. rabbithole)
				isworkable = (
					(work_action == nil and v:HasTag("NPC_workable")) or
					(v.components.workable:CanBeWorked() and work_action and COLLAPSIBLE_WORK_ACTIONS[work_action.id])
				)
			end
			if isworkable then
				v.components.workable:Destroy(inst)
				if v:IsValid() and v:HasTag("stump") then
					v:Remove()
				end
			elseif v.components.pickable and v.components.pickable:CanBePicked() and not v:HasTag("intense") then
				v.components.pickable:Pick(inst)
			end
		end
	end
end

local TOSSITEM_MUST_TAGS = { "_inventoryitem" }
local TOSSITEM_CANT_TAGS = { "locomotor", "INLIMBO" }

local function TossLaunch(inst, launcher, basespeed, startheight)
	local x0, y0, z0 = launcher.Transform:GetWorldPosition()
	local x1, y1, z1 = inst.Transform:GetWorldPosition()
	local dx, dz = x1 - x0, z1 - z0
	local dsq = dx * dx + dz * dz
	local angle
	if dsq > 0 then
		local dist = math.sqrt(dsq)
		angle = math.atan2(dz / dist, dx / dist) + (math.random() * 20 - 10) * DEGREES
	else
		angle = TWOPI * math.random()
	end
	local speed = basespeed + math.random()
	inst.Physics:Teleport(x1, startheight, z1)
	inst.Physics:SetVel(math.cos(angle) * speed, speed * 5 + math.random() * 2, math.sin(angle) * speed)
end

local function TossItems(inst, x, z)
	for i, v in ipairs(TheSim:FindEntities(x, 0, z, inst.AOE_RADIUS + WORK_RADIUS_PADDING, TOSSITEM_MUST_TAGS, TOSSITEM_CANT_TAGS)) do
		if v.components.mine then
			v.components.mine:Deactivate()
		end
		if not v.components.inventoryitem.nobounce and v.Physics and v.Physics:IsActive() then
			TossLaunch(v, inst, 1, 0.4)
		end
	end
end

--------------------------------------------------------------------------

local TRAP_TAGS = { "trap_vines" }
local DEPLOY_IGNORE_TAGS = { "flower", "_inventoryitem", "projectile", "trap_vines", "NOBLOCK", "locomotor", "character", "invisible", "FX", "INLIMBO", "DECOR" }

local function SpawnTrapRing(inst, x, z, attacker, r, n, theta)
	local delta = TWOPI / n
	local map = TheWorld.Map
	local pt = Vector3(0, 0, 0)
	for i = 1, n do
		pt.x = x + r * math.cos(theta)
		pt.z = z - r * math.sin(theta)
		if map:IsPassableAtPoint(pt.x, 0, pt.z, false, true) and map:IsDeployPointClear(pt, nil, 1, nil, nil, nil, DEPLOY_IGNORE_TAGS) then
			for _, v in ipairs(TheSim:FindEntities(pt.x, 0, pt.z, 1, TRAP_TAGS)) do
				v:DespawnTrap()
			end
			local trap = SpawnPrefab("trap_vines")
			trap.Transform:SetPosition(pt:Get())
			trap.attacker = attacker
		end
		theta = theta + delta
	end
end

local function SpawnAOETrap(inst, x, z, attacker)
	local theta = math.random() * TWOPI

	if inst.AOE_LEVEL == 1 then
		SpawnTrapRing(inst, x, z, attacker, 0, 1, theta)
		SpawnTrapRing(inst, x, z, attacker, 1.6, 5, theta)
		SpawnTrapRing(inst, x, z, attacker, 3, 10, theta + TWOPI / 20)
	else
		SpawnTrapRing(inst, x, z, attacker, 1, 3, theta)
		SpawnTrapRing(inst, x, z, attacker, 2.4, 8, theta + TWOPI / 15)
		if inst.AOE_LEVEL >= 2 then
			SpawnTrapRing(inst, x, z, attacker, 3.7, 12, theta + TWOPI / 2)
			if inst.AOE_LEVEL >= 3 then
				SpawnTrapRing(inst, x, z, attacker, 5, 16, theta + TWOPI / 91)
			end
		end
	end
end

--------------------------------------------------------------------------

local function OnHit(inst, attacker, target)
    local x, y, z = inst.Transform:GetWorldPosition()
    inst.Physics:Stop()
    inst.Physics:Teleport(x, 0, z)

	local element = ELEMENTS[inst.element:value()]
	if not inst.mega then
		inst.AnimState:PlayAnimation("impact"..(inst.AOE_LEVEL ~= 0 and tostring(inst.AOE_LEVEL) or "")..(element and ("_"..element) or ""))
	elseif element == "shadow" then
		inst.AnimState:PlayAnimation("impact2_shadow")
	else--hybrid or lunar => show the lunar
		inst.AnimState:PlayAnimation("impact"..(inst.AOE_LEVEL ~= 0 and tostring(inst.AOE_LEVEL) or "").."_special")
	end
    inst:ListenForEvent("animover", inst.Remove)

    inst.hideanim:set(true)
    if inst.animent ~= nil then
        inst.animent:Remove()
        inst.animent = nil
    end

	if inst.mega and (element == "lunar" or element == "hybrid") then
		DoAOEWork(inst, x, z)
	end
	if not (inst.mega and element == "shadow") then
		DoAOEAttack(inst, x, z, attacker, element)
	end
	if inst.mega and (element == "shadow" or element == "hybrid") then
		SpawnAOETrap(inst, x, z, attacker)
	end
	if inst.mega and (element == "lunar" or element == "hybrid") then
		TossItems(inst, x, z)
	end
end

local function KeepTargetFn(inst)
    return false
end

local function CreateProjectileAnim()
    local inst = CreateEntity()

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")
    --[[Non-networked entity]]
    inst.persists = false

    inst.entity:AddTransform()
    inst.entity:AddAnimState()

    inst.Transform:SetSixFaced()

    inst.AnimState:SetBank("winona_catapult_projectile")
    inst.AnimState:SetBuild("winona_catapult_projectile")
	inst.AnimState:PlayAnimation("air_rock", true)

    return inst
end

local function OnHideAnimDirty(inst)
    if inst.hideanim:value() and inst.animent ~= nil then
        inst.animent:Remove()
        inst.animent = nil
    end
end

--------------------------------------------------------------------------

local function OnElementDirty(inst)
	if inst.animent then
		local element = ELEMENTS[inst.element:value()]
		inst.animent.AnimState:PlayAnimation("air_"..(element or "rock"), true)
		if element == "lunar" then
			inst.animent.AnimState:SetSymbolBloom("white_parts")
			inst.animent.AnimState:SetSymbolLightOverride("white_parts", 0.1)
		elseif element == "shadow" then
			inst.animent.AnimState:SetSymbolLightOverride("red_parts", 1)
		elseif element == "hybrid" then
			inst.animent.AnimState:SetSymbolBloom("white_parts")
			inst.animent.AnimState:SetSymbolLightOverride("white_parts", 0.1)
			inst.animent.AnimState:SetSymbolLightOverride("red_parts", 1)
		end
	end
end

local function SetElementalRock(inst, element, mega)
	inst.mega = mega or false
	local elem = ELEMENT_ID[element] or 0
	if elem ~= inst.element:value() then
		inst.element:set(elem)
		OnElementDirty(inst)
	end
end

local function SetAoeRadius(inst, radius, level)
	inst.AOE_RADIUS = radius or TUNING.WINONA_CATAPULT_AOE_RADIUS
	inst.AOE_LEVEL = level or 0
	inst.components.combat:SetRange(inst.AOE_RADIUS)
end

--------------------------------------------------------------------------

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddPhysics()
    inst.entity:AddNetwork()

    inst.Transform:SetSixFaced()

    inst.AnimState:SetBank("winona_catapult_projectile")
    inst.AnimState:SetBuild("winona_catapult_projectile")
    inst.AnimState:PlayAnimation("empty")
	inst.AnimState:SetSymbolLightOverride("red_parts", 1)
	inst.AnimState:SetSymbolLightOverride("white_parts_fx", 0.1)
	inst.AnimState:SetSymbolLightOverride("white_parts", 0.1)
	inst.AnimState:SetSymbolBloom("white_parts")

    inst.Physics:SetMass(1)
    inst.Physics:SetFriction(0)
    inst.Physics:SetDamping(0)
	inst.Physics:SetRestitution(0)
    inst.Physics:SetCollisionGroup(COLLISION.ITEMS)
    inst.Physics:ClearCollisionMask()
    inst.Physics:CollidesWith(COLLISION.GROUND)
    inst.Physics:SetSphere(.4)

    inst:AddTag("NOCLICK")
    inst:AddTag("notarget")

    --projectile (from complexprojectile component) added to pristine state for optimization
    inst:AddTag("projectile")

    inst.hideanim = net_bool(inst.GUID, "winona_catapult_projectile.hideanim", "hideanimdirty")
	inst.element = net_tinybyte(inst.GUID, "winona_catapult_projectile.element", "elementdirty")

    --Dedicated server does not need to spawn the local animation
    if not TheNet:IsDedicated() then
        inst.animent = CreateProjectileAnim()
        inst.animent.entity:SetParent(inst.entity)

        if not TheWorld.ismastersim then
            inst:ListenForEvent("hideanimdirty", OnHideAnimDirty)
			inst:ListenForEvent("elementdirty", OnElementDirty)
        end
    end

    inst:SetPrefabNameOverride("winona_catapult") --for death announce

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

	inst.AOE_RADIUS = TUNING.WINONA_CATAPULT_AOE_RADIUS
	inst.AOE_LEVEL = 0
	inst.mega = false

    local complexprojectile = inst:AddComponent("complexprojectile")
    complexprojectile:SetGravity(-100)
    complexprojectile:SetLaunchOffset(Vector3(1.25, 3, 0))
    complexprojectile:SetHorizontalSpeedForDistance(TUNING.WINONA_CATAPULT_MAX_RANGE, 35)
    complexprojectile:SetOnHit(OnHit)

    inst:AddComponent("combat")
    inst.components.combat:SetDefaultDamage(TUNING.WINONA_CATAPULT_DAMAGE)
	inst.components.combat:SetRange(inst.AOE_RADIUS)
    inst.components.combat:SetKeepTargetFunction(KeepTargetFn)

	inst:AddComponent("planardamage")
	inst:AddComponent("damagetypebonus")

	inst.SetElementalRock = SetElementalRock
	inst.SetAoeRadius = SetAoeRadius

    inst.persists = false

    return inst
end

return Prefab("winona_catapult_projectile", fn, assets, prefabs)
