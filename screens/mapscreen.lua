local Screen = require "widgets/screen"
local MapWidget = require("widgets/mapwidget")
local Widget = require "widgets/widget"
local MapControls = require "widgets/mapcontrols"
local HudCompass = require "widgets/hudcompass"

-- NOTES(JBK): These constants are from MiniMapRenderer ZOOM_CLAMP_MIN and ZOOM_CLAMP_MAX
local ZOOM_CLAMP_MIN = 1
local ZOOM_CLAMP_MAX = 20

local MapScreen = Class(Screen, function(self, owner)
    self.owner = owner
    Screen._ctor(self, "MapScreen")
    self.minimap = self:AddChild(MapWidget(self.owner))

    self.bottomright_root = self:AddChild(Widget("br_root"))
    self.bottomright_root:SetScaleMode(SCALEMODE_PROPORTIONAL)
    self.bottomright_root:SetHAnchor(ANCHOR_RIGHT)
    self.bottomright_root:SetVAnchor(ANCHOR_BOTTOM)
    self.bottomright_root:SetMaxPropUpscale(MAX_HUD_SCALE)

    self.bottomright_root = self.bottomright_root:AddChild(Widget("br_scale_root"))
    self.bottomright_root:SetScale(TheFrontEnd:GetHUDScale())
    self.bottomright_root.inst:ListenForEvent("refreshhudsize", function(hud, scale) self.bottomright_root:SetScale(scale) end, owner.HUD.inst)

    if not TheInput:ControllerAttached() then
        self.mapcontrols = self.bottomright_root:AddChild(MapControls())
        self.mapcontrols:SetPosition(-60,70,0)
        self.mapcontrols.pauseBtn:Hide()
    end

    self.hudcompass = self.bottomright_root:AddChild(HudCompass(self.owner, false))
    self.hudcompass:SetPosition(-160,70,0)

    self.zoom_to_cursor = Profile:IsMinimapZoomCursorFollowing()
    self.zoom_target = self.minimap:GetZoom()
    self.zoomsensitivity = 20

    SetAutopaused(true)
end)

function MapScreen:OnBecomeInactive()
    MapScreen._base.OnBecomeInactive(self)

    if TheWorld.minimap.MiniMap:IsVisible() then
        TheWorld.minimap.MiniMap:ToggleVisibility()
    end
    --V2C: Don't set pause in multiplayer, all it does is change the
    --     audio settings, which we don't want to do now
    --SetPause(false)
end

function MapScreen:OnBecomeActive()
    MapScreen._base.OnBecomeActive(self)

    if not TheWorld.minimap.MiniMap:IsVisible() then
        TheWorld.minimap.MiniMap:ToggleVisibility()
    end
    self.minimap:UpdateTexture()

    if TheInput:ControllerAttached() then
        self.minimap.centerreticle:Show()
    else
        self.minimap.centerreticle:Hide()
    end

    self.zoomsensitivity = Profile:GetMiniMapZoomSensitivity()
    --V2C: Don't set pause in multiplayer, all it does is change the
    --     audio settings, which we don't want to do now
    --SetPause(true)
end

function MapScreen:OnDestroy()
    SetAutopaused(false)

	MapScreen._base.OnDestroy(self)
end

function MapScreen:GetZoomOffset(scaler)
    -- NOTES(JBK): The magic constant 9 comes from the scaler in MiniMapRenderer ZOOM_MODIFIER.
    local zoomfactor = 9 * self.minimap:GetZoom() / scaler
    local x, y = self:GetCursorPosition()
    local w, h = TheSim:GetScreenSize()
    x = x * w / zoomfactor
    y = y * h / zoomfactor
    return x, y
end

function MapScreen:DoZoomIn(negativedelta)
    negativedelta = negativedelta or -0.1
    -- Run the function always, conditionally do offset fixup.
    if self.minimap:OnZoomIn(negativedelta) and self.zoom_to_cursor then
        local x, y = self:GetZoomOffset(-negativedelta)
        self.minimap:Offset(-x, -y)
    end
end

function MapScreen:DoZoomOut(positivedelta)
    positivedelta = positivedelta or 0.1
    -- Run the function always, conditionally do offset fixup.
    if self.minimap:OnZoomOut(positivedelta) and self.zoom_to_cursor then
        local x, y = self:GetZoomOffset(positivedelta)
        self.minimap:Offset(x, y)
    end
end

function MapScreen:OnUpdate(dt)
    local s = -100 * dt -- now per second, not per repeat

    -- NOTES(JBK): Controllers apply smooth analog input so use it for more precision with joysticks.
    local xdir = TheInput:GetAnalogControlValue(CONTROL_MOVE_RIGHT) - TheInput:GetAnalogControlValue(CONTROL_MOVE_LEFT)
    local ydir = TheInput:GetAnalogControlValue(CONTROL_MOVE_UP) - TheInput:GetAnalogControlValue(CONTROL_MOVE_DOWN)
    local xmag = xdir * xdir + ydir * ydir
    local deadzonesq = 0.3 * 0.3 -- TODO(JBK): Global controller deadzone setting.
    if xmag >= deadzonesq then
        self.minimap:Offset(xdir * s, ydir * s)
    end

    -- NOTES(JBK): In order to change digital to analog without causing issues engine side with prior binds we emulate it.
    local indir = TheInput:IsControlPressed(CONTROL_MAP_ZOOM_IN) and -1 or 0
    local outdir = TheInput:IsControlPressed(CONTROL_MAP_ZOOM_OUT) and 1 or 0
    self.zoom_target = math.clamp(self.zoom_target + self.zoomsensitivity * (indir + outdir) * dt, ZOOM_CLAMP_MIN, ZOOM_CLAMP_MAX)
    local zoom_delta = self.zoom_target - self.minimap:GetZoom()
    if math.abs(zoom_delta) > 0.1 then -- Floats.
        zoom_delta = zoom_delta * 0.4 -- Arbitrarily picked for the decay time, done here after the threshold check.
        if zoom_delta < 0 then
            self:DoZoomIn(zoom_delta)
        elseif zoom_delta > 0 then
            self:DoZoomOut(zoom_delta)
        end
    end
