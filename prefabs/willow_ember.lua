local willow_ember_common = require("prefabs/willow_ember_common")

local assets =
{
    Asset("ANIM", "anim/willow_embers.zip"),

    Asset("ATLAS", "images/spell_icons.xml"),
    Asset("IMAGE", "images/spell_icons.tex"),
    Asset("INV_IMAGE", "willow_ember"),
    Asset("INV_IMAGE", "willow_ember_open"),
    Asset("SCRIPT", "scripts/prefabs/willow_ember_common.lua"),
}

local retucleassets =
{
    Asset("ANIM", "anim/reticuleaoe.zip"),
}

local prefabs =
{
    "spell_fire_throw",
    "firesplash_fx",
    "firering_fx",
    "flamethrower_fx",
    "willow_shadow_flame",
    "willow_throw_flame",
    "deerclops_laserscorch",
    "reticulemultitarget",
    "reticuleaoe5line",
    "reticuleaoeping5line",
    "willow_frenzy",
}

local SCALE = .8

local SPELLCOSTS = {
    ["firethrow"] = TUNING.WILLOW_EMBER_THROW,
    ["fireburst"] = TUNING.WILLOW_EMBER_BURST,
    ["fireball"] = TUNING.WILLOW_EMBER_BALL,
    ["lunarfire"] = TUNING.WILLOW_EMBER_LUNAR,
    ["firefrenzy"] = TUNING.WILLOW_EMBER_FRENZY,
    ["shadowfire"] = TUNING.WILLOW_EMBER_SHADOW,
}

local function KillEmber(inst)
    inst:ListenForEvent("animover", inst.Remove)

    inst.AnimState:PlayAnimation("idle_pst")
    inst.SoundEmitter:PlaySound("dontstarve/characters/wortox/soul/spawn", nil, .5)
end

local function toground(inst)
    inst.persists = false

    if inst._task == nil then
        inst._task = inst:DoTaskInTime(TUNING.WILLOW_EMBER_DURATION, KillEmber) -- NOTES(JBK): This is 1.1 max keep it in sync with "[WST]"
    end

    if inst.AnimState:IsCurrentAnimation("idle_loop") then
		inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)
    end
end

local EMBER_TAGS = { "willow_ember" }

local function OnDropped(inst)
    if inst.components.stackable ~= nil and inst.components.stackable:IsStack() then
        local x, y, z = inst.Transform:GetWorldPosition()
        local num = 10 - TheSim:CountEntities(x, y, z, 4, EMBER_TAGS)

        if num > 0 then
            for i = 1, math.min(num, inst.components.stackable:StackSize()) do
                local ember = inst.components.stackable:Get()
                ember.Physics:Teleport(x, y, z)
                ember.components.inventoryitem:OnDropped(true)
            end
        end
    end
end

------------------------------------------
-- MAGIC STUFF

local function CheckStackSize(inst, doer, spell)
    return doer.replica.inventory ~= nil and doer.replica.inventory:Has(inst.prefab, SPELLCOSTS[spell])
end

local function OnOpenSpellBook(inst)
    local inventoryitem = inst.replica.inventoryitem
    if inventoryitem ~= nil then
        inventoryitem:OverrideImage("willow_ember_open")
    end

    TheFocalPoint.SoundEmitter:PlaySound("meta3/willow/ember_container_open","willow_ember_open")
end

local function OnCloseSpellBook(inst)
    local inventoryitem = inst.replica.inventoryitem
    if inventoryitem ~= nil then
        inventoryitem:OverrideImage(nil)
    end

    TheFocalPoint.SoundEmitter:KillSound("willow_ember_open")
end

local SPAWN_FIRE_CANT =     { "player", "INLIMBO", "FX", "NOCLICK" }
local SPAWN_FIRE_CANT_PVP = { "INLIMBO", "FX", "NOCLICK" }

