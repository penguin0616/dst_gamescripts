local Image = require "widgets/image"
local ImageButton = require "widgets/imagebutton"
local Widget = require "widgets/widget"
local Text = require "widgets/text"
local Grid = require "widgets/grid"
local Spinner = require "widgets/spinner"

local TEMPLATES = require "widgets/redux/templates"

local IngredientUI = require "widgets/ingredientui"
local CraftingMenuDetails = require "widgets/redux/craftingmenu_details"

require("util")

-- ref: craftslot.lua, craftslots.lua, crafting.lua, recipetile.lua, recipepopup.lua

-------------------------------------------------------------------------------------------------------
local CraftingMenuWidget = Class(Widget, function(self, owner, crafting_hud, height)
    Widget._ctor(self, "CraftingMenuWidget")

	self.owner = owner
	self.crafting_hud = crafting_hud

	local build_state_sorting = 
	{
		freecrafting = 0,
		buffered = 1, 
		has_ingredients = 2,
		prototype = 2,
		no_ingredients = 3,
	}

	local function sort_alpha(a, b)
		local a_name = STRINGS.NAMES[string.upper(a.recipe.name)] or STRINGS.NAMES[string.upper(a.recipe.product)] or ""
		local b_name = STRINGS.NAMES[string.upper(b.recipe.name)] or STRINGS.NAMES[string.upper(b.recipe.product)] or ""
		return a_name < b_name
	end

    self.sort_modes = {
        {str = STRINGS.UI.CRAFTING_MENU.SORTING.DEFAULT, atlas = "images/button_icons2.xml", img = "sort_default.tex", fn = function(a, b)
			if self.current_filter_name ~= nil then
				local sort_values = FunctionOrValue(CRAFTING_FILTERS[self.current_filter_name].default_sort_values)
				if sort_values ~= nil then
					if (sort_values[a.recipe.name] or 99999) < (sort_values[b.recipe.name] or 99999) then
						return true
					end
				end
			end
			return false
		end},
        {str = STRINGS.UI.CRAFTING_MENU.SORTING.CRAFTABLE, atlas = "images/button_icons.xml", img = "sort_rarity.tex", fn = function(a, b) 
			local sort_a, sort_b = build_state_sorting[a.meta.build_state] or 99999, build_state_sorting[b.meta.build_state] or 99999
			if sort_a == sort_b then
				return self.sort_modes[1].fn(a, b)
			end
			return sort_a < sort_b
		end},
        {str = STRINGS.UI.CRAFTING_MENU.SORTING.NAME, atlas = "images/button_icons.xml", img = "sort_name.tex", fn = sort_alpha},
    }
	self.sort_mode = 1

    self.root = self:AddChild(Widget("root"))

	self.current_filter_name = nil
	self.filtered_recipes = {}
	self.filter_buttons = {}

	self.last_search_text = ""
	self.search_text = ""
	self.last_searched_recipes = {}
	self.searched_recipes = {}
	self.search_delay = 0
	self.current_recipe_search = nil

	self.frame = self.root:AddChild(self:MakeFrame(500, height, 150))

	self:UpdateFilterButtons()

	self:SelectFilter(CRAFTING_FILTERS.TOOLS.name, true)

	self.details_root:PopulateRecipeDetailPanel(self.filtered_recipes[1])


	--self.panel = self.root:AddChild(CrockpotPage(owner, "cookpot"))
	--self.focus_forward = self.panel.parent_default_focus
	--if TheInput:ControllerAttached() then
	--	self.panel.parent_default_focus:SetFocus()
	--end

	self.focus_forward = self.filter_panel.filter_grid
end)

function CraftingMenuWidget:OnControl(control, down)
    if CraftingMenuWidget._base.OnControl(self, control, down) then return true end

	return false
end

