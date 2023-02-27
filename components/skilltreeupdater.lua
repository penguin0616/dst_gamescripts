local skilltreedefs = require "prefabs/skilltree_defs"

local function onplayeractivated(inst)
    local self = inst.components.skilltreeupdater

    if self and not TheNet:IsDedicated() and inst == ThePlayer then
        self.skilltree = TheSkillTree -- skilltreedata type
        self.skilltree.save_enabled = nil -- Disable saving until the activation handshake is complete to preserve client save state.
    end
end

local SkillTreeUpdater = Class(function(self, inst)
    self.inst = inst

    self.skilltree = require("skilltreedata")()
    inst:ListenForEvent("playeractivated", onplayeractivated)
end)

-- NOTES(JBK): Wrapper functions to adhere to abstraction layers.

function SkillTreeUpdater:IsActivated(skill)
    return self.skilltree:IsActivated(skill, self.inst.prefab)
end

function SkillTreeUpdater:IsValidSkill(skill)
return self.skilltree:IsValidSkill(self.inst.prefab, skill)
end

function SkillTreeUpdater:GetSkillXP()
    return self.skilltree:GetSkillXP(self.inst.prefab)
end

function SkillTreeUpdater:GetPointsForSkillXP(skillxp)
    return self.skilltree:GetPointsForSkillXP(skillxp)
end

function SkillTreeUpdater:GetAvailableSkillPoints()
    return self.skilltree:GetAvailableSkillPoints(self.inst.prefab)
end

function SkillTreeUpdater:GetPlayerSkillSelection() -- NOTES(JBK): Returns an array table of bitfield entries of all activated skills.
    return self.skilltree:GetPlayerSkillSelection(self.inst.prefab)
end

function SkillTreeUpdater:GetNamesFromSkillSelection(skillselection) -- NOTES(JBK): Gets a skill name key table from an array table of bitfield entries of all activated skills.
    return self.skilltree:GetNamesFromSkillSelection(skillselection, self.inst.prefab)
end


function SkillTreeUpdater:ActivateSkill_Client(skill, unlocks) -- NOTES(JBK): Use ActivateSkill instead.
    local characterprefab = ThePlayer.prefab
    --print("[STUpdater] ActivateSkill CLIENT", characterprefab, skill)
    ThePlayer:PushEvent("onactivateskill_client", {skill = skill,})
    if unlocks ~= nil then
        for _, v in ipairs(unlocks) do
            ThePlayer:PushEvent("onunlockskill_client", {skill = v,})
        end
    end
end
function SkillTreeUpdater:ActivateSkill_Server(skill, unlocks) -- NOTES(JBK): Use ActivateSkill instead.
    local characterprefab = self.inst.prefab
    --print("[STUpdater] ActivateSkill SERVER", characterprefab, skill)
    local onactivate = skilltreedefs.SKILLTREE_DEFS[characterprefab][skill].onactivate
    if onactivate then
        onactivate(self.inst)
    end
    self.inst:PushEvent("onactivateskill_server", {skill = skill,})
end
function SkillTreeUpdater:ActivateSkill(skill, prefab, fromrpc)
    -- should ignore the prefab paramater as that's just used skilltreedata at frontend
    local characterprefab = self.inst.prefab
    if characterprefab and skill then
        local updated, unlocks = self.skilltree:ActivateSkill(skill, characterprefab)
        if self.silent then
            return
        end

        if updated then
            if TheWorld.ismastersim then
                if self.inst.userid and (TheNet:IsDedicated() or (TheWorld.ismastersim and self.inst ~= ThePlayer)) then
                    self:ActivateSkill_Server(skill, unlocks)
                    if not fromrpc then
                        SendRPCToClient(CLIENT_RPC.SetSkillActivatedState, self.inst.userid, self.skilltree:GetSkillIDFromName(characterprefab, skill), true)
                    end
                else
                    self:ActivateSkill_Client(skill, unlocks)
                    self:ActivateSkill_Server(skill, unlocks)
                end
            elseif self.inst == ThePlayer then
                self:ActivateSkill_Client(skill, unlocks)
                if not fromrpc then
                    SendRPCToServer(RPC.SetSkillActivatedState, self.skilltree:GetSkillIDFromName(characterprefab, skill), true)
                end
            end
        end
    end
end


function SkillTreeUpdater:DeactivateSkill_Client(skill) -- NOTES(JBK): Use DeactivateSkill instead.
    local characterprefab = ThePlayer.prefab
    --print("[STUpdater] DeactivateSkill CLIENT", characterprefab, skill)
    ThePlayer:PushEvent("ondeactivateskill_client", {skill = skill,})
end
function SkillTreeUpdater:DeactivateSkill_Server(skill) -- NOTES(JBK): Use DeactivateSkill instead.
    local characterprefab = self.inst.prefab
    --print("[STUpdater] DeactivateSkill SERVER", characterprefab, skill)
    self.inst:PushEvent("ondeactivateskill_server", {skill = skill,})
