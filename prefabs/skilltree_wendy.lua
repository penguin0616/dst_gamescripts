local WENDY_SKILL_STRINGS = STRINGS.SKILLTREE.WENDY

-- Positions
local TILEGAP = 38
local TILE = 50
local POS_X_1 = -245 -- -211
local POS_Y_1 = 172

local X = -298
local Y = 288

local width = 255+249-50
local height = 142+10

local CURVE_BASE_H = 75
local A_BASE_H = -10 +TILE

local COL1= POS_X_1+math.floor(width/11)
local COL2= POS_X_1+math.floor(width/11) *2
local COL3= POS_X_1+math.floor(width/11) *3
local COL4= POS_X_1+math.floor(width/11) *4
local COL5= POS_X_1+math.floor(width/11) *5

local COL6= POS_X_1+math.floor(width/11) *7
local COL7= POS_X_1+math.floor(width/11) *8
local COL8= POS_X_1+math.floor(width/11) *9
local COL9= POS_X_1+math.floor(width/11) *10
local COL10= POS_X_1+math.floor(width/11) *11

local CURV1 = CURVE_BASE_H + 0
local CURV2 = CURVE_BASE_H + math.floor(TILE/1.5)
local CURV3 = CURVE_BASE_H + math.floor(TILE/1.5+TILE/3)
local CURV4 = CURVE_BASE_H + math.floor(TILE/1.5+TILE/3+TILE/4)
local CURV5 = CURVE_BASE_H + math.floor(TILE/1.5+TILE/3+TILE/4+TILE/5)

--

