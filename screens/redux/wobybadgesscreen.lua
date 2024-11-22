local Image = require "widgets/image"
local ImageButton = require "widgets/imagebutton"
local Menu = require "widgets/menu"
local Screen = require "widgets/screen"
local Text = require "widgets/text"
local UIAnim = require "widgets/uianim"
local Widget = require "widgets/widget"

local TEMPLATES = require("widgets/redux/templates")

--------------------------------------------------------------------------------------------------------------------

local SCREEN_OFFSET = -.38 * RESOLUTION_X

local NUM_BADGES_PER_ROW = 5

local DISABLED_BADGE_COLOUR = .4

local BADGE_FOCUS_SCALE = { 1.05, 1.05, 1.05 }
local BADGE_FOCUS_SCALE_DISABLED = { 1, 1, 1 }

local ATLAS_1 = "images/woby_badges.xml"
local ATLAS_2 = "images/woby_badges2.xml"

local BADGE_DEFAULT = "badge_empty.tex"
local BADGE_IMAGE_FMT = "badge_%s.tex"
local BADGE_LABEL_IMAGE_FMT = "badge_label_%d.tex"
local BADGE_HOVER_IMAGE_FMT = "badge_select_%d.tex"

local PIN_COLORS =
{
    { 148/255, 18/255,  18/255  }, -- red
    { 49/255,  131/255, 63/255  }, -- green
    { 231/255, 191/255, 69/255  }, -- yellow
    { 41/255,  103/255, 188/255 }, -- blue
    { 239/255, 239/255, 238/255 }, -- white
}

--------------------------------------------------------------------------------------------------------------------

local SlotsText = Class(Text, function(self, font, size, colour)
    self.text_fmt = "%d/"..tostring(TUNING.SKILLS.WALTER.WOBY_MAX_BADGES_SLOTS or "?")

    Text._ctor(self, font, size, self.text_fmt:format(0), colour)
end)

function SlotsText:UpdateNumOccupiedSlots(n)
    self:SetString(self.text_fmt:format(n))
end

--------------------------------------------------------------------------------------------------------------------

local BadgeNameLabel = Class(Widget, function(self, name)
    Widget._ctor(self, name or "BadgeName")

    self.imagebox = self:AddChild(Image(ATLAS_1, BADGE_LABEL_IMAGE_FMT:format(math.random(3))))
    self.imagebox:SetScale(0.35)

    self.name = self:AddChild(Text(HEADERFONT, 15, STRINGS.UI.WOBY_BADGES_POPUP.BADGES.EMPTY_SLOT, UICOLOURS.BLACK))
    self.name:SetHAlign(ANCHOR_MIDDLE)
    self.name:SetPosition(0, -1)

    self:SetColour(DISABLED_BADGE_COLOUR, DISABLED_BADGE_COLOUR, DISABLED_BADGE_COLOUR, 1)

    self:SetRotation((math.random() * 5 - 2.5 + 360) % 360)
end)

function BadgeNameLabel:UpdateString(str)
    self.name:SetString(str)
end

function BadgeNameLabel:SetColour(r, g, b, a)
    self.imagebox:SetTint(r, g, b, a)
end

--------------------------------------------------------------------------------------------------------------------

