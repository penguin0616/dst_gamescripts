
local TileBG = require "widgets/tilebg"
local Image = require "widgets/image"
local ImageButton = require "widgets/imagebutton"
local Widget = require "widgets/widget"
local UIAnim = require "widgets/uianim"
local Text = require "widgets/text"

local CraftingMenuWidget = require "widgets/redux/craftingmenu_widget"
local CraftingMenuPinBar = require "widgets/redux/craftingmenu_pinbar"

local HEIGHT = 600

local CraftingMenuHUD = Class(Widget, function(self, owner)
    Widget._ctor(self, "CraftingMenuHUD")
    self.owner = owner

	self.valid_recipes = {}
	self:RebuildRecipes()

	self.closed_pos = Vector3(0, 0, 0)
	self.opened_pos = Vector3(530, 0, 0)


	self.ui_root = self:AddChild(Widget("craftingmenu_root"))
	self.ui_root:SetPosition(0, 0)

	self.craftingmenu = self.ui_root:AddChild(CraftingMenuWidget(owner, self, HEIGHT))
	self.craftingmenu:SetPosition(-255, 0)
	self.craftingmenu:Disable()

	self.pinbar = self.ui_root:AddChild(CraftingMenuPinBar(owner, self, HEIGHT))
	self.pinbar:SetPosition(0, 0)
	self.pinbar:MoveToBack()

	self.openhint = self:AddChild(Text(UIFONT, 30))
	self.openhint:SetPosition(28, 34 + HEIGHT/2)

	self:RefreshControllers(TheInput:ControllerAttached())

	self.craftingmenu:DoFocusHookups()

    self:StartUpdating()

    local function event_UpdateRecipes()
        self:UpdateRecipes()
    end

    local last_health_seg = nil
    local last_health_penalty_seg = nil
    local last_sanity_seg = nil
    local last_sanity_penalty_seg = nil

    local function UpdateRecipesForHealthIngredients(owner, data)
        local health = owner.replica.health
        if health ~= nil then
            local current_seg = math.floor(math.ceil(data.newpercent * health:Max()) / CHARACTER_INGREDIENT_SEG)
            local penalty_seg = health:GetPenaltyPercent()
            if current_seg ~= last_health_seg or
                penalty_seg ~= last_health_penalty_seg then
                last_health_seg = current_seg
                last_health_penalty_seg = penalty_seg
                self:UpdateRecipes()
            end
        end
    end

    local function UpdateRecipesForSanityIngredients(owner, data)
        local sanity = owner.replica.sanity
        if sanity ~= nil then
            local current_seg = math.floor(math.ceil(data.newpercent * sanity:Max()) / CHARACTER_INGREDIENT_SEG)
            local penalty_seg = sanity:GetPenaltyPercent()
            if current_seg ~= last_sanity_seg or
                penalty_seg ~= last_sanity_penalty_seg then
                last_sanity_seg = current_seg
                last_sanity_penalty_seg = penalty_seg
                self:UpdateRecipes()
            end
        end
    end

	local function InitializeCraftingMenu()
		self:Initialize()
	end

    self.inst:ListenForEvent("playeractivated", InitializeCraftingMenu, self.owner)
    self.inst:ListenForEvent("healthdelta", UpdateRecipesForHealthIngredients, self.owner)
    self.inst:ListenForEvent("sanitydelta", UpdateRecipesForSanityIngredients, self.owner)
    self.inst:ListenForEvent("techtreechange", event_UpdateRecipes, self.owner)
    self.inst:ListenForEvent("itemget", event_UpdateRecipes, self.owner)
    self.inst:ListenForEvent("itemlose", event_UpdateRecipes, self.owner)
    self.inst:ListenForEvent("newactiveitem", event_UpdateRecipes, self.owner)
    self.inst:ListenForEvent("stacksizechange", event_UpdateRecipes, self.owner)
    self.inst:ListenForEvent("unlockrecipe", event_UpdateRecipes, self.owner)
    self.inst:ListenForEvent("refreshcrafting", event_UpdateRecipes, self.owner)
    self.inst:ListenForEvent("refreshinventory", event_UpdateRecipes, self.owner)
    if TheWorld then
        self.inst:ListenForEvent("serverpauseddirty", event_UpdateRecipes, TheWorld)
    end

    self:Hide()
end)

function CraftingMenuHUD:IsCraftingOpen()
    return self.is_open
end

function CraftingMenuHUD:Open()
	if self:IsCraftingOpen() then
		return 
	end

	self.is_open = true
	TheFrontEnd.crafting_navigation_mode = true

	self.ui_root:SetPosition(self.closed_pos.x, self.closed_pos.y, self.closed_pos.z)
	self.ui_root:Disable()

	self.craftingmenu:OnPreOpen()
	self.craftingmenu:Disable()
	self.pinbar:OnCraftingMenuOpen()
	self.pinbar:Disable()
	self.ui_root:MoveTo(self.closed_pos, self.opened_pos, .25, function() 
	    TheFrontEnd:StopTrackingMouse()

		self.ui_root:Enable() 
		self.craftingmenu:Enable()
		self.pinbar:Enable()

		self.craftingmenu:SetFocus()
	end)

	TheFocalPoint.SoundEmitter:PlaySound("dontstarve/HUD/craft_open")

    SetCraftingAutopaused(true)
