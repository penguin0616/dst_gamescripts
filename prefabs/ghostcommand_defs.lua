local ICON_SCALE = .6

local function ReticuleGhostTargetFn(inst)
    return Vector3(ThePlayer.entity:LocalToWorldSpace(7, 0.001, 0))
end

local function StartAOETargeting(inst)
    if ThePlayer.components.playercontroller then
        ThePlayer.components.playercontroller:StartAOETargetingUsing(inst)
    end
end

-- Commands that aren't skill-enabled
local function GhostUnsummonSpell(inst, doer)
	inst:RemoveTag("unsummoning_spell")

	local doer_ghostlybond = doer.components.ghostlybond
	if not doer_ghostlybond then
		return false
	else
		doer_ghostlybond:Recall(false)
		return true
	end
end

local BASECOMMANDS = {
	{
		label = STRINGS.GHOSTCOMMANDS.UNSUMMON,
		onselect = function(inst)
			local spellbook = inst.components.spellbook
			spellbook:SetSpellName(STRINGS.GHOSTCOMMANDS.UNSUMMON)

			inst:AddTag("unsummoning_spell")
			if TheWorld.ismastersim then
				inst.components.aoespell:SetSpellFn(nil)
                spellbook:SetSpellFn(GhostUnsummonSpell)
			end
		end,
		execute = function(inst)
			if ThePlayer.replica.inventory then
				ThePlayer.replica.inventory:CastSpellBookFromInv(inst)
			end
		end,
		bank = "spell_icons_wendy",
		build = "spell_icons_wendy",
		anims =
		{
			idle = { anim = "unsummon" },
			focus = { anim = "unsummon_focus", loop = true },
			down = { anim = "unsummon_pressed" },
		},
		widget_scale = ICON_SCALE,
	},
}

-- Rile Up and Soothe actions
local function GhostChangeBehaviour(inst, doer)
	doer.components.ghostlybond:ChangeBehaviour()

	inst:PushEvent("spellupdateneeded", doer)

	return true
end

local RILE_UP_ACTION = {
	label = STRINGS.ACTIONS.COMMUNEWITHSUMMONED.MAKE_AGGRESSIVE,
	onselect = function(inst)
		local spellbook = inst.components.spellbook
		spellbook:SetSpellName(STRINGS.ACTIONS.COMMUNEWITHSUMMONED.MAKE_AGGRESSIVE)

		if TheWorld.ismastersim then
			inst.components.aoespell:SetSpellFn(nil)
			spellbook:SetSpellFn(GhostChangeBehaviour)
		end
	end,
	execute = function(inst)
		if ThePlayer.replica.inventory then
			ThePlayer.replica.inventory:CastSpellBookFromInv(inst)
		end
	end,
	bank = "spell_icons_wendy",
	build = "spell_icons_wendy",
	anims =
	{
		idle = { anim = "rile" },
		focus = { anim = "rile_focus", loop = true },
		down = { anim = "rile_pressed" },
	},
	widget_scale = ICON_SCALE,
}

local SOOTHE_ACTION = {
	label = STRINGS.ACTIONS.COMMUNEWITHSUMMONED.MAKE_DEFENSIVE,
	onselect = function(inst)
		local spellbook = inst.components.spellbook
		spellbook:SetSpellName(STRINGS.ACTIONS.COMMUNEWITHSUMMONED.MAKE_DEFENSIVE)

		if TheWorld.ismastersim then
			inst.components.aoespell:SetSpellFn(nil)
			spellbook:SetSpellFn(GhostChangeBehaviour)
		end
	end,
	execute = function(inst)
		if ThePlayer.replica.inventory then
			ThePlayer.replica.inventory:CastSpellBookFromInv(inst)
		end
	end,
	bank = "spell_icons_wendy",
	build = "spell_icons_wendy",
	anims =
	{
		idle = { anim = "soothe" },
		focus = { anim = "soothe_focus", loop = true },
		down = { anim = "soothe_pressed" },
	},
	widget_scale = ICON_SCALE,
}

-- SKILL TREE COMMANDS
local function GhostEscapeSpell(inst, doer)
	local doer_ghostlybond = doer.components.ghostlybond
	if not doer_ghostlybond then return false end

	local ghost = doer_ghostlybond.ghost
	if not ghost then return false end

	ghost:PushEvent("do_ghost_escape")

	if doer.components.spellbookcooldowns then
		doer.components.spellbookcooldowns:RestartSpellCooldown("ghostcommand", TUNING.WENDYSKILL_COMMAND_COOLDOWN)
	end

	return true
