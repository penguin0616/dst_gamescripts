local Widget = require "widgets/widget"
local Image = require "widgets/image"
local ImageButton = require "widgets/imagebutton"
local Text = require "widgets/text"
local ThreeSlice = require "widgets/threeslice"

local CraftingMenuIngredients = require "widgets/redux/craftingmenu_ingredients"

require "widgets/widgetutil"

local PinSlot = Class(Widget, function(self, owner, craftingmenu, slot_num, pin_data)
    Widget._ctor(self, "PinSlot")
    self.owner = owner
	self.craftingmenu = craftingmenu
	self.slot_num = slot_num

	self.FindPinUp = nil		-- must be implemented by the owner
	self.FindPinDown = nil		-- must be implemented by the owner

	if pin_data ~= nil then
		self.recipe_name = pin_data.recipe_name
		self.skin_name = pin_data.skin_name
	end

	self.base_scale = 0.6

	self:SetScale(self.base_scale)

	local atlas = resolvefilepath(CRAFTING_ATLAS)

	----------------
	self.craft_button = self:AddChild(ImageButton(atlas, "pinslot_bg.tex"))
	self.craft_button.AllowOnControlWhenSelected = true
    self.craft_button.ongainfocusfn = function() 
		self.craft_button.recipe_held = false
		self.craft_button.last_recipe_click = nil
	end
	self.craft_button:SetWhileDown(function()
		if self.craft_button.recipe_held then
			local recipe_data = self.craftingmenu:GetRecipeState(self.recipe_name) 
			DoRecipeClick(self.owner, recipe_data.recipe, self.skin_name)
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
				return

			elseif self.recipe_name ~= nil then
				local recipe_name, skin_name = self.craftingmenu:GetCurrentRecipeName()
				if recipe_name ~= self.recipe_name or self.skin_name ~= skin_name then
					self.craftingmenu:PopulateRecipeDetailPanel(self.recipe_name, self.skin_name)

					local data = self.craftingmenu:GetRecipeState(self.recipe_name) 
					local details_recipe_name, details_skin_name = self.craftingmenu:GetCurrentRecipeName()
					self.craft_button:SetHelpTextMessage(details_recipe_name ~= self.recipe_name and STRINGS.UI.HUD.SELECT
															or (data ~= nil and data.meta.build_state == "buffered") and STRINGS.UI.HUD.DEPLOY 
															or STRINGS.UI.HUD.BUILD)

					self.craft_button.last_recipe_click = GetTime()
					self.craft_button.recipe_held = false
					return
				end
			else
				local recipe_name, skin_name = self.craftingmenu:GetCurrentRecipeName()
				if recipe_name ~= nil then
					self:SetRecipe(recipe_name, skin_name)
					TheCraftingMenuProfile:SetPinnedRecipe(self.slot_num, recipe_name, skin_name)
				end
				return
			end
		end		

		local recipe_data = self.craftingmenu:GetRecipeState(self.recipe_name) 
		if recipe_data ~= nil then
			if not self.craft_button.recipe_held then
				local stay_open, error_msg = DoRecipeClick(self.owner, recipe_data.recipe, self.skin_name) 
				if not stay_open then
					self.owner:PushEvent("refreshcrafting") -- this is only really neede for free crafting
					self.owner.HUD:CloseCrafting()
				end
				if error_msg and not TheNet:IsServerPaused() then
					SendRPCToServer(RPC.CannotBuild, error_msg)
				end
			end

			if recipe_data.recipe.placer == nil then
				self.craft_button.last_recipe_click = GetTime()
			end
			self.craft_button.recipe_held = false
		end
	end)
	self.craft_button.onselect = function()
	    if self.craft_button.focus_scale then
			self.craft_button.image:SetScale(self.craft_button.focus_scale[1], self.craft_button.focus_scale[2], self.craft_button.focus_scale[3])
        end
	end
	self.craft_button.OnControl = function(_self, control, down)
		if ImageButton.OnControl(_self, control, down) then return true end

		if self.focus and down and not _self.down then
			if control == CONTROL_MENU_MISC_1 then
				if TheInput:ControllerAttached() and self.owner.HUD:IsCraftingOpen() then
					if down and not _self.down then
						self:SetRecipe(nil, nil)
						TheCraftingMenuProfile:SetPinnedRecipe(self.slot_num, nil, nil)
						TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_move")
						return true
					end
				end
			end
		end
	end

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

	local r_size = 400
	self.unpin_controllerhint = self.craft_button.image:AddChild(Text(UIFONT, 32/self.base_scale))
	self.unpin_controllerhint:SetPosition(r_size/2 + 58, 0)
	self.unpin_controllerhint:SetHAlign(ANCHOR_LEFT)
	self.unpin_controllerhint:SetRegionSize(r_size, 32/self.base_scale)
	self.unpin_controllerhint:Hide()


	----------------
	self.recipe_popup = self:AddChild(self:MakeRecipePopup())
	self.recipe_popup:Hide()
	self.recipe_popup:MoveToBack()

	----------------
    self.item_img = self.craft_button.image:AddChild(Image("images/global.xml", "square.tex"))
    self.fg = self.craft_button.image:AddChild(Image("images/global.xml", "square.tex"))
	self.fg:SetScale(0.92)
	self.fg:Hide()

	----------------
	self:Hide()
end)

