require("stategraphs/commonstates")

local function movetail(inst,anim)
    if inst.tails and #inst.tails > 0 then
        local time = 0   
        for i=#inst.tails, 1,-1 do
            local tail = inst.tails[i]
            --for i, tail in ipairs(inst.tails)do
            time = time + 0.1
            inst:DoTaskInTime(time,function() tail.sg:GoToState(anim) end)                
        end
    end
end

local actionhandlers =
{
}
local MUST_TAGS =  {"_combat"}
local CANT_TAGS = { "FX", "NOCLICK", "DECOR", "INLIMBO", "invisible", "notarget", "noattack", "lunarthrall_plant", "lunarthrall_plant_end" }
local events =
{
    CommonHandlers.OnFreeze(),
    EventHandler("attacked", function(inst)
        if not inst.components.health:IsDead() then
            if inst.sg:HasStateTag("caninterrupt") or not inst.sg:HasStateTag("busy") then
                inst.sg:GoToState("hit")
            end
        end
    end),
    EventHandler("doattack", function(inst, data)
        if not (inst.sg:HasStateTag("busy") and not inst.components.health:IsDead()) then 
            if not inst.sg:HasStateTag("emerged") then
                inst.sg:GoToState("emerge")
            else          
                inst.sg:GoToState("attack")
            end
        else
            inst:DoTaskInTime(0,function()inst:ChooseAction()end)
        end
    end),
    EventHandler("death", function(inst) inst.sg:GoToState("death") end),
}

