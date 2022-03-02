local Widget = require "widgets/widget"
local Image = require "widgets/image"
local ImageButton = require "widgets/imagebutton"
local RecipeTile = require "widgets/recipetile"
local RecipePopup = require "widgets/recipepopup"

require "widgets/widgetutil"

local PinSlot = Class(Widget, function(self, owner, craftingmenu, slot_num, pin_data)
    Widget._ctor(self, "PinSlot")
    self.owner = owner
	self.craftingmenu = craftingmenu
	self.slot_num = slot_num

	if pin_data ~= nil then
		self.recipe_name = pin_data.recipe_name
		self.skin_name = pin_data.skin_name
	end

	self:SetScale(0.6)

	local atlas = resolvefilepath(CRAFTING_ATLAS)

	----------------
	self.craft_button = self:AddChild(ImageButton(atlas, "pinslot_bg.tex"))
	self.craft_button:SetWhileDown(function()
		if not self.owner.HUD:IsCraftingOpen() then	
			if self.craft_button.recipe_held then
				local recipe_data = self.craftingmenu:GetRecipeState(self.recipe_name) 
				DoRecipeClick(self.owner, recipe_data.recipe, self.skin_name)
			end
		end
	end)
	self.craft_button:SetOnDown(function()
		if self.craft_button.last_recipe_click and (GetTime() - self.craft_button.last_recipe_click) < 1 then
			self.craft_button.recipe_held = true
			self.craft_button.last_recipe_click = nil
		end
	end)
	self.craft_button:SetOnClick(function()
		if self.owner.HUD:IsCraftingOpen() then
			if self.unpin_button.focus then
				self:SetRecipe(nil, nil)
				TheCraftingMenuProfile:SetPinnedRecipe(self.slot_num, nil, nil)

			elseif self.recipe_name ~= nil then
				self.craftingmenu:PopulateRecipeDetailPanel(self.recipe_name, self.skin_name)

			else
				local recipe_name, skin_name = self.craftingmenu:GetCurrentRecipeName()
				if recipe_name ~= nil then
					self:SetRecipe(recipe_name, skin_name)
					TheCraftingMenuProfile:SetPinnedRecipe(self.slot_num, recipe_name, skin_name)
				end
			end
		else
			self.craft_button.last_recipe_click = GetTime()
			if not self.craft_button.recipe_held then
				local recipe_data = self.craftingmenu:GetRecipeState(self.recipe_name) 
				if recipe_data ~= nil and not DoRecipeClick(self.owner, recipe_data.recipe, self.skin_name) then
					self.owner.HUD:CloseCrafting()
				end
			end
			self.craft_button.recipe_held = false
		end
	end)

	self.focus_forward = self.craft_button

	----------------
	self.unpin_button_bg = self.craft_button.image:AddChild(Image(atlas, "pinslot_unpin_backing.tex"))
	self.unpin_button_bg:SetPosition(64 + 8, 0)
	self.unpin_button_bg:Hide()
	self.unpin_button_bg:MoveToBack()

	----------------
	self.unpin_button = self.craft_button.image:AddChild(ImageButton(atlas, "pinslot_unpin_button.tex"))	-- this is a fake button, all the real work is done via self.craft_button
	self.unpin_button:SetPosition(64 + 12, 0)
	self.unpin_button:SetScale(0.7)
	self.unpin_button:Hide()

	----------------
	self.bg = self.craft_button
    self.item_img = self.bg.image:AddChild(Image("images/global.xml", "square.tex"))
    self.fg = self.bg.image:AddChild(Image("images/global.xml", "square.tex"))
	self.fg:SetScale(0.92)
	self.fg:Hide()

	self:Hide()
end)

function PinSlot:HasRecipe()
	return self.recipe_name ~= nil
end

function PinSlot:SetRecipe(recipe_name, skin_name)
	self.recipe_name = recipe_name
	self.skin_name = skin_name

	self:Refresh()
	if self.focus then
		self:OnGainFocus()
	end
end

