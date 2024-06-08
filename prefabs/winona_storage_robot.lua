require("prefabutil")

local assets =
{
	Asset("ANIM", "anim/winona_storage_robot.zip"),
	Asset("ANIM", "anim/winona_storage_robot_placement.zip"),
	Asset("SCRIPT", "scripts/prefabs/storage_robot_common.lua"),
}

local prefabs =
{
	"winona_battery_sparks",
}

local brain = require("brains/storage_robotbrain")
local StorageRobotCommon = require("prefabs/storage_robot_common")

local PHYSICS_RADIUS = 0.5

local LED_BLINK_DELAY = 1.5
local LED_BLINK_TIME = 0.75

local function SetLedEnabled(inst, enabled)
	if enabled then
		inst.AnimState:Show("BALL_OVERLAY")
		inst.AnimState:SetSymbolLightOverride("antenna_base", 0.24)
		inst.AnimState:SetSymbolLightOverride("Bolt", 0.16)
		inst.AnimState:SetSymbolLightOverride("topbody", 0.09)
		inst.AnimState:SetSymbolLightOverride("bodycircle", 0.06)
		inst.AnimState:SetSymbolLightOverride("base", 0.05)
	else
		inst.AnimState:Hide("BALL_OVERLAY")
		inst.AnimState:SetSymbolLightOverride("antenna_base", 0)
		inst.AnimState:SetSymbolLightOverride("Bolt", 0)
		inst.AnimState:SetSymbolLightOverride("topbody", 0)
		inst.AnimState:SetSymbolLightOverride("bodycircle", 0)
		inst.AnimState:SetSymbolLightOverride("base", 0)
	end
end

local function CancelLedBlink(inst)
	if inst._ledblinktask then
		inst._ledblinktask:Cancel()
		inst._ledblinktask = nil
		inst._ledblinkon = nil
	else
		inst._ledblinktasktime = nil
	end
	inst.OnEntitySleep = nil
	inst.OnEntityWake = nil
end

local function SetLedStatusOn(inst)
	CancelLedBlink(inst)
	SetLedEnabled(inst, true)
end

local function SetLedStatusOff(inst)
	CancelLedBlink(inst)
	SetLedEnabled(inst, false)
end

local function OnLedBlink(inst)
	inst._ledblinkon = not inst._ledblinkon
	inst._ledblinktask = inst:DoTaskInTime(inst._ledblinkon and LED_BLINK_TIME or LED_BLINK_DELAY, OnLedBlink)
	SetLedEnabled(inst, inst._ledblinkon)
end

local function OnEntitySleep(inst)
	if inst._ledblinktask then
		inst._ledblinktasktime = GetTaskRemaining(inst._ledblinktask)
		inst._ledblinktask:Cancel()
		inst._ledblinktask = nil
	end
end

local function OnEntityWake(inst)
	if inst._ledblinktasktime then
		inst._ledblinktask = inst:DoTaskInTime(inst._ledblinktasktime, OnLedBlink)
		inst._ledblinktasktime = nil
	end
end

local function SetLedStatusBlink(inst, initialon)
	if not (inst._ledblinktask or inst._ledblinktasktime) then
		inst.OnEntitySleep = OnEntitySleep
		inst.OnEntityWake = OnEntityWake
		SetLedEnabled(inst, initialon)
		inst._ledblinkon = initialon
		local delay = initialon and LED_BLINK_TIME or LED_BLINK_DELAY
		if inst:IsAsleep() then
			inst._ledblinktasktime = delay
		else
			inst._ledblinktask = inst:DoTaskInTime(delay, OnLedBlink)
		end
	end
end

local function RefreshLedStatus(inst)
	if inst.components.inventoryitem:IsHeld() then
		SetLedStatusOff(inst)
	elseif inst.sg or inst._powertask then
		SetLedStatusOn(inst)
	elseif not inst.components.fueled:IsEmpty() then
		SetLedStatusBlink(inst, false)
	else
		SetLedStatusOff(inst)
	end
end

