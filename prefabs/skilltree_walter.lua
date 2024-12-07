local PADDING = 38

local BADGE_POS_X_LEFT = -217
local BADGE_POS_Y_TOP = 173 - PADDING * 3

local MODS_POS_X_MIDDLE = 57
local MODS_POS_Y_TOP = 173 - PADDING * 1.75

local AMMO_POS_X_LEFT = -217 + PADDING/2
local AMMO_POS_Y_TOP = 183

local AMMO_ECONOMY_POS_X = MODS_POS_X_MIDDLE - PADDING - 5
local AMMO_ECONOMY_POS_Y_TOP = 193

local ALLEGIANCE_LOCK_POS_X = 201
local ALLEGIANCE_SHADOW_POS_X = ALLEGIANCE_LOCK_POS_X - 22
local ALLEGIANCE_LUNAR_POS_X  = ALLEGIANCE_LOCK_POS_X + 25
local ALLEGIANCE_POS_Y_TOP = 183

local POSITIONS =
{
    walter_woby_badge_base = { x = BADGE_POS_X_LEFT + PADDING * 2, y = BADGE_POS_Y_TOP },

    walter_woby_badge_speed_2      = { x = BADGE_POS_X_LEFT + PADDING * 0, y = BADGE_POS_Y_TOP - PADDING },
    walter_woby_badge_resistance_2 = { x = BADGE_POS_X_LEFT + PADDING * 1, y = BADGE_POS_Y_TOP - PADDING },
    walter_woby_badge_bravery_2    = { x = BADGE_POS_X_LEFT + PADDING * 2, y = BADGE_POS_Y_TOP - PADDING },
    walter_woby_badge_digging_2    = { x = BADGE_POS_X_LEFT + PADDING * 3, y = BADGE_POS_Y_TOP - PADDING },
    walter_woby_badge_fetching_2   = { x = BADGE_POS_X_LEFT + PADDING * 4, y = BADGE_POS_Y_TOP - PADDING },

    walter_slingshot_modding          = { x = MODS_POS_X_MIDDLE,           y = MODS_POS_Y_TOP - PADDING * 0     },
    walter_slingshot_band_tentacle    = { x = MODS_POS_X_MIDDLE - PADDING, y = MODS_POS_Y_TOP - PADDING * 1.125 },
    walter_slingshot_handle_sticky    = { x = MODS_POS_X_MIDDLE,           y = MODS_POS_Y_TOP - PADDING * 1.125 },
    walter_slingshot_frame_gems       = { x = MODS_POS_X_MIDDLE + PADDING, y = MODS_POS_Y_TOP - PADDING * 1.125 },
    walter_slingshot_handle_voidcloth = { x = MODS_POS_X_MIDDLE,           y = MODS_POS_Y_TOP - PADDING * 2.25  },
    walter_slingshot_frame_wagpunk    = { x = MODS_POS_X_MIDDLE + PADDING, y = MODS_POS_Y_TOP - PADDING * 2.25  },

    walter_slingshot_ammo_honey        = { x = AMMO_POS_X_LEFT + PADDING * 0.5, y = AMMO_POS_Y_TOP           },
    walter_slingshot_ammo_stinger      = { x = AMMO_POS_X_LEFT + PADDING * 1.5, y = AMMO_POS_Y_TOP           },
    walter_slingshot_ammo_scrapfeather = { x = AMMO_POS_X_LEFT + PADDING * 2.5, y = AMMO_POS_Y_TOP           },
    walter_slingshot_ammo_moonglass    = { x = AMMO_POS_X_LEFT + PADDING * 0.5, y = AMMO_POS_Y_TOP - PADDING },
    walter_slingshot_ammo_gunpowder    = { x = AMMO_POS_X_LEFT + PADDING * 1.5, y = AMMO_POS_Y_TOP - PADDING },
    walter_slingshot_ammo_dreadstone   = { x = AMMO_POS_X_LEFT + PADDING * 2.5, y = AMMO_POS_Y_TOP - PADDING },

    walter_slingshot_ammo_economy_lock = { x = AMMO_ECONOMY_POS_X + PADDING * 0 , y = AMMO_ECONOMY_POS_Y_TOP },
    walter_slingshot_ammo_economy_1    = { x = AMMO_ECONOMY_POS_X + PADDING * 1 , y = AMMO_ECONOMY_POS_Y_TOP },
    walter_slingshot_ammo_economy_2    = { x = AMMO_ECONOMY_POS_X + PADDING * 2 , y = AMMO_ECONOMY_POS_Y_TOP },

    walter_allegiance_shadow_lock_1 = { x = ALLEGIANCE_SHADOW_POS_X, y = ALLEGIANCE_POS_Y_TOP - PADDING * 0.2  },
    walter_allegiance_shadow_lock_2 = { x = ALLEGIANCE_SHADOW_POS_X, y = ALLEGIANCE_POS_Y_TOP - PADDING * 1.55 },
    walter_allegiance_lunar_lock_1  = { x = ALLEGIANCE_LUNAR_POS_X,  y = ALLEGIANCE_POS_Y_TOP - PADDING * 0.2  },
    walter_allegiance_lunar_lock_2  = { x = ALLEGIANCE_LUNAR_POS_X,  y = ALLEGIANCE_POS_Y_TOP - PADDING * 1.55 },

    walter_allegiance_shadow = { x = ALLEGIANCE_SHADOW_POS_X,  y = ALLEGIANCE_POS_Y_TOP - PADDING * 3 },
    walter_allegiance_lunar  = { x = ALLEGIANCE_LUNAR_POS_X,   y = ALLEGIANCE_POS_Y_TOP - PADDING * 3 },
}