local function ThrowFire_SpawnFire(inst, doer, pos)
    local x, y, z = pos:Get()

    SpawnPrefab("willow_throw_flame").Transform:SetPosition(x, 0, z)

    local ents = TheSim:FindEntities(x, 0, z, 2, nil, TheNet:GetPVPEnabled() and SPAWN_FIRE_CANT_PVP or SPAWN_FIRE_CANT)

    if doer == nil or ents == nil then
        return
    end

    for i, target in ipairs(ents) do
        if target ~= doer and
            target.components.burnable ~= nil
        then
            if target.components.freezable ~= nil and target.components.freezable:IsFrozen() then
                target.components.freezable:Unfreeze()

            elseif target.components.fueled == nil or (
                target.components.fueled.fueltype ~= FUELTYPE.BURNABLE and
                target.components.fueled.secondaryfueltype ~= FUELTYPE.BURNABLE
            ) then
                -- Does not take burnable fuel, so just burn it.
                if target.components.burnable.canlight or target.components.combat ~= nil then
                    target.components.burnable:Ignite(true, inst, doer)
                end

            elseif target.components.fueled.accepting then
                -- Takes burnable fuel, so fuel it.
                local fuel = SpawnPrefab("boards")

                if fuel ~= nil then
                    if fuel.components.fuel ~= nil and
                        fuel.components.fuel.fueltype == FUELTYPE.BURNABLE
                    then
                        target.components.fueled:TakeFuelItem(fuel)
                    else
                        fuel:Remove()
                    end
                end
            end
        end
    end
end

local function TryThrowFire(inst, doer, pos)
    if CheckStackSize(inst, doer, "firethrow") then
        ThrowFire_SpawnFire(inst, doer, pos)

        return true
    end

    return false
end

local function spawnfirefx(pos)
    local ring = SpawnPrefab("firering_fx")
    ring.Transform:SetPosition(pos.x,pos.y,pos.z)

    local theta = math.random(2*PI)

    for i=1,4 do
        local radius = 4
        local newtheta = theta  + (PI/2*i)
        local offset = Vector3(radius * math.cos( newtheta ), 0, -radius * math.sin( newtheta ))
        local puff = SpawnPrefab("firesplash_fx")
        local newpos = pos+offset
        puff.Transform:SetPosition(newpos.x, newpos.y, newpos.z)
    end
end

local function TryBurstFire(inst, doer, pos)
    if CheckStackSize(inst, doer, "fireburst") then
        local ents = willow_ember_common.GetBurstTargets(doer)
        local success = false

        if ents == nil then
            return false
        end

        for i, ent in ipairs(ents) do
            local distsq = doer:GetDistanceSqToInst(ent)

            if ent ~= doer then
                local time = Remap(distsq, 0, TUNING.FIRE_BURST_RANGE*TUNING.FIRE_BURST_RANGE, 0, 0.5)

                inst:DoTaskInTime(time, function()
                    if ent.components.burnable then
                        ent.components.burnable:Ignite(nil, inst, doer)
                    else
                        ent:PushEvent("onlighterlight")
                    end
                end)

                success = true
            end
        end

        return success
    end

    return false
end

local function TryBallFire(inst, doer, pos)
    if CheckStackSize(inst, doer, "fireball") then
        local ball= SpawnPrefab("emberlight")
        ball.Transform:SetPosition(pos.x,pos.y,pos.z)
        return true
    end
    return false
end

local function EndLunarFire(fx, doer)
	if doer.components.channelcaster then
		doer.components.channelcaster:StopChanneling()
	end
end

local function TryLunarFire(inst, doer, pos)
    if CheckStackSize(inst, doer, "lunarfire") and
		doer.components.channelcaster and
		not doer.components.channelcaster:IsChanneling()
	then
		local fx = SpawnPrefab("flamethrower_fx")
		fx.entity:SetParent(doer.entity)
		fx:SetFlamethrowerAttacker(doer)

		local endtask = fx:DoTaskInTime(TUNING.WILLOW_LUNAR_FIRE_TIME, EndLunarFire, doer)

		fx:ListenForEvent("stopchannelcast", function()
			if fx then
				endtask:Cancel()
				fx:KillFX()
				fx = nil
			end
		end, doer)

        if inst.components.spellbook then
            inst.components.spellbook:StartCooldown(inst.components.spellbook:GetSelectedSpell(),TUNING.WILLOW_LUNAR_FIRE_COOLDOWN)
        end

		if doer.components.channelcaster:StartChanneling() then
			return true
		end

		--channelcast fail
		fx:Remove()
    end
    return false
end

