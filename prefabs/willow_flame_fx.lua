local shadowassets =
{
    Asset("ANIM", "anim/shadow_fire_fx.zip"),
    Asset("SOUND", "sound/common.fsb"),
}

local throwassets =
{
    Asset("ANIM", "anim/flamethrow_fx.zip"),
    Asset("SOUND", "sound/common.fsb"),
}


local frenzyassets = {
    Asset("ANIM", "anim/frenzy_fx.zip"),
}

local prefabs =
{
    "firefx_light",
    "willow_shadow_fire_explode",
}

local shadowfirelevels =
{
    {anim="anim1", sound="meta3/willow/shadowflame", radius=2, intensity=.8, falloff=.33, colour = {253/255,179/255,179/255}, soundintensity=.1},
    {anim="anim2",                                   radius=2, intensity=.8, falloff=.33, colour = {253/255,179/255,179/255}, soundintensity=.1},
    {anim="anim3",                                   radius=2, intensity=.8, falloff=.33, colour = {253/255,179/255,179/255}, soundintensity=.1},
    {anim="anim3",                                   radius=2, intensity=.8, falloff=.33, colour = {253/255,179/255,179/255}, soundintensity=.1},
}

local throwfirelevels =
{
    {anim="pre", sound="dontstarve/common/campfire", radius=2, intensity=.8, falloff=.33, colour = {253/255,179/255,179/255}, soundintensity=.1},
}

local CLOSERANGE = 1

local TARGETS_MUST = {"_health"}
local TARGETS_CANT = {"player"}

local FLAME_MUST = {"willow_shadow_flame"}

local function settarget(inst,target,life,source)
    local maxdeflect = 30

    if life > 0 then

        inst:DoTaskInTime(0.1,function()

            local theta = inst.Transform:GetRotation() * DEGREES
            local radius = CLOSERANGE

            if not target or not target:IsValid() or target.components.health:IsDead() then
                inst.shadow_ember_target = nil
                local pos = Vector3(inst.Transform:GetWorldPosition())
                local ents = TheSim:FindEntities(pos.x, pos.y, pos.z, 20, TARGETS_MUST,TARGETS_CANT)

                local targets = {}
                local flameents = TheSim:FindEntities(pos.x, pos.y, pos.z, 20, FLAME_MUST)
                for i,flame in ipairs(flameents)do
                    if flame.shadow_ember_target then
                        targets[flame.shadow_ember_target] = true
                    end
                end


                if #ents > 0 then
                    for i=#ents,1,-1 do
                        local ent = ents[i]
                        if (
                                ent:HasTag("hostile") or
                                (ent.components.combat and ent.components.combat.target and ent.components.combat.target == source) 
                            ) and
                            (not ent.components.follower or not ent.components.follower.leader or ent.components.follower.leader ~= source ) 
                            and not targets[ent]
                        then
                            --keep
                        else
                            table.remove(ents,i)
                        end
                    end
                
                    target = ents[1]    
                    inst.shadow_ember_target = target
                end
                
            end
            if target then
                local dist = inst:GetDistanceSqToInst(target)

                if dist<CLOSERANGE*CLOSERANGE then

                    local blast = SpawnPrefab("willow_shadow_fire_explode")
                    local pos = Vector3(target.Transform:GetWorldPosition())
                    blast.Transform:SetPosition(pos.x,pos.y,pos.z)

                    local weapon = inst

                    source.components.combat.ignorehitrange = true
                    source.components.combat.ignoredamagereflect = true

                    source.components.combat:DoAttack(target, weapon)

                    source.components.combat.ignorehitrange = false
                    source.components.combat.ignoredamagereflect = false

                    theta = nil
                else
                    local pt = Vector3(target.Transform:GetWorldPosition())
                    local angle = inst:GetAngleToPoint(pt.x,pt.y,pt.z)
                    local anglediff = angle - inst.Transform:GetRotation() 
                    if anglediff > 180 then
                        anglediff = anglediff - 360
                    elseif anglediff < -180 then
                        anglediff = anglediff + 360
                    end
                    if math.abs(anglediff) > maxdeflect then 
                        anglediff = math.clamp(anglediff, -maxdeflect, maxdeflect)
                    end

                    theta = (inst.Transform:GetRotation() + anglediff) * DEGREES
                end
            else
                if not inst.currentdeflection then
                    inst.currentdeflection = {time = math.random(1,10), deflection = maxdeflect * ((math.random() *2)-1) }
                end
                inst.currentdeflection.time = inst.currentdeflection.time -1
                if inst.currentdeflection.time then
                    inst.currentdeflection = {time = math.random(1,10), deflection = maxdeflect * ((math.random() *2)-1) }
                end

                theta =  (inst.Transform:GetRotation() + inst.currentdeflection.deflection) * DEGREES
            end

            if theta  then
                local offset = Vector3(radius * math.cos( theta ), 0, -radius * math.sin( theta ))
                local newpos = Vector3(inst.Transform:GetWorldPosition()) + offset
                local newangle = inst:GetAngleToPoint(newpos.x,newpos.y,newpos.z)

                local fire = SpawnPrefab("willow_shadow_flame")
                fire.Transform:SetRotation(newangle)
                fire.Transform:SetPosition(newpos.x,newpos.y,newpos.z)
                fire:settarget(target,life-1, source)
            end
        end)

    end
