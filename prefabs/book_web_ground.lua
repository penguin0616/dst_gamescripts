local assets =
{
    Asset("ANIM", "anim/fx_book_web.zip"),
    Asset("SOUND", "sound/wickerbottom_rework.fsb")
}

local SLOWDOWN_MUST_TAGS = { "locomotor" }
local SLOWDOWN_CANT_TAGS = { "player", "flying", "playerghost", "INLIMBO" }

local function OnUpdate(inst, x, y, z, rad)
    for i, v in ipairs(TheSim:FindEntities(x, y, z, TUNING.BOOK_WEB_GROUND_RADIUS, SLOWDOWN_MUST_TAGS, SLOWDOWN_CANT_TAGS)) do
        local is_follower = v.components.follower ~= nil and v.components.follower.leader ~= nil and v.components.follower.leader:HasTag("player")
        if v.components.locomotor ~= nil and not is_follower then
            v.components.locomotor:PushTempGroundSpeedMultiplier(TUNING.BEEQUEEN_HONEYTRAIL_SPEED_PENALTY, WORLD_TILES.MUD)
        end
    end
end

local function OnInit(inst, scale)
    local x, y, z = inst.Transform:GetWorldPosition()
    if scale == nil then
        scale = inst.Transform:GetScale()
    end

    if inst.tast ~= nil then
        inst.task:Cancel()
        inst.task = nil
    end
    
    inst.task = inst:DoPeriodicTask(0, OnUpdate, nil, x, y, z, scale)
    OnUpdate(inst, x, y, z, scale)
end

local function Despawn(inst)
    inst.AnimState:PlayAnimation("despawn")
    inst:ListenForEvent("animover", inst.Remove)
end

local function fn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.Transform:SetRotation(math.random(1, 360))

    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    --inst:AddTag("FX")
    

    inst.AnimState:SetBank ("fx_book_web")
    inst.AnimState:SetBuild("fx_book_web")
    inst.AnimState:PlayAnimation("spawn")
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetSortOrder(3)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:DoTaskInTime(TUNING.BOOK_WEB_GROUND_DURATION, Despawn)
    inst.SoundEmitter:PlaySound("wickerbottom_rework/book_spells/web")
    inst.persists = false
    inst:DoTaskInTime(0, OnInit)

    return inst
end

return Prefab("book_web_ground", fn, assets)