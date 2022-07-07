-- inst in this context is the cursed object

local function canchange(owner)
    if owner.sg:HasStateTag("nomorph") then
        return false
    end

    if owner.sg:HasStateTag("busy") then
        return false
    end

    if owner.sg:HasStateTag("pinned") then
        return false
    end

    if owner:HasTag("weregoose") then
        return false
    end

    if owner:HasTag("weremoose") then
        return false
    end    
    
    if owner:HasTag("beaver") then
        return false
    end

    return true
end

local function uncurse(owner, num)

    local function hit(player)
        if not player.sg:HasStateTag("dead") then
            player.sg:GoToState("hit_spike","med")
            local fx = SpawnPrefab("monkey_de_morphin_fx")
            player:AddChild(fx)
        end
    end

    if owner:HasTag("wonkey") then
        if num <= 0 then
            --should be checking "nomorph"... but that probably isn't supported
            --correctly if a state change is forced here in this way.
            if not owner.sg:HasStateTag("dead") then
                owner.sg:GoToState("changefrommonkey")
            end
        else
            hit(owner)
        end
    else
        if not owner.components.timer or not owner.components.timer:TimerExists("monkeycursehit") then
            owner.components.timer:StartTimer("monkeycursehit", 1)
            hit(owner)
        end
        if num <= 0 then
            owner.monkeyfeet = nil
            owner.monkeyhands = nil
            owner.monkeytail = nil
            owner.components.skinner:ClearMonkeyCurse("MONKEY_CURSE_1")
            owner:RemoveTag("MONKEY_CURSE_1")
            owner:RemoveTag("MONKEY_CURSE_2")
            owner:RemoveTag("MONKEY_CURSE_3")
        elseif num <= 2 then
            owner.monkeyfeet = true
            owner.monkeyhands = nil
            owner.monkeytail = nil
            owner.components.skinner:SetMonkeyCurse("MONKEY_CURSE_1")
            owner:AddTag("MONKEY_CURSE_1")
            owner:RemoveTag("MONKEY_CURSE_2")
            owner:RemoveTag("MONKEY_CURSE_3")
        elseif num <=5 then
            owner.monkeyfeet = true
            owner.monkeyhands = true
            owner.monkeytail = nil
            owner.components.skinner:SetMonkeyCurse("MONKEY_CURSE_2")
            owner:RemoveTag("MONKEY_CURSE_1")
            owner:AddTag("MONKEY_CURSE_2")
            owner:RemoveTag("MONKEY_CURSE_3")
        else
            owner.monkeyfeet = true
            owner.monkeyhands = true
            owner.monkeytail = true
            owner.components.skinner:SetMonkeyCurse("MONKEY_CURSE_3")
            owner:RemoveTag("MONKEY_CURSE_1")
            owner:RemoveTag("MONKEY_CURSE_2")
            owner:AddTag("MONKEY_CURSE_3")
        end  
    end
end

local function docurse(owner, numitems)

    if owner then
        local fx = SpawnPrefab("monkey_morphin_power_players_fx")
        owner:AddChild(fx)
    end

    if numitems >= TUNING.MONKEY_TOKEN_COUNTS.LEVEL_4 and not owner:HasTag("wonkey") then
        if not owner.trycursetask then
            owner.trycursetask = owner:DoPeriodicTask(0.1, function()
                    if owner.components.rider ~= nil and owner.components.rider:IsRiding() then
                        owner.components.rider:Dismount()
                    elseif canchange(owner) then
                        if owner.trycursetask then
                            owner.trycursetask:Cancel()
                            owner.trycursetask = nil
                        end
                        owner.sg:GoToState("changetomonkey")
                    end
                end)
        end
    else
        if not owner.components.timer or not owner.components.timer:TimerExists("monkeycursehit") then
            owner.components.timer:StartTimer("monkeycursehit", 1)
            owner.sg:GoToState("hit")
        end
        if numitems > TUNING.MONKEY_TOKEN_COUNTS.LEVEL_1 and not owner.monkeyfeet then

            owner:DoTaskInTime(1, function() if owner.prefab ~= "wonkey"  then owner.components.talker:Say(GetString(owner, "ANNOUNCE_MONKEY_CURSE_1")) end end)
            owner.monkeyfeet = true
            owner.components.skinner:SetMonkeyCurse("MONKEY_CURSE_1")
            owner:AddTag("MONKEY_CURSE_1")
        end
        if numitems > TUNING.MONKEY_TOKEN_COUNTS.LEVEL_2 and not owner.monkeyhands then
            owner.monkeyhands = true
            owner.components.skinner:SetMonkeyCurse("MONKEY_CURSE_2")
            owner:RemoveTag("MONKEY_CURSE_1")
            owner:AddTag("MONKEY_CURSE_2")
        end
        if numitems > TUNING.MONKEY_TOKEN_COUNTS.LEVEL_3 and not owner.monkeytail then
            owner.monkeytail = true
            owner.components.skinner:SetMonkeyCurse("MONKEY_CURSE_3")
            owner:RemoveTag("MONKEY_CURSE_2")
            owner:AddTag("MONKEY_CURSE_3")
        end        
    end
end

return {
  docurse = docurse,
  uncurse = uncurse,
}