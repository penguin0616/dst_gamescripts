local assets =
{
    Asset("MINIMAP_IMAGE", "moonstormmarker0"),
    Asset("MINIMAP_IMAGE", "moonstormmarker1"),
    Asset("MINIMAP_IMAGE", "moonstormmarker2"),
    Asset("MINIMAP_IMAGE", "moonstormmarker3"),
    Asset("MINIMAP_IMAGE", "moonstormmarker4"),
    Asset("MINIMAP_IMAGE", "moonstormmarker5"),
    Asset("MINIMAP_IMAGE", "moonstormmarker6"),
    Asset("MINIMAP_IMAGE", "moonstormmarker7"),
}

local prefabs =
{
    "globalmapicon",
}

local function do_marker_minimap_swap(inst)
    inst.marker_index = inst.marker_index + 1
    if inst.marker_index == 8  then
        inst.marker_index = 1
    end
    local marker_image = (inst.marker_index == 1 and "moonstormmarker0.png") or "moonstormmarker"..inst.marker_index..".png"

    inst.MiniMapEntity:SetIcon(marker_image)
    inst.icon.MiniMapEntity:SetIcon(marker_image)
end

local function show_minimap(inst)
    -- Create a global map icon so the minimap icon is visible to other players as well.
    inst.icon = SpawnPrefab("globalmapicon")
    inst.icon:TrackEntity(inst)
    inst.icon.MiniMapEntity:SetPriority(21)

    inst:DoPeriodicTask(TUNING.STORM_SWAP_TIME, do_marker_minimap_swap)
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst.MiniMapEntity:SetCanUseCache(false)
    inst.MiniMapEntity:SetDrawOverFogOfWar(true) 
    inst.MiniMapEntity:SetIcon("moonstormmarker.png")
    inst.MiniMapEntity:SetPriority(21)

	-- inst:SetPrefabNameOverride("MINIFLARE")

    inst.entity:SetCanSleep(false)

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst:DoTaskInTime(0, show_minimap)

    inst.persists = false

    inst._small_minimap = 1

    return inst
end

local function bigfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst.MiniMapEntity:SetCanUseCache(false)
    inst.MiniMapEntity:SetDrawOverFogOfWar(true)
    inst.MiniMapEntity:SetIcon("moonstormmarker0.png")
    inst.MiniMapEntity:SetPriority(21)

    -- inst:SetPrefabNameOverride("MINIFLARE")

    inst.entity:SetCanSleep(false)

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst.icon = SpawnPrefab("globalmapicon")
    inst.icon:TrackEntity(inst)
    inst.icon.MiniMapEntity:SetPriority(21)

    inst.persists = false

    inst._small_minimap = 1

    inst.marker_index = 1
    inst:DoTaskInTime(0, show_minimap)

    return inst
end

-- local function on_ignite_over(inst)
--     local fx, fy, fz = inst.Transform:GetWorldPosition()

--     local random_angle = math.pi * 2 * math.random()
--     local random_radius = -(TUNING.MINIFLARE.OFFSHOOT_RADIUS) + (math.random() * 2 * TUNING.MINIFLARE.OFFSHOOT_RADIUS)

--     fx = fx + (random_radius * math.cos(random_angle))
--     fz = fz + (random_radius * math.sin(random_angle))

--     -------------------------------------------------------------
--     -- Find talkers to say speech.
--     for _, player in ipairs(AllPlayers) do
--         if player._miniflareannouncedelay == nil and math.random() > TUNING.MINIFLARE.CHANCE_TO_NOTICE then
--             local px, py, pz = player.Transform:GetWorldPosition()
--             local sq_dist_to_flare = distsq(fx, fz, px, pz)
--             if sq_dist_to_flare > TUNING.MINIFLARE.SPEECH_MIN_DISTANCE_SQ then
-- 				player._miniflareannouncedelay = player:DoTaskInTime(TUNING.MINIFLARE.NEXT_NOTICE_DELAY, function(i) i._miniflareannouncedelay = nil end) -- so gross, if this logic gets any more complicated then make a component
--                 player.components.talker:Say(GetString(player, "ANNOUNCE_FLARE_SEEN"))
--             end
--         end
--     end

--     -------------------------------------------------------------
--     -- Create an entity to cover the close-up minimap icon; the 'globalmapicon' doesn't cover this.
--     local minimap = SpawnPrefab("moonstormmarker")
--     minimap.Transform:SetPosition(fx, fy, fz)
--     minimap:DoTaskInTime(TUNING.MINIFLARE.TIME, function()
--         minimap:Remove()
--     end)

--     inst:Remove()
-- end

return Prefab("moonstormmarker", fn, assets, prefabs),
       Prefab("moonstormmarker_big", bigfn, assets, prefabs)