local function OnUpdateChargingFuel(inst)
	if inst.components.fueled:IsFull() then
		inst.components.fueled:StopConsuming()
	end
end

local function SetCharging(inst, powered, duration)
	if not powered then
		if inst._powertask then
			inst._powertask:Cancel()
			inst._powertask = nil
			inst.components.fueled:StopConsuming()
			inst.components.fueled.rate = 1
			inst.components.fueled:SetUpdateFn(nil)
			inst.components.powerload:SetLoad(0)
			RefreshLedStatus(inst)
		end
	else
		local waspowered = inst._powertask ~= nil
		local remaining = waspowered and GetTaskRemaining(inst._powertask) or 0
		if duration > remaining then
			if inst._powertask then
				inst._powertask:Cancel()
			end
			inst._powertask = inst:DoTaskInTime(duration, SetCharging, false)
			if not waspowered then
				inst.components.fueled.rate = TUNING.WINONA_STORAGE_ROBOT_RECHARGE_RATE * (inst._quickcharge and TUNING.SKILLS.WINONA.QUICKCHARGE_MULT or 1)
				inst.components.fueled:SetUpdateFn(OnUpdateChargingFuel)
				inst.components.fueled:StartConsuming()
				inst.components.powerload:SetLoad(TUNING.WINONA_STORAGE_ROBOT_POWER_LOAD_CHARGING)
				RefreshLedStatus(inst)
			end
		end
	end
end

local function OnTeleported(inst)
	StorageRobotCommon.UpdateSpawnPoint(inst)
end

local function OnDeactivateRobot(inst)
	if inst.sg then
		inst:SetBrain(nil)
		inst:ClearStateGraph()
		inst:ClearBufferedAction()
		inst:RemoveEventCallback("teleported", OnTeleported)
		inst:RemoveComponent("locomotor")
		inst.components.inventory:CloseAllChestContainers()
		inst.components.fueled:StopConsuming()
		inst.Transform:SetNoFaced()
		inst.AnimState:PlayAnimation("idle_off")
		ChangeToInventoryItemPhysics(inst, 1, PHYSICS_RADIUS)
		StorageRobotCommon.ClearSpawnPoint(inst)
		inst._isactive:set(false)
		if not inst.components.inventoryitem:IsHeld() then
			inst.components.circuitnode:ConnectTo("engineeringbattery")
		end
	end
end

local function OnDeploy(inst, pt)--, deployer)
	ChangeToCharacterPhysics(inst, 50, PHYSICS_RADIUS)
	if pt then --loading doesn't pass pt
		inst.Physics:Teleport(pt.x, 0, pt.z)
	end

	inst:AddComponent("locomotor")
	inst.components.locomotor:SetTriggersCreep(false)
	inst.components.locomotor.pathcaps = { ignorecreep = true }
	inst.components.locomotor.runspeed = TUNING.WINONA_STORAGE_ROBOT_RUNSPEED

	inst.Transform:SetFourFaced()
	inst:SetStateGraph("SGwinona_storage_robot")
	inst:SetBrain(brain)
	SetCharging(inst, false)
	RefreshLedStatus(inst)
	inst.components.fueled:StartConsuming()
	if pt then
		StorageRobotCommon.UpdateSpawnPoint(inst)
	end
	if not inst:IsAsleep() then
		inst:RestartBrain()
	end
	inst:ListenForEvent("teleported", OnTeleported)

	inst._isactive:set(true)
end

local function OnPutInInventory(inst, owner)
	if inst._inittask then
		inst._inittask:Cancel()
		inst._inittask = nil
	end
	inst._owner = owner
	inst._quickcharge = false
	OnDeactivateRobot(inst)
	inst.components.circuitnode:Disconnect()
	RefreshLedStatus(inst)
end

local function OnDropped(inst)
	if inst._owner then
		if inst._owner.components.skilltreeupdater and
			inst._owner.components.skilltreeupdater:IsActivated("winona_gadget_recharge") and
			not (inst._owner.components.health and inst._owner.components.health:IsDead() or inst._owner:HasTag("playerghost"))
		then
			inst._quickcharge = true
		end
		inst._owner = nil
	end

	if inst.components.inventoryitem.is_landed then
		inst.components.circuitnode:ConnectTo("engineeringbattery")
	else
		inst.components.circuitnode:Disconnect()
	end
	RefreshLedStatus(inst)