local function BuildSkillsData(SkillTreeFns)
    local skills = {}
    local function finalize_skill_group(skill_subset, group_name)
        for skill_name, skill_data in pairs(skill_subset) do
            local skill_name_upper = string.upper(skill_name)
            skill_data.group = group_name
            table.insert(skill_data.tags, group_name)

            skill_data.desc = skill_data.desc or WENDY_SKILL_STRINGS[skill_name_upper.."_DESC"]
            if not skill_data.lock_open then
                skill_data.title = skill_data.title or WENDY_SKILL_STRINGS[skill_name_upper.."_TITLE"]
                skill_data.icon = skill_data.icon or skill_name
            end

            skills[skill_name] = skill_data
        end
    end

    local sisturn_skills =
    {
        wendy_sisturn_1 = {
            pos = {COL1+1, CURV1 + TILEGAP-5},
            tags = {"sisturn"},
            root = true,
            connects = {
                "wendy_sisturn_2",
            },
        },
        wendy_sisturn_2 = {
            pos = {COL2, CURV2+ TILEGAP -8},
            tags = {"sisturn"},
            onactivate   = function(inst, fromload)
               inst.components.sanityauraadjuster:StartTask()
            end,
            ondeactivate = function(inst, fromload)
                inst.components.sanityauraadjuster:StopTask()
            end,
            connects = {
                "wendy_sisturn_3",
            },
        },

        wendy_sisturn_3 = {
            pos = {COL3, CURV3+ TILEGAP},
            tags = {"sisturn"},
            onactivate   = function(inst, fromload)
                inst:AddTag("can_set_babysitter")
            end,
            ondeactivate = function(inst, fromload)
                inst:RemoveTag("can_set_babysitter")
                inst.components.ghostlybond.ghost:PushEven("set_babysitter",nil)
            end,
        },
    }
    finalize_skill_group(sisturn_skills, "sisturn_upgrades")

    local potion_skills =
    {
        wendy_potion_1 = {
            pos = {COL1+30, CURV1-14},
            tags = {"potion"},
            root = true,
            connects = {
                "wendy_potion_2",
            },
        },
        wendy_potion_2 = {
            pos = {X+ 152,Y-192},
            tags = {"potion"},
            connects = {
                "wendy_potion_3",
            },
        },
        wendy_potion_3 = {
            pos =  {X+ 190, Y-171},
            tags = {"potion"},
        },
    }
    finalize_skill_group(potion_skills, "potion_upgrades")

    local petal_skills =
    {
        wendy_petal_1 = {
            pos = {COL4, CURV4 +TILEGAP+1},
            tags = {},
            connects = {
                "wendy_petal_2",
            },

            root = true,
            defaultfocus = true,
        },
        wendy_petal_2 = {
            pos = {COL5, CURV5+TILEGAP},
            tags = {},            
        },
    }
    finalize_skill_group(petal_skills, "petal")

    local avenging_ghost_skills =
    {
        wendy_avenging_ghost = {
            pos = {COL4 +(TILEGAP/2)+5, CURV4 },            
            tags = {},
            root = true,
        },
    }
    finalize_skill_group(avenging_ghost_skills, "avengingghost")


    local smallghost_skills =
    {
        wendy_smallghost_1 = {
            pos = {COL6, CURV5+TILEGAP},
            tags = {},
            root=true,
            connects = {
                "wendy_smallghost_2",
            },
        },
        wendy_smallghost_2 = {
            pos = {X+392,Y-115},
            tags = {},
            connects = {
                "wendy_smallghost_3",
            },
        },
        wendy_smallghost_3 = {
            pos = {X+439,Y-140},
            tags = {},
        },
    }
    finalize_skill_group(smallghost_skills, "smallghost")

    local gravestone_skills =
    {
        wendy_gravestone_1 = {
            pos = {COL6, CURV5},
            tags = {},
            root=true,

            onactivate = function(inst, fromload)
                inst:AddTag(UPGRADETYPES.GRAVESTONE.."_upgradeuser")
            end,

            ondeactivate = function(inst, fromload)
                inst:RemoveTag(UPGRADETYPES.GRAVESTONE.."_upgradeuser")
            end,

            connects = {
                "wendy_gravestone_2",
            },
        },
        wendy_gravestone_2 = {
            pos = {X+388,Y-161},
            tags = {},

            onactivate = function(inst, fromload)
                inst:AddTag("gravedigger_user")
            end,

            ondeactivate = function(inst, fromload)
                inst:RemoveTag("gravedigger_user")
            end,

            connects = {
                "wendy_makegravemounds",
            },
        },
        wendy_makegravemounds = {
            pos = {X+430,Y-189},
            tags = {},
        },
    }
    finalize_skill_group(gravestone_skills, "gravestone")

    local ghost_command_skills =
    {
        wendy_ghostcommand_1 = {
            pos = {X+482,Y-175},
            tags = {},
            connects = {
                "wendy_ghostcommand_2",
            },

            root = true,
        },
        wendy_ghostcommand_2 = {
            pos = {X+495,Y-215},
            tags = {},
            connects = {
                "wendy_ghostcommand_3",
            },
        },
        wendy_ghostcommand_3 = {
            pos = {X+455,Y-237},
            tags = {},
        },
    }
    finalize_skill_group(ghost_command_skills, "ghost_command")

    local allegiance_skills =
    {

        wendy_shadow_lock_1 = SkillTreeFns.MakeFuelWeaverLock({ pos = {COL3+TILEGAP/2 +21, A_BASE_H} }),
        wendy_shadow_lock_2 = SkillTreeFns.MakeNoLunarLock({ pos = {COL4+TILEGAP/2 +18, A_BASE_H} }),

        wendy_shadow_1 = {
            pos = {COL5+TILEGAP/2 +21, A_BASE_H },
            tags = {"allegiance","shadow","shadow_favor"},
            connects = {
                "wendy_shadow_2",
            },

            locks = {"wendy_shadow_lock_1", "wendy_shadow_lock_2"},

            onactivate = function(inst, fromload)
                inst:AddTag("player_shadow_aligned")

                local addresists = function(pref)
                    local damagetyperesist = pref.components.damagetyperesist
                    if damagetyperesist then
                        damagetyperesist:AddResist("shadow_aligned", pref, TUNING.SKILLS.WENDY.ALLEGIANCE_SHADOW_RESIST, "allegiance_shadow")
                    end
                    local damagetypebonus = pref.components.damagetypebonus
                    if damagetypebonus then
                        damagetypebonus:AddBonus("lunar_aligned", pref, TUNING.SKILLS.WENDY.ALLEGIANCE_VS_LUNAR_BONUS, "allegiance_shadow")
                    end
                end

                addresists(inst)
                if inst.components.ghostlybond and inst.components.ghostlybond.ghost then
                    inst.components.ghostlybond.ghost:AddTag("shadow_aligned")
                    addresists(inst.components.ghostlybond.ghost)
                    inst.components.ghostlybond.ghost.components.planardefense:SetBaseDefense(TUNING.SKILLS.WENDY.GHOST_PLANARDEFENSE)
                end
            end,

            ondeactivate = function(inst, fromload)
                inst:RemoveTag("player_shadow_aligned")

                local removeresist = function(pref)
                    local damagetyperesist = pref.components.damagetyperesist
                    if damagetyperesist then
                        damagetyperesist:RemoveResist("shadow_aligned", pref, "allegiance_shadow")
                    end
                    local damagetypebonus = pref.components.damagetypebonus
                    if damagetypebonus then
                        damagetypebonus:RemoveBonus("lunar_aligned", pref, "allegiance_shadow")
                    end
                end
                removeresist(inst)
                if inst.components.ghostlybond and inst.components.ghostlybond.ghost then
                    inst.components.ghostlybond.ghost:RemoveTag("shadow_aligned")
                    removeresist(inst.components.ghostlybond.ghost)
                    inst.components.ghostlybond.ghost.components.planardefense:SetBaseDefense(0)
                end
            end,

        },
        wendy_shadow_2 = {
            pos = {COL5+(width/11)+TILEGAP/2 +21, A_BASE_H},
            tags = {"allegiance","shadow","shadow_favor"},
            connects = {
                "wendy_shadow_3",
            },
            onactivate = function(inst, fromload)
                inst:AddTag("wendy_shadow_craft")
            end,
            ondeactivate = function(inst, fromload)
                inst:RemoveTag("wendy_shadow_craft")
            end,
        },
        wendy_shadow_3 = {
            pos = {COL6+TILEGAP/2 +21, A_BASE_H},
            tags = {"allegiance","shadow","shadow_favor"},
        },

        wendy_lunar_lock_1 = SkillTreeFns.MakeCelestialChampionLock({ pos = {COL3+TILEGAP/2 +21,A_BASE_H+TILEGAP}}),
        wendy_lunar_lock_2 = SkillTreeFns.MakeNoShadowLock({ pos = {COL4+TILEGAP/2 +18, A_BASE_H+TILEGAP}}), 

        wendy_lunar_1 = {
            pos = {COL5+TILEGAP/2 +21, A_BASE_H+TILEGAP },
            tags = {"allegiance","lunar","lunar_favor"},
            connects = {
                "wendy_lunar_2",
            },

            locks = {"wendy_lunar_lock_1", "wendy_lunar_lock_2"},

            onactivate = function(inst, fromload)
                inst:AddTag("player_lunar_aligned")

                local addresists = function(pref)
                    local damagetyperesist = pref.components.damagetyperesist
                    if damagetyperesist then
                        damagetyperesist:AddResist("lunar_aligned", pref, TUNING.SKILLS.WENDY.ALLEGIANCE_LUNAR_RESIST, "allegiance_lunar")
                    end
                    local damagetypebonus = pref.components.damagetypebonus
                    if damagetypebonus then
                        damagetypebonus:AddBonus("shadow_aligned", pref, TUNING.SKILLS.WENDY.ALLEGIANCE_VS_SHADOW_BONUS, "allegiance_lunar")
                    end
                end

                addresists(inst)
                if inst.components.ghostlybond and inst.components.ghostlybond.ghost then
                    inst.components.ghostlybond.ghost:AddTag("lunar_aligned")
                    addresists(inst.components.ghostlybond.ghost)
                    inst.components.ghostlybond.ghost.components.planardefense:SetBaseDefense(TUNING.SKILLS.WENDY.GHOST_PLANARDEFENSE)
                end
            end,

            ondeactivate = function(inst, fromload)
                inst:RemoveTag("player_lunar_aligned")

                local removeresist = function(pref)
                    local damagetyperesist = pref.components.damagetyperesist
                    if damagetyperesist then
                        damagetyperesist:RemoveResist("lunar_aligned", pref, "allegiance_lunar")
                    end
                    local damagetypebonus = pref.components.damagetypebonus
                    if damagetypebonus then
                        damagetypebonus:RemoveBonus("shadow_aligned", pref, "allegiance_lunar")
                    end
                end
                removeresist(inst)
                if inst.components.ghostlybond and inst.components.ghostlybond.ghost then
                    inst.components.ghostlybond.ghost:RemoveTag("lunar_aligned")
                    removeresist(inst.components.ghostlybond.ghost)
                    inst.components.ghostlybond.ghost.components.planardefense:SetBaseDefense(0)
                end
            end,

        },
        wendy_lunar_2 = {
            pos = {COL5+(width/11)+TILEGAP/2 +21, A_BASE_H+TILEGAP},
            tags = {"allegiance","lunar","lunar_favor"},
            connects = {
                "wendy_lunar_3",
            },
            onactivate = function(inst, fromload)
                inst:AddTag("wendy_lunar_craft")
            end,
            ondeactivate = function(inst, fromload)
                inst:RemoveTag("wendy_lunar_craft")
            end,
        },
        wendy_lunar_3 = {
            pos = {COL6+TILEGAP/2 +21, A_BASE_H+TILEGAP},
            tags = {"allegiance","lunar","lunar_favor"},
        }, 

    }
    finalize_skill_group(allegiance_skills, "wendy_alliegience") --allegiance


    return {
        SKILLS = skills,
        ORDERS = {
         --   {"petal",               {POS_X_1, POS_Y_1 + TILEGAP}},
         --   {"ghost_command",       {POS_X_1 + TILEGAP * 2, POS_Y_1 + TILEGAP}  },
         --   {"sisturn_upgrades",    {POS_X_1 + TILEGAP, POS_Y_1 + TILEGAP}      },
          --  {"smallghost",          {POS_X_1 + TILEGAP * 3, POS_Y_1 + TILEGAP}  },
          --  {"gravestone",          {POS_X_1 + TILEGAP * 4, POS_Y_1 + TILEGAP}  },
          --  {"potion_upgrades",     {POS_X_1 + TILEGAP * 5, POS_Y_1 + TILEGAP}  },
          --  {"allegiance",          {COL5+(width/11), (TILEGAP*2.8) }           },
        },
    }
end

return BuildSkillsData