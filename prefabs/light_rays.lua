local assets=
{
    Asset("ANIM", "anim/lightrays.zip"),
}

local function OnEntityWake(inst)
    inst.Transform:SetRotation(45)
end

local function OnEntitySleep(inst)

end

local light_params =
{
    day =
    {
        radius = 2,
        intensity = .6,  --.8
        falloff = 1,   --.7
        colour = { 180/255, 195/255, 150/255 },
        time = 2,
    },

    dusk =
    {
        radius = 2,
        intensity = .8,
        falloff = .7,
        colour = { 100/255, 100/255, 100/255 },
        time = 4,
    },

    night =
    {
        radius = 0,
        intensity = 0,
        falloff = 1,
        colour = { 0, 0, 0 },
        time = 6,
    },

    fullmoon =
    {
        radius = 2,
        intensity = .6,
        falloff = .6,
        colour = { 131/255, 194/255, 255/255 },
        time = 4,
    },
}

-- Generate light phase ID's
-- Add tint to params
local light_phases = {}
for k, v in pairs(light_params) do
    table.insert(light_phases, k)
    v.id = #light_phases
    v.tint = { v.colour[1] * .5, v.colour[2] * .5, v.colour[3] * .5, 0--[[ alpha, zero for additive blending ]] }
end

local function pushparams(inst, params)
    inst.Light:SetRadius(params.radius * inst.widthscale)
    inst.Light:SetIntensity(params.intensity)
    inst.Light:SetFalloff(params.falloff)
    inst.Light:SetColour(unpack(params.colour))
    inst.AnimState:OverrideMultColour(unpack(params.tint))
    if TheWorld.ismastersim then
        if params.intensity > 0 then
            inst.Light:Enable(true)
            inst:Show()
        else
            inst.Light:Enable(false)
            inst:Hide()
        end
    end
end

-- Not using deepcopy because we want to copy in place
local function copyparams(dest, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            dest[k] = dest[k] or {}
            copyparams(dest[k], v)
        else
            dest[k] = v
        end
    end
end

local function lerpparams(pout, pstart, pend, lerpk)
    for k, v in pairs(pend) do
        if type(v) == "table" then
            lerpparams(pout[k], pstart[k], v, lerpk)
        else
            pout[k] = pstart[k] * (1 - lerpk) + v * lerpk
        end
    end
end

local function OnUpdateLight(inst, dt)
    inst._currentlight.time = inst._currentlight.time + dt
    if inst._currentlight.time >= inst._endlight.time then
        inst._currentlight.time = inst._endlight.time
        inst._lighttask:Cancel()
        inst._lighttask = nil
    end
    lerpparams(inst._currentlight, inst._startlight, inst._endlight, inst._endlight.time > 0 and inst._currentlight.time / inst._endlight.time or 1)
    pushparams(inst, inst._currentlight)
end

local function OnLightPhaseDirty(inst)
    local phase = light_phases[inst._lightphase:value()]
    if phase ~= nil then
        local params = light_params[phase]
        if params ~= nil and params ~= inst._endlight then
            copyparams(inst._startlight, inst._currentlight)
            inst._currentlight.time = 0
            inst._startlight.time = 0
            inst._endlight = params
            if inst._lighttask == nil then
                inst._lighttask = inst:DoPeriodicTask(FRAMES, OnUpdateLight, nil, FRAMES)
            end
        end
    end
end

local function OnPhase(inst, phase)
    local params = light_params[phase == "night" and TheWorld.state.isfullmoon and "fullmoon" or phase]
    if params ~= nil then
        inst._lightphase:set(params.id)
        OnLightPhaseDirty(inst)
    end
end

local function OnInit(inst)
    if TheWorld.ismastersim then
        inst:WatchWorldState("phase", OnPhase)
        local params = light_params[TheWorld.state.iscavenight and TheWorld.state.isfullmoon and "fullmoon" or TheWorld.state.cavephase]
        if params ~= nil then
            inst._lightphase:set(params.id)
        end
    else
        inst:ListenForEvent("lightphasedirty", OnLightPhaseDirty)
    end

    local phase = light_phases[inst._lightphase:value()]
    if phase ~= nil then
        local params = light_params[phase]
        if params ~= nil and params ~= inst._endlight then
            copyparams(inst._currentlight, params)
            inst._endlight = params
            if inst._lighttask ~= nil then
                inst._lighttask:Cancel()
                inst._lighttask = nil
            end
            pushparams(inst, inst._currentlight)
        end
    end
end

local function makefn(fadeout)

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
--[[
        inst.Light:SetFalloff(1)
        inst.Light:SetIntensity(INTENSITY)
        inst.Light:SetRadius(1)
        inst.Light:SetColour(180/255, 195/255, 150/255)
        inst.Light:SetIntensity(0)
        inst.Light:Enable(false)
]]
 --       inst.Light:EnableClientModulation(true)
--[[
        inst.widthscale = 1
        inst._endlight = light_params.day
        inst._startlight = {}
        inst._currentlight = {}
        copyparams(inst._startlight, inst._endlight)
        copyparams(inst._currentlight, inst._endlight)
        pushparams(inst, inst._currentlight)

        inst._lightphase = net_tinybyte(inst.GUID, "lightrays._lightphase", "lightphasedirty")
        inst._lightphase:set(inst._currentlight.id)
        inst._lighttask = nil
]]
   --     inst:DoTaskInTime(0, OnInit)

        --inst:WatchWorldState("phase", timechange)

        if not TheNet:IsDedicated() then
            inst:AddComponent("distancefade")
            inst.components.distancefade:Setup(15,25)
        end

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst.AnimState:SetMultColour(255/255,177/255,32/255,0)

        local rays = {1,2,3,4,5,6,7,8,9,10,11}
        for i=1,#rays,1 do
            inst.AnimState:Hide("lightray"..i)
        end

        for i=1,math.random(2,3),1 do
            local selection =math.random(1,#rays)
            inst.AnimState:Show("lightray"..rays[selection]) 
            table.remove(rays,selection)
        end

        return inst
    end
    return fn
end


local function rays(name, fadeout)
    return Prefab(name, makefn(fadeout), assets)
end

return rays("lightrays_canopy")