--------------------------------------------------------------------------------------------------

local WALTER_SKILL_STRINGS = STRINGS.SKILLTREE.WALTER

--------------------------------------------------------------------------------------------------

-- local function CreateAddTagFn(tag)
--     return function(inst) inst:AddTag(tag) end
-- end

-- local function CreateRemoveTagFn(tag)
--     return function(inst) inst:RemoveTag(tag) end
-- end

-- local function CreateAccomplishmentLockFn(key)
--     return
--         function(prefabname, activatedskills, readonly)
--             return readonly and "question" or TheGenericKV:GetKV(key) == "1"
--         end
-- end

-- local function CreateAccomplishmentCountLockFn(key, value)
--     return
--         function(prefabname, activatedskills, readonly)
--             return readonly and "question" or tonumber(TheGenericKV:GetKV(key) or 0) >= (value or 1)
--         end
-- end

local function CreateSkillTagCountLockFn(tag, count, SkillTreeFns)
    return
        function(prefabname, activatedskills, readonly)
            return readonly and "question" or (SkillTreeFns.CountTags(prefabname, tag, activatedskills) >= count)
        end
end

--------------------------------------------------------------------------------------------------

local BADGE_SKILLNAME_FMT = "walter_woby_badge_%s_%d"

local function CreateWobyBadgeSkill(skills, name)
    for i=2, NUM_WOBY_TRAINING_ASPECTS_LEVELS do
        skills[BADGE_SKILLNAME_FMT:format(name, i)] = {
            group = "wobybadges",

            connects = i < NUM_WOBY_TRAINING_ASPECTS_LEVELS and { BADGE_SKILLNAME_FMT:format(name, i+1) },
        }
    end
end

--------------------------------------------------------------------------------------------------

local BASIC_AMMO_TYPES =
{
    "moonglass",
    "dreadstone",
    "gunpowder",
    "scrapfeather",
    "stinger",
    "honey",
}

local AMMO_SKILLNAME_FMT = "walter_slingshot_ammo_%s"

local function CreateBasicSlingshotAmmoSkill(skills, name)
    skills[AMMO_SKILLNAME_FMT:format(name)] = {
        group = "slingshotammo",
        root = true,

        defaultfocus = name == "stinger",
    }
