local skilltreedata_all = require("prefabs/skilltree_defs")
local SKILLTREE_DEFS, SKILLTREE_METAINFO = skilltreedata_all.SKILLTREE_DEFS, skilltreedata_all.SKILLTREE_METAINFO


local SkillTreeData = Class(function(self)
    self.activatedskills = {}
    self.skillxp = {}
    self.NILDATA = self:EncodeSkillTreeData() -- NOTES(JBK): This the default output when no data is available.

    --self.save_enabled = nil
    --self.dirty = nil
end)

-- NOTES(JBK): Chances are you want to use the wrapper functions in skilltreeupdater for these.

function SkillTreeData:IsActivated(skill, characterprefab)
    if SKILLTREE_DEFS[characterprefab] == nil then
        --print("Invalid skilltree characterprefab to IsActivated:", characterprefab, skill)
        return false
    end
    local skills = self.activatedskills[characterprefab]
    return skills and (skills[skill] ~= nil) or false
end

function SkillTreeData:IsValidSkill(skill, characterprefab)
    if SKILLTREE_DEFS[characterprefab] == nil then
        --print("Invalid skilltree characterprefab to IsValidSkill:", characterprefab, skill)
        return false
    end
    return SKILLTREE_DEFS[characterprefab][skill] ~= nil
end

function SkillTreeData:GetSkillXP(characterprefab)
    return self.skillxp[characterprefab] or 0
end

function SkillTreeData:GetMaximumExperiencePoints()
    local tally = 0
    for i,threshold in ipairs(TUNING.SKILL_THRESHOLDS)do
        tally = tally + threshold
    end
    return tally
end

function SkillTreeData:GetPointsForSkillXP(skillxp)
    local tally = 0
    local current = 0
    for i, threshold in ipairs(TUNING.SKILL_THRESHOLDS) do
        tally = tally + threshold

        if skillxp < tally then
            return current
        end
        current = i
        if skillxp == tally then
            return current
        end
    end
    return 0
end

function SkillTreeData:GetAvailableSkillPoints(characterprefab)
    local total = 0
    local skills = self.activatedskills[characterprefab]
    if skills then
        for k, v in pairs(skills) do
            total = total + 1
        end
    end

    return self:GetPointsForSkillXP(self:GetSkillXP(characterprefab)) - total
end

function SkillTreeData:GetPlayerSkillSelection(characterprefab)
    local skillselection = {}
    -- NOTES(JBK): [Searchable "SN_SKILLSELECTION"] The engine will only use the first slot for a maximum of 32 skills at this time. Adding more data will not be shown to other players.
    local bitfield = 0
    local skills = self.activatedskills[characterprefab]
    if skills then
        local skilldefs = SKILLTREE_DEFS[characterprefab]
        if skilldefs then
            for skill in pairs(skills) do
                local rpc_id = skilldefs[skill].rpc_id
                local rpc_bit = 2 ^ rpc_id
                bitfield = bit.bor(bitfield, rpc_bit)
            end
        end
    end
    skillselection[1] = bitfield
    return skillselection
end

function SkillTreeData:GetNamesFromSkillSelection(skillselection, characterprefab)
    local activatedskills = {}
    local skilldefs = SKILLTREE_DEFS[characterprefab]
    if skilldefs then
        -- NOTES(JBK): [Searchable "SN_SKILLSELECTION"] The engine will only use the first slot for a maximum of 32 skills at this time. Adding more data will not be shown to other players.
        local bitfield = skillselection[1]
        for skill, skilldata in pairs(skilldefs) do
            local rpc_id = skilldata.rpc_id
            local rpc_bit = 2 ^ rpc_id
            if bit.band(bitfield, rpc_bit) > 0 then
                activatedskills[skill] = true
            end
        end
    end
    return activatedskills
end

-- NOTES(JBK): Very internal functions below see skilltreeupdater for use of things.

function SkillTreeData:ActivateSkill(skill, characterprefab)
    if not self:IsValidSkill(skill, characterprefab) then
        print("Invalid skilltree skill to ActivateSkill:", characterprefab, skill)
        return false
    end
    local skills = self.activatedskills[characterprefab] or {}
    self.activatedskills[characterprefab] = skills
    if not skills[skill] then
        skills[skill] = true
        self:UpdateSaveState(characterprefab)
        return true, SKILLTREE_DEFS[characterprefab][skill].unlocks
    end
    return false, nil
end

function SkillTreeData:DeactivateSkill(skill, characterprefab)
    if not self:IsValidSkill(skill, characterprefab) then
        print("Invalid skilltree skill to DeactivateSkill:", characterprefab, skill)
        return false
    end
    local skills = self.activatedskills[characterprefab]
    if skills ~= nil and skills[skill] then
        skills[skill] = nil
        if next(skills) == nil then
            self.activatedskills[characterprefab] = nil
        end
        self:UpdateSaveState(characterprefab)
        return true
    end
    return false
