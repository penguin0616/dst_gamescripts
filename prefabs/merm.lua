local assets =
{
    Asset("ANIM", "anim/merm_build.zip"),
    Asset("ANIM", "anim/merm_guard_build.zip"),
    Asset("ANIM", "anim/merm_guard_small_build.zip"),
    Asset("ANIM", "anim/merm_actions.zip"),
    Asset("ANIM", "anim/merm_actions_skills.zip"),
    Asset("ANIM", "anim/merm_guard_transformation.zip"),
    Asset("ANIM", "anim/ds_pig_boat_jump.zip"),
    Asset("ANIM", "anim/pigman_yotb.zip"),
    Asset("ANIM", "anim/ds_pig_basic.zip"),
    Asset("ANIM", "anim/ds_pig_actions.zip"),
    Asset("ANIM", "anim/ds_pig_attacks.zip"),
    Asset("ANIM", "anim/ds_pig_elite.zip"),

    Asset("ANIM", "anim/merm_lunar_eye_build.zip"),

    Asset("ANIM", "anim/merm_lunar_build.zip"),
    Asset("ANIM", "anim/merm_guard_lunar_build.zip"),
    Asset("ANIM", "anim/merm_guard_small_lunar_build.zip"),

    Asset("ANIM", "anim/merm_actions_skills.zip"),

    Asset("SOUND", "sound/merm.fsb"),
}

local assetsfx =
{
    Asset("ANIM", "anim/bramblefx.zip"),
}

local prefabs =
{
    "pondfish",
    "froglegs",
    "mermking",
    "merm_splash",
    "merm_spawn_fx",
    "merm_shadow",

    "mermking_buff_trident",
    "mermking_buff_crown",
    "mermking_buff_pauldron",

    "lunarmerm_thorns_fx",

    "shadow_merm_spawn_poof_fx",
    "shadow_merm_smacked_poof_fx",
}

local merm_loot =
{
    "pondfish",
    "froglegs",
}

local merm_guard_loot =
{
    "pondfish",
    "froglegs",
}

local merm_shadow_loot =
{
    "nightmarefuel",
}

SetSharedLootTable( 'merm_lunar_loot',
{
    {"froglegs",          1.00},
    {"pondfish",          1.00},
    {"tentaclespots",     0.25},
})

local sounds = {
    attack = "dontstarve/creatures/merm/attack",
    hit = "dontstarve/creatures/merm/hurt",
    death = "dontstarve/creatures/merm/death",
    talk = "dontstarve/characters/wurt/merm/warrior/talk",
    buff = "dontstarve/characters/wurt/merm/warrior/yell",
}

local sounds_guard = {
    attack = "dontstarve/characters/wurt/merm/warrior/attack",
    hit = "dontstarve/characters/wurt/merm/warrior/hit",
    death = "dontstarve/characters/wurt/merm/warrior/death",
    talk = "dontstarve/characters/wurt/merm/warrior/talk",
    buff = "dontstarve/characters/wurt/merm/warrior/yell",
}

local merm_brain = require "brains/mermbrain"
local merm_guard_brain = require "brains/mermguardbrain"

local SLIGHTDELAY = 1

local LOW_HEALTH_PERCENT = 0.2

local function MermDamageCalculator(inst)
    local hasking = TheWorld.components.mermkingmanager ~= nil and TheWorld.components.mermkingmanager:HasKingAnywhere()

    local damage = hasking and TUNING.MERM_DAMAGE_KINGBONUS or TUNING.MERM_DAMAGE

    if inst:HasTag("guard") then
        damage = hasking and TUNING.MERM_GUARD_DAMAGE or TUNING.PUNY_MERM_DAMAGE
    end

    if inst.components.planardamage ~= nil then
        damage = damage - inst.components.planardamage:GetBaseDamage()
    end

    return damage
end

local function FindInvaderFn(guy, inst)
    if guy:HasTag("NPC_contestant") then
        return nil
    end

    local leader = inst.components.follower and inst.components.follower.leader

    local leader_guy = guy.components.follower and guy.components.follower.leader
    if leader_guy and leader_guy.components.inventoryitem then
        leader_guy = leader_guy.components.inventoryitem:GetGrandOwner()
    end

    return (guy:HasTag("character") and not guy:HasTag("merm")) and
           not (TheWorld.components.mermkingmanager and TheWorld.components.mermkingmanager:HasKingAnywhere()) and
           not (leader and leader:HasTag("player")) and
           not (leader_guy and (leader_guy:HasTag("merm")) and
                not guy:HasTag("pig") and
                not guy:HasTag("wonkey"))
end

local function RetargetFn(inst)
    if inst:HasTag("NPC_contestant") then
        return nil
    end

    local defend_dist = (inst:HasTag("mermguard") and TUNING.MERM_GUARD_DEFEND_DIST) or TUNING.MERM_DEFEND_DIST
    defend_dist = (defend_dist * defend_dist)
    local home = inst.components.homeseeker and inst.components.homeseeker.home

    local defenseTarget = (home ~= nil and inst:GetDistanceSqToInst(home) < defend_dist and home)
        or inst

    return FindEntity(defenseTarget, SpringCombatMod(TUNING.MERM_TARGET_DIST), FindInvaderFn)
end

local function KeepTargetFn(inst, target)
    local defend_dist = (inst:HasTag("mermguard") and TUNING.MERM_GUARD_DEFEND_DIST) or TUNING.MERM_DEFEND_DIST
    defend_dist = (defend_dist * defend_dist)
    local home = inst.components.homeseeker and inst.components.homeseeker.home
    local follower = inst.components.follower and inst.components.follower.leader

    if home and not follower then
        return home:GetDistanceSqToInst(target) < defend_dist
               and home:GetDistanceSqToInst(inst) < defend_dist
    else
        return inst.components.combat:CanTarget(target)
    end
end

local DECIDROOTTARGET_MUST_TAGS = { "_combat", "_health", "merm" }
local DECIDROOTTARGET_CANT_TAGS = { "INLIMBO" }

local function OnAttackedByDecidRoot(inst, attacker)
    local isguard = inst:HasTag("mermguard")
    local share_target_dist = (isguard and TUNING.MERM_GUARD_SHARE_TARGET_DIST) or TUNING.MERM_SHARE_TARGET_DIST
    local max_target_shares = (isguard and TUNING.MERM_GUARD_MAX_TARGET_SHARES) or TUNING.MERM_MAX_TARGET_SHARES

    local x, y, z = inst.Transform:GetWorldPosition()
    local combat_helpers = TheSim:FindEntities(x, y, z, SpringCombatMod(share_target_dist) * .5, DECIDROOTTARGET_MUST_TAGS, DECIDROOTTARGET_CANT_TAGS)
    local num_helpers = 0

    for _, helper in ipairs(combat_helpers) do
        if helper ~= inst and not helper.components.health:IsDead() then
            helper:PushEvent("suggest_tree_target", { tree = attacker })
            num_helpers = num_helpers + 1
            if num_helpers >= max_target_shares then
                break
            end
        end
    end
