--------------------------------------------------------------------------
--[[ worldmeteorshower class definition ]]
--------------------------------------------------------------------------
local SourceModifierList = require("util/sourcemodifierlist")

return Class(function(self, inst)
self.inst = inst

assert(TheWorld.ismastersim, "worldmeteorshower should not exist on client")

self.moonrockshell_chance = 0
self.moonrockshell_chance_additionalodds = SourceModifierList(self.inst, 0, SourceModifierList.additive)

function self:GetMeteorLootPrefab(prefab)
	if prefab == "rock_moon" and self.moonrockshell_chance < 1 then
		self.moonrockshell_chance = self.moonrockshell_chance + TUNING.MOONROCKSHELL_CHANCE

        local odds = self.moonrockshell_chance + self.moonrockshell_chance_additionalodds:Get()

		if odds >= 1 or TheWorld.state.cycles >= 60 or math.random() <= odds then
			self.moonrockshell_chance = 1
			return "rock_moon_shell"
		end
	end
	return prefab
end

function self:SpawnMeteorLoot(prefab) -- NOTES(JBK): Deprecated kept for mods.
	return SpawnPrefab(self:GetMeteorLootPrefab(prefab))
end

--------------------------------------------------------------------------
--[[ Save/Load ]]
--------------------------------------------------------------------------

function self:OnSave()
    return
    {
        moonrockshell_chance = self.moonrockshell_chance,
    }
end

function self:OnLoad(data)
    self.moonrockshell_chance = data.moonrockshell_chance or 0
end

--------------------------------------------------------------------------
--[[ Debug ]]
--------------------------------------------------------------------------

--------------------------------------------------------------------------
--[[ End ]]
--------------------------------------------------------------------------

end)