local function TryShadowFire(inst, doer, pos)
    if CheckStackSize(inst, doer, "shadowfire") then

        local startangle = inst:GetAngleToPoint(pos.x,pos.y,pos.z)*DEGREES

        local burst = 5

        for i=1,burst do
            local radius = 2
            local theta = startangle + (PI*2/burst*i) - (PI*2/burst)
            local offset = Vector3(radius * math.cos( theta ), 0, -radius * math.sin( theta ))

            local newpos = Vector3(inst.Transform:GetWorldPosition()) + offset

            local fire = SpawnPrefab("willow_shadow_flame")
            fire.Transform:SetRotation(theta/DEGREES)
            fire.Transform:SetPosition(newpos.x,newpos.y,newpos.z)
            fire:settarget(nil,50,doer)
        end

        if inst.components.spellbook then
            inst.components.spellbook:StartCooldown(inst.components.spellbook:GetSelectedSpell(),TUNING.WILLOW_SHADOW_FIRE_COOLDOWN)
        end

        return true
    end
    return false
end

local function TryFireFrenzy(inst, doer, pos)
    if CheckStackSize(inst, doer, "firefrenzy") then

        doer:AddDebuff("buff_firefrenzy", "buff_firefrenzy")

        return true
    end
    return false
end

local function FireBurstSpellFn(inst, doer, pos)
    if not CheckStackSize(inst, doer, "fireburst") then
        return false, "NOT_ENOUGH_EMBERS"
    elseif TryBurstFire(inst, doer, pos) then
        doer.components.inventory:ConsumeByName(inst.prefab, SPELLCOSTS["fireburst"])

        return true
    end
    return false, "NO_TARGETS"
end

local function FireThrowSpellFn(inst, doer, pos)
    if not CheckStackSize(inst, doer, "firethrow") then
        return false, "NOT_ENOUGH_EMBERS"
    elseif TryThrowFire(inst, doer, pos) then
        doer.components.inventory:ConsumeByName(inst.prefab, SPELLCOSTS["firethrow"])
        return true
    end
    return false
end

local function FireBallSpellFn(inst, doer, pos)
    if not CheckStackSize(inst, doer, "fireball") then
        return false, "NOT_ENOUGH_EMBERS"
    elseif TryBallFire(inst, doer, pos) then
        doer.components.inventory:ConsumeByName(inst.prefab, SPELLCOSTS["fireball"])
        return true
    end
    return false
end

local function LunarFireSpellFn(inst, doer, pos)
    if inst.components.spellbook:CheckCooldown(inst.components.spellbook:GetSelectedSpell()) then
        return false, "SPELL_ON_COOLDOWN"
    elseif doer.components.rider:IsRiding() then
        return false, "CANT_SPELL_MOUNTED"
    elseif not CheckStackSize(inst, doer, "lunarfire") then
        return false, "NOT_ENOUGH_EMBERS"
    elseif TryLunarFire(inst, doer, pos) then
        doer.components.inventory:ConsumeByName(inst.prefab, SPELLCOSTS["lunarfire"])
        return true
    end
    return false
end

local function ShadowFireSpellFn(inst, doer, pos)
    if inst.components.spellbook:CheckCooldown(inst.components.spellbook:GetSelectedSpell()) then
        return false, "SPELL_ON_COOLDOWN"    
    elseif not CheckStackSize(inst, doer, "shadowfire") then
        return false, "NOT_ENOUGH_EMBERS"
    elseif TryShadowFire(inst, doer, pos) then
        doer.components.inventory:ConsumeByName(inst.prefab, SPELLCOSTS["shadowfire"])
        return true
    end
    return false
end

local function FireFrenzySpellFn(inst, doer, pos)
    if not CheckStackSize(inst, doer, "firefrenzy") then
        return false, "NOT_ENOUGH_EMBERS"
    elseif TryFireFrenzy(inst, doer, pos) then
        doer.components.inventory:ConsumeByName(inst.prefab, SPELLCOSTS["firefrenzy"])
        return true
    end
    return false
end

local function ReticuleTargetAllowWaterFn()
    local player = ThePlayer
    local ground = TheWorld.Map
    local pos = Vector3()
    --Cast range is 8, leave room for error
    --4 is the aoe range
    for r = 7, 0, -.25 do
        pos.x, pos.y, pos.z = player.entity:LocalToWorldSpace(r, 0, 0)
        if ground:IsPassableAtPoint(pos.x, 0, pos.z, true) and not ground:IsGroundTargetBlocked(pos) then
            return pos
        end
    end
    return pos