end

local function IsNonPlayerMerm(this)
    return not this.isplayer and this:HasTag("merm")
end

local function resolve_on_attacked(inst, attacker)
    if attacker.prefab == "deciduous_root" and attacker.owner ~= nil then
        OnAttackedByDecidRoot(inst, attacker.owner)

    elseif attacker.prefab ~= "deciduous_root" and inst.components.combat:CanTarget(attacker) then
        local isguard = inst:HasTag("mermguard")

        local share_target_dist = (isguard and TUNING.MERM_GUARD_SHARE_TARGET_DIST) or TUNING.MERM_SHARE_TARGET_DIST
        local max_target_shares = (isguard and TUNING.MERM_GUARD_MAX_TARGET_SHARES) or TUNING.MERM_MAX_TARGET_SHARES

        inst.components.combat:SetTarget(attacker)
        if inst.components.combat:HasTarget() then
            local home = inst.components.homeseeker and inst.components.homeseeker.home
            if home and home.components.childspawner and inst:GetDistanceSqToInst(home) <= share_target_dist*share_target_dist then
                max_target_shares = max_target_shares - home.components.childspawner.childreninside
                home.components.childspawner:ReleaseAllChildren(attacker)
            end
        end
        inst.components.combat:ShareTarget(attacker, share_target_dist, IsNonPlayerMerm, max_target_shares)
    end
end

local function OnAttacked(inst, data)
    local attacker = data and data.attacker
    if attacker then
        resolve_on_attacked(inst, attacker)
    end
end

local function OnAttackDodged(inst, attacker)
    if attacker then
        resolve_on_attacked(inst, attacker)
    end
end

local MERM_TAGS = { "merm" }
local MERM_IGNORE_TAGS = { "FX", "NOCLICK", "DECOR", "INLIMBO", "player" }
local function MermSort(a, b) -- Better than bubble!
    local ap = a.components.follower:GetLoyaltyPercent()
    local bp = b.components.follower:GetLoyaltyPercent()
    if ap == bp then
        return a.GUID < b.GUID
    else
        return ap < bp
    end
end
local function GetOtherMerms(inst, radius, maxcount)
    local x, y, z = inst.Transform:GetWorldPosition()
    local merms = TheSim:FindEntities(x, y, z, radius, nil, MERM_IGNORE_TAGS, MERM_TAGS)
    local merms_highpriority = {}
    local merms_lowpriority = {}

    for _, merm in ipairs(merms) do
        if merm ~= inst and merm:IsValid() and not merm.components.health:IsDead() then
            local follower = merm.components.follower
            if follower then
                -- No leader or about to lose loyalty is high priority.
                if follower.leader == nil or follower:GetLoyaltyPercent() < TUNING.MERM_LOW_LOYALTY_WARNING_PERCENT then
                    table.insert(merms_highpriority, merm)
                else
                    table.insert(merms_lowpriority, merm)
                end
            end
        end
    end

    table.sort(merms_highpriority, MermSort)
    table.sort(merms_lowpriority, MermSort)

    local merms_valid = {}
    local merms_count = 0
    for _, merm in ipairs(merms_highpriority) do
        if merms_count >= maxcount then
            break
        end
        merms_count = merms_count + 1
        table.insert(merms_valid, merm)
    end
    if merms_count < maxcount then
        for _, merm in ipairs(merms_lowpriority) do
            if merms_count >= maxcount then
                break
            end
            merms_count = merms_count + 1
            table.insert(merms_valid, merm)
        end
    end

    return merms_valid
end

local function IsAbleToAccept(inst, item, giver)
    if inst.components.health ~= nil and inst.components.health:IsDead() then
        return false, "DEAD"
    elseif inst.sg ~= nil and inst.sg:HasStateTag("busy") then
        if inst.sg:HasStateTag("sleeping") then
            return true
        else
            return false, "BUSY"
        end
    else
        return true
    end
end

local function ShouldAcceptItem(inst, item, giver)
    if inst.king ~= nil and inst:HasTag("mermguard") then
        return false
    end

    if inst.components.sleeper and inst.components.sleeper:IsAsleep() then
        inst.components.sleeper:WakeUp()
    end

    -- Giving merm Moon Glass.
    if giver.components.skilltreeupdater ~= nil and
        giver.components.skilltreeupdater:IsActivated("wurt_lunar_allegiance_1") and
        inst.components.follower ~= nil and inst.components.follower:GetLeader() == giver and
        item:HasTag("moonglass_piece") and not inst:HasTag("lunarminion") and not inst:HasTag("shadowminion")
    then
        return true
    end

    return (giver:HasTag("merm") and not (inst:HasTag("mermguard") and giver:HasTag("mermdisguise"))) and
           ((item.components.equippable ~= nil and item.components.equippable.equipslot == EQUIPSLOTS.HEAD) or
           (item.components.edible and inst.components.eater and inst.components.eater:CanEat(item)) or
           (item:HasTag("fish") and not (TheWorld.components.mermkingmanager and TheWorld.components.mermkingmanager:IsCandidate(inst)))) 

end

local function DoCheer_Act(inst)
    inst:PushEvent("cheer")
end
local function DoCheer(inst)
    inst:DoTaskInTime(math.random()*SLIGHTDELAY, DoCheer_Act)
end

local function DoDisapproval_Act(inst)
    if inst.sg ~= nil and not inst.sg:HasStateTag("busy") then
        inst.sg:GoToState("disapproval")
    end
end
local function DoDisapproval(inst)
    inst:DoTaskInTime(math.random()*SLIGHTDELAY, DoDisapproval_Act)
end

