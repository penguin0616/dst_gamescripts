local SKILLTREE_DEFS = {}
local SKILLTREE_METAINFO = {}

-- A quick exclusion test using counters.
local function ExcludeTest(skills)
    local exclusions = {}
    for name, data in pairs(skills) do
        local exclude = data.exclude
        if exclude ~= nil then
            for _, v in ipairs(exclude) do
                exclusions[name] = (exclusions[name] or 0) + 1
                exclusions[v] = (exclusions[v] or 0) - 1
            end
        end
    end
    for name, count in pairs(exclusions) do
        if count ~= 0 then
            print("SKILLTREE_DEFS exclude found a bad counter", name, count)
            return false
        end
    end
    return true
end

-- A recursive dependency test to stop dependency loops.
local function RequiredTest_Internal(skills, name, data, tested, untested)
    untested[name] = true
    if data.required ~= nil then
        for _, testname in pairs(data.required) do
            if tested[testname] == nil then
                if untested[testname] ~= nil then
                    print("SKILLTREE_DEFS required found a circular dependency between", name, testname)
                    return false
                end
                if not RequiredTest_Internal(skills, testname, skills[testname], tested, untested) then
                    return false
                end
            end
        end
    end
    untested[name] = nil
    tested[name] = true
    return true
end
local function RequiredTest(skills)
    local tested, untested = {}, {}
    for name, data in pairs(skills) do
        if not RequiredTest_Internal(skills, name, data, tested, untested) then
            return false
        end
    end
    return true
end

-- Floating skills test that are ones unable to be unlocked because they are floating outside of any node network.
local function FloatingTest(skills)
    local hasunlock = {}
    for name, data in pairs(skills) do
        if data.root ~= nil then
            hasunlock[name] = true
        end
        local unlocks = data.unlocks
        if unlocks ~= nil then
            for _, v in ipairs(unlocks) do
                hasunlock[v] = true
            end
        end
    end
    for name, data in pairs(skills) do
        if hasunlock[name] == nil then
            print("SKILLTREE_DEFS floating found a skill unable to be gained", name)
            return false
        end
    end
    return true
end

-- Creates a position for each skill in the tree as a suggestion for how it should be laid out from each root node.
local SPACE_X = 10
local SPACE_Y = 10
local function CreateSuggestedLayout_Internal(skills, name, position, debugindent)
    local data = skills[name]
    local unlocks = data.unlocks
    if unlocks ~= nil then
        local unlockscount = #unlocks
        for i = 1, unlockscount do
            local v = unlocks[i]
            data.position = {x = position.x + SPACE_X * (i - 1) - SPACE_X * (unlockscount - 1) * 0.5, y = position.y - SPACE_Y}
            print(string.format(string.format("    %%%dsPos<%%s>: %%.1f %%.1f", debugindent*2), "", v, data.position.x, data.position.y))
            CreateSuggestedLayout_Internal(skills, v, data.position, debugindent + 1)
        end
    end
end
local function CreateSuggestedLayout(skills)
    print("CreateSuggestedLayout")
    local roots = {}
    for name, data in pairs(skills) do
        if data.root ~= nil then
            roots[name] = {x = 0, y = 0,}
        end
    end
    for name, position in pairs(roots) do
        print(string.format("  Root<%s>", name))
        CreateSuggestedLayout_Internal(skills, name, position, 0)
    end
end

-- Wrapper function to help modders with their strange prefab names and tree validation process.
local function CreateSkillTreeFor(characterprefab, skills)
    assert(ExcludeTest(skills), "Bad CreateSkillTreeFor ExcludeTest")
    assert(RequiredTest(skills), "Bad CreateSkillTreeFor RequiredTest")
    --assert(FloatingTest(skills), "Bad CreateSkillTreeFor FloatingTest")

    --CreateSuggestedLayout(skills)

    local RPC_LOOKUP = {}
    local rpc_id = 0
    for k, v in orderedPairs(skills) do
        v.rpc_id = rpc_id
        RPC_LOOKUP[rpc_id] = k
        rpc_id = rpc_id + 1
        -- NOTES(JBK): If this goes beyond 32 it will not be shown to other players in the inspection panel.
    end
    SKILLTREE_DEFS[characterprefab] = skills
    SKILLTREE_METAINFO[characterprefab] = {
        RPC_LOOKUP = RPC_LOOKUP,
        TOTAL_SKILLS_COUNT = rpc_id,
    }
end

