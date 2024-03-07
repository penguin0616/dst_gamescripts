require "behaviours/standstill"

---------------------------------------------------------------------------------------------------

-- Table shared by all storage robots.
-- Keeping this for mods / people spawning more of them.
local ignorethese = { --[[ [item] = worker ]] }

local StorageRobotBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

function StorageRobotBrain:IgnoreItem(item)
    self:UnignoreItem()

    self._targetitem = item

    ignorethese[item] = self.inst
end

function StorageRobotBrain:UnignoreItem()
    if self._targetitem and ignorethese[self._targetitem] then
        ignorethese[self._targetitem] = nil
    end
end

function StorageRobotBrain:ShouldIgnoreItem(item)
    return ignorethese[item] ~= nil and ignorethese[item] ~= self.inst
end

---------------------------------------------------------------------------------------------------

local CONTAINER_MUST_TAGS = { "_container" }
local CONTAINER_CANT_TAGS = { "FX", "NOCLICK", "DECOR", "INLIMBO" }

local function FindContainerWithItem(inst, item, count)
    count = count or 0
    local x, y, z = inst:GetSpawnPoint():Get()

    local stack_maxsize = item.components.stackable ~= nil and item.components.stackable.maxsize or 1

    local ents = TheSim:FindEntities(x, y, z, TUNING.STORAGE_ROBOT_WORK_RADIUS, CONTAINER_MUST_TAGS, CONTAINER_CANT_TAGS)

    for i, ent in ipairs(ents) do
        if ent.components.container ~= nil and
            ent.components.container:Has(item.prefab, 1) and
            ent.components.container:CanAcceptCount(item, stack_maxsize) > count and
            ent:IsOnPassablePoint() and
            ent:GetCurrentPlatform() == inst:GetCurrentPlatform()
        then
            return ent
        end
    end

    return
end

---------------------------------------------------------------------------------------------------

local function FindPickupableItem_filter(inst, item, onlytheseprefabs)
    -- Ignore ourself and other storage robots.
    if item:HasTag("storagerobot") then
        return false
    end

    if not (item.components.inventoryitem ~= nil and
        item.components.inventoryitem.canbepickedup and
        item.components.inventoryitem.cangoincontainer and
        not item.components.inventoryitem:IsHeld())
    then
        return false
    end

    if not item:IsOnPassablePoint() or item:GetCurrentPlatform() ~= inst:GetCurrentPlatform() then
        return false
    end

    if inst.brain:ShouldIgnoreItem(item) then
        return false
    end

    if onlytheseprefabs ~= nil and onlytheseprefabs[item.prefab] == nil then
        return false
    end

    if item.components.bait ~= nil and item.components.bait.trap ~= nil then -- Do not steal baits.
        return false
    end

    if item.components.trap ~= nil and not (item.components.trap:IsSprung() and item.components.trap:HasLoot()) then -- Only interact with traps that have something in it to take.
        return false
    end

    -- Checks how many of this item we have.
    local _, count = inst.components.inventory:Has(item.prefab, 1)

    if not FindContainerWithItem(inst, item, count) then
        return false
    end

    return item
end

local PICKUP_MUST_TAGS =
{
    "_inventoryitem"
}

local PICKUP_CANT_TAGS =
{
    "INLIMBO", "NOCLICK", "irreplaceable", "knockbackdelayinteraction",
    "event_trigger", "mineactive", "catchable", "fire", "spider", "cursed",
    "heavy", "outofreach",
}

local function FindPickupableItem(inst, onlytheseprefabs)
    local x, y, z    = inst.Transform:GetWorldPosition()
    local sx, xy, sz = inst:GetSpawnPoint():Get()

    local ents = TheSim:FindEntities(x, y, z, TUNING.STORAGE_ROBOT_WORK_RADIUS, PICKUP_MUST_TAGS, PICKUP_CANT_TAGS)

    for i, ent in ipairs(ents) do
        if ent:GetDistanceSqToPoint(sx, xy, sz) <= TUNING.STORAGE_ROBOT_WORK_RADIUS * TUNING.STORAGE_ROBOT_WORK_RADIUS and
            FindPickupableItem_filter(inst, ent, onlytheseprefabs)
        then
            return ent
        end
    end

    return
end

local function PickUpAction(inst)
    local activeitem = inst.components.inventory:GetActiveItem()

    if activeitem ~= nil then
        inst.components.inventory:DropItem(activeitem, true, true)
    end

    ----------------

    local onlytheseprefabs

    local item = inst.components.inventory:GetFirstItemInAnySlot()

    if item ~= nil then
        if (item.components.stackable == nil or item.components.stackable:IsFull()) then
            return
        end

        onlytheseprefabs = {[item.prefab] = true}
    end

    ----------------

    local item = FindPickupableItem(inst, onlytheseprefabs)

    if item == nil then
        return
    end

    inst.brain:IgnoreItem(item)

    return BufferedAction(inst, item, item.components.trap ~= nil and ACTIONS.CHECKTRAP or ACTIONS.PICKUP, nil, nil, nil, nil, nil, nil, 0)
end

---------------------------------------------------------------------------------------------------

local function StoreItemAction(inst)
    local item = inst.components.inventory:GetFirstItemInAnySlot() or inst.components.inventory:GetActiveItem() -- This is intentionally backwards to give the bigger stacks first.

    if item == nil then
        return nil
    end

    inst.brain:UnignoreItem()

    local container = FindContainerWithItem(inst, item)

    return container ~= nil and BufferedAction(inst, container, ACTIONS.STORE, item) or nil
end

---------------------------------------------------------------------------------------------------

local function GoHomeAction(inst)
    local pos = inst:GetSpawnPoint()

    if pos == nil then
        return
    end

    inst.brain:UnignoreItem()

    local item = inst.components.inventory:GetFirstItemInAnySlot() or inst.components.inventory:GetActiveItem() -- This is intentionally backwards to give the bigger stacks first.

    if item ~= nil then
        inst.components.inventory:DropItem(item, true, true)
    end

    return BufferedAction(inst, nil, ACTIONS.WALKTO, nil, pos, nil, 0.2)
end

---------------------------------------------------------------------------------------------------

function StorageRobotBrain:OnStart()
    self.PickUpAction = PickUpAction
    self.StoreItemAction  = StoreItemAction
    self.GoHomeAction = GoHomeAction

    local root = PriorityNode(
    {
        WhileNode( function() return not self.inst.sg:HasAnyStateTag("busy", "broken") end, "NO BRAIN WHEN BUSY OR BROKEN",
            PriorityNode({
                DoAction( self.inst, self.PickUpAction,     "Pick Up Item",    true, 3 ),
                DoAction( self.inst, self.StoreItemAction,  "Store Item",      true, 3 ),
                DoAction( self.inst, self.GoHomeAction,     "Return to spawn", true, 3 ),
                StandStill(self.inst),
            }, .25)
        ),
    }, .25)

    self.bt = BT(self.inst, root)
end

function StorageRobotBrain:OnInitializationComplete()
    self.inst:UpdateSpawnPoint(true)
end

return StorageRobotBrain