local function OnGetItemFromPlayer(inst, giver, item)
    local mermkingmanager = TheWorld.components.mermkingmanager

    if item.components.edible ~= nil then
        -- It is better to feed guards than regulars to maintain loyalty!
        -- This will increase loyalty time and bonuses per hunger when feeding a guard.
        local isguard = inst:HasTag("mermguard")
        local loyalty_max = (isguard and TUNING.MERM_GUARD_LOYALTY_MAXTIME) or TUNING.MERM_LOYALTY_MAXTIME
        local loyalty_per_hunger = (isguard and TUNING.MERM_GUARD_LOYALTY_PER_HUNGER) or TUNING.MERM_LOYALTY_PER_HUNGER

        local loyalty_radius = (isguard and TUNING.MERM_GUARD_FOLLOWER_RADIUS) or TUNING.MERM_FOLLOWER_RADIUS
        local loyalty_count = (isguard and TUNING.MERM_GUARD_FOLLOWER_COUNT) or TUNING.MERM_FOLLOWER_COUNT

        -- King makes everything better! Keep it up!
        local hasking = (mermkingmanager and mermkingmanager:HasKingAnywhere()) or false
        if hasking then
            loyalty_max = loyalty_max + TUNING.MERM_LOYALTY_MAXTIME_KINGBONUS
            loyalty_per_hunger = loyalty_per_hunger + TUNING.MERM_LOYALTY_PER_HUNGER_KINGBONUS
        end

        local loyalty_time = item.components.edible:GetHunger() * loyalty_per_hunger

        local hiremoremerms = false
        if inst.components.combat:TargetIs(giver) then
            inst.components.combat:SetTarget(nil)
        elseif giver.components.leader ~= nil and inst.components.follower ~= nil and
                not (mermkingmanager and mermkingmanager:IsCandidate(inst)) then
            giver:PushEvent("makefriend")
            giver.components.leader:AddFollower(inst)

            inst.components.follower.maxfollowtime = loyalty_max
            inst.components.follower:AddLoyaltyTime(loyalty_time)

            if item:HasTag("fish") then
                DoCheer(inst)
            end

            hiremoremerms = true
        end

        if hiremoremerms then
            local othermerms = GetOtherMerms(inst, loyalty_radius, loyalty_count) -- Only other merms, capped by count, and prioritized by necessity.
            for _, othermerm in ipairs(othermerms) do
                local effectdone = true

                if othermerm.components.combat.target == giver then
                    othermerm.components.combat:SetTarget(nil)
                elseif giver.components.leader ~= nil and othermerm.components.follower ~= nil and
                        not (mermkingmanager and mermkingmanager:IsCandidate(inst)) then
                    -- "makefriend" event fires above no matter what do not play it again here.
                    giver.components.leader:AddFollower(othermerm)

                    -- Intentional use of cached variables here to make feeding guards better than regulars.
                    othermerm.components.follower.maxfollowtime = loyalty_max
                    othermerm.components.follower:AddLoyaltyTime(loyalty_time)
                else
                    effectdone = false
                end

                if effectdone then
                    if othermerm.components.sleeper and othermerm.components.sleeper:IsAsleep() then
                        othermerm.components.sleeper:WakeUp()
                    elseif othermerm.DoCheer then
                        othermerm:DoCheer()
                    end
                end
            end
        end
    end


    -- I also wear hats
    if item.components.equippable ~= nil and item.components.equippable.equipslot == EQUIPSLOTS.HEAD then
        local current = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD)
        if current ~= nil then
            inst.components.inventory:DropItem(current)
        end
        inst.components.inventory:Equip(item)
        inst.AnimState:Show("hat")
    end
end

local function OnRefuseItem(inst, item)
    inst.sg:GoToState("refuse")

    if inst.components.sleeper and inst.components.sleeper:IsAsleep() then
        inst.components.sleeper:WakeUp()
    end
end

local function SuggestTreeTarget(inst, data)
    local ba = inst:GetBufferedAction()
    if data ~= nil and data.tree ~= nil and (ba == nil or ba.action ~= ACTIONS.CHOP) then
        inst.tree_target = data.tree
    end
end

local function RoyalUpgrade(inst)
    if inst.components.health:IsDead() then
        return
    end

    inst.components.health:SetMaxHealth(TUNING.MERM_HEALTH_KINGBONUS)
    inst.components.combat:SetDefaultDamage(inst:MermDamageCalculator())
    inst.Transform:SetScale(1.05, 1.05, 1.05)
end

local function RoyalDowngrade(inst)
    if inst.components.health:IsDead() then
        return
    end

    inst.components.health:SetMaxHealth(TUNING.MERM_HEALTH)
    inst.components.combat:SetDefaultDamage(inst:MermDamageCalculator())
    inst.Transform:SetScale(1, 1, 1)
end

local function RoyalGuardUpgrade(inst)
    if inst.components.health:IsDead() then
        return
    end

    inst.components.health:SetMaxHealth(TUNING.MERM_GUARD_HEALTH)
    inst.components.combat:SetDefaultDamage(inst:MermDamageCalculator())
    if inst:HasTag("lunarminion") then
        inst.AnimState:SetBuild("merm_guard_lunar_build")
    else
        inst.AnimState:SetBuild("merm_guard_build")
    end    
    inst.Transform:SetScale(1, 1, 1)
end

local function RoyalGuardDowngrade(inst)
    if inst.components.health:IsDead() then
        return
    end

    inst.components.health:SetMaxHealth(TUNING.PUNY_MERM_HEALTH)
    inst.components.combat:SetDefaultDamage(inst:MermDamageCalculator())
    if inst:HasTag("lunarminion") then
        inst.AnimState:SetBuild("merm_guard_small_lunar_build")
    else
        inst.AnimState:SetBuild("merm_guard_small_build")
    end
    inst.Transform:SetScale(0.9, 0.9, 0.9)
end

local function ResolveMermChatter(inst, strid, strtbl)
    local stringtable = STRINGS[strtbl:value()]
    if stringtable then
        local table_at_id = stringtable[strid:value()]
        if table_at_id ~= nil then
            -- The first value is always the translated one
            local fluency_id = (ThePlayer ~= nil and ThePlayer:HasTag("mermfluent") and 1)
                or 2
            return table_at_id[fluency_id]
        end
    end

end

local function ShouldGuardSleep(inst)
    return false
end

local function ShouldGuardWakeUp(inst)
    return true
end

local function ShouldSleep(inst)
    return NocturnalSleepTest(inst)
        and ((inst.components.follower == nil or inst.components.follower.leader) == nil and
        not TheWorld.components.mermkingmanager and TheWorld.components.mermkingmanager:IsCandidate(inst))
end

local function ShouldWakeUp(inst)
    return NocturnalWakeTest(inst) or (TheWorld.components.mermkingmanager and TheWorld.components.mermkingmanager:IsCandidate(inst))
end

local function OnTimerDone(inst, data)
    if data.name == "facetime" then
        inst.components.timer:StartTimer("dontfacetime", 10)
    end
end

