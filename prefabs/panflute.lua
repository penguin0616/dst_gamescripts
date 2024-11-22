local assets = {
    Asset("ANIM", "anim/pan_flute.zip"),
}

local function OnPlayed(inst, musician)
    -- Clear temp variables in UseModifier!
    inst.panflute_sleeptime = TUNING.PANFLUTE_SLEEPTIME

    if musician:HasDebuff("wortox_panflute_buff") then
        musician:RemoveDebuff("wortox_panflute_buff")
        if musician.components.sanity then
            musician.components.sanity:DoDelta(TUNING.SANITY_TINY)
        end
        inst.panflute_shouldfiniteuses_stopuse = true
    end

    local skilltreeupdater = musician.components.skilltreeupdater
    if skilltreeupdater then
        if skilltreeupdater:IsActivated("wortox_panflute_duration") then
            inst.panflute_sleeptime = inst.panflute_sleeptime + TUNING.SKILLS.WORTOX.WORTOX_PANFLUTE_SLEEP_DURATION
        end
        if skilltreeupdater:IsActivated("wortox_panflute_forget") then
            inst.panflute_wortox_forget_debuff = true
        end
    end
end

local function HearPanFlute(inst, musician, instrument)
    if inst ~= musician and
        (TheNet:GetPVPEnabled() or not inst:HasTag("player")) and
        not (inst.components.freezable ~= nil and inst.components.freezable:IsFrozen()) and
        not (inst.components.pinnable ~= nil and inst.components.pinnable:IsStuck()) and
        not (inst.components.fossilizable ~= nil and inst.components.fossilizable:IsFossilized()) then
        local mount = inst.components.rider ~= nil and inst.components.rider:GetMount() or nil
        if mount ~= nil then
            mount:PushEvent("ridersleep", { sleepiness = 10, sleeptime = instrument.panflute_sleeptime })
        end
		if inst.components.farmplanttendable ~= nil then
			inst.components.farmplanttendable:TendTo(musician)
        elseif inst.components.sleeper ~= nil then
            inst.components.sleeper:AddSleepiness(10, instrument.panflute_sleeptime)
        elseif inst.components.grogginess ~= nil then
            inst.components.grogginess:AddGrogginess(10, instrument.panflute_sleeptime)
        else
            inst:PushEvent("knockedout")
        end
        if instrument.panflute_wortox_forget_debuff and inst.components.combat then
            inst:AddDebuff("wortox_forget_debuff", "wortox_forget_debuff", {toforget = musician})
        end
    end
end

local function UseModifier(uses, action, doer, target, item)
    item.panflute_wortox_forget_debuff = nil
    if item.panflute_shouldfiniteuses_stopuse then
        item.panflute_shouldfiniteuses_stopuse = nil
        return 0
    end
    return uses
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst:AddTag("flute")

    inst.AnimState:SetBank("pan_flute")
    inst.AnimState:SetBuild("pan_flute")
    inst.AnimState:PlayAnimation("idle")

    --tool (from tool component) added to pristine state for optimization
    inst:AddTag("tool")

    MakeInventoryFloatable(inst, "small", 0.05, 0.8)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")
    inst:AddComponent("instrument")
    inst.components.instrument:SetRange(TUNING.PANFLUTE_SLEEPRANGE)
    inst.components.instrument:SetOnPlayedFn(OnPlayed)
    inst.components.instrument:SetOnHeardFn(HearPanFlute)

    inst:AddComponent("tool")
    inst.components.tool:SetAction(ACTIONS.PLAY)

    inst:AddComponent("finiteuses")
    inst.components.finiteuses:SetMaxUses(TUNING.PANFLUTE_USES)
    inst.components.finiteuses:SetUses(TUNING.PANFLUTE_USES)
    inst.components.finiteuses:SetOnFinished(inst.Remove)
    inst.components.finiteuses:SetConsumption(ACTIONS.PLAY, 1)
    inst.components.finiteuses:SetModifyUseConsumption(UseModifier)

    inst:AddComponent("inventoryitem")

    MakeHauntableLaunch(inst)

    inst:ListenForEvent("floater_startfloating", function(inst) inst.AnimState:PlayAnimation("float") end)
    inst:ListenForEvent("floater_stopfloating", function(inst) inst.AnimState:PlayAnimation("idle") end)

    return inst
end

return Prefab("panflute", fn, assets)
