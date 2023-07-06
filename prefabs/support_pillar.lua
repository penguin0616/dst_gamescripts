local assets =
{
    Asset("ANIM", "anim/support_pillar.zip"),
    Asset("MINIMAP_IMAGE", "support_pillar"),
}

local prefabs =
{
    "support_pillar",
    "support_pillar_complete",
    "support_pillar_broken",
}

local function crumble(inst)
    local new_pillar = ReplacePrefab(inst, "support_pillar_broken")
end

local function onquake_complete(inst)    
    inst.AnimState:PlayAnimation("quake",false)
    inst.AnimState:PushAnimation("idle", true)
end

local function onhit_complete(inst)
    inst.AnimState:PlayAnimation("idle_hit",false)
    inst.AnimState:PushAnimation("idle", true)

    inst.components.workable:SetWorkLeft(5)

    local find = function(item)
        return item and true
    end

    local rock = inst.components.inventory:DropItem(inst.components.inventory:GetItemInSlot(1))
    if rock then 
        rock:Remove() 
        if math.random() < 0.3 then inst.components.lootdropper:FlingItem(SpawnPrefab("rocks")) end
    end

    if not inst.components.inventory:FindItem(find) then
        local new_pillar = ReplacePrefab(inst, "support_pillar")
        new_pillar.components.constructionsite:AddMaterial("rocks", 39)
    end
end

local function onhammered_complete(inst)
    
end

local function gridplacing(inst)
    inst:DoTaskInTime(0,function()    
        inst._pfpos = inst:GetPosition()
        local x,y,z = inst._pfpos:Get()

        TheWorld.Pathfinder:AddWall(x+1,y,z+1)
        TheWorld.Pathfinder:AddWall(x+0,y,z+1)
        TheWorld.Pathfinder:AddWall(x-1,y,z+1)

        TheWorld.Pathfinder:AddWall(x+1,y,z-1)
        TheWorld.Pathfinder:AddWall(x+0,y,z-1)
        TheWorld.Pathfinder:AddWall(x-1,y,z-1)

        TheWorld.Pathfinder:AddWall(x-1,y,z+0)
        TheWorld.Pathfinder:AddWall(x+1,y,z+0)
        TheWorld.Pathfinder:AddWall(x+0,y,z+0)        
    end)
    inst:ListenForEvent("onremove",function() 
        if inst._pfpos ~= nil then
            local x,y,z = inst._pfpos:Get()

            TheWorld.Pathfinder:RemoveWall(x+1,y,z+1)
            TheWorld.Pathfinder:RemoveWall(x+0,y,z+1)
            TheWorld.Pathfinder:RemoveWall(x-1,y,z+1)

            TheWorld.Pathfinder:RemoveWall(x+1,y,z-1)
            TheWorld.Pathfinder:RemoveWall(x+0,y,z-1)
            TheWorld.Pathfinder:RemoveWall(x-1,y,z-1)

            TheWorld.Pathfinder:RemoveWall(x-1,y,z+0)
            TheWorld.Pathfinder:RemoveWall(x+1,y,z+0)
            TheWorld.Pathfinder:RemoveWall(x+0,y,z+0)
        end
    end)  
end

local function completefn()

    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddLight()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

    inst.MiniMapEntity:SetIcon("support_pillar.png")

    inst:AddTag("structure")
    inst:AddTag("quake_blocker")
    inst.AnimState:SetMultColour(1,0.8,0.8,1)

    inst:SetPhysicsRadiusOverride(1)
    MakeObstaclePhysics(inst, inst.physicsradiusoverride)

    inst.AnimState:SetBank("support_pillar")
    inst.AnimState:SetBuild("support_pillar")
    inst.AnimState:PlayAnimation("idle", true)

    inst:AddTag("antlion_sinkhole_blocker")

    MakeSnowCoveredPristine(inst)

    gridplacing(inst)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst._construction_product = nil

    inst:AddComponent("lootdropper")

    inst:AddComponent("inventory")    

    inst:AddComponent("inspectable")    
    inst:ListenForEvent("startquake",function() onquake_complete(inst) end, TheWorld.net)
    inst:ListenForEvent("animover", function()
        if inst.AnimState:IsCurrentAnimation("hit") then
            local find = function(item)
                return item and true
            end

            local rock = inst.components.inventory:DropItem(inst.components.inventory:GetItemInSlot(1))
            if rock then rock:Remove() end

            if not inst.components.inventory:FindItem(find) then
                local new_pillar = ReplacePrefab(inst, "support_pillar")
                new_pillar.components.constructionsite:AddMaterial("rocks", 39)
            end
        end
    end)

    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
    inst.components.workable:SetWorkLeft(5)
    inst.components.workable:SetOnFinishCallback(onhammered_complete)
    inst.components.workable:SetOnWorkCallback(onhit_complete)        

    return inst
end

local function onconstruction_built(inst)
    inst.AnimState:PlayAnimation("place")
    inst.AnimState:PushAnimation("scaffold", true)
