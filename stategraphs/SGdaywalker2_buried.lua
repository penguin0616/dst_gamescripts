local function GetLevelAnim(inst, anim)
	return anim..(inst.sg.mem.level == 2 and "_small" or "_full")
end

local function PlayAnimation(inst, anim, loop)
	anim = GetLevelAnim(inst, anim)
	inst.AnimState:PlayAnimation(anim, loop)
	if inst.junkfx then
		for i, v in ipairs(inst.junkfx) do
			v.AnimState:PlayAnimation(anim, loop)
		end
	end
end

local function PushAnimation(inst, anim, loop)
	anim = GetLevelAnim(inst, anim)
	inst.AnimState:PushAnimation(anim, loop)
	if inst.junkfx then
		for i, v in ipairs(inst.junkfx) do
			v.AnimState:PushAnimation(anim, loop)
		end
	end
end

local states =
{
	State{
		name = "transition",
	},

	State{
		name = "idle",

		onenter = function(inst)
			PlayAnimation(inst, "buried_hold", true)
			local numloops = math.random(5)
			if numloops > 3 then
				--give extra chance for 2-3 loops instead of 1
				numloops = numloops - 2
			end
			inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength() * numloops)
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("struggle")
		end,
	},

	State{
		name = "struggle",

		onenter = function(inst)
			PlayAnimation(inst, "buried")
			inst.SoundEmitter:PlaySound("qol1/daywalker_scrappy/buried_stagger")
		end,

		timeline =
		{
			FrameEvent(26, function(inst)
				local junk = inst.components.entitytracker:GetEntity("junk")
				if junk then
					junk:PushEvent("shake")
				end
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
		name = "tryemerge",

		onenter = function(inst)
			PlayAnimation(inst, "buried_stagger")
			PushAnimation(inst, "buried_stagger_loop")
			inst.SoundEmitter:PlaySound("qol1/daywalker_scrappy/buried_stagger")
		end,
	},

	State{
		name = "cancelemerge",

		onenter = function(inst)
			PlayAnimation(inst, "buried_stagger_pst")
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
}

return StateGraph("daywalker2_buried", states, {}, "idle")