local function CountTags(prefab, targettag)
    local tags = {}
    if TheSkillTree.activatedskills[prefab] then
        for skill, flag in pairs(TheSkillTree.activatedskills[prefab]) do
            local data =  SKILLTREE_DEFS[prefab][skill]
            for i,tag in ipairs(data.tags) do
                if not tags[tag] then
                    tags[tag] = 0
                end
                tags[tag] = tags[tag] +1
            end
        end
    end
    return tags[targettag] or 0
end

local function CountSkills(prefab)
    local count = 0
    if TheSkillTree.activatedskills[prefab] then
        for skill, flag in pairs(TheSkillTree.activatedskills[prefab]) do
            count = count + 1
        end
    end
    return count or 0
end

local FN = {
    CountSkills = CountSkills,
    CountTags = CountTags,
}

CreateSkillTreeFor("wilson", {
    wilson_alchemy_1 = {
        title = STRINGS.SKILLTREE.WILSON.WILSON_ALCHEMY_1_TITLE,
        desc = STRINGS.SKILLTREE.WILSON.WILSON_ALCHEMY_1_DESC,
        icon = "wilson_alchemy_1",
        pos = {-62,176},
        --pos = {1,0},
        group = "alchemy",
        tags = {"alchemy"},
        onactivate = function(inst, fromload)
                inst:AddTag("alchemist")
            end,
        root = true,
        connects = {
            "wilson_alchemy_2",
            "wilson_alchemy_3",
            "wilson_alchemy_4",
        },
    },
    wilson_alchemy_2 = {
        title = STRINGS.SKILLTREE.WILSON.WILSON_ALCHEMY_2_TITLE,
        desc = STRINGS.SKILLTREE.WILSON.WILSON_ALCHEMY_2_DESC,
        icon = "wilson_alchemy_gem_1",
        pos = {-62,176-54},        
        --pos = {0,-1},
        group = "alchemy",
        tags = {"alchemy"},
        onactivate = function(inst, fromload)
                inst:AddTag("gem_alchemistI")
            end,        
        connects = {
            "wilson_alchemy_5",
        },
    },
    wilson_alchemy_5 = {
        title = STRINGS.SKILLTREE.WILSON.WILSON_ALCHEMY_5_TITLE,
        desc = STRINGS.SKILLTREE.WILSON.WILSON_ALCHEMY_5_DESC,
        icon = "wilson_alchemy_gem_2",
        pos = {-62,176-54-38},        
        --pos = {0,-2},
        group = "alchemy",
        tags = {"alchemy"},
        onactivate = function(inst, fromload)
                inst:AddTag("gem_alchemistII")
            end,
        connects = {
            "wilson_alchemy_6",
        },
    },
    wilson_alchemy_6 = {
        title = STRINGS.SKILLTREE.WILSON.WILSON_ALCHEMY_6_TITLE,
        desc = STRINGS.SKILLTREE.WILSON.WILSON_ALCHEMY_6_DESC,
        icon = "wilson_alchemy_gem_3",
        pos = {-62,176-54-38-38},        
        --pos = {0,-3},
        group = "alchemy",
        tags = {"alchemy"},
        onactivate = function(inst, fromload)
                inst:AddTag("gem_alchemistIII")
            end,
        connects = {
        },
    },

    wilson_alchemy_3 = {
        title = STRINGS.SKILLTREE.WILSON.WILSON_ALCHEMY_3_TITLE,
        desc = STRINGS.SKILLTREE.WILSON.WILSON_ALCHEMY_3_DESC,
        icon = "wilson_alchemy_ore_1",
        pos = {-62-38,176-54},
        --pos = {1,-1},
        group = "alchemy",
        tags = {"alchemy"},
        onactivate = function(inst, fromload)
                inst:AddTag("ore_alchemistI")
            end,
        connects = {
            "wilson_alchemy_7",
        },
    },
    wilson_alchemy_7 = {
        title = STRINGS.SKILLTREE.WILSON.WILSON_ALCHEMY_7_TITLE,
        desc = STRINGS.SKILLTREE.WILSON.WILSON_ALCHEMY_7_DESC,
        icon = "wilson_alchemy_ore_2",
        pos = {-62-38,176-54-38},
        --pos = {1,-2},
        group = "alchemy",
        tags = {"alchemy"},
        onactivate = function(inst, fromload)
                inst:AddTag("ore_alchemistII")
            end,        
        connects = {
            "wilson_alchemy_8",
        },
    },
    wilson_alchemy_8 = {
        title = STRINGS.SKILLTREE.WILSON.WILSON_ALCHEMY_8_TITLE,
        desc = STRINGS.SKILLTREE.WILSON.WILSON_ALCHEMY_8_DESC,
        icon = "wilson_alchemy_ore_3",
        pos = {-62-38,176-54-38-38},
        --pos = {1,-3},
        group = "alchemy",
        tags = {"alchemy"},
        onactivate = function(inst, fromload)
                inst:AddTag("ore_alchemistIII")
            end,         
        connects = {
        },
    },

    wilson_alchemy_4 = {
        title = STRINGS.SKILLTREE.WILSON.WILSON_ALCHEMY_4_TITLE,
        desc = STRINGS.SKILLTREE.WILSON.WILSON_ALCHEMY_4_DESC,
        icon = "wilson_alchemy_iky_1",
        pos = {-62+38,176-54},
        --pos = {2,-1},
        group = "alchemy",
        tags = {"alchemy"},
        onactivate = function(inst, fromload)
                inst:AddTag("ick_alchemistI")
            end,         
        connects = {
            "wilson_alchemy_9",
        },
    },
    wilson_alchemy_9 = {
        title = STRINGS.SKILLTREE.WILSON.WILSON_ALCHEMY_9_TITLE,
        desc = STRINGS.SKILLTREE.WILSON.WILSON_ALCHEMY_9_DESC,
        icon = "wilson_alchemy_iky_2",
        pos = {-62+38,176-54-38},
        --pos = {2,-2},
        group = "alchemy",
        tags = {"alchemy"},
        onactivate = function(inst, fromload)
                inst:AddTag("ick_alchemistII")
            end,        
        connects = {
            "wilson_alchemy_10",
        },
    },
    wilson_alchemy_10 = {
        title = STRINGS.SKILLTREE.WILSON.WILSON_ALCHEMY_10_TITLE,
        desc = STRINGS.SKILLTREE.WILSON.WILSON_ALCHEMY_10_DESC,
        icon = "wilson_alchemy_iky_3",
        pos = {-62+38,176-54-38-38},
        --pos = {2,-3},
        group = "alchemy",
        tags = {"alchemy"},
        onactivate = function(inst, fromload)
                inst:AddTag("ick_alchemistIII")
            end,        
        connects = {
        },
    },

    wilson_torch_1 = {
        title = STRINGS.SKILLTREE.WILSON.WILSON_TORCH_1_TITLE,
        desc = STRINGS.SKILLTREE.WILSON.WILSON_TORCH_1_DESC,
        icon = "wilson_torch_time_1",
        pos = {-214,176},
        --pos = {0,0},
        group = "torch",
        tags = {"torch"},
        onactivate = function(inst, fromload)
                if not fromload then
                    local equipped = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
                    if equipped and equipped.applyskilleffect then
                        equipped:applyskilleffect("wilson_torch_1", inst)
                    end
                end
            end,
        root = true,
        connects = {
            "wilson_torch_2",
        },
    },
    wilson_torch_2 = {
        title = STRINGS.SKILLTREE.WILSON.WILSON_TORCH_2_TITLE,
        desc = STRINGS.SKILLTREE.WILSON.WILSON_TORCH_2_DESC,
        icon = "wilson_torch_time_2",
        pos = {-214,176-38},
        --pos = {0,-1},
        group = "torch",
        tags = {"torch"},
        onactivate = function(inst, fromload)
                if not fromload then
                    local equipped = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
                    if equipped and equipped.applyskilleffect then
                        equipped:applyskilleffect("wilson_torch_2", inst)
                    end
                end
            end,        
        connects = {
            "wilson_torch_3",
        },
    },
    wilson_torch_3 = {
        title = STRINGS.SKILLTREE.WILSON.WILSON_TORCH_3_TITLE,
        desc = STRINGS.SKILLTREE.WILSON.WILSON_TORCH_3_DESC,
        icon = "wilson_torch_time_3",
        pos = {-214,176-38-38},
        --pos = {0,-2},
        group = "torch",
        tags = {"torch"},
        onactivate = function(inst, fromload) 
                if not fromload then
                    local equipped = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
                    if equipped and equipped.applyskilleffect then
                        equipped:applyskilleffect("wilson_torch_3", inst)
                    end
                end
            end,
        connects = {
        },
    },
    wilson_torch_4 = {
        title = STRINGS.SKILLTREE.WILSON.WILSON_TORCH_4_TITLE,
        desc = STRINGS.SKILLTREE.WILSON.WILSON_TORCH_4_DESC,
        icon = "wilson_torch_brightness_1",
        pos = {-214+38,176},        
        --pos = {1,0},
        group = "torch",
        tags = {"torch"},
        onactivate = function(inst, fromload)
                if not fromload then
                    local equipped = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
                    if equipped and equipped.applyskilleffect then
                        equipped:applyskilleffect("wilson_torch_4", inst)
                    end
                end
            end,        
        root = true,
        connects = {
            "wilson_torch_5",
        },
    },
    wilson_torch_5 = {
        title = STRINGS.SKILLTREE.WILSON.WILSON_TORCH_5_TITLE,
        desc = STRINGS.SKILLTREE.WILSON.WILSON_TORCH_5_DESC,
        icon = "wilson_torch_brightness_2",
        pos = {-214+38,176-38},
        --pos = {1,-1},
        group = "torch",
        tags = {"torch"},
        onactivate = function(inst, fromload)
                if not fromload then
                    local equipped = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
                    if equipped and equipped.applyskilleffect then
                        equipped:applyskilleffect("wilson_torch_5", inst)
                    end
                end
            end,        
        connects = {
            "wilson_torch_6",
        },
    },
    wilson_torch_6 = {
        title = STRINGS.SKILLTREE.WILSON.WILSON_TORCH_6_TITLE,
        desc = STRINGS.SKILLTREE.WILSON.WILSON_TORCH_6_DESC,
        icon = "wilson_torch_brightness_3",
        pos = {-214+38,176-38-38},
        --pos = {1,-2},
        group = "torch",
        tags = {"torch"},
        onactivate = function(inst, fromload)
                if not fromload then
                    local equipped = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
                    if equipped and equipped.applyskilleffect then
                        equipped:applyskilleffect("wilson_torch_5", inst)
                    end
                end
            end,        
        connects = {
        },
    }, 

    wilson_torch_lock_1 = {
        desc = STRINGS.SKILLTREE.WILSON.WILSON_TORCH_1_LOCK_DESC,
        pos = {-214+18,58},
        --pos = {2,0},
        group = "torch",
        tags = {"torch","lock"},
        root = true,
        lock_open = function(prefabname) return CountTags(prefabname,"torch") > 2 end,
        connects = {
            "wilson_torch_7",
        },
    },
    wilson_torch_7 = {
        title = STRINGS.SKILLTREE.WILSON.WILSON_TORCH_7_TITLE,
        desc = STRINGS.SKILLTREE.WILSON.WILSON_TORCH_7_DESC,
        icon = "wilson_torch_throw",
        pos = {-214+18,58-38},        
        --pos = {2,-1},
        group = "torch",
        tags = {"torch"},
        connects = {
        },
    },    

    wilson_beard_1 = {
        title = STRINGS.SKILLTREE.WILSON.WILSON_BEARD_1_TITLE,
        desc = STRINGS.SKILLTREE.WILSON.WILSON_BEARD_1_DESC,
        icon = "wilson_beard_insulation_1",        
        pos = {66,176},
        --pos = {0,0},
        group = "beard",
        tags = {"beard"},
        root = true,
        connects = {
            "wilson_beard_2",
        },
    },
    wilson_beard_2 = {
        title = STRINGS.SKILLTREE.WILSON.WILSON_BEARD_2_TITLE,
        desc = STRINGS.SKILLTREE.WILSON.WILSON_BEARD_2_DESC,
        icon = "wilson_beard_insulation_2",
        pos = {66,176-38},
        --pos = {0,-1},
        group = "beard",
        tags = {"beard"},
        connects = {
            "wilson_beard_3",
        },
    },
    wilson_beard_3 = {
        title = STRINGS.SKILLTREE.WILSON.WILSON_BEARD_3_TITLE,
        desc = STRINGS.SKILLTREE.WILSON.WILSON_BEARD_3_DESC,
        icon = "wilson_beard_insulation_3",
        pos = {66,176-38-38},
        --pos = {0,-2},
        group = "beard",
        tags = {"beard"},
        connects = {
        },
    },

    wilson_beard_4 = {
        title = STRINGS.SKILLTREE.WILSON.WILSON_BEARD_4_TITLE,
        desc = STRINGS.SKILLTREE.WILSON.WILSON_BEARD_4_DESC,
        icon = "wilson_beard_speed_1",
        pos = {66+38,176},
        --pos = {1,0},
        group = "beard",
        tags = {"beard"},
        onactivate = function(inst, fromload)
                if not inst.components.skilltreeupdater:IsActivated("wilson_beard_5") and not inst.components.skilltreeupdater:IsActivated("wilson_beard_6") then
                    inst:skills_upgradebeardspeed()
                end
            end,
        root = true,
        connects = {
            "wilson_beard_5",
        },
    },
    wilson_beard_5 = {
        title = STRINGS.SKILLTREE.WILSON.WILSON_BEARD_5_TITLE,
        desc = STRINGS.SKILLTREE.WILSON.WILSON_BEARD_5_DESC,
        icon = "wilson_beard_speed_2",
        pos = {66+38,176-38},
        --pos = {1,-1},
        group = "beard",
        tags = {"beard"},
        onactivate = function(inst, fromload)
                if not inst.components.skilltreeupdater:IsActivated("wilson_beard_6") then
                    inst:skills_upgradebeardspeed()
                end
            end,
        connects = {
            "wilson_beard_6",
        },
    },
    wilson_beard_6 = {
        title = STRINGS.SKILLTREE.WILSON.WILSON_BEARD_6_TITLE,
        desc = STRINGS.SKILLTREE.WILSON.WILSON_BEARD_6_DESC,
        icon = "wilson_beard_speed_3",
        pos = {66+38,176-38-38},
        --pos = {1,-2},
        group = "beard",
        tags = {"beard"},
        onactivate = function(inst, fromload)
                inst:skills_upgradebeardspeed()
            end,
        connects = {
        },
    },

    wilson_beard_lock_1 = {
        desc = STRINGS.SKILLTREE.WILSON.WILSON_BEARD_1_LOCK_DESC,
        pos = {66+18,58},
        --pos = {2,0},
        group = "beard",
        tags = {"beard","lock"},
        root = true,
        lock_open = function(prefabname) return CountTags(prefabname,"beard") > 2 end,
        connects = {
            "wilson_beard_7",
        },
    },
    wilson_beard_7 = {
        title = STRINGS.SKILLTREE.WILSON.WILSON_BEARD_7_TITLE,
        desc = STRINGS.SKILLTREE.WILSON.WILSON_BEARD_7_DESC,
        icon = "wilson_beard_inventory",
        pos = {66+18,58-38},
        --pos = {2,-1},
        onactivate = function(inst, fromload)
                if inst.components.beard then
                    inst.components.beard:UpdateBeardInventory()
                end
            end,
        group = "beard",
        tags = {"beard"},
        connects = {
        },
    },

    wilson_allegiance_lock_1 = {
        desc = STRINGS.SKILLTREE.WILSON.WILSON_ALLEGIANCE_LOCK_1_DESC,
        pos = {204,176},
        --pos = {0.5,0},
        group = "allegiance",
        tags = {"allegiance","lock"},
        root = true,
        lock_open = function(prefabname) return CountSkills(prefabname) >= 12 end,
        connects = {
            "wilson_allegiance_shadow",
        },
    },

    wilson_allegiance_lock_2 = {
        desc = STRINGS.SKILLTREE.WILSON.WILSON_ALLEGIANCE_LOCK_2_DESC,
        pos = {204,176-50},  -- -22
        --pos = {0,-1},
        group = "allegiance",
        tags = {"allegiance","lock"},
        root = true,
        lock_open = function(inst) 
                local kv = TheInventory:GetLocalGenericKV()
                return kv.fuelweaver_killed == "1" 
            end,
        connects = {
            "wilson_allegiance_shadow",
        },
    },

    wilson_allegiance_shadow = {
        title = STRINGS.SKILLTREE.WILSON.WILSON_ALLEGIANCE_SHADOW_TITLE,
        desc = STRINGS.SKILLTREE.WILSON.WILSON_ALLEGIANCE_SHADOW_DESC,
        icon = "wilson_favor_shadow",
        pos = {204 ,176-60-38},  --  -22
        --pos = {0,-2},
        group = "allegiance",
        tags = {"allegiance","shadow"},
        locks = {"wilson_allegiance_lock_1", "wilson_allegiance_lock_2"},
        onactivate = function(inst, fromload)
                inst:AddTag("skill_wilson_allegiance_shadow")
            end,        
        connects = {
        },
    },  

})


setmetatable(SKILLTREE_DEFS, {
    __newindex = function(t, k, v)
        v.modded = true
        rawset(t, k, v)
    end,
})

local SKILLTREE_ORDERS = {
    wilson = {
            {"torch",           { -214+18   , 176 + 30 }},
            {"alchemy",         { -62       , 176 + 30 }},
            {"beard",           { 66+18     , 176 + 30 }},
            {"allegiance",      { 204       , 176 + 30 }},
          },
}

return {SKILLTREE_DEFS = SKILLTREE_DEFS, SKILLTREE_METAINFO = SKILLTREE_METAINFO, CreateSkillTreeFor = CreateSkillTreeFor, SKILLTREE_ORDERS = SKILLTREE_ORDERS, FN = FN}
