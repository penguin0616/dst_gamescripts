require("stategraphs/commonstates")
require("stategraphs/SGcritter_common")

local actionhandlers =
{
    ActionHandler(ACTIONS.WOBY_PICKUP, "pickup")
}

local events =
{
    SGCritterEvents.OnEat(),
    SGCritterEvents.OnAvoidCombat(),
    SGCritterEvents.OnTraitChanged(),

    CommonHandlers.OnSleepEx(),
    CommonHandlers.OnWakeEx(),
    CommonHandlers.OnLocomote(false,true),
    CommonHandlers.OnHop(),
    CommonHandlers.OnSink(),
    CommonHandlers.OnFallInVoid(),

    EventHandler("transform", function(inst, data)
        if inst.sg.currentstate.name ~= "transform" then
            inst.sg:GoToState("transform")
        end
    end),

    EventHandler("dig_ground", function(inst, data)
        if not inst.sg:HasStateTag("nointerrupt") then
            inst.sg:GoToState("dig_ground")
        end
    end),
}

-----------------------------------------------------------------------------------------------------------------------

local function StartActionCooldown(inst, name, cooldown, aspect)
    local dogtrainer = inst._playerlink ~= nil and inst._playerlink.components.dogtrainer or nil

    if dogtrainer ~= nil then
        local tuning = TUNING.SKILLS.WALTER.WOBY_BADGES
        local badge_fmt = string.upper(aspect).."_%d"

        local pct = dogtrainer:GetAspectPercent(aspect)

        local badge

        for i=1, NUM_WOBY_TRAINING_ASPECTS_LEVELS do
            badge = badge_fmt:format(i)

            if tuning[badge] ~= nil and dogtrainer:HasBadge(badge) then
                cooldown = cooldown - tuning[badge] * pct
            end
        end

        dogtrainer:DoAspectDelta(aspect, TUNING.SKILLS.WALTER.WOBY_BADGES_ASPECT_GAIN_RATE[aspect])
    end

    inst.components.timer:StartTimer(name, cooldown)

end

local function ShouldFailPickup(inst)
    local dogtrainer = inst._playerlink ~= nil and inst._playerlink.components.dogtrainer or nil

    if dogtrainer ~= nil then
        local tuning = TUNING.SKILLS.WALTER.WOBY_FETCHING_ASSIST_SUCCESS_CHANCE

        local pct = dogtrainer:GetAspectPercent(WOBY_TRAINING_ASPECTS.FETCHING)
        local chance = tuning.min + (tuning.max - tuning.min) * pct

        return math.random() > chance
    end

    return true
end

-----------------------------------------------------------------------------------------------------------------------

local states =
{
        State{
        name="transform",
        tags = {"busy"},

        onenter = function(inst, data)
            inst.components.locomotor:StopMoving()
            inst.AnimState:AddOverrideBuild("woby_big_build")
            inst.AnimState:PlayAnimation("transform_small_to_big")
        end,

        timeline =
        {
            TimeEvent(1*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/transform_small_to_big") end),
            TimeEvent(41*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/big/roar") end),
            TimeEvent(80*FRAMES, function(inst)
                inst:FinishTransformation()
            end),
        },
    },

    State{
        name = "despawn",
        tags = {"busy", "nointerrupt"},

        onenter = function(inst, pushanim)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("idle_loop", true)
        end,

        onexit = function(inst)
            inst:DoTaskInTime(0, inst.Remove)
        end,
    },

    State{
        name = "dig_ground",
        tags = {"busy"},

        onenter = function(inst)
            inst.components.locomotor:StopMoving()

            local mass = inst.Physics:GetMass()

            if mass > 0 then
                inst.sg.statemem.restoremass = mass
                inst.Physics:SetMass(99999)
            end

            inst.AnimState:PlayAnimation("dig_pre")
            inst.AnimState:PushAnimation("dig_loop")

            inst.sg:SetTimeout((22 + 16 * math.random(2, 3)) * FRAMES) -- dig_pre + 2/3 dig_loop
        end,

        ontimeout = function(inst)
            inst.sg:GoToState("dig_ground_pst")
        end,

        onexit = function(inst)
            if inst.sg.statemem.restoremass ~= nil then
                inst.Physics:SetMass(inst.sg.statemem.restoremass)
            end
        end,
    },

    State{
        name = "dig_ground_pst",
        tags = {"busy"},

        onenter = function(inst)
            inst.components.locomotor:StopMoving()

            local mass = inst.Physics:GetMass()

            if mass > 0 then
                inst.sg.statemem.restoremass = mass
                inst.Physics:SetMass(99999)
            end

            inst.sg.statemem.item = inst:SpawnDiggingReward()

            inst.AnimState:PlayAnimation(inst.sg.statemem.item ~= nil and "dig_pst" or "dig_fail")

            StartActionCooldown(inst, "diggingcooldown", TUNING.SKILLS.WALTER.WOBY_DIGGING_COOLDOWN, WOBY_TRAINING_ASPECTS.DIGGING)
        end,

        timeline =
        {
            TimeEvent(10*FRAMES, function(inst)
                if inst.sg.statemem.item ~= nil then
                    inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/small/bark")
                end
            end),
            TimeEvent(15*FRAMES, function(inst)
                if inst.sg.statemem.restoremass ~= nil then
                    inst.Physics:SetMass(inst.sg.statemem.restoremass)

                    inst.sg.statemem.restoremass = nil
                end
            end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end)
        },

        onexit = function(inst)
            if inst.sg.statemem.restoremass ~= nil then
                inst.Physics:SetMass(inst.sg.statemem.restoremass)
            end
        end,
    },

    State{
        name = "pickup",
        tags = {"busy", "jumping"},

        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            inst.components.locomotor:EnableGroundSpeedMultiplier(false)

            inst.sg.statemem.missed = ShouldFailPickup(inst)

            inst.AnimState:PlayAnimation("fetch")
            inst.AnimState:SetFrame(6)

            local buffaction = inst:GetBufferedAction()
            local target = buffaction ~= nil and buffaction.target or nil

            if target ~= nil and target:IsValid() then
                inst:ForceFacePoint(buffaction.target.Transform:GetWorldPosition())
            end
        end,

        onupdate = function(inst)
            local buffaction = inst:GetBufferedAction()
            local target = buffaction ~= nil and buffaction.target or nil

            if target ~= nil and inst.sg.statemem.missed then
                inst.Physics:SetMotorVelOverride(5, 0, 0)

                return
            end

            if target == nil or not target:IsValid() then
                inst.Physics:ClearMotorVelOverride()

                inst:ClearBufferedAction()

                return
            end

            local distance = math.sqrt(inst:GetDistanceSqToInst(target))

            if distance > .2 then
                inst.Physics:SetMotorVelOverride(math.max(distance, 4), 0, 0)
            else
                inst.Physics:ClearMotorVelOverride()
            end
        end,

        timeline = {
            TimeEvent((21-6)*FRAMES, function(inst)
                if inst.sg.statemem.missed then
                    inst:ClearBufferedAction()
                else
                    inst:PerformBufferedAction()
                end

                StartActionCooldown(inst, "fetchingcooldown", TUNING.SKILLS.WALTER.WOBY_FETCHING_ASSIST_COOLDOWN, WOBY_TRAINING_ASPECTS.FETCHING)
            end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("pickup_pst", inst.sg.statemem.missed)
                end
            end)
        },

        onexit = function(inst)
            inst.components.locomotor:EnableGroundSpeedMultiplier(true)
            inst.Physics:ClearMotorVelOverride()
        end,
    },

    State{
        name = "pickup_pst",
        tags = {"busy"},

        onenter = function(inst, missed)
            inst.components.locomotor:StopMoving()

            inst.AnimState:PlayAnimation(missed and "fetch_fail_pst" or "fetch_pst")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end)
        },
    },
}

