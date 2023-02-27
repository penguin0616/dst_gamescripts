local Screen = require "widgets/screen"
local Widget = require "widgets/widget"
local ImageButton = require "widgets/imagebutton"
local TEMPLATES = require "widgets/redux/templates"
local Text = require "widgets/text"
local SkillTreeWidget = require "widgets/redux/skilltreewidget"

local SkillTreePopupScreen = Class(Screen, function(self, owner, player_name, data, show_net_profile, force)
    self.owner = owner
    self.data = data or self.owner.components.playeravatardata:GetData()
    self.player_name = player_name or self.data.name
    self.show_net_profile = show_net_profile
    self.force = force

    Screen._ctor(self, "SkillTreePopupScreen")
--[[
    local black = self:AddChild(ImageButton("images/global.xml", "square.tex"))
    black.image:SetVRegPoint(ANCHOR_MIDDLE)
    black.image:SetHRegPoint(ANCHOR_MIDDLE)
    black.image:SetVAnchor(ANCHOR_MIDDLE)
    black.image:SetHAnchor(ANCHOR_MIDDLE)
    black.image:SetScaleMode(SCALEMODE_FILLSCREEN)
    black.image:SetTint(0,0,0,.5)
    black:SetOnClick(function() TheFrontEnd:PopScreen() end)
    black:SetHelpTextMessage("")
]]
	self.root = self:AddChild(Widget("root"))
	self.root:SetScaleMode(SCALEMODE_PROPORTIONAL)
    self.root:SetHAnchor(ANCHOR_MIDDLE)
    self.root:SetVAnchor(ANCHOR_MIDDLE)
	self.root:SetPosition(0,0)

    self:MakeTabs()
    self:MakeSkillTree()

	--self.default_focus = self.plantregistry

    --SetAutopaused(true)
end)

function SkillTreePopupScreen:MakeTabs()
    self.root.tabs = self.root:AddChild(Widget("tabs"))
    self.root.tabs:SetPosition(0,0)
    self.root.tabs.playerAvatarPopup = self.root.tabs:AddChild(ImageButton("images/frontend.xml","button_long.tex","button_long.tex","button_long_disabled.tex","button_long_down.tex","button_long_highlight.tex"))
    self.root.tabs.playerAvatarPopup:SetPosition(80,250)
    self.root.tabs.playerAvatarPopup:SetScale(.5)
    self.root.tabs.playerAvatarPopup:SetFont(CHATFONT)
    self.root.tabs.playerAvatarPopup.text:SetColour(0,0,0,1)
    self.root.tabs.playerAvatarPopup:SetText(STRINGS.SKILLTREE.INFOPANEL)
    self.root.tabs.playerAvatarPopup:SetOnClick(function()
        TheFrontEnd:PopScreen()
        self.owner.HUD:OpenPlayerAvatarPopup(self.player_name, self.data, self.show_net_profile, self.force)       
    end)
    
    self.root.tabs.skillTreePopup = self.root.tabs:AddChild(ImageButton("images/frontend.xml","button_long.tex","button_long.tex","button_long_disabled.tex","button_long_down.tex","button_long_highlight.tex"))
    self.root.tabs.skillTreePopup:SetPosition(-80,250)
    self.root.tabs.skillTreePopup:SetScale(.5)
    self.root.tabs.skillTreePopup:SetFont(CHATFONT)
    self.root.tabs.skillTreePopup.text:SetColour(0,0,0,1)
    self.root.tabs.skillTreePopup:SetText(STRINGS.SKILLTREE.SKILLTREE)
    self.root.tabs.skillTreePopup:Disable()
end

function SkillTreePopupScreen:MakeSkillTree()
    self.skilltree = self.root:AddChild(SkillTreeWidget(self.owner))
end

function SkillTreePopupScreen:OnDestroy()
    --SetAutopaused(false)

    POPUPS.SKILLTREE:Close(self.owner)

	SkillTreePopupScreen._base.OnDestroy(self)
end

function SkillTreePopupScreen:OnBecomeInactive()
    SkillTreePopupScreen._base.OnBecomeInactive(self)
end

function SkillTreePopupScreen:OnBecomeActive()
    SkillTreePopupScreen._base.OnBecomeActive(self)
end

function SkillTreePopupScreen:OnControl(control, down)
    if SkillTreePopupScreen._base.OnControl(self, control, down) then return true end

    if not down and (control == CONTROL_MAP or control == CONTROL_CANCEL) then
		TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_move")
        TheFrontEnd:PopScreen()
        return true
    end

	return false
end

function SkillTreePopupScreen:GetHelpText()
    local controller_id = TheInput:GetControllerID()
    local t = {}

    table.insert(t,  TheInput:GetLocalizedControl(controller_id, CONTROL_CANCEL) .. " " .. STRINGS.UI.HELP.BACK)

    return table.concat(t, "  ")
end

return SkillTreePopupScreen
