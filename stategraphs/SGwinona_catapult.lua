local events =
{
    EventHandler("doattack", function(inst, data)
        if inst.sg.mem.ison and
            data ~= nil and
            data.target ~= nil and
            not inst.components.health:IsDead() and
            (not inst.sg:HasStateTag("busy") or inst.sg:HasStateTag("hit")) and
            data.target:IsValid() and
			not inst:IsTargetTooClose(data.target)
		then
            inst.sg:GoToState("attack", data.target)
        end
    end),
	EventHandler("dovolley", function(inst, data)
		if inst.sg.mem.ison and data and data.targetpos and not inst.components.health:IsDead() then
			inst.sg.mem.elemvolleyqueue = nil
			if not inst.sg:HasStateTag("busy") or inst.sg:HasStateTag("hit") then
				inst.sg:GoToState("attack", data.targetpos)
			elseif inst.sg.mem.volleyqueue then
				table.insert(inst.sg.mem.volleyqueue, data.targetpos)
			else
				inst.sg.mem.volleyqueue = { data.targetpos }
			end
		end
	end),
	EventHandler("doelementalvolley", function(inst, data)
		if inst.sg.mem.ison and data and data.targetpos and not inst.components.health:IsDead() then
			inst.sg.mem.volleyqueue = nil
			if not inst.sg:HasStateTag("busy") or inst.sg:HasStateTag("hit") then
				inst.sg:GoToState("attack", { pos = data.targetpos, mega = true })
			elseif inst.sg.mem.elemvolleyqueue then
				table.insert(inst.sg.mem.elemvolleyqueue, data.targetpos)
			else
				inst.sg.mem.elemvolleyqueue = { data.targetpos }
			end
		end
	end),
    EventHandler("attacked", function(inst, data)
        if not inst.components.health:IsDead() and
            (not inst.sg:HasStateTag("busy") or inst.sg:HasStateTag("caninterrupt")) and
            (data == nil or data.damage ~= 0 or data.weapon == nil or not data.weapon._nocatapulthit) then
            --V2C: last line of conditions is for fire/ice staffs, since those generally don't trigger hit state on structures
            inst.sg:GoToState("hit")
        end
    end),
}

local function TryQueuedVolley(inst)
	if inst:IsActiveMode() then
		if inst.sg.mem.elemvolleyqueue then
			local targetpos = table.remove(inst.sg.mem.elemvolleyqueue, 1)
			if #inst.sg.mem.elemvolleyqueue <= 0 then
				inst.sg.mem.elemvolleyqueue = nil
			end
			if targetpos then
				inst.sg:GoToState("attack", { pos = targetpos, mega = true })
				return true
			end
		end
		if inst.sg.mem.volleyqueue then
			local targetpos = table.remove(inst.sg.mem.volleyqueue, 1)
			if #inst.sg.mem.volleyqueue <= 0 then
				inst.sg.mem.volleyqueue = nil
			end
			if targetpos then
				inst.sg:GoToState("attack", targetpos)
				return true
			end
		end
	end
	return false
end

local function ClearQueuedVolley(inst)
	inst.sg.mem.volleyqueue = nil
	inst.sg.mem.elemvolleyqueue = nil
end

