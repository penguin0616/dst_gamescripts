require("stategraphs/commonstates")

local function FixupWorkerCarry(inst, swap)
    if inst.prefab == "shadowworker" then
        if swap == nil then
            inst.AnimState:ClearOverrideSymbol("swap_object")
            inst.AnimState:Hide("ARM_carry")
            inst.AnimState:Show("ARM_normal")
        else
            inst.AnimState:Show("ARM_carry")
            inst.AnimState:Hide("ARM_normal")
            inst.AnimState:OverrideSymbol("swap_object", swap, swap)
        end
    else
        if swap == nil then -- DEPRECATED workers.
            inst.AnimState:Hide("swap_arm_carry")
        --'else' case cannot exist old workers had one item only assumed.
        end
    end
end

local function DetachFX(fx)
	fx.Transform:SetPosition(fx.Transform:GetWorldPosition())
	fx.entity:SetParent(nil)
end

local function DoDespawnFX(inst)
	--shadow_despawn is in the air => detaches from sinking boats
	--shadow_glob_fx is on ground => dies with sinking boats
	local x, y, z = inst.Transform:GetWorldPosition()
	local fx1 = SpawnPrefab("shadow_despawn")
	local fx2 = SpawnPrefab("shadow_glob_fx")
	fx2.AnimState:SetScale(math.random() < .5 and -1.3 or 1.3, 1.3, 1.3)
	local platform = inst:GetCurrentPlatform()
	if platform ~= nil then
		fx1.entity:SetParent(platform.entity)
		fx2.entity:SetParent(platform.entity)
		fx1:ListenForEvent("onremove", function() DetachFX(fx1) end, platform)
		x, y, z = platform.entity:WorldToLocalSpace(x, y, z)
	end
	fx1.Transform:SetPosition(x, y, z)
	fx2.Transform:SetPosition(x, y, z)
end

local function TrySplashFX(inst, size)
	local x, y, z = inst.Transform:GetWorldPosition()
	if TheWorld.Map:IsOceanAtPoint(x, 0, z) then
		SpawnPrefab("ocean_splash_"..(size or "med")..tostring(math.random(2))).Transform:SetPosition(x, 0, z)
		return true
	end
end

local function TryStepSplash(inst)
	local t = GetTime()
	if (inst.sg.mem.laststepsplash == nil or inst.sg.mem.laststepsplash + .1 < t) and TrySplashFX(inst) then
		inst.sg.mem.laststepsplash = t
	end
end

local function DoSound(inst, sound)
	inst.SoundEmitter:PlaySound(sound)
end

local actionhandlers =
{
    ActionHandler(ACTIONS.CHOP,
        function(inst)
            FixupWorkerCarry(inst, "swap_axe")
            if not inst.sg:HasStateTag("prechop") then
                return inst.sg:HasStateTag("chopping")
                    and "chop"
                    or "chop_start"
            end
        end),
    ActionHandler(ACTIONS.MINE,
        function(inst)
            FixupWorkerCarry(inst, "swap_pickaxe")
            if not inst.sg:HasStateTag("premine") then
                return inst.sg:HasStateTag("mining")
                    and "mine"
                    or "mine_start"
            end
        end),
    ActionHandler(ACTIONS.DIG,
        function(inst)
            FixupWorkerCarry(inst, "swap_shovel")
            if not inst.sg:HasStateTag("predig") then
                return inst.sg:HasStateTag("digging")
                    and "dig"
                    or "dig_start"
            end
        end),
    ActionHandler(ACTIONS.GIVE, "give"),
    ActionHandler(ACTIONS.GIVEALLTOPLAYER, "give"),
    ActionHandler(ACTIONS.DROP, "give"),
    ActionHandler(ACTIONS.PICKUP, "take"),
    ActionHandler(ACTIONS.CHECKTRAP, "take"),
}

local events =
{
    CommonHandlers.OnLocomote(true, false),
    CommonHandlers.OnAttacked(),
    CommonHandlers.OnDeath(),
    CommonHandlers.OnAttack(),
    EventHandler("dance", function(inst)
        if not inst.sg:HasStateTag("busy") and (inst._brain_dancedata ~= nil or not inst.sg:HasStateTag("dancing")) then
            inst.sg:GoToState("dance")
        end
    end),
}

