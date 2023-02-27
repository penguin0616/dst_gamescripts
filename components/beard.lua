local function OnDayComplete(self)
    if not self.pause then
        self.daysgrowth = self.daysgrowth + 1
        local cb = self.callbacks[self.daysgrowth]
        if cb ~= nil then
            cb(self.inst, self.skinname)
        end
        self:UpdateBeardInventory()
    end
end

local function OnRespawn(inst)
    inst.components.beard:Reset()
end

local Beard = Class(function(self, inst)
    self.inst = inst

    --V2C: Recommended to explicitly add tag to prefab pristine state
    inst:AddTag("bearded")

    self.daysgrowth = 0
    self.callbacks = {}
    self.prize = nil
    self.bits = 0
    self.insulation_factor = 1
    self.pause = nil
    self.onreset = nil

    inst:ListenForEvent("ms_respawnedfromghost", OnRespawn)

    self.isgrowing = nil --force dirty for initial EnableGrowth call
    self:EnableGrowth(true)
end)

function Beard:OnRemoveFromEntity()
    self:EnableGrowth(false)
    self.inst:RemoveTag("bearded")
    self.inst:RemoveEventCallback("ms_respawnedfromghost", OnRespawn)
end

function Beard:EnableGrowth(enable)
    if enable then
        if not self.isgrowing then
            self.isgrowing = true
            self:WatchWorldState("cycles", OnDayComplete)
        end
    elseif self.isgrowing then
        self.isgrowing = nil
        self:StopWatchingWorldState("cycles", OnDayComplete)
    end
end

function Beard:GetInsulation()
    local skill_mod = 1

    if self.inst.components.skilltreeupdater:IsActivated("wilson_beard_3") then
        skill_mod = TUNING.SKILLS.WILSON_BEARD_3
    elseif self.inst.components.skilltreeupdater:IsActivated("wilson_beard_2") then
        skill_mod = TUNING.SKILLS.WILSON_BEARD_2
    elseif self.inst.components.skilltreeupdater:IsActivated("wilson_beard_1") then
        skill_mod = TUNING.SKILLS.WILSON_BEARD_1
    end

    return self.bits * TUNING.INSULATION_PER_BEARD_BIT * self.insulation_factor * skill_mod
end

function Beard:ShouldTryToShave(who, whithwhat)
    if self.bits == 0 then
        return false, "NOBITS"
    elseif self.canshavetest ~= nil then
        local pass, reason = self.canshavetest(self.inst, who)
        if not pass then
            return false, reason
        end
    end
    return true
end

function Beard:Shave(who, withwhat)
    if self.bits == 0 then
        return false, "NOBITS"
    elseif self.canshavetest ~= nil then
        local pass, reason = self.canshavetest(self.inst, who)
        if not pass then
            return false, reason
        end
    end

    if self.prize ~= nil then
        for k = 1 , self.bits do
            local bit = SpawnPrefab(self.prize)
            local x, y, z = self.inst.Transform:GetWorldPosition()
            bit.Transform:SetPosition(x, y + 2, z)
            local speed = 1 + math.random()
            local angle = math.random() * 2 * PI
            bit.Physics:SetVel(speed * math.cos(angle), 2 + math.random() * 3, speed * math.sin(angle))
        end
        self:Reset()
    end

    if who == self.inst and who.components.sanity ~= nil then
        who.components.sanity:DoDelta(TUNING.SANITY_SMALL)
    end

    self:UpdateBeardInventory()

    self.inst:PushEvent("shaved")

    return true
end

function Beard:AddCallback(day, cb)
    self.callbacks[day] = cb
end

-- THIS DATA NEEDS TO BE IN ASCENDING ORDER
function Beard:UpdateCallbackTimes(data)

    local ranks = {}
    for day,cb in pairs(self.callbacks) do
        table.insert(ranks, {day, cb})
    end
    
    table.sort(ranks, function (a, b) return a[1] < b[1] end)
    
    for i=1,#ranks do
        if ranks[i][1] >  self.daysgrowth and data[i] <= self.daysgrowth then  
            self.callbacks[ranks[i][1]](self.inst, self.skinname)
        end
        self.callbacks[data[i]] = ranks[i][2]
        self.callbacks[ranks[i][1]] = nil
    end
end

function Beard:Reset()
    self.daysgrowth = 0
    self.bits = 0
    if self.onreset ~= nil then
        self.onreset(self.inst)
    end
    self:UpdateBeardInventory()
end

function Beard:OnSave()
    return
    {
        growth = self.daysgrowth,
        bits = self.bits,
        skinname = self.skinname
    }
end

function Beard:OnLoad(data)
    -- because there is an unknowable delay between the day callback and actually
    -- growing more hair, we need to store how much hair we _actually_ had on quit
    -- to determing the current beefalo state.
    if data.bits ~= nil then
        self.bits = data.bits
    end
    if data.growth ~= nil then
        self.daysgrowth = data.growth
    end
    if data.skinname ~= nil then
        self.skinname = data.skinname
    end
    for k = 0, self.daysgrowth do
        local cb = self.callbacks[k]
        if cb ~= nil then
            cb(self.inst, self.skinname)
        end
    end        
end

function Beard:SetSkin(skinname)
    self.skinname = skinname
    for k = 0, self.daysgrowth do
        local cb = self.callbacks[k]
        if cb ~= nil then
            cb(self.inst, self.skinname)
        end
    end
end

function Beard:GetDebugString()
    local nextevent = math.huge
    for k, v in pairs(self.callbacks) do
        if k >= self.daysgrowth and k < nextevent then
            nextevent = k
        end
    end
    return string.format("Bits: %d Daysgrowth: %d Next Event: %d", self.bits, self.daysgrowth, nextevent)
end

--used for networking beard skins to client for oversized veggie pictures.
function Beard:GetBeardSkinAndLength()
    local length = 0
    for k = 0, self.daysgrowth do
        --assume that every callback equals 1 length, this works out nicely for webber and wilson, if this doesn't hold true, adjust this logic.
        if self.callbacks[k] then
            length = length + 1
        end
    end
    if length == 0 then return end --don't bother networking data that wont do anything
    return self.skinname, length
end

function Beard:UpdateBeardInventory()

    if self.inst.components.skilltreeupdater and self.inst.components.skilltreeupdater:IsActivated("wilson_beard_7") then
        local level = nil
        if self.bits >= TUNING.WILSON_BEARD_BITS.LEVEL3 then
            level = "beard_sack_3"
        elseif self.bits >= TUNING.WILSON_BEARD_BITS.LEVEL2 then
            level = "beard_sack_2"
        elseif self.bits >= TUNING.WILSON_BEARD_BITS.LEVEL1 then
            level = "beard_sack_1"
        end

        local beardsack = self.inst.components.inventory:GetEquippedItem(EQUIPSLOTS.BEARD)
        if not level and beardsack then
            beardsack.components.container:DropEverything()
            beardsack.components.equippable:SetPreventUnequipping(false)
            beardsack:Remove()
        end
        if level and not beardsack then
            local newsack = SpawnPrefab(level)
            self.inst.components.inventory:Equip(newsack)
        elseif level and not beardsack:HasTag(level) then
            local newsack = SpawnPrefab(level)
            for k,v in pairs(beardsack.components.container.slots) do
               beardsack.components.container:RemoveItem(v,true)
               newsack.components.container:GiveItem(v)
            end
            beardsack.components.equippable:SetPreventUnequipping(false)
            beardsack:Remove()
            self.inst.components.inventory:Equip(newsack)
        end
    end
end

return Beard