local emotes =
{
    { anim="emote_scratch",
      timeline=
         {
            TimeEvent(15*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/emote_scratch") end),
            TimeEvent(26*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/emote_scratch") end),
            TimeEvent(35*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/emote_scratch") end),
            TimeEvent(45*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/emote_scratch") end),
            TimeEvent(55*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/emote_scratch") end),
        },
    },
    { anim="emote_play_dead",
      timeline=
         {
            TimeEvent(20*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/pant") end),
            TimeEvent(48*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/pant") end),
            TimeEvent(76*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/small/bark") end),
        },
    },
}

SGCritterStates.AddIdle(states, #emotes,
    {
        --TimeEvent(7*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/pant") end),
    })
SGCritterStates.AddRandomEmotes(states, emotes)
SGCritterStates.AddEmote(states, "cute",
    {
        TimeEvent(10*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/sheepington/stallion") end),
        TimeEvent(14*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/sheepington/stallion") end),
        TimeEvent(19*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/sheepington/stallion") end),
        TimeEvent(22*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/sheepington/stallion") end),
        TimeEvent(25*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/sheepington/stallion") end),
        TimeEvent(29*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/sheepington/stallion") end),
        TimeEvent(34*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/sheepington/stallion") end),
    })
SGCritterStates.AddPetEmote(states,
    {
        TimeEvent(8*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/tail") end),
        TimeEvent(12*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/tail") end),
        TimeEvent(16*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/tail") end),
        TimeEvent(24*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/tail") end),
    })
SGCritterStates.AddCombatEmote(states,
    {
        pre =
        {
            TimeEvent(9*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/small/bark") end),
        },
        loop =
        {
            TimeEvent(9*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/small/bark") end),
            TimeEvent(26*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/pant") end),
            TimeEvent(34*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/pant") end),
            TimeEvent(48*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/small/bark") end),
        },
    })
SGCritterStates.AddPlayWithOtherCritter(states, events,
    {
        active =
        {
            TimeEvent(3*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/growl") end),
            TimeEvent(13*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/growl") end),
        },
        passive =
        {
            TimeEvent(5*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/pant") end),
            TimeEvent(14*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/pant") end),
        },
    })
SGCritterStates.AddEat(states,
    {
        TimeEvent(0*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/small/eat") end),
    })


SGCritterStates.AddHungry(states,
    {
        TimeEvent(0*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/small/bark") end),
    })
SGCritterStates.AddNuzzle(states, actionhandlers,
    {
        TimeEvent(13*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/emote_scratch") end),
        TimeEvent(13*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/sleep") end),
        TimeEvent(35*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/emote_scratch") end),
        TimeEvent(36*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/sleep") end),
    })

SGCritterStates.AddWalkStates(states,
    {
        starttimeline =
        {
            TimeEvent(0*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/pant") end),
            TimeEvent(4*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/pant") end),
        },
        walktimeline =
        {
            TimeEvent(1*FRAMES, function(inst) PlayFootstep(inst, 0.25) end),
            TimeEvent(4*FRAMES, function(inst) PlayFootstep(inst, 0.25) end),
        },
    }, true)

CommonStates.AddSleepExStates(states,
    {
        starttimeline =
        {
            TimeEvent(6*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/growl") end),
        },
        sleeptimeline =
        {
            TimeEvent(14*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/sleep") end),
        },
    })

CommonStates.AddHopStates(states, true)
CommonStates.AddSinkAndWashAshoreStates(states)
CommonStates.AddVoidFallStates(states)

return StateGraph("wobysmall", states, events, "idle", actionhandlers)
