-- Native Liang modifier protects structures. Lua only compensates disaster population loss.
-- No building/district/improvement/defense snapshots or repair calls belong here.
include('MNS_World')
MNS_Protection = {}
local P, W = MNS_Protection, MNS_World
function P.snapshotCity(city)
    return {owner=city:GetOwner(), id=city:GetID(), x=city:GetX(), y=city:GetY(),
            population=city:GetPopulation(), faith=city:GetYield(YieldTypes.FAITH)}
end
function P.capture()
    local all={}
    for _,id in ipairs(PlayerManager.GetAliveMajorIDs()) do
        if W.minoan(id) then
            for _,city in Players[id]:GetCities():Members() do
                if W.protected(city) then all[#all+1]=P.snapshotCity(city) end
            end
        end
    end
    table.sort(all,function(a,b)
        if a.owner~=b.owner then return a.owner<b.owner end
        return a.id<b.id
    end)
    return all
end
function P.restoreOne(s)
    local city=W.city(s.owner,s.id)
    -- Never recreate deleted cities, compensate captured cities, or rely on a stale governor state.
    if not city or city:GetX()~=s.x or city:GetY()~=s.y or not W.protected(city) then return end
    local diff=s.population-city:GetPopulation()
    if diff>0 then city:ChangePopulation(diff) end
end
function P.restore(all, affectedPlots)
    local affected={}
    for _,index in ipairs(affectedPlots or {}) do
        local city=W.plotCity(Map.GetPlotByIndex(index))
        if city then affected[city:GetOwner()..':'..city:GetID()]=true end
    end
    for _,s in ipairs(all or {}) do
        if affected[s.owner..':'..s.id] then P.restoreOne(s) end
    end
end
return P
