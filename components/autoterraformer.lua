local GroundTiles = require("worldtiledefs")

local AutoTerraformer = Class(function(self, inst)
    assert(inst.components.container ~= nil, "AutoTerraformer requires the Container component")
    self.inst = inst

    self.repeat_tile_delay = TUNING.AUTOTERRAFORMER_REPEAT_DELAY

    self.container = inst.components.container
end)

function AutoTerraformer:DoTerraform(px, py, pz, x, y)
    local map = TheWorld.Map

    local item_tile
    local item = self.container:GetItemInSlot(1)
    if item and item.tile then
        item_tile = item.tile
    end

    local original_tile_type = map:GetTile(x, y)
    if item_tile == original_tile_type then
        return
    end

    --place our turf if we can do that
    if item_tile ~= nil and map:CanPlaceTurfAtPoint(px, py, pz) then
        self.container:RemoveItem(item, false):Remove()
        map:SetTile(x, y, item_tile)
	    self.inst:PushEvent("onterraform")
        return
    end

	if not map:CanTerraformAtPoint(px, py, pz) then
        return
    end

    local underneath_tile = TheWorld.components.undertile:GetTileUnderneath(x, y)
    if underneath_tile then
        map:SetTile(x, y, underneath_tile)
    else
        if item_tile then
            self.container:RemoveItem(item, false):Remove()
        end
        map:SetTile(x, y, item_tile or WORLD_TILES.DIRT)
    end

    local spawnturf = GroundTiles.turf[original_tile_type] or nil
    if spawnturf ~= nil then
        local loot = SpawnPrefab("turf_"..spawnturf.name)
        if loot.components.inventoryitem ~= nil then
            loot.components.inventoryitem:InheritMoisture(TheWorld.state.wetness, TheWorld.state.iswet)
        end
        loot.Transform:SetPosition(px, py, pz)
        SpawnPrefab("sand_puff").Transform:SetPosition(px, py, pz)
        if loot.Physics ~= nil then
            local angle = math.random() * 2 * PI
            loot.Physics:SetVel(2 * math.cos(angle), 10, 2 * math.sin(angle))
        end
    else
        SpawnPrefab("sinkhole_spawn_fx_"..tostring(math.random(3))).Transform:SetPosition(px, py, pz)
    end

    for _, ent in ipairs(TheWorld.Map:GetEntitiesOnTileAtPoint(px, py, pz)) do
        if ent:HasTag("soil") then
            ent:PushEvent("collapsesoil")
        end
    end

	self.inst:PushEvent("onterraform")

    if self.inst.components.finiteuses then
        self.inst.components.finiteuses:Use()
    end

    return underneath_tile ~= nil
end

function AutoTerraformer:StartTerraforming()
    self.last_x, self.last_y, self.repeat_delay = nil, nil, nil
    self.inst:StartUpdatingComponent(self)
end

function AutoTerraformer:StopTerraforming()
    self.inst:StopUpdatingComponent(self)
end

function AutoTerraformer:OnUpdate(dt)
    local px, py, pz = self.inst.Transform:GetWorldPosition()
    local x, y = TheWorld.Map:GetTileXYAtPoint(px, py, pz)

    if self.repeat_delay ~= nil then
        self.repeat_delay = self.repeat_delay - dt
    end

    if (self.last_x == nil and self.last_y == nil) or
    (self.last_x ~= x or self.last_y ~= y) or
    (self.last_x == x and self.last_y == y and self.repeat_delay == 0) then
        self.repeat_delay = nil
        local repeat_tile = self:DoTerraform(px, py, pz, x, y)

        self.last_x, self.last_y = x, y
        if repeat_tile then
            self.repeat_delay = self.repeat_tile_delay
        end
    end
end

return AutoTerraformer