end

function SkillTreeData:AddSkillXP(amount, characterprefab)
    local oldskillxp = self:GetSkillXP(characterprefab)
    if self.ignorexp then
        return false, oldskillxp
    end
    local newskillxp = math.clamp(oldskillxp + amount, 0, self:GetMaximumExperiencePoints())

    if newskillxp ~= oldskillxp then
        self.skillxp[characterprefab] = newskillxp
        self:UpdateSaveState(characterprefab)
        return true, newskillxp
    end

    return false, oldskillxp
end

-- NOTES(JBK): RPC handlers should only be used for networkclientrpc things.

function SkillTreeData:GetSkillNameFromID(characterprefab, skill_rpc_id)
    local skillmeta = SKILLTREE_METAINFO[characterprefab] or nil
    local skill = skillmeta and skillmeta.RPC_LOOKUP[skill_rpc_id] or nil
    return skill
end

function SkillTreeData:GetSkillIDFromName(characterprefab, skill)
    local skilldefs = SKILLTREE_DEFS[characterprefab] or nil
    local skill_rpc_id = skilldefs and skilldefs[skill] and skilldefs[skill].rpc_id or nil
    return skill_rpc_id
end

-- NOTES(JBK): These do not have use case out of the data layer they are here in case mods want to make their own handlers. Do not call.

function SkillTreeData:OPAH_DoBackup()
    local characterprefab = ThePlayer.prefab
    self.save_enabled = nil -- We will get a bunch of events from the server do not write to disk every time.
    -- The server is intending to send the client its known state to the local player.
    -- The local player will preserve its skill selection and other data it does not want to get stomped.
    if self.activatedskills_backup == nil and next(self.activatedskills) ~= nil then
        -- We have data on the local client, try to preserve it.
        self.activatedskills_backup = deepcopy(self.activatedskills)
        self.activatedskills = {}
    end

    -- Send off stats to the server it should know of.
    self.ignorexp = true
    local xp = self:GetSkillXP(characterprefab)
    if xp > 0 then
        local skilltreeupdater = ThePlayer.components.skilltreeupdater
        skilltreeupdater:AddSkillXP(xp)
    end
end
function SkillTreeData:OPAH_Ready()
    local characterprefab = ThePlayer.prefab
    -- The server is done sending the client data on the activated skills it knows of.
    -- The local player will first check if the states are identical and if so disregard preservation entirely.
    -- Afterwards the local player will send to the server stats it knows of that the server should also be aware of.
    if self.activatedskills_backup ~= nil then
        if self.activatedskills_backup[characterprefab] == nil or -- No reason to backup.
            self.activatedskills[characterprefab] ~= nil and -- Has a reason to check keys to backup.
            table.keysareidentical(self.activatedskills[characterprefab], self.activatedskills_backup[characterprefab]) -- Keys are identical, no reason to backup.
        then
            -- There is no need to backup this table for this character.
            self.activatedskills = self.activatedskills_backup
            self.activatedskills_backup = nil
        end
    end

    self.save_enabled = true -- Safe to write to disk again.
    self.ignorexp = nil
    local skilltreeupdater = ThePlayer.components.skilltreeupdater
    skilltreeupdater:AddSkillXP(0) -- Update local client to see if it needs to show a notification.
end

function SkillTreeData:DecodeSkillTreeData(data)
    -- "s1,s2,s3,s4,s5|12345"
    local datachunks = string.split(data, "|")
    if datachunks[1] == nil or datachunks[2] == nil then
        -- "" or "|"
        return nil, nil
    end
    local activatedskillsarray = string.split(datachunks[1], ",")
    local activatedskills = {}
    if activatedskillsarray[1] ~= "!" then
        for _, skill in ipairs(activatedskillsarray) do
            activatedskills[skill] = true
        end
    end
    local skillxp = tonumber(datachunks[2])
    return activatedskills, skillxp
end

function SkillTreeData:EncodeSkillTreeData(characterprefab)
    local skillxp_backup = self.skillxp_backup or 0
    local skillxp = self.skillxp[characterprefab]
    if skillxp == nil then
        skillxp = 0
    end
    skillxp = math.max(skillxp, skillxp_backup) -- Do not lose experience.

    local activatedskills = self.activatedskills_backup and self.activatedskills_backup[characterprefab] or self.activatedskills[characterprefab]
    if activatedskills == nil then
        return string.format("!|%d", skillxp)
    end

    if next(activatedskills) == nil then -- Should not happen but just in case.
        return string.format("!|%d", skillxp)
    end

    local activatedskillsarray = {}
    for skill in pairs(activatedskills) do
        table.insert(activatedskillsarray, skill)
    end
    table.sort(activatedskillsarray) -- Make the output consistent between encoding runs.

    return string.format("%s|%d", table.concat(activatedskillsarray, ","), skillxp)
