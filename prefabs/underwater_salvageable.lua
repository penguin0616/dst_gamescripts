local assets =
{
	Asset("ANIM", "anim/flotsam.zip"),
	Asset("ANIM", "anim/flotsam_heavy.zip"),
    Asset("MINIMAP_IMAGE", "flotsam_heavy"),
}

local prefabs =
{
    "messagebottletreasure_marker",
}

local SWIMMING_COLLISION_MASK   = COLLISION.GROUND
								+ COLLISION.LAND_OCEAN_LIMITS
								+ COLLISION.OBSTACLES
                                + COLLISION.SMALLOBSTACLES
                                
local function OnSalvage(inst)
    return inst.components.inventory:GetItemInSlot(1)
end

local function fn(data)
   local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()
	inst.entity:AddPhysics()

    inst.entity:AddMiniMapEntity()
    inst.MiniMapEntity:SetIcon("flotsam_heavy.png")
	
    inst.Physics:SetCollisionGroup(COLLISION.CHARACTERS)
	inst.Physics:SetCollisionMask(SWIMMING_COLLISION_MASK)
    inst.Physics:SetCapsule(0.5, 1)

    inst:AddTag("ignorewalkableplatforms")
	inst:AddTag("notarget")
	inst:AddTag("NOCLICK")
    inst:AddTag("NOBLOCK")-- it's fine to build things on top of them
    inst:AddTag("winchtarget")--from winchtarget component

    inst.AnimState:SetBank("flotsam_heavy")
    inst.AnimState:SetBuild("flotsam_heavy")
    inst.AnimState:PlayAnimation("idle", true)

    inst.AnimState:SetSortOrder(ANIM_SORT_ORDER_BELOW_GROUND.UNDERWATER)
    inst.AnimState:SetLayer(LAYER_WIP_BELOW_OCEAN)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("winchtarget")
    inst.components.winchtarget:SetSalvageFn(OnSalvage)
    
    inst:AddComponent("treasuremarked")

	inst:AddComponent("inventory")
	inst.components.inventory.ignorescangoincontainer = true
	inst.components.inventory.maxslots = 1

    return inst
end

return Prefab("underwater_salvageable", fn, assets, prefabs)