local Badge = Class(ImageButton, function(self, context, index)
    ImageButton._ctor(self)

    self.screen = context.screen
    self.badgedata = nil

    self.NUM_BADGES_PER_ROW = NUM_BADGES_PER_ROW
    self.BADGE_SIZE = 680/self.NUM_BADGES_PER_ROW - 45

    self:SetTextures(
        ATLAS_1,
        BADGE_DEFAULT,    -- normal
        BADGE_DEFAULT,    -- focus
        BADGE_DEFAULT,    -- disabled
        BADGE_DEFAULT,    -- down
        BADGE_DEFAULT     -- selected
    )

    self.image:SetRotation((math.random() * 12 - 6 + 360) % 360)

    self:UseFocusOverlay("badge_select_1.tex")

    self.ignore_standard_scaling = true
    self.move_on_click = false

    self:SetFocusScale(BADGE_FOCUS_SCALE_DISABLED)
    self:ForceImageSize(self.BADGE_SIZE, self.BADGE_SIZE)

    self.namelabel = self:AddChild(BadgeNameLabel())
    self.namelabel:SetPosition(0, self.BADGE_SIZE/2 + 20, 0)

    self.progressbar_root = self:AddChild(Widget("progressbar_root"))
    self.progressbar_root:SetPosition(0, -self.BADGE_SIZE/2 - 15)
    self.progressbar_root:SetRotation((math.random() * 3 - 1.5 + 360) % 360)
    self.progressbar_root:Hide()

    self.progressbar = self.progressbar_root:AddChild(UIAnim())
    self.progressbar:GetAnimState():SetBank("woby_badge_progressbar")
    self.progressbar:GetAnimState():SetBuild("woby_badge_progressbar")
    self.progressbar:GetAnimState():PlayAnimation("fill_progress", true)
    self.progressbar:GetAnimState():SetPercent("fill_progress", 0)
    self.progressbar:SetPosition(5, 0)
    self.progressbar:SetScale(.6)

    self.percentage = self.progressbar_root:AddChild(Text(HEADERFONT, 14, nil, UICOLOURS.BLACK))
    self.percentage:SetPosition(-self.BADGE_SIZE/2 - 5, 0)
    self.percentage:SetRegionSize(35, 15)
    self.percentage:SetHAlign(ANCHOR_RIGHT)

    self.pin = self:AddChild(UIAnim())
    self.pin._scale = .275
    self.pin:GetAnimState():SetBank("woby_badge_pin")
    self.pin:GetAnimState():SetBuild("woby_badge_pin")
    self.pin:GetAnimState():PlayAnimation("pin")
    self.pin:SetScale(self.pin._scale)
    self.pin:Hide()

    self:SetOnClick(function() self:OnClicked() end)
end)

function Badge:SetBadgeType(data)
    self.badgedata = data

    self.namelabel:UpdateString(STRINGS.UI.WOBY_BADGES_POPUP.BADGES[string.upper(data.name)] or data.name)

    self.percentage:SetString(string.format("%0.0f%%", data.progress*100))

    self.progressbar_root:Show()

    self.progressbar:GetAnimState():SetPercent("fill_progress", data.progress)

    local texture = BADGE_IMAGE_FMT:format(data.name)

    self:SetTextures(
        ATLAS_1,
        texture,          -- normal
        texture,    -- focus
        texture,    -- disabled
        texture,    -- down  ---------- THIS IS ALSO FOCUS.
        texture           -- selected
    )

    self.BADGE_SIZE = 680/self.NUM_BADGES_PER_ROW - (data.level == 1 and 45 or 25)

    self:UseFocusOverlay(BADGE_HOVER_IMAGE_FMT:format(data.level))

    self:ForceImageSize(self.BADGE_SIZE, self.BADGE_SIZE)

    self.progressbar_root:SetPosition(0, -self.BADGE_SIZE/2 - 15)
    self.namelabel:SetPosition(0, self.BADGE_SIZE/2 + 20, 0)

    self:ToggleEnabledState(data.active)

    self:SetFocusScale(BADGE_FOCUS_SCALE)
end

function Badge:ToggleEnabledState(enabled)
    local colour = enabled and 1 or DISABLED_BADGE_COLOUR

    self.screen.enabled_badges[self] = enabled or nil

    self.screen.slots_str:UpdateNumOccupiedSlots(self.screen:GetNumCurrentOccupiedSlots())

    self:SetImageNormalColour(colour, colour, colour, 1)
    self.image:SetTint(colour, colour, colour, 1)
    self.namelabel:SetColour(colour, colour, colour, 1)
    self.progressbar:GetAnimState():SetMultColour(colour, colour, colour, 1)

    if enabled then
        self.pin:Show()

        local offset = (self.badgedata.level == 1 and 0 or 7.5)

        self.pin._pos_y = self.BADGE_SIZE/2 - offset - 0

        self.pin:SetPosition(math.random() * 14 - 7, self.pin._pos_y)
        self.pin:SetRotation((math.random() * 30 - 15 + 360) % 360)

        -- Try to have all possible colours in the board.
        self.pin.colour = table.remove(self.screen.PIN_COLOURS, math.random(#self.screen.PIN_COLOURS)) or GetRandomItem(PIN_COLORS)

        local r, g, b = unpack(self.pin.colour)

        self.pin:GetAnimState():SetSymbolMultColour("colour", r, g, b, 1)
    else
        self.pin:Hide()

        if self.pin.colour ~= nil then
            table.insert(self.screen.PIN_COLOURS, self.pin.colour)

            self.pin.colour = nil
        end
    end
end

function Badge:OnClicked()
    if self.badgedata == nil then
        return -- Empty spot, we were able to click if somehow...
    end

    self.image:ScaleToSize(self.size_x*self.focus_scale[1], self.size_y*self.focus_scale[2]) -- Keep "focus" scale.

    if self.screen.enabled_badges[self] ~= nil then
        self:ToggleEnabledState(false)

        self.screen.dirty = true

    elseif (self.screen:GetNumCurrentOccupiedSlots() + self.badgedata.level) <= TUNING.SKILLS.WALTER.WOBY_MAX_BADGES_SLOTS then
        self:ToggleEnabledState(true)

        self.screen.dirty = true

    else
        -- You can't enable more badges.
        TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_negative")
    end
end

function Badge:UseFocusOverlay(...)
    self._base.UseFocusOverlay(self, ...)

    local badge_size = self.image:GetSize()

    -- self.hover_overlay is added by base UseFocusOverlay.
    self.hover_overlay:ScaleToSize(badge_size + 8, badge_size + 8)
    self.hover_overlay:MoveToBack()
end

function Badge:OnGainFocus()
    if self.stopclicksound then
        return -- Empty badge.
    end

    self._base.OnGainFocus(self)

    if self:IsSelected() or self:IsDisabledState() or not self:IsEnabled() then
        return
    end

    if self.pin ~= nil and self.pin._scale ~= nil and self.pin._pos_y then
        if self.ignore_standard_scaling and self.focus_scale then
            self.pin:SetScale(self.pin._scale*self.focus_scale[1])

            self.pin:SetPosition(self.pin:GetPosition().x, self.pin._pos_y * self.focus_scale[1])
        else
            self.pin:SetScale(self.pin._scale)
        end
    end
end

function Badge:OnLoseFocus()
    if self.stopclicksound then
        return -- Empty badge.
    end

    self._base.OnLoseFocus(self)

    if self:IsSelected() or self:IsDisabledState() or not self:IsEnabled() then
        return
    end

    if self.pin ~= nil and self.pin._scale ~= nil and self.pin._pos_y then
        if self.ignore_standard_scaling and self.normal_scale then
            self.pin:SetScale(self.pin._scale*self.normal_scale[1])

            self.pin:SetPosition(self.pin:GetPosition().x, self.pin._pos_y * self.normal_scale[1])
        else
            self.pin:SetScale(self.pin._scale)
        end
    end
end

--------------------------------------------------------------------------------------------------------------------

local function ScrollWidgetSetData(context, widget, data, index)
    if data == nil then
        widget:Hide()

        return
    end

    widget:Show()

    if context.screen:ShouldShowBadge(data) then
        widget:SetBadgeType(data)
    else
        widget.empty = true

        local badge_size = 680/context.screen.NUM_BADGES_PER_ROW - (data.level == 1 and 45 or 25)

        widget.namelabel:SetPosition(0, badge_size/2 + 20, 0)

        widget.stopclicksound = true
    end
end

--------------------------------------------------------------------------------------------------------------------

local BADGE_FMT = "%s_%d"
local BADGE_SKILL_FMT = "walter_woby_badge_%s_%d"

local WobyBadgesScreen = Class(Screen, function(self, owner, trainingdata)
    Screen._ctor(self, "WobyBadgesScreen")

    self.NUM_BADGES_PER_ROW = NUM_BADGES_PER_ROW
    self.ASPECTS_IDS = table.invert(WOBY_TRAINING_ASPECTS_LIST)

    self.enabled_badges = { --[[ badge = true ]]} -- NOTE(DiogoW): This rely on all badges being visible to work...

    self.owner = owner
    self.data = self:DecodeTrainingData(trainingdata)

    self.PIN_COLOURS = deepcopy(PIN_COLORS)

    self.dirty = false

    self:DoInit()

    TheCamera:PushScreenHOffset(self, SCREEN_OFFSET)

    SetAutopaused(true)
end)

function WobyBadgesScreen:DoInit()
    self.root = self:AddChild(TEMPLATES.ScreenRoot())

    self.bg = self.root:AddChild(Image("images/bg_redux_wardrobe_bg.xml", "wardrobe_bg.tex"))
    self.bg:SetScale(0.8)
    self.bg:SetPosition(-200, 0)
    self.bg:SetTint(1, 1, 1, 0.76)

    self.box_root = self.root:AddChild(Widget("box_root"))
    self.box_root:SetPosition(-200 * 0.8, 0) -- BG pos * scale.

    self.box = self.box_root:AddChild(Image(ATLAS_2, "badge_bg.tex"))
    self.box:SetScale(.65)

    self.slots_str = self.box_root:AddChild(SlotsText(HEADERFONT, 26))
    self.slots_str:SetPosition(-12, 220)

    self.badges_bar = self.box_root:AddChild(
        TEMPLATES.ScrollingGrid(
            self:GetGridItems(),
            {
                scroll_context = { screen = self },
                widget_width  = 680/self.NUM_BADGES_PER_ROW,
                widget_height = 680/self.NUM_BADGES_PER_ROW+50,
                force_peek    = true,
                num_visible_rows = 2,
                num_columns      = self.NUM_BADGES_PER_ROW,
                item_ctor_fn = Badge,
                apply_fn     = ScrollWidgetSetData,
                scrollbar_offset = 20,
                scrollbar_height_offset = -70
            }
        )
    )

    self.badges_bar:SetPosition(0, -30)

    self.slots_str:MoveToFront()

    local buttons =
    {
        { text = STRINGS.UI.WOBY_BADGES_POPUP.CANCEL, cb = function() self:Cancel()       end },
        { text = STRINGS.UI.WOBY_BADGES_POPUP.SAVE,   cb = function() self:SaveAndClose() end },
    }

    self.menu = self.root:AddChild(Menu(buttons, 70, false, "carny_long", nil, 30))
    self.menu:SetMenuIndex(3)
    self.menu:SetPosition(493, -260, 0)

    -- Hide the menu if the player is using a controller; we'll control this with button presses that are listed in the helpbar.
    if TheInput:ControllerAttached() then
        self.menu:Hide()
        self.menu:Disable()
    end

    self.default_focus = self.badges_bar
end

function WobyBadgesScreen:DecodeTrainingData(data)
    data = string.len(data) > 0 and DecodeAndUnzipString(data) or nil

    local ret = {}

    if data == nil then
        return ret
    end

    local fields = 3 -- Baded on DogTrainer:ZipAndEncodeData()
    local aspect, bitlevels

    for i = 1, #data, fields do
        aspect = WOBY_TRAINING_ASPECTS_LIST[data[i]]

        if aspect ~= nil then
            ret[aspect] = {
                percentage = data[i + 1] / 100,
                active = {},
            }

            bitlevels = data[i + 2]

            for j=1, NUM_WOBY_TRAINING_ASPECTS_LEVELS do
                ret[aspect].active[BADGE_FMT:format(aspect, j)] = checkbit(bitlevels, 2^(j-1))
            end
        end
    end

    return ret
end

function WobyBadgesScreen:GetGridItems()
    local items = {}

    for i, aspect in ipairs(WOBY_TRAINING_ASPECTS_LIST) do
        for j=1, NUM_WOBY_TRAINING_ASPECTS_LEVELS do
            local badge_name = BADGE_FMT:format(aspect, j)
            local aspect_data = self.data[aspect]

            table.insert(items,
            {
                name = badge_name,
                index = i + (self.NUM_BADGES_PER_ROW * (j-1)),
                aspect = aspect,
                level = j,
                skill = BADGE_SKILL_FMT:format(string.lower(aspect), j),
                progress = aspect_data ~= nil and aspect_data.percentage or 0,
                active = aspect_data ~= nil and aspect_data.active[badge_name] or false,
            })
        end
    end

    table.sort(items, function(a, b) return a.index < b.index end )

    return items
end

function WobyBadgesScreen:GetNumCurrentOccupiedSlots()
    local ret = 0

    for widget, _ in pairs(self.enabled_badges) do
        if widget.badgedata ~= nil then
            ret = ret + widget.badgedata.level
        end
    end

    return ret
end

function WobyBadgesScreen:ShouldShowBadge(badgedata)
    local skilltreeupdater = self.owner.components.skilltreeupdater

    if skilltreeupdater == nil then
        return false
    end

    return skilltreeupdater:IsActivated(badgedata.skill)
end

function WobyBadgesScreen:OnDestroy()
    TheCamera:PopScreenHOffset(self, SCREEN_OFFSET)

    SetAutopaused(false)

    self._base.OnDestroy(self)
end

function WobyBadgesScreen:OnBecomeInactive()
    self._base.OnBecomeInactive(self)
end

function WobyBadgesScreen:OnBecomeActive()
    self._base.OnBecomeActive(self)

    if TheInput:ControllerAttached() then
        self.default_focus:SetFocus()
    end
end

------------------------------------------------------------------------------------------------------------------

-- Menu buttons

function WobyBadgesScreen:Cancel()
    POPUPS.WOBYBADGECUSTOMIZATION:Close(self.owner)

    TheFrontEnd:PopScreen(self)
end

function WobyBadgesScreen:SaveAndClose()
    if not self.dirty then
        self:Cancel()

        return
    end

    local data = {}
    local n

    for widget, _ in pairs(self.enabled_badges) do
        if widget.badgedata ~= nil then
            n = #data

            data[n + 1] = self.ASPECTS_IDS[widget.badgedata.aspect] or -1
            data[n + 2] = widget.badgedata.level
        end
    end

    POPUPS.WOBYBADGECUSTOMIZATION:Close(self.owner, #data > 0 and ZipAndEncodeString(data) or nil)

    TheFrontEnd:PopScreen(self)
end

------------------------------------------------------------------------------------------------------------------

-- Controller Support

function WobyBadgesScreen:OnControl(control, down)
    if self._base.OnControl(self, control, down) then
        return true
    end

    if down then
        return false
    end

    if control == CONTROL_MENU_BACK or control == CONTROL_CANCEL then
        TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_move")

        self:Cancel()

        return true

    elseif control == CONTROL_MENU_START then
        TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_move")

        self:SaveAndClose()

        return true
    end

    return false
end

function WobyBadgesScreen:GetHelpText()
    local controller_id = TheInput:GetControllerID()

    local ret = {
        TheInput:GetLocalizedControl(controller_id, CONTROL_CANCEL) .. " " .. STRINGS.UI.WOBY_BADGES_POPUP.CANCEL,
        TheInput:GetLocalizedControl(controller_id, CONTROL_MENU_START) .. " " .. STRINGS.UI.WOBY_BADGES_POPUP.SAVE,
    }

    return table.concat(ret, "  ")
end

------------------------------------------------------------------------------------------------------------------

return WobyBadgesScreen