end

local function OnConstructed(inst, doer)
    local concluded = true
    for i, v in ipairs(CONSTRUCTION_PLANS[inst.prefab] or {}) do
        if inst.components.constructionsite:GetMaterialCount(v.type) < v.amount then
            concluded = false
            break
        end
    end

    if concluded then
        local new_pillar = ReplacePrefab(inst, inst._construction_product)
        new_pillar.AnimState:PlayAnimation("build", false)
        new_pillar.AnimState:PushAnimation("idle",true)
        for i=1,10 do
            new_pillar.components.inventory:GiveItem(SpawnPrefab("rocks"))
        end
    end
end

local function onhit_scaffold(inst)
    inst.components.workable:SetWorkLeft(5)
    if inst.components.constructionsite.materials["rocks"] then
        inst.components.constructionsite.materials["rocks"].amount = inst.components.constructionsite.materials["rocks"].amount -1
        if math.random() < 0.3 then inst.components.lootdropper:FlingItem(SpawnPrefab("rocks")) end
    end
    if not inst.components.constructionsite.materials["rocks"] or inst.components.constructionsite.materials["rocks"].amount < 1 then
        local fx = SpawnPrefab("collapse_small")
        fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
        fx:SetMaterial("rock")       
        inst:Remove() 
    end    
    inst.AnimState:PlayAnimation("scaffold_hit")
    inst.AnimState:PushAnimation("scaffold", true)
end

local function onhammered_scaffold(inst)

end

local function scaffoldfn()

	local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddLight()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

	inst.MiniMapEntity:SetIcon("support_pillar.png")

    inst:AddTag("structure")

    inst:SetPhysicsRadiusOverride(1)
    MakeObstaclePhysics(inst, inst.physicsradiusoverride)

	inst.AnimState:SetBank("support_pillar")
	inst.AnimState:SetBuild("support_pillar")
	inst.AnimState:PlayAnimation("scaffold")

    inst:AddTag("constructionsite")

	inst:AddTag("antlion_sinkhole_blocker")

    MakeSnowCoveredPristine(inst)

    gridplacing(inst)

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst._construction_product = "support_pillar_complete"

	inst:AddComponent("constructionsite")
	inst.components.constructionsite:SetConstructionPrefab("construction_container")
    inst.components.constructionsite:SetOnConstructedFn(OnConstructed)

	inst:AddComponent("inspectable")

    inst:AddComponent("lootdropper")

	inst:ListenForEvent("onbuilt", onconstruction_built)

    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
    inst.components.workable:SetWorkLeft(5)
    inst.components.workable:SetOnFinishCallback(onhammered_scaffold)
    inst.components.workable:SetOnWorkCallback(onhit_scaffold)    

    return inst
end

local function onquake(inst)
    inst.AnimState:PlayAnimation("break_quake_"..inst.getartnum(inst), false)
    inst.AnimState:PushAnimation("break_"..inst.getartnum(inst), true)
    inst.components.constructionsite:Disable()
end

local function onhit(inst)
    inst.AnimState:PlayAnimation("break_hit_"..inst.getartnum(inst), false)
    inst.AnimState:PushAnimation("break_"..inst.getartnum(inst), true)
    inst.components.workable:SetWorkLeft(5)
    if inst.components.constructionsite.materials["rocks"] then
        inst.components.constructionsite.materials["rocks"].amount = inst.components.constructionsite.materials["rocks"].amount -1
        if math.random() < 0.3 then inst.components.lootdropper:FlingItem(SpawnPrefab("rocks")) end
    end
    if not inst.components.constructionsite.materials["rocks"] or inst.components.constructionsite.materials["rocks"].amount < 1 then
        local fx = SpawnPrefab("collapse_small")
        fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
        fx:SetMaterial("rock")       
        local newpillar = ReplacePrefab(inst, "support_pillar_broken")
    end
end

local function onhammered(inst)

end

local function getartnum(inst)
    local percent = inst.components.constructionsite.materials["rocks"] and inst.components.constructionsite.materials["rocks"].amount/TUNING.STACK_SIZE_SMALLITEM or 0
    if percent > 0.5 then 
        return "1"
    elseif percent > 0.25 then
        return "2"
    else
        return "3"
    end
end