end

local function StartAOETargeting(inst)
    local playercontroller = ThePlayer.components.playercontroller
    if playercontroller ~= nil then
        playercontroller:StartAOETargetingUsing(inst)
    end
end

local function ShouldRepeatFireThrow(inst, doer)
    return CheckStackSize(inst, doer, "firethrow")
end

local function ShouldRepeatFireBurst(inst, doer)
    return CheckStackSize(inst, doer, "fireburst")
end

local function ShouldRepeatFireBall(inst, doer)
    return CheckStackSize(inst, doer, "fireball")
end

local function ShouldRepeatFireFrenzy(inst, doer)
    return CheckStackSize(inst, doer, "firefrenzy")
end

local function ShouldRepeatShadowFire(inst, doer)
    return CheckStackSize(inst, doer, "shadowfire")
end

local function ShouldRepeatLunarFire(inst, doer)
    return CheckStackSize(inst, doer, "lunarfire")
end

-------------------------------------------------------------
local function burst_reticule_mouse_target_function(inst, mousepos)
    if mousepos == nil then
        return nil
    end

    local owner = inst.replica.inventoryitem:IsHeldBy(ThePlayer) and ThePlayer
    if owner then
        local pos = Vector3(owner.Transform:GetWorldPosition())
        return pos
    end
end

local function burst_reticule_target_function(inst)
    if ThePlayer and ThePlayer.components.playercontroller ~= nil and ThePlayer.components.playercontroller.isclientcontrollerattached then
        local owner = inst.components.inventoryitem.owner
        if owner then
            local pos = Vector3(owner.Transform:GetWorldPosition())
            return pos
        end
    end
end

local function burst_reticule_update_position_function(inst, pos, reticule, ease, smoothing, dt)
    local owner = inst.replica.inventoryitem:IsHeldBy(ThePlayer) and ThePlayer

    if owner then
        reticule.Transform:SetPosition(Vector3(owner.Transform:GetWorldPosition()):Get())
        reticule.Transform:SetRotation(0)
    end
end

--------------------------------------------------

local function single_reticule_mouse_target_function(inst, mousepos)
    if mousepos == nil then
        return nil
    end
    local owner = inst.replica.inventoryitem:IsHeldBy(ThePlayer) and ThePlayer
    if owner then
        local pos = Vector3(owner.Transform:GetWorldPosition())
        return pos
    end
end

local function single_reticule_target_function(inst)
    if ThePlayer and ThePlayer.components.playercontroller ~= nil and ThePlayer.components.playercontroller.isclientcontrollerattached then
        local owner = inst.components.inventoryitem.owner
        if owner then
            local pos = Vector3(owner.Transform:GetWorldPosition())
            return pos
        end
    end
end

local function single_reticule_update_position_function(inst, pos, reticule, ease, smoothing, dt)
    local owner = inst.replica.inventoryitem:IsHeldBy(ThePlayer) and ThePlayer

    if owner then
        reticule.Transform:SetPosition(Vector3(owner.Transform:GetWorldPosition()):Get())
        reticule.Transform:SetRotation(0)
    end
end

-------------------------------------------------

local function line_reticule_target_function(inst)
    if ThePlayer and ThePlayer.components.playercontroller ~= nil and ThePlayer.components.playercontroller.isclientcontrollerattached then
        local owner = inst.components.inventoryitem.owner
        if owner then
            local pos = Vector3(owner.Transform:GetWorldPosition())
            return pos
        end
    end
end

local function line_reticule_mouse_target_function(inst, mousepos)
    if mousepos ~= nil then
        local x, y, z = inst.Transform:GetWorldPosition()
        local dx = mousepos.x - x
        local dz = mousepos.z - z
        local l = dx * dx + dz * dz
        if l <= 0 then
            return inst.components.reticule.targetpos
        end
        l = 6.5 / math.sqrt(l)
        return Vector3(x + dx * l, 0, z + dz * l)
    end
end