end

--------------------------------------------------------------------------------------------------

local ONACTIVATE_FNS = {
    PlaceHolderFn = function(inst)
        -- Logic.
    end,

    AllegianceShadow = function(inst)
        inst:AddTag("player_shadow_aligned")

        if inst.components.damagetyperesist ~= nil then
            inst.components.damagetyperesist:AddResist("shadow_aligned", inst, TUNING.SKILLS.WALTER.ALLEGIANCE_SHADOW_RESIST, "allegiance_shadow")
        end

        if inst.components.damagetypebonus ~= nil then
            inst.components.damagetypebonus:AddBonus("lunar_aligned", inst, TUNING.SKILLS.WALTER.ALLEGIANCE_VS_LUNAR_BONUS, "allegiance_shadow")
        end
    end,

    AllegianceLunar = function(inst)
        inst:AddTag("player_lunar_aligned")

        if inst.components.damagetyperesist ~= nil then
            inst.components.damagetyperesist:AddResist("lunar_aligned", inst, TUNING.SKILLS.WALTER.ALLEGIANCE_LUNAR_RESIST, "allegiance_lunar")
        end

        if inst.components.damagetypebonus ~= nil then
            inst.components.damagetypebonus:AddBonus("shadow_aligned", inst, TUNING.SKILLS.WALTER.ALLEGIANCE_VS_SHADOW_BONUS, "allegiance_lunar")
        end
    end,
}

local ONDEACTIVATE_FNS = {
    PlaceHolderFn = function(inst)
        -- Logic.
    end,

    AllegianceShadow = function(inst)
        inst:RemoveTag("player_shadow_aligned")

        if inst.components.damagetyperesist ~= nil then
            inst.components.damagetyperesist:RemoveResist("shadow_aligned", inst, "allegiance_shadow")
        end

        if inst.components.damagetypebonus ~= nil then
            inst.components.damagetypebonus:RemoveBonus("lunar_aligned", inst, "allegiance_shadow")
        end
    end,

    AllegianceLunar = function(inst)
        inst:RemoveTag("player_lunar_aligned")

        if inst.components.damagetyperesist ~= nil then
            inst.components.damagetyperesist:RemoveResist("lunar_aligned", inst, "allegiance_lunar")
        end

        if inst.components.damagetypebonus ~= nil then
            inst.components.damagetypebonus:RemoveBonus("shadow_aligned", inst, "allegiance_lunar")
        end
    end,
}

--------------------------------------------------------------------------------------------------

local ORDERS =
{
    {"wobybadges",     { BADGE_POS_X_LEFT + PADDING * 2, BADGE_POS_Y_TOP + 30      }},
    {"slingshotammo",  { BADGE_POS_X_LEFT + PADDING * 2, AMMO_POS_Y_TOP + 30       }},
    {"slingshotmods",  { MODS_POS_X_MIDDLE,              MODS_POS_Y_TOP + 30       }},
    {"allegiance",     { ALLEGIANCE_LOCK_POS_X,          ALLEGIANCE_POS_Y_TOP + 25 }},
}

--------------------------------------------------------------------------------------------------

local function IncrementNumber(str)
    return tostring(tonumber(str) + 1)
end