end

local function GhostAttackAtSpell(inst, doer, pos)
	local doer_ghostlybond = doer.components.ghostlybond
	if not doer_ghostlybond then return false end

	local ghost = doer_ghostlybond.ghost
	if not ghost then return false end

	ghost:PushEvent("do_ghost_attackat", pos)

	if doer.components.spellbookcooldowns then
		doer.components.spellbookcooldowns:RestartSpellCooldown("ghostcommand", TUNING.WENDYSKILL_COMMAND_COOLDOWN)
	end

	return true
end

local function GhostScareSpell(inst, doer)
	local doer_ghostlybond = doer.components.ghostlybond
	if not doer_ghostlybond then return false end

	local ghost = doer_ghostlybond.ghost
	if not ghost then return false end

	if doer.components.spellbookcooldowns then
		doer.components.spellbookcooldowns:RestartSpellCooldown("ghostcommand", TUNING.WENDYSKILL_COMMAND_COOLDOWN)
	end

	ghost.sg:GoToState("scare")

	return true
end

local function GhostHauntSpell(inst, doer, pos)
	local doer_ghostlybond = doer.components.ghostlybond
	if not doer_ghostlybond then return false end

	local ghost = doer_ghostlybond.ghost
	if not ghost then return false end

	ghost:PushEvent("do_ghost_hauntat", pos)

	if doer.components.spellbookcooldowns then
		doer.components.spellbookcooldowns:RestartSpellCooldown("ghostcommand", TUNING.WENDYSKILL_COMMAND_COOLDOWN)
	end

	return true
end

