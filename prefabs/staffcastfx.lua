local assets =
{
    Asset("ANIM", "anim/staff.zip"),
}

local assets_cointoss =
{
    Asset("ANIM", "anim/cointosscast_fx.zip"),
    Asset("ANIM", "anim/mount_cointosscast_fx.zip"),
}

local function SetUp(inst, colour)
    inst.AnimState:SetMultColour(colour[1], colour[2], colour[3], 1)
end

local function MakeStaffFX(anim, build, bank)
    return function()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()

        inst:AddTag("FX")

        inst.Transform:SetFourFaced()

        inst.AnimState:SetBank(bank or "staff_fx")
        inst.AnimState:SetBuild(build or "staff")
        inst.AnimState:PlayAnimation(anim)

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst.SetUp = SetUp

        inst.persists = false

        --Anim is padded with extra blank frames at the end
        inst:ListenForEvent("animover", inst.Remove)

        return inst
    end
end

return Prefab("staffcastfx", MakeStaffFX("staff"), assets),
    Prefab("staffcastfx_mount", MakeStaffFX("staff_mount"), assets),
	Prefab("cointosscastfx", MakeStaffFX("cointoss", "cointosscast_fx", "cointosscast_fx"), assets_cointoss),
	Prefab("cointosscastfx_mount", MakeStaffFX("cointoss", "cointosscast_fx", "mount_cointosscast_fx"), assets_cointoss)