function CraftingMenuWidget:DoFocusHookups()
	self.filter_panel:SetFocusChangeDir(MOVE_UP, self.favorites_filter)
	self.filter_panel:SetFocusChangeDir(MOVE_DOWN, self.recipe_grid)
	self.filter_panel:SetFocusChangeDir(MOVE_RIGHT, self.crafting_hud.pinbar)

	self.recipe_grid:SetFocusChangeDir(MOVE_UP, self.filter_panel)
	self.recipe_grid:SetFocusChangeDir(MOVE_RIGHT, function() return self.crafting_hud.pinbar:GetFirstButton() end)

	self.crafting_hud.pinbar:SetFocusChangeDir(MOVE_LEFT, function() if self.crafting_hud:IsCraftingOpen() then return #self.recipe_grid.items > 0 and self.recipe_grid or self.filter_panel end end)


	self.favorites_filter:SetFocusChangeDir(MOVE_RIGHT, function() return self.special_event_filter ~= nil and self.special_event_filter
																			or self.crafting_station_filter:IsVisible() and self.crafting_station_filter 
																			or self.search_box
														end)
	self.favorites_filter:SetFocusChangeDir(MOVE_DOWN, self.filter_panel)

	if self.special_event_filter ~= nil then
		self.special_event_filter:SetFocusChangeDir(MOVE_LEFT, self.favorites_filter)
		self.special_event_filter:SetFocusChangeDir(MOVE_RIGHT, function() return self.crafting_station_filter:IsVisible() and self.crafting_station_filter or self.search_box end)
		self.special_event_filter:SetFocusChangeDir(MOVE_DOWN, self.filter_panel)
	end

	self.crafting_station_filter:SetFocusChangeDir(MOVE_LEFT, function() return self.special_event_filter ~= nil and self.special_event_filter or self.favorites_filter end)
	self.crafting_station_filter:SetFocusChangeDir(MOVE_RIGHT, self.search_box)
	self.crafting_station_filter:SetFocusChangeDir(MOVE_DOWN, self.filter_panel)

	self.search_box:SetFocusChangeDir(MOVE_LEFT, function() return self.crafting_station_filter:IsVisible() and self.crafting_station_filter 
																			or self.special_event_filter ~= nil and self.special_event_filter
																			or self.favorites_filter
														end)
	self.search_box:SetFocusChangeDir(MOVE_RIGHT, function() return self.mods_filter:IsVisible() and self.mods_filter or self.sort_button end)
	self.search_box:SetFocusChangeDir(MOVE_DOWN, self.filter_panel)

	self.mods_filter:SetFocusChangeDir(MOVE_LEFT, self.search_box)
	self.mods_filter:SetFocusChangeDir(MOVE_RIGHT, self.sort_button)
	self.mods_filter:SetFocusChangeDir(MOVE_DOWN, self.filter_panel)

	self.sort_button:SetFocusChangeDir(MOVE_LEFT, function() return self.mods_filter:IsVisible() and self.mods_filter or self.search_box end)
	self.sort_button:SetFocusChangeDir(MOVE_RIGHT, function() return self.crafting_hud.pinbar:GetFirstButton() end)
	self.sort_button:SetFocusChangeDir(MOVE_DOWN, self.filter_panel)
end

function CraftingMenuWidget:PopulateRecipeDetailPanel(recipe, skin_name)
	self.details_root:PopulateRecipeDetailPanel(recipe, skin_name)
end

local function search_exact_match(search, str)
    str = str:gsub(" ", "")

    --Simple find in strings for multi word search
	return string.find( str, search, 1, true ) ~= nil
end

local function text_filter(recipe, search_str)
    if search_str == "" then
        return true
    end

	local name_upper = string.upper(recipe.name)

	local product = recipe.product
	local product_upper = string.upper(product)

	local name = STRINGS.NAMES[name_upper] or STRINGS.NAMES[product_upper]
	local desc = STRINGS.RECIPE_DESC[name_upper] or STRINGS.RECIPE_DESC[product_upper]

    return search_exact_match(search_str, string.lower(product))
        or (name and search_exact_match(search_str, string.lower(name)))
        or (desc and search_exact_match(search_str, string.lower(desc)))
end

function CraftingMenuWidget:ApplyFilters()
	self.filtered_recipes = {}

	local filter_recipes = (self.current_filter_name ~= nil and CRAFTING_FILTERS[self.current_filter_name] ~= nil) and FunctionOrValue(CRAFTING_FILTERS[self.current_filter_name].recipes) or nil
	if filter_recipes ~= nil then
		for _, recipe_name in ipairs(filter_recipes) do
			local data = self.crafting_hud.valid_recipes[recipe_name]
			if data ~= nil and data.meta.build_state ~= "hide" then
				table.insert(self.filtered_recipes, data)
			end
		end
	else
		for _, data in pairs(self.crafting_hud.valid_recipes) do
			if data.meta.build_state ~= "hide" then
				if self:IsRecipeValidForSearch(data.recipe.name) then
					table.insert(self.filtered_recipes, data)
				end
			end
		end
	end

	if self.sort_mode ~= 1 then
		self:SortFilteredRecipes()
	else
		self.recipe_grid:SetItemsData(self.filtered_recipes)
	end
end

function CraftingMenuWidget:SortFilteredRecipes()
	if #self.filtered_recipes > 0 then
		table.sort(self.filtered_recipes, self.sort_fn)
	end
	self.recipe_grid:SetItemsData(self.filtered_recipes)
end

function CraftingMenuWidget:UpdateFilterButtons()
	local builder = self.owner ~= nil and self.owner.replica.builder or nil
	if builder ~= nil then
		if builder:IsFreeBuildMode() then
			self.crafting_station_filter.button:SetHoverText(STRINGS.UI.CRAFTING_FILTERS.CRAFTING_STATION)
			self.crafting_station_filter:Show()
		else
			local prototyper = builder:GetCurrentPrototyper()
			local crafting_station_def = prototyper ~= nil and PROTOTYPER_DEFS[prototyper.prefab] or nil
			if crafting_station_def ~= nil and crafting_station_def.is_crafting_station then
				self.crafting_station_filter.button:SetHoverText(crafting_station_def.filter_text)
				self.crafting_station_filter.filter_img:SetTexture(crafting_station_def.icon_atlas, crafting_station_def.icon_image)
				self.crafting_station_filter.filter_img:ScaleToSize(54, 54)
				self.crafting_station_filter:Show()
			else			
				self.crafting_station_filter:Hide()
			end
		end
	end

	if #CRAFTING_FILTERS.MODS.recipes == 0 then
		if self.mods_filter:IsVisible() then
			self.mods_filter:Hide()
		end
	else
		if not self.mods_filter:IsVisible() then
			self.mods_filter:Show()
		end
	end

	local atlas = resolvefilepath(CRAFTING_ATLAS)

	local can_prototype = false
	local new_recipe_available = false

	for name, button in pairs(self.filter_buttons) do
		if button.filter_def.recipes ~= nil then 
			local state = nil
			local num_can_build = 0
			for _, recipe_name in pairs(FunctionOrValue(button.filter_def.recipes)) do
				local data = self.crafting_hud.valid_recipes[recipe_name]
				if data ~= nil then
					if data.meta.build_state == "prototype" then
						state = "prototype"
						can_prototype = true
						num_can_build = num_can_build + 1
						break
					elseif data.meta.can_build then
						state = "can_build"
						num_can_build = num_can_build + 1
					end
				end
			end
			if button.state ~= state then
				button.bg:SetTexture(atlas, (state ~= nil and "filterslot_bg_highlight.tex" or "filterslot_bg.tex"))
				if state == "prototype" then
					button.prototype_icon:Show()
				else
					button.prototype_icon:Hide()
				end
				button.state = state
			end
			if state ~= "prototype" and button.num_can_build == nil or num_can_build > button.num_can_build then
				new_recipe_available = true
			end
			button.num_can_build = num_can_build
		end
	end


	if self.crafting_hud.pinbar ~= nil and self.crafting_hud.pinbar.pin_open ~= nil then
		self.crafting_hud.pinbar.pin_open:SetCraftingState(can_prototype, new_recipe_available)
	end
end

function CraftingMenuWidget:Refresh()
	self:UpdateFilterButtons()
	self:ApplyFilters()
	self.details_root:Refresh()
end

function CraftingMenuWidget:OnUpdate(dt)
	self.search_delay = self.search_delay - dt
	if self.search_delay > 0 then
		return
	end

	self.current_recipe_search = next(AllRecipes, self.current_recipe_search)
	local processed_recipe_count = 0
	while self.current_recipe_search and processed_recipe_count < 30 do
		if self.searched_recipes[self.current_recipe_search] == nil then
			self:ValidateRecipeForSearch(self.current_recipe_search)
			processed_recipe_count = processed_recipe_count + 1
		end

		self.current_recipe_search = next(AllRecipes, self.current_recipe_search)
	end

	if self.current_recipe_search == nil then
		self:StopUpdating()
	end
end

function CraftingMenuWidget:OnPreOpen()
	local builder = self.owner ~= nil and self.owner.replica.builder or nil
	local prototyper = builder ~= nil and builder:GetCurrentPrototyper() or nil
	local prototyper_def = prototyper ~= nil and PROTOTYPER_DEFS[prototyper.prefab] or nil
	if prototyper_def ~= nil and prototyper_def.is_crafting_station then
		self.is_at_crafting_station = true
		if self.pre_crafting_station_filter == nil then
			self.pre_crafting_station_filter = self.current_filter_name
		end
		self:SelectFilter(CRAFTING_FILTERS.CRAFTING_STATION.name, true)
	else
		if self.pre_crafting_station_filter ~= nil then
			self:SelectFilter(self.pre_crafting_station_filter, true)
			self.pre_crafting_station_filter = nil
		end
	end
end

function CraftingMenuWidget:GetHelpText()
    local controller_id = TheInput:GetControllerID()
    local t = {}

--    table.insert(t, TheInput:GetLocalizedControl(controller_id, CONTROL_OPEN_CRAFTING).."/"..TheInput:GetLocalizedControl(controller_id, CONTROL_OPEN_INVENTORY).. " " .. STRINGS.UI.HELP.CHANGE_TAB)

    return table.concat(t, "  ")
end


function CraftingMenuWidget:MakeFrame(width, height, fileters_height)
	local w = Widget("crafting_menu_frame")

	local atlas = resolvefilepath(CRAFTING_ATLAS)

	local fill = w:AddChild(Image(atlas, "backing.tex"))
	fill:ScaleToSize(width, height + 18)
	fill:SetTint(1, 1, 1, 0.5)

	local left = w:AddChild(Image(atlas, "side.tex"))
	left:SetPosition(-width/2 - 8, 1)
	left:ScaleToSize(-26, -580)
	
	local right = w:AddChild(Image(atlas, "side.tex"))
	right:SetPosition(width/2 + 8, 1)
	right:ScaleToSize(26, 580)

	local top = w:AddChild(Image(atlas, "top.tex"))
	top:SetPosition(0, height/2 + 10)
	top:ScaleToSize(534, 38)

	local bottom = w:AddChild(Image(atlas, "bottom.tex"))
	bottom:SetPosition(0, -height/2 - 8)
	bottom:ScaleToSize(534, 38)

	----------------
	self.filter_panel = w:AddChild(self:MakeFilterPanel(width, fileters_height))
	self.filter_panel:SetPosition(-width/2 + width/2, height/2 - 20)

	self.recipe_grid = w:AddChild(self:MakeRecipeList(width, height - fileters_height))
	local grid_w, grid_h = self.recipe_grid:GetScrollRegionSize()
	self.recipe_grid:SetPosition(-2, height/2 - fileters_height - grid_h/2)

	----------------

	self.itemlist_split = w:AddChild(Image(atlas, "horizontal_bar.tex"))
	self.itemlist_split:SetPosition(0, height/2 - fileters_height)
	self.itemlist_split:ScaleToSize(502, 15)

	self.itemlist_split2 = w:AddChild(Image(atlas, "horizontal_bar.tex"))
	self.itemlist_split2:SetPosition(0, height/2 - fileters_height - grid_h - 2)
	self.itemlist_split2:ScaleToSize(502, 15)

	----------------

	self.details_root = w:AddChild(CraftingMenuDetails(self.owner, width - 20 * 2, height - 20 * 2))
	self.details_root:SetPosition(0, height/2 - fileters_height - grid_h - 10)

	----------------

	self.recipe_grid:MoveToBack()

	fill:MoveToBack()
	return w
end

function CraftingMenuWidget:ValidateRecipeForSearch(name)
	local is_narrower_search = self.search_text:len() > self.last_search_text:len()
	local is_appended_string = (is_narrower_search and search_exact_match(self.last_search_text, self.search_text)) or
		(not is_narrower_search and search_exact_match(self.search_text, self.last_search_text)) or nil

	if not is_appended_string or self.last_searched_recipes[name] == nil or is_narrower_search == self.last_searched_recipes[name] then
		self.searched_recipes[name] = text_filter(AllRecipes[name], self.search_text)
	else
		self.searched_recipes[name] = self.last_searched_recipes[name]
	end
end

function CraftingMenuWidget:IsRecipeValidForSearch(name)
	if self.searched_recipes[name] == nil then
		self:ValidateRecipeForSearch(name)
	end

	return self.searched_recipes[name]
end

function CraftingMenuWidget:SetSearchText(search_text)
	search_text = TrimString(string.lower(search_text)):gsub(" ", "")

	if search_text == self.last_search_text then
		return
	end

	self.last_search_text = self.search_text
	self.search_text = search_text

	self.last_searched_recipes = self.searched_recipes
	self.searched_recipes = {}

	self:StartUpdating()
	self.search_delay = 1
	self.current_recipe_search = nil
end

function CraftingMenuWidget:MakeSearchBox(box_width, box_height)
    local searchbox = Widget("search")
    searchbox.textbox_root = searchbox:AddChild(TEMPLATES.StandardSingleLineTextEntry(nil, box_width, box_height))
    searchbox.textbox = searchbox.textbox_root.textbox
    searchbox.textbox:SetTextLengthLimit(200)
    searchbox.textbox:SetForceEdit(true)
    searchbox.textbox:EnableWordWrap(false)
    searchbox.textbox:EnableScrollEditWindow(true)
    searchbox.textbox:SetHelpTextEdit("")
    searchbox.textbox:SetHelpTextApply(STRINGS.UI.SERVERCREATIONSCREEN.SEARCH)
    searchbox.textbox:SetTextPrompt(STRINGS.UI.SERVERCREATIONSCREEN.SEARCH, UICOLOURS.GREY)
    searchbox.textbox.prompt:SetHAlign(ANCHOR_MIDDLE)
    searchbox.textbox.OnTextInputted = function()
		self:SetSearchText(self.search_box.textbox:GetString())

		self:SelectFilter(nil, false)
    end

     -- If searchbox ends up focused, highlight the textbox so we can tell something is focused.
    searchbox:SetOnGainFocus( function() searchbox.textbox:OnGainFocus() end )
    searchbox:SetOnLoseFocus( function() searchbox.textbox:OnLoseFocus() end )

    searchbox.focus_forward = searchbox.textbox

    return searchbox
end

function CraftingMenuWidget:SelectFilter(name, clear_search_text)
	if name ~= CRAFTING_FILTERS.CRAFTING_STATION.name then
		self.pre_crafting_station_filter = nil
	end

	if clear_search_text then
		self:SetSearchText("")
		self.search_box.textbox:SetString("")
	end

	if name == nil or CRAFTING_FILTERS[name] == nil or self.filter_buttons[name] == nil then
		name = "EVERYTHING"
	end

	if name == self.current_filter_name and clear_search_text then
		return
	end

	if self.current_filter_name ~= nil and self.filter_buttons[self.current_filter_name] ~= nil then
		self.filter_buttons[self.current_filter_name].button:Unselect()
	end
	
	self.current_filter_name = name
	self.filter_buttons[name].button:Select()

	self:ApplyFilters()
end

function CraftingMenuWidget:MakeFilterButton(filter_def, button_size)
	local atlas = resolvefilepath(CRAFTING_ATLAS)

	local w = Widget("filter_"..filter_def.name)
	w:SetScale(button_size/64)

	local button = w:AddChild(ImageButton(atlas, "filterslot_frame.tex", "filterslot_frame_highlight.tex", nil, nil, "filterslot_frame_select.tex"))
	w.button = button
	button:SetOnClick(function()
		self:SelectFilter(filter_def.name, true)
	end)
	button:SetOnSelect(function()
		self.search_box.textbox.prompt:SetString(STRINGS.UI.CRAFTING_FILTERS[filter_def.name])
	end)
	button:SetHoverText(STRINGS.UI.CRAFTING_FILTERS[filter_def.name], {offset_y = 30})

	w.focus_forward = button

	----------------
	local filter_atlas = FunctionOrValue(filter_def.atlas, self.owner, filter_def)
	local filter_image = FunctionOrValue(filter_def.image, self.owner, filter_def)

	local filter_img = button:AddChild(Image(filter_atlas, filter_image))
	--filter_img:SetTint(0, 0, 0, 1)
	if filter_def.image_size ~= nil then
		filter_img:ScaleToSize(filter_def.image_size, filter_def.image_size)
	else
		filter_img:ScaleToSize(54, 54)
	end
	filter_img:MoveToBack()
	w.filter_img = filter_img

	w.filter_def = filter_def

	w.bg = button:AddChild(Image(atlas, "filterslot_bg.tex"))
	w.bg:MoveToBack()

	w.prototype_icon = button:AddChild(Image(atlas, "filterslot_prototype.tex")) 
	w.prototype_icon:Hide()

	return w
end

function CraftingMenuWidget:AddSorter()
    local btn = TEMPLATES.IconButton(self.sort_modes[1].atlas, self.sort_modes[1].img)
    btn:SetScale(0.7)
    btn.SetSortType = function(w, sort_mode)
		if sort_mode == nil or self.sort_modes[sort_mode] == nil then
			sort_mode = 1
		end

        w:SetHoverText( subfmt(STRINGS.UI.CRAFTING_MENU.SORT_MODE_FMT, { mode = self.sort_modes[sort_mode].str }) )
        w.icon:SetTexture(self.sort_modes[sort_mode].atlas, self.sort_modes[sort_mode].img )

		self.sort_fn = self.sort_modes[sort_mode].fn
		self.sort_mode = sort_mode
    end
    local function onclick()
        local sort_mode = self.sort_mode + 1
        if self.sort_modes[sort_mode] == nil then
            sort_mode = 1
        end

        btn:SetSortType(sort_mode)
		self:SortFilteredRecipes()
		TheCraftingMenuProfile:SetSortMode(sort_mode)
    end
    btn:SetOnClick(onclick)

	btn:SetSortType(TheCraftingMenuProfile:GetSortMode())

    return btn
end


function CraftingMenuWidget:MakeFilterPanel(width, height)
	width = width - 40
	local button_size = 38
	local grid_button_space = button_size + 5
	local grid_buttons_wide = math.floor(width/(button_size + 1))
	local grid_left = -grid_button_space * grid_buttons_wide/2 + grid_button_space/2

    local w = Widget("FilterPanel")

	local y = -2

	-- favorites filter button
	local favorites_filter = w:AddChild(self:MakeFilterButton(CRAFTING_FILTERS.FAVORITES, button_size))
	favorites_filter:SetPosition(grid_left, y)
	self.filter_buttons[CRAFTING_FILTERS.FAVORITES.name] = favorites_filter
	self.favorites_filter = favorites_filter

	-- special_event_filter
	local event_layout = IsAnySpecialEventActive()
	if event_layout then
		local special_event_filter = w:AddChild(self:MakeFilterButton(CRAFTING_FILTERS.SPECIAL_EVENT, button_size))
		special_event_filter:SetPosition(grid_left + grid_button_space, y)
		self.filter_buttons[CRAFTING_FILTERS.SPECIAL_EVENT.name] = special_event_filter

		local event_name
		if GetActiveSpecialEventCount() == 1 then
			event_name = STRINGS.UI.SPECIAL_EVENT_NAMES[string.upper(WORLD_SPECIAL_EVENT)]
		else
			event_name = STRINGS.UI.SPECIAL_EVENT_NAMES.MULTIPLE_EVENTS
		end
		special_event_filter.button:SetHoverText(event_name or "")
		--special_event_filter.filter_img:SetTexture(crafting_station_def.filter_atlas, crafting_station_def.filter_image)
		--special_event_filter.filter_img:ScaleToSize(54, 54)

		self.special_event_filter = special_event_filter
	end

	-- favorites filter button
	local filter_station = w:AddChild(self:MakeFilterButton(CRAFTING_FILTERS.CRAFTING_STATION, button_size))
	filter_station:SetPosition(grid_left + grid_button_space + (event_layout and grid_button_space or 0), y)
	self.filter_buttons[CRAFTING_FILTERS.CRAFTING_STATION.name] = filter_station
	self.crafting_station_filter = filter_station

	-- search bar
    self.search_box = w:AddChild(self:MakeSearchBox(grid_button_space * (event_layout and 5 or 6.5), 40))
	self.search_box:SetPosition(0, y)

	-- modded items filter button
	local filter_mods = w:AddChild(self:MakeFilterButton(CRAFTING_FILTERS.MODS, button_size))
	filter_mods:SetPosition(grid_left + grid_button_space * 9, y)
	self.filter_buttons[CRAFTING_FILTERS.MODS.name] = filter_mods
	self.mods_filter = filter_mods

	-- sort button
	self.sort_button = w:AddChild(self:AddSorter())
	self.sort_button:SetPosition(grid_left + grid_button_space * 10, y)

	y = y - button_size / 2

	-- Divider
	y = y - 5
	local line_height = 4
	local line = w:AddChild(Image("images/ui.xml", "line_horizontal_white.tex"))
	line:SetPosition(0, y - line_height/2)
    line:SetTint(unpack(BROWN))
	line:ScaleToSize(width, line_height)
	line:MoveToBack()
	y = y - line_height

	-- grid
	y = y - 8
	local filter_grid = w:AddChild(Grid())
    filter_grid:SetLooping(false, false)

	local widgets = {}
	for i, filter_def in ipairs(CRAFTING_FILTER_DEFS) do
		if not filter_def.custom_pos and (filter_def ~= CRAFTING_FILTERS.MODS or #filter_def.recipes > 0) then
			local w = self:MakeFilterButton(filter_def, button_size)
			self.filter_buttons[filter_def.name] = w
			table.insert(widgets, w)
		end
	end
	filter_grid:FillGrid(grid_buttons_wide, grid_button_space, grid_button_space, widgets)
	filter_grid:SetPosition(grid_left, y - 17)

	w.filter_grid = filter_grid
	w.focus_forward = filter_grid

	return w
end

function CraftingMenuWidget:MakeRecipeList(width, height)
    local cell_size = 60
    local row_w = cell_size
    local row_h = cell_size
    local row_spacing = 6
	local item_size = 94
	local atlas = resolvefilepath(CRAFTING_ATLAS)

    local function ScrollWidgetsCtor(context, index)
        local w = Widget("recipe-cell-".. index)

		w:SetScale(0.475)

		----------------
		w.cell_root = w:AddChild(ImageButton(atlas, "slot_frame.tex", "slot_frame_highlight.tex"))

		w.focus_forward = w.cell_root
        w.cell_root.ongainfocusfn = function() 
			self.recipe_grid:OnWidgetFocus(w)
			w.cell_root.recipe_held = false
			w.cell_root.last_recipe_click = nil
		end
		w.cell_root:SetWhileDown(function()
			if w.cell_root.recipe_held then
				DoRecipeClick(self.owner, w.data.recipe, self.details_root.skins_spinner:GetItem())
			end
		end)
		w.cell_root:SetOnDown(function()
			if w.cell_root.last_recipe_click and (GetTime() - w.cell_root.last_recipe_click) < 1 then
				w.cell_root.recipe_held = true
				w.cell_root.last_recipe_click = nil
			end
		end)
		w.cell_root:SetOnClick(function()
			local is_current = w.data == self.details_root.data
			self.details_root:PopulateRecipeDetailPanel(w.data)
			if w.data.meta.build_state == "buffered" then
				if not DoRecipeClick(self.owner, w.data.recipe, self.details_root.skins_spinner:GetItem()) then
					self.owner.HUD:CloseCrafting()
				end
			elseif is_current then -- clicking the item when it is already selected will trigger a build
				if not w.cell_root.recipe_held then
					local stay_open, error_msg = DoRecipeClick(self.owner, w.data.recipe, self.details_root.skins_spinner:GetItem())
					if not stay_open then
						self.owner.HUD:CloseCrafting()
					end
					if error_msg then
						SendRPCToServer(RPC.CannotBuild, error_msg)
					end
				end
			end
			w.cell_root.last_recipe_click = GetTime()
			w.cell_root.recipe_held = false
		end)

		----------------
		w.bg = w.cell_root:AddChild(Image(atlas, "slot_bg.tex"))
        w.item_img = w.bg:AddChild(Image("images/global.xml", "square.tex"))
        w.fg = w.bg:AddChild(Image("images/global.xml", "square.tex"))
		w.bg:MoveToBack()

		return w
    end
	
    local function ScrollWidgetSetData(context, widget, data, index)
		widget.data = data

		if data ~= nil and data.recipe ~= nil and data.meta ~= nil then
			-- see CraftSlot:Refresh() for more details on what needs to be done here
		
			local recipe = data.recipe
			local meta = data.meta

			widget.cell_root:Show()

			local image = recipe.imagefn ~= nil and recipe.imagefn() or recipe.image
			widget.item_img:SetTexture(recipe:GetAtlas(), image, image ~= recipe.image and recipe.image or nil)
			widget.item_img:ScaleToSize(item_size, item_size)
			
			widget.item_img:SetTint(1, 1, 1, 1)

			if meta.build_state == "buffered" then
				widget.bg:SetTexture(atlas, "slot_bg_buffered.tex")
				widget.fg:Hide()
			elseif meta.build_state == "prototype" then
				widget.bg:SetTexture(atlas, "slot_bg_prototype.tex")
				widget.fg:SetTexture(atlas, "slot_fg_prototype.tex")
				widget.fg:Show()
			elseif meta.can_build then
				widget.bg:SetTexture(atlas, "slot_bg.tex")
				widget.fg:Hide()
			elseif meta.build_state == "hint" then
				widget.bg:SetTexture(atlas, "slot_bg_missing_mats.tex")
				widget.item_img:SetTint(0.7, 0.7, 0.7, 1)
				widget.fg:SetTexture(atlas, "slot_fg_lock.tex")
                widget.fg:Show()
			else
				widget.bg:SetTexture(atlas, "slot_bg_missing_mats.tex")
				widget.item_img:SetTint(0.7, 0.7, 0.7, 1)
                
				--widget.fg:SetTexture(atlas, "slot_fg_missing_mats.tex")
                widget.fg:Hide()
			end

			widget:Enable()
		else
			widget:Disable()
			widget.cell_root:Hide()
		end
    end


	local grid = TEMPLATES.ScrollingGrid(
        {},
        {
            context = {},
            widget_width  = row_w+row_spacing,
            widget_height = row_h+row_spacing,
			peek_percent     = 0.5,
            num_visible_rows = 3,
            num_columns      = 7,
            item_ctor_fn = ScrollWidgetsCtor,
            apply_fn     = ScrollWidgetSetData,
            scrollbar_offset = 7,
            scrollbar_height_offset = -50
        })

	grid.up_button:SetTextures(atlas, "scrollbar_arrow_up.tex", "scrollbar_arrow_up_hl.tex")
    grid.up_button:SetScale(0.4)
	
	grid.down_button:SetTextures(atlas, "scrollbar_arrow_down.tex", "scrollbar_arrow_down_hl.tex")
    grid.down_button:SetScale(0.4)
	
	grid.scroll_bar_line:SetTexture(atlas, "scrollbar_bar.tex")
    grid.scroll_bar_line:ScaleToSize(11, grid.scrollbar_height - 15)

	grid.position_marker:SetTextures(atlas, "scrollbar_handle.tex")
	grid.position_marker.image:SetTexture(atlas, "scrollbar_handle.tex")
    grid.position_marker:SetScale(.3)

	return grid
end


return CraftingMenuWidget





