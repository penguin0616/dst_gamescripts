local assets =
{
    Asset("ANIM", "anim/alterguardian_phase3.zip"),
    Asset("ANIM", "anim/alterguardian_spawn_death.zip"),
}

local prefabs =
{
    "alterguardian_laser",
    "alterguardian_laserempty",
    "alterguardian_phase3circle",
    "alterguardian_phase3deadorb",
    "alterguardian_phase3trapprojectile",
    "alterguardian_summon_fx",
    "chesspiece_guardianphase3_sketch",
    "largeguard_alterguardian_projectile",
    "moonglass",
    "moonglass_charged",
    "moonrocknugget",
}

-- For a spray of moon glass and rocks when the boss dies
SetSharedLootTable("alterguardian_phase3",
{
    {"chesspiece_guardianphase3_sketch", 1.00},
    {"moonglass",           1.00},
    {"moonglass",           1.00},
    {"moonglass",           1.00},
    {"moonglass",           1.00},
    {"moonglass",           1.00},
    {"moonglass",           1.00},
    {"moonglass",           1.00},
    {"moonglass",           1.00},
    {"moonglass",           1.00},
    {"moonglass",           0.66},
    {"moonglass",           0.66},
    {"moonglass",           0.66},
    {"moonglass",           0.66},
    {"moonglass",           0.66},
    {"moonglass",           0.33},
    {"moonglass",           0.33},
    {"moonglass",           0.33},
    {"moonglass",           0.33},
    {"moonglass",           0.33},
    {"moonglass_charged",   1.00},
    {"moonglass_charged",   1.00},
    {"moonglass_charged",   1.00},
    {"moonglass_charged",   1.00},
    {"moonglass_charged",   1.00},
    {"moonglass_charged",   1.00},
    {"moonglass_charged",   0.66},
    {"moonglass_charged",   0.66},
    {"moonglass_charged",   0.66},
    {"moonglass_charged",   0.33},
    {"moonglass_charged",   0.33},
    {"moonglass_charged",   0.33},
    {"moonrocknugget",      1.00},
    {"moonrocknugget",      1.00},
    {"moonrocknugget",      1.00},
    {"moonrocknugget",      1.00},
    {"moonrocknugget",      0.66},
    {"moonrocknugget",      0.66},
})

local brain = require "brains/alterguardian_phase3brain"

local TARGET_DSQ = (1.9*TUNING.ALTERGUARDIAN_PHASE3_TARGET_DIST)^2
local RETARGET_MUST_TAGS = { "_combat" }
local RETARGET_CANT_TAGS = { "INLIMBO", "playerghost" }
local RETARGET_ONEOF_TAGS = { "character", "monster" }
local function Retarget(inst)
    local spawnpoint_position = inst.components.knownlocations:GetLocation("spawnpoint")

    if spawnpoint_position ~= nil and
            inst:GetDistanceSqToPoint(spawnpoint_position:Get()) >= TARGET_DSQ then
        return nil
    else
        return FindEntity(
            inst,
            TUNING.ALTERGUARDIAN_PHASE3_TARGET_DIST,
            function(guy)
                return inst.components.combat:CanTarget(guy)
            end,
            RETARGET_MUST_TAGS,
            RETARGET_CANT_TAGS,
            RETARGET_ONEOF_TAGS
        )
    end
end

-- Phase 3 doesn't really chase people, so having a max target range just outside of its max attack range should work.
local MAX_KEEPTARGET_DSQ = 1.15 * TUNING.ALTERGUARDIAN_PHASE3_ATTACK_RANGE
local function KeepTarget(inst, target)
    return inst.components.combat:CanTarget(target)
        and target:GetDistanceSqToPoint(inst.Transform:GetWorldPosition()) < MAX_KEEPTARGET_DSQ
end

local function NoHoles(pt)
    return not TheWorld.Map:IsPointNearHole(pt)
end

local function SpawnTrapProjectile(inst, target_positions)
    local target_position = table.remove(target_positions)

    local projectile = SpawnPrefab("alterguardian_phase3trapprojectile")
    projectile.Transform:SetPosition(target_position:Get())
    projectile:SetGuardian(inst)

    if #target_positions > 0 then
        -- Spawn the projectiles, in a tail-recursive-style way.
        inst:DoTaskInTime(0.5, SpawnTrapProjectile, target_positions)
    else
        inst:PushEvent("endtraps")
    end