local function OnRanHome(inst)
    if inst:IsValid() then
        inst.runhometask = nil
        inst.wantstoteleport = nil

        local home = inst.components.homeseeker and inst.components.homeseeker:GetHome() or nil
        if home ~= nil and home.components.childspawner ~= nil then
            local invcmp = inst.components.inventory
            if invcmp then
                -- Drop equips only and place them around home!
                local x, y, z = home.Transform:GetWorldPosition()
                local homeradius = home:GetPhysicsRadius(1) + 1
                for _, equipped_item in pairs(invcmp.equipslots) do
                    local angle = math.random() * TWOPI
                    local pos = Vector3(x + math.cos(angle) * homeradius, 0, z - math.sin(angle) * homeradius)
                    invcmp:DropItem(equipped_item, true, true, pos)
                end
            end
            home.components.childspawner:GoHome(inst)
        end
    end
end

local function CancelRunHomeTask(inst)
    if inst.runhometask ~= nil then
        inst.runhometask:Cancel()
        inst.runhometask = nil
    end
end

local function OnEntitySleepMerm(inst)
    CancelRunHomeTask(inst) -- Cancel it here in case behaviour changes due to components.

    if not inst.wantstoteleport then
        return -- It did not want to teleport anyway, bail.
    end

    if inst.components.follower and inst.components.follower.leader then
        return -- Leader component takes care of this case by teleporting the entity to the leader.
    end

    local hometraveltime = inst.components.homeseeker and inst.components.homeseeker:GetHomeDirectTravelTime() or nil
    if hometraveltime ~= nil then
        inst.runhometask = inst:DoTaskInTime(hometraveltime, OnRanHome)
    end
end

local function OnMarkForTeleport(inst, data)
    if data and data.leader then
        -- Lost loyalty with a leader, mark home for magic poofing during off-screen "traveling" when going to entitysleep.
        inst.wantstoteleport = true
    end
end

local function OnUnmarkForTeleport(inst, data)
    if data and data.leader then
        -- Gain loyalty with a leader, remove mark home for magic poofing during off-screen "traveling" when going to entitysleep.
        inst.wantstoteleport = nil
    end
end

local function battlecry(combatcmp, target)
    local strtbl = (combatcmp.inst:HasTag("guard") and "MERM_GUARD_BATTLECRY")
        or "MERM_BATTLECRY"
    return strtbl, math.random(#STRINGS[strtbl])
end

local function OnSave(inst, data)
    if inst.wantstoteleport then
        data.wantstoteleport = true
    end
end

local function spawn_shadow_merm(inst)
    local merm = "merm_shadow"
    if inst:HasTag("guard") then
        merm = "mermguard_shadow"
    end
    local shadow = SpawnPrefab(merm)

    shadow.Transform:SetPosition(inst.Transform:GetWorldPosition())
    shadow.Transform:SetRotation(inst.Transform:GetRotation())
    inst.shadow_spawn_old_leader.components.leader:AddFollower(shadow)

    shadow:PushEvent("shadowmerm_spawn")
end

local function OnLoad(inst, data)
    if data then
        inst.wantstoteleport = data.wantstoteleport or inst.wantstoteleport
    end
end

local function TestForShadowDeath(inst)
    if not inst:HasTag("shadowminion") and inst.shadow_spawn_old_leader then
        spawn_shadow_merm(inst)
    end    
end

local function newcombattarget(inst, data)
    local tool = inst.components.inventory ~= nil and inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) or nil
    if tool then
        inst.components.inventory:GiveItem(inst.components.inventory:Unequip(EQUIPSLOTS.HANDS))
    end
end

local function droppedtarget(inst, data)
    local tool = inst.components.inventory ~= nil and inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) or nil
    if tool then
        return nil
    end

    if inst.components.inventory then 
        tool = inst.components.inventory:FindItem(function(item)
            if item.components.equippable and item.components.equippable.equipslot == EQUIPSLOTS.HANDS then
                return true
            end
        end)
    end
    if tool then
        inst.components.inventory:Equip(tool)
    end
end

local function itemget(inst,data)

    if not inst:HasTag("mermguard") then        
        local tool = inst.components.inventory ~= nil and inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) or nil
        if not tool and (data.item:HasTag("merm_tool") or data.item:HasTag("merm_tool_upgraded")) then            
            inst.components.inventory:Equip(data.item)
        end
    end
    if inst:HasTag("mermguard") then
        local armor = inst.components.inventory ~= nil and inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD) or nil
        if not armor and (data.item:HasTag("mermarmorhat") or data.item:HasTag("mermarmorupgradedhat")) then
            inst.components.inventory:Equip(data.item)
        end
    end
end

local function ShadowMerm_OnItemEquipped(inst, data)
    inst._equipschanged:push()

    if not TheNet:IsDedicated() then
        inst:_OnEquipsChanged()
    end
end

local function DoThorns(inst)
    SpawnPrefab("lunarmerm_thorns_fx"):SetFXOwner(inst)

    if inst.SoundEmitter ~= nil then
        inst.SoundEmitter:PlaySound("dontstarve/common/together/armor/cactus")
    end
end

local function DoLunarMutation(inst)
    local prefab = inst:HasTag("guard") and "mermguard_lunar" or "merm_lunar"

    local lunarmerm = SpawnPrefab(prefab)
    lunarmerm.Transform:SetPosition(inst.Transform:GetWorldPosition())
    lunarmerm.Transform:SetRotation(inst.Transform:GetRotation())

    inst.components.health:TransferComponent(lunarmerm)
    inst.components.inventory:TransferComponent(lunarmerm)

    local leader = inst.components.follower ~= nil and inst.components.follower:GetLeader() or nil

    if leader ~= nil then
        leader.components.leader:AddFollower(lunarmerm)
    end

    lunarmerm:PushEvent("mutated")

    inst:Remove()

    return lunarmerm
end

local function TestForLunarMutation(inst,item)
    if item:HasTag("moonglass_piece") then
        inst:DoLunarMutation()
        item:Remove()
    end
end

-- COMMON CODE FOR LIVING MERM, NOT SHADOW MERM
local function living_merm_common_master(inst)
    inst:AddComponent("eater")
    inst.components.eater:SetDiet({ FOODGROUP.VEGETARIAN }, { FOODGROUP.VEGETARIAN })
        
    inst:AddComponent("sleeper")
    inst.components.sleeper:SetNocturnal(true)
    inst.components.sleeper:SetSleepTest(ShouldSleep)
    inst.components.sleeper:SetWakeTest(ShouldWakeUp)

    inst:AddComponent("named")
    inst.components.named.possiblenames = STRINGS.MERMNAMES
    inst.components.named:PickNewName()

    MakeMediumBurnableCharacter(inst, "pig_torso")
