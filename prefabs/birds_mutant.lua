require "prefabutil"

local assets_robin =
{
    Asset("ANIM", "anim/mutated_robin.zip"),    
}

local assets_crow =
{
    Asset("ANIM", "anim/mutated_crow.zip"),   
}

local prefabs =
{
	"bilesplat",
}

local brain = require "brains/bird_mutant_brain"
local easing = require("easing")

----------------------------------------------------------

local function LaunchProjectile(inst, targetpos)
    local x, y, z = inst.Transform:GetWorldPosition()

    local projectile = SpawnPrefab("bilesplat")
    projectile.Transform:SetPosition(x, y, z)

    --V2C: scale the launch speed based on distance
    --     because 15 does not reach our max range.
    local dx = targetpos.x - x
    local dz = targetpos.z - z
    local rangesq = dx * dx + dz * dz
    local maxrange = TUNING.FIRE_DETECTOR_RANGE
    --local speed = easing.linear(rangesq, 15, 3, maxrange * maxrange)
    local speed = easing.linear(rangesq, 15, 1, maxrange * maxrange)
    projectile.components.complexprojectile:SetHorizontalSpeed(speed)
    projectile.components.complexprojectile:SetGravity(-35)
    projectile.components.complexprojectile:Launch(targetpos, inst, inst)
end

local function IsNearInvadeTarget(inst, dist)
    local target = inst.components.entitytracker:GetEntity("swarmTarget")
    return target == nil or inst:IsNear(target, dist)
end

local RETARGET_MUST_TAGS = { "_combat" }
local INVADER_RETARGET_CANT_TAGS = { "playerghost", "INLIMBO"}
local function Retarget(inst)
    return IsNearInvadeTarget(inst, TUNING.MUTANT_BIRD_AGGRO_DIST)
    --[[
        and FindEntity(
                inst,
                TUNING.MUTANT_BIRD_TARGET_DIST,
                function(guy)
                    local can = inst.components.combat:CanTarget(guy)
                    if guy:HasTag("player") or (guy.components.follower and guy.components.follower:GetLeader() and guy.components.follower:GetLeader():HasTag("player")) then                       
                        return can
                    end
                end,
                RETARGET_MUST_TAGS,
                INVADER_RETARGET_CANT_TAGS
            )
            ]]

        and FindEntity(
                inst,
                TUNING.MUTANT_BIRD_TARGET_DIST,
                function(guy)
                    local can = inst.components.combat:CanTarget(guy)
                    if guy == inst.components.entitytracker:GetEntity("swarmTarget") then
                        return can
                    end
                    if guy:HasTag("player") or (guy.components.follower and guy.components.follower:GetLeader() and guy.components.follower:GetLeader():HasTag("player")) then                       
                        return can
                    end                    
                end,
                RETARGET_MUST_TAGS,
                INVADER_RETARGET_CANT_TAGS
            )

        or nil
end

local function KeepTargetFn(inst, target)
    return IsNearInvadeTarget(inst, TUNING.MUTANT_BIRD_RETURN_DIST)
        and inst.components.combat:CanTarget(target)
end

----------------------------------------------------------

local function OnNewCombatTarget(inst, data)
	if inst.components.inspectable == nil then
		inst:AddComponent("inspectable")
		inst:AddTag("scarytoprey")
	end
end

local function OnNoCombatTarget(inst)
	inst.components.combat:RestartCooldown()
	inst:RemoveComponent("inspectable")
	inst:RemoveTag("scarytoprey")
end

local function commonPreMain(inst)
   
    --Core components
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()
    inst.entity:AddPhysics()   
    inst.entity:AddDynamicShadow()     

    inst.sounds =
    {
        flyin = "dontstarve/birds/flyin",
    }

    --Initialize physics
    inst.Physics:SetCollisionGroup(COLLISION.CHARACTERS)
    inst.Physics:ClearCollisionMask()
    inst.Physics:CollidesWith(COLLISION.WORLD)
    inst.Physics:SetMass(1)
    inst.Physics:SetSphere(1)

	inst:AddTag("bird_mutant")
	inst:AddTag("NOBLOCK")
	inst:AddTag("soulless") -- no wortox souls
	inst:AddTag("hostile")
    inst:AddTag("monster")
    inst:AddTag("scarytoprey")

    inst.Transform:SetFourFaced()    

    inst.AnimState:SetBuild("crow_build")
    inst.AnimState:SetBank("crow")
    inst.AnimState:PlayAnimation("idle", true)

    inst.DynamicShadow:SetSize(1, .75)
    inst.DynamicShadow:Enable(false)

	return inst
end


local function commonPostMain(inst)

    inst:AddComponent("sanityaura")
	inst.components.sanityaura.aura = TUNING.SANITYAURA_MED

    inst:AddComponent("locomotor") -- locomotor must be constructed before the stategraph
    inst.components.locomotor.walkspeed = TUNING.MUTANT_BIRD_WALK_SPEED
    inst.components.locomotor.runspeed = TUNING.MUTANT_BIRD_WALK_SPEED
    inst.components.locomotor:EnableGroundSpeedMultiplier(false)
    inst.components.locomotor:SetTriggersCreep(false)

	inst:AddComponent("health")
    inst.components.health:SetMaxHealth(TUNING.MUTANT_BIRD_HEALTH)

    inst:AddComponent("entitytracker")

    inst:AddComponent("timer")

	inst:AddComponent("combat")
	inst.components.combat:SetDefaultDamage(TUNING.MUTANT_BIRD_DAMAGE)
	inst.components.combat:SetAttackPeriod(TUNING.MUTANT_BIRD_ATTACK_COOLDOWN)
	inst.components.combat:SetRange(TUNING.MUTANT_BIRD_ATTACK_RANGE)
    inst.components.combat:SetRetargetFunction(1, Retarget)
	inst:ListenForEvent("newcombattarget", OnNewCombatTarget)
	inst:ListenForEvent("droppedtarget", OnNoCombatTarget)
	inst:ListenForEvent("losttarget", OnNoCombatTarget)
	
	inst:AddComponent("knownlocations")

    inst:SetStateGraph("SGbird_mutant")
    inst:SetBrain(brain)

    return inst
end

local function runnerfn()
	local inst = CreateEntity()

	inst = commonPreMain(inst)

    inst.AnimState:SetBuild("mutated_crow")
    inst.AnimState:SetBank("mutated_crow")
    inst.AnimState:PlayAnimation("idle", true)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst = commonPostMain(inst)

	return inst
end

local function spitterfn()
	local inst = CreateEntity()
	inst = commonPreMain(inst)
    inst.AnimState:SetBuild("mutated_robin")
    inst.AnimState:SetBank("mutated_robin")

	inst:AddTag("bird_mutant_spitter")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end
	
	inst = commonPostMain(inst)
	inst.LaunchProjectile = LaunchProjectile
	
	return inst
end

return Prefab("bird_mutant", runnerfn, assets_crow, prefabs),
       Prefab("bird_mutant_spitter", spitterfn, assets_robin, prefabs)
