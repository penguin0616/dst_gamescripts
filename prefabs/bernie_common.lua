local fn = {}
fn.isleadercrazy = function(inst,leader)

    if ( leader.components.sanity:IsCrazy() or
        (leader.components.sanity:GetPercent() < TUNING.SKILLS.WILLOW_BERNIESANITY_1 and leader.components.skilltreeupdater:IsActivated("willow_berniesanity_1") ) or 
        (leader.components.sanity:GetPercent() < TUNING.SKILLS.WILLOW_BERNIESANITY_2 and leader.components.skilltreeupdater:IsActivated("willow_berniesanity_2") ) ) then
        return true
    end

end

return fn