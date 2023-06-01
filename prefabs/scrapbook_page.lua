local assets =
{
    Asset("ANIM", "anim/scrapbook_page.zip"),
}

local function OnActivate(inst, doer)
    local dataset = require("screens/redux/scrapbookdata")

    local unknown = {}
    for prefab,data in pairs(dataset) do
        if TheScrapbookPartitions:GetLevelFor(prefab) < 1 then
            table.insert(unknown,prefab)
        end
    end

    if #unknown > 0 then 
        local numofentries = math.random(3,4)
        local learned_something = false
        while #unknown > 0 and numofentries>0 do

            local choice = math.random(1,#unknown)

            local ok = false
            for i, cat  in ipairs(SCRAPBOOK_CATS) do
                if dataset[unknown[choice]].type == cat then
                    ok = true
                    break
                end
            end
            if ok then
                learned_something = true
                TheScrapbookPartitions:SetSeenInGame(unknown[choice])
                numofentries = numofentries -1
            end
            table.remove(unknown,choice)
        end

        inst:Remove()
        if learned_something then
            return        
        end
    end

    inst.components.activatable.inactive = true
    doer.components.talker:Say(GetString(doer, "ANNOUNCE_SCRAPBOOK_FULL"))
end

local function GetActivateVerb(inst, doer)
    return "SCRAPBOOK"
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("scrapbook_page")
    inst.AnimState:SetBuild("scrapbook_page")
    inst.AnimState:PlayAnimation("idle")

    inst:AddTag("cattoy")
    inst:AddTag("scrapbook_page")

    MakeInventoryFloatable(inst, "med", nil, 0.75)

    inst.entity:SetPristine()

    inst.GetActivateVerb = GetActivateVerb

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("stackable")
    inst.components.stackable.maxsize = TUNING.STACK_SIZE_SMALLITEM

    inst:AddComponent("inspectable")

    inst:AddComponent("fuel")
    inst.components.fuel.fuelvalue = TUNING.SMALL_FUEL

    inst:AddComponent("tradable")

    inst:AddComponent("activatable")
    inst.components.activatable.OnActivate = OnActivate
    inst.components.activatable.inactive = true

    MakeSmallBurnable(inst, TUNING.SMALL_BURNTIME)
    MakeSmallPropagator(inst)
    MakeHauntableLaunchAndIgnite(inst)

    inst:AddComponent("inventoryitem")

    return inst
end

return Prefab("scrapbook_page", fn, assets)