local function BuildSkillsData(SkillTreeFns)
    local skills =
    {
        walter_woby_badge_base = {
            group = "slingshotmods",
            root = true,

            connects = {}, -- Connections are added below.
        },

        -----------------------------------------------------------------------------------------------------------------

        walter_slingshot_modding = {
            group = "slingshotmods",
            root = true,

            connects = { "walter_slingshot_band_tentacle", "walter_slingshot_handle_sticky", "walter_slingshot_frame_gems" },
        },

        walter_slingshot_band_tentacle = {
            group = "slingshotmods",
        },

        walter_slingshot_handle_sticky = {
            group = "slingshotmods",

            connects = {"walter_slingshot_handle_voidcloth" },
        },

        walter_slingshot_frame_gems = {
            group = "slingshotmods",

            connects = {"walter_slingshot_frame_wagpunk" },
        },

        walter_slingshot_handle_voidcloth = {
            group = "slingshotmods",
        },

        walter_slingshot_frame_wagpunk = {
            group = "slingshotmods",
        },

        -----------------------------------------------------------------------------------------------------------------

        walter_slingshot_ammo_economy_lock = {
            group = "slingshotammo",
            root = true,

            lock_open = CreateSkillTagCountLockFn("slingshotammo", 4, SkillTreeFns),
        },

        walter_slingshot_ammo_economy_1 = {
            group = "slingshotammo",
            tags = { "slingshoteconomy" },

            locks = { "walter_slingshot_ammo_economy_lock" },
            connects = { "walter_slingshot_ammo_economy_2" },
        },

        walter_slingshot_ammo_economy_2 = {
            group = "slingshotammo",
            tags = { "slingshoteconomy" },
        },

        -----------------------------------------------------------------------------------------------------------------

        walter_allegiance_shadow_lock_1 = SkillTreeFns.MakeFuelWeaverLock(),
        walter_allegiance_shadow_lock_2 = SkillTreeFns.MakeNoLunarLock(),

        walter_allegiance_lunar_lock_1  = SkillTreeFns.MakeCelestialChampionLock(),
        walter_allegiance_lunar_lock_2  = SkillTreeFns.MakeNoShadowLock(),

        walter_allegiance_shadow = {
            group = "allegiance",
            tags = { "slingshotammo", "shadow", "shadow_favor" },

            locks = { "walter_allegiance_shadow_lock_1", "walter_allegiance_shadow_lock_2" },

            onactivate = ONACTIVATE_FNS.AllegianceShadow,
            ondeactivate = ONDEACTIVATE_FNS.AllegianceShadow,
        },

        walter_allegiance_lunar = {
            group = "allegiance",
            tags = { "slingshotammo", "lunar", "lunar_favor" },

            locks = { "walter_allegiance_lunar_lock_1", "walter_allegiance_lunar_lock_2" },

            onactivate = ONACTIVATE_FNS.AllegianceLunar,
            ondeactivate = ONDEACTIVATE_FNS.AllegianceLunar,
        },
    }

    for i, badge in ipairs(WOBY_TRAINING_ASPECTS_LIST) do
        CreateWobyBadgeSkill(skills, badge)

        table.insert(skills.walter_woby_badge_base.connects, BADGE_SKILLNAME_FMT:format(badge, 2))
    end

    for i, type in ipairs(BASIC_AMMO_TYPES) do
        CreateBasicSlingshotAmmoSkill(skills, type)
    end

    for name, data in pairs(skills) do
        local uppercase_name = string.upper(name)

        data.tags = data.tags or {}

        local pos = POSITIONS[name]

        data.pos = pos ~= nil and { pos.x, pos.y } or data.pos

        if not table.contains(data.tags, data.group) then
            table.insert(data.tags, data.group)
        end

        data.desc = data.desc or WALTER_SKILL_STRINGS[uppercase_name.."_DESC"]

        -- If it's not a lock.
        if not data.lock_open then
            data.title = data.title or WALTER_SKILL_STRINGS[uppercase_name.."_TITLE"]
            data.icon = data.icon or name

            -- Auto-connects skills that have the same name-scheme.
            -- local next = string.gsub(name, "(%d)", IncrementNumber)

            -- if next ~= name and not data.connects and skills[next] ~= nil then
            --     data.connects = { next }
            -- end

        elseif not table.contains(data.tags, "lock") then
            table.insert(data.tags, "lock")
        end
    end

    return {
        SKILLS = skills,
        ORDERS = ORDERS,
    }
end

--------------------------------------------------------------------------------------------------

return BuildSkillsData