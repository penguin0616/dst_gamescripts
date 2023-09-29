local DEFAULT_SCALE = 2
local DEFAULT_HEIGHT = -130

local function Createpoi(self, data)
    local inst = CreateEntity("poi")
    --[[Non-networked entity]]
    inst.entity:AddTransform()
    inst.entity:AddAnimState()

    inst:AddTag("CLASSIFIED")
    inst:AddTag("NOCLICK")
    inst:AddTag("FX")

    inst.AnimState:SetBank("poi_marker")
    inst.AnimState:SetBuild("poi_marker")
    inst.AnimState:PlayAnimation("idle")

    inst.Transform:SetScale(DEFAULT_SCALE,DEFAULT_SCALE,DEFAULT_SCALE)

    inst.persists = false

    return inst
end

local function CreaterRing(self, data)
    local inst = CreateEntity("poi_ring")
    --[[Non-networked entity]]
    inst.entity:AddTransform()
    inst.entity:AddAnimState()

    inst:AddTag("CLASSIFIED")
    inst:AddTag("NOCLICK")
    inst:AddTag("FX")

    inst.AnimState:SetBank("poi_marker")
    inst.AnimState:SetBuild("poi_marker")
    inst.AnimState:PlayAnimation("ring")

    inst.Transform:SetScale(DEFAULT_SCALE,DEFAULT_SCALE,DEFAULT_SCALE)

    inst.persists = false

    return inst
end

local function Createstand(self)
    local inst = CreateEntity("poi_stand")
    --[[Non-networked entity]]
    inst.entity:AddTransform()    
    inst.entity:AddAnimState()

    inst:AddTag("CLASSIFIED")
    inst:AddTag("NOCLICK")
    inst:AddTag("FX")

    inst.AnimState:SetBank("poi_stand") 
    inst.AnimState:SetBuild("flint")  -- This didn't work without a build..just needed any build to work.
    inst.AnimState:PlayAnimation("idle")

    inst.persists = false

    return inst
end

local Pointofinterest = Class(function(self, inst)
	self.inst = inst
	self.indicator = nil
	self.inst:DoTaskInTime(0, function() self.inst:StartUpdatingComponent(self) end)   
end)

function Pointofinterest:RemoveHudIndicator()
    if ThePlayer ~= nil and ThePlayer.HUD ~= nil then
    	self.indicator = nil
        ThePlayer.HUD:RemoveTargetIndicator(self.inst)
    end
end

function Pointofinterest:AddPrefabIndicator()
    if not self.stand and not self.trigger_end then
        self.stand = Createstand(self)
        self.inst:AddChild(self.stand)

        self.marker = Createpoi(self)
        self.marker.entity:AddFollower()
        self.marker.Follower:FollowSymbol(self.stand.GUID, "marker", 0,self.height and self.height + DEFAULT_HEIGHT or DEFAULT_HEIGHT,0)
    end
end

function Pointofinterest:TriggerPulse()
    if self.marker then
        TheFocalPoint.SoundEmitter:PlaySound("dontstarve/HUD/poi_register")
        self.marker.AnimState:PlayAnimation("dark")
        self.trigger_end = true
        self.marker.scale = 1
        self.marker.target = 0.7
        self.loops = 0
    end             
end

function Pointofinterest:SetArt(img,atlas)
	self.img = img
	self.atlas = atlas
end

function Pointofinterest:SetHeight(height)
    self.height =  height
end

function Pointofinterest:TriggerEnd()
    self:RemoveHudIndicator(self.inst)
    self:TriggerPulse()
end

function Pointofinterest:RemoveEverything()
    self.trigger_end = false
    if self.ring1 then
        self.ring1:Remove()
        self.ring1 = nil
    end

    if self.ring2 then
        self.ring2:Remove()
        self.ring2 = nil
    end    
    
    if self.marker then
        self.marker:Remove()
        self.marker = nil
    end

    if self.stand then
        self.stand:Remove()
        self.stand = nil
    end        
