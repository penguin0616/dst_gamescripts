local USE_SETTINGS_FILE = PLATFORM ~= "PS4" and PLATFORM ~= "NACL"

local cooking = require("cooking")

local CraftingMenuProfile = Class(function(self)
	self.favorites = {}
	self.favorites_ordered = {}

	self.pinned_recipes = {} -- Warning! this array may have holes in it, never use ipairs on this

	self:MakeDefaultPinnedRecipes()

	self.sort_mode = nil

	--self.new_recipes = {}

	self.save_enabled = true
end)

function CraftingMenuProfile:Save(force_save)
	if force_save or (self.save_enabled and self.dirty) then
		local str = json.encode({
			version = 1, 
			favorites = self.favorites,
			sort_mode = self.sort_mode,
		})
		TheSim:SetPersistentString("craftingmenuprofile", str, false)
		self.dirty = false
	end
end

function CraftingMenuProfile:Load()
	TheSim:GetPersistentString("craftingmenuprofile", function(load_success, data)
		if load_success and data ~= nil then
			local status, data = pcall( function() return json.decode(data) end )
		    if status and data then
				self.favorites = data.favorites or {}
				self.favorites_ordered = table.invert(self.favorites)

				if data.sort_mode ~= nil then
					self.sort_mode = tonumber(data.sort_mode)
				end
			else
				print("Faild to load the crafting menue profile!", status, data)
			end
		end
	end)
end

function CraftingMenuProfile:SetSortMode(mode)
	if self.sort_mode ~= mode then
		self.sort_mode = tonumber(mode)
		self.dirty = true
	end
end

function CraftingMenuProfile:GetSortMode()
	return self.sort_mode
end

function CraftingMenuProfile:GetFavorites()
	return self.favorites
end

function CraftingMenuProfile:GetFavoritesOrder()
	return self.favorites_ordered
end

function CraftingMenuProfile:IsFavorite(recipe_name)
	return self.favorites_ordered[recipe_name] ~= nil
end

function CraftingMenuProfile:AddFavorite(recipe_name)
	if not type(recipe_name) == "string" then
		print("[CraftingMenuProfile] Error: only strings can be added to recipe favorites.")
		return
	end

	if not self.favorites_ordered[recipe_name] then
		table.insert(self.favorites, recipe_name)
		self.favorites_ordered[recipe_name] = #self.favorites
		self.dirty = true
	end
end

function CraftingMenuProfile:RemoveFavorite(recipe_name)
	local cur_size = #self.favorites
	table.removearrayvalue(self.favorites, recipe_name)
	if cur_size ~= #self.favorites then
		self.favorites_ordered = table.invert(self.favorites)
		self.dirty = true
	end
end

function CraftingMenuProfile:SetPinnedRecipe(slot, recipe_name, skin_name)
	self.pinned_recipes[slot] = {recipe_name = recipe_name, skin_name = skin_name}
end

function CraftingMenuProfile:GetPinnedRecipes()
	return self.pinned_recipes
end

function CraftingMenuProfile:MakeDefaultPinnedRecipes()
	self.pinned_recipes = {}
	for _, v in pairs(TUNING.DEFAULT_PINNED_RECIPES) do
		--table.insert(self.pinned_recipes, {recipe_name = v, skin_name = Profile:GetLastUsedSkinForItem(v)}) -- this felt odd, I'll have to keep thinking about it some more...
		table.insert(self.pinned_recipes, {recipe_name = v})
	end
end

function CraftingMenuProfile:DeserializeLocalClientSessionData(data)
	self.pinned_recipes = {}
	if data ~= nil and type(data.pinned_recipes) == "table" then
		for k, v in pairs(data.pinned_recipes) do
			if type(v) == "table" then
				self.pinned_recipes[k] = {recipe_name = v.recipe_name, skin_name = v.skin_name}
			else
				self.pinned_recipes[k] = {recipe_name = v, skin_name = nil}
			end
		end
	end
end

function CraftingMenuProfile:SerializeLocalClientSessionData()
	return {pinned_recipes = self.pinned_recipes}
end

return CraftingMenuProfile