local function line_reticule_update_position_function(inst, pos, reticule, ease, smoothing, dt)
    local owner = inst.replica.inventoryitem:IsHeldBy(ThePlayer) and ThePlayer

    if owner then
        reticule.Transform:SetPosition(Vector3(owner.Transform:GetWorldPosition()):Get())
        local angle = owner:GetAngleToPoint(pos.x,pos.y,pos.z)
        reticule.Transform:SetRotation(angle)
    end
end

---------------------------------------------------

local ICON_SCALE = .6
local ICON_RADIUS = 50
local SPELLBOOK_RADIUS = 100
local SPELLBOOK_FOCUS_RADIUS = SPELLBOOK_RADIUS + 2
local BASESPELLS = {}

local FIRE_THROW =
{
    {
        label = STRINGS.PYROMANCY.FIRE_THROW,
        onselect = function(inst)
            inst.components.spellbook:SetSpellName(STRINGS.PYROMANCY.FIRE_THROW)            
            inst.components.aoetargeting:SetDeployRadius(0)
            inst.components.aoetargeting:SetShouldRepeatCastFn(ShouldRepeatFireThrow)
            inst.components.aoetargeting.reticule.reticuleprefab = "reticuleaoefiretarget_1" --"reticuleaoe_1d2_12"
            inst.components.aoetargeting.reticule.pingprefab = "reticuleaoefiretarget_1ping" --"reticuleaoeping_1d2_12"

            inst.components.aoetargeting.reticule.mousetargetfn = nil -- throw_reticule_mouse_target_function
            inst.components.aoetargeting.reticule.targetfn = nil -- throw_reticule_target_function
            inst.components.aoetargeting.reticule.updatepositionfn = nil --throw_reticule_update_position_function

            if TheWorld.ismastersim then
                inst.components.aoetargeting:SetTargetFX("reticuleaoefiretarget_1")
                inst.components.aoespell:SetSpellFn(FireThrowSpellFn)
                inst.components.spellbook:SetSpellFn(nil)
            end
        end,
        execute = StartAOETargeting,
        atlas = "images/spell_icons.xml",
        normal = "fire_throw.tex",
        widget_scale = ICON_SCALE,
        hit_radius = ICON_RADIUS,
    },
}

local FIRE_BURST =
{
    {
        label = STRINGS.PYROMANCY.FIRE_BURST,
        onselect = function(inst)
            inst.components.spellbook:SetSpellName(STRINGS.PYROMANCY.FIRE_BURST)
            inst.components.aoetargeting:SetDeployRadius(0)
            inst.components.aoetargeting:SetShouldRepeatCastFn(ShouldRepeatFireBurst)
            inst.components.aoetargeting.reticule.reticuleprefab = "reticulemultitarget"
            inst.components.aoetargeting.reticule.pingprefab = "reticulemultitargetping"

            inst.components.aoetargeting.reticule.mousetargetfn = burst_reticule_mouse_target_function
            inst.components.aoetargeting.reticule.targetfn = burst_reticule_target_function
            inst.components.aoetargeting.reticule.updatepositionfn = burst_reticule_update_position_function

            if TheWorld.ismastersim then
                inst.components.aoetargeting:SetTargetFX("reticulemultitarget")
                inst.components.aoespell:SetSpellFn(FireBurstSpellFn)
                inst.components.spellbook:SetSpellFn(nil)
            end
        end,
        execute = StartAOETargeting,
        atlas = "images/spell_icons.xml",
        normal = "fire_burst.tex",
        widget_scale = ICON_SCALE,
        hit_radius = ICON_RADIUS,
    },
}

local FIRE_BALL =
{
    {
        label = STRINGS.PYROMANCY.FIRE_BALL,
        onselect = function(inst)
            inst.components.spellbook:SetSpellName(STRINGS.PYROMANCY.FIRE_BALL)
            inst.components.aoetargeting:SetDeployRadius(0)
            inst.components.aoetargeting:SetShouldRepeatCastFn(ShouldRepeatFireBall)
            inst.components.aoetargeting.reticule.reticuleprefab = "reticuleaoefiretarget_1"
            inst.components.aoetargeting.reticule.pingprefab = "reticuleaoefiretarget_1ping"

            inst.components.aoetargeting.reticule.mousetargetfn = nil
            inst.components.aoetargeting.reticule.targetfn = nil
            inst.components.aoetargeting.reticule.updatepositionfn = nil

            if TheWorld.ismastersim then
                inst.components.aoetargeting:SetTargetFX("reticuleaoefiretarget_1")
                inst.components.aoespell:SetSpellFn(FireBallSpellFn)
                inst.components.spellbook:SetSpellFn(nil)
            end
        end,
        execute = StartAOETargeting,
        atlas = "images/spell_icons.xml",
        normal = "fire_ball.tex",
        widget_scale = ICON_SCALE,
        hit_radius = ICON_RADIUS,
    },
}

