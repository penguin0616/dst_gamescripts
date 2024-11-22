local assets =
{
    Asset("ANIM", "anim/shadow_ground_arc_fx.zip"),
    Asset("SOUND", "sound/sfx.fsb"),
}

local prefabs =
{

}

local function findnextlocation(inst)
    local angle = nil
    local scale = nil

    local animlength = 4

    local nextpoint = nil

    if inst.target then
        local dist = inst:GetDistanceSqToInst(inst.target)
        local targetangle = inst:GetAngleToPoint(inst.target.Transform:GetWorldPosition())
        if dist < animlength*animlength and  dist > (animlength/2)*(animlength/2) or inst.bounced then
            angle = targetangle
            scale = math.min(1, (animlength*animlength)/dist)
        else
            if inst.toward and  dist > (animlength/2)*(animlength/2) then
                angle = targetangle + (math.random()*50)-25
            else
                if dist <= (animlength/2)*(animlength/2) then
                    inst.bounced = true
                end
                angle = targetangle + (((math.random()*30)+100) * (math.random()<0.5 and 1 or -1) )
            end

            scale = (math.random() * 0.25) + 0.75

            local radius = scale*animlength
            local theta = angle * DEGREES
            local offset = Vector3(radius * math.cos( theta ), 0, -radius * math.sin( theta ))
            nextpoint = Vector3(inst.Transform:GetWorldPosition()) + offset

        end
    end

    if angle and scale then
        inst.Transform:SetRotation(angle)
        inst.AnimState:SetScale(scale,1,1)        
    end

    inst:DoTaskInTime(0.15, function() 
        if nextpoint then
            local nextFX = SpawnPrefab("shadow_ground_seeking_bolt")
            nextFX.target = inst.target
            nextFX.finishfn = inst.finishfn
            nextFX.toward = not inst.toward
            nextFX.bounced = inst.bounced
            --local x,y,z = inst.Transform:GetWorldPosition()
            nextFX.Transform:SetPosition(nextpoint.x,0,nextpoint.z)
            nextFX:findnextlocation()            
        else
            if inst.finishfn then
                inst.finishfn(inst)
            end
        end
    end)
    
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst.AnimState:SetBank("shadow_ground_arc_fx")
    inst.AnimState:SetBuild("shadow_ground_arc_fx")
    inst.AnimState:PlayAnimation("shadow_ground_arc_fx")

    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetLayer(LAYER_GROUND)
    inst.AnimState:SetSortOrder(1)
    inst.AnimState:SetFinalOffset(1)

    inst:AddTag("NOCLICK")
    inst:AddTag("fx")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.findnextlocation = findnextlocation
    inst:ListenForEvent("animover", function() inst:Remove() end)

    return inst
end

return Prefab("shadow_ground_seeking_bolt", fn, assets, prefabs)