end

local TRAP_PLAYERCOUNT_DSQ = TUNING.ALTERGUARDIAN_PHASE3_TARGET_DIST^2
local function do_traps(inst)
    local position = inst:GetPosition()
    local px, py, pz = position:Get()

    -- Add extra traps based on the number of nearby players.
    local num_traps = 3
    for _, v in ipairs(AllPlayers) do
        if not v:HasTag("playerghost") and v.entity:IsVisible()
                and v:GetDistanceSqToPoint(px, py, pz) < TRAP_PLAYERCOUNT_DSQ then
            num_traps = num_traps + 2
        end
    end

    -- Space out the traps mostly evenly, but a little randomly (leaves a little pocket of sorts sometimes)
    local delta = (1.5 + math.random() * 0.5) * PI / num_traps
    local initial_offset = PI2 * math.random()

    local angles = {}
    for i = 1, num_traps do
        table.insert(angles, i*delta + initial_offset)
    end
    shuffleArray(angles)

    local target_positions = {}
    for i = 1, #angles do
        local range = TUNING.ALTERGUARDIAN_PHASE3_TRAP_MINRANGE + math.sqrt(math.random()) * TUNING.ALTERGUARDIAN_PHASE3_TRAP_MAXRANGE
        local offset = FindWalkableOffset(position, angles[i], range, 12, true, true, NoHoles)
        if offset ~= nil then
            -- Turn the offset into a world position.
            offset.x = offset.x + position.x
            offset.y = 0
            offset.z = offset.z + position.z
            table.insert(target_positions, offset)
        end
    end

    if #target_positions > 0 then
        -- Spawn the projectiles, in a tail-recursive-style way.
        inst:DoTaskInTime(0.5, SpawnTrapProjectile, target_positions)
    else
        inst:PushEvent("endtraps")
    end
end

local function track_trap(inst, trap)
    local function ontrapremoved()
        inst._traps[trap] = nil
    end
    inst._traps[trap] = true
    inst:ListenForEvent("onremove", ontrapremoved, trap)
end

local function CalcSanityAura(inst, observer)
    return (inst.components.combat.target ~= nil and TUNING.SANITYAURA_HUGE) or TUNING.SANITYAURA_LARGE
end

local function OnSave(inst, data)
    data.loot_dropped = inst._loot_dropped

    data.traps = {}
    local ents = {}
    if GetTableSize(inst._traps) > 0 then
        for trap, v in pairs(inst._traps) do
            if v and trap and trap:IsValid() then
                table.insert(data.traps, trap.GUID)
                table.insert(ents, trap.GUID)
            end
        end
    end

    return ents
end

local function OnLoad(inst, data)
    if data ~= nil then
        inst._loot_dropped = data.loot_dropped
    end
end

local function OnLoadPostPass(inst, newents, data)
    if data ~= nil and data.traps ~= nil and #data.traps > 0 then
        for _, trapID in ipairs(data.traps) do
            inst:TrackTrap(newents[trapID].entity)
        end
    end
end

local function OnEntitySleep(inst)
    if inst.components.health:IsDead() then
        return
    end

    -- If we haven't reached our max health yet OR we're hurt, set a time
    -- so that, when we wake up, we can regain health.
    if inst.components.health.maxhealth < TUNING.ALTERGUARDIAN_PHASE3_MAXHEALTH
            or inst.components.health:IsHurt() then
        inst._start_sleep_time = GetTime()
    end
end

local HEALTH_GAIN_RATE = (TUNING.ALTERGUARDIAN_PHASE3_MAXHEALTH - TUNING.ALTERGUARDIAN_PHASE3_STARTHEALTH) / (TUNING.TOTAL_DAY_TIME * 2)
local function gain_sleep_health(inst)
    local gain = HEALTH_GAIN_RATE * (GetTime() - inst._start_sleep_time)
    local hp_plus_gain = inst.components.health.currenthealth + gain

    -- If our gain would be enough to break our current max health,
    -- assign a new max health, up to our tuned real maximum health.
    if hp_plus_gain > inst.components.health.maxhealth then
        local new_max = math.min(hp_plus_gain, TUNING.ALTERGUARDIAN_PHASE3_MAXHEALTH)
        inst.components.health:SetMaxHealth(new_max)
    else
        inst.components.health:DoDelta(gain)
    end
end

