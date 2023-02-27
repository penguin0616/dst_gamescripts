local ExperienceCollecter = Class(function(self, inst)
    self.inst = inst

    self:SetTask()
end)

function ExperienceCollecter:SetTask()
    self.inst.xpgeneration_task = self.inst:DoPeriodicTask(TUNING.SEG_TIME, function() self:UpdateXp() end)
end

function ExperienceCollecter:UpdateXp()
    self.inst.components.skilltreeupdater:AddSkillXP(1)
end

function ExperienceCollecter:LongUpdate(dt)
    print("LONG UPDATE",dt,TUNING.SEG_TIME)
    local timeremaining = 0

    if self.inst.xpgeneration_task then
        timeremaining = GetTaskRemaining(self.inst.xpgeneration_task)
    end

    if dt < timeremaining then        
        timeremaining = timeremaining - dt
        print("timeremaining",timeremaining)
    else
        local cycles,remaining = math.modf(dt/TUNING.SEG_TIME)
        
        if cycles > 0 then
            for i=1,cycles do
                self:UpdateXp()
            end
        end

        if self.inst.xpgeneration_task then
            self.inst.xpgeneration_task.nexttick = data.time
        end

        timeremaining = remaining * TUNING.SEG_TIME
        print("timeremaining",timeremaining)
    end

    if not self.inst.xpgeneration_task then
        self:SetTask()
    end
    
    self.inst.xpgeneration_task.nexttick = GetTime() + timeremaining
end

function ExperienceCollecter:OnSave()
   return
   {
        time = GetTaskRemaining(self.inst.xpgeneration_task)
   }
end

function ExperienceCollecter:OnLoad(data)
   if data.time then
        if self.inst.xpgeneration_task then
            self.inst.xpgeneration_task.nexttick = GetTime() + data.time
        end
   end
end

return ExperienceCollecter