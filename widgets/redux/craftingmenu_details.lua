local Image = require "widgets/image"
local ImageButton = require "widgets/imagebutton"
local Widget = require "widgets/widget"
local Text = require "widgets/text"
local Spinner = require "widgets/spinner"

local TEMPLATES = require "widgets/redux/templates"

local IngredientUI = require "widgets/ingredientui"
local SkinSelectorUI = require "widgets/redux/craftingmenu_skinselector"
local CraftingMenuIngredients = require "widgets/redux/craftingmenu_ingredients"


require("util")

-- ref: craftslot.lua, craftslots.lua, crafting.lua, recipetile.lua, recipepopup.lua

local INGREDIENTS_SCALE = 0.75

-------------------------------------------------------------------------------------------------------
local CraftingMenuDetails = Class(Widget, function(self, owner, parent_widget, panel_width, panel_height)
    Widget._ctor(self, "CraftingMenuDetails")

	self.owner = owner
	self.parent_widget = parent_widget
	self.panel_width = panel_width
	self.panel_height = panel_height
end)

function CraftingMenuDetails:OnControl(control, down)
    if CraftingMenuDetails._base.OnControl(self, control, down) then return true end

	return false
end

function CraftingMenuDetails:_GetHintTextForRecipe(player, recipe)
    local validmachines = {}
    local adjusted_level = deepcopy(recipe.level)

    -- Adjust recipe's level for bonus so that the hint gives the right message
	local tech_bonus = player.replica.builder:GetTechBonuses()
	for k, v in pairs(adjusted_level) do
		adjusted_level[k] = math.max(0, v - (tech_bonus[k] or 0))
	end

    for k, v in pairs(TUNING.PROTOTYPER_TREES) do
        local canbuild = CanPrototypeRecipe(adjusted_level, v)
        if canbuild then
            table.insert(validmachines, {TREE = tostring(k), SCORE = 0})
        end
    end

    if #validmachines > 0 then
        if #validmachines == 1 then
            --There's only once machine is valid. Return that one.
            return validmachines[1].TREE
        end

        --There's more than one machine that gives the valid tech level! We have to find the "lowest" one (taking bonus into account).
        for k,v in pairs(validmachines) do
            for rk,rv in pairs(adjusted_level) do
                local prototyper_level = TUNING.PROTOTYPER_TREES[v.TREE][rk]
                if prototyper_level and (rv > 0 or prototyper_level > 0) then
                    if rv == prototyper_level then
                        --recipe level matches, add 1 to the score
                        v.SCORE = v.SCORE + 1
                    elseif rv < prototyper_level then
                        --recipe level is less than prototyper level, remove 1 per level the prototyper overshot the recipe
                        v.SCORE = v.SCORE - (prototyper_level - rv)
                    end
                end
            end
        end

        table.sort(validmachines, function(a,b) return (a.SCORE) > (b.SCORE) end)

        return validmachines[1].TREE
    end

    return "CANTRESEARCH"
end

local hint_text =
{
    ["SCIENCEMACHINE"] = "NEEDSCIENCEMACHINE",
    ["ALCHEMYMACHINE"] = "NEEDALCHEMYENGINE",
    ["SHADOWMANIPULATOR"] = "NEEDSHADOWMANIPULATOR",
    ["PRESTIHATITATOR"] = "NEEDPRESTIHATITATOR",
    ["CANTRESEARCH"] = "CANTRESEARCH",
    ["ANCIENTALTAR_HIGH"] = "NEEDSANCIENT_FOUR",
    ["SPIDERCRAFT"] = "NEEDSSPIDERFRIENDSHIP",
}