end

function CraftingMenuHUD:Close()
	if not self.is_open then
		return 
	end

	self:ClearFocus()

	self.is_open = false
	TheFrontEnd.crafting_navigation_mode = false

    SetCraftingAutopaused(false)

	self.ui_root:Disable()
	self.craftingmenu:Disable()
	self.pinbar:OnCraftingMenuClose()
	self.pinbar:Disable()

	TheCraftingMenuProfile:Save()

	self.ui_root:MoveTo(self.ui_root:GetPosition(), self.closed_pos, .25, function()
		self.ui_root:Enable() 
		self.pinbar:Enable()
	end)

	TheFocalPoint.SoundEmitter:PlaySound("dontstarve/HUD/craft_close")
end

function CraftingMenuHUD:GetRecipeState(recipe_name)
	return self.valid_recipes[recipe_name]
end

function CraftingMenuHUD:GetCurrentRecipeState()
	return self.craftingmenu.details_root.data
end

function CraftingMenuHUD:GetCurrentRecipeName()
	return self.craftingmenu.details_root.data ~= nil and self.craftingmenu.details_root.data.recipe.name or nil,
			self.craftingmenu.details_root.skins_spinner ~= nil and self.craftingmenu.details_root.skins_spinner:GetItem() or nil
end

function CraftingMenuHUD:PopulateRecipeDetailPanel(recipe_name, skin_name)
	self.craftingmenu:PopulateRecipeDetailPanel(self.valid_recipes[recipe_name], skin_name)
end

function CraftingMenuHUD:Initialize()
	self:RebuildRecipes()

	self.craftingmenu:Initialize()

	self.pinbar:Refresh()

	self.needtoupdate = false
end

function CraftingMenuHUD:UpdateRecipes()
    self.needtoupdate = true
end

function CraftingMenuHUD:RebuildRecipes()
    if self.owner ~= nil and self.owner.replica.builder ~= nil then

		local builder = self.owner.replica.builder
		local freecrafting = builder:IsFreeBuildMode()

		local tech_trees = builder:GetTechTrees()
        for k, recipe in pairs(AllRecipes) do
            if IsRecipeValid(recipe.name) then
				local knows_recipe = builder:KnowsRecipe(recipe)
				local should_hint_recipe = ShouldHintRecipe(recipe.level, tech_trees)

				if self.valid_recipes[recipe.name] == nil then
					self.valid_recipes[recipe.name] = {recipe = recipe, meta = {}}
				end

				local meta = self.valid_recipes[recipe.name].meta
				--meta.can_build = true/false
				--meta.build_state = string

				if knows_recipe or should_hint_recipe or freecrafting then --Knows enough to see it
				--and (self.filter == nil or self.filter(recipe.name, builder, nil)) -- Has no filter or passes the filter in place

					if builder:IsBuildBuffered(recipe.name) then
						meta.can_build = true
						meta.build_state = "buffered"
					elseif freecrafting then
						meta.can_build = true
						meta.build_state = "freecrafting"
					elseif not builder:CanLearn(recipe.name) then	-- canlearn is "not build tag restricted"
						meta.can_build = false
						meta.build_state = "hide"
					elseif knows_recipe then
						meta.can_build = builder:HasIngredients(recipe)
						meta.build_state = meta.can_build and "has_ingredients" or "no_ingredients"
					elseif CanPrototypeRecipe(recipe.level, tech_trees) then
						meta.can_build = builder:HasIngredients(recipe)
						meta.build_state = meta.can_build and (recipe.nounlock and "has_ingredients" or "prototype") or "no_ingredients"
					elseif recipe.nounlock then
						meta.can_build = false
						meta.build_state = "hide"
					elseif should_hint_recipe then
						meta.can_build = false
						meta.build_state = "hint"
					else
						meta.can_build = false
						meta.build_state = "hide"
					end
				else
					meta.can_build = false
					meta.build_state = "hide"
				end
            end

        end
	end
end

function CraftingMenuHUD:RefreshControllers(controller_mode)
    if controller_mode then
        self.openhint:Show()
        self.openhint:SetString(TheInput:GetLocalizedControl(TheInput:GetControllerID(), CONTROL_OPEN_CRAFTING))
    else
        self.openhint:Hide()
	end

	self.craftingmenu:RefreshControllers(controller_mode)
	self.pinbar:RefreshControllers(controller_mode)
end

function CraftingMenuHUD:OnUpdate(dt)
    if self.needtoupdate then
		self:RebuildRecipes()

		self.craftingmenu:Refresh() 
		self.pinbar:Refresh()

		self.needtoupdate = false
    end
end

function CraftingMenuHUD:OnControl(control, down)
    if CraftingMenuHUD._base.OnControl(self, control, down) then return true end

	return false
end

function CraftingMenuHUD:SelectPin()
	return self.pinbar:StartControllerNav()

end

return CraftingMenuHUD