end

local function OnNoLongerLanded(inst)
	inst.components.circuitnode:Disconnect()
end

local function OnLanded(inst)
	if not (inst.sg or inst.components.circuitnode:IsEnabled() or inst.components.inventoryitem:IsHeld()) then
		inst.components.circuitnode:ConnectTo("engineeringbattery")
	end
end

local function OnSectionChanged(newsection, oldsection, inst)--, doer)
	if oldsection == 0 then
		inst:AddComponent("deployable")
		inst.components.deployable.restrictedtag = "handyperson"
		inst.components.deployable.ondeploy = OnDeploy
		inst.components.deployable:SetDeploySpacing(DEPLOYSPACING.DEFAULT)
		RefreshLedStatus(inst)
	elseif newsection == 0 then
		inst:RemoveComponent("deployable")
		RefreshLedStatus(inst)
	end
end

local function OnSave(inst, data)
	data.power = inst._powertask and math.ceil(GetTaskRemaining(inst._powertask) * 1000) or nil

	--skilltree
	data.quickcharge = inst._quickcharge or nil
end

local function OnLoad(inst, data)--, newents)
	if inst._inittask then
		inst._inittask:Cancel()
		inst._inittask = nil
	end

	--skilltree
	inst._quickcharge = data and data.quickcharge or false

	if not inst.components.fueled:IsEmpty() and StorageRobotCommon.UpdateSpawnPointOnLoad(inst) then
		OnDeploy(inst) --don't pass pt
	else
		StorageRobotCommon.ClearSpawnPoint(inst)
		if data and data.power then
			inst:AddBatteryPower(math.max(2 * FRAMES, data.power / 1000))
		else
			SetCharging(inst, false)
		end
		--Enable connections, but leave the initial connection to batteries' OnPostLoad
		inst.components.circuitnode:ConnectTo(nil)
	end
end

local function OnInit(inst)
	inst._inittask = nil
	inst.components.circuitnode:ConnectTo("engineeringbattery")
end

--------------------------------------------------------------------------

local PLACER_SCALE = 1.5

local function OnUpdatePlacerHelper(helperinst)
	if not helperinst.placerinst:IsValid() then
		helperinst.components.updatelooper:RemoveOnUpdateFn(OnUpdatePlacerHelper)
		helperinst.AnimState:SetAddColour(0, 0, 0, 0)
	else
		local range = TUNING.WINONA_BATTERY_RANGE - TUNING.WINONA_STORAGE_ROBOT_FOOTPRINT
		local hx, hy, hz = helperinst.Transform:GetWorldPosition()
		local px, py, pz = helperinst.placerinst.Transform:GetWorldPosition()
		--<= match circuitnode FindEntities range tests
		if distsq(hx, hz, px, pz) <= range * range and TheWorld.Map:GetPlatformAtPoint(hx, hz) == TheWorld.Map:GetPlatformAtPoint(px, pz) then
			helperinst.AnimState:SetAddColour(helperinst.placerinst.AnimState:GetAddColour())
		else
			helperinst.AnimState:SetAddColour(0, 0, 0, 0)
		end
	end
end

local function CreatePlacerBatteryRing()
	local inst = CreateEntity()

	--[[Non-networked entity]]
	inst.entity:SetCanSleep(false)
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst:AddTag("CLASSIFIED")
	inst:AddTag("NOCLICK")
	inst:AddTag("placer")

	inst.AnimState:SetBank("winona_storage_robot_placement")
	inst.AnimState:SetBuild("winona_storage_robot_placement")
	inst.AnimState:PlayAnimation("idle")
	inst.AnimState:Hide("outer")
	inst.AnimState:SetLightOverride(1)
	inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
	inst.AnimState:SetLayer(LAYER_BACKGROUND)
	inst.AnimState:SetSortOrder(1)
	inst.AnimState:SetScale(PLACER_SCALE, PLACER_SCALE)

	return inst