function PinSlot:Refresh()
	local data = self.craftingmenu:GetRecipeState(self.recipe_name) 

	local item_size = 80

	local atlas = resolvefilepath(CRAFTING_ATLAS)

	if data ~= nil and data.recipe ~= nil and data.meta ~= nil then
		local recipe = data.recipe
		local meta = data.meta

		local inv_image
		if self.skin_name ~= nil then
			inv_image = GetSkinInvIconName(self.skin_name)..".tex"
		else
			inv_image = recipe.imagefn ~= nil and recipe.imagefn() or recipe.image
		end
		local inv_atlas = GetInventoryItemAtlas(inv_image)

		self.item_img:SetTexture(inv_atlas, inv_image or "default.tex", "default.tex")
		self.item_img:ScaleToSize(item_size, item_size)
		self.item_img:SetTint(1, 1, 1, 1)

		if meta.build_state == "buffered" then
			self.bg:SetTextures(atlas, "pinslot_bg_buffered.tex")
			self.fg:Hide()
		elseif meta.build_state == "prototype" then
			self.bg:SetTextures(atlas, "pinslot_bg_prototype.tex")
			self.fg:SetTexture(atlas, "pinslot_fg_prototype.tex")
			self.fg:Show()
		elseif meta.can_build then
			self.bg:SetTextures(atlas, "pinslot_bg.tex")
			self.fg:Hide()
		elseif meta.build_state == "hint" then
			self.bg:SetTextures(atlas, "pinslot_bg_missing_mats.tex")
			self.item_img:SetTint(0.7, 0.7, 0.7, 1)
			self.fg:SetTexture(atlas, "pinslot_fg_lock.tex")
            self.fg:Show()
		elseif meta.build_state == "no_ingredients" then
			self.bg:SetTextures(atlas, "pinslot_bg_missing_mats.tex")
			self.item_img:SetTint(0.7, 0.7, 0.7, 1)
            self.fg:Hide()
		else
			self.bg:SetTextures(atlas, "pinslot_bg_missing_mats.tex")
			self.item_img:SetTint(0.7, 0.7, 0.7, 1)
			self.fg:SetTexture(atlas, "pinslot_fg_lock.tex")
            self.fg:Show()
		end

		self:Show()
	else
		self.bg:SetTextures(atlas, "pinslot_bg_missing_mats.tex")
        self.fg:Hide()
		self.item_img:SetTexture(atlas, "pinslot_fg_pin.tex")
		self.item_img:ScaleToSize(item_size, item_size)
	end
	
end

function PinSlot:OnGainFocus()
    PinSlot._base.OnGainFocus(self)
    
	if self.owner.HUD:IsCraftingOpen() then
		if self.recipe_name ~= nil then
			self.unpin_button:Show()
			self.unpin_button_bg:Show()
		else
			self.unpin_button:Hide()
			self.unpin_button_bg:Hide()
		end
	else
		self:ShowRecipe()
	end
end

function PinSlot:OnLoseFocus()
    PinSlot._base.OnLoseFocus(self)

	self.unpin_button:Hide()
	self.unpin_button_bg:Hide()

    self:StopUpdating()
    
	self:HideRecipe()
end

function PinSlot:OnControl(control, down)
    if PinSlot._base.OnControl(self, control, down) then return true end

end

function PinSlot:OnUpdate(dt)
    if self.down and self.recipe_held then
		local recipe_data = self.craftingmenu:GetRecipeState(self.recipe_name)
		if recipe_data ~= nil then
	        DoRecipeClick(self.owner, recipe_data, self.skin_name)
		end
    end
end

function PinSlot:OnCraftingMenuOpen()
	self:Show()
	if self.recipe_name ~= nil then
		--self.unpin_button:Show()
	end
end

function PinSlot:OnCraftingMenuClose()
	if self.recipe_name == nil then
		self:Hide()
	end
end

function PinSlot:Open()
	--self:Hide()
end

function PinSlot:Close()
	--self:Show()
end

function PinSlot:ShowRecipe()
--    if self.recipe and self.recipepopup then
--        self.recipepopup:Show()
--        self.recipepopup:SetRecipe(self.recipe, self.owner)
--    end
end

function PinSlot:HideRecipe()
--    if self.recipepopup then
--        self.recipepopup:Hide()
--    end
end

return PinSlot