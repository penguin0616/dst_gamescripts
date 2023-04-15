local assets =
{
	Asset("ANIM", "anim/brilliance_projectile_fx.zip"),
}

local SPEED = 15
local BOUNCE_RANGE = 12
local BOUNCE_SPEED = 10
local MAX_BOUNCES = 7

local function PlayAnimAndRemove(inst, anim)
	inst.AnimState:PlayAnimation(anim)
	if not inst.removing then
		inst.removing = true
		inst:ListenForEvent("animover", inst.Remove)
	end
end

local function PushColour(inst, r, g, b)
	if inst.target:IsValid() then
		if inst.target.components.colouradder ~= nil then
			inst.target.components.colouradder:PushColour(inst, r, g, b, 0)
		else
			inst.target.AnimState:SetAddColour(r, g, b, 0)
		end
	end
end

local function PopColour(inst)
	inst.OnRemoveEntity = nil
	if inst.target:IsValid() then
		if inst.target.components.colouradder ~= nil then
			inst.target.components.colouradder:PopColour(inst)
		else
			inst.target.AnimState:SetAddColour(0, 0, 0, 0)
		end
	end
end

local function OnThrown(inst, owner, target, attacker)
	inst.owner = owner
end

local function OnPreHit(inst, attacker, target)
	--recenttargets means is bounced; inst.owner is the weapon
	if inst.recenttargets ~= nil and inst.owner ~= nil and inst.owner.components.finiteuses ~= nil then
		inst.owner.components.finiteuses:SetIgnoreCombatDurabilityLoss(true)
	end
end

local function TryBounce(inst, x, z, attacker, target)
	if not (attacker ~= nil and attacker.components.combat ~= nil and attacker:IsValid()) then
		return
	end
	local newtarget, newrecentindex, newhostile
	for i, v in ipairs(TheSim:FindEntities(x, 0, z, BOUNCE_RANGE, { "_combat" }, { "INLIMBO", "wall", "notarget", "player", "companion", "flight" })) do
		if v ~= target and v.entity:IsVisible() and
			not (v.components.health ~= nil and v.components.health:IsDead()) and
			attacker.components.combat:CanTarget(v) and not attacker.components.combat:IsAlly(v)
			then
			local vhostile = v:HasTag("hostile")
			local vrecentindex
			if inst.recenttargets ~= nil then
				for i1, v1 in ipairs(inst.recenttargets) do
					if v == v1 then
						vrecentindex = i1
						break
					end
				end
			end
			if newtarget == nil then
				newtarget = v
				newrecentindex = vrecentindex
				newhostile = vhostile
			elseif vhostile and not newhostile then
				newtarget = v
				newrecentindex = vrecentindex
				newhostile = vhostile
			elseif vhostile or not newhostile then
				if vrecentindex == nil then
					if newrecentindex ~= nil or (newtarget.prefab ~= target.prefab and v.prefab == target.prefab) then
						newtarget = v
						newrecentindex = vrecentindex
						newhostile = vhostile
					end
				elseif newrecentindex ~= nil and vrecentindex < newrecentindex then
					newtarget = v
					newrecentindex = vrecentindex
					newhostile = vhostile
				end
			end
		end
	end

	if newtarget ~= nil then
		local newinst = SpawnPrefab("brilliance_projectile_fx")
		newinst.Transform:SetPosition(x, 0, z)
		newinst.components.projectile:SetSpeed(BOUNCE_SPEED)
		if inst.recenttargets ~= nil then
			if newrecentindex ~= nil then
				table.remove(inst.recenttargets, newrecentindex)
			end
			table.insert(inst.recenttargets, target)
			newinst.recenttargets = inst.recenttargets
		else
			newinst.recenttargets = { target }
		end
		newinst.bounce = inst.bounce
		newinst.components.projectile.overridestartpos = Vector3(x, 0, z)
		newinst.components.projectile:Throw(inst.owner, newtarget, attacker)
	end
end

local function OnHit(inst, attacker, target)
	--Restore flag from PreHit
	if inst.recenttargets ~= nil and inst.owner ~= nil and inst.owner.components.finiteuses ~= nil then
		inst.owner.components.finiteuses:SetIgnoreCombatDurabilityLoss(false)
	end

	inst:RemoveComponent("projectile")
	local x, y, z = inst.Transform:GetWorldPosition()
	if target:IsValid() then
		local radius = target:GetPhysicsRadius(0) + .2
		local x1, y1, z1 = target.Transform:GetWorldPosition()
		if x ~= x1 or z ~= z1 then
			local dx = x - x1
			local dz = z - z1
			local k = radius / math.sqrt(dx * dx + dz * dz)
			x1 = x1 + dx * k
			z1 = z1 + dz * k
		end
		x = x1 + GetRandomMinMax(-.2, .2)
		y = GetRandomMinMax(.1, .3)
		z = z1 + GetRandomMinMax(-.2, .2)
		inst.Physics:Teleport(x, y, z)
		inst.target = target
		PushColour(inst, .1, .1, .1)
		inst:DoTaskInTime(4 * FRAMES, PushColour, .075, .075, .075)
		inst:DoTaskInTime(7 * FRAMES, PushColour, .05, .05, .05)
		inst:DoTaskInTime(9 * FRAMES, PushColour, .025, .025, .025)
		inst:DoTaskInTime(10 * FRAMES, PopColour)
		inst.OnRemoveEntity = PopColour
	end
	inst.Physics:SetActive(false)
	PlayAnimAndRemove(inst, "blast"..tostring(math.random(2)))

	inst.bounce = (inst.bounce or 0) + 1
	if inst.bounce < MAX_BOUNCES then
		inst:DoTaskInTime(.1, TryBounce, x, z, attacker, target)
	end
end

local function OnMiss(inst, attacker, target)
	if not inst.AnimState:IsCurrentAnimation("disappear") then
		PlayAnimAndRemove(inst, "disappear")
	end
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddPhysics()
	inst.entity:AddNetwork()

	MakeInventoryPhysics(inst)
	RemovePhysicsColliders(inst)

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")

	inst.AnimState:SetBank("brilliance_projectile_fx")
	inst.AnimState:SetBuild("brilliance_projectile_fx")
	inst.AnimState:PlayAnimation("idle_loop", true)
	inst.AnimState:SetSymbolMultColour("light_bar", 1, 1, 1, .5)
	inst.AnimState:SetSymbolBloom("light_bar")
	inst.AnimState:SetSymbolBloom("lightbeam2")
	inst.AnimState:SetSymbolBloom("moon_glow")
	inst.AnimState:SetSymbolBloom("lunar_ring")
	inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
	inst.AnimState:SetLightOverride(.5)

	--projectile (from projectile component) added to pristine state for optimization
	inst:AddTag("projectile")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst:AddComponent("projectile")
	inst.components.projectile:SetSpeed(SPEED)
	inst.components.projectile:SetRange(25)
	inst.components.projectile:SetOnThrownFn(OnThrown)
	inst.components.projectile:SetOnPreHitFn(OnPreHit)
	inst.components.projectile:SetOnHitFn(OnHit)
	inst.components.projectile:SetOnMissFn(OnMiss)

	inst.persists = false

	return inst
end

return Prefab("brilliance_projectile_fx", fn, assets)
