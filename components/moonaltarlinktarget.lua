local link_search_tags = { "moonaltarlinktarget" }

local function breaklink(inst)
    if inst.components.moonaltarlinktarget.link ~= nil then
        inst.components.moonaltarlinktarget.link.components.moonaltarlink:BreakLink()
    end
end

local MoonAltarLinkTarget = Class(function(self, inst)
    self.inst = inst
    self.link = nil
    self.link_radius = 20

    -- self.onlinkfn = nil
    -- self.onlinkbrokenfn = nil

    -- self.onfoundotheraltarfn = nil

    -- self.canbelinkedfn = nil

    self.inst:AddTag("moonaltarlinktarget")

    self.inst:ListenForEvent("onremove", breaklink)
end)

function MoonAltarLinkTarget:OnRemoveFromEntity()
    self.inst:RemoveTag("moonaltarlinktarget")

    self.inst:RemoveEventCallback("onremove", breaklink)
end

function MoonAltarLinkTarget:TryEstablishLink()
    local x, y, z = self.inst.Transform:GetWorldPosition()
    
    local ents = TheSim:FindEntities(x, y, z, self.link_radius, link_search_tags)
    
    local looking_for_altars = { moon_altar = true, moon_altar_cosmic = true, moon_altar_astral = true }
    looking_for_altars[self.inst.prefab] = nil

    local altars = { self.inst }
    local altars_found = 1
    
    for i, v in ipairs(ents) do
        if looking_for_altars[v.prefab] and v.components.moonaltarlinktarget:CanBeLinked() then
            local tx, _, tz = v.Transform:GetWorldPosition()
            if VecUtil_LengthSq(tx - x, tz - z) >= TUNING.MOON_ALTAR_LINK_ALTAR_MIN_RADIUS_SQ then
                table.insert(altars, v)
                looking_for_altars[v.prefab] = nil
                altars_found = altars_found + 1

                if self.onfoundotheraltarfn ~= nil then
                    self.onfoundotheraltarfn(self.inst, v)
                end

                if altars_found == 3 then
                    local other_altars = {}
                    for _, w in ipairs(altars) do
                        if w.prefab ~= self.inst.prefab then
                            table.insert(other_altars, w)
                        end
                    end

                    local other_altar1_x, _, other_altar1_z = other_altars[1].Transform:GetWorldPosition()
                    local other_altar2_x, _, other_altar2_z = other_altars[2].Transform:GetWorldPosition()
                    if VecUtil_LengthSq(other_altar1_x - other_altar2_x, other_altar1_z - other_altar2_z) < TUNING.MOON_ALTAR_LINK_ALTAR_MIN_RADIUS_SQ then
                        return
                    end
                    
                    if not self:AngleTest(other_altars[1], other_altars[2]) or not other_altars[1].components.moonaltarlinktarget:AngleTest(other_altars[2], self.inst) then
                        return
                    end

                    local cx, _, cz = 0, 0, 0
                    for _, altar in ipairs(altars) do
                        local altar_x, _, altar_z = altar.Transform:GetWorldPosition()
                        cx, cz = cx + altar_x, cz + altar_z
                    end
                    cx, cz = cx / 3, cz / 3

                    if TheWorld.Map:IsPassableAtPoint(cx, 0, cz, false, true)
                        and TheWorld.Map:IsAboveGroundAtPoint(cx, 0, cz, false) then
                        
                        local ents = TheSim:FindEntities(cx, 0, cz, 10) -- 10: at least the size of the largest deploy_extra_spacing
                        for _, v in ipairs(ents) do
                            local pt = Point(cx, 0, cz)

                            if (v:HasTag("antlion_sinkhole_blocker") and v:GetDistanceSqToPoint(pt) <= TUNING.MOON_ALTAR_LINK_POINT_VALID_RADIUS_SQ)
                                or (v.deploy_extra_spacing ~= nil and v:GetDistanceSqToPoint(pt) <= v.deploy_extra_spacing * v.deploy_extra_spacing) then
                                    
                                return
                            end
                        end

                        SpawnPrefab("moon_altar_link").components.moonaltarlink:EstablishLink(altars)
                    end

                    return
                end
            end
        end
    end
end

function MoonAltarLinkTarget:AngleTest(other_altar1, other_altar2)
    local x, _, z = self.inst.Transform:GetWorldPosition()
    local x1, _, z1 = other_altar1.Transform:GetWorldPosition()
    local x2, _, z2 = other_altar2.Transform:GetWorldPosition()

    local delta_normalized_this_to_other1_x, delta_normalized_this_to_other1_z = VecUtil_Normalize(x1 - x, z1 - z)
    local delta_normalized_this_to_other2_x, delta_normalized_this_to_other2_z = VecUtil_Normalize(x2 - x, z2 - z)
    local dot_this_to_other1_other2 = VecUtil_Dot(
        delta_normalized_this_to_other1_x, delta_normalized_this_to_other1_z,
        delta_normalized_this_to_other2_x, delta_normalized_this_to_other2_z)
        
    return math.abs(dot_this_to_other1_other2) <= TUNING.MOON_ALTAR_LINK_MAX_ABS_DOT
end

function MoonAltarLinkTarget:CanBeLinked()
    return self.canbelinkedfn == nil or self.canbelinkedfn(self.inst)
end

return MoonAltarLinkTarget
