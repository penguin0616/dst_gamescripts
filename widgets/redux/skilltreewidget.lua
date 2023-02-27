local Image = require "widgets/image"
local ImageButton = require "widgets/imagebutton"
local Widget = require "widgets/widget"
local Text = require "widgets/text"
local TEMPLATES = require "widgets/redux/templates"
local skilltreedefs = require "prefabs/skilltree_defs"
local skilltreebuilder = require "widgets/redux/skilltreebuilder"
local UIAnim = require "widgets/uianim"

require("util")

-------------------------------------------------------------------------------------------------------
local SkillTreeWidget = Class(Widget, function(self, prefabname, targetdata, fromfrontend)
    Widget._ctor(self, "SkillTreeWidget")

    self.fromfrontend = fromfrontend
    self.targetdata = targetdata

    self.target = prefabname
    if self.targetdata.inst then
        self.target = self.targetdata.inst.prefab
    end

    self.root = self:AddChild(Widget("root"))

    self.midlay = self.root:AddChild(Widget())

    self.bg_tree = self.root:AddChild(Image("images/skilltree2.xml", "wilson_background_shadowbranch_white.tex"))
    self.bg_tree:SetPosition(2,-20)
    self.bg_tree:ScaleToSize(600, 460)

    if self.fromfrontend then
        local color = UICOLOURS.GOLD
        self.bg_tree:SetTint(color[1],color[2],color[3],0.6)
    else 
        local color = UICOLOURS.BLACK
        self.bg_tree:SetTint(color[1],color[2],color[3],1)
    end

    self.root.infopanel = self.root:AddChild(Widget("infopanel"))
    self.root.infopanel:SetPosition(0,-148)

    self.root.infopanel.bg = self.root.infopanel:AddChild(Image("images/skilltree.xml", "wilson_background_text.tex"))
    self.root.infopanel.bg:ScaleToSize(470, 130)
    self.root.infopanel.bg:SetPosition(0, -10)

    self.root.infopanel.activatebutton = self.root.infopanel:AddChild(ImageButton("images/global_redux.xml", "button_carny_long_normal.tex", "button_carny_long_hover.tex", "button_carny_long_disabled.tex", "button_carny_long_down.tex"))
    self.root.infopanel.activatebutton.image:SetScale(1)
    self.root.infopanel.activatebutton:SetFont(CHATFONT)
    self.root.infopanel.activatebutton:SetPosition(0,-37)
    self.root.infopanel.activatebutton.text:SetColour(0,0,0,1)
    self.root.infopanel.activatebutton:SetScale(0.5)
    self.root.infopanel.activatebutton:SetText(STRINGS.SKILLTREE.ACTIVATE)

    self.root.infopanel.activatedtext = self.root.infopanel:AddChild(Text(HEADERFONT, 18, STRINGS.SKILLTREE.ACTIVATED, UICOLOURS.BLACK))
    self.root.infopanel.activatedtext:SetPosition(0,-37)
    self.root.infopanel.activatedtext:SetSize(20)

    self.root.infopanel.title = self.root.infopanel:AddChild(Text(HEADERFONT, 18, "title", UICOLOURS.BROWN_DARK))
    self.root.infopanel.title:SetPosition(0,28)
    self.root.infopanel.title:SetVAlign(ANCHOR_TOP)

    self.root.infopanel.desc = self.root.infopanel:AddChild(Text(CHATFONT, 13, "desc", UICOLOURS.BROWN_DARK))
    self.root.infopanel.desc:SetPosition(0,0)
    self.root.infopanel.desc:SetHAlign(ANCHOR_LEFT)
    self.root.infopanel.desc:SetVAlign(ANCHOR_TOP)
    self.root.infopanel.desc:SetMultilineTruncatedString(STRINGS.SKILLTREE.INFOPANEL_DESC, 3, 400, nil,nil,true,6)
    self.root.infopanel.desc:Hide()

    self.root.infopanel.intro = self.root.infopanel:AddChild(Text(CHATFONT, 18, "desc", UICOLOURS.BROWN_DARK))
    self.root.infopanel.intro:SetPosition(0,-10)
    self.root.infopanel.intro:SetHAlign(ANCHOR_LEFT)
    self.root.infopanel.intro:SetString(STRINGS.SKILLTREE.INFOPANEL_DESC)


    self.root.tree = self.root:AddChild(skilltreebuilder(self.root.infopanel, self.fromfrontend, self))
    self.root.tree:SetPosition(0,-50)

    if not self.fromfrontend then
        self.root.scroll_left  = self.root:AddChild(Image("images/skilltree2.xml", "overlay_left.tex"))
        self.root.scroll_left:ScaleToSize(44, 460)
        self.root.scroll_left:SetPosition(-278,-20)
        self.root.scroll_right = self.root:AddChild(Image("images/skilltree2.xml", "overlay_right.tex"))
        self.root.scroll_right:ScaleToSize(44, 460)
        self.root.scroll_right:SetPosition(278,-20)
    end

    self.readonly = self.target ~= prefabname
    if not self.readonly then
        if ThePlayer then
            ThePlayer.new_skill_available_popup = nil
            ThePlayer:PushEvent("newskillpointupdated")
        end
    end

    self.root.tree:CreateTree(self.target, self.targetdata, self.readonly)

    if self.root.tree then
        self.root.tree:SetFocusChangeDirs()
        self.default_focus = self.root.tree:GetDefaultFocus()
    end
    self:SpawnFavorOverlay()
end)