end

function Pointofinterest:OnUpdate(dt)
	if ThePlayer ~= nil and (not self.testfn or self.testfn(self.inst)) then
        local fx, fy, fz = self.inst.Transform:GetWorldPosition()
        local px, py, pz = ThePlayer.Transform:GetWorldPosition()
        local sq_dist = distsq(fx, fz, px, pz)        

        if not TheScrapbookPartitions:WasInspectedByCharacter(self.inst, ThePlayer.prefab) then
            if ThePlayer.HUD ~= nil then
                self:AddPrefabIndicator()
                
                if (sq_dist < TUNING.MIN_INDICATOR_RANGE*TUNING.MIN_INDICATOR_RANGE or sq_dist > TUNING.MAX_INDICATOR_RANGE*TUNING.MAX_INDICATOR_RANGE) then
                	if self.indicator then
                    	self:RemoveHudIndicator()
                    end                    
                else
                	if not self.indicator then
    	            	self.indicator = true
    	                ThePlayer.HUD:AddTargetIndicator(self.inst, {image = "poi_question.tex", atlas= "images/avatars.xml"})
    	                self.inst:ListenForEvent("onremove", function() self:RemoveHudIndicator() end)	               
                	end
                end
            end
        else
            if not self.trigger_end then
                self:TriggerEnd()
            end
        end
    end

    if self.trigger_end == true and self.marker then

        if self.ring1 then
            self.ring1.scale = self.ring1.scale + (1.05 *dt)
            self.ring1.alpha = self.ring1.alpha - (2 *dt)
            if self.ring1.scale > 2 then
                self.ring1:Remove()
                self.ring1 = nil
            else
                self.ring1.Transform:SetScale(self.ring1.scale * DEFAULT_SCALE,self.ring1.scale * DEFAULT_SCALE,self.ring1.scale * DEFAULT_SCALE)
                self.ring1.AnimState:SetMultColour(1,1,1,self.ring1.alpha)
            end
        end 

        if self.ring2 then
            self.ring2.scale = self.ring2.scale + (1.05 *dt)
            self.ring2.alpha = self.ring2.alpha - (2 *dt)
            if self.ring2.scale > 2 then
                self.ring2:Remove()
                self.ring2 = nil
            else
                self.ring2.Transform:SetScale(self.ring2.scale * DEFAULT_SCALE,self.ring2.scale * DEFAULT_SCALE,self.ring2.scale * DEFAULT_SCALE)
                self.ring2.AnimState:SetMultColour(1,1,1,self.ring2.alpha)
            end
        end                 

        if self.marker then
            if self.marker.target then
                self.marker.scale = self.marker.scale - (0.75 *dt)
                self.marker.Transform:SetScale(self.marker.scale * DEFAULT_SCALE,self.marker.scale * DEFAULT_SCALE,self.marker.scale * DEFAULT_SCALE)

                if self.marker.scale < self.marker.target then
                    self.loops = self.loops + 1
                    if self.loops == 1 then
                        self.marker.scale = 1.3
                        self.marker.target = 1

                        self.ring1 = CreaterRing()
                        self.ring1.entity:AddFollower()
                        self.ring1.Follower:FollowSymbol(self.stand.GUID, "marker", 0,self.height and self.height + DEFAULT_HEIGHT or DEFAULT_HEIGHT,0)
                        self.ring1.scale = 1
                        self.ring1.alpha = 1
                    elseif self.loops == 2 then
                        self.marker.scale = 1
                        self.marker.target = 0.7
                        self.ring2 = CreaterRing()
                        self.ring2.entity:AddFollower()
                        self.ring2.Follower:FollowSymbol(self.stand.GUID, "marker", 0,self.height and self.height + DEFAULT_HEIGHT or DEFAULT_HEIGHT,0)
                        self.ring2.scale = 1
                        self.ring2.alpha = 1
                    else
                        self:RemoveEverything()
                    end
                end
            end
        end        
    end

end

return Pointofinterest