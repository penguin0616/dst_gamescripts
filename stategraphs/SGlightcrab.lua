local WALK_SPEED = 4
local RUN_SPEED = 7

require("stategraphs/commonstates")

local actionhandlers =
{
    ActionHandler(ACTIONS.EAT, "eat"),
}

local events=
{
    CommonHandlers.OnSleep(),
    CommonHandlers.OnFreeze(),
    CommonHandlers.OnAttacked(),
    CommonHandlers.OnDeath(),
    CommonHandlers.OnLocomote(true, true),
    EventHandler("trapped", function(inst)
		if inst.components.health == nil or not inst.components.health:IsDead() then
			inst.sg:GoToState("trapped")
		end
	end),
    EventHandler("stunbomb", function(inst)
		if inst.components.health == nil or not inst.components.health:IsDead() then
			inst.sg:GoToState("stunned")
		end
    end),
}

local states=
{
    State{
        name = "idle",
        tags = {"idle", "canrotate"},
        onenter = function(inst, playanim)
            inst.Physics:Stop()
            if playanim then
                inst.AnimState:PlayAnimation(playanim)
            else
				local r = math.random(10) - 7
				if r > 1 then
					inst.sg:GoToState("idle"..r)
					return
				else
                    inst.SoundEmitter:KillSound("walk_loop")
                    inst.SoundEmitter:KillSound("run_loop")
	                inst.AnimState:PlayAnimation("idle")

				end

            end
        end,

        events =
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        },
    },

    State{
        name = "eat",
		tabs = {"canrotate"},

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("idle3", false)
            inst.AnimState:PushAnimation("eat", false)
            inst.SoundEmitter:KillSound("walk_loop")
            inst.SoundEmitter:KillSound("run_loop")
        end,

        events=
        {
            EventHandler("animqueueover", function(inst) 
				if math.random() < 0.125 then
					inst:PerformBufferedAction() 
					inst.sg:GoToState("idle") 
				else
					inst:ClearBufferedAction()
					inst.sg:GoToState("idle") 
				end

			end),
        },
    },

    State{
        name = "death",
        tags = {"busy"},

        onenter = function(inst)
            inst.Physics:Stop()
            RemovePhysicsColliders(inst)
			inst.Light:Enable(false)
            inst.SoundEmitter:KillSound("walk_loop")
            inst.SoundEmitter:KillSound("run_loop")

            inst.AnimState:PlayAnimation("death")
            inst.SoundEmitter:PlaySound("monkeyisland/lightcrab/death")
            inst.components.lootdropper:DropLoot()
        end,

    },

     State{
        name = "portal_spawn",
        tags = {"busy", "stunned", "nointerrupt", "jumping", "nosleep"},
        onenter = function(inst)
            inst.Physics:SetDamping(0)
            inst.AnimState:PlayAnimation("stunned_loop", true)
        end,

        onupdate = function(inst)
            local x, y, z = inst.Transform:GetWorldPosition()
            if y <= .1 then
                inst.Physics:Stop()
                inst.Physics:SetDamping(5)
                inst.sg:GoToState("hit")
            end
        end,

        onexit = function(inst)
            local x, y, z = inst.Transform:GetWorldPosition()
            inst.Transform:SetPosition(x, 0, z)
        end,
    },

    State{
        name = "stunned",
        tags = {"busy", "stunned"},

        onenter = function(inst, duration)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("stunned_loop", true)
            inst.sg:SetTimeout(duration or GetRandomWithVariance(6, 2) )
            if inst.components.inventoryitem then
                inst.components.inventoryitem.canbepickedup = true
            end
        end,

        onexit = function(inst)
            if inst.components.inventoryitem then
                inst.components.inventoryitem.canbepickedup = false
            end
        end,

        ontimeout = function(inst) inst.sg:GoToState("idle") end,
    },

    State{
        name = "trapped",
        tags = {"busy", "trapped"},

        onenter = function(inst)
            inst.Physics:Stop()
			inst:ClearBufferedAction()
            inst.AnimState:PlayAnimation("stunned_loop", true)
            inst.SoundEmitter:KillSound("walk_loop")
            inst.SoundEmitter:KillSound("run_loop")
            inst.sg:SetTimeout(1)
        end,

        ontimeout = function(inst) inst.sg:GoToState("idle") end,
    },

    State{
        name = "hit",
        tags = {"busy"},

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("hit")
            inst.SoundEmitter:KillSound("walk_loop")
            inst.SoundEmitter:KillSound("run_loop")
            inst.SoundEmitter:PlaySound("monkeyisland/lightcrab/hit")
        end,

        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end ),
        },
    },

}

CommonStates.AddWalkStates(states,
{
    starttimeline =
    {
		-- todo: sound effects
    },

    walktimeline =
    {
    TimeEvent(0*FRAMES, function(inst) inst.SoundEmitter:PlaySound("monkeyisland/lightcrab/walk", "walk_loop") end),
    },
},
nil, nil, nil,
{
    endonexit = function(inst)
    inst.SoundEmitter:KillSound("walk_loop")
    end,
})
CommonStates.AddRunStates(states,
{
    starttimeline =
    {
        -- todo: sound effects
    },
    runtimeline =
    {
    TimeEvent(0*FRAMES, function(inst) inst.SoundEmitter:PlaySound("monkeyisland/lightcrab/run", "run_loop") end),
    },
},
nil, nil, nil,
{
    endonexit = function(inst)
        inst.SoundEmitter:KillSound("run_loop")
    end,
})

CommonStates.AddSleepStates(states)
CommonStates.AddFrozenStates(states)
CommonStates.AddSimpleState(states, "idle2", "idle2", {"canrotate"})
CommonStates.AddSimpleState(states, "idle3", "idle3", {"canrotate"})



return StateGraph("lightcrab", states, events, "idle", actionhandlers)

