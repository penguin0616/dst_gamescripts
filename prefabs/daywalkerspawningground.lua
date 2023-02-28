local prefabs =
{
	"daywalker",
	"daywalker_pillar",
}

local function CheckForLunar(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local node, node_index = TheWorld.Map:FindVisualNodeAtPoint(x, y, z)
    if node then
        for _, tag in ipairs(node.tags) do
            if tag == "lunacyarea" or tag == "not_mainland" then
                inst:Remove()
                return
            end
        end
    end

    TheWorld:PushEvent("ms_registerdaywalkerspawningground", inst)
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    --[[Non-networked entity]]

    inst:AddTag("daywalkerspawningground")
    inst:AddTag("NOBLOCK")
    inst:AddTag("NOCLICK")

    inst:DoTaskInTime(0, CheckForLunar)

    return inst
end

return Prefab("daywalkerspawningground", fn, nil, prefabs)