end

function SkillTreeData:Save(force_save, characterprefab)
    --print("[STData] Save")
    if force_save or (self.save_enabled and self.dirty) then
        self.skillxp[characterprefab] = self.skillxp_backup or self.skillxp[characterprefab]
        local str = json.encode({activatedskills = self.activatedskills_backup or self.activatedskills, skillxp = self.skillxp, })
        TheSim:SetPersistentString("skilltree", str, false)
        self.dirty = false
    end
end

function SkillTreeData:Load()
    --print("[STData] Load")
    self.activatedskills = {}
    self.skillxp = {}
    TheSim:GetPersistentString("skilltree", function(load_success, data)
        if load_success and data ~= nil then
            local status, skilltree_data = pcall(function() return json.decode(data) end)
            if status and skilltree_data then
                self.activatedskills = skilltree_data.activatedskills or self.activatedskills
                self.skillxp = skilltree_data.skillxp or self.skillxp
            else
                print("Failed to load the data in skilltree!", status, skilltree_data)
            end
        end
    end)
end

function SkillTreeData:UpdateSaveState(characterprefab)
    self.dirty = true
    if self.save_enabled then
        --print("[STData] UpdateSaveState", characterprefab)
        local def = SKILLTREE_DEFS[characterprefab]
        if def and not def.modded and not TheNet:IsDedicated() and table.contains(DST_CHARACTERLIST, characterprefab) then
            TheInventory:SetSkillTreeValue(characterprefab, self:EncodeSkillTreeData(characterprefab))
        end
        self:Save(true, characterprefab)

        return true
    end
    return false
end

function SkillTreeData:ValidateCharacterData(characterprefab, activatedskills, skillxp)
    local def = SKILLTREE_DEFS[characterprefab]
    if def == nil then
        print("Invalid skilltree characterprefab to ValidateCharacterData:", characterprefab)
        return false
    end

    if activatedskills == nil or skillxp == nil then
        print("Invalid skilltree activatedskills or skillxp data to ValidateCharacterData:", activatedskills, skillxp)
        return false
    end

    local newskillxp = math.clamp(skillxp, 0, self:GetMaximumExperiencePoints())
    if skillxp ~= newskillxp then
        print("Invalid skilltree skillxp to ValidateCharacterData:", characterprefab, skillxp, newskillxp)
        return false
    end

    local maxpointsallocatable = self:GetPointsForSkillXP(skillxp)
    local allocatedskills = #activatedskills
    if allocatedskills > maxpointsallocatable then
        print("Invalid skilltree skills to ValidateCharacterData:", characterprefab, allocatedskills, maxpointsallocatable)
        return false
    end

    -- Quick lookup creation to speed up future checks.
    local skillslookup = {}
    for _, skillname in ipairs(activatedskills) do
        skillslookup[skillname] = true
    end
    for _, skillname in ipairs(activatedskills) do
        local skilldef = def[skillname]
        if skilldef == nil then
            print("Invalid skilltree skillname to ValidateCharacterData:", characterprefab, skillname)
            return false
        end

        local required = skilldef.required
        if required ~= nil then
            for _, musthave in ipairs(required) do
                if not skillslookup[musthave] then
                    print("Invalid skilltree required musthave to ValidateCharacterData:", characterprefab, skillname, musthave)
                    return false
                end
            end
        end

        local exclude = skilldef.exclude
        if exclude ~= nil then
            for _, mustnothave in ipairs(exclude) do
                if skillslookup[mustnothave] then
                    print("Invalid skilltree exclude mustnothave to ValidateCharacterData:", characterprefab, skillname, mustnothave)
                    return false
                end
            end
        end
    end

    return true
end

function SkillTreeData:ApplyCharacterData(characterprefab, skilltreedata)
    --print("[STData] ApplyCharacterData", characterprefab, skilltreedata)
    local activatedskills, skillxp = self:DecodeSkillTreeData(skilltreedata)
    if self:ValidateCharacterData(characterprefab, activatedskills, skillxp) then
        self.skillxp[characterprefab] = skillxp
        self.activatedskills[characterprefab] = activatedskills
        return true
    end
    return false
end

function SkillTreeData:ApplyOnlineProfileData()
    --print("[STData] ApplyOnlineProfileData")
    if not self.synced and
        (TheInventory:HasSupportForOfflineSkins() or not (TheFrontEnd ~= nil and TheFrontEnd:GetIsOfflineMode() or not TheNet:IsOnlineMode())) and
        TheInventory:HasDownloadedInventory() then
        for k, v in pairs(TheInventory:GetLocalSkillTree()) do
            self:ApplyCharacterData(k, v)
        end
        self.synced = true
    end
    return self.synced
end

return SkillTreeData
