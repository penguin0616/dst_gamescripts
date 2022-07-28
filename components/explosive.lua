local Explosive = Class(function(self,inst)
    self.inst = inst
    self.explosiverange = 3
    self.explosivedamage = 200
    self.buildingdamage = 10
    self.lightonexplode = true
    self.onexplodefn = nil
end)

function Explosive:SetOnExplodeFn(fn)
    self.onexplodefn = fn
end

local BURNT_CANT_TAGS = { "INLIMBO" }
function Explosive:OnBurnt()
	if not self.skip_camera_flash then
		for i, v in ipairs(AllPlayers) do
			local distSq = v:GetDistanceSqToInst(self.inst)
			local k = math.max(0, math.min(1, distSq / 400))
			local intensity = k * 0.75 * (k - 2) + 0.75 --easing.outQuad(k, 1, -1, 1)
			if intensity > 0 then
				v:ScreenFlash(intensity)
				v:ShakeCamera(CAMERASHAKE.FULL, .7, .02, intensity / 2)
			end
		end
	end

    if self.onexplodefn ~= nil then
        self.onexplodefn(self.inst)
    end

    local stacksize = self.inst.components.stackable ~= nil and self.inst.components.stackable:StackSize() or 1
    local totaldamage = self.explosivedamage * stacksize

    local x, y, z = self.inst.Transform:GetWorldPosition()

    local world = TheWorld
    if world.components.dockmanager ~= nil then
        world.components.dockmanager:DamageDockAtPoint(x, y, z, totaldamage)
    end

    local workablecount = TUNING.EXPLOSIVE_MAX_WORKABLE_INVENTORYITEMS
    local ents = TheSim:FindEntities(x, y, z, self.explosiverange, nil, BURNT_CANT_TAGS)
    for i, v in ipairs(ents) do
        if v ~= self.inst and v:IsValid() and not v:IsInLimbo() then
            if v.components.workable ~= nil and v.components.workable:CanBeWorked() then
                -- NOTES(JBK): Stackable inventory items can be placed down 1 by 1 making this a convenience to players to not have to drop them down 1 by 1 first for maximum potential output.
                local workdamage = self.buildingdamage * stacksize
                local dowork = true
                if v.components.inventoryitem ~= nil then
                    if workablecount > 0 then
                        workablecount = workablecount - 1
                        workdamage = workdamage * (v.components.stackable ~= nil and v.components.stackable:StackSize() or 1)
                    else
                        dowork = false
                    end
                end
                if dowork then
                    v.components.workable:WorkedBy(self.inst, workdamage)
                end
            end

            --Recheck valid after work
            if v:IsValid() and not v:IsInLimbo() then
                if self.lightonexplode and
                    v.components.fueled == nil and
                    v.components.burnable ~= nil and
                    not v.components.burnable:IsBurning() and
                    not v:HasTag("burnt") then
                    v.components.burnable:Ignite()
                end

                if v.components.combat ~= nil and not (v.components.health ~= nil and v.components.health:IsDead()) then
                    local dmg = totaldamage
                    if v.components.explosiveresist ~= nil then
                        dmg = dmg * (1 - v.components.explosiveresist:GetResistance())
                        v.components.explosiveresist:OnExplosiveDamage(dmg, self.inst)
                    end
                    v.components.combat:GetAttacked(self.inst, dmg, nil)
                end

                v:PushEvent("explosion", { explosive = self.inst })
            end
        end
    end

    for i = 1, stacksize do
        world:PushEvent("explosion", { damage = self.explosivedamage })
    end

    if self.inst.components.health ~= nil then
        -- NOTES(JBK): Make sure to keep the events fired up to date with the health component.
        world:PushEvent("entity_death", { inst = self.inst, explosive = true, })
        self.inst:PushEvent("death")
    end

    self.inst:Remove()
end

return Explosive
