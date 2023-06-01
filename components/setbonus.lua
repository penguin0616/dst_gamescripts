local function EnableBonusForEquip(equip)
    local setbonus = equip.components.setbonus

    if setbonus ~= nil and setbonus.enabled == false then
        --print(string.format('>> Enabling set bonus ["%s"] for equipment ["%s"]...', setbonus.setname, equip.prefab))
        setbonus.enabled = true
        if setbonus.onenabledfn ~= nil then
            setbonus.onenabledfn(equip)
        end
    end
end

local function DisableBonusForEquip(equip)
    local setbonus = equip.components.setbonus

    if setbonus ~= nil and setbonus.enabled == true then
        --print(string.format('<< Disabling set bonus ["%s"] for equipment ["%s"]...', setbonus.setname, equip.prefab))
        setbonus.enabled = false
        if setbonus.ondisabledfn ~= nil then
            setbonus.ondisabledfn(equip)
        end
    end
end

local SetBonus = Class(function(self, inst)
    self.inst = inst

    self.setname = ""

    self.enabled = false

    self.onenabledfn = nil
    self.ondisabledfn = nil

    self.EnableBonusForEquip  = EnableBonusForEquip  -- Mods
    self.DisableBonusForEquip = DisableBonusForEquip -- Mods
end)

function SetBonus:SetSetName(name)
    assert(EQUIPMENTSETNAMES[string.upper(name)] ~= nil, string.format('The set bonus name "%s" isn\'t defined in EQUIPMENTSETNAMES in constants.lua', name))
    self.setname = name
end

function SetBonus:SetOnEnabledFn(fn)
    self.onenabledfn = fn
end

function SetBonus:SetOnDisabledFn(fn)
    self.ondisabledfn = fn
end

function SetBonus:_HasSetBonus(inventory)
    local head, body = inventory.equipslots[EQUIPSLOTS.HEAD], inventory.equipslots[EQUIPSLOTS.BODY]
    
    if head == nil or body == nil then
        return false
    end

    if head.components.setbonus == nil or body.components.setbonus == nil then
        return false
    end

    return head.components.setbonus.setname == body.components.setbonus.setname
end

-- Called by inventory:Equip() and inventory:Unequip()
function SetBonus:UpdateSetBonus(inventory)
    if inventory ~= nil then
        local has_setbonus = self:_HasSetBonus(inventory)
        inventory:ForEachEquipment(has_setbonus and self.EnableBonusForEquip or self.DisableBonusForEquip)

        -- self.inst isn't in inventory.equipslots anymore.
        if not has_setbonus then
            self.DisableBonusForEquip(self.inst)
        end
    end
end

function SetBonus:IsEnabled()
    return self.enabled == true
end

function SetBonus:OnRemoveFromEntity()
    if self:IsEnabled() then 
        self.DisableBonusForEquip(self.inst)

        if self.inst.components.inventoryitem ~= nil and
            self.inst.components.inventoryitem.owner ~= nil and
            self.inst.components.inventoryitem.owner.components.inventory ~= nil
        then
            self:UpdateSetBonus(self.inst.components.inventoryitem.owner.components.inventory)
        end
    end
end

function SetBonus:GetDebugString()
    return string.format(
        "Set Name: %s  -  Bonus: %s",
        self.setname,
        self.enabled and "Enabled" or "Disabled"
    )
end

return SetBonus
