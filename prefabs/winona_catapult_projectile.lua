local assets =
{
    Asset("ANIM", "anim/winona_catapult_projectile.zip"),
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

local function OnHit(inst, attacker, target)
    local x, y, z = inst.Transform:GetWorldPosition()
    inst.Physics:Stop()
    inst.Physics:Teleport(x, 0, z)

	local element = ELEMENTS[inst.element:value()]
	if inst.mega then
		inst.AnimState:PlayAnimation("impact"..(inst.AOE_LEVEL ~= 0 and tostring(inst.AOE_LEVEL) or "").."_special")
	else
		inst.AnimState:PlayAnimation("impact"..(inst.AOE_LEVEL ~= 0 and tostring(inst.AOE_LEVEL) or "")..(element and ("_"..element) or ""))
	end
    inst:ListenForEvent("animover", inst.Remove)

    inst.hideanim:set(true)
    if inst.animent ~= nil then
        inst.animent:Remove()
        inst.animent = nil
    end

    if attacker ~= nil and attacker.components.combat ~= nil and attacker:IsValid() then
        attacker.components.combat.ignorehitrange = true
		ConfigureElementalDamage(inst, attacker, element)
    else
        attacker = nil
    end
	inst.components.combat.ignorehitrange = true
	ConfigureElementalDamage(inst, inst, element)

    local hit = false
	for i, v in ipairs(TheSim:FindEntities(x, y, z, inst.AOE_RADIUS + AOE_RANGE_PADDING, COMBAT_TAGS, TheNet:GetPVPEnabled() and NO_TAGS_PVP or NO_TAGS)) do
		if v:IsValid() and
			v.entity:IsVisible() and
			v:GetDistanceSqToPoint(x, y, z) < inst.components.combat:CalcHitRangeSq(v) and
			inst.components.combat:CanTarget(v)
		then
            if attacker ~= nil and not (v.components.combat.target ~= nil and v.components.combat.target:HasTag("player")) then
                --if target is not targeting a player, then use the catapult as attacker to draw aggro
                attacker.components.combat:DoAttack(v)
            else
                inst.components.combat:DoAttack(v)
            end
            hit = true
        end
    end

    if attacker ~= nil then
        attacker.components.combat.ignorehitrange = false
		ResetDamage(inst, attacker)
    end
	inst.components.combat.ignorehitrange = false
	--ResetDamage(inst, inst) -- don't need, we're gonna be deleted

    inst.SoundEmitter:PlaySound("dontstarve/common/together/catapult/rock_hit", nil, hit and .5 or nil)
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
    inst.Physics:SetRestitution(.5)
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

return Prefab("winona_catapult_projectile", fn, assets)
