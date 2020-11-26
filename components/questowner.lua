local function onquesting(self, questing)
    if questing then
        self.inst:AddTag("questing")
    else
        self.inst:RemoveTag("questing")
    end
end

local QuestOwner = Class(function(self, inst)
    self.inst = inst
    self.on_begin_quest = nil
    self.on_abandon_quest = nil
    self.questing = false

    --self.CanBeginFn = nil
    --self.CanAbandonFn = nil
end,
nil,
{
    questing = onquesting,
})

function QuestOwner:SetOnBeginQuest(on_begin_quest)
    self.on_begin_quest = on_begin_quest
end

function QuestOwner:SetOnAbandonQuest(on_abandon_quest)
    self.on_abandon_quest = on_abandon_quest
end

function QuestOwner:OnRemoveFromEntity()
    self.inst:RemoveTag("questing")
end

function QuestOwner:CanBeginQuest(doer)
    return self.CanBeginFn == nil or self.CanBeginFn(self.inst, doer)
end

function QuestOwner:BeginQuest(doer)
    local begin_message = nil
    if self.on_begin_quest ~= nil then
        self.questing, begin_message = self.on_begin_quest(self.inst, doer)
    end
    return self.questing, begin_message
end

function QuestOwner:CanAbandonQuest(doer)
    return self.CanAbandonFn == nil or self.CanAbandonFn(self.inst, doer)
end

function QuestOwner:AbandonQuest(doer)
    if self.on_abandon_quest ~= nil then
        local quest_abandoned, abandon_message = self.on_abandon_quest(self.inst, doer)
        if quest_abandoned then
            self.questing = false
        end
        return quest_abandoned, abandon_message
    end
    return nil
end

function QuestOwner:OnSave()
    local data =
    {
        questing = self.questing,
    }

    return data
end

function QuestOwner:OnLoad(data)
    if data ~= nil then
        self.questing = data.questing or false
    end
end

return QuestOwner