end

local function CreateFlameFx()
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

    inst.AnimState:SetMultColour(1,1,1,0.5)

    inst.AnimState:SetBank("pigman")
    inst.AnimState:SetBuild("merm_actions_skills")
    inst.AnimState:PlayAnimation("flame", true)
    --inst.AnimState:SetSymbolLightOverride("fx_flame_red", 1)
    --inst.AnimState:SetSymbolLightOverride("fx_red", 1)
    inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()))

    return inst
end

local function MakeMerm(name, assets, prefabs, common_postinit, master_postinit,data)
    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddSoundEmitter()
        inst.entity:AddDynamicShadow()
        inst.entity:AddNetwork()

        MakeCharacterPhysics(inst, 50, .5)
        inst:SetPhysicsRadiusOverride(0.5)

        inst.DynamicShadow:SetSize(1.5, .75)
        inst.Transform:SetFourFaced()

        inst.AnimState:SetBank("pigman")
        inst.AnimState:Hide("hat")

        if IsSpecialEventActive(SPECIAL_EVENTS.YOTB) then
            inst.AnimState:AddOverrideBuild("pigman_yotb")
        end

        inst:AddTag("character")
        inst:AddTag("merm")
        inst:AddTag("wet")

        local talker = inst:AddComponent("talker")
        talker.fontsize = 35
        talker.font = TALKINGFONT
        talker.offset = Vector3(0, -400, 0)
        talker.resolvechatterfn = ResolveMermChatter
        talker:MakeChatter()


        if common_postinit ~= nil then
            common_postinit(inst)
        end

        -- Sneak these into pristine state for optimization.
        inst:AddTag("_named")

        inst.entity:SetPristine()
        if not TheWorld.ismastersim then
            return inst
        end

        inst.ismerm = true

        -- Remove these tags so that they can be added properly when replicating components below.
        inst:RemoveTag("_named")

        inst.DoCheer = DoCheer
        inst.DoDisapproval = DoDisapproval
        inst.OnSave = OnSave
        inst.OnLoad = OnLoad

        inst:AddComponent("locomotor")
        -- boat hopping setup
        inst.components.locomotor:SetAllowPlatformHopping(true)
        inst:AddComponent("embarker")
	    inst:AddComponent("drownable")

        -- Keep in sync with Wurt + mermking! But make sure no bonuses are applied!
        local foodaffinity = inst:AddComponent("foodaffinity")
        foodaffinity:AddFoodtypeAffinity(FOODTYPE.VEGGIE, 1)
        foodaffinity:AddPrefabAffinity  ("kelp",          1) -- prevents the negative stats
        foodaffinity:AddPrefabAffinity  ("kelp_cooked",   1) -- prevents the negative stats
        foodaffinity:AddPrefabAffinity  ("durian",        1) -- prevents the negative stats
        foodaffinity:AddPrefabAffinity  ("durian_cooked", 1) -- prevents the negative stats

        inst:AddComponent("health")
        inst.components.health:StartRegen(TUNING.MERM_HEALTH_REGEN_AMOUNT, TUNING.MERM_HEALTH_REGEN_PERIOD)

        inst:AddComponent("combat")
        inst.components.combat.GetBattleCryString = battlecry
        inst.components.combat.hiteffectsymbol = "pig_torso"

        inst:AddComponent("lootdropper")
        inst:AddComponent("inventory")
        inst:AddComponent("inspectable")
        inst:AddComponent("knownlocations")
        inst:AddComponent("follower")
        inst:AddComponent("mermcandidate")

        inst:AddComponent("timer")

        local trader = inst:AddComponent("trader")
        trader:SetAcceptTest(ShouldAcceptItem)
        trader:SetAbleToAcceptTest(IsAbleToAccept)
        trader.onaccept = OnGetItemFromPlayer
        trader.onrefuse = OnRefuseItem
        trader.deleteitemonaccept = false

        MakeMediumFreezableCharacter(inst, "pig_torso")


        inst:ListenForEvent("timerdone", OnTimerDone)
        inst:ListenForEvent("attacked", OnAttacked)
        inst:ListenForEvent("attackdodged", OnAttackDodged)
        inst:ListenForEvent("suggest_tree_target", SuggestTreeTarget)
        inst:ListenForEvent("entitysleep", OnEntitySleepMerm)
        inst:ListenForEvent("entitywake", CancelRunHomeTask)
        -- NOTES(JBK): The following events are not mutually exclusive such that `gainloyalty` can also fire off when `startfollowing` does.
        inst:ListenForEvent("loseloyalty", OnMarkForTeleport)
        inst:ListenForEvent("stopfollowing", OnMarkForTeleport)
        inst:ListenForEvent("gainloyalty", OnUnmarkForTeleport)
        inst:ListenForEvent("startfollowing", OnUnmarkForTeleport)
        inst:ListenForEvent("droppedtarget", droppedtarget)
        inst:ListenForEvent("newcombattarget", newcombattarget)
        inst:ListenForEvent("itemget", itemget)

        inst.TestForLunarMutation = TestForLunarMutation
        inst.DoLunarMutation = DoLunarMutation
        inst.MermDamageCalculator = MermDamageCalculator
        inst.TestForShadowDeath = TestForShadowDeath
        inst.DoThorns = DoThorns

        if not data or not data.unliving then
            living_merm_common_master(inst) 
        end

        if master_postinit ~= nil then
            master_postinit(inst)
        end

        if inst.sg and inst.physicsradiusoverride then
            inst.sg.mem.radius = inst.physicsradiusoverride
        end

        return inst
    end

    return Prefab(name, fn, assets, prefabs)
end

local function OnEat(inst, data)
    if data.food and data.food.components.edible then
        if TheWorld.components.mermkingmanager and TheWorld.components.mermkingmanager:IsCandidate(inst) then
            inst.components.mermcandidate:AddCalories(data.food)
        end
    end
end

-- Guard
local function guard_common(inst)
    inst.AnimState:SetBuild("merm_guard_build")
    inst:AddTag("mermguard")
    inst.Transform:SetScale(1, 1, 1)
    inst:AddTag("guard")

    inst.sounds = sounds_guard
end

local function on_mermking_created_upgrade_guard(inst)
    RoyalGuardUpgrade(inst)
    inst:PushEvent("onmermkingcreated")
end
local function guard_on_mermking_created_anywhere(inst)
    inst:DoTaskInTime(math.random()*SLIGHTDELAY, on_mermking_created_upgrade_guard)
end

