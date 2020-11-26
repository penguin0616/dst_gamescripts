local function onplayeractivated(inst)
	local self = inst.components.cookbookupdater
	if not TheNet:IsDedicated() and inst == ThePlayer then
		self.cookbook = TheCookbook
		self.cookbook.save_enabled = true
	end
end

local CookbookUpdater = Class(function(self, inst)
    self.inst = inst

	self.cookbook = require("cookbookdata")()
	inst:ListenForEvent("playeractivated", onplayeractivated)
end)

function CookbookUpdater:LearnRecipe(product, ingredients)
	if product ~= nil and ingredients ~= nil then
		local updated = self.cookbook:AddRecipe(product, ingredients)
		--print("CookbookUpdater:LearnRecipe", product, updated, unppack(ingredients))

		-- Servers will only tell the clients if this is a new recipe in this world
		-- Since the servers do not know the client's actual cookbook data, this is the best we can do for reducing the amount of data sent
		if updated and (TheNet:IsDedicated() or (TheWorld.ismastersim and self.inst ~= ThePlayer)) then
			if self.inst.player_classified ~= nil then
				self.inst.player_classified.cookbook_product:set(product..":"..table.concat(ingredients, ","))
				-- TODO: Handle ingredients
			end
		end
	end
end

function CookbookUpdater:LearnFoodStats(product)
	local updated = self.cookbook:LearnFoodStats(product)
	--print("CookbookUpdater:LearnFoodStats", product, updated)

	-- Servers will only tell the clients if this is a new recipe in this world
	-- Since the servers do not know the client's actual cookbook data, this is the best we can do for reducing the amount of data sent
	if updated and (TheNet:IsDedicated() or (TheWorld.ismastersim and self.inst ~= ThePlayer)) then
		if self.inst.player_classified ~= nil then
			self.inst.player_classified.cookbook_learnstats:set(product)
		end
	end
end


return CookbookUpdater