local SKILLTREE_COMMAND_DEFS =
{
	["wendy_ghostcommand_1"] =
	{
		label = STRINGS.GHOSTCOMMANDS.ESCAPE,
		onselect = function(inst)
			local spellbook = inst.components.spellbook
			spellbook:SetSpellName(STRINGS.GHOSTCOMMANDS.ESCAPE)

			if TheWorld.ismastersim then
				inst.components.aoespell:SetSpellFn(nil)
                spellbook:SetSpellFn(GhostEscapeSpell)
			end
		end,
		execute = function(inst)
			if ThePlayer.replica.inventory then
				ThePlayer.replica.inventory:CastSpellBookFromInv(inst)
			end
		end,
		bank = "spell_icons_wendy",
		build = "spell_icons_wendy",
		anims =
		{
			idle = { anim = "teleport" },
			focus = { anim = "teleport_focus", loop = true },
			down = { anim = "teleport_pressed" },
			disabled = { anim = "teleport_disabled" },
			cooldown = { anim = "teleport_cooldown" },
		},
		widget_scale = ICON_SCALE,
		checkcooldown = function(doer)
			--client safe
			return (doer ~= nil
				and doer.components.spellbookcooldowns
				and doer.components.spellbookcooldowns:GetSpellCooldownPercent("ghostcommand"))
				or nil
		end,
		cooldowncolor = { 0.65, 0.65, 0.65, 0.75 },
	},
	["wendy_ghostcommand_2"] =
    {
        label = STRINGS.GHOSTCOMMANDS.ATTACK_AT,
        onselect = function(inst)
			local spellbook = inst.components.spellbook
			local aoetargeting = inst.components.aoetargeting

            spellbook:SetSpellName(STRINGS.GHOSTCOMMANDS.ATTACK_AT)
            aoetargeting:SetDeployRadius(0)
			aoetargeting:SetRange(20)
            aoetargeting.reticule.reticuleprefab = "reticuleaoeghosttarget"
            aoetargeting.reticule.pingprefab = "reticuleaoeghosttarget_ping"

            aoetargeting.reticule.mousetargetfn = nil
            aoetargeting.reticule.targetfn = ReticuleGhostTargetFn
            aoetargeting.reticule.updatepositionfn = nil
			aoetargeting.reticule.twinstickrange = 15

            if TheWorld.ismastersim then
                aoetargeting:SetTargetFX("reticuleaoeghosttarget")
                inst.components.aoespell:SetSpellFn(GhostAttackAtSpell)
                spellbook:SetSpellFn(nil)
            end
        end,
        execute = StartAOETargeting,
		bank = "spell_icons_wendy",
		build = "spell_icons_wendy",
		anims =
		{
			idle = { anim = "attack_at" },
			focus = { anim = "attack_at_focus", loop = true },
			down = { anim = "attack_at_pressed" },
			disabled = { anim = "attack_at_disabled" },
			cooldown = { anim = "attack_at_cooldown" },
		},
        widget_scale = ICON_SCALE,
		checkcooldown = function(doer)
			--client safe
			return (doer ~= nil
				and doer.components.spellbookcooldowns
				and doer.components.spellbookcooldowns:GetSpellCooldownPercent("ghostcommand"))
				or nil
		end,
		cooldowncolor = { 0.65, 0.65, 0.65, 0.75 },
    },
	["wendy_ghostcommand_haunt"] =
    {
        label = STRINGS.GHOSTCOMMANDS.HAUNT_AT,
        onselect = function(inst)
			local spellbook = inst.components.spellbook
			local aoetargeting = inst.components.aoetargeting

            spellbook:SetSpellName(STRINGS.GHOSTCOMMANDS.HAUNT_AT)
            aoetargeting:SetDeployRadius(0)
			aoetargeting:SetRange(20)
            aoetargeting.reticule.reticuleprefab = "reticuleaoeghosttarget"
            aoetargeting.reticule.pingprefab = "reticuleaoeghosttarget_ping"

            aoetargeting.reticule.mousetargetfn = nil
            aoetargeting.reticule.targetfn = ReticuleGhostTargetFn
            aoetargeting.reticule.updatepositionfn = nil
			aoetargeting.reticule.twinstickrange = 15

            if TheWorld.ismastersim then
                aoetargeting:SetTargetFX("reticuleaoeghosttarget")
                inst.components.aoespell:SetSpellFn(GhostHauntSpell)
                spellbook:SetSpellFn(nil)
            end
        end,
        execute = StartAOETargeting,
		bank = "spell_icons_wendy",
		build = "spell_icons_wendy",
		anims =
		{
			idle = { anim = "haunt" },
			focus = { anim = "haunt_focus", loop = true },
			down = { anim = "haunt_pressed" },
			cooldown = { anim = "haunt_cooldown" },
		},
        widget_scale = ICON_SCALE,
		checkcooldown = function(doer)
			--client safe
			return (doer ~= nil
				and doer.components.spellbookcooldowns
				and doer.components.spellbookcooldowns:GetSpellCooldownPercent("ghostcommand"))
				or nil
		end,
		cooldowncolor = { 0.65, 0.65, 0.65, 0.75 },
    },
	["wendy_ghostcommand_3"] =
    {
        label = STRINGS.GHOSTCOMMANDS.SCARE,
		onselect = function(inst)
			local spellbook = inst.components.spellbook
			spellbook:SetSpellName(STRINGS.GHOSTCOMMANDS.SCARE)

			if TheWorld.ismastersim then
				inst.components.aoespell:SetSpellFn(nil)
                spellbook:SetSpellFn(GhostScareSpell)
			end
		end,
		execute = function(inst)
			if ThePlayer.replica.inventory then
				ThePlayer.replica.inventory:CastSpellBookFromInv(inst)
			end
		end,
		bank = "spell_icons_wendy",
		build = "spell_icons_wendy",
		anims =
		{
			idle = { anim = "scare" },
			focus = { anim = "scare_focus", loop = true },
			down = { anim = "scare_pressed" },
			disabled = { anim = "scare_disabled" },
			cooldown = { anim = "scare_cooldown" },
		},
        widget_scale = ICON_SCALE,
		checkcooldown = function(doer)
			--client safe
			return (doer ~= nil
				and doer.components.spellbookcooldowns
				and doer.components.spellbookcooldowns:GetSpellCooldownPercent("ghostcommand"))
				or nil
		end,
		cooldowncolor = { 0.65, 0.65, 0.65, 0.75 },
    },
}

local function GetGhostCommandsFor(owner)
    local commands = shallowcopy(BASECOMMANDS)

	local behaviour_command = (owner:HasTag("has_aggressive_follower") and SOOTHE_ACTION) or RILE_UP_ACTION
	table.insert(commands, behaviour_command)

    if owner.components.skilltreeupdater then
        for skill, skill_command in pairs(SKILLTREE_COMMAND_DEFS) do
            if owner.components.skilltreeupdater:IsActivated(skill) then
                table.insert(commands, skill_command)
            end
        end
    end

    return commands
end

local function GetBaseCommands()
    return BASECOMMANDS
end

return {
    GetGhostCommandsFor = GetGhostCommandsFor,
    GetBaseCommands = GetBaseCommands,
}