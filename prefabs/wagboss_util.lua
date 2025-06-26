local SpDamageUtil = require("components/spdamageutil")

--------------------------------------------------------------------------

local FISSURES

local function TileCoordsToId(tx, ty)
	return string.format("%d.%d", tx, ty)
end

local function IdToTileCoords(id)
	local sep = string.find(id, "%.")
	return tonumber(string.sub(id, 1, sep - 1)), tonumber(string.sub(id, sep + 1))
end

local function OnRemoveFissure(fissure)
	assert(FISSURES[fissure._wagpunkarena_fissure_id] == fissure)
	FISSURES[fissure._wagpunkarena_fissure_id] = nil
	if fissure.size > 1 then
		local tx, ty = IdToTileCoords(fissure._wagpunkarena_fissure_id)
		for tx1 = tx, tx + fissure.size - 1 do
			for ty1 = ty, ty + fissure.size - 1 do
				if tx ~= tx1 or ty ~= ty1 then
					local id1 = TileCoordsToId(tx1, ty1)
					assert(FISSURES[id1] == fissure)
					FISSURES[id1] = nil
				end
			end
		end
	end
	if next(FISSURES) == nil then
		FISSURES = nil
		--print("All alterguardian_lunar_fissures cleared.")
	end
end

local function SpawnFissureAtXZ(x, z, size, id, tx, ty)
	local fissure = SpawnPrefab("alterguardian_lunar_fissures")
	fissure:SetGridSize(size)
	fissure.Transform:SetPosition(x, 0, z)
	fissure._wagpunkarena_fissure_id = id
	if FISSURES then
		assert(FISSURES[id] == nil)
		FISSURES[id] = fissure
	else
		FISSURES = { [id] = fissure }
	end
	if size > 1 then
		for tx1 = tx, tx + size - 1 do
			for ty1 = ty, ty + size - 1 do
				if tx ~= tx1 or ty ~= ty1 then
					local id1 = TileCoordsToId(tx1, ty1)
					assert(FISSURES[id1] == nil)
					FISSURES[id1] = fissure
				end
			end
		end
	end
	fissure:ListenForEvent("onremove", OnRemoveFissure)
	return fissure
end

local function DespawnFissure(fissure, anim)
	fissure.persists = false
	if not fissure:IsAsleep() then
		if fissure._wagpunkarena_fissure_id then
			fissure:RemoveEventCallback("onremove", OnRemoveFissure)
			OnRemoveFissure(fissure)
		end
		fissure.AnimState:PlayAnimation(anim.."_pst")
		fissure:ListenForEvent("animover", fissure.Remove)
	elseif POPULATING then
		fissure:DoStaticTaskInTime(0, fissure.Remove)
	else
		fissure:Remove()
	end
end

local TILE_SIZE = 4

local function OnLoadFissure(fissure)
	local x, _, z = fissure.Transform:GetWorldPosition()
	local size = fissure.size
	local offs = TILE_SIZE * (size - 1) / 2
	local tx, ty = TheWorld.Map:GetTileCoordsAtPoint(x - offs, 0, z - offs)

	if FISSURES == nil then
		FISSURES = {}
	end

	for tx1 = tx, tx + size - 1 do
		for ty1 = ty, ty + size - 1 do
			local id1 = TileCoordsToId(tx1, ty1)
			if FISSURES[id1] then
				if BRANCH == "dev" then
					assert(false, "[WagBossUtil] Failed to register "..tostring(fissure))
				else
					print("[WagBossUtil] Failed to register "..tostring(fissure))
				end
				--undo what we've registered up till now
				for tx2 = tx, tx1 do
					for ty2 = ty, tx2 < tx1 and ty + size - 1 or ty1 - 1 do
						local id2 = TileCoordsToId(tx2, ty2)
						FISSURES[id2] = nil
					end
				end
				return false
			end
			FISSURES[id1] = fissure
			if fissure._wagpunkarena_fissure_id == nil then
				fissure._wagpunkarena_fissure_id = id1
			end
		end
	end

	fissure:ListenForEvent("onremove", OnRemoveFissure)
	return true
