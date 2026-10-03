-- FireTuner Gameplay console: MNS_Diagnose(playerID)
include('MNS_World')
function MNS_Diagnose(playerID)
    local W=MNS_World
    local p=Players[playerID]
    print('[MNS CHECK] player='..tostring(playerID)..' minoan='..tostring(W.minoan(playerID)))
    if not p then return end
    print('[MNS CHECK] ApplyEvent='..tostring(GameRandomEvents and GameRandomEvents.ApplyEvent~=nil))
    print('[MNS CHECK] comet='..tostring(W.cometAvailable())..' (Prophet-only; never automatic/Oracle)')
    print('[MNS CHECK] protection: native Liang structures; Lua population-only, no repair fallback')
    local count=0
    for def in GameInfo.RandomEvents() do
        local family=W.fertileFamily(def)
        if family then
            count=count+1;print('[MNS CHECK] cultivation candidate='..def.RandomEventType..' family='..family)
        end
    end
    print('[MNS CHECK] eligible fertility definitions='..count..' (before plot/category switches)')
    print('[MNS CHECK] climate fertility readable='..tostring(GameClimate and GameClimate.GetSeverityForLastSeaLevelEvent~=nil))
    print('[MNS CHECK] culture progress readable='..tostring(p:GetCulture().GetCulturalProgress~=nil))
    print('[MNS CHECK] pending invocation='..tostring(Game:GetProperty('MNS_PendingInvocation')~=nil))
    for _,city in p:GetCities():Members() do
        local g=W.governor(city)
        print('[MNS CHECK] city='..city:GetID()..' governor='..tostring(g)..' establishedMarker='..tostring(city:GetProperty('MNS_GovernorEstablished'))..' protected='..tostring(W.protected(city)))
    end
    print('[MNS CHECK] governor transition strength='..tostring(W.setting('MinoanGovernorTransitionStrength','missing')))
    local s=p:GetProperty('MNS_Knowledge') or {}
    print('[MNS CHECK] bank science='..tostring(s.science or 0)..' culture='..tostring(s.culture or 0))
end
