local assets =
{
    Asset("ANIM", "anim/wilsonstatue.zip"),
}

local function OnHealthDelta(inst, data)
    if data.amount <= 0 then
        inst.Label:SetText(data.amount)
        inst.Label:SetUIOffset(math.random() * 20 - 10, math.random() * 20 - 10, 0)
        inst.AnimState:PlayAnimation("hit")
        inst.AnimState:PushAnimation("idle")
    end
end

local function MakeLunar(inst, planar)
	if planar then
		inst:AddComponent("planardefense")
	else
		inst:RemoveComponent("planardefense")
	end
	inst:RemoveTag("shadow_aligned")
	inst:AddTag("lunar_aligned")
	inst.AnimState:SetBrightness(3)
end

local function MakeShadow(inst, planar)
	if planar then
		inst:AddComponent("planardefense")
	else
		inst:RemoveComponent("planardefense")
	end
	inst:RemoveTag("lunar_aligned")
	inst:AddTag("shadow_aligned")
	inst.AnimState:SetBrightness(.3)
end

local function MakeNormal(inst)
	inst:RemoveComponent("planardefense")
	inst:RemoveTag("lunar_aligned")
	inst:RemoveTag("shadow_aligned")
	inst.AnimState:SetBrightness(1)
end

local function OnSave(inst, data)
	data.planar = inst.components.planardefense ~= nil or nil
	data.lunar = inst:HasTag("lunar_aligned") or nil
	data.shadow = inst:HasTag("shadow_aligned") or nil
end

local function OnLoad(inst, data)
	if data ~= nil then
		if data.lunar then
			inst:MakeLunar(data.planar)
		elseif data.shadow then
			inst:MakeShadow(data.planar)
		end
	end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()
    inst.entity:AddLabel()

    inst.Label:SetFontSize(50)
    inst.Label:SetFont(DEFAULTFONT)
    inst.Label:SetWorldOffset(0, 3, 0)
    inst.Label:SetUIOffset(0, 0, 0)
    inst.Label:SetColour(1, 1, 1)
    inst.Label:Enable(true)

    MakeObstaclePhysics(inst, .3)

    inst.AnimState:SetBank("wilsonstatue")
    inst.AnimState:SetBuild("wilsonstatue")
    inst.AnimState:PlayAnimation("idle")

	inst:AddTag("monster")

    MakeSnowCoveredPristine(inst)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("bloomer")
    inst:AddComponent("colouradder")

    inst:AddComponent("inspectable")

    inst:AddComponent("combat")
    inst:AddComponent("debuffable")
    inst.components.debuffable:SetFollowSymbol("ww_head", 0, -250, 0)

    inst:AddComponent("health")
    inst.components.health:SetMaxHealth(1000)
    inst.components.health:StartRegen(1000, .1)
    inst:ListenForEvent("healthdelta", OnHealthDelta)

	if TheNet:GetServerGameMode() == "lavaarena" then
		TheWorld:PushEvent("ms_register_for_damage_tracking", { inst = inst })
	end

	inst.MakeLunar = MakeLunar
	inst.MakeShadow = MakeShadow
	inst.MakeNormal = MakeNormal
	inst.OnSave = OnSave
	inst.OnLoad = OnLoad

    return inst
end

return Prefab("dummytarget", fn, assets)
