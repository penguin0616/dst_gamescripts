
local Widget = require "widgets/widget"
local TileBG = require "widgets/tilebg"
local Image = require "widgets/image"
local ImageButton = require "widgets/imagebutton"
local UIAnim = require "widgets/uianim"
local Text = require "widgets/text"
local Grid = require "widgets/grid"

local PinSlot = require "widgets/redux/craftingmenu_pinslot"

local CraftingMenuPinBar = Class(Widget, function(self, owner, crafting_hud, height)
    Widget._ctor(self, "Crafting Menu Pin Bar")

	self.owner = owner
	self.crafing_hud = crafting_hud

	local atlas = resolvefilepath(CRAFTING_ATLAS)

	local tabs = {}
	
	self.root = self:AddChild(Widget("slot_root"))
	self.root:SetScale(0.73)
	self.root:SetPosition(30, 0)

	local y = 368
	local buttonsize = 64

	self.pin_open = self.root:AddChild(ImageButton(atlas, "crafting_tab.tex", "crafting_tab.tex", nil, nil, nil, {1,1}, {0,0}))
	self.pin_open.slot_num = 0
	self.pin_open:SetPosition(24, y)
	self.pin_open:SetScale(0.45)

	self.pin_open.glow = self.pin_open.image:AddChild(Image("images/global_redux.xml", "shop_glow.tex"))
	self.pin_open.glow:SetTint(.8, .8, .8, 0.4)
	self.pin_open.glow:Hide()
	self.pin_open.icon = self.pin_open.image:AddChild(Image(PROTOTYPER_DEFS.none.icon_atlas, PROTOTYPER_DEFS.none.icon_image))
	self.pin_open.icon:SetScale(0.75)
	self.pin_open.icon:SetPosition(-12, 0)
	self.pin_open.prototype = self.pin_open.image:AddChild(Image(atlas, "pinslot_fg_prototype.tex"))
	self.pin_open.prototype:SetScale(1.5)
	self.pin_open.prototype:SetPosition(-20, 0)
	self.pin_open.prototype:Hide()

	local function animate_glow(initial) 
		local len = 1
		if initial then 
			self.pin_open.glow:CancelTintTo()
			self.pin_open.glow:CancelRotateTo()
			self.pin_open.glow:CancelScaleTo()

			self.pin_open.glow:Show() 
			self.pin_open.glow:SetTint(.8, .8, .8, 0.4)

			self.pin_open.glow:SetScale(0)
			self.pin_open.glow:ScaleTo(0, 1.5, len/2, animate_glow) 

			local t = math.random() * 360
			self.pin_open.glow:RotateTo(t, t-360, len + 0.5)
		else 
			self.pin_open.glow:TintTo({ r=0.8, g=0.8, b=0.8, a=.4 }, { r=0.8, g=0.8, b=0.8, a=0 }, len/2, function() self.pin_open.glow:Hide() end)
		end
	end

	self.pin_open:SetOnClick(function()
		if self.owner.HUD:IsCraftingOpen() then
			self.owner.HUD:CloseCrafting()
		else
			self.owner.HUD:OpenCrafting()
		end
    end)
	self.pin_open.SetCraftingState = function(s, can_prototype, new_recipe_available)
		local animate = false
		if s.can_prototype ~= can_prototype then
			if can_prototype then
				s.prototype:Show()
				TheFocalPoint.SoundEmitter:PlaySound("dontstarve/HUD/research_available")
				animate = true
			else
				s.prototype:Hide()
			end
			s.can_prototype = can_prototype
		elseif new_recipe_available then
			TheFocalPoint.SoundEmitter:PlaySound("dontstarve/HUD/recipe_ready")
			animate = true
		end	

		if animate then
			animate_glow(true)
		end

	end

	y = y - 100

	self.pin_slots = {}

	local pinned_recipes = TheCraftingMenuProfile:GetPinnedRecipes()

	for i = 1, TUNING.MAX_PINNED_RECIPES do
		local pin_slot = self.root:AddChild(PinSlot(self.owner, crafting_hud, i, pinned_recipes[i]))
		pin_slot:SetPosition(0, y)
		table.insert(self.pin_slots, pin_slot)

		y = y - buttonsize - 16
	end

	self.focus_forward = self.pin_slots[1]
end)

function CraftingMenuPinBar:DoFocusHookups()
	local function OnFocusChangeUp(_pin)
		for i = _pin.slot_num - 1, 0, -1 do
			if i == 0 then
				return self.pin_open
			else
				if self.pin_slots[i]:IsVisible() then
					return self.pin_slots[i]
				end
			end
		end
	end
	local function OnFocusChangeDown(_pin)
		for i = _pin.slot_num + 1, TUNING.MAX_PINNED_RECIPES do
			if self.pin_slots[i]:IsVisible() then
				return self.pin_slots[i]
			end
		end
	end

	for _, pin_slot in pairs(self.pin_slots) do
		pin_slot:SetFocusChangeDir(MOVE_UP, OnFocusChangeUp)
		pin_slot:SetFocusChangeDir(MOVE_DOWN, OnFocusChangeDown)
	end

	self.pin_open:SetFocusChangeDir(MOVE_DOWN, OnFocusChangeDown)
end

function CraftingMenuPinBar:ClearFocusHookups()
	for _, pin_slot in pairs(self.pin_slots) do
		pin_slot:ClearFocusDirs()
	end

	self.pin_open:ClearFocusDirs()
end

function CraftingMenuPinBar:GetFirstButton()
	for i = 1, TUNING.MAX_PINNED_RECIPES do
		if self.pin_slots[i]:IsVisible() then
			return self.pin_slots[i]
		end
	end
end


function CraftingMenuPinBar:Refresh()
	local atlas = resolvefilepath(CRAFTING_ATLAS)

	local builder = self.owner ~= nil and self.owner.replica.builder or nil
	local prototyper = builder ~= nil and builder:GetCurrentPrototyper() or nil
	local prototyper_def = prototyper ~= nil and PROTOTYPER_DEFS[prototyper.prefab] or PROTOTYPER_DEFS.none
	self.pin_open.icon:SetTexture(prototyper_def.icon_atlas, prototyper_def.icon_image)

	for i, pin in ipairs(self.pin_slots) do
		pin:Refresh()
	end
end

function CraftingMenuPinBar:OnCraftingMenuOpen()
	for i, pin in ipairs(self.pin_slots) do
		pin:OnCraftingMenuOpen()
	end

	self:DoFocusHookups()
end

function CraftingMenuPinBar:OnCraftingMenuClose()
	for i, pin in ipairs(self.pin_slots) do
		pin:OnCraftingMenuClose()
	end

	self:ClearFocusHookups()
end


return CraftingMenuPinBar
