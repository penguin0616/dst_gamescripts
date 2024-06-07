require("stategraphs/commonstates")

local actionhandlers =
{
	ActionHandler(ACTIONS.PICKUP, "pickup"),
	ActionHandler(ACTIONS.STORE, "store"),
}

local events =
{
	CommonHandlers.OnLocomote(true, false),
	EventHandler("onfueldsectionchanged", function(inst, data)
		if not inst.sg:HasStateTag("busy") then
			inst.sg.statemem.keepnofaced = true
			inst.sg:GoToState("poweroff")
		end
	end),
}

local states =
{
	State{
		name = "idle",
		tags = { "idle", "canrotate" },

		onenter = function(inst, pushanim)
			if inst.components.fueled:IsEmpty() then
				inst.sg.statemem.keepnofaced = true
				inst.sg:GoToState("poweroff")
				return
			end
			inst.components.locomotor:StopMoving()
			inst.Transform:SetNoFaced()
			if pushanim then
				inst.AnimState:PushAnimation("idle")
			else
				inst.AnimState:PlayAnimation("idle", true)
			end
		end,

		onexit = function(inst)
			if not inst.sg.statemem.keepnofaced then
				inst.Transform:SetFourFaced()
			end
		end,
	},

	State{
		name = "poweron",
		tags = { "busy" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.Transform:SetNoFaced()
			inst.AnimState:PlayAnimation("poweron")
		end,

		timeline =
		{
			FrameEvent(34, function(inst)
				inst.sg.statemem.keepnofaced = true
				inst.sg:GoToState("idle", true)
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.keepnofaced then
				inst.Transform:SetFourFaced()
			end
		end,
	},

	State{
		name = "poweroff",
		tags = { "busy" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.Transform:SetNoFaced()
			inst.AnimState:PlayAnimation("poweroff")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst:OnDeactivateRobot()
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.keepnofaced then
				inst.Transform:SetFourFaced()
			end
		end,
	},

	State{
		name = "pickup",
		tags = { "busy", "jumping" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("pickup")
		end,

		timeline =
		{
			FrameEvent(0, function(inst)
				--can't start physics in onenter, since it'll get stopped after entering the action state
				local target = inst.bufferedaction and inst.bufferedaction.target or nil
				if target and target:IsValid() then
					local x, y, z = inst.Transform:GetWorldPosition()
					local x1, y1, z1 = target.Transform:GetWorldPosition()
					local dx, dz = x1 - x, z1 - z
					if dx ~= 0 or dz ~= 0 then
						inst.Transform:SetRotation(math.atan2(-dz, dx) * RADIANS)
						local dist = dx * dx + dz * dz
						dist = dist < 4 and math.sqrt(dist) or 2
						local speed = dist / (10 * FRAMES)
						inst.Physics:SetMotorVelOverride(speed, 0, 0)
					end
				else
					inst.Physics:SetMotorVelOverride(0.75 / (7 * FRAMES), 0, 0)
				end
			end),
			FrameEvent(10, function(inst)
				inst.Physics:ClearMotorVelOverride()
				inst.Physics:Stop()
				local target = inst.bufferedaction and inst.bufferedaction.target
				if target and not target:IsInLimbo() and target:IsValid() and inst:IsNear(target, 0.5) then
					inst:PerformBufferedAction()
				else
					inst:ClearBufferedAction()
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

		onexit = function(inst)
			inst.Physics:ClearMotorVelOverride()
			inst.Physics:Stop()
		end,
	},

	State{
		name = "store",
		tags = { "busy" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.Transform:SetNoFaced()
			inst.AnimState:PlayAnimation("dropoff")
			inst.Physics:SetMass(0)
		end,

		timeline =
		{
			FrameEvent(7, function(inst)
				inst.Physics:SetMass(50)
				inst:PerformBufferedAction()
			end),
			FrameEvent(35, function(inst)
				inst.components.inventory:CloseAllChestContainers()
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.keepnofaced = true
					inst.sg:GoToState("idle")
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.keepnofaced then
				inst.Transform:SetFourFaced()
			end
			inst.components.inventory:CloseAllChestContainers()
		end,
	},
}

CommonStates.AddRunStates(states)

return StateGraph("winona_storage_robot", states, events, "poweron", actionhandlers)
