include('NaturalDisasterPopup')

local baseShowRandomEvent = ShowRandomEvent
function ShowRandomEvent(eventType, ...)
    local config = PlayerConfigurations[Game.GetLocalPlayer()]
    local event = GameInfo.RandomEvents[eventType]
    if config and config:GetLeaderTypeName() == 'LEADER_MNS_MINOS'
        and event and event.EffectOperatorType == 'VOLCANO' then
        -- Skip before native popup/MFX sequence locks are acquired. Gameplay still runs.
        -- Covers natural and summoned eruptions; no cross-context property timing needed.
        print('[MNS CINEMATIC] Skipped volcano presentation: ' .. event.RandomEventType)
        return
    end
    return baseShowRandomEvent(eventType, ...)
end
print('[MNS CINEMATIC] Volcano presentation bypass loaded for Minos.')