local function on_mermking_destroyed_downgrade_guard(inst)
    RoyalGuardDowngrade(inst)
    inst:PushEvent("onmermkingdestroyed")
end
local function guard_on_mermking_destroyed_anywhere(inst)
    inst:DoTaskInTime(math.random()*SLIGHTDELAY, on_mermking_destroyed_downgrade_guard)
end

local function on_guard_initialize(inst)
    if not (TheWorld.components.mermkingmanager and TheWorld.components.mermkingmanager:HasKingAnywhere()) then
        RoyalGuardDowngrade(inst)
    end
end

local function Guard_ShouldWaitForHelp(inst)
    if inst.components.combat.target == nil then
        return false
    end

    local leader = inst.components.follower:GetLeader()

    return leader ~= nil and
        leader.components.skilltreeupdater ~= nil and
        leader.components.skilltreeupdater:IsActivated("wurt_merm_flee") and
        inst.components.health:GetPercent() <= LOW_HEALTH_PERCENT
end

local function Guard_CanTripleAttack(inst)
    return inst.components.debuffable ~= nil
        and inst.components.debuffable:HasDebuff("mermkingtridentbuff")
        and math.random() < TUNING.MERMKING_TRIDENTBUFF_TRIPLEHIT_CHANCE
end

local function guard_master(inst)
    inst.ShouldWaitForHelp = Guard_ShouldWaitForHelp

    -- Limit the triple attack upgrade to the merm guards
    inst.CanTripleAttack = Guard_CanTripleAttack

    inst.components.locomotor.runspeed =  TUNING.MERM_GUARD_RUN_SPEED
    inst.components.locomotor.walkspeed = TUNING.MERM_GUARD_WALK_SPEED

    inst:SetStateGraph("SGmerm")
    inst:SetBrain(merm_guard_brain)

    inst.components.combat:SetRetargetFunction(1, RetargetFn)
    inst.components.combat:SetKeepTargetFunction(KeepTargetFn)

    inst.components.health:SetMaxHealth(TUNING.MERM_GUARD_HEALTH)
    inst.components.combat:SetDefaultDamage(inst:MermDamageCalculator())
    inst.components.combat:SetAttackPeriod(TUNING.MERM_GUARD_ATTACK_PERIOD)

    if inst.components.sleeper then
        inst.components.sleeper:SetSleepTest(ShouldGuardSleep)
        inst.components.sleeper:SetWakeTest(ShouldGuardWakeUp)
    end

    inst.components.lootdropper:SetLoot(merm_guard_loot)

    inst.components.follower.maxfollowtime = TUNING.MERM_GUARD_LOYALTY_MAXTIME

    inst:ListenForEvent("onmermkingcreated_anywhere", function() guard_on_mermking_created_anywhere(inst) end, TheWorld)
    inst:ListenForEvent("onmermkingdestroyed_anywhere", function() guard_on_mermking_destroyed_anywhere(inst) end, TheWorld)

    inst:DoTaskInTime(0, on_guard_initialize)
end

-- Common
local function common_displaynamefn(inst)
    return (inst:HasTag("mermprince") and STRINGS.NAMES.MERM_PRINCE) or nil
end

local function common_common(inst)
    inst.sounds = sounds
    inst.AnimState:SetBuild("merm_build")

    inst.displaynamefn = common_displaynamefn
end


local function on_mermking_created_upgrade(inst)
    RoyalUpgrade(inst)
    inst:PushEvent("onmermkingcreated")
end
local function on_mermking_created_anywhere(inst)
    inst:DoTaskInTime(math.random()*SLIGHTDELAY, on_mermking_created_upgrade)
end

local function on_mermking_destroyed_downgrade(inst)
    RoyalDowngrade(inst)
    inst:PushEvent("onmermkingdestroyed")
end
local function on_mermking_destroyed_anywhere(inst)
    inst:DoTaskInTime(math.random()*SLIGHTDELAY, on_mermking_destroyed_downgrade)
end

local function no_holes(pt)
    return not TheWorld.Map:IsPointNearHole(pt)
end

local function OnAttackOther(inst, data)
    local victim = data.target
    if not victim then return end

    local leader = (inst.components.follower and inst.components.follower.leader) or nil
    if not leader then return end

    local leader_has_shadow_terrain_skill = (leader.components.skilltreeupdater
        and leader.components.skilltreeupdater:IsActivated("wurt_shadow_allegiance_2")
    ) or false
    if leader_has_shadow_terrain_skill and math.random() > TUNING.WURT_TERRAFORMING_SHADOW_PROCCHANCE then
        local tile_type = inst:GetCurrentTileType()
        if tile_type == WORLD_TILES.SHADOW_MARSH then
            local pt = victim:GetPosition()
            local offset = FindWalkableOffset(pt, math.random() * TWOPI, 2, 3, false, true, no_holes, false, true)
            if offset ~= nil then
                inst.SoundEmitter:PlaySound("dontstarve/common/shadowTentacleAttack_1")
                inst.SoundEmitter:PlaySound("dontstarve/common/shadowTentacleAttack_2")
                local tentacle = SpawnPrefab("shadowtentacle")
                if tentacle ~= nil then
                    tentacle.owner = inst
                    tentacle.Transform:SetPosition(pt.x + offset.x, 0, pt.z + offset.z)
                    tentacle.components.combat:SetTarget(victim)
                end
            end
        end
    end
end

local function common_master(inst)

    inst.components.locomotor.runspeed = TUNING.MERM_RUN_SPEED
    inst.components.locomotor.walkspeed = TUNING.MERM_WALK_SPEED

    inst:SetStateGraph("SGmerm")
    inst:SetBrain(merm_brain)

    inst.components.combat:SetAttackPeriod(TUNING.MERM_ATTACK_PERIOD)
    inst.components.combat:SetRetargetFunction(1, RetargetFn)
    inst.components.combat:SetKeepTargetFunction(KeepTargetFn)

    inst.components.health:SetMaxHealth(TUNING.MERM_HEALTH)
    inst.components.combat:SetDefaultDamage(inst:MermDamageCalculator())
    inst.components.combat:SetAttackPeriod(TUNING.MERM_ATTACK_PERIOD)

    MakeHauntablePanic(inst)

    inst.components.lootdropper:SetLoot(merm_loot)

    inst.components.follower.maxfollowtime = TUNING.MERM_LOYALTY_MAXTIME

    inst:ListenForEvent("onmermkingcreated_anywhere", function() on_mermking_created_anywhere(inst) end, TheWorld)
    inst:ListenForEvent("onmermkingdestroyed_anywhere", function() on_mermking_destroyed_anywhere(inst) end, TheWorld)
    inst:ListenForEvent("onattackother", OnAttackOther) -- TODO @stevenm this could maybe be a (de)buff instead.
    inst:ListenForEvent("oneat", OnEat)


    if TheWorld.components.mermkingmanager and TheWorld.components.mermkingmanager:HasKingAnywhere() then
        RoyalUpgrade(inst)
    end