end

local function CreateWorkRangeRing()
	local inst = CreateEntity()

	--[[Non-networked entity]]
	inst.entity:SetCanSleep(false)
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst:AddTag("CLASSIFIED")
	inst:AddTag("NOCLICK")
	inst:AddTag("placer")

	inst.AnimState:SetBank("winona_storage_robot_placement")
	inst.AnimState:SetBuild("winona_storage_robot_placement")
	inst.AnimState:PlayAnimation("idle")
	inst.AnimState:Hide("inner")
	inst.AnimState:SetAddColour(0, .2, .5, 0)
	inst.AnimState:SetLightOverride(1)
	inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
	inst.AnimState:SetLayer(LAYER_BACKGROUND)
	inst.AnimState:SetSortOrder(1)
	inst.AnimState:SetScale(PLACER_SCALE, PLACER_SCALE)

	return inst
end

local function RemoveWorkRangeRing(inst)
	inst.helper:Remove()
	inst.helper = nil
end

local function OnIsActiveDirty(inst)
	if inst._isactive:value() then
		if inst.helper == nil then
			inst.helper = CreateWorkRangeRing()
			inst.helper.Transform:SetPosition(inst._originx:value(), 0, inst._originz:value())
			inst.OnRemoveEntity = RemoveWorkRangeRing
		end
	elseif inst.helper then
		inst.helper:Remove()
		inst.helper = nil
		inst.OnRemoveEntity = nil
	end
end

local function OnOriginDirty(inst)
	if inst.helper then
		inst.helper.Transform:SetPosition(inst._originx:value(), 0, inst._originz:value())
	end
end

local function OnEnableHelper(inst, enabled, recipename, placerinst)
	if enabled then
		if placerinst and placerinst.prefab == "winona_storage_robot_placer" then
			if not inst.helperlisteners then
				inst.helperlisteners = true
				inst:ListenForEvent("isactivedirty", OnIsActiveDirty)
				inst:ListenForEvent("origindirty", OnOriginDirty)
				OnIsActiveDirty(inst)
			end
		elseif inst.helper == nil
			and placerinst
			and (	placerinst.prefab == "winona_battery_low_item_placer" or
					placerinst.prefab == "winona_battery_high_item_placer" or
					recipename == "winona_battery_low" or
					recipename == "winona_battery_high"
				)
		then
			inst.helper = CreatePlacerBatteryRing()
			inst.helper.entity:SetParent(inst.entity)
			inst.helper:AddComponent("updatelooper")
			inst.helper.components.updatelooper:AddOnUpdateFn(OnUpdatePlacerHelper)
			inst.helper.placerinst = placerinst
			OnUpdatePlacerHelper(inst.helper)
		end
	else
		if inst.helperlisteners then
			inst.helperlisteners = nil
			inst:RemoveEventCallback("isactivedirty", OnIsActiveDirty)
			inst:RemoveEventCallback("origindirty", OnOriginDirty)
		end
		if inst.helper then
			inst.helper:Remove()
			inst.helper = nil
			inst.OnRemoveEntity = nil
		end
	end
end

local function OnStartHelper(inst)--, recipename, placerinst)
	if inst.AnimState:IsCurrentAnimation("poweron") and inst.AnimState:GetCurrentAnimationFrame() < 30 then
		inst.components.deployhelper:StopHelper()
	end
end

--------------------------------------------------------------------------

local function GetStatus(inst)
	return inst.sg == nil and (
				(inst._powertask and "CHARGING") or
				(inst.components.circuitnode:IsConnected() and inst.components.fueled:IsFull() and "CHARGED") or
				(inst.components.fueled:IsEmpty() and "OFF") or
				"SLEEP"
			)
		or nil
end

local function AddBatteryPower(inst, power)
	if inst.components.fueled:IsFull() then
		SetCharging(inst, false)
	else
		SetCharging(inst, true, power)
	end
end