function PinSlot:Highlight() -- called from inventorybar
	if not self.focus then
		self:SetFocus()
	end
end

function PinSlot:DeHighlight()
	self:ClearFocus()
end

function PinSlot:MakeRecipePopup()
	local atlas = resolvefilepath(CRAFTING_ATLAS)

	local root = Widget("RecipePopupRoot")

	root.max_ingredients_wide = 5
	root._scale = 1.15 / self.base_scale
	root.ShowPopup = function(popup_self, recipe)
		if recipe ~= nil then
			popup_self:Show()
			popup_self.ingredients:SetRecipe(recipe)

		    popup_self.background:ManualFlow(math.min(root.max_ingredients_wide, popup_self.ingredients.num_items), true)

			local x = popup_self.background.startcap:GetPositionXYZ()
			popup_self:SetPosition(x *popup_self._scale + 37/self.base_scale, 0)

			local end_x = popup_self.background.startcap:GetPositionXYZ()
			popup_self.openhint:SetPosition(x *popup_self._scale * 0.5 + 14, 0)
		else
			popup_self:Hide()
		end
	end

	root.HidePopup = function(popup_self)
		popup_self:Hide()
	end

	root.background = root:AddChild(ThreeSlice(atlas, "popup_end.tex", "popup_short.tex"))
	root.ingredients = root:AddChild(CraftingMenuIngredients(self.owner, root.max_ingredients_wide))

	root.openhint = root:AddChild(Text(UIFONT, 32))

	root:SetScale(root._scale)

	return root
end

function PinSlot:HasRecipe()
	return self.recipe_name ~= nil
end

function PinSlot:SetRecipe(recipe_name, skin_name)
	self.recipe_name = recipe_name
	self.skin_name = skin_name

	self:Refresh()
	self:OnGainFocus()
end

function PinSlot:Refresh()
	local data = self.craftingmenu:GetRecipeState(self.recipe_name) 

	local item_size = 80

	local atlas = resolvefilepath(CRAFTING_ATLAS)

	if data ~= nil and data.recipe ~= nil and data.meta ~= nil then
		local recipe = data.recipe
		local meta = data.meta

		if self.recipe_popup:IsVisible() then
			self.recipe_popup:ShowPopup(recipe)
		end

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
			self.craft_button:SetTextures(atlas, "pinslot_bg_buffered.tex", nil, nil, nil, "pinslot_bg_buffered.tex")
			self.fg:Hide()
		elseif meta.build_state == "prototype" then
			self.craft_button:SetTextures(atlas, "pinslot_bg_prototype.tex", nil, nil, nil, "pinslot_bg_prototype.tex")
			self.fg:SetTexture(atlas, "pinslot_fg_prototype.tex")
			self.fg:Show()
		elseif meta.can_build then
			self.craft_button:SetTextures(atlas, "pinslot_bg.tex", nil, nil, nil, "pinslot_bg.tex")
			self.fg:Hide()
		elseif meta.build_state == "hint" then
			self.craft_button:SetTextures(atlas, "pinslot_bg_missing_mats.tex", nil, nil, nil, "pinslot_bg_missing_mats.tex")
			self.item_img:SetTint(0.7, 0.7, 0.7, 1)
			self.fg:SetTexture(atlas, "pinslot_fg_lock.tex")
            self.fg:Show()
		elseif meta.build_state == "no_ingredients" then
			self.craft_button:SetTextures(atlas, "pinslot_bg_missing_mats.tex", nil, nil, nil, "pinslot_bg_missing_mats.tex")
			self.item_img:SetTint(0.7, 0.7, 0.7, 1)
            self.fg:Hide()
		else
			self.craft_button:SetTextures(atlas, "pinslot_bg_missing_mats.tex", nil, nil, nil, "pinslot_bg_missing_mats.tex")
			self.item_img:SetTint(0.7, 0.7, 0.7, 1)
			self.fg:SetTexture(atlas, "pinslot_fg_lock.tex")
            self.fg:Show()
		end

		local details_recipe_name, details_skin_name = self.craftingmenu:GetCurrentRecipeName()
		self.craft_button:SetHelpTextMessage(details_recipe_name ~= self.recipe_name and STRINGS.UI.HUD.SELECT
											 or meta.build_state == "buffered" and STRINGS.UI.HUD.DEPLOY 
											 or STRINGS.UI.HUD.BUILD)

		self:Show()
	else
		self.craft_button:SetTextures(atlas, "pinslot_bg_missing_mats.tex", nil, nil, nil, "pinslot_bg_missing_mats.tex")
        self.fg:Hide()
		self.item_img:SetTexture(atlas, "pinslot_fg_pin.tex")
		self.item_img:ScaleToSize(item_size, item_size)

		self.craft_button:SetHelpTextMessage(STRINGS.UI.HUD.CRAFTING_PIN)
	end
	
