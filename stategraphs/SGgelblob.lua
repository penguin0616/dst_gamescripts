require("stategraphs/commonstates")

local events =
{
	CommonHandlers.OnAttacked(),
	CommonHandlers.OnDeath(),
	EventHandler("jiggle", function(inst)
		if not inst.components.health:IsDead() and
			(not inst.sg:HasStateTag("busy") or inst.sg:HasStateTag("caninterrupt"))
		then
			inst.sg:GoToState("jiggle")
		end
	end),
}

local function _PlayAnimation(inst, anim, loop)
	anim = anim..inst.size
	inst.AnimState:PlayAnimation(anim, loop)
	inst.back.AnimState:PlayAnimation(anim, loop)
end

local function _PushAnimation(inst, anim, loop)
	anim = anim..inst.size
	inst.AnimState:PushAnimation(anim, loop)
	inst.back.AnimState:PushAnimation(anim, loop)
end

local function SetShadowScale(inst, scale)
	inst.DynamicShadow:SetSize(4.5 * scale, 2.5 * scale)
end

local states =
{
	State{
		name = "idle",
		tags = { "idle", "canrotate" },

		onenter = function(inst)
			_PlayAnimation(inst, "idle", true)
		end,
	},

	State{
		name = "spawn",
		tags = { "spawning", "busy", "noattack", "temp_invincible" },

		onenter = function(inst)
			_PlayAnimation(inst, "spawn")
			SetShadowScale(inst, 0.19)
		end,

		timeline =
		{
			FrameEvent(1, function(inst) SetShadowScale(inst, 0.25) end),
			FrameEvent(2, function(inst) SetShadowScale(inst, 0.34) end),
			FrameEvent(3, function(inst) SetShadowScale(inst, 0.45) end),
			FrameEvent(4, function(inst) SetShadowScale(inst, 0.6) end),
			FrameEvent(5, function(inst) SetShadowScale(inst, 0.8) end),

			FrameEvent(33, function(inst) SetShadowScale(inst, 0.82) end),
			FrameEvent(34, function(inst) SetShadowScale(inst, 0.86) end),
			FrameEvent(35, function(inst) SetShadowScale(inst, 0.92) end),
			FrameEvent(36, function(inst)
				SetShadowScale(inst, 1)
				inst.sg:RemoveStateTag("noattack")
				inst.sg:RemoveStateTag("temp_invincible")
				inst.sg:RemoveStateTag("spawning")
				inst:OnSpawnLanded()
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("idle")
				end
			end),
		},

		onexit = function(inst)
			SetShadowScale(inst, 1)
		end,
	},

	State{
		name = "hit",
		tags = { "hit", "busy" },

		onenter = function(inst)
			_PlayAnimation(inst, "hit")
		end,

		timeline =
		{
			FrameEvent(6, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("idle")
				end
			end),
		},
	},

	State{
		name = "jiggle",
		tags = { "hit", "busy" },

		onenter = function(inst)
			_PlayAnimation(inst, "contact_jiggle")
		end,

		timeline =
		{
			FrameEvent(6, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("idle")
				end
			end),
		},
	},

	State{
		name = "spit",
		tags = { "busy" },

		onenter = function(inst)
			_PlayAnimation(inst, "spit")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("idle")
				end
			end),
		},
	},

	State{
		name = "shrink_med",
		tags = { "hit", "busy" },

		onenter = function(inst)
			inst.size = "_med"
			_PlayAnimation(inst, "big_to")
		end,

		timeline =
		{
			FrameEvent(8, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("idle")
				end
			end),
		},
	},

	State{
		name = "shrink_small",
		tags = { "hit", "busy" },

		onenter = function(inst)
			inst.size = "_small"
			_PlayAnimation(inst, "med_to")
		end,

		timeline =
		{
			FrameEvent(8, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("idle")
				end
			end),
		},
	},

	State{
		name = "grow_med",
		tags = { "hit", "busy" },

		onenter = function(inst)
			inst.size = "_med"
			_PlayAnimation(inst, "small_to")
		end,

		timeline =
		{
			FrameEvent(8, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("idle")
				end
			end),
		},
	},

	State{
		name = "grow_big",
		tags = { "hit", "busy" },

		onenter = function(inst)
			inst.size = "_big"
			_PlayAnimation(inst, "med_to")
		end,

		timeline =
		{
			FrameEvent(8, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("idle")
				end
			end),
		},
	},

	State{
		name = "death",
		tags = { "dead", "busy" },

		onenter = function(inst)
			inst.size = "_small"
			_PlayAnimation(inst, "death")
		end,

		timeline =
		{
			FrameEvent(10, function(inst)
				inst.DynamicShadow:Enable(false)
			end),
		},

		onexit = function(inst)
			--should not reach here
			inst.DynamicShadow:Enable(true)
		end,
	},
}

return StateGraph("gelblob", states, events, "idle")
