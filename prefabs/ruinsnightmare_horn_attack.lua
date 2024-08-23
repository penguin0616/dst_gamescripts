local assets =
{
    Asset("ANIM", "anim/shadow_insanity3_basic.zip"),
}

local prefabs =
{
    "ruinsnightmare_horn_attack_fx",
}

---------------------------------------------------------------------------------------------------------------------

local easing = require("easing")

local AOE_DAMAGE_TARGET_MUST_TAGS = { "_combat", "player" }
local AOE_DAMAGE_TARGET_CANT_TAGS = { "INLIMBO", "notarget", "noattack", "flight", "invisible", "playerghost" }

local AOE_DAMAGE_RADIUS = 1.5
local AOE_DAMAGE_RADIUS_PADDING = 3

local DAMAGE_OFFSET_DIST = .5
local COLLIDE_POINT_DIST = 3

local INITIAL_SPEED = 8
local FINAL_SPEED = 15
local FINAL_SPEED_TIME = .5

local INITIAL_DIST_FROM_TARGET = 10

local OWNER_REAPPEAR_TIME = 1

---------------------------------------------------------------------------------------------------------------------

local function OnUpdate(inst)
    local x, y, z = inst.Transform:GetWorldPosition()

    if inst.collision_x ~= nil then
        if distsq(x, z, inst.collision_x, inst.collision_z) < COLLIDE_POINT_DIST then
            inst:Remove()

            if inst.owner ~= nil then
                inst.owner:DoTaskInTime(OWNER_REAPPEAR_TIME, inst.owner.PushEvent, "reappear")
            end

            if inst.spawnfx then
                SpawnPrefab("ruinsnightmare_horn_attack_fx").Transform:SetPosition(inst.collision_x, 0, inst.collision_z)
            end

            return
        end
    end

    local speed = math.min(easing.inCubic(inst:GetTimeAlive(), INITIAL_SPEED, FINAL_SPEED-INITIAL_SPEED, FINAL_SPEED_TIME), FINAL_SPEED)

    inst.Physics:SetMotorVelOverride(speed, 0, 0)

    local combat = inst.owner ~= nil and inst.owner.components.combat or nil

    if combat == nil then
        return
    end

    combat.ignorehitrange = true

    if DAMAGE_OFFSET_DIST ~= 0 then
        local theta = inst.Transform:GetRotation() * DEGREES
        local cos_theta = math.cos(theta)
        local sin_theta = math.sin(theta)

        x = x + DAMAGE_OFFSET_DIST * cos_theta
        z = z - DAMAGE_OFFSET_DIST * sin_theta
    end

    for i, v in ipairs(TheSim:FindEntities(x, y, z, AOE_DAMAGE_RADIUS + AOE_DAMAGE_RADIUS_PADDING, AOE_DAMAGE_TARGET_MUST_TAGS, AOE_DAMAGE_TARGET_CANT_TAGS)) do
        if v ~= inst and
            not inst.targets[v] and
            v:IsValid() and not v:IsInLimbo() and
            not (v.components.health ~= nil and v.components.health:IsDead())
        then
            local range = AOE_DAMAGE_RADIUS + v:GetPhysicsRadius(0)
            local x1, y1, z1 = v.Transform:GetWorldPosition()
            local dx = x1 - x
            local dz = z1 - z

            if (dx * dx + dz * dz) < (range * range) and combat:CanTarget(v) then
                combat:DoAttack(v) -- TODO(DiogoW): Different damage?

                inst.targets[v] = true
            end
        end
    end

    combat.ignorehitrange = false
end

---------------------------------------------------------------------------------------------------------------------

local function SetUp(inst, owner, target, other)
    local x, y, z = target.Transform:GetWorldPosition()

    local theta = other == nil and TWOPI * math.random() or other.Transform:GetRotation() * DEGREES

    inst.Transform:SetPosition(x + INITIAL_DIST_FROM_TARGET * math.cos(theta), 0, z - INITIAL_DIST_FROM_TARGET * math.sin(theta))

    inst:FacePoint(x, 0, z)

    inst.collision_x = x
    inst.collision_z = z

    inst.owner = owner
    inst.spawnfx = other == nil

    inst.components.updatelooper:AddOnUpdateFn(inst._OnUpdateFn)
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddPhysics()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst.Transform:SetEightFaced()

    MakeCharacterPhysics(inst, 10, 1.5)
    RemovePhysicsColliders(inst)

    inst.Physics:SetMotorVelOverride(INITIAL_SPEED, 0, 0)

    inst.AnimState:SetBank("shadowcreature3")
    inst.AnimState:SetBuild("shadow_insanity3_basic")
    inst.AnimState:PlayAnimation("horn_atk_pre")
    inst.AnimState:PushAnimation("horn_atk")

    inst.AnimState:SetMultColour(1, 1, 1, 0.5)
    inst.AnimState:UsePointFiltering(true)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.targets = {}

    inst.SetUp = SetUp
    inst._OnUpdateFn = OnUpdate

    inst:AddComponent("updatelooper")

    inst.persists = false

    return inst
end

return Prefab("ruinsnightmare_horn_attack", fn, assets, prefabs)