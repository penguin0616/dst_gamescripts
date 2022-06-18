local MONKEY_CURSE_PREFAB = "cursed_monkey_token"

local events =
{
    EventHandler("stopcursechanneling", function(inst, data)
        if inst.sg:HasStateTag("channel") then
            if data.success then
                inst.sg:GoToState("removecurse_success")
            else
                inst.sg:GoToState("removecurse_fail")
            end
        end
    end),
}

local states =
{
    State{
        name = "idle",
        tags = {"idle"},
        onenter = function(inst)
            inst.AnimState:PlayAnimation("idle")
        end,
        events = 
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end)
        },
    },

    State{
        name = "getitem",
        tags = {"busy"},
        onenter = function(inst, data)
            inst.components.talker:Say(STRINGS["MONKEY_QUEEN_BANANAS"][math.random(1,#STRINGS["MONKEY_QUEEN_BANANAS"])])
            inst.AnimState:OverrideSymbol("swap_item", "cave_banana", "cave_banana01")
            inst.AnimState:PlayAnimation("receive_item")

            inst.SoundEmitter:PlaySound("monkeyisland/monkeyqueen/receive_item")

            inst.sg.statemem.giver = data.giver
        end,

        events = 
        {
            EventHandler("animover", function(inst) 
                local ents = nil
                if inst.sg.statemem.giver then
                    ents = inst.sg.statemem.giver.components.inventory:FindItems(function(item) return item:HasTag("cursed") end)
                end
                if ents and #ents > 0 then
                    inst.sg:GoToState("removecurse", {giver = inst.sg.statemem.giver})
                else 
                    if inst.sg.statemem.giver:HasTag("player") then

                        if not inst.sg.statemem.giver.components.builder:KnowsRecipe("boat_cannon_kit") then
                            local loot = SpawnPrefab("boat_cannon_kit_blueprint")
                            inst.components.lootdropper:FlingItem(loot)
                            loot:AddTag("nosteal")
                            local loot2 = SpawnPrefab("cannonball_rock_item_blueprint")
                            inst.components.lootdropper:FlingItem(loot2)
                            loot2:AddTag("nosteal")
                        elseif not inst.sg.statemem.giver.components.builder:KnowsRecipe("dock_kit") then
                            local loot = SpawnPrefab("dock_kit_blueprint")
                            inst.components.lootdropper:FlingItem(loot)
                            loot:AddTag("nosteal")
                            local loot2 = SpawnPrefab("dock_woodposts_item_blueprint")
                            inst.components.lootdropper:FlingItem(loot2)
                            loot2:AddTag("nosteal")
                        elseif not inst.sg.statemem.giver.components.builder:KnowsRecipe("turf_monkey_ground") then
                             local loot = SpawnPrefab("turf_monkey_ground_blueprint")
                            inst.components.lootdropper:FlingItem(loot)
                            loot:AddTag("nosteal")
                        end
                    end
                    inst.sg:GoToState("happy",{say="MONKEY_QUEEN_HAPPY"})
                end
            end)
        },
    },

    State{
        name = "happy",
        tags = {"busy"},
        onenter = function(inst, data)
            inst.components.talker:Say(STRINGS[data.say][math.random(1,#STRINGS[data.say])])
            inst.AnimState:PlayAnimation("happy")

            inst.SoundEmitter:PlaySound("monkeyisland/monkeyqueen/happy")
        end,

        events = 
        {
            EventHandler("animover", function(inst) 
                inst.sg:GoToState("idle")
            end)
        },    
    },

    State{
        name = "removecurse",
        tags = {"busy"},
        onenter = function(inst, data)
            inst.components.talker:Say(STRINGS["MONKEY_QUEEN_REMOVE_CURSE"][math.random(1,#STRINGS["MONKEY_QUEEN_REMOVE_CURSE"])])
            inst.AnimState:PlayAnimation("curse_remove_pre")
            inst.SoundEmitter:PlaySound("monkeyisland/monkeyqueen/channel_magic_pre")
            inst.sg.statemem.giver = data.giver
        end,

        events = 
        {
            EventHandler("animover", function(inst)
                if inst.sg.statemem.giver then
                    local giver = inst.sg.statemem.giver
                    if giver.components.inventory ~= nil and giver.components.cursable then
                        giver.components.cursable:RemoveCurse("MONKEY",4)

                        local curse = SpawnPrefab("cursed_monkey_token_prop")
                        curse.Transform:SetPosition(giver.Transform:GetWorldPosition())
                        curse:RemoveComponent("inventoryitem")
                        curse:RemoveComponent("curseditem")
                        curse.target = inst
                    end

                    local curses =  giver.components.inventory:FindItems(function(thing) return thing:HasTag("monkey_token") end)

                    if #curses >= 0 then
                        inst.right_of_passage = true
                        if inst.components.timer:TimerExists("right_of_passage") then
                            inst.components.timer:SetTimeLeft("right_of_passage", TUNING.MONKEY_QUEEN_GRACE_TIME) -- TUNING.TOTAL_DAY_TIME/2 )
                        else
                            inst.components.timer:StartTimer("right_of_passage", TUNING.MONKEY_QUEEN_GRACE_TIME) -- TUNING.TOTAL_DAY_TIME/2
                        end
                    end
                end
                inst.sg:GoToState("removecurse_channel")
            end)
        },
    },

    State{
        name = "removecurse_channel",
        tags = {"busy","channel"},
        onenter = function(inst, data)
            inst.AnimState:PlayAnimation("channel_loop",true)

            inst.SoundEmitter:PlaySound("monkeyisland/monkeyqueen/channel_magic_lp","channel")
        end,

        onexit = function(inst)
            inst.SoundEmitter:KillSound("channel")
        end
    },

    State{
        name = "removecurse_success",
        tags = {"busy"},
        onenter = function(inst, data)
            inst.AnimState:PlayAnimation("curse_success")
            inst.SoundEmitter:PlaySound("monkeyisland/monkeyqueen/remove_curse_success")
        end,

        timeline =
        {
            TimeEvent(15 * FRAMES, function(inst)
                inst.sg:RemoveStateTag("busy")
            end),
        },

        events =
        {
            EventHandler("animover", function(inst) 
                inst.sg:GoToState("idle")
            end)
        },
    },

    State{
        name = "removecurse_fail",
        tags = {"busy"},
        onenter = function(inst, data)
            inst.AnimState:PlayAnimation("curse_fail")
            inst.SoundEmitter:PlaySound("monkeyisland/monkeyqueen/remove_curse_fail")
        end,

        timeline =
        {
            TimeEvent(15 * FRAMES, function(inst)
                inst.sg:RemoveStateTag("busy")
            end),
        },

        events =
        {
            EventHandler("animover", function(inst) 
                inst.sg:GoToState("idle")
            end)
        },
    },    

    State{
        name = "sleep",
        tags = {"sleeping"},
        onenter = function(inst,data)
            inst.AnimState:PlayAnimation("sleep_pre")
            inst.SoundEmitter:PlaySound("monkeyisland/monkeyqueen/sleep_pre")
        end,

        events = 
        {
            EventHandler("animover", function(inst) 
                inst.sg:GoToState("sleeping")
            end)
        },
    },

    State{
        name = "sleeping",
        tags = {"sleeping"},
        onenter = function(inst,data)
            inst.AnimState:PlayAnimation("sleep_loop")
            inst.SoundEmitter:PlaySound("monkeyisland/monkeyqueen/sleep_lp","sleep_lp")
            
        end,

        onexit = function(inst,data)
            if not inst.sg.statemem.keeploopsnd == true then
                inst.SoundEmitter:KillSound("sleep_lp")
            end
        end,

        events = 
        {
            EventHandler("animover", function(inst) 
                inst.sg.statemem.keeploopsnd = true
                inst.sg:GoToState("sleeping")
            end)
        },
    },

    State{
        name = "wake",
        tags = {"waking"},
        onenter = function(inst,data)
            inst.AnimState:PlayAnimation("sleep_pst")
            inst.SoundEmitter:PlaySound("monkeyisland/monkeyqueen/sleep_post")
        end,

        events = 
        {
            EventHandler("animover", function(inst)
                inst.components.talker:Say(STRINGS["MONKEY_QUEEN_WAKE"][math.random(1,#STRINGS["MONKEY_QUEEN_WAKE"])])
                inst.sg:GoToState("idle")
            end)
        },
    },        

    State{
        name = "refuse",
        tags = {"busy"},
        onenter = function(inst,data)
            inst.AnimState:PlayAnimation("unimpressed")
            inst.SoundEmitter:PlaySound("monkeyisland/monkeyqueen/unimpressed")
        end,

        events = 
        {
            EventHandler("animover", function(inst) 
                inst.sg:GoToState("idle")
            end)
        },
    },    
}

return StateGraph("monkeyqueen", states, events, "idle")