local states =
{
    State{
        name = "place",
        tags = { "busy", "noattack" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("place")
            inst.SoundEmitter:PlaySound("dontstarve/common/together/catapult/place")
            inst:AddTag("NOCLICK")
            inst.sg.mem.recentlyplaced = true
            inst.sg.mem.ison = nil
        end,

        timeline =
        {
            TimeEvent(18 * FRAMES, function(inst)
                inst.sg:AddStateTag("caninterrupt")
                inst.sg:RemoveStateTag("noattack")
                if not inst.components.health:IsDead() then
                    inst:RemoveTag("NOCLICK")
                    if not inst:HasTag("burnt") then
						inst:OnReadyForConnection()
                    end
                end
            end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },

        onexit = function(inst)
            if inst.sg:HasStateTag("noattack") and not inst.components.health:IsDead() then
                inst:RemoveTag("NOCLICK")
                if not inst:HasTag("burnt") then
					inst:OnReadyForConnection()
                end
            end
        end,
    },

	State{
		name = "deploy",
		tags = { "busy", "noattack" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("deploy")
			inst:AddTag("NOCLICK")
			inst.sg.mem.recentlyplaced = true
			inst.sg.mem.ison = nil
		end,

		timeline =
		{
			SoundFrameEvent(4, "meta4/winona_catapult/deploy_f4"),
			FrameEvent(17, function(inst)
				inst.sg:AddStateTag("caninterrupt")
				inst.sg:RemoveStateTag("noattack")
				if not inst.components.health:IsDead() then
					inst:RemoveTag("NOCLICK")
					if not inst:HasTag("burnt") then
						inst:OnReadyForConnection()
					end
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
			if inst.sg:HasStateTag("noattack") and not inst.components.health:IsDead() then
				inst:RemoveTag("NOCLICK")
				if not inst:HasTag("burnt") then
					inst:OnReadyForConnection()
				end
			end
		end,
	},

    State{
        name = "idle",
        tags = { "idle", "canrotate" },

        onenter = function(inst, loading)
            if inst.sg.mem.ison then
				if inst:IsActiveMode() then
                    local anim = inst.sg.mem.recentlyplaced and "idle_nodir" or "idle"
                    if not inst.AnimState:IsCurrentAnimation(anim) then
                        inst.AnimState:PlayAnimation(anim, true)
                    end
                else
                    inst.sg:GoToState("powerdown")
					return
                end
			elseif inst:IsActiveMode() then
                if loading then
                    inst.sg.mem.ison = true
                    inst.sg.mem.recentlyplaced = nil
                    if not inst.AnimState:IsCurrentAnimation("idle") then
                        inst.AnimState:PlayAnimation("idle", true)
						inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)
                    end
                else
                    inst.sg:GoToState("powerup")
					return
                end
            else
            	ClearQueuedVolley(inst)
                inst.AnimState:PlayAnimation(inst.sg.mem.recentlyplaced and "idle_off_nodir" or "idle_off")
            end

			TryQueuedVolley(inst)
        end,

        events =
        {
            EventHandler("togglepower", function(inst, data)
                if inst.sg.mem.ison then
                    if not data.ison then
                        inst.sg:GoToState("powerdown")
                    end
                elseif data.ison then
                    inst.sg:GoToState("powerup")
                end
            end),
        },
    },

    State{
        name = "powerup",
        tags = { "busy", "caninterrupt" },

        onenter = function(inst)
            inst.SoundEmitter:PlaySound("dontstarve/common/together/catapult/hit", nil, .5)
            inst.SoundEmitter:PlaySound("dontstarve/common/together/catapult/ratchet_LP", "power")
            inst.AnimState:PlayAnimation(inst.sg.mem.recentlyplaced and "idle_trans_nodir" or "idle_trans")
            inst.sg.mem.ison = true
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },

        onexit = function(inst)
            inst.SoundEmitter:KillSound("power")
        end,
    },

    State{
        name = "powerdown",
        tags = { "busy", "caninterrupt" },

        onenter = function(inst)
            inst.SoundEmitter:PlaySound("dontstarve/common/together/catapult/ratchet_LP", "power")
            inst.AnimState:PlayAnimation(inst.sg.mem.recentlyplaced and "idle_trans_off_nodir" or "idle_trans_off")
            inst.sg.mem.ison = false
            ClearQueuedVolley(inst)
        end,

        timeline =
        {
            TimeEvent(8 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/common/together/catapult/hit", nil, .35) end),
            TimeEvent(11 * FRAMES, function(inst) inst.SoundEmitter:KillSound("power") end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },

        onexit = function(inst)
            inst.SoundEmitter:KillSound("power")
        end,
    },

    State{
        name = "hit",
        tags = { "hit", "busy" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation((inst.sg.mem.ison and "hit" or "hit_off")..(inst.sg.mem.recentlyplaced and "_nodir" or ""))
            inst.SoundEmitter:PlaySound("dontstarve/common/together/catapult/hit")
        end,

        timeline =
        {
            TimeEvent(4 * FRAMES, function(inst)
                inst.sg:AddStateTag("caninterrupt")
            end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },

    State{
        name = "attack",
        tags = { "attack", "busy" },

        onenter = function(inst, target)
            inst.sg.mem.recentlyplaced = nil

			if EntityScript.is_instance(target) then
				if target:IsValid() then
					inst.sg.statemem.target = target
					inst.sg.statemem.targetpos = target:GetPosition()
					inst:ForceFacePoint(inst.sg.statemem.targetpos)
				end
			elseif Vector3.is_instance(target) then
				inst.sg.statemem.targetpos = Vector3(target:Get())
				inst:ForceFacePoint(inst.sg.statemem.targetpos)
			elseif target and target.mega then
				inst.sg.statemem.mega = true
				inst.sg.statemem.targetpos = Vector3(target.pos:Get())
				inst:ForceFacePoint(inst.sg.statemem.targetpos)
			end

			local numshadow, numlunar, numtotal = 0, 0, 0
			inst.components.circuitnode:ForEachNode(function(inst, node)
				if node.components.fueled and not node.components.fueled:IsEmpty() then
					local elem = node:CheckElementalBattery()
					if elem == "horror" then
						numshadow = numshadow + 1
					elseif elem == "brilliance" then
						numlunar = numlunar + 1
					end
					numtotal = numtotal + 1
				end
			end)
			if numtotal > 0 then
				local costperbattery
				if numshadow == 0 and numlunar == 0 then
					inst.sg.statemem.mega = nil
					costperbattery = TUNING.WINONA_CATAPULT_ATTACK_POWER_COST / numtotal
				else
					costperbattery = (inst.sg.statemem.mega and TUNING.WINONA_CATAPULT_MEGA_ATTACK_POWER_COST or TUNING.WINONA_CATAPULT_ATTACK_POWER_COST) / (numshadow + numlunar)
					inst.sg.statemem.elemental = numshadow > 0 and (numlunar > 0 and "hybrid" or "shadow") or "lunar"
				end
				inst.components.circuitnode:ForEachNode(function(inst, node)
					if node.components.fueled and not node.components.fueled:IsEmpty() then
						if inst.sg.statemem.elemental == "shadow" then
							if node:CheckElementalBattery() == "horror" then
								node:ConsumeBatteryAmount(costperbattery, inst)
							end
						elseif inst.sg.statemem.elemental == "lunar" then
							if node:CheckElementalBattery() == "brilliance" then
								node:ConsumeBatteryAmount(costperbattery, inst)
							end
						elseif inst.sg.statemem.elemental == "hybrid" then
							local elem = node:CheckElementalBattery()
							if elem == "horror" or elem == "brilliance" then
								node:ConsumeBatteryAmount(costperbattery, inst)
							end
						else
							node:ConsumeBatteryAmount(costperbattery, inst)
						end
					end
				end)
			else
				inst.sg.statemem.mega = nil
			end

            inst.AnimState:PlayAnimation("atk")
            inst.SoundEmitter:PlaySound("dontstarve/common/together/catapult/ratchet_LP", "attack_pre")
			inst:OnStartAttack(inst.sg.statemem.elemental)
        end,

        onupdate = function(inst)
            if inst.sg.statemem.target ~= nil then
                if inst.sg.statemem.target:IsValid() then
                    inst.sg.statemem.targetpos.x, inst.sg.statemem.targetpos.y, inst.sg.statemem.targetpos.z = inst.sg.statemem.target.Transform:GetWorldPosition()
                    inst:ForceFacePoint(inst.sg.statemem.targetpos)
                else
                    inst.sg.statemem.target = nil
                end
            end
        end,

        timeline =
        {
            TimeEvent(20 * FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/common/together/catapult/fire")
            end),
            TimeEvent(21 * FRAMES, function(inst)
                inst.components.combat:StartAttack()
                local x, y, z = inst.Transform:GetWorldPosition()
                inst.sg.statemem.rock = SpawnPrefab("winona_catapult_projectile")
				inst.sg.statemem.rock:SetElementalRock(inst.sg.statemem.elemental, inst.sg.statemem.mega)
				inst.sg.statemem.rock:SetAoeRadius(inst.sg.statemem.mega and inst.AOE_RADIUS * 2 or inst.AOE_RADIUS, inst._aoe)
                inst.sg.statemem.rock.Transform:SetPosition(x, y, z)
                local pos = inst.sg.statemem.targetpos
                if pos == nil then
                    --in case of missing target, toss a rock random distance in front of current facing
                    local theta = (inst.Transform:GetRotation() + 90) * DEGREES
                    local len = GetRandomMinMax(TUNING.WINONA_CATAPULT_MIN_RANGE, TUNING.WINONA_CATAPULT_MAX_RANGE)
                    pos = inst:GetPosition()
                    pos.x = pos.x + math.sin(theta) * len
                    pos.z = pos.z + math.cos(theta) * len
                else
                    if inst.sg.statemem.target ~= nil and inst.sg.statemem.target:IsValid() then
                        pos.x, pos.y, pos.z = inst.sg.statemem.target.Transform:GetWorldPosition()
                    end
                    local dx = pos.x - x
                    local dz = pos.z - z
                    local l = dx * dx + dz * dz
                    if l < TUNING.WINONA_CATAPULT_MIN_RANGE * TUNING.WINONA_CATAPULT_MIN_RANGE then
                        l = TUNING.WINONA_CATAPULT_MIN_RANGE / math.sqrt(l)
                        pos.x = x + dx * l
                        pos.z = z + dz * l
					elseif l > TUNING.WINONA_CATAPULT_MAX_RANGE * TUNING.WINONA_CATAPULT_MAX_RANGE then
						l = TUNING.WINONA_CATAPULT_MAX_RANGE / math.sqrt(l)
						pos.x = x + dx * l
						pos.z = z + dz * l
                    end
                end
                pos.y = 0
                inst.sg.statemem.target = nil --stop onupdate
                inst:ForceFacePoint(pos)
                inst.sg.statemem.rock.components.complexprojectile:Launch(pos, inst)
                inst.sg.statemem.rock:Hide()
                --inst.sg.statemem.damageself = true
            end),
            TimeEvent(24 * FRAMES, function(inst)
                inst.SoundEmitter:KillSound("attack_pre")
                if inst.sg.statemem.rock:IsValid() then
                    inst.AnimState:Hide("rock")
                    inst.sg.statemem.rock:Show()
                end
                inst.sg.statemem.rock = nil
            end),
            TimeEvent(34 * FRAMES, function(inst)
				if TryQueuedVolley(inst) then
					return
				end
                inst.sg:RemoveStateTag("busy")
            end),
            --[[TimeEvent(36 * FRAMES, function(inst)
                inst.sg.statemem.damageself = nil
                if not inst.components.health:IsDead() then
                    local state = inst._state
                    inst.components.health:DoDelta(TUNING.WINONA_CATAPULT_HEALTH / -8)
                    if state ~= inst._state then
                        inst.sg:GoToState("hit")
                    end
                end
            end),]]
            TimeEvent(38 * FRAMES, function(inst)
                inst.sg:AddStateTag("canrotate")
            end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },

        onexit = function(inst)
            inst.SoundEmitter:KillSound("attack_pre")
            if inst.sg.statemem.rock ~= nil then
                inst.sg.statemem.rock:Remove()
            end
            inst.AnimState:Show("rock")
            --[[if inst.sg.statemem.damageself and not inst.components.health:IsDead() then
                local state = inst._state
                inst.components.health:DoDelta(TUNING.WINONA_CATAPULT_HEALTH / -8)
                if state ~= inst._state then
                    inst.sg:GoToState("hit")
                end
            end]]
        end,
    },

    State{
        name = "death",
        tags = { "death", "busy" },

        onenter = function(inst)
			inst:AddTag("NOCLICK")
			inst:AddTag("notarget")
            inst.AnimState:PlayAnimation("death")
            inst.SoundEmitter:PlaySound("dontstarve/common/together/catapult/destroy")
        end,
    },
}

return StateGraph("winona_catapult", states, events, "idle")