end
function SkillTreeUpdater:DeactivateSkill(skill, prefab,  fromrpc)
    -- should ignore the prefab paramater as that's just used skilltreedata at frontend
    local characterprefab = self.inst.prefab
    if characterprefab and skill then
        local updated = self.skilltree:DeactivateSkill(skill, characterprefab) -- FIXME(JBK): Detect if this will cause skills to get locked, and then also deactivate the whole tree branch recursively.
        if self.silent then
            return
        end

        if updated then
            if TheWorld.ismastersim then
                if self.inst.userid and (TheNet:IsDedicated() or (TheWorld.ismastersim and self.inst ~= ThePlayer)) then
                    self:DeactivateSkill_Server(skill)
                    if not fromrpc then
                        SendRPCToClient(CLIENT_RPC.SetSkillActivatedState, self.inst.userid, self.skilltree:GetSkillIDFromName(characterprefab, skill), false)
                    end
                else
                    self:DeactivateSkill_Client(skill)
                    self:DeactivateSkill_Server(skill)
                end
            elseif self.inst == ThePlayer then
                self:DeactivateSkill_Client(skill)
                if not fromrpc then
                    SendRPCToServer(RPC.SetSkillActivatedState, self.skilltree:GetSkillIDFromName(characterprefab, skill), false)
                end
            end
        end
    end
end

function SkillTreeUpdater:AddSkillXP_Client(amount, total) -- NOTES(JBK): Use AddSkillXP instead.
    local characterprefab = ThePlayer.prefab
    --print("[STUpdater] AddSkillXP CLIENT", characterprefab, amount, total)
    ThePlayer:PushEvent("onaddskillxp_client", {amount = amount, total = total})
end
function SkillTreeUpdater:AddSkillXP_Server(amount, total) -- NOTES(JBK): Use AddSkillXP instead.
    local characterprefab = self.inst.prefab
    --print("[STUpdater] AddSkillXP SERVER", characterprefab, amount, total)
    self.inst:PushEvent("onaddskillxp_server", {amount = amount, total = total})
end
function SkillTreeUpdater:AddSkillXP(amount, prefab, fromrpc)
    -- should ignore the prefab paramater as that's just used skilltreedata at frontend
    local characterprefab = self.inst.prefab
    if characterprefab and amount then
        local updated, total = self.skilltree:AddSkillXP(amount, characterprefab)

        if updated then
            if TheWorld.ismastersim then
                if self.inst.userid and (TheNet:IsDedicated() or (TheWorld.ismastersim and self.inst ~= ThePlayer)) then
                    self:AddSkillXP_Server(amount, total)
                    if not fromrpc then
                        SendRPCToClient(CLIENT_RPC.AddSkillXP, self.inst.userid, amount)
                    end
                else
                    self:AddSkillXP_Client(amount, total)
                    self:AddSkillXP_Server(amount, total)
                end
            elseif self.inst == ThePlayer then
                self:AddSkillXP_Client(amount, total)
                if not fromrpc then
                    SendRPCToServer(RPC.AddSkillXP, amount)
                end
            end
        end

        if self.inst == ThePlayer and not TheSkillTree.ignorexp then -- Local UI handler.
            if self:GetAvailableSkillPoints() > 0 then
                ThePlayer.new_skill_available_popup = true
                ThePlayer:PushEvent("newskillpointupdated")
            end
        end
    end
end

-- NOTES(JBK): Data layer. Engage at your own risk.

function SkillTreeUpdater:OnSave()
    local skilltreeblob = self.skilltreeblob or self.skilltree:EncodeSkillTreeData(self.inst.prefab)
    --print("[STUpdater] OnSave", skilltreeblob)
    if skilltreeblob ~= TheSkillTree.NILDATA then
        return {skilltreeblob = skilltreeblob,}
    end
end

function SkillTreeUpdater:SetPlayerSkillSelection(skillselection) -- NOTES(JBK): Applies an array table of bitfield entries of all activated skills and does not network anything.
    local activatedskills = self:GetNamesFromSkillSelection(skillselection)
    self.silent = true
    for skill, _ in pairs(activatedskills) do
        self:ActivateSkill(skill) -- Hiding this to stop networking and activation callbacks.
    end
    self.silent = nil
    self.skilltreeblob = self.skilltree:EncodeSkillTreeData(self.inst.prefab)
end

function SkillTreeUpdater:SendFromSkillTreeBlob(inst)
    if self.skilltreeblob ~= nil then
        local activatedskills, skillxp = self.skilltree:DecodeSkillTreeData(self.skilltreeblob)
        self.skilltreeblob = nil
        if activatedskills ~= nil then
            self.silent = true
            for skill, _ in pairs(activatedskills) do
                self:DeactivateSkill(skill)
            end
            self.silent = nil
            for skill, _ in pairs(activatedskills) do
                self:ActivateSkill(skill) -- Two loops just in case of activation states.
            end
        end
        -- Do not use nor send skillxp here.
    end
end

function SkillTreeUpdater:OnLoad(data)
    self.skilltreeblob = data.skilltreeblob
    --print("[STUpdater] OnLoad", self.skilltreeblob)
end

return SkillTreeUpdater