local FIRE_FRENZY =
{
    {
        label = STRINGS.PYROMANCY.FIRE_FRENZY,
        onselect = function(inst)
            inst.components.spellbook:SetSpellName(STRINGS.PYROMANCY.FIRE_FRENZY)
            inst.components.aoetargeting:SetDeployRadius(0)
            inst.components.aoetargeting:SetShouldRepeatCastFn(ShouldRepeatFireFrenzy)
            inst.components.aoetargeting.reticule.reticuleprefab = "reticuleaoefiretarget_1"
            inst.components.aoetargeting.reticule.pingprefab = "reticuleaoefiretarget_1ping"

            inst.components.aoetargeting.reticule.mousetargetfn = single_reticule_mouse_target_function
            inst.components.aoetargeting.reticule.targetfn = single_reticule_target_function
            inst.components.aoetargeting.reticule.updatepositionfn = single_reticule_update_position_function

            if TheWorld.ismastersim then
                inst.components.aoetargeting:SetTargetFX("reticuleaoefiretarget_1")
                inst.components.aoespell:SetSpellFn(FireFrenzySpellFn)
                inst.components.spellbook:SetSpellFn(nil)
            end
        end,
        execute = StartAOETargeting,
        atlas = "images/spell_icons.xml",
        normal = "fire_frenzy.tex",
        widget_scale = ICON_SCALE,
        hit_radius = ICON_RADIUS,
    },
}

local LUNAR_FIRE =
{
    {
        label = STRINGS.PYROMANCY.LUNAR_FIRE,
        onselect = function(inst)
            inst.components.spellbook:SetSpellName(STRINGS.PYROMANCY.LUNAR_FIRE)
            inst.components.aoetargeting:SetDeployRadius(0)
            inst.components.aoetargeting:SetShouldRepeatCastFn(ShouldRepeatLunarFire)
            inst.components.aoetargeting.reticule.reticuleprefab = "reticuleline"
            inst.components.aoetargeting.reticule.pingprefab = "reticulelineping"

            inst.components.aoetargeting.reticule.mousetargetfn = line_reticule_mouse_target_function
            inst.components.aoetargeting.reticule.targetfn = line_reticule_target_function
            inst.components.aoetargeting.reticule.updatepositionfn = line_reticule_update_position_function

            if TheWorld.ismastersim then
                inst.components.aoetargeting:SetTargetFX("reticuleaoefiretarget_1")
                inst.components.aoespell:SetSpellFn(LunarFireSpellFn)
                inst.components.spellbook:SetSpellFn(nil)
            end
        end,
        execute = StartAOETargeting,
        atlas = "images/spell_icons.xml",
        normal = "lunar_fire.tex",
        widget_scale = ICON_SCALE,
        hit_radius = ICON_RADIUS,
    },
}

local SHADOW_FIRE =
{
    {
        label = STRINGS.PYROMANCY.SHADOW_FIRE,
        onselect = function(inst)
            inst.components.spellbook:SetSpellName(STRINGS.PYROMANCY.SHADOW_FIRE)
            inst.components.aoetargeting:SetDeployRadius(0)
            inst.components.aoetargeting:SetShouldRepeatCastFn(ShouldRepeatShadowFire)
            inst.components.aoetargeting.reticule.reticuleprefab = "reticuleaoe5line"
            inst.components.aoetargeting.reticule.pingprefab = "reticuleaoeping5line"

            inst.components.aoetargeting.reticule.mousetargetfn = line_reticule_mouse_target_function
            inst.components.aoetargeting.reticule.targetfn = line_reticule_target_function
            inst.components.aoetargeting.reticule.updatepositionfn = line_reticule_update_position_function

            if TheWorld.ismastersim then
                inst.components.aoetargeting:SetTargetFX("reticuleaoe5line")
                inst.components.aoespell:SetSpellFn(ShadowFireSpellFn)
                inst.components.spellbook:SetSpellFn(nil)
            end
        end,
        execute = StartAOETargeting,
        atlas = "images/spell_icons.xml",
        normal = "shadow_fire.tex",
        widget_scale = ICON_SCALE,
        hit_radius = ICON_RADIUS,
    },
}