local function OnUpdateSparks(inst)
	if inst._flash > 0 then
		local k = inst._flash * inst._flash
		inst.components.colouradder:PushColour("wiresparks", .3 * k, .3 * k, 0, 0)
		inst._flash = inst._flash - .15
	else
		inst.components.colouradder:PopColour("wiresparks")
		inst._flash = nil
		inst.components.updatelooper:RemoveOnUpdateFn(OnUpdateSparks)
	end
end

local function DoWireSparks(inst)
	inst.SoundEmitter:PlaySound("dontstarve/common/together/spot_light/electricity", nil, .5)
	SpawnPrefab("winona_battery_sparks").entity:AddFollower():FollowSymbol(inst.GUID, "wire", 0, 0, 0)
	if inst.components.updatelooper then
		if inst._flash == nil then
			inst.components.updatelooper:AddOnUpdateFn(OnUpdateSparks)
		end
		inst._flash = 1
		OnUpdateSparks(inst)
	end
end

local function NotifyCircuitChanged(inst, node)
	node:PushEvent("engineeringcircuitchanged")
end

local function OnCircuitChanged(inst)
	--Notify other connected batteries
	inst.components.circuitnode:ForEachNode(NotifyCircuitChanged)
end

local function OnConnectCircuit(inst)--, node)
	if not inst._wired then
		inst._wired = true
		inst.AnimState:ClearOverrideSymbol("wire")
		if not POPULATING then
			DoWireSparks(inst)
		end
	end
	OnCircuitChanged(inst)
end

local function OnDisconnectCircuit(inst)--, node)
	if inst.components.circuitnode:IsConnected() then
		OnCircuitChanged(inst)
	elseif inst._wired then
		inst._wired = nil
		--This will remove mouseover as well (rather than just :Hide("wire"))
		inst.AnimState:OverrideSymbol("wire", "winona_storage_robot", "dummy")
		DoWireSparks(inst)
		SetCharging(inst, false)
	end
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddDynamicShadow()
	inst.entity:AddNetwork()

	MakeInventoryPhysics(inst, 1, PHYSICS_RADIUS)

	inst:SetDeploySmartRadius(DEPLOYSPACING_RADIUS[DEPLOYSPACING.DEFAULT] / 2)

	inst.DynamicShadow:SetSize(1.5, 0.8)

	inst:AddTag("companion")
	inst:AddTag("NOBLOCK")
	inst:AddTag("scarytoprey")
	inst:AddTag("storagerobot")
	inst:AddTag("engineering")
	inst:AddTag("engineeringbatterypowered")
	inst:AddTag("usedeploystring")

	inst._originx = net_float(inst.GUID, "winona_storage_robot._originx", "origindirty")
	inst._originz = net_float(inst.GUID, "winona_storage_robot._originz", "origindirty")
	inst._isactive = net_bool(inst.GUID, "winona_storage_robot._isactive", "isactivedirty")
	inst._isactive:set(false)

	inst.AnimState:SetBank("winona_storage_robot")
	inst.AnimState:SetBuild("winona_storage_robot")
	inst.AnimState:PlayAnimation("idle_off")
	--This will remove mouseover as well (rather than just :Hide("wire"))
	inst.AnimState:OverrideSymbol("wire", "winona_storage_robot", "dummy")
	inst.AnimState:Hide("BALL_OVERLAY")
	inst.AnimState:SetSymbolLightOverride("ball_overlay", 0.5)
	inst.AnimState:SetSymbolBloom("ball_overlay")
	inst.AnimState:SetFinalOffset(1) --tends to overlap items during pickup

	--Dedicated server does not need deployhelper
	if not TheNet:IsDedicated() then
		inst:AddComponent("deployhelper")
		inst.components.deployhelper:AddRecipeFilter("winona_battery_low")
		inst.components.deployhelper:AddRecipeFilter("winona_battery_high")
		inst.components.deployhelper:AddKeyFilter("winona_battery_engineering")
		inst.components.deployhelper.onenablehelper = OnEnableHelper
		inst.components.deployhelper.onstarthelper = OnStartHelper
	end

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst.scrapbook_anim = "placer"

	inst.PICKUP_ARRIVE_DIST = 1

	inst:AddComponent("knownlocations")

	inst:AddComponent("inspectable")
	inst.components.inspectable.getstatus = GetStatus

	inst:AddComponent("updatelooper")
	inst:AddComponent("colouradder")

	inst:AddComponent("inventory")
	inst.components.inventory.maxslots = 1

	inst:AddComponent("inventoryitem")
	inst.components.inventoryitem:SetOnPutInInventoryFn(OnPutInInventory)
	inst.components.inventoryitem:SetOnDroppedFn(OnDropped)

	inst:AddComponent("circuitnode")
	inst.components.circuitnode:SetRange(TUNING.WINONA_BATTERY_RANGE - TUNING.WINONA_STORAGE_ROBOT_FOOTPRINT + TUNING.WINONA_ENGINEERING_FOOTPRINT)
	inst.components.circuitnode:SetFootprint(TUNING.WINONA_STORAGE_ROBOT_FOOTPRINT)
	inst.components.circuitnode:SetOnConnectFn(OnConnectCircuit)
	inst.components.circuitnode:SetOnDisconnectFn(OnDisconnectCircuit)
	inst.components.circuitnode.connectsacrossplatforms = false
	inst.components.circuitnode.rangeincludesfootprint = true

	inst:AddComponent("powerload")
	inst.components.powerload:SetLoad(0)

	inst:ListenForEvent("engineeringcircuitchanged", OnCircuitChanged)
	inst:ListenForEvent("on_no_longer_landed", OnNoLongerLanded)
	inst:ListenForEvent("on_landed", OnLanded)

	MakeHauntable(inst)

	inst.OnDeactivateRobot = OnDeactivateRobot
	inst.AddBatteryPower = AddBatteryPower
	inst.OnSave = OnSave
	inst.OnLoad = OnLoad
	--inst.OnEntitySleep = OnEntitySleep
	--inst.OnEntityWake = OnEntityWake

	--skilltree
	inst._quickcharge = false

	inst._wired = nil
	inst._ledblinktask = nil
	inst._ledblinktasktime = nil
	inst._ledblinkon = nil
	inst._inittask = inst:DoTaskInTime(0, OnInit)

	inst:AddComponent("fueled")
	inst.components.fueled.fueltype = FUELTYPE.MAGIC
	inst.components.fueled.rate = 1
	inst.components.fueled:SetSectionCallback(OnSectionChanged)
	inst.components.fueled:InitializeFuelLevel(TUNING.WINONA_STORAGE_ROBOT_FUEL) --last, since triggers section callback

	RefreshLedStatus(inst)

	return inst