end

function PinSlot:OnGainFocus()
    PinSlot._base.OnGainFocus(self)
    
	if self.owner.HUD:IsCraftingOpen() then
		if TheInput:ControllerAttached() then
			self.unpin_button_bg:Show()
			self.unpin_controllerhint:Show()
			if self.recipe_name ~= nil then
				self.unpin_controllerhint:SetString(TheInput:GetLocalizedControl(TheInput:GetControllerID(), CONTROL_MENU_MISC_1) .. " " .. STRINGS.UI.HUD.CRAFTING_UNPIN)
			else
				self.unpin_controllerhint:SetString(TheInput:GetLocalizedControl(TheInput:GetControllerID(), CONTROL_ACCEPT) .. " " .. STRINGS.UI.HUD.CRAFTING_PIN)
			end

			local data = self.craftingmenu:GetRecipeState(self.recipe_name) 
			local details_recipe_name, details_skin_name = self.craftingmenu:GetCurrentRecipeName()
			self.craft_button:SetHelpTextMessage(details_recipe_name ~= self.recipe_name and STRINGS.UI.HUD.SELECT
													or (data ~= nil and data.meta.build_state == "buffered") and STRINGS.UI.HUD.DEPLOY 
													or STRINGS.UI.HUD.BUILD)
		else
			self.unpin_controllerhint:Hide()

			if self.recipe_name ~= nil then
				self.unpin_button_bg:Show()
				self.unpin_button:Show()
			else
				self.unpin_button_bg:Hide()
				self.unpin_button:Hide()
			end
		end
	else
		self:ShowRecipe()
	end
end

function PinSlot:OnLoseFocus()
    PinSlot._base.OnLoseFocus(self)

	self.unpin_button:Hide()
	self.unpin_button_bg:Hide()
	self.unpin_controllerhint:Hide()

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

function PinSlot:RefreshControllers(controller_mode)
	if controller_mode then
		if self.owner.HUD:IsCraftingOpen() then
			self.craft_button:SetControl(CONTROL_ACCEPT)
			--self.craft_button:SetHelpTextMessage(self.recipe_name ~= nil and STRINGS.UI.HUD.SELECT or STRINGS.UI.HUD.CRAFTING_PIN)

			self.recipe_popup.openhint:Hide()
			self.unpin_button:Hide()
			if self.focus then
				self.unpin_button_bg:Show()
				self.unpin_controllerhint:Show()
			end
			if self.recipe_name ~= nil then
				self.unpin_controllerhint:SetString(TheInput:GetLocalizedControl(TheInput:GetControllerID(), CONTROL_MENU_MISC_1) .. " " .. STRINGS.UI.HUD.CRAFTING_UNPIN)
			else
				self.unpin_controllerhint:SetString(TheInput:GetLocalizedControl(TheInput:GetControllerID(), CONTROL_ACCEPT) .. " " .. STRINGS.UI.HUD.CRAFTING_PIN)
			end
		else
			self.craft_button:SetControl(CONTROL_INVENTORY_USEONSCENE)

			self.recipe_popup.openhint:Show()
			self.recipe_popup.openhint:SetString(TheInput:GetLocalizedControl(TheInput:GetControllerID(), CONTROL_INVENTORY_USEONSCENE))
			self.unpin_controllerhint:Hide()
		end
    else
		self.craft_button:SetControl(CONTROL_PRIMARY)
        self.recipe_popup.openhint:Hide()

		if self.owner.HUD:IsCraftingOpen() then
			if self.recipe_name ~= nil and self.focus then
				self.unpin_button_bg:Show()
				self.unpin_button:Show()
			end
			self.unpin_controllerhint:Hide()
		end
	end
end

function PinSlot:OnCraftingMenuOpen()
	local controller = TheInput:ControllerAttached()
	self:RefreshControllers(controller)
	self:Show()

	if self.focus and controller and self.recipe_name ~= nil then
		self.craftingmenu:PopulateRecipeDetailPanel(self.recipe_name, self.skin_name)
	end
end

function PinSlot:OnCraftingMenuClose()
	self:RefreshControllers(TheInput:ControllerAttached())
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
	self.craft_button:Select()

	if self.recipe_name ~= nil and self.recipe_popup ~= nil then
		local recipe_data = self.craftingmenu:GetRecipeState(self.recipe_name) 
		if recipe_data ~= nil then
			self.recipe_popup:ShowPopup(recipe_data.recipe)
		end
	end
end

function PinSlot:HideRecipe()
	self.craft_button:ClearFocus()
	self.craft_button:Unselect() -- clearning focus so that unselect doesn't end up reselecting the button

    if self.recipe_popup then
        self.recipe_popup:HidePopup()
    end
end

return PinSlot