local function OnEntityWake(inst)
    -- If a sleep time was set, gain health as appropriate.
    if inst._start_sleep_time ~= nil then
        gain_sleep_health(inst)

        inst._start_sleep_time = nil
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddDynamicShadow()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

    inst.Transform:SetSixFaced()

    inst.DynamicShadow:SetSize(3.0, 1.0)

    inst.Light:SetIntensity(0)
    inst.Light:SetRadius(0)
    inst.Light:SetFalloff(0)
    inst.Light:SetColour(0.01, 0.35, 1)

    inst.AnimState:SetBank("alterguardian_phase3")
    inst.AnimState:SetBuild("alterguardian_phase3")
    inst.AnimState:PlayAnimation("idle")

    MakeTinyFlyingCharacterPhysics(inst, 500, 0)

    inst:AddTag("epic")
    inst:AddTag("hostile")
    inst:AddTag("largecreature")
    inst:AddTag("mech")
    inst:AddTag("monster")
    inst:AddTag("scarytoprey")
    inst:AddTag("soulless")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("locomotor")
    inst.components.locomotor.walkspeed = TUNING.ALTERGUARDIAN_PHASE3_WALK_SPEED

    inst:SetStateGraph("SGalterguardian_phase3")
    inst:SetBrain(brain)

    inst:AddComponent("health")
    inst.components.health:SetMaxHealth(TUNING.ALTERGUARDIAN_PHASE3_STARTHEALTH)
    inst.components.health.nofadeout = true
    inst.components.health.save_maxhealth = true

    inst:AddComponent("combat")
    inst.components.combat:SetDefaultDamage(TUNING.ALTERGUARDIAN_PHASE3_DAMAGE)
    inst.components.combat:SetAttackPeriod(TUNING.ALTERGUARDIAN_PHASE3_ATTACK_PERIOD)
    inst.components.combat:SetRetargetFunction(2, Retarget)
    inst.components.combat:SetKeepTargetFunction(KeepTarget)
    inst.components.combat:SetRange(TUNING.ALTERGUARDIAN_PHASE3_ATTACK_RANGE, TUNING.ALTERGUARDIAN_PHASE3_STAB_HITRANGE)
    inst.components.combat:SetAreaDamage(3, 0.8)
    inst.components.combat.playerdamagepercent = TUNING.ALTERGUARDIAN_PLAYERDAMAGEPERCENT
    inst.components.combat.noimpactsound = true
    inst.components.combat:SetHurtSound("moonstorm/creatures/boss/alterguardian1/onothercollide")

    inst:AddComponent("sanityaura")
    inst.components.sanityaura.aurafn = CalcSanityAura
    inst.components.sanityaura.max_distsq = 225

    inst:AddComponent("lootdropper")
    inst.components.lootdropper:SetChanceLootTable("alterguardian_phase3")
    inst.components.lootdropper.min_speed = 4.0
    inst.components.lootdropper.max_speed = 6.0
    inst.components.lootdropper.y_speed = 14
    inst.components.lootdropper.y_speed_variance = 2

    inst:AddComponent("inspectable")

    inst:AddComponent("knownlocations")

    inst:AddComponent("timer")
    --inst.components.timer:StartTimer("runaway_blocker", n/a)
    --inst.components.timer:StartTimer("traps_cd", n/a)
    inst.components.timer:StartTimer("summon_cd", math.floor(TUNING.ALTERGUARDIAN_PHASE3_SUMMONCOOLDOWN / 2))

    MakeLargeBurnableCharacter(inst, "p3_fx_ball_centre")
    inst.components.burnable:SetBurnTime(5)

    MakeHugeFreezableCharacter(inst)
    inst.components.freezable:SetResistance(8)

    MakeHauntableGoToState(inst, "atk_stab", TUNING.HAUNT_CHANCE_OCCASIONAL, TUNING.ALTERGUARDIAN_PHASE3_ATTACK_PERIOD, TUNING.HAUNT_SMALL)

    inst.DoTraps = do_traps
    inst.TrackTrap = track_trap
    inst._traps = {}

    inst.OnSave = OnSave
    inst.OnLoad = OnLoad
    inst.OnLoadPostPass = OnLoadPostPass
    inst.OnEntitySleep = OnEntitySleep
    inst.OnEntityWake = OnEntityWake

    return inst
end

return Prefab("alterguardian_phase3", fn, assets, prefabs)
