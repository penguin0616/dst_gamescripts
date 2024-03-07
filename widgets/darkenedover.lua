local Widget = require "widgets/widget"
local Image = require "widgets/image"

local DarkenedOver =  Class(Widget, function(self, owner)
    self.owner = owner
    Widget._ctor(self, "DarkenedOver")

    self:SetClickable(false)

    self.bg = self:AddChild(Image("images/global.xml", "square.tex"))
    self.bg:SetVRegPoint(ANCHOR_MIDDLE)
    self.bg:SetHRegPoint(ANCHOR_MIDDLE)
    self.bg:SetVAnchor(ANCHOR_MIDDLE)
    self.bg:SetHAnchor(ANCHOR_MIDDLE)
    self.bg:SetScaleMode(SCALEMODE_FILLSCREEN)
    self.bg:SetTint(0, 0, 0, 0.3)

    self.vignette = self:AddChild(Image("images/fx3.xml", "goggle_over.tex"))
    self.vignette:SetVRegPoint(ANCHOR_MIDDLE)
    self.vignette:SetHRegPoint(ANCHOR_MIDDLE)
    self.vignette:SetVAnchor(ANCHOR_MIDDLE)
    self.vignette:SetHAnchor(ANCHOR_MIDDLE)
    self.vignette:SetScaleMode(SCALEMODE_FILLSCREEN)

    self:Hide()

    self.inst:ListenForEvent("darkenedvision", function(owner, data) self:Toggle(data.enabled) end, owner)

    if owner ~= nil and
        owner.components.playervision ~= nil and
        owner.components.playervision:HasDarkenedVision()
    then
        self:Toggle(true)
    end
end)

function DarkenedOver:Toggle(show)
    if show and not self.shown then
        self:Show()

    elseif not show and self.shown then
        self:Hide()
    end

    self.shown = show
end

return DarkenedOver
