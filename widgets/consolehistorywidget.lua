local Widget = require "widgets/widget"
local Text = require "widgets/text"
local ImageButton = require "widgets/imagebutton"
local Button = require "widgets/button"
local Image = require "widgets/image"

local FONT_SIZE = 22
local PADDING = 10

local MAX_LINES = 10

local ConsoleHistoryWidget = Class(Widget, function(self, text_edit, max_width, mode)
    Widget._ctor(self, "ConsoleHistoryWidget")

	self.text_edit = text_edit

	local function onwordpredictionupdated()
		if self:IsVisible() then
			self:Hide()
		end
	end
	self.text_edit.inst:ListenForEvent("onwordpredictionupdated", onwordpredictionupdated)

	self.enter_complete = string.match(mode, "enter", 1, true) ~= nil
	self.tab_complete = string.match(mode, "tab", 1, true) ~= nil

	self.sizey = FONT_SIZE + 4
	self.max_width = max_width or 300

	local root = self:AddChild(Widget("consolehistorywidget_root"))
	root:SetPosition(0, self.sizey * 0.5)

    self.backing = root:AddChild(Image("images/ui.xml", "black.tex"))
    self.backing:SetTint(1,1,1,.8)
	self.backing:SetPosition(-5, 0)
    self.backing:SetHRegPoint(ANCHOR_LEFT)

	self.history_root = root:AddChild(Widget("history_root"))

	self.starting_offset_x = 0

	local dismiss_btn = root:AddChild(ImageButton("images/global_redux.xml", "close.tex"))
	dismiss_btn:SetOnClick(function()
		self:Dismiss()
		TheFrontEnd:SetConsoleLogPosition(0, 0, 0)
	end)
	dismiss_btn:SetNormalScale(.50)
	dismiss_btn:SetFocusScale(.50)
	dismiss_btn:SetImageNormalColour(UICOLOURS.GREY)
	dismiss_btn:SetImageFocusColour(UICOLOURS.WHITE)
	dismiss_btn:SetPosition(10, 0)
	dismiss_btn:SetHoverText(STRINGS.UI.WORDPREDICTIONWIDGET.DISMISS)
	self.starting_offset_x = 20 + PADDING
end)

function ConsoleHistoryWidget:IsMouseOnly()
	return self.enter_complete == false and self.tab_complete == false
end

function ConsoleHistoryWidget:OnRawKey(key, down)

	if key == KEY_TAB then
		return self.tab_complete
	elseif key == KEY_ENTER then
		return self.enter_complete
	elseif key == KEY_UP and not self:IsMouseOnly() then
		if down and self.active_selection_btn > 1 then
			self.selection_btns[self.active_selection_btn - 1]:Select()
		end
		return true
	elseif key == KEY_DOWN and not self:IsMouseOnly() then
		if down and self.active_selection_btn < #self.selection_btns then
			self.selection_btns[self.active_selection_btn + 1]:Select()
		end
		return true
	elseif key == KEY_ESCAPE then
		return true
	end

	return false
end

function ConsoleHistoryWidget:OnControl(control, down)
    if ConsoleHistoryWidget._base.OnControl(self,control, down) then return true end

	if control == CONTROL_CANCEL then
		if not down then
			self:Dismiss()
		end
		return true
	elseif control == CONTROL_ACCEPT then
		if self.enter_complete then
			if not down then
				self.text_edit:ApplyWordPrediction(self.active_selection_btn)
			end
			return true
		end
	end

	return false
end

function ConsoleHistoryWidget:Show(history, index)
	self._base.Show(self)
	self:Enable()
	self:RefreshHistory(history, index)
end

function ConsoleHistoryWidget:Hide()
	self._base.Hide(self)
	self:Disable()
	TheFrontEnd:SetConsoleLogPosition(0, 0, 0)
end

function ConsoleHistoryWidget:Dismiss()
	self.selection_btns = {}
	self.active_selection_btn = nil
	self.history_root:KillAllChildren()

	self:Hide()
	self:Disable()
end

function ConsoleHistoryWidget:RefreshHistory(history, index)
	if history == nil then
		return
	end

	local console_history = {}
	--local console_localremote_history = {}
	shallowcopy(history, console_history)
	--shallowcopy(ConsoleScreenSettings:GetConsoleLocalRemoteHistory(), console_localremote_history)

	if #console_history <= 0 then
		return
	end

	console_history = table.reverse(console_history)
	--console_localremote_history = table.reverse(console_history)

	-- Index is reversed, so need to account for this
	self.active_selection_btn = index and (#console_history - index + 1) or nil
	local start_offset = self.active_selection_btn ~= nil and self.active_selection_btn > MAX_LINES and self.active_selection_btn - MAX_LINES or 0

	self.selection_btns = {}
	self.history_root:KillAllChildren()

	local offset_x = self.starting_offset_x
	local offset_y = 0
	local backing_width = 0
	local backing_height = self.sizey + 4

	for i, v in ipairs(console_history) do
		if i > MAX_LINES + start_offset then
			break
		elseif i > start_offset then
			local btn = self.history_root:AddChild(Button())
			btn:SetFont(CHATFONT)
			btn:SetDisabledFont(CHATFONT)
			btn:SetTextColour(UICOLOURS.GOLD_CLICKABLE)
			btn:SetTextFocusColour(UICOLOURS.GOLD_CLICKABLE)
			btn:SetTextSelectedColour(UICOLOURS.GOLD_FOCUS)
			btn:SetText(v)
			btn:SetTextSize(FONT_SIZE)
			btn.clickoffset = Vector3(0,0,0)

			btn.bg = btn:AddChild(Image("images/ui.xml", "blank.tex"))
			local w,h = btn.text:GetRegionSize()
			btn.bg:ScaleToSize(w, h)
			btn.bg:SetPosition(0,0)
			btn.bg:MoveToBack()

			btn:SetOnClick(function()
				if self.active_selection_btn ~= nil then
					self.text_edit:SetString(v)
				end
			end)
			btn:SetOnSelect(function()
				if self.active_selection_btn ~= nil and self.active_selection_btn ~= i - start_offset then
					self.selection_btns[self.active_selection_btn]:Unselect()
				end
				self.active_selection_btn = i
			end)
			btn.ongainfocus = function()
				btn:Select()
				self.text_edit:SetEditing(false)
				self.active_selection_btn = self.active_selection_btn - start_offset
			end
			btn.AllowOnControlWhenSelected = true

			if self:IsMouseOnly() then
				btn.onlosefocus = function() if btn.selected then btn:Unselect() self.active_selection_btn = nil end end
			end

			local sx, sy = btn.text:GetRegionSize()
			btn:SetPosition(sx * 0.5 + offset_x, offset_y)
			offset_y = offset_y + backing_height

			backing_width = offset_x > backing_width and offset_x or backing_width

			table.insert(self.selection_btns, btn)
		end
	end

	if self:IsMouseOnly() then
		self.active_selection_btn = nil
	else
		self.active_selection_btn = self.active_selection_btn - start_offset or 1
		if self.active_selection_btn > 0 then
			print("update", self.active_selection_btn)
			self.selection_btns[self.active_selection_btn or 1]:Select()
		end
	end

	local num_rows = math.min(#console_history, MAX_LINES)
	self.backing:SetSize(self.max_width, backing_height * num_rows)
	self.backing:SetPosition(-5, backing_height * (num_rows - 1) * 0.5)
	TheFrontEnd:SetConsoleLogPosition(0, (backing_height + self.sizey * 0.5) * (num_rows - 1), 0)
end

return ConsoleHistoryWidget