function CraftingMenuDetails:UpdateBuildButton()
    local builder = self.owner.replica.builder
	local recipe = self.data.recipe
	local meta = self.data.meta

	local teaser = self.build_button_root.teaser
	local button = self.build_button_root.button

    if meta.build_state == "hint" or self.hint_tech_ingredient ~= nil then
        local str
        if self.hint_tech_ingredient ~= nil then
            str = STRINGS.UI.CRAFTING.NEEDSTECH[self.hint_tech_ingredient]
		else
            local prototyper_tree = self:_GetHintTextForRecipe(self.owner, recipe)
            str = STRINGS.UI.CRAFTING[hint_text[prototyper_tree] or ("NEEDS"..prototyper_tree)]
        end
		teaser:SetSize(20)
		teaser:UpdateOriginalSize()
        teaser:SetMultilineTruncatedString(str, 2, (self.panel_width / 2) * 0.8, nil, false, true)

        teaser:Show()
        button:Hide()
    else
        local buttonstr = meta.build_state == "prototype" and STRINGS.UI.CRAFTING.PROTOTYPE
							or meta.build_state == "buffered" and STRINGS.UI.CRAFTING.PLACE
							or recipe.actionstr ~= nil and STRINGS.UI.CRAFTING.RECIPEACTION[recipe.actionstr]
							or STRINGS.UI.CRAFTING.BUILD

        if TheInput:ControllerAttached() then
            if meta.can_build then
				teaser:SetSize(26)
				teaser:UpdateOriginalSize()
				teaser:SetMultilineTruncatedString(TheInput:GetLocalizedControl(TheInput:GetControllerID(), CONTROL_ACCEPT).." "..buttonstr, 2, (self.panel_width / 2) * 0.8, nil, false, true)
				teaser:Show()
            else
				teaser:SetSize(20)
				teaser:UpdateOriginalSize()
				teaser:SetMultilineTruncatedString(STRINGS.UI.CRAFTING.NEEDSTUFF, 2, (self.panel_width / 2) * 0.8, nil, false, true)
				teaser:Show()
            end

			button:Hide()
        else
            button:SetText(buttonstr)
            if meta.can_build then
                button:Enable()
            else
                button:Disable()
            end

			button:Show()
			teaser:Hide()
        end
    end

end

function CraftingMenuDetails:_MakeBuildButton()
	local root = Widget("build_button_root")
	
	root.teaser = root:AddChild(Text(BODYTEXTFONT, 20))
	root.teaser:Hide()

	local button = root:AddChild(ImageButton())
	button:SetWhileDown(function()
		if button.recipe_held then
			DoRecipeClick(self.owner, self.data.recipe, self.skins_spinner:GetItem())
		end
	end)
	button:SetOnDown(function()
		if button.last_recipe_click and (GetTime() - button.last_recipe_click) < 1 then
			button.recipe_held = true
			button.last_recipe_click = nil
		end
	end)
	button:SetOnClick(function()
		button.last_recipe_click = GetTime()
        local skin = self.skins_spinner:GetItem()

		if not button.recipe_held then
			if not DoRecipeClick(self.owner, self.data.recipe, skin) then
				self.owner.HUD:CloseCrafting()
			end
		end
		button.recipe_held = false
	end)
	button.OnHide = function()
		button.recipe_held = false
	end
	button:SetScale(.7,.7,.7)
	button.image:SetScale(.45, .7)
    button:Disable()
	button:Hide()
	root.button = button

	return root
end

function CraftingMenuDetails:Refresh()
	self:PopulateRecipeDetailPanel(self.data, self.skins_spinner ~= nil and self.skins_spinner:GetItem() or nil)
end

function CraftingMenuDetails:RefreshControllers(controller_mode)
	if self.skins_spinner ~= nil then
		self.skins_spinner:RefreshControllers(controller_mode)
	end
end