local states =
{
	State{
		name = "spawn",
		tags = { "busy", "noattack" },

		onenter = function(inst, mult)
			inst.Physics:Stop()
			ToggleOffCharacterCollisions(inst)
			inst.AnimState:PlayAnimation("minion_spawn")
           -- inst.SoundEmitter:PlaySound("maxwell_rework/shadow_worker/spawn")
			inst.components.health:SetInvincible(true)
			mult = mult or .8 + math.random() * .2
			inst.AnimState:SetDeltaTimeMultiplier(mult)

			mult = 1 / mult
			inst.sg.statemem.tasks =

			{
                inst:DoTaskInTime(0 * FRAMES * mult, DoSound, "maxwell_rework/shadow_worker/spawn"),
				inst:DoTaskInTime(0 * FRAMES * mult, TrySplashFX),
				inst:DoTaskInTime(20 * FRAMES * mult, TrySplashFX),
				inst:DoTaskInTime(44 * FRAMES * mult, TrySplashFX, "small"),
			}
			inst.sg:SetTimeout(70 * FRAMES * mult)
		end,

		ontimeout = function(inst)
			inst.sg:AddStateTag("caninterrupt")
			inst.components.health:SetInvincible(false)
			ToggleOnCharacterCollisions(inst)
			inst.AnimState:SetDeltaTimeMultiplier(1)
		end,

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("idle")
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.spawn then
				inst.components.health:SetInvincible(false)
				ToggleOnCharacterCollisions(inst)
				inst.AnimState:SetDeltaTimeMultiplier(1)
			end
			for i, v in ipairs(inst.sg.statemem.tasks) do
				v:Cancel()
			end
		end,
	},

	State{
		name = "quickspawn",

		onenter = function(inst)
			SpawnPrefab("statue_transition_2").Transform:SetPosition(inst.Transform:GetWorldPosition())
			inst.sg:GoToState("idle")
		end,
	},

	State{
		name = "quickdespawn",

		onenter = function(inst)
			DoDespawnFX(inst)
			if inst.sg.mem.laststepsplash ~= GetTime() then
				TrySplashFX(inst)
			end
			inst:Remove()
		end,
	},

    State{
        name = "idle",
        tags = {"idle", "canrotate"},

        onenter = function(inst, pushanim)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("idle_loop", true)
        end,
    },

    State{
        name = "run_start",
        tags = {"moving", "running", "canrotate"},

        onenter = function(inst)
            inst.components.locomotor:RunForward()
            inst.AnimState:PlayAnimation("run_pre")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("run")
                end
            end),
        },

        timeline =
        {
			TimeEvent(1 * FRAMES, TryStepSplash),
			TimeEvent(3 * FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/maxwell/shadowmax_step")
            end),
        },
    },

    State{
        name = "run",
        tags = {"moving", "running", "canrotate"},

        onenter = function(inst)
            inst.components.locomotor:RunForward()
            if not inst.AnimState:IsCurrentAnimation("run_loop") then
                inst.AnimState:PlayAnimation("run_loop", true)
            end
            inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())
        end,

        timeline =
        {
			TimeEvent(5 * FRAMES, TryStepSplash),
            TimeEvent(7 * FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/maxwell/shadowmax_step")
				inst.sg.mem.laststepsplash = GetTime()
            end),
			TimeEvent(13 * FRAMES, TryStepSplash),
            TimeEvent(15 * FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/maxwell/shadowmax_step")
				inst.sg.mem.laststepsplash = GetTime()
            end),
        },

        ontimeout = function(inst)
			inst.sg.statemem.running = true
            inst.sg:GoToState("run")
        end,

		onexit = function(inst)
			if not inst.sg.statemem.running then
				TryStepSplash(inst)
			end
		end,
    },

    State{
        name = "run_stop",
        tags = {"canrotate", "idle"},

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("run_pst")
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
        name = "attack",
        tags = {"attack", "notalking", "abouttoattack", "busy"},

        onenter = function(inst)
            inst.sg.statemem.target = inst.components.combat.target
            inst.components.combat:StartAttack()
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("atk")
            inst.SoundEmitter:PlaySound("dontstarve/wilson/attack_nightsword")

            if inst.components.combat.target ~= nil and inst.components.combat.target:IsValid() then
                inst:FacePoint(inst.components.combat.target.Transform:GetWorldPosition())
            end
        end,

        timeline =
        {
            TimeEvent(8*FRAMES, function(inst) inst.components.combat:DoAttack(inst.sg.statemem.target) inst.sg:RemoveStateTag("abouttoattack") end),
            TimeEvent(12*FRAMES, function(inst) -- Keep FRAMES time synced up with ShouldKiteProtector.
                inst.sg:RemoveStateTag("busy")
            end),
            TimeEvent(13*FRAMES, function(inst)
                inst.sg:RemoveStateTag("attack")
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
        tags = {"busy"},

        onenter = function(inst)
            inst.Physics:Stop()
            FixupWorkerCarry(inst, nil)
            inst.AnimState:PlayAnimation("death")
        end,

		timeline =
		{
			TimeEvent(13 * FRAMES, TrySplashFX),
			TimeEvent(38 * FRAMES, TrySplashFX),
		},

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
					DoDespawnFX(inst)
					TrySplashFX(inst)
                    inst:Remove()
                end
            end),
        },
    },

    State{
        name = "take",
        tags = {"busy"},
        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("pickup")
            inst.AnimState:PushAnimation("pickup_pst", false)
        end,

        timeline =
        {
            TimeEvent(6 * FRAMES, function(inst)
                inst:PerformBufferedAction()
            end),
        },

        events=
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle") 
                end
            end),
        },
    },

    State{
        name = "give",
        tags = {"busy"},
        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("give")
            inst.AnimState:PushAnimation("give_pst", false)
        end,

        timeline =
        {
            TimeEvent(14 * FRAMES, function(inst)
                inst:PerformBufferedAction()
            end),
        },

        events=
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },
    },

    State{
        name = "hit",
        tags = {"busy"},

        onenter = function(inst)
            inst:ClearBufferedAction()
            inst.AnimState:PlayAnimation("hit")
            inst.Physics:Stop()
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },

        timeline =
        {
            TimeEvent(3*FRAMES, function(inst)
                inst.sg:RemoveStateTag("busy")
            end),
        },
    },

    State{
        name = "stunned",
        tags = {"busy", "canrotate"},

        onenter = function(inst)
            inst:ClearBufferedAction()
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("idle_sanity_pre")
            inst.AnimState:PushAnimation("idle_sanity_loop", true)
            inst.sg:SetTimeout(5)
        end,

        ontimeout = function(inst)
            inst.sg:GoToState("idle")
        end,
    },

    State{
        name = "chop_start",
        tags = {"prechop", "working"},

        onenter = function(inst)
            local buffaction = inst:GetBufferedAction()
            inst.sg.statemem.target = buffaction ~= nil and buffaction.target or nil

            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("chop_pre")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("chop")
                end
            end),
        },
    },

    State{
        name = "chop",
        tags = {"prechop", "chopping", "working"},

        onenter = function(inst)
            local buffaction = inst:GetBufferedAction()
            inst.sg.statemem.target = buffaction ~= nil and buffaction.target or nil

            inst.AnimState:PlayAnimation("chop_loop")
        end,

        timeline =
        {
            TimeEvent(2 * FRAMES, function(inst)
                inst:PerformBufferedAction()
            end),

            --NOTE: This is one frame off from SGwilson's since it was
            --      too slow when coupled with our brain update period
            TimeEvent(13 * FRAMES, function(inst)
                inst.sg:RemoveStateTag("prechop")
            end),

            TimeEvent(16*FRAMES, function(inst)
                inst.sg:RemoveStateTag("chopping")
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
        name = "mine_start",
        tags = {"premine", "working"},

        onenter = function(inst)
            local buffaction = inst:GetBufferedAction()
            inst.sg.statemem.target = buffaction ~= nil and buffaction.target or nil

            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("pickaxe_pre")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("mine")
                end
            end),
        },
    },

    State{
        name = "mine",
        tags = {"premine", "mining", "working"},

        onenter = function(inst)
            local buffaction = inst:GetBufferedAction()
            inst.sg.statemem.target = buffaction ~= nil and buffaction.target or nil

            inst.AnimState:PlayAnimation("pickaxe_loop")
        end,

        timeline =
        {
            TimeEvent(7 * FRAMES, function(inst)
                local buffaction = inst:GetBufferedAction()
                if buffaction ~= nil then
                    PlayMiningFX(inst, buffaction.target)
                    inst:PerformBufferedAction()
                end
            end),

            TimeEvent(14 * FRAMES, function(inst)
                inst.sg:RemoveStateTag("premine")
            end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.AnimState:PlayAnimation("pickaxe_pst")
                    inst.sg:GoToState("idle", true)
                end
            end),
        },
    },

    State{
        name = "dig_start",
        tags = {"predig", "working"},

        onenter = function(inst)
            local buffaction = inst:GetBufferedAction()
            inst.sg.statemem.target = buffaction ~= nil and buffaction.target or nil

            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("shovel_pre")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("dig")
                end
            end),
        },
    },

    State{
        name = "dig",
        tags = {"predig", "digging", "working"},

        onenter = function(inst)
            local buffaction = inst:GetBufferedAction()
            inst.sg.statemem.target = buffaction ~= nil and buffaction.target or nil

            inst.AnimState:PlayAnimation("shovel_loop")
        end,

        timeline =
        {
            TimeEvent(15 * FRAMES, function(inst)
                inst:PerformBufferedAction()
                inst.SoundEmitter:PlaySound("dontstarve/wilson/dig")
            end),

            TimeEvent(35 * FRAMES, function(inst)
                inst.sg:RemoveStateTag("predig")
            end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.AnimState:PlayAnimation("shovel_pst")
                    inst.sg:GoToState("idle", true)
                end
            end),
        },
    },

    State{
        name = "dance",
        tags = {"idle", "dancing"},

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst:ClearBufferedAction()
            local ignoreplay = inst.AnimState:IsCurrentAnimation("run_pst")
            if inst._brain_dancedata and #inst._brain_dancedata > 0 then
                for _, data in ipairs(inst._brain_dancedata) do
                    if data.play and not ignoreplay then
                        inst.AnimState:PlayAnimation(data.anim, data.loop)
                    else
                        inst.AnimState:PushAnimation(data.anim, data.loop)
                    end
                end
            else
                -- NOTES(JBK): No dance data do default dance.
                if ignoreplay then
                    inst.AnimState:PushAnimation("emoteXL_pre_dance0")
                else
                    inst.AnimState:PlayAnimation("emoteXL_pre_dance0")
                end
                inst.AnimState:PushAnimation("emoteXL_loop_dance0", true)
            end
            inst._brain_dancedata = nil -- Remove reference no matter what so garbage collector can pick up the memory.
        end,
    },

    State{
        name = "jumpout",
        tags = { "busy", "canrotate", "jumping" },

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("jumpout")
            inst.Physics:SetMotorVel(4, 0, 0)
            inst.Physics:ClearCollisionMask()
            inst.Physics:CollidesWith(COLLISION.GROUND)
        end,

        timeline =
        {
            TimeEvent(10 * FRAMES, function(inst)
                inst.Physics:SetMotorVel(3, 0, 0)
            end),
            TimeEvent(15 * FRAMES, function(inst)
                inst.Physics:SetMotorVel(2, 0, 0)
            end),
            TimeEvent(15.2 * FRAMES, function(inst)
                inst.sg.statemem.physicson = true
                inst.Physics:ClearCollisionMask()
                inst.Physics:CollidesWith(COLLISION.WORLD)
                inst.Physics:CollidesWith(COLLISION.CHARACTERS)
                inst.Physics:CollidesWith(COLLISION.GIANTS)
            end),
            TimeEvent(17 * FRAMES, function(inst)
                inst.Physics:SetMotorVel(1, 0, 0)
            end),
            TimeEvent(18 * FRAMES, function(inst)
                inst.Physics:Stop()
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
            if not inst.sg.statemem.physicson then
                inst.Physics:ClearCollisionMask()
                inst.Physics:CollidesWith(COLLISION.WORLD)
                inst.Physics:CollidesWith(COLLISION.CHARACTERS)
                inst.Physics:CollidesWith(COLLISION.GIANTS)
            end
        end,
    },
}

return StateGraph("shadowmaxwell", states, events, "spawn", actionhandlers)