end

-------------------------------------------------------------------------------
-- SHADOW MERM DEFS

local function CLIENT_ShadowMerm_OnEquipsChanged(inst)
    if inst.highlightchildren ~= nil then
        for _, child in ipairs(inst.highlightchildren) do
            child.AnimState:SetMultColour(0, 0, 0, .5)
            child.AnimState:UsePointFiltering(true)
        end
    end
end

local function shadow_merm_common(inst)
    common_common(inst)
    inst:SetPhysicsRadiusOverride(0.5)

    inst:AddTag("shadowminion")
    inst:AddTag("shadow_aligned")
    inst.AnimState:UsePointFiltering(true)

    inst.AnimState:SetMultColour(0,0,0,0.5)

    inst._equipschanged = net_event(inst.GUID, "merm_shadow._equipschanged")

    inst._OnEquipsChanged = CLIENT_ShadowMerm_OnEquipsChanged

    if not TheWorld.ismastersim then
        inst:ListenForEvent("merm_shadow._equipschanged", inst._OnEquipsChanged)
    end
end

local function shadow_merm_master(inst)
    common_master(inst)

    inst:RemoveComponent("sleeper")
   
    inst.components.combat:SetAttackPeriod(TUNING.MERM_ATTACK_PERIOD)
    inst.components.combat:SetRetargetFunction(1, RetargetFn)
    inst.components.combat:SetKeepTargetFunction(KeepTargetFn)

    inst.components.health:SetMaxHealth(TUNING.MERM_HEALTH)
    inst.components.combat:SetDefaultDamage(inst:MermDamageCalculator())
    inst.components.combat:SetAttackPeriod(TUNING.MERM_ATTACK_PERIOD)

    inst:AddComponent("planardamage")
    inst.components.planardamage:SetBaseDamage(0)

    inst.components.talker:IgnoreAll()

    inst.components.lootdropper:SetLoot(merm_shadow_loot)

    inst.components.follower.maxfollowtime = TUNING.MERM_LOYALTY_MAXTIME

    inst:ListenForEvent("equip", ShadowMerm_OnItemEquipped)
end

local function shadow_mermguard_common(inst)
    guard_common(inst)
    inst:SetPhysicsRadiusOverride(0.5)

    inst:AddTag("shadowminion")
    inst:AddTag("shadow_aligned")
    inst.AnimState:UsePointFiltering(true)
    inst.AnimState:SetMultColour(0,0,0,0.5)

    inst._equipschanged = net_event(inst.GUID, "merm_shadow._equipschanged")

    inst._OnEquipsChanged = CLIENT_ShadowMerm_OnEquipsChanged

    if not TheWorld.ismastersim then
        inst:ListenForEvent("merm_shadow._equipschanged", inst._OnEquipsChanged)
    end
end

local function shadow_mermguard_master(inst)
    guard_master(inst)

    inst.components.combat:SetAttackPeriod(TUNING.MERM_ATTACK_PERIOD)
    inst.components.combat:SetRetargetFunction(1, RetargetFn)
    inst.components.combat:SetKeepTargetFunction(KeepTargetFn)

    inst.components.health:SetMaxHealth(TUNING.MERM_GUARD_HEALTH)
    inst.components.combat:SetDefaultDamage(inst:MermDamageCalculator())
    inst.components.combat:SetAttackPeriod(TUNING.MERM_GUARD_ATTACK_PERIOD)

    inst:AddComponent("planardamage")
    inst.components.planardamage:SetBaseDamage(0)

    inst.components.lootdropper:SetLoot(merm_shadow_loot)

    inst.components.follower.maxfollowtime = TUNING.MERM_LOYALTY_MAXTIME

    inst:ListenForEvent("equip", ShadowMerm_OnItemEquipped)
end

-------------------------------------------------------------------------------
-- LUNAR MERM DEFS

local function SetLunarEyeFire(inst)
    local flamesL = CreateFlameFx()
    flamesL.entity:SetParent(inst.entity)
    flamesL.Follower:FollowSymbol(inst.GUID, "flameL", nil, nil, nil, true)
    inst.flamesL = flamesL

    local flamesR = CreateFlameFx()
    flamesR.entity:SetParent(inst.entity)
    flamesR.Follower:FollowSymbol(inst.GUID, "flameR", nil, nil, nil, true)
    inst.flamesR = flamesR
end

local function RemoveLunarEyeFire(inst)
    if inst.flamesL then
        inst.flamesL:Remove()
    end
    if inst.flamesR then
        inst.flamesR:Remove()
    end
end

local function lunarbuff_changed(inst)
    if inst.lunarbuffed:value() then
        SetLunarEyeFire(inst)
    else
        RemoveLunarEyeFire(inst)
    end
end

local function lunar_merm_common(inst)
    common_common(inst)
    inst.AnimState:SetBuild("merm_lunar_build")
    inst:SetPhysicsRadiusOverride(0.5)

    inst.lunarbuffed = net_bool(inst.GUID, "merm.lunarbuffed", "lunarbuffeddirty")

    if not TheNet:IsDedicated() then
        inst:ListenForEvent("lunarbuffeddirty", lunarbuff_changed)
    end

    inst:AddTag("lunarminion")
    inst:AddTag("lunar_aligned")
end

local function lunar_merm_master(inst)
    common_master(inst)
   
    inst.components.combat:SetAttackPeriod(TUNING.MERM_ATTACK_PERIOD)
    inst.components.combat:SetRetargetFunction(1, RetargetFn)
    inst.components.combat:SetKeepTargetFunction(KeepTargetFn)

    inst.components.health:SetMaxHealth(TUNING.MERM_LUNAR_HEALTH)
    inst.components.combat:SetDefaultDamage(inst:MermDamageCalculator())
    inst.components.combat:SetAttackPeriod(TUNING.MERM_ATTACK_PERIOD)

    inst:AddComponent("planardamage")
    inst.components.planardamage:SetBaseDamage(0)

    inst.components.talker:IgnoreAll()
    
    inst.components.lootdropper:SetChanceLootTable('merm_lunar_loot')

    inst.components.follower.maxfollowtime = TUNING.MERM_LOYALTY_MAXTIME
end

