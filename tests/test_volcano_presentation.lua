local root = arg[1] or '.'
local leader = 'LEADER_MNS_MINOS'
local calls = 0
Game = {GetLocalPlayer=function() return 0 end}
PlayerConfigurations = {[0]={GetLeaderTypeName=function() return leader end}}
GameInfo = {RandomEvents={
    [1]={EffectOperatorType='VOLCANO', RandomEventType='RANDOM_EVENT_VOLCANO_GENTLE'},
    [2]={EffectOperatorType='FLOODPLAIN'},
}}
function include(name)
    assert(name == 'NaturalDisasterPopup')
    function ShowRandomEvent(...) calls=calls+1; return ... end
    -- Native registered callbacks resolve the global ShowRandomEvent at call time.
    function OnRandomEventStarted(...) return ShowRandomEvent(...) end
    function OnRandomEventOccurred(...) return ShowRandomEvent(...) end
end
dofile(root .. '/mods/minoan/UI/MNS_NaturalDisasterPopup.lua')
OnRandomEventStarted(1)
OnRandomEventOccurred(1)
assert(calls == 0, 'volcano must never enter native presentation/lock path')
local event, severity, x, y = OnRandomEventOccurred(2, 3, 50, 27)
assert(calls == 1 and event == 2 and severity == 3 and x == 50 and y == 27)
leader = 'OTHER_LEADER'
OnRandomEventStarted(1)
assert(calls == 2, 'other leaders retain native volcano presentation')
PlayerConfigurations[0] = nil
OnRandomEventOccurred(1)
assert(calls == 3)
print('PASS volcano presentation bypass and native fallback')