local function updatespells(inst,owner)

    local spells = deepcopy(BASESPELLS)

    if owner and owner.components.skilltreeupdater:IsActivated("willow_embers") then
        ConcatArrays(spells,FIRE_THROW)
    end

    if owner and owner.components.skilltreeupdater:IsActivated("willow_fire_burst") then
        ConcatArrays(spells,FIRE_BURST)
    end

    if owner and owner.components.skilltreeupdater:IsActivated("willow_fire_ball") then
        ConcatArrays(spells,FIRE_BALL)
    end

    if owner and owner.components.skilltreeupdater:IsActivated("willow_fire_frenzy") then
        ConcatArrays(spells,FIRE_FRENZY)
    end

    if owner and owner.components.skilltreeupdater:IsActivated("willow_allegiance_lunar_fire") then
        ConcatArrays(spells,LUNAR_FIRE)
    end

    if owner and owner.components.skilltreeupdater:IsActivated("willow_allegiance_shadow_fire") then
        ConcatArrays(spells,SHADOW_FIRE)
    end

    inst.components.spellbook:SetItems(spells)
end

local function OnUpdateSpellsDirty(inst)
    local owner = inst.replica.inventoryitem:IsHeldBy(ThePlayer) and ThePlayer or nil

    if owner then
		if inst._onskillrefresh == nil then
			inst._onskillrefresh = function() OnUpdateSpellsDirty(inst) end
			inst:ListenForEvent("onactivateskill_client", inst._onskillrefresh, owner)
			inst:ListenForEvent("ondeactivateskill_client", inst._onskillrefresh, owner)
		end
        updatespells(inst,owner)
	elseif inst._onskillrefresh then
		inst:RemoveEventCallback("onactivateskill_client", inst._onskillrefresh, owner)
		inst:RemoveEventCallback("ondeactivateskill_client", inst._onskillrefresh, owner)
		inst._onskillrefresh = nil
    end
end

local function DoOnClientInit(inst)
    inst:ListenForEvent("willow_ember._updatespells", OnUpdateSpellsDirty)
    OnUpdateSpellsDirty(inst)
end

local function topocket(inst, owner)
    inst.persists = true
    if inst._task ~= nil then
        inst._task:Cancel()
        inst._task = nil
    end

    inst._updatespells:push()
    updatespells(inst,owner)
end

-- END MAGIC STUFF
-----------------------------------------------

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)
    RemovePhysicsColliders(inst)

    inst.AnimState:SetBank("willow_embers")
    inst.AnimState:SetBuild("willow_embers")
    inst.AnimState:PlayAnimation("idle_loop", true)
    inst.AnimState:SetScale(SCALE, SCALE)

    inst:AddTag("nosteal")
    inst:AddTag("NOCLICK")

    inst:AddTag("willow_ember")

    inst.scrapbook_specialinfo = "WILLOWEMBER"

    inst:AddComponent("spellbook")
    inst.components.spellbook:SetRequiredTag("ember_master")
    inst.components.spellbook:SetRadius(SPELLBOOK_RADIUS)
    inst.components.spellbook:SetFocusRadius(SPELLBOOK_FOCUS_RADIUS)
    inst.components.spellbook:SetItems(BASESPELLS)
    inst.components.spellbook:SetOnOpenFn(OnOpenSpellBook)
    inst.components.spellbook:SetOnCloseFn(OnCloseSpellBook)
    inst.components.spellbook.closesound = "meta3/willow/ember_container_close"

    inst:AddComponent("aoetargeting")
    inst.components.aoetargeting:SetAllowWater(true)
    inst.components.aoetargeting.reticule.targetfn = ReticuleTargetAllowWaterFn
    inst.components.aoetargeting.reticule.validcolour = { 1, .75, 0, 1 }
    inst.components.aoetargeting.reticule.invalidcolour = { .5, 0, 0, 1 }
    inst.components.aoetargeting.reticule.ease = true
    inst.components.aoetargeting.reticule.mouseenabled = true
    inst.components.aoetargeting.reticule.twinstickmode = 1
    inst.components.aoetargeting.reticule.twinstickrange = 8

    inst._updatespells = net_event(inst.GUID, "willow_ember._updatespells")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        inst:DoTaskInTime(0,DoOnClientInit)
        return inst
    end
    inst:AddComponent("fuel")
    inst.components.fuel.fueltype = FUELTYPE.LIGHTER
    inst.components.fuel.fuelvalue = TUNING.HUGE_FUEL

    inst:AddComponent("aoespell")

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.canbepickedup = false
    inst.components.inventoryitem.canonlygoinpocket = true
    inst.components.inventoryitem:SetOnDroppedFn(OnDropped)

    inst:AddComponent("locomotor")

    --inst.components.inventoryitem:ChangeImageName("willow_ember")

    inst:AddComponent("stackable")
    inst.components.stackable.maxsize = TUNING.STACK_SIZE_SMALLITEM

    inst:AddComponent("inspectable")

    inst._activetask = nil
    inst._soundtasks = {}

    inst:ListenForEvent("onputininventory", topocket)
    inst:ListenForEvent("ondropped", toground)

    inst.OnEntitySleep = OnEntitySleep
    inst.OnEntityWake = OnEntityWake

    inst.castsound = "maxwell_rework/shadow_magic/cast"

    inst.updatespells = updatespells

    inst._task = nil
    toground(inst)

    return inst