end

local function shadowfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst.AnimState:SetBank("shadow_fire_fx")
    inst.AnimState:SetBuild("shadow_fire_fx")
    inst.AnimState:PlayAnimation("anim"..math.random(1,3),false)

    --inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
    inst.AnimState:SetMultColour(0, 0, 0, .6)
    inst.AnimState:SetFinalOffset(3)

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")
    inst:AddTag("willow_shadow_flame")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false

    inst:AddComponent("firefx")
    inst.components.firefx.levels = shadowfirelevels

    inst.components.firefx:SetLevel(math.random(1,4))

    inst:AddComponent("weapon")
    inst.components.weapon:SetDamage(TUNING.WILLOW_LUNAR_FIRE_DAMAGE * 2)

    inst:AddComponent("planardamage")
    inst.components.planardamage:SetBaseDamage(TUNING.WILLOW_LUNAR_FIRE_PLANAR_DAMAGE * 2)


    inst:AddComponent("damagetypebonus")
    inst.components.damagetypebonus:AddBonus("lunar_aligned", inst, TUNING.WILLOW_SHADOW_FIRE_BONUS)        


    inst:ListenForEvent("animover", function()
        if inst.AnimState:IsCurrentAnimation("anim1") or inst.AnimState:IsCurrentAnimation("anim2") or inst.AnimState:IsCurrentAnimation("anim3") then
            inst:Remove()
        end
    end)

    inst.settarget = settarget

    return inst
end

local function throwfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst.AnimState:SetBank("flamethrow_fx")
    inst.AnimState:SetBuild("flamethrow_fx")
    inst.AnimState:PlayAnimation("pre",false)

    inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
    inst.AnimState:SetFinalOffset(3)

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false

    inst:AddComponent("firefx")
    inst.components.firefx.levels = throwfirelevels

    inst.components.firefx:SetLevel(1)
    inst:DoTaskInTime(10/30,function() 
            local x,y,z= inst.Transform:GetWorldPosition()
            SpawnPrefab("deerclops_laserscorch").Transform:SetPosition(x, 0, z)
    end)

    inst:ListenForEvent("animover", function()
        if inst.AnimState:IsCurrentAnimation("pre") then            
            inst:Remove()
        end
    end)

    inst.settarget = settarget

    return inst
end

---- FRENZY


local function onloopfrenzy(inst,dt)
    local rate = 10
    inst.Transform:SetRotation(inst.Transform:GetRotation()+(rate*dt))
    if inst._frenzyparent:IsValid() then
        inst.Transform:SetPosition(inst._frenzyparent.Transform:GetWorldPosition())
    end
end

local function AddFrenzyFX(parent)
    local inst = CreateEntity()

    inst:AddTag("NOCLICK")
    inst:AddTag("FX")
    --[[Non-networked entity]]
    inst.persists = false

    inst.entity:AddTransform()
    inst.entity:AddAnimState()

    inst.AnimState:SetBank("frenzy_fx")
    inst.AnimState:SetBuild("frenzy_fx")
    inst.AnimState:PlayAnimation("pre",false)
    inst.AnimState:PlayAnimation("loop",true)
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetSortOrder(3)

    inst.AnimState:SetMultColour(1,1,1,0.2)

    inst:ListenForEvent("animover", function()
        if inst.AnimState:IsCurrentAnimation("post") then            
            inst:Remove()
        end
    end)

    inst:AddComponent("updatelooper")
    inst.components.updatelooper:AddOnUpdateFn(onloopfrenzy)

    inst._frenzyparent = parent
    return inst
end


local function FrenzyDoOnClientInit(inst)
    inst.fx = AddFrenzyFX(inst)
    inst.fx.entity:AddFollower()
    inst.fx.Follower:FollowSymbol(inst.GUID, "circle", 0, 0, 0)
end


local function OnFrenzyEnd(inst)
    if inst._end:value() == true then
        inst.fx.AnimState:PlayAnimation("post")
        inst:DoTaskInTime(2,function() inst:Remove() end)
    end
end

local function frenzydone(inst)
    inst._end:set(true)    
end

local function frenzyfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    inst.AnimState:SetBank("frenzy_fx")
    inst.AnimState:SetBuild("frenzy_fx")
    inst.AnimState:PlayAnimation("pre",false)
    inst.AnimState:SetMultColour(1,1,1,0)

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")

    inst._end = net_bool(inst.GUID, "frenzyfn._end", "enddirty")
    inst._end:set(false)

    inst.entity:SetPristine()    

    --Dedicated server does not need the fx
    if not TheNet:IsDedicated() then
        inst:ListenForEvent("enddirty", OnFrenzyEnd)
        FrenzyDoOnClientInit(inst)
    end

    if not TheWorld.ismastersim then        
        return inst
    end    

    inst.frenzydone = frenzydone

    inst.persists = false

    return inst
end

return Prefab("willow_shadow_flame", shadowfn, shadowassets, prefabs),
       Prefab("willow_throw_flame", throwfn, throwassets, prefabs),
       Prefab("willow_frenzy", frenzyfn, frenzyassets)