local states=
{
    State{
        name = "idle",
        tags = {"idle", "canrotate","emerged"},

        onenter = function(inst)
            inst.AnimState:PlayAnimation("breach_idle")
        end,

        events =
        {
            EventHandler("animover", function(inst) 
                inst.sg:GoToState("idle")
                inst:ChooseAction()
            end),
        },
    },

    State{
        name = "emerge",
        tags = {"busy", "canrotate","emerged"},

        onenter = function(inst)
            inst.SoundEmitter:PlaySound("rifts/lunarthrall/vine_spawn")
            inst.AnimState:PlayAnimation("breach_pre")
        end,

        timeline=
        {
            TimeEvent(7*FRAMES, function(inst) inst.sg:AddStateTag("caninterrupt") end ),
        },

        events =
        {
            EventHandler("animover", function(inst) 
                inst:ChooseAction()
                inst.sg:GoToState("idle") 
            end),
        },
    },

    State{
        name = "retract",
        tags = {"busy", "canrotate", "retracting"},

        onenter = function(inst, pos)
            inst.sg.statemem.pos = pos
            inst.AnimState:PlayAnimation("breach_pst")
        end,

        timeline=
        {
            TimeEvent(15*FRAMES, function(inst) 
                inst.sg:AddStateTag("noattack")
                if inst.components.burnable and inst.components.burnable:IsBurning() then
                    inst.components.burnable:Extinguish()
                end
            end ),
        },

        events =
        {
            EventHandler("animover", function(inst) 
                if inst.sg.statemem.pos then
                    -- moving forward
                    inst.sg:GoToState("nub_spawn",inst.sg.statemem.pos)
                elseif #inst.tails > 0 then
                    -- moving backward
                    inst.Transform:SetPosition(inst.tails[#inst.tails].Transform:GetWorldPosition())
                    inst.tails[#inst.tails]:Remove()
                    inst.tails[#inst.tails] = nil
                    inst:ChooseAction()
                else
                    -- TELL THE PLANT YOU HAVE REMOVED.. do event listener?
                    inst:Remove()
                end
            end),
        },
    },

    State{
        name = "attack",
        tags = {"busy", "canrotate","emerged"},

        onenter = function(inst)
            inst.AnimState:PlayAnimation("atk")
            inst.components.timer:StartTimer("attack_cooldown",TUNING.LUNARTHRALL_PLANT_ATTACK_PERIOD)
        end,

        timeline=
        {

            TimeEvent(10*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("rifts/lunarthrall/vine_attack")
            end),
            TimeEvent(17*FRAMES, function(inst)
                local x,y,z = inst.Transform:GetWorldPosition()
                local targets = TheSim:FindEntities(x, y, z, TUNING.LUNARTHRALL_PLANT_VINE_ATTACK_RANGE, MUST_TAGS, CANT_TAGS )
                for i,target in ipairs(targets)do
                    inst.components.combat:DoAttack(target)
                end
            end ),
        },

        events =
        {
            EventHandler("animover", function(inst) 
                inst.sg:GoToState("idle")
                inst:ChooseAction()
            end),
        },
    },

    State{
        name = "hit",
        tags = {"busy","emerged"},

        onenter = function(inst)
            inst.AnimState:PlayAnimation("hit")
        end,

        timeline=
        {
            --TimeEvent(25*FRAMES, function(inst) end ),
        },

        events =
        {
            EventHandler("animover", function(inst) 
                inst.sg:GoToState("idle") 
                inst:ChooseAction()
            end),
        },

        onexit = function(inst)
        end,
    },
    
    State{
        name = "death",
        tags = {"busy","emerged"},

        onenter = function(inst)
            if inst.parentplant and inst.parentplant:IsValid() then
                inst.parentplant:vinekilled(inst)
            end
            inst.AnimState:PlayAnimation("death")
            inst.SoundEmitter:PlaySound("rifts/lunarthrall/vine_death")
        end,
    },

    State{
        name = "nub_spawn",
        tags = {"busy", "noattack"},

        onenter = function(inst,pos)
            inst.sg.statemem.pos = pos
            inst.AnimState:PlayAnimation("spawn")
            movetail(inst,"nub_forward")
             
        end,
        events =
        {
            EventHandler("animover", function(inst)
                local nub = SpawnPrefab("lunarthrall_plant_vine")
                nub.Transform:SetPosition(inst.Transform:GetWorldPosition())
                nub.sg:GoToState("nub_idle")

                if inst.tintcolor then
                    nub.tintcolor = inst.tintcolor
                    nub.AnimState:SetMultColour(inst.tintcolor, inst.tintcolor, inst.tintcolor, 1)
                end

                nub.Transform:SetRotation(inst.Transform:GetRotation())
                table.insert(inst.tails,nub)
                local dist = inst:GetDistanceSqToPoint(inst.sg.statemem.pos)
                local newpos = inst.sg.statemem.pos
                if dist > TUNING.LUNARTHRALL_PLANT_MOVEDIST * TUNING.LUNARTHRALL_PLANT_MOVEDIST then
                    local theta = inst:GetAngleToPoint(newpos)*DEGREES
                    local radius = 2.5
                    local offset = Vector3(radius * math.cos( theta ), 0, -radius * math.sin( theta ))
                    newpos = Vector3(inst.Transform:GetWorldPosition()) + offset
                end
                local angle = nub:GetAngleToPoint(newpos)
                inst.Transform:SetPosition(newpos.x,newpos.y,newpos.z)
                inst.Transform:SetRotation(angle)
                inst.sg:RemoveStateTag("busy")
                inst:ChooseAction()
            end),
        },
    },

    State{
        name = "nub_idle",
        tags = {"idle", "noattack"},

        onenter = function(inst)
            inst.AnimState:PlayAnimation("idle")
        end,
    },

    State{
        name = "nub_reverse",
        tags = {"noattack"},

        onenter = function(inst)
            inst.AnimState:PlayAnimation("retract_loop")
        end,

        events =
        {
            EventHandler("animover", function(inst) 
                inst.sg:GoToState("nub_idle") 
            end),
        },        
    },  

    State{
        name = "nub_forward",
        tags = {"noattack"},

        onenter = function(inst)
            inst.AnimState:PlayAnimation("loop")
        end,

        events =
        {
            EventHandler("animover", function(inst) 
                inst.sg:GoToState("nub_idle") 
            end),
        },        
    },  

    State{
        name = "nub_retract",
        tags = {"noattack"},

        onenter = function(inst)
            inst.AnimState:PlayAnimation("retract")
            inst.SoundEmitter:PlaySound("rifts/lunarthrall/vine_retract")
            movetail(inst,"nub_reverse")
        end,
        events =
        {
            EventHandler("animover", function(inst) 
                if #inst.tails > 0 then
                    inst.Transform:SetPosition(inst.tails[#inst.tails].Transform:GetWorldPosition())
                    inst.tails[#inst.tails]:Remove()
                    inst.tails[#inst.tails] = nil
                    inst:ChooseAction()
                else
                    inst:Remove()
                end
            end),
        },
    },
}

CommonStates.AddFrozenStates(states)

return StateGraph("lunarthrall_plant_vine", states, events, "nub_idle", actionhandlers)