end

--[[ EXAMPLE of map coordinate functions
function MapScreen:NearestEntToCursor()
    local closestent = nil
    local closest = nil
    for ent,_ in pairs(someentities) do
        local ex,ey,ez = ent.Transform:GetWorldPosition()
        local entpos = self:MapPosToWidgetPos( Vector3(self.minimap:WorldPosToMapPos(ex,ez,0)) )
        local mousepos = self:ScreenPosToWidgetPos( TheInput:GetScreenPosition() )
        local delta = mousepos - entpos

        local length = delta:Length()
        if length < 30 then
            if closest == nil or length < closest then
                closestent = ent
                closest = length
            end
        end
    end

    if closestent ~= nil then
        local ex,ey,ez = closestent.Transform:GetWorldPosition()
        local entpos = self:MapPosToWidgetPos( Vector3(self.minimap:WorldPosToMapPos(ex,ez,0)) )

        self.hovertext:SetPosition(entpos:Get())
        self.hovertext:Show()
    else
        self.hovertext:Hide()
    end
end
]]

function MapScreen:MapPosToWidgetPos(mappos)
    return Vector3(
        mappos.x * RESOLUTION_X/2,
        mappos.y * RESOLUTION_Y/2,
        0
    )
end

function MapScreen:ScreenPosToWidgetPos(screenpos)
    local w, h = TheSim:GetScreenSize()
    return Vector3(
        screenpos.x / w * RESOLUTION_X - RESOLUTION_X/2,
        screenpos.y / h * RESOLUTION_Y - RESOLUTION_Y/2,
        0
    )
end

function MapScreen:WidgetPosToMapPos(widgetpos)
    return Vector3(
        widgetpos.x / (RESOLUTION_X/2),
        widgetpos.y / (RESOLUTION_Y/2),
        0
    )
end

function MapScreen:GetCursorPosition()
    -- This function uses the origin at the center of the screen.
    -- Outputs are normalized from -1 to 1 on both axii.
    local x, y
    if TheInput:ControllerAttached() then
        x, y = 0, 0 -- Controller users do not have a cursor to control so center it.
    else
        x, y = TheSim:GetPosition()
        local w, h = TheSim:GetScreenSize()
        x = 2 * x / w - 1
        y = 2 * y / h - 1
    end
    return x, y
end

function MapScreen:GetWorldPositionAtCursor()
    local x, y = self:GetCursorPosition()
    x, y = self.minimap:MapPosToWorldPos(x, y, 0)
    return x, 0, y -- Coordinate conversion from minimap widget to world.
end

function MapScreen:OnControl(control, down)
    if MapScreen._base.OnControl(self, control, down) then return true end

    if not down and (control == CONTROL_MAP or control == CONTROL_CANCEL) then
        TheFrontEnd:PopScreen()
        return true
    end

    if not (down and self.shown) then
        return false
    end

    if control == CONTROL_ROTATE_LEFT and ThePlayer and ThePlayer.components.playercontroller then
        ThePlayer.components.playercontroller:RotLeft()
    elseif control == CONTROL_ROTATE_RIGHT and ThePlayer and ThePlayer.components.playercontroller then
        ThePlayer.components.playercontroller:RotRight()
    elseif control == CONTROL_MAP_ZOOM_IN then -- NOTES(JBK): Keep these here for mods but modify their value to do nothing with new code.
        self:DoZoomIn(0)
    elseif control == CONTROL_MAP_ZOOM_OUT then
        self:DoZoomOut(0)
    else
        return false
    end
    return true
end

function MapScreen:GetHelpText()
    local controller_id = TheInput:GetControllerID()
    local t = {}

    table.insert(t,  TheInput:GetLocalizedControl(controller_id, CONTROL_ROTATE_LEFT) .. " " .. STRINGS.UI.HELP.ROTATE_LEFT)
    table.insert(t,  TheInput:GetLocalizedControl(controller_id, CONTROL_ROTATE_RIGHT) .. " " .. STRINGS.UI.HELP.ROTATE_RIGHT)
    table.insert(t,  TheInput:GetLocalizedControl(controller_id, CONTROL_MAP_ZOOM_IN) .. " " .. STRINGS.UI.HELP.ZOOM_IN)
    table.insert(t,  TheInput:GetLocalizedControl(controller_id, CONTROL_MAP_ZOOM_OUT) .. " " .. STRINGS.UI.HELP.ZOOM_OUT)
    table.insert(t,  TheInput:GetLocalizedControl(controller_id, CONTROL_CANCEL) .. " " .. STRINGS.UI.HELP.BACK)

    return table.concat(t, "  ")
end

return MapScreen
