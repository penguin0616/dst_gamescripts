local assets =
{
    Asset("ANIM", "anim/wolfgang_whistle.zip"),
}

local function getuseitemverb(inst,doer)
    if doer:HasTag("wolfgang_coach") and doer:HasTag("mightiness_normal") then
        if doer:HasTag("coaching") then
            return "COACH_OFF"
        else
            return "COACH_ON"
        end
    else
        return "TWEET"
    end
end

local function onuse(inst,doer)
    if doer:HasTag("wolfgang_coach") and doer.components.mightiness:GetState() == "normal" then
        if doer:HasTag("coaching") then        
            inst.components.useableitem:StopUsingItem()
            if doer.components.coach then
                doer.components.coach:Disable()
            end
        else           
            if doer.components.coach then
                doer.components.coach:Enable()
            end
        end
    end
    doer:PushEvent("coach_whistle")
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("wolfgang_whistle")
    inst.AnimState:SetBuild("wolfgang_whistle")
    inst.AnimState:PlayAnimation("idle")

    inst.getuseitemverb = getuseitemverb

    inst.pickupsound = "metal"

    inst:AddTag("cattoy")
    inst:AddTag("useitem_toggle")

    MakeInventoryFloatable(inst, "med", 0.05, 0.68)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inventoryitem")

    inst:AddComponent("inspectable")
    inst:AddComponent("tradable")

    inst:AddComponent("useableitem")
    inst.components.useableitem:SetOnUseFn(onuse)

    MakeHauntableLaunchAndIgnite(inst)

    return inst
end

return Prefab("wolfgang_whistle", fn, assets)