function CraftingMenuDetails:PopulateRecipeDetailPanel(data, skin_name)
	if data == nil then
		self.data = nil

		self.build_button_root = nil
		self.ingredients = nil
		self.skins_spinner = nil
		self.fav_button = nil

		self:KillAllChildren()
		return
	end

	local recipe = data.recipe

	if self.data == data and self.skins_spinner:GetItem() == skin_name then
		self.ingredients:SetRecipe(recipe)
		self:UpdateBuildButton()
		return
	end

	self:KillAllChildren()

	self.data = data

	local atlas = resolvefilepath(CRAFTING_ATLAS)

	local top = -5
	local left = -self.panel_width / 2

	local width = self.panel_width / 2
	local title_width = self.panel_width - 60

	if recipe.custom_craftingmenu_details_fn ~= nil then
		-- Modders can define this on a preparedfoods definition table if they use this if they want to have their own custom display.
		return recipe.custom_craftingmenu_details_fn(self, data, self, top, left)
	end

	local root_left = self:AddChild(Widget("left_root"))
	root_left:SetPosition(-self.panel_width / 4, 0)

	local y = top

	-- Name
	local name_font_size = 30
	local name = root_left:AddChild(Text(UIFONT, name_font_size))
	name:SetAutoSizingString(STRINGS.NAMES[string.upper(recipe.name)] or STRINGS.NAMES[string.upper(recipe.product)], title_width)
	name:SetPosition(0, y - name_font_size/2)

	-- Favorite Button
	local is_favorite = TheCraftingMenuProfile:IsFavorite(recipe.name)
	local fav_button = root_left:AddChild(ImageButton(atlas, is_favorite and "favorite_checked.tex" or "favorite_unchecked.tex", is_favorite and "favorite_checked.tex" or "favorite_unchecked.tex", nil, is_favorite and "favorite_unchecked.tex" or "favorite_checked.tex", nil, { .81, .81 }, { 0, 0 }))
    fav_button.focus_scale = {1, 1}
    fav_button.normal_scale = {.81, .81}
	fav_button:SetPosition(-width/2 + 5, y - name_font_size/2)
	fav_button:SetOnClick(function()
		local is_favorite_recipe = TheCraftingMenuProfile:IsFavorite(recipe.name)
		if is_favorite_recipe then
			TheCraftingMenuProfile:RemoveFavorite(recipe.name)
			fav_button:SetTextures(atlas, "favorite_unchecked.tex", "favorite_unchecked.tex", nil, "favorite_checked.tex", nil, { .81, .81 }, { 0, 0 })
		else
			TheCraftingMenuProfile:AddFavorite(recipe.name)
			fav_button:SetTextures(atlas, "favorite_checked.tex", "favorite_checked.tex", nil, "favorite_unchecked.tex", nil, { .81, .81 }, { 0, 0 })
		end

		self.parent_widget:OnFavoriteChanged(recipe.name, not is_favorite_recipe)

		self.owner:PushEvent("refreshcrafting")
	end)
	self.fav_button = fav_button

	y = y - name_font_size

	-- Divider
	y = y - 5
	local line_height = 4
	local line = root_left:AddChild(Image("images/ui.xml", "line_horizontal_white.tex"))
	line:SetPosition(0, y - line_height/2)
    line:SetTint(unpack(BROWN))
	line:ScaleToSize(width, line_height)
	line:MoveToBack()
	y = y - line_height

	-- Description
	y = y - 5
	local desc_font_size = 25
	local desc = root_left:AddChild(Text(BODYTEXTFONT, desc_font_size))
	desc:SetMultilineTruncatedString(STRINGS.RECIPE_DESC[string.upper(recipe.description or recipe.product)], 2, width, nil, false, true)
	desc:SetPosition(0, y - desc_font_size)
	y = y - desc_font_size * 2 -- 2 lines

	-- Right Side
	y = top + 2

	local root_right = self:AddChild(Widget("root_right"))
	root_right:SetPosition(self.panel_width / 4 + 5, y)

	-- Skins Menu
    self.skins_spinner = root_right:AddChild(SkinSelectorUI(recipe, self.owner, skin_name))
    self.skins_spinner:SetPosition(0, y)
	y = y - self.skins_spinner.widget_height

	-- Ingredients
	y = y - 10
	self.ingredients = root_right:AddChild(CraftingMenuIngredients(self.owner, 4, recipe))
	local ing_height = 45
	self.ingredients:SetPosition(0, y - ing_height/2 - 5)
	y = y - ing_height

	
	-- Build Button
	y = y - 5
	self.build_button_root = root_right:AddChild(Widget("build_button_root"))
	self.build_button_root = self.build_button_root:AddChild(self:_MakeBuildButton())
	self.build_button_root:SetPosition(0, y - 60/2)

	self:UpdateBuildButton()
end

return CraftingMenuDetails