local function fn()

    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddLight()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

    inst.MiniMapEntity:SetIcon("support_pillar.png")

    inst:AddTag("structure")
    inst:AddTag("quake_blocker")    

    inst:SetPhysicsRadiusOverride(1)
    MakeObstaclePhysics(inst, inst.physicsradiusoverride)

    inst.AnimState:SetBank("support_pillar")
    inst.AnimState:SetBuild("support_pillar")
    inst.AnimState:PlayAnimation("break_1", true)

    inst:AddTag("constructionsite")

    inst:AddTag("antlion_sinkhole_blocker")

    MakeSnowCoveredPristine(inst)

    gridplacing(inst)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end


    inst._construction_product = "support_pillar_complete"

    inst:AddComponent("constructionsite")
    inst.components.constructionsite:SetConstructionPrefab("construction_container")
    inst.components.constructionsite:SetOnConstructedFn(OnConstructed)

    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
    inst.components.workable:SetWorkLeft(5)
    inst.components.workable:SetOnFinishCallback(onhammered)
    inst.components.workable:SetOnWorkCallback(onhit)    

    inst:AddComponent("lootdropper")

    inst:AddComponent("inspectable")

    inst:ListenForEvent("startquake",function() onquake(inst) end, TheWorld.net)
    inst:ListenForEvent("animover", function()
        if inst.AnimState:IsCurrentAnimation("hit") then
            inst.components.constructionsite:Enable()
            if inst.components.constructionsite.materials["rocks"] then
                inst.components.constructionsite.materials["rocks"].amount = inst.components.constructionsite.materials["rocks"].amount -1            
            end
            if not inst.components.constructionsite.materials["rocks"] or inst.components.constructionsite.materials["rocks"].amount < 1 then
                crumble(inst)
            end            
        end
    end)

    inst.getartnum = getartnum
    inst.AnimState:PlayAnimation("break_"..getartnum(inst), true)

    return inst
end

local function onhit_broken(inst)
--    inst:PlayAnimation("hit")
--    inst:PushAnimation("idle", false)
    inst.components.workable:SetWorkLeft(5)
    if inst.components.constructionsite.materials["rocks"] then
        inst.components.constructionsite.materials["rocks"].amount = inst.components.constructionsite.materials["rocks"].amount -1
        if math.random() < 0.3 then inst.components.lootdropper:FlingItem(SpawnPrefab("rocks")) end
    end
    if not inst.components.constructionsite.materials["rocks"] or inst.components.constructionsite.materials["rocks"].amount < 1 then
        local fx = SpawnPrefab("collapse_small")
        fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
        fx:SetMaterial("rock")       
        inst:Remove() 
    end
end

local function onhammered_broken(inst)

end

local function brokenfn()

    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddLight()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

    inst.MiniMapEntity:SetIcon("support_pillar.png")

    inst:AddTag("structure")

    inst:SetPhysicsRadiusOverride(1)
    MakeObstaclePhysics(inst, inst.physicsradiusoverride)

    inst.AnimState:SetBank("support_pillar")
    inst.AnimState:SetBuild("support_pillar")
    inst.AnimState:PlayAnimation("broken")

    inst:AddTag("constructionsite")

    inst:AddTag("antlion_sinkhole_blocker")

    MakeSnowCoveredPristine(inst)

    gridplacing(inst)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst._construction_product = "support_pillar_complete"

    inst:AddComponent("constructionsite")
    inst.components.constructionsite:SetConstructionPrefab("construction_container")
    inst.components.constructionsite:SetOnConstructedFn(OnConstructed)

    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
    inst.components.workable:SetWorkLeft(5)
    inst.components.workable:SetOnFinishCallback(onhammered_broken)
    inst.components.workable:SetOnWorkCallback(onhit_broken)

    inst:AddComponent("lootdropper")

    inst:AddComponent("inspectable")

    inst:ListenForEvent("onbuilt", onconstruction_built)

    return inst
end


local function placer_postinit_fn(inst)
    local inner = CreateEntity()

    --[[Non-networked entity]]
    inner.entity:SetCanSleep(false)
    inner.persists = false

    inner.entity:AddTransform()
    inner.entity:AddAnimState()

    inner:AddTag("CLASSIFIED")
    inner:AddTag("NOCLICK")
    inner:AddTag("placer")


    inner.AnimState:SetBank("firefighter_placement")
    inner.AnimState:SetBuild("firefighter_placement")
    inner.AnimState:PlayAnimation("idle")
    inner.AnimState:SetAddColour(0, .2, .5, 0)
    inner.AnimState:SetLightOverride(1)
    inner.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inner.AnimState:SetLayer(LAYER_WORLD_BACKGROUND)
    inner.AnimState:SetSortOrder(3)
    inner.AnimState:SetScale(5.28, 5.28)

    inner.entity:SetParent(inst.entity)
    inst.components.placer:LinkEntity(inner)

    --local recipe = AllRecipes.table_winters_feast
   -- local inner_radius_scale = PLACER_SCALE --recipe ~= nil and recipe.min_spacing ~= nil and (recipe.min_spacing / 2.2) or 1 -- roughly lines up size of animation with blocking radius
    --inner.AnimState:SetScale(inner_radius_scale, inner_radius_scale)
end

return Prefab("support_pillar_scaffold", scaffoldfn, assets, prefabs),             
       MakePlacer("support_pillar_scaffold_placer", "support_pillar", "support_pillar", "idle", nil, false, true, nil, nil, nil, placer_postinit_fn),
       Prefab("support_pillar", fn, assets, prefabs),
       Prefab("support_pillar_complete", completefn, assets, prefabs),
       Prefab("support_pillar_broken", brokenfn, assets, prefabs)