end

local function Buff_OnKill(inst)
    inst.components.debuff:Stop()
end

local function Buff_OnAttached(inst, target)
    inst.entity:SetParent(target.entity)
    inst.Transform:SetPosition(0, 0, 0) --in case of loading

    inst:ListenForEvent("death", function()
        inst.components.debuff:Stop()
    end, target)

    inst.bufftask = inst:DoTaskInTime(TUNING.WILLOW_FIREFRENZY_DURATION, Buff_OnKill)

    if target ~= nil and target:IsValid() then
        target:AddTag("firefrenzy")

        local fx = SpawnPrefab("willow_frenzy")
        fx.entity:SetParent(target.entity)

        inst.bufffx = fx
    end
end

local function Buff_OnDetached(inst, target)
    if target ~= nil and target:IsValid() then
        target:RemoveTag("firefrenzy")
    end

    if inst.bufffx and inst.bufffx:IsValid() then
        inst.bufffx:Kill()
    end

    inst.bufffx = nil
    inst:Remove()
end

local function Buff_OnExtended(inst, target)
    if inst.bufftask ~= nil then
        inst.bufftask:Cancel()
        inst.bufftask = inst:DoTaskInTime(TUNING.WILLOW_FIREFRENZY_DURATION, Buff_OnKill)
    end
end

local function bufffn()
    local inst = CreateEntity()

    if not TheWorld.ismastersim then
        --Not meant for client!
        inst:DoTaskInTime(0, inst.Remove)
        return inst
    end

    inst.entity:AddTransform()

    --[[Non-networked entity]]
    --inst.entity:SetCanSleep(false)
    inst.entity:Hide()
    inst.persists = false

    inst:AddTag("CLASSIFIED")

    inst:AddComponent("debuff")
    inst.components.debuff:SetAttachedFn(Buff_OnAttached)
    inst.components.debuff:SetDetachedFn(Buff_OnDetached)
    inst.components.debuff:SetExtendedFn(Buff_OnExtended)
    inst.components.debuff.keepondespawn = true

    return inst
end


local function reticulefn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    --inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)
    RemovePhysicsColliders(inst)

    inst.AnimState:SetBank("reticuleaoe")
    inst.AnimState:SetBuild("reticuleaoe")
    inst.AnimState:PlayAnimation("idle_target_1")
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGroundFixed)
    inst.AnimState:SetLayer(LAYER_WORLD_BACKGROUND)
    inst.AnimState:SetSortOrder(3)
    inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")

    inst.entity:SetCanSleep(false)
    inst.persists = false

    return inst
end

return Prefab("willow_ember", fn, assets, prefabs),
       Prefab("willow_ember_burst_target_reticule", reticulefn, retucleassets),
       Prefab("buff_firefrenzy", bufffn, nil, prefabs)