end

local function HasFissure(id)
	return (FISSURES and FISSURES[id]) ~= nil
end

--------------------------------------------------------------------------

--currently player_classified.lunarburnflags is net_tinybyte => 3 bits
local LunarBurnFlags =
{
	GENERIC =			0x1,
	NEAR_SUPERNOVA =	0x2,
	SUPERNOVA =			0x4,

	ALL =				0x7,
}

--bit not available outside of sim
--local _lunarburn_dmg_mask = bit.bor(LunarBurnFlags.GENERIC, LunarBurnFlags.SUPERNOVA)
local _lunarburn_dmg_mask = LunarBurnFlags.GENERIC + LunarBurnFlags.SUPERNOVA
local _lunarburn_near_mask = LunarBurnFlags.NEAR_SUPERNOVA

local function HasLunarBurnDamage(flags)
	return bit.band(flags, _lunarburn_dmg_mask) ~= 0
end

local function _acc_def_mult(ent, def, mult)
	def = def + SpDamageUtil.GetSpDefenseForType(ent, "planar")
	if ent.components.damagetyperesist then
		mult = mult * ent.components.damagetyperesist:GetResistForTag("lunar_aligned")
	end
	return def, mult
end

local function CalcLunarBurnTickDamage(target, dps)
	local def, mult = _acc_def_mult(target, 0, 1)
	if target.components.inventory then
		for eslot, equip in pairs(target.components.inventory.equipslots) do
			def, mult = _acc_def_mult(equip, def, mult)
		end
	end
	if target.components.rideable then
		local saddle = target.components.rideable.saddle
		if saddle then
			def, mult = _acc_def_mult(saddle, def, mult)
		end
	end
	return math.max(0, (dps * mult - def / 4) * FRAMES)
end

--------------------------------------------------------------------------

local BLOCKER_TAGS = { "lunarsupernovablocker" }

local function FindSupernovaBlockersNearXZ(x, z)
	return TheSim:FindEntities(x, 0, z, 4, BLOCKER_TAGS)
end

local function IsSupernovaBlockedAtXZ(srcx, srcz, x, z, blockers)
	if #blockers > 0 then
		local dx = x - srcx
		local dz = z - srcz
		if dx ~= 0 or dz ~= 0 then
			local dsqsrc2me = dx * dx + dz * dz
			local anglesrc2me = math.atan2(-dz, dx)

			for i, v in ipairs(blockers) do
				local x2, _, z2 = v.Transform:GetWorldPosition()
				dx = x2 - srcx
				dz = z2 - srcz
				if dx ~= 0 or dz ~= 0 then
					local hsq = dx * dx + dz * dz
					if hsq < dsqsrc2me then
						local h = math.sqrt(hsq)
						local o = v:GetPhysicsRadius(0)
						local safearc = math.asin(o / h)
						local anglesrc2blocker = math.atan2(-dz, dx)
						if DiffAngleRad(anglesrc2blocker, anglesrc2me) < safearc then
							return true
						end
					end
				end
			end
		end
	end
	return false
end

--------------------------------------------------------------------------

return
{
	--Fissures
	TileCoordsToId = TileCoordsToId,
	IdToTileCoords = IdToTileCoords,
	SpawnFissureAtXZ = SpawnFissureAtXZ,
	DespawnFissure = DespawnFissure,
	OnLoadFissure = OnLoadFissure,
	HasFissure = HasFissure,

	--Lunar Burn
	LunarBurnFlags = LunarBurnFlags,
	HasLunarBurnDamage = HasLunarBurnDamage,
	CalcLunarBurnTickDamage = CalcLunarBurnTickDamage,

	--Supernova
	FindSupernovaBlockersNearXZ = FindSupernovaBlockersNearXZ,
	IsSupernovaBlockedAtXZ = IsSupernovaBlockedAtXZ,
	SupernovaNoArenaRange = 24, --for players who like to spawn our bosses in random places
	SupernovaNoArenaRangeSq = 24 * 24,
}
