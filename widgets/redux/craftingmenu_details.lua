local Image = require "widgets/image"
local ImageButton = require "widgets/imagebutton"
local Widget = require "widgets/widget"
local Text = require "widgets/text"
local Grid = require "widgets/grid"
local Spinner = require "widgets/spinner"

local TEMPLATES = require "widgets/redux/templates"

local IngredientUI = require "widgets/ingredientui"
local SkinSelectorUI = require "widgets/redux/craftingmenu_skinselector"

require("util")

-- ref: craftslot.lua, craftslots.lua, crafting.lua, recipetile.lua, recipepopup.lua

local INGREDIENTS_SCALE = 0.75

-------------------------------------------------------------------------------------------------------
local CraftingMenuDetails = Class(Widget, function(self, owner, panel_width, panel_height)
    Widget._ctor(self, "CraftingMenuDetails")

	self.owner = owner
	self.panel_width = panel_width
	self.panel_height = panel_height
end)

function CraftingMenuDetails:OnControl(control, down)
    if CraftingMenuDetails._base.OnControl(self, control, down) then return true end

	return false
end

function CraftingMenuDetails:_MakeIngredientList()
	local atlas = resolvefilepath(CRAFTING_ATLAS)

	local owner = self.owner
    local builder = owner.replica.builder
    local inventory = owner.replica.inventory
	local recipe = self.data.recipe

    local ingredient_widgets = {}
	local ingredients_root = Widget("ingredients_root")

	local equippedBody = inventory:GetEquippedItem(EQUIPSLOTS.BODY)
    local showamulet = equippedBody and equippedBody.prefab == "greenamulet"

    local num = (recipe.ingredients ~= nil and #recipe.ingredients or 0)
			    + (recipe.character_ingredients ~= nil and #recipe.character_ingredients or 0)
				+ (recipe.tech_ingredients ~= nil and #recipe.tech_ingredients or 0)
				+ (showamulet and 1 or 0)


    local w = 64
    local div = 10
    local half_div = div * .5
    local offset = 0 --center
    if num > 1 then
        offset = offset - (w *.5 + half_div) * (num - 1)
    end

	local scale = math.min(1, 4 / num)
	ingredients_root:SetScale(scale * INGREDIENTS_SCALE)

	local quant_text_scale = math.max(1, 1/(scale*1.125))

    self.hint_tech_ingredient = nil

    for i, v in ipairs(recipe.tech_ingredients) do
        if v.type:sub(-9) == "_material" then
            local has, level = builder:HasTechIngredient(v)
            local ing = ingredients_root:AddChild(IngredientUI(v:GetAtlas(), v:GetImage(), nil, nil, has, STRINGS.NAMES[string.upper(v.type)], owner, v.type, quant_text_scale))
            if GetGameModeProperty("icons_use_cc") then
                ing.ing:SetEffect("shaders/ui_cc.ksh")
            end
            if num > 1 and #ingredient_widgets > 0 then
                offset = offset + half_div
            end
            ing:SetPosition(offset, 0)
            offset = offset + w + half_div
            table.insert(ingredient_widgets, ing)
            if not has and self.hint_tech_ingredient == nil then
                self.hint_tech_ingredient = v.type:sub(1, -10):upper()
            end
        end
    end

    for i, v in ipairs(recipe.ingredients) do
        local has, num_found = inventory:Has(v.type, math.max(1, RoundBiasedUp(v.amount * builder:IngredientMod())), true)
        local ing = ingredients_root:AddChild(IngredientUI(v:GetAtlas(), v:GetImage(), v.amount ~= 0 and v.amount or nil, num_found, has, STRINGS.NAMES[string.upper(v.type)], owner, v.type, quant_text_scale))
        if GetGameModeProperty("icons_use_cc") then
            ing.ing:SetEffect("shaders/ui_cc.ksh")
        end
        if num > 1 and #ingredient_widgets > 0 then
            offset = offset + half_div
        end
        ing:SetPosition(offset, 0)
        offset = offset + w + half_div
        table.insert(ingredient_widgets, ing)
    end

    for i, v in ipairs(recipe.character_ingredients) do
        --#BDOIG - does this need to listen for deltas and change while menu is open?
        --V2C: yes, but the entire craft tabs does. (will be added there)
        local has, amount = builder:HasCharacterIngredient(v)

		if v.type == CHARACTER_INGREDIENT.HEALTH and owner:HasTag("health_as_oldage") then
			v = Ingredient(CHARACTER_INGREDIENT.OLDAGE, math.ceil(v.amount * TUNING.OLDAGE_HEALTH_SCALE))
		end
        local ing = ingredients_root:AddChild(IngredientUI(v:GetAtlas(), v:GetImage(), v.amount, amount, has, STRINGS.NAMES[string.upper(v.type)], owner, v.type, quant_text_scale))
        if GetGameModeProperty("icons_use_cc") then
            ing.ing:SetEffect("shaders/ui_cc.ksh")
        end
        if num > 1 and #ingredient_widgets > 0 then
            offset = offset + half_div
        end
        ing:SetPosition(offset, 0)
        offset = offset + w + half_div
        table.insert(ingredient_widgets, ing)
    end

	if showamulet then
		local amulet_atlas, amulet_img = equippedBody.replica.inventoryitem:GetAtlas(), equippedBody.replica.inventoryitem:GetImage()
		
		local amulet = ingredients_root:AddChild(IngredientUI(amulet_atlas, amulet_img, 0.2, 0.2, true, STRINGS.GREENAMULET_TOOLTIP, owner, CHARACTER_INGREDIENT.MAX_HEALTH, quant_text_scale))
		amulet:SetPosition(offset + half_div, 0)
		table.insert(ingredient_widgets, amulet)

        --for _, ing in ipairs(ingredient_widgets) do
		--	local glow = ingredients_root:AddChild(Image(atlas, "slot_frame_select.tex"))
		--	glow:SetTint(0.2, .8, 0.2, .75)
		--	glow:SetScale(0.58)
		--	glow:SetPosition(ing:GetPosition())
		--	glow:MoveToBack()
		--end

		--local amulet = ingredients_root:AddChild(Image(amulet_atlas, amulet_img))
		--amulet:SetPosition(offset + half_div, -4)
		--table.insert(ingredient_widgets, amulet)

        for _, ing in ipairs(ingredient_widgets) do
			local glow = ing:AddChild(Image("images/global_redux.xml", "shop_glow.tex"))
			glow:SetTint(.8, .8, .8, 0.4)
			local len = 3
			local function doscale(start) if start then glow:SetScale(0) glow:ScaleTo(0, 0.5, len/2, doscale) else glow:ScaleTo(.5, 0, len/2) end end
			local function animate_glow() 
				local t = math.random() * 360
				glow:RotateTo(t, t-360, 3, animate_glow) 
				doscale(true)
			end
			animate_glow()
		end

	end

	return ingredients_root
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
            else
				teaser:SetSize(20)
				teaser:UpdateOriginalSize()
				teaser:SetMultilineTruncatedString(STRINGS.UI.CRAFTING.NEEDSTUFF, 2, (self.panel_width / 2) * 0.8, nil, false, true)
            end

			teaser:Show()
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

		if skin ~= nil then
			Profile:SetLastUsedSkinForItem(self.data.recipe.name, skin)
			--Profile:SetRecipeTimestamp(self.data.recipe.name, button.timestamp)									-- TODO - support the timestamp, see recipepopup
		end
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
	self:PopulateRecipeDetailPanel(self.data)
end

function CraftingMenuDetails:PopulateRecipeDetailPanel(data, skin_name)
	if data == nil then
		self.data = nil
		self:KillAllChildren()
		return
	end

	local recipe = data.recipe

	if self.data == data then
		self.ingredients_list:KillAllChildren()
		self.ingredients_list:AddChild(self:_MakeIngredientList())
		
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
		if TheCraftingMenuProfile:IsFavorite(recipe.name) then
			TheCraftingMenuProfile:RemoveFavorite(recipe.name)
			fav_button:SetTextures(atlas, "favorite_unchecked.tex", "favorite_unchecked.tex", nil, "favorite_checked.tex", nil, { .81, .81 }, { 0, 0 })
		else
			TheCraftingMenuProfile:AddFavorite(recipe.name)
			fav_button:SetTextures(atlas, "favorite_checked.tex", "favorite_checked.tex", nil, "favorite_unchecked.tex", nil, { .81, .81 }, { 0, 0 })
		end

		self.owner:PushEvent("refreshcrafting")
	end)

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
	self.ingredients_list = root_right:AddChild(Widget("ingredients_list"))
	self.ingredients_list:AddChild(self:_MakeIngredientList())
	local ing_height = 45
	self.ingredients_list:SetPosition(0, y - ing_height/2 - 5)
	y = y - ing_height

	
	-- Build Button
	y = y - 5
	self.build_button_root = root_right:AddChild(Widget("build_button_root"))
	self.build_button_root = self.build_button_root:AddChild(self:_MakeBuildButton())
	self.build_button_root:SetPosition(0, y - 60/2)

	self:UpdateBuildButton()
end

return CraftingMenuDetails

