--------------------------------------------------------------------------
--[[ crabkingspawner class definition ]]
--------------------------------------------------------------------------

return Class(function(self, inst)

assert(TheWorld.ismastersim, "CrabkingSpawner should not exist on client")

--------------------------------------------------------------------------
--[[ Constants ]]
--------------------------------------------------------------------------

local INITIAL_SPAWN_TIME = 10

--------------------------------------------------------------------------
--[[ Member variables ]]
--------------------------------------------------------------------------

--Public
self.inst = inst

local _crabkinglocation = nil
local _respawntask = nil

--------------------------------------------------------------------------
--[[ Private member functions ]]
--------------------------------------------------------------------------

local function StopRespawnTimer()
    if _respawntask ~= nil then
        _respawntask:Cancel()
        _respawntask = nil
    end
end

local function OnRespawnTimer()
    _respawntask = nil

    if _crabkinglocation ~= nil then
        if not TheWorld.Map:GetPlatformAtPoint(_crabkinglocation.x, _crabkinglocation.z) then
            local king = SpawnPrefab("crabking")
            king.Transform:SetPosition(_crabkinglocation.x,0,_crabkinglocation.z)
            king.sg:GoToState("reappear")
        else
            _respawntask = inst:DoTaskInTime(10, OnRespawnTimer)
        end        
    end
end

local function StartRespawnTimer(t)
    StopRespawnTimer()
    _respawntask = inst:DoTaskInTime(t or TUNING.CRABKING_RESPAWN_TIME, OnRespawnTimer)
end

--------------------------------------------------------------------------
--[[ Private event handlers ]]
--------------------------------------------------------------------------

local function OnCrabKingKilled(inst,data)    
    _crabkinglocation = data.pt
    StartRespawnTimer()
end


--------------------------------------------------------------------------
--[[ Initialization ]]
--------------------------------------------------------------------------

--Initialize variables

--Register events
inst:ListenForEvent("crabkingkilled", OnCrabKingKilled)

--------------------------------------------------------------------------
--[[ Update ]]
--------------------------------------------------------------------------

function self:LongUpdate(dt)
    if _respawntask ~= nil then
        local t = GetTaskRemaining(_respawntask)
        if t > dt then
            StartRespawnTimer(t - dt)
        else
            StopRespawnTimer()
            OnRespawnTimer()
        end
    end
end

--------------------------------------------------------------------------
--[[ Save/Load ]]
--------------------------------------------------------------------------

function self:OnSave()
    local data = {}

    if _respawntask ~= nil then
       data.timetorespawn = math.ceil(GetTaskRemaining(_respawntask))
    end

    if _crabkinglocation ~= nil then
       data.crabkingx = _crabkinglocation.x
       data.crabkingz = _crabkinglocation.z
    end

    return data   
end

function self:OnLoad(data)
    if data.timetorespawn ~= nil then
        StartRespawnTimer(data.timetorespawn)
    else
        StopRespawnTimer()
    end
    if data.crabkingx and data.crabkingz then
        _crabkinglocation = Vector3(data.crabkingx,0,data.crabkingz)
    end
end

--------------------------------------------------------------------------
--[[ Debug ]]
--------------------------------------------------------------------------

function self:GetDebugString()
    return string.format(
        "Crabking Cooldown: %.2f",
        _respawntask ~= nil and GetTaskRemaining(_respawntask) or 0
    )
end

--------------------------------------------------------------------------
--[[ End ]]
--------------------------------------------------------------------------

end)