function SkillTreeWidget:SpawnFavorOverlay(pre)
    if not self.fromfrontend then
        local hasskill = false
        if self.readonly then
            local skillselection = TheSkillTree:GetNamesFromSkillSelection(self.targetdata.skillselection, self.targetdata.prefab)
            hasskill = skillselection["wilson_allegiance_shadow"]
        else
            local skilltreeupdater = ThePlayer and ThePlayer.components.skilltreeupdater or nil
            if skilltreeupdater then
                hasskill = skilltreeupdater:IsActivated("wilson_allegiance_shadow")
            end
        end
        if hasskill then
            self.midlay.splash = self.midlay:AddChild(UIAnim())
            self.midlay.splash:GetAnimState():SetBuild("skills_shadow")
            self.midlay.splash:GetAnimState():SetBank("skills_shadow")
            if pre then  
                TheFrontEnd:GetSound():PlaySound("wilson_rework/ui/shadow_skill")
                
                self.midlay.splash:GetAnimState():PlayAnimation("pre",false)
                self.midlay.splash:GetAnimState():PushAnimation("idle",true)
            else            
                self.midlay.splash:GetAnimState():PlayAnimation("idle",true)
            end
            self.midlay.splash:SetPosition(0,-10)
        end
    end
end

function SkillTreeWidget:Kill()
	--ThePlantRegistry:Save() -- for saving filter settings
	SkillTreeWidget._base.Kill(self)
end

function SkillTreeWidget:OnControl(control, down)
    if SkillTreeWidget._base.OnControl(self, control, down) then return true end

    if self.readonly then return true end

    if not down and control == CONTROL_PAUSE then
        local skilltreeupdater = ThePlayer.components.skilltreeupdater
        if skilltreeupdater == nil then
            return false
        end
        skilltreeupdater:ActivateSkill(self.root.tree.selectedskill)
        self.root.tree:RefreshTree()
        return true
    end

    return false
end

function SkillTreeWidget:GetHelpText()
    local controller_id = TheInput:GetControllerID()
    local t = {}

	if self.root.infopanel.activatebutton:IsVisible() then
		table.insert(t, TheInput:GetLocalizedControl(controller_id, CONTROL_PAUSE).. " " .. STRINGS.SKILLTREE.ACTIVATE)
    end

    return table.concat(t, "  ")
end

return SkillTreeWidget