--------------------------------------------------------------------------
--[[ wagpunk_floor_helper class definition ]]
--------------------------------------------------------------------------

return Class(function(self, inst)
local _world = TheWorld
local _map = _world.Map

self.inst = inst

self.barrier_active = net_bool(self.inst.GUID, "wagpunk_floor_helper.barrier_active")
self.arena_active = net_bool(self.inst.GUID, "wagpunk_floor_helper.arena_active")
self.arena_origin_x = net_float(self.inst.GUID, "wagpunk_floor_helper.arena_origin_x") -- Could probably be a ushort if arenas are tile aligned only.
self.arena_origin_z = net_float(self.inst.GUID, "wagpunk_floor_helper.arena_origin_z")
self.barrier_active:set(false)
self.arena_active:set(false)
self.arena_origin_x:set(0)
self.arena_origin_z:set(0)

local scale = TILE_SCALE
local SIZE_WIDE = 7 * scale
local SIZE_SQUARE = 6 * scale
local SIZE_SKINNY = 5 * scale

-- Common.

function self:IsPointInArena(x, y, z)
    if not self.arena_active:value() then
        return false
    end

    -- NOTES(JBK): This arena is a very square circle.
    -- The size is fixed and tied to the shape of hermitcrab_01 static layout.
    -- We can check if any point is in the arena by checking a total of three rectangles.
    local ax, az = self.arena_origin_x:value(), self.arena_origin_z:value()
    local dx, dz = ax - x, az - z
    -- The first rectangle is the horizontal wide.
    if dx >= -SIZE_WIDE and dx <= SIZE_WIDE then
        if dz >= -SIZE_SKINNY and dz <= SIZE_SKINNY then
            return true
        end
    end
    -- Then the vertical tall.
    if dx >= -SIZE_SKINNY and dx <= SIZE_SKINNY then
        if dz >= -SIZE_WIDE and dz <= SIZE_WIDE then
            return true
        end
    end
    -- Finally the square center.
    if dx >= -SIZE_SQUARE and dx <= SIZE_SQUARE then
        if dz >= -SIZE_SQUARE and dz <= SIZE_SQUARE then
            return true
        end
    end

    return false
end

function self:GetArenaOrigin()
    if not self.arena_active:value() then
        return nil, nil
    end

    return self.arena_origin_x:value(), self.arena_origin_z:value()
end

function self:IsBarrierUp()
    return self.barrier_active:value()
end

-- Server.

self.OnRemove_Marker = function(ent, data)
    self.marker = nil
    self.arena_active:set(false)
    self.arena_origin_x:set(0)
    self.arena_origin_z:set(0)
end

function self:TryToSetMarker(inst)
    if self.marker then
        inst:Remove()
        return
    end

    self.marker = inst
    local x, y, z = self.marker.Transform:GetWorldPosition()
    self.arena_active:set(true)
    self.arena_origin_x:set(x)
    self.arena_origin_z:set(z)
    inst:ListenForEvent("onremove", self.OnRemove_Marker)
end

end)