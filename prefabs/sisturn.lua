require "prefabutil"

local prefabs =
{
    "collapse_small",
}

local assets =
{
    Asset("ANIM", "anim/sisturn.zip"),
	Asset("ANIM", "anim/ui_chest_2x2.zip"),
}

local FLOWER_LAYERS =
{
	"flower1_roof",
	"flower2_roof",
	"flower1",
	"flower2",
}

-- Skill tree reactions
local function ConfigureSkillTreeUpgrades(inst, builder)
	local skilltreeupdater = (builder and builder.components.skilltreeupdater) or nil

	local petal_preserve = (skilltreeupdater and skilltreeupdater:IsActivated("wendy_sisturn_1")) or nil
	local sanityaura_size = (skilltreeupdater and skilltreeupdater:IsActivated("wendy_sisturn_2") and TUNING.SANITYAURA_MED) or nil

	local dirty = (inst._petal_preserve ~= petal_preserve) or (inst._sanityaura_size ~= sanityaura_size)

	inst._petal_preserve = petal_preserve
	inst._sanityaura_size = sanityaura_size

	return dirty
end

local function ApplySkillModifiers(inst)
	inst.components.preserver:SetPerishRateMultiplier(inst._petal_preserve)
	if inst.components.sanityaura then
		inst.components.sanityaura.aura = inst._sanityaura_size or TUNING.SANITYAURA_SMALL
	end
end

--
local function IsFullOfFlowers(inst)
	return inst.components.container ~= nil and inst.components.container:IsFull()
end

local function onhammered(inst)
    inst.components.lootdropper:DropLoot()
    if inst.components.container ~= nil then
        inst.components.container:DropEverything()
    end

    local fx = SpawnPrefab("collapse_small")
    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    fx:SetMaterial("wood")
    inst:Remove()
end

local function onhit(inst, worker, workleft)
    if workleft > 0 and not inst:HasTag("burnt") then
        inst.SoundEmitter:PlaySound("dontstarve/characters/wendy/sisturn/hit")
        inst.AnimState:PlayAnimation("hit")
        inst.AnimState:PushAnimation("idle")

		if inst.components.container ~= nil then
			inst.components.container:DropEverything()
		end
    end
end

local function on_built(inst, data)
    inst.AnimState:PlayAnimation("place")
    inst.SoundEmitter:PlaySound("dontstarve/characters/wendy/sisturn/place")
    inst.AnimState:PushAnimation("idle", false)
    inst.SoundEmitter:PlaySound("dontstarve/characters/wendy/sisturn/hit")

	if not data.builder then return end

	inst._builder_id = data.builder.userid
	if ConfigureSkillTreeUpgrades(inst, data.builder) then
		ApplySkillModifiers(inst)
	end
end

local function update_sanityaura(inst)
	if IsFullOfFlowers(inst) then
		if not inst.components.sanityaura then
			inst:AddComponent("sanityaura")
		end
		inst.components.sanityaura.aura = inst._sanityaura_size or TUNING.SANITYAURA_SMALL
	elseif inst.components.sanityaura ~= nil then
		inst:RemoveComponent("sanityaura")
	end
end

local function update_idle_anim(inst)
    if inst:HasTag("burnt") then
		return
	end

	if IsFullOfFlowers(inst) then
		inst.AnimState:PlayAnimation("on_pre")
		inst.AnimState:PushAnimation("on", true)
        inst.SoundEmitter:PlaySound("dontstarve/characters/wendy/sisturn/LP","sisturn_on")
	else
		inst.AnimState:PlayAnimation("on_pst")
		inst.AnimState:PushAnimation("idle", false)
        inst.SoundEmitter:KillSound("sisturn_on")
	end
end

local function remove_decor(inst, data)
    if data ~= nil and data.slot ~= nil and FLOWER_LAYERS[data.slot] then
		inst.AnimState:Hide(FLOWER_LAYERS[data.slot])
    end
	update_sanityaura(inst)
	update_idle_anim(inst)
	TheWorld:PushEvent("ms_updatesisturnstate", {inst = inst, is_active = IsFullOfFlowers(inst)})
end

local function add_decor(inst, data)
    if data ~= nil and data.slot ~= nil and FLOWER_LAYERS[data.slot] and not inst:HasTag("burnt") then
		inst.AnimState:Show(FLOWER_LAYERS[data.slot])
    end
	update_sanityaura(inst)
	update_idle_anim(inst)

	local is_full = IsFullOfFlowers(inst)
	TheWorld:PushEvent("ms_updatesisturnstate", {inst = inst, is_active = is_full})

	local doer = (is_full and inst.components.container ~= nil and inst.components.container.currentuser) or nil
	if doer ~= nil and doer.components.talker ~= nil and doer:HasTag("ghostlyfriend") then
		doer.components.talker:Say(GetString(doer, "ANNOUNCE_SISTURN_FULL"), nil, nil, true)
	end
end

local function getstatus(inst)
	local container = inst.components.container
	local num_decor = (container ~= nil and container:NumItems()) or 0
	local num_slots = (container ~= nil and container.numslots) or 1
	return num_decor >= num_slots and "LOTS_OF_FLOWERS"
			or num_decor > 0 and "SOME_FLOWERS"
			or nil
end

local function OnSave(inst, data)
	if inst:HasTag("burnt") or (inst.components.burnable and inst.components.burnable:IsBurning()) then
		data.burnt = true
	end

	data.preserve_rate = inst._preserve_rate
	data.sanityaura_size = inst._sanityaura_size
	data.builder_id = inst._builder_id
end

local function OnLoad(inst, data)
	if data then
		if data.burnt and inst.components.burnable then
			inst.components.burnable.onburnt(inst)
		else
			inst._builder_id = data.builder_id
			inst._preserve_rate = data.preserve_rate
			inst._sanityaura_size = data.sanityaura_size

			ApplySkillModifiers(inst)
		end
	end
end

local function updatefn(inst, comp, dt)	

	if not inst.update_timer then
		inst.update_timer = 1
	end
	inst.update_timer = inst.update_timer -dt
	if inst.update_timer <= 0 then
		inst.update_timer = inst.update_timer + 1

		for ghost,i in pairs(comp.babysitting)do
			if not inst.components.container:IsFull() then
				inst.components.ghostbabysitter:RemoveGhost(ghost)
			elseif ghost.components.health:GetPercent() >= 1 and ghost:GetDistanceSqToInst(inst) < 25*25 then
				if ghost.AddBonusHealth then
					ghost:AddBonusHealth(1)
				end
			end
		end
	end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
	inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

	inst:SetDeploySmartRadius(1) --recipe min_spacing/2
    MakeObstaclePhysics(inst, .5)

    inst:AddTag("structure")

    inst.AnimState:SetBank("sisturn")
    inst.AnimState:SetBuild("sisturn")
    inst.AnimState:PlayAnimation("idle")
	for _, layer_name in ipairs(FLOWER_LAYERS) do
		inst.AnimState:Hide(layer_name)
	end

	inst.MiniMapEntity:SetIcon("sisturn.png")

    MakeSnowCoveredPristine(inst)

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

	--
    inst:AddComponent("container")
    inst.components.container:WidgetSetup("sisturn")

	--
    inst:AddComponent("inspectable")
	inst.components.inspectable.getstatus = getstatus

	--
    inst:AddComponent("lootdropper")

    --

    inst:AddComponent("ghostbabysitter")
    inst.components.ghostbabysitter.updatefn = updatefn

	--
	inst:AddComponent("preserver")

	--
    local workable = inst:AddComponent("workable")
    workable:SetWorkAction(ACTIONS.HAMMER)
    workable:SetWorkLeft(4)
    workable:SetOnFinishCallback(onhammered)
    workable:SetOnWorkCallback(onhit)

	--
    MakeSmallBurnable(inst, nil, nil, true)
    MakeSmallPropagator(inst)

	--
    MakeHauntableWork(inst)
    MakeSnowCovered(inst)

	--
    inst:ListenForEvent("itemget", add_decor)
    inst:ListenForEvent("itemlose", remove_decor)
    inst:ListenForEvent("onbuilt", on_built)

	--
	if not TheWorld.components.sisturnregistry then
		TheWorld:AddComponent("sisturnregistry")
	end
	TheWorld.components.sisturnregistry:Register(inst)

	--
	inst:ListenForEvent("wendy_sisturnskillchanged", function(_, user)
		if user.userid == inst._builder_id and not inst:HasTag("burnt")
				and ConfigureSkillTreeUpgrades(inst, user) then
			ApplySkillModifiers(inst)
		end
	end, TheWorld)

	--
	inst.OnSave = OnSave
	inst.OnLoad = OnLoad

	--
    return inst
end

return Prefab("sisturn", fn, assets, prefabs),
       MakePlacer("sisturn_placer", "sisturn", "sisturn", "placer")
