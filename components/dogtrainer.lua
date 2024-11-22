local function OnAspects(self, aspects)
    if aspects ~= nil then
        self.aspects_ids = table.invert(aspects)
    end
end

local function OnEnabled(self, enabled)
    self.inst:AddOrRemoveTag("dogtrainer", enabled)
end

------------------------------------------------------------------------------------------------------------------

local DogTrainer = Class(function(self, inst)
    self.inst = inst

    self.enabled = false

    self.badges = {}
    self.aspects = {}
    self.aspectsdata = {}
end,
nil,
{
    enabled = OnEnabled,
    aspects = OnAspects,
})

------------------------------------------------------------------------------------------------------------------

function DogTrainer:Enable(bool)
    self.enabled = bool ~= false
end

function DogTrainer:IsEnabled()
    return self.enabled == true
end

function DogTrainer:SetAspects(aspects)
    assert(type(aspects) == "table")

    self.aspects = aspects
end

function DogTrainer:DoAspectDelta(aspect, delta)
    if self.aspects_ids[aspect] == nil then
        print("DogTrainer::DoAspectDelta - Invalid aspect.")

        return
    end

    if not self.enabled then
        print("DogTrainer::DoAspectDelta - Component not enabled!")

        return
    end

    if self.aspectsdata[aspect] == nil then
        self.aspectsdata[aspect] = {
            percentage = 0,
        }
    end

    self.aspectsdata[aspect].percentage = math.clamp(self.aspectsdata[aspect].percentage + delta, 0, 1)
end

function DogTrainer:DoAspectDeltaIfHasBadge(aspect, delta)
    if self:HasBadgeOfAspect(aspect) then
        self:DoAspectDelta(aspect, delta)
    end
end

function DogTrainer:GetAspectPercent(aspect)
    return self.aspectsdata[aspect] ~= nil and self.aspectsdata[aspect].percentage or 0
end

function DogTrainer:GetBadgesStateBitData(aspect)
    local bitlevels = 0

    for i=1, NUM_WOBY_TRAINING_ASPECTS_LEVELS do
        if self:HasBadge(string.upper(aspect).."_"..i) then
            bitlevels = setbit(bitlevels, 2^(i-1))
        end
    end

    return bitlevels
end

function DogTrainer:ZipAndEncodeData()
    local ret = {}

    local data, n, bitlevels

    for i, aspect in ipairs(self.aspects) do
        data = self.aspectsdata[aspect]

        n = #ret

        ret[n + 1] = self.aspects_ids[aspect] or -1
        ret[n + 2] = data ~= nil and math.floor(data.percentage * 100) or 0
        ret[n + 3] = self:GetBadgesStateBitData(aspect)
    end

    return #ret > 0 and ZipAndEncodeString(ret) or ""
end

------------------------------------------------------------------------------------------------------------------

function DogTrainer:SetBadges(badges)
    self.badges = badges
end

function DogTrainer:DecodeAndValidateBadgesData(data)
    data = string.len(data) > 0 and DecodeAndUnzipString(data) or nil

    local activebadges = {}

    if data == nil or type(data) ~= "table" then
        return activebadges
    end

    local fields = 2 -- Baded on WobyBadgesScreen:XXXXXXXX()
    local slots, max_slots = 0, TUNING.SKILLS.WALTER.WOBY_MAX_BADGES_SLOTS

    local aspect, aspectid, level

    local max_idx = max_slots * fields -- All level 1 badges.

    for i = 1, math.min(max_idx, #data), fields do
        aspectid, level = data[i], data[i + 1]

        if checkuint(aspectid) and checkuint(level) and level >= 1 and level <= NUM_WOBY_TRAINING_ASPECTS_LEVELS then
            aspect = WOBY_TRAINING_ASPECTS_LIST[data[i]]

            if aspect ~= nil and (slots + level) <= max_slots then
                table.insert(activebadges, string.format("%s_%d", string.upper(aspect), level))

                slots = slots + level
            end
        end
    end

    self:SetBadges(activebadges)

    return activebadges
end

function DogTrainer:HasBadge(badge)
    return table.contains(self.badges, badge)
end

function DogTrainer:HasBadgeOfAspect(aspect)
    local badge_fmt = string.upper(aspect).."_%d"

    for i=1, NUM_WOBY_TRAINING_ASPECTS_LEVELS do
        if self:HasBadge(badge_fmt:format(i)) then
            return true
        end
    end

    return false
end

------------------------------------------------------------------------------------------------------------------

function DogTrainer:OnSave()
    local ret = { aspects = {} }

    local bitlevels

    for i, aspect in ipairs(self.aspects) do
        bitlevels = self:GetBadgesStateBitData(aspect)

        ret.aspects[aspect] = {
            aspectdata = self.aspectsdata[aspect] or nil,
            bitlevels  = bitlevels > 0 and bitlevels or nil,
        }

        if not next(ret.aspects[aspect]) then
            ret.aspects[aspect] = nil
        end
    end

    return next(ret.aspects) ~= nil and ret or nil
end

function DogTrainer:OnLoad(data, newents)
    if data == nil then
        return
    end

    local enabled_badges = {}

    if data.aspects ~= nil then
        for aspect, data in pairs(data.aspects) do
            if self.aspects_ids[aspect] ~= nil then
                self.aspectsdata[aspect] = data.aspectdata or self.aspectsdata[aspect]

                if data.bitlevels ~= nil then
                    local badge_fmt = string.upper(aspect).."_%d"

                    for i=1, NUM_WOBY_TRAINING_ASPECTS_LEVELS do
                        if checkbit(data.bitlevels, 2^(i-1)) then
                            table.insert(enabled_badges, badge_fmt:format(i))
                        end
                    end
                end
            end
        end
    end

    if #enabled_badges > 0 then
        self:SetBadges(enabled_badges)
    end
end

------------------------------------------------------------------------------------------------------------------

function DogTrainer:OnRemoveFromEntity()

end

function DogTrainer:GetDebugString()
    local aspects = {}

    for i, aspect in ipairs(self.aspects) do
        table.insert(aspects, string.format("        %s = %.2f", aspect, self:GetAspectPercent(aspect)))
    end

    local str = string.format(
        "\n    Aspects:\n%s\n\n    Badges: [ %s ]",
        table.concat(aspects, "\n"),
        table.concat(self.badges, ", ")
    )

    return str
end

------------------------------------------------------------------------------------------------------------------

return DogTrainer
