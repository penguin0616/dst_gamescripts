return Class(function(self, inst)

--------------------------------------------------------------------------
--[[ Member variables ]]
--------------------------------------------------------------------------

--Public
self.inst = inst

-- Private
local _world = TheWorld
local _ismastersim = _world.ismastersim
local _ismastershard = _world.ismastershard
local _wagboss_defeated = false

local function on_wagboss_defeated()
    _wagboss_defeated = true
    _world:PushEvent("master_wagbossinfoupdate", {isdefeated = true})
end

function self:IsWagbossDefeated()
    return _wagboss_defeated
end

function self:OnSave()
    return {
        wagboss_defeated = _wagboss_defeated,
    }
end

function self:OnLoad(data)
    if data then
        _wagboss_defeated = data.wagboss_defeated
        _world:PushEvent("master_wagbossinfoupdate", {isdefeated = true})
    end
end

--------------------------------------------------------------------------
--[[ Initialization ]]
--------------------------------------------------------------------------

inst:ListenForEvent("wagboss_defeated", on_wagboss_defeated)

end)