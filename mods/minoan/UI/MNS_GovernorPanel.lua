-- Keep the native governor UI, filtering only Minos' replaced candidates.
include('GovernorPanel')
local baseCandidate = AddGovernorCandidate
local function replaced(def)
    local config = PlayerConfigurations[Game.GetLocalPlayer()]
    return config and config:GetLeaderTypeName() == 'LEADER_MNS_MINOS'
        and GameInfo.MNS_GovernorReplacements
        and GameInfo.MNS_GovernorReplacements[def.GovernorType] ~= nil
end
function AddGovernorCandidate(def, canAppoint)
    if not replaced(def) then return baseCandidate(def, canAppoint) end
end
-- Originals already appointed in an old save remain manageable in the native UI.
print('[MNS GOVERNORS] Native panel filter loaded: original candidates hidden for Minos.')