local function lunar_mermguard_common(inst)
    guard_common(inst)
    inst.AnimState:SetBuild("merm_guard_lunar_build")
    inst:SetPhysicsRadiusOverride(0.5)

    inst.lunarbuffed = net_bool(inst.GUID, "merm.lunarbuffed", "lunarbuffeddirty")

    if not TheNet:IsDedicated() then
        inst:ListenForEvent("lunarbuffeddirty", lunarbuff_changed)
    end

    inst:AddTag("lunarminion")
    inst:AddTag("lunar_aligned")
end

local function lunar_mermguard_master(inst)
    guard_master(inst)

    inst:RemoveComponent("sleeper")

    inst.components.combat:SetAttackPeriod(TUNING.MERM_ATTACK_PERIOD)
    inst.components.combat:SetRetargetFunction(1, RetargetFn)
    inst.components.combat:SetKeepTargetFunction(KeepTargetFn)

    inst.components.health:SetMaxHealth(TUNING.MERM_LUNAR_GUARD_HEALTH)
    inst.components.combat:SetDefaultDamage(inst:MermDamageCalculator())
    inst.components.combat:SetAttackPeriod(TUNING.MERM_GUARD_ATTACK_PERIOD)

    inst:AddComponent("planardamage")
    inst.components.planardamage:SetBaseDamage(0)
    
    inst.components.lootdropper:SetChanceLootTable('merm_lunar_loot')

    inst.components.follower.maxfollowtime = TUNING.MERM_LOYALTY_MAXTIME
end

-----------------------------------------------------------------------------

--DSV uses 4 but ignores physics radius
local MAXRANGE = 3
local NO_TAGS_NO_PLAYERS =  { "bramble_resistant", "INLIMBO", "notarget", "noattack", "flight", "invisible", "wall", "player", "companion" }
local NO_TAGS =             { "bramble_resistant", "INLIMBO", "notarget", "noattack", "flight", "invisible", "wall", "playerghost" }
local COMBAT_TARGET_TAGS = { "_combat" }

local function OnUpdateThorns(inst)
    inst.range = inst.range + .75

    local x, y, z = inst.Transform:GetWorldPosition()
    for i, v in ipairs(TheSim:FindEntities(x, y, z, inst.range + 3, COMBAT_TARGET_TAGS, inst.canhitplayers and NO_TAGS or NO_TAGS_NO_PLAYERS)) do
        if not inst.ignore[v] and
            v:IsValid() and
            v.entity:IsVisible() and
            v.components.combat ~= nil and
            not (v.components.inventory ~= nil and
                v.components.inventory:EquipHasTag("bramble_resistant")) then
            local range = inst.range + v:GetPhysicsRadius(0)
            if v:GetDistanceSqToPoint(x, y, z) < range * range then
                if inst.owner ~= nil and not inst.owner:IsValid() then
                    inst.owner = nil
                end
                if inst.owner ~= nil then
                    local leader = inst.owner.components.follower and inst.owner.components.follower.leader
                    if inst.owner.components.combat ~= nil and
                        inst.owner.components.combat:CanTarget(v) and
                        not inst.owner.components.combat:IsAlly(v) and
                        (not leader or not leader.components.combat:IsAlly(v)) and
                        not v:HasTag("merm")
                    then
                        inst.ignore[v] = true
                        v.components.combat:GetAttacked(v.components.follower and v.components.follower:GetLeader() == inst.owner and inst or inst.owner, inst.damage, nil, nil, inst.spdmg)
                        --V2C: wisecracks make more sense for being pricked by picking
                        --v:PushEvent("thorns")
                    end
                elseif v.components.combat:CanBeAttacked() then
                    -- NOTES(JBK): inst.owner is nil here so this is for non worn things like the bramble trap.
                    local isally = false
                    if not inst.canhitplayers then
                        --non-pvp, so don't hit any player followers (unless they are targeting a player!)
                        local leader = v.components.follower ~= nil and v.components.follower:GetLeader() or nil
                        isally = leader ~= nil and leader:HasTag("player") and
                            not (v.components.combat ~= nil and
                                v.components.combat.target ~= nil and
                                v.components.combat.target:HasTag("player"))
                    end
                    if not isally then
                        inst.ignore[v] = true
                        v.components.combat:GetAttacked(inst, inst.damage, nil, nil, inst.spdmg)
                        --v:PushEvent("thorns")
                    end
                end
            end
        end
    end

    if inst.range >= MAXRANGE then
        inst.components.updatelooper:RemoveOnUpdateFn(OnUpdateThorns)
    end
end

local function SetFXOwner(inst, owner)
    inst.Transform:SetPosition(owner.Transform:GetWorldPosition())
    inst.owner = owner
    inst.canhitplayers = not owner:HasTag("player") or TheNet:GetPVPEnabled()
    inst.ignore[owner] = true
end

local function MakeFX(name, anim, damage, planardamage)
    local function fxfn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()

        if planardamage then
            inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
        end

        inst:AddTag("FX")
        inst:AddTag("thorny")
        if name == "bramblefx_trap" then
            inst:AddTag("trapdamage")
        end

        inst.Transform:SetFourFaced()

        inst.AnimState:SetBank("bramblefx")
        inst.AnimState:SetBuild("bramblefx")
        inst.AnimState:PlayAnimation(anim)

        inst:SetPrefabNameOverride("bramblefx")

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("updatelooper")
        inst.components.updatelooper:AddOnUpdateFn(OnUpdateThorns)

        inst:ListenForEvent("animover", inst.Remove)
        inst.persists = false
        inst.damage = TUNING[damage]
        inst.spdmg = planardamage and { planar = TUNING[planardamage] } or nil
        inst.range = .75
        inst.ignore = {}
        inst.canhitplayers = true
        --inst.owner = nil

        inst.SetFXOwner = SetFXOwner

        return inst
    end

    return Prefab(name, fxfn, assetsfx)
end
return MakeMerm("merm", assets, prefabs, common_common, common_master),
       MakeMerm("mermguard", assets, prefabs, guard_common, guard_master),
       MakeMerm("merm_shadow", assets, prefabs, shadow_merm_common, shadow_merm_master,{unliving=true}),
       MakeMerm("mermguard_shadow", assets, prefabs, shadow_mermguard_common, shadow_mermguard_master,{unliving=true}),
       MakeMerm("merm_lunar", assets, prefabs, lunar_merm_common, lunar_merm_master),
       MakeMerm("mermguard_lunar", assets, prefabs, lunar_mermguard_common, lunar_mermguard_master),
       MakeFX("lunarmerm_thorns_fx", "idle", "MERM_LUNAR_THORN_DAMAGE")