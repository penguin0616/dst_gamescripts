local function onactive(self, active)
    if active then
        self.inst:AddTag("cursed_inventory_item")
    else
        self.inst:RemoveTag("cursed_inventory_item")
    end
end

local Curseditem = Class(function(self, inst)
    self.inst = inst
    self.active = true
    self.cursed_target = nil
    self.target = nil

    self.inst:ListenForEvent("onpickup", function(item,data)
            self:Given(item, data)
        end)

    self.inst:ListenForEvent("entitysleep", function() self.inst:StopUpdatingComponent(self) end)
    self.inst:ListenForEvent("entitywake", function() self.inst:StartUpdatingComponent(self) end)

    self.inst:StartUpdatingComponent(self)
end,
nil,
{
    active = onactive,
})

function Curseditem:lookforplayer() 
    if self.inst.findplayertask then
        self.inst.findplayertask:Cancel()
        self.inst.findplayertask = nil
    end

    self.inst.findplayertask = self.inst:DoPeriodicTask(1,function()
        local x,y,z = self.inst.Transform:GetWorldPosition()
        local player = FindClosestPlayerInRangeSq(x,y,z,10*10,true)
        if player and player.components.cursable and player.components.cursable:IsCursable(self.inst) then
            if self.inst.findplayertask then
                self.inst.findplayertask:Cancel()
                self.inst.findplayertask = nil
            end

            self.target = player
            self.starttime = GetTime()
            self.startpos = Vector3(self.inst.Transform:GetWorldPosition())
        end
    end)
end

function Curseditem:CheckForOwner()
    if self.cursed_target.components.health and self.cursed_target.components.health:IsDead() then
        self.inst:RemoveTag("applied_curse")
        self.cursed_target = nil
    end
    if self.cursed_target then        
        if not self.inst:HasTag("INLIMBO") or 
            (self.inst.components.inventoryitem.owner and self.inst.components.inventoryitem.owner ~= self.cursed_target) then
            self.cursed_target.components.cursable:ForceOntoOwner(self.inst)
        end
    end
end

local ATTACHDIST = 2

function Curseditem:OnUpdate(dt)

    if self.cursed_target then
        self:CheckForOwner()
        if self.cursed_target then
            return
        end
    end
    if self.target and self.target:IsValid() and (not self.target.components.health or not self.target.components.health:IsDead()) and self.target.components.cursable and self.target.components.cursable:IsCursable(self.inst) then
        local dist = self.inst:GetDistanceSqToInst(self.target)
        if dist < ATTACHDIST*ATTACHDIST then
            self.target.components.cursable:ForceOntoOwner(self.inst)
        else
            local x,y,z = self.target.Transform:GetWorldPosition()
            local angle = self.inst:GetAngleToPoint(x, y, z)*DEGREES
            local dist =  math.sqrt(dist)
            local speed = math.min(Remap( dist ,0,10,20,1)*dt, dist )
            if speed <= 0 then
                self.target = nil
                if not self.inst.findplayertask then
                    self:lookforplayer()
                end
            else
                local offset = Vector3(speed * math.cos( angle ), 0, -speed * math.sin( angle ))
                local x1,y1,z1 = self.inst.Transform:GetWorldPosition()
                self.inst.Transform:SetPosition(x1+offset.x,0,z1+offset.z)

                if self.inst.components.floater:ShouldShowEffect() then
                    self.inst.components.floater:OnLandedServer()
                else
                    self.inst.components.floater:OnNoLongerLandedServer()
                end
            end
        end
    else
        self.target = nil
        if not self.inst.findplayertask then
            self.inst.findplayertask = self.inst:DoTaskInTime(1,function()
                if not self.inst:HasTag("INLIMBO") then
                    self:lookforplayer()
                end
            end)
        end
    end
end

function Curseditem:Given(item, data) 
    self.target = nil
    if data.owner and data.owner.components.cursable then
        if not self.inst:HasTag("applied_curse") then
            data.owner.components.cursable:ApplyCurse(self.inst)
        else 
            if not data.skipspeech then
                data.owner:DoTaskInTime(0.5,function()
                    if self.inst ~= data.owner.components.inventory.activeitem then
                        data.owner.components.talker:Say(GetString(data.owner, "ANNOUNCE_CANT_ESCAPE_CURSE"))
                    end
                end)
            end
        end
    end
end
--[[
function Curseditem:SetCursefn(fn)
    self.cursefn = fn
end

function Curseditem:SetRemovecursefn(fn)
    self.removecursefn = fn
end

function Curseditem:PerformCurse(data)
    if data.owner and data.owner.components.cursable then
        data.owner.components.cursable:ApplyCurse(self.inst)
        self.cursed_target = data.owner
    end
end


function Curseditem:RemoveCurse(player)
    print("+++ RemoveCurse",player,self.cursed_target)

    if data.owner and data.owner.components.cursable then
        data.owner.components.cursable:RemoveCurse(self.inst)
    end

end
]]
return Curseditem