local events =
{
    --[[EventHandler("loadammo", function(inst, data)
    end),]]
}

local states =
{
    State{
        name = "idle",
        tags = { "idle" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("idle", true)
        end,
    },

    State{
        name = "load",
        tags = { "busy" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("load")
        end,

        timeline =
        {
            TimeEvent(1 * FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("monkeyisland/cannon/load")
                inst.AnimState:HideSymbol("cannon_flap_up")
                inst.AnimState:ShowSymbol("cannon_flap_down")
            end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },

    State{
        name = "shoot",
        tags = { "busy", "shooting" },

        onenter = function(inst, data)
            inst.AnimState:PlayAnimation("shoot")
            inst.SoundEmitter:PlaySound("monkeyisland/cannon/shoot")
        end,

        timeline =
        {
            TimeEvent(7 * FRAMES, function(inst)
                inst.components.boatcannon:Shoot()
            end),
            TimeEvent(10 * FRAMES, function(inst)
                inst.AnimState:HideSymbol("cannon_flap_down")
                inst.AnimState:ShowSymbol("cannon_flap_up")
            end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },

    State{
        name = "place",
        tags = { "busy" },

        onenter = function(inst)
            inst.SoundEmitter:PlaySound("monkeyisland/cannon/place")
            inst.AnimState:PlayAnimation("place")
            inst.AnimState:HideSymbol("cannon_flap_down")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },

    State{
        name = "hit",
        tags = { "busy" },

        onenter = function(inst, light)
            inst.SoundEmitter:PlaySound("monkeyisland/cannon/hit")
            inst.AnimState:PlayAnimation("hit")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },
}

return StateGraph("boatcannon", states, events, "idle")
