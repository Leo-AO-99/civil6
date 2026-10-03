local root=arg[1]or'.'
local F=dofile(root..'/tests/game_mock.lua')
dofile(root..'/mods/minoan/Gameplay/MNS_Gameplay.lua')
local p,city=Players[0],F.cities[0]
local count=0
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function test(n,f)f();count=count+1;print('PASS '..n)end
local function buy(role)
 GameEvents.MNS_Action.fire(0,{Action='Buy',Role=role,CityID=0})
 return p.units.items[F.unitSerial]
end
-- Sanctuary available for purchasing. No native immunity is emulated by this mock.
city.district.pillaged=false
test('shelter follows native establishment, not elapsed assignment time',function()
 F.turn=1;eq(MNS_World.protected(city),false)
 F.turn=20;city:SetProperty('MNS_Assignment',{governor=99,turn=0})
 eq(MNS_World.protected(city),false)
 F.turn=2;F.setEstablished(city,true)
 eq(MNS_World.protected(city),true);eq(city.governor:IsEstablished(),true)
end)
local oracle
test('purchase deducts configured faith exactly once',function()
 local old=p.faith;oracle=buy('Oracle');assert(oracle);eq(p.faith,old-400);eq(oracle:GetProperty('MNS_Charges'),2)
end)
test('enemy target rejected with no charge or disaster',function()
 local n=F.applyCount
 GameEvents.MNS_Action.fire(0,{Action='Cast',UnitID=oracle.id,PlotID=3})
 eq(F.applyCount,n);eq(oracle:GetProperty('MNS_Charges'),2)
end)
test('disaster bracket compensates population but NEVER repairs any structures',function()
 F.disasterDamage=function()
  city.pop=5;city.buildings.pillaged=true;city.district.pillaged=true;city.district.damage[0]=70;city.district.damage[1]=80
  F.plots[1].improvement=-1;F.plots[1].pillaged=false
  F.cities[1].pop=3
 end
 GameEvents.MNS_Action.fire(0,{Action='Cast',UnitID=oracle.id,PlotID=1})
 eq(city.pop,8);eq(city.buildings.pillaged,true);eq(city.district.pillaged,true)
 eq(city.district.damage[0],70);eq(city.district.damage[1],80)
 eq(F.plots[1].improvement,-1);eq(F.plots[1].pillaged,false)
 eq(F.cities[1].pop,3);eq(oracle:GetProperty('MNS_Charges'),1);eq(oracle.moves,0)
 eq(p:GetProperty('MNS_Knowledge').science,20);eq(p:GetProperty('MNS_Knowledge').culture,20)
end)
test('native duplicate callback never duplicates payout',function()
 Events.RandomEventOccurred.fire(0,0,1,0,0,F.eventID)
 eq(p:GetProperty('MNS_Knowledge').science,20)
end)
test('unrelated population change never heals',function()city.pop=7;Events.CityPopulationChanged.fire(0,0,7);eq(city.pop,7)end)
test('science completes selected tech and retains overflow despite reentrancy',function()
 p.science.current=0;Events.ResearchChanged.fire(0,0)
 eq(p.science.progress[0],15);eq(p:GetProperty('MNS_Knowledge').science,5)
 p.science.current=1;Events.ResearchChanged.fire(0,1)
 eq(p.science.progress[1],5);eq(p:GetProperty('MNS_Knowledge').science,0)
end)
test('culture separately completes civic and retains overflow',function()
 p.culture.current=0;Events.CivicChanged.fire(0,0)
 eq(p.culture.progress[0],15);eq(p:GetProperty('MNS_Knowledge').culture,5)
 p.culture.current=1;Events.CivicChanged.fire(0,1)
 eq(p.culture.progress[1],5);eq(p:GetProperty('MNS_Knowledge').culture,0)
end)
test('unavailable progress getter holds reward instead of discarding it',function()
 local s=p:GetProperty('MNS_Knowledge');s.culture=9;p:SetProperty('MNS_Knowledge',s)
 local fn=p.culture.GetCulturalProgress;p.culture.GetCulturalProgress=nil
 Events.CivicChanged.fire(0,1);eq(p:GetProperty('MNS_Knowledge').culture,9)
 p.culture.GetCulturalProgress=fn
end)
test('native loss of establishment immediately removes shelter',function()
 F.setEstablished(city,false);eq(MNS_World.protected(city),false)
 F.turn=100;eq(MNS_World.protected(city),false)
 F.turn=4;F.setEstablished(city,true);eq(MNS_World.protected(city),true)
 -- Explicit fixture reset for the later purchase; NOT a gameplay repair.
 city.district.pillaged=false
end)
test('failed unit creation charges no faith',function()
 oracle.x=1;F.failCreate=true;local before=p.faith;buy('Prophet');eq(p.faith,before);F.failCreate=false
end)
local prophet
test('prophet price increments with purchases',function()
 prophet=buy('Prophet');assert(prophet);eq(MNS_World.price(p,'Prophet'),4500)
end)
test('peace blocks comet; war permits it; no economic reward',function()
 local n=F.applyCount
 GameEvents.MNS_Action.fire(0,{Action='Cast',UnitID=prophet.id,PlotID=3});eq(F.applyCount,n)
 F.war=true;F.footprint={3};F.disasterDamage=nil
 local old=p:GetProperty('MNS_Knowledge')
 GameEvents.MNS_Action.fire(0,{Action='Cast',UnitID=prophet.id,PlotID=3})
 eq(F.applyCount,n+1);eq(p.units.items[prophet.id],nil)
 eq(p:GetProperty('MNS_Knowledge').science,old.science)
 eq(p:GetProperty('MNS_Knowledge').culture,old.culture)
end)
print(count..' gameplay mock tests passed (not a game-runtime test)')