end

--------------------------------------------------------------------------

local function CreatePlacerStorageRobot()
	local inst = CreateEntity()

	--[[Non-networked entity]]
	inst.entity:SetCanSleep(false)
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst:AddTag("CLASSIFIED")
	inst:AddTag("NOCLICK")
	inst:AddTag("placer")

	inst.Transform:SetTwoFaced()

	inst.AnimState:SetBank("winona_storage_robot")
	inst.AnimState:SetBuild("winona_storage_robot")
	inst.AnimState:PlayAnimation("placer")
	inst.AnimState:SetLightOverride(1)

	return inst
end

local function placer_postinit_fn(inst)
	--Show the storage robot placer on top of the storage robot range ground placer

	local placer2 = CreatePlacerStorageRobot()
	placer2.entity:SetParent(inst.entity)
	inst.components.placer:LinkEntity(placer2)

	inst.AnimState:SetScale(PLACER_SCALE, PLACER_SCALE)

	inst.deployhelper_key = "winona_battery_engineering"
	inst.engineering_footprint_override = TUNING.WINONA_STORAGE_ROBOT_FOOTPRINT
end

--------------------------------------------------------------------------

return Prefab("winona_storage_robot", fn, assets, prefabs),
	MakePlacer("winona_storage_robot_placer", "winona_storage_robot_placement", "winona_storage_robot_placement", "idle", true, nil, nil, nil, nil, nil, placer_postinit_fn)
