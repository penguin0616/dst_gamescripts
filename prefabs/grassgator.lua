local brain = require "brains/grassgatorbrain"

local assets =
{
    Asset("ANIM", "anim/grass_gator.zip"),
    Asset("ANIM", "anim/grass_gator_basic.zip"),
    Asset("ANIM", "anim/grass_gator_basic_water.zip"),
    Asset("ANIM", "anim/grass_gator_actions.zip"),
    Asset("ANIM", "anim/grass_gator_actions_water.zip"),
}

local prefabs =
{
    "cutgrass",
    "plantmeat",
    "twigs",
}

local grass_gator = {"plantmeat","plantmeat","plantmeat","plantmeat","plantmeat","plantmeat","plantmeat","cutgrass","twigs","cutgrass","twigs"}
--V2C: "trunk" is a dummy loot prefab that should be converted to "trunk_cooked"

local WAKE_TO_RUN_DISTANCE = 10
local SLEEP_NEAR_ENEMY_DISTANCE = 14

local function ShouldWakeUp(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    return DefaultWakeTest(inst) or IsAnyPlayerInRange(x, y, z, WAKE_TO_RUN_DISTANCE)
end

local function ShouldSleep(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    return DefaultSleepTest(inst) and not IsAnyPlayerInRange(x, y, z, SLEEP_NEAR_ENEMY_DISTANCE)
end

local function KeepTarget(inst, target)
    return inst:IsNear(target, TUNING.KOALEFANT_CHASE_DIST)
end

local function ShareTargetFn(dude)
    return dude:HasTag("koalefant") and not dude:HasTag("player") and not dude.components.health:IsDead()
end

local function OnAttacked(inst, data)
    inst.components.combat:SetTarget(data.attacker)
    inst.components.combat:ShareTarget(data.attacker, 30, ShareTargetFn, 5)
end

local function lootsetfn(lootdropper)
    if lootdropper.inst.components.burnable ~= nil and lootdropper.inst.components.burnable:IsBurning() or lootdropper.inst:HasTag("burnt") then
        lootdropper:SetLoot(loot_fire)
    end
end

local function OnTimerDone(inst, data)
    if data and data.name == "shed" then
        inst.shed_ready = true
    end
end

local function OnSave(inst, data)
    if inst.shed_ready then
        data.shed_ready = inst.shed_ready
    end

    if inst.components.timer:TimerExists("shed") then
        data.shed_timer = inst.components.timer:GetTimeLeft("shed")
    end

end

local function OnLoad(inst, data)
    if data ~= nil then
        if data.shed_ready ~= nil then
            inst.shed_ready = data.shed_ready           
        elseif data.shed_timer ~= nil then
            if inst.components.timer:TimerExists("shed") then
                inst.components.timer:SetTimeLeft("shed",data.shed_timer)
            else                
                inst.components.timer:StartTimer("shed", data.shed_timer)
            end
        end
    end
end

local function isovershallowwater(inst)
    local tile = TheWorld.Map:GetTileAtPoint(inst.Transform:GetWorldPosition())
    if tile then
        local tile_info = GetTileInfo(tile)
        if tile_info ~= nil and tile_info.ocean_depth ~= nil then                   
            if tile_info.ocean_depth == "SHALLOW" then
                return true
            end
        end
    end
end

local function checkforshallowwater(inst)    

    local x,y,z = inst.Transform:GetWorldPosition()
    if TheWorld.Map:IsVisualGroundAtPoint(x,y,z) then
        return
    end

    if inst:IsValid() and not inst.components.sleeper:IsAsleep() and (not inst.sg or not inst.sg:HasStateTag("diving")) then
        if not isovershallowwater(inst) then        
            --inst.movetoshallow = true       
            inst:PushEvent("diveandrelocate")
        end         
    end
end

local function findnewshallowlocation(inst, range)
    if not range then 
        range = 25 + (math.random()*5)
    end
    inst.surfacelocation = nil
    local range = 25 + (math.random()*5)
    local pos = Vector3(inst.Transform:GetWorldPosition())
    local angle = (inst.Transform:GetRotation()-180) * DEGREES 
    local finaloffset = FindValidPositionByFan(angle, range or 8, 8, function(offset)
        local x, z = pos.x + offset.x, pos.z + offset.z

        local tile = TheWorld.Map:GetTileAtPoint(inst.Transform:GetWorldPosition())
        if tile then
            local tile_info = GetTileInfo(tile)
            if tile_info ~= nil and tile_info.ocean_depth ~= nil then
                if tile_info.ocean_depth <= "SHALLOW" then                    
                    return true
                end
            end            
        end        
    end)
    if finaloffset then
        return pos+finaloffset
    end
end

local function create_base(build)
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddDynamicShadow()
    inst.entity:AddNetwork()

    MakeCharacterPhysics(inst, 100, .75)

    inst.DynamicShadow:SetSize(4.5, 2)
    inst.Transform:SetSixFaced()

    inst:AddTag("grassgator")
    inst:AddTag("animal")
    inst:AddTag("largecreature")

    --saltlicker (from saltlicker component) added to pristine state for optimization
    inst:AddTag("saltlicker")

    inst.AnimState:SetBank("grass_gator")
    inst.AnimState:SetBuild("grass_gator")
    inst.AnimState:PlayAnimation("idle_loop", true)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("eater")
    inst.components.eater:SetDiet({ FOODTYPE.VEGGIE }, { FOODTYPE.VEGGIE })

    inst:AddComponent("combat")
    inst.components.combat.hiteffectsymbol = "grass_gator_body"
    inst.components.combat:SetDefaultDamage(TUNING.GRASSGATOR_DAMAGE)
    inst.components.combat:SetKeepTargetFunction(KeepTarget)
    inst:ListenForEvent("attacked", OnAttacked)

    inst:AddComponent("health")
    inst.components.health:SetMaxHealth(TUNING.GRASSGATOR_HEALTH)

    inst:AddComponent("lootdropper")
    inst.components.lootdropper:SetLootSetupFn(lootsetfn)
    inst.components.lootdropper:SetLoot(grass_gator)

    inst:AddComponent("inspectable")

    inst:AddComponent("knownlocations")
--[[
    inst:AddComponent("periodicspawner")
    inst.components.periodicspawner:SetPrefab("poop")
    inst.components.periodicspawner:SetRandomTimes(40, 60)
    inst.components.periodicspawner:SetDensityInRange(20, 2)
    inst.components.periodicspawner:SetMinimumSpacing(8)
    inst.components.periodicspawner:Start()
]]
    inst:AddComponent("timer")
    inst:ListenForEvent("timerdone", OnTimerDone)

    inst.components.timer:StartTimer("shed", TUNING.GRASSGATOR_SHEDTIME_SET + (math.random()* TUNING.GRASSGATOR_SHEDTIME_VAR))

    inst:AddComponent("saltlicker")
    inst.components.saltlicker:SetUp(TUNING.SALTLICK_GRASSGATOR_USES)

    MakeLargeBurnableCharacter(inst, "grass_gator_body")
    MakeLargeFreezableCharacter(inst, "grass_gator_body")

    MakeHauntablePanic(inst)

    inst:AddComponent("locomotor") -- locomotor must be constructed before the stategraph
    inst.components.locomotor.walkspeed = TUNING.GRASSGATOR_WALKSPEED
    inst.components.locomotor.runspeed = TUNING.GRASSGATOR_RUNSPEED
    inst.components.locomotor:CanPathfindOnWater()


    inst:AddComponent("sleeper")
    inst.components.sleeper:SetResistance(3)
    inst.components.sleeper:SetSleepTest(ShouldSleep)
    inst.components.sleeper:SetWakeTest(ShouldWakeUp)

    inst:SetBrain(brain)
    inst:SetStateGraph("SGgrassgator")

    inst:AddComponent("embarker")
    inst.components.embarker.embark_speed = inst.components.locomotor.runspeed

    inst.components.locomotor:SetAllowPlatformHopping(true)


    inst:AddComponent("amphibiouscreature")
    inst.components.amphibiouscreature:SetBanks("grass_gator", "grass_gator_water")
    inst.components.amphibiouscreature:SetEnterWaterFn(
            function(inst)
                inst.landspeed = inst.components.locomotor.runspeed
                inst.components.locomotor.runspeed = TUNING.GRASSGATOR_RUNSPEED_WATER
                inst.hop_distance = inst.components.locomotor.hop_distance
                inst.components.locomotor.hop_distance = 4
            end)
    inst.components.amphibiouscreature:SetExitWaterFn(
            function(inst)
                if inst.landspeed then
                    inst.components.locomotor.runspeed = TUNING.GRASSGATOR_RUNSPEED
                end
                if inst.hop_distance then
                    inst.components.locomotor.hop_distance = inst.hop_distance
                end
            end)

    inst.components.locomotor.pathcaps = { allowocean = true }

    inst:DoPeriodicTask(2,checkforshallowwater)
    inst.findnewshallowlocation = findnewshallowlocation
    inst.isovershallowwater = isovershallowwater

    inst.OnSave = OnSave
    inst.OnLoad = OnLoad

    return inst
end

return Prefab("grassgator", create_base, assets, prefabs)
