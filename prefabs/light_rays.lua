local assets=
{
    Asset("ANIM", "anim/lightrays.zip"),
}

local function OnEntityWake(inst)
    inst.Transform:SetRotation(45)
end

local function OnEntitySleep(inst)

end

local function showlightrays(inst)
    inst.components.colourtweener:StartTween({255/255,177/255,32/255,1}, 2)
    local rays = {1,2,3,4,5,6,7,8,9,10,11}
    for i=1,#rays,1 do
        inst.AnimState:Hide("lightray"..i)
    end

    for i=1,math.random(2,3),1 do
        local selection =math.random(1,#rays)
        inst.AnimState:Show("lightray"..rays[selection]) 
        table.remove(rays,selection)
    end
end

local function hiderays(inst)
    local rays = {1,2,3,4,5,6,7,8,9,10,11}
    for i=1,#rays,1 do
        inst.AnimState:Hide("lightray"..i)
    end
end

local function hidelightrays(inst)
    inst.components.colourtweener:StartTween({0,0,0,0}, 2, hiderays)
end

local function fadelightrays(inst)
    inst.components.colourtweener:StartTween({255/255/3,177/255/3,32/255/3,1/3}, 2)        
end

local function OnPhase(inst, phase)

    if phase == "dusk" then
        print("LIGHTRRAYS fade")
        fadelightrays(inst)
    end

    if phase == "night" then
        if TheWorld.state.isfullmoon then
            inst.components.colourtweener:StartTween({255/255,177/255,32/255,1}, 2)
        else
            print("LIGHTRRAYS  hide")
            hidelightrays(inst)
        end
    end

    if phase == "day" then
        print("LIGHTRRAYS show")
        if not inst.lastphasefullmoon then 
            showlightrays(inst)
        end
    end

    inst.lastphasefullmoon = TheWorld.state.isfullmoon
end

local function makefn()

    local function fn(Sim)
        local inst = CreateEntity()
        local trans = inst.entity:AddTransform()
        local anim = inst.entity:AddAnimState()
        inst.entity:AddNetwork()        
        inst.entity:AddLight()        
        inst.entity:AddSoundEmitter()
        trans:SetEightFaced()

        inst.OnEntitySleep = OnEntitySleep
        inst.OnEntityWake = OnEntityWake

        anim:SetBank("lightrays")
        anim:SetBuild("lightrays")
        anim:PlayAnimation("idle_loop", true)
        inst:AddTag("lightrays")
        inst:AddTag("exposure")    
        inst:AddTag("ignorewalkableplatforms")

        inst.persists = false

        inst.Transform:SetRotation(45)
        inst:AddTag("NOBLOCK")
        inst:AddTag("NOCLICK")

        if not TheNet:IsDedicated() then
            inst:AddComponent("distancefade")
            inst.components.distancefade:Setup(15,25)
        end

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("colourtweener")
        inst.components.colourtweener:StartTween({255/255,177/255,32/255,1}, 0)

        inst:WatchWorldState("phase", OnPhase)

        showlightrays(inst)

        return inst
    end
    return fn
end

return Prefab("lightrays_canopy", makefn(), assets)
