-- Synthetic database and callback tests. They prove selection/repair boundaries,
-- NOT that the native engine applies immunity or fertility.
local root=arg[1] or '.'
local count=0
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function test(name,fn)
    local F=dofile(root..'/tests/game_mock.lua')
    include('MNS_Protection')
    fn(F,MNS_World,MNS_Protection)
    count=count+1;print('PASS '..name)
end
local safe = {
    {'RANDOM_EVENT_FLOOD_MODERATE','FLOODPLAIN','flood'},
    {'RANDOM_EVENT_FLOOD_MAJOR','FLOODPLAIN','flood'},
    {'RANDOM_EVENT_FLOOD_1000_YEAR','FLOODPLAIN','flood'},
    {'RANDOM_EVENT_VOLCANO_GENTLE','VOLCANO','volcano'},
    {'RANDOM_EVENT_VOLCANO_CATASTROPHIC','VOLCANO','volcano'},
    {'RANDOM_EVENT_VOLCANO_MEGACOLOSSAL','VOLCANO','volcano'},
    {'RANDOM_EVENT_FOREST_FIRE','FIRE','forest'},
    {'RANDOM_EVENT_JUNGLE_FIRE','FIRE','jungle'},
    {'RANDOM_EVENT_DUST_STORM_GRADIENT','STORM','sandstorm'},
    {'RANDOM_EVENT_DUST_STORM_HABOOB','STORM','sandstorm'},
    {'RANDOM_EVENT_BLIZZARD_SIGNIFICANT','STORM','blizzard'},
    {'RANDOM_EVENT_BLIZZARD_CRIPPLING','STORM','blizzard'}
}
local function catalog(F, names)
    local events,yields={},{}
    for _,v in ipairs(names) do
        events[#events+1]={RandomEventType=v[1],EffectOperatorType=v[2]}
        yields[#yields+1]={RandomEventType=v[1],YieldType='YIELD_FOOD',Amount=1,Percentage=25}
    end
    GameInfo.RandomEvents=F.info(events,'RandomEventType')
    GameInfo.RandomEvent_Yields=F.info(yields,'RandomEventType')
end
local function ground(F,feat,terr)
    GameInfo.Features=F.info({{FeatureType=feat}},'FeatureType')
    GameInfo.Terrains=F.info({{TerrainType=terr}},'TerrainType')
    return F.plots[1]
end
test('all twelve allowlisted land events require positive loaded yield data',function(F,W)
    catalog(F,safe)
    for _,v in ipairs(safe) do eq(W.fertileFamily(GameInfo.RandomEvents[v[1]]),v[3]) end
end)
for _,bad in ipairs {
    'RANDOM_EVENT_COMET_STRIKE','RANDOM_EVENT_COMET_STRIKE_TARGETED',
    'RANDOM_EVENT_METEOR_SHOWER','RANDOM_EVENT_SEA_LEVEL_RISE4',
    'RANDOM_EVENT_SOLAR_FLARE','RANDOM_EVENT_NUCLEAR_ACCIDENT',
    'RANDOM_EVENT_TORNADO_FAMILY','RANDOM_EVENT_TORNADO_OUTBREAK',
    'RANDOM_EVENT_DROUGHT_MAJOR','RANDOM_EVENT_DROUGHT_EXTREME',
    'RANDOM_EVENT_VOLCANO_TRIGGERED','RANDOM_EVENT_FLOOD_TRIGGERED',
    'RANDOM_EVENT_FOREST_FIRE_TRIGGERED','RANDOM_EVENT_JUNGLE_FIRE_TRIGGERED',
    'RANDOM_EVENT_MOD_FLOOD_COMET','RANDOM_EVENT_HURRICANE_CAT_5'
} do
    test('closed cultivation pool rejects '..bad..' even with positive yields',function(F,W)
        catalog(F,{{bad,'FLOODPLAIN'}})
        eq(W.fertileFamily(GameInfo.RandomEvents[bad]),nil)
        eq(#W.options(F.plots[1],false),0)
    end)
end
test('missing fertility table or empty table denies cultivation',function(F,W)
    local d=GameInfo.RandomEvents[0]
    GameInfo.RandomEvent_Yields=nil;eq(W.fertileFamily(d),nil)
    GameInfo.RandomEvent_Yields=F.info({},'RandomEventType');eq(W.fertileFamily(d),nil)
end)
test('zero amount zero chance and negative yields never qualify as fertility',function(F,W)
    local d=GameInfo.RandomEvents[0]
    for _,v in ipairs{{0,100},{1,0},{-1,100}} do
        GameInfo.RandomEvent_Yields=F.info({{RandomEventType=d.RandomEventType,YieldType='YIELD_FOOD',Amount=v[1],Percentage=v[2]}},'RandomEventType')
        eq(W.fertileFamily(d),nil)
    end
end)
test('late fire recovery yields qualify without fabricating immediate fertility',function(F,W)
    local d=GameInfo.RandomEvents[0]
    GameInfo.RandomEvent_Yields=F.info({
        {RandomEventType=d.RandomEventType,YieldType='YIELD_FOOD',Amount=0,Percentage=100,Turn=0},
        {RandomEventType=d.RandomEventType,YieldType='YIELD_PRODUCTION',Amount=1,Percentage=100,Turn=6}
    },'RandomEventType')
    eq(W.fertileFamily(d),'forest')
end)
test('repurposed canonical name with comet operator is refused',function(F,W)
    GameInfo.RandomEvents[0].EffectOperatorType='COMET_STRIKE'
    eq(W.fertileFamily(GameInfo.RandomEvents[0]),nil)
end)
test('global ice-loss halt-fertility and negative-fertility flags refuse canonical event',function(F,W)
    local d=GameInfo.RandomEvents[0]
    for _,key in ipairs{'Global','IceLoss','HaltsFloodFertility','HaltsStormFertility','FertilityRemovalChance'} do
        d[key]=1;eq(W.fertileFamily(d),nil);d[key]=0
    end
    d.NaturalWonder='FEATURE_TEST';eq(W.fertileFamily(d),nil)
end)
test('forest and jungle use their own event IDs, never each other',function(F,W)
    catalog(F,{{'RANDOM_EVENT_FOREST_FIRE','FIRE'},{'RANDOM_EVENT_JUNGLE_FIRE','FIRE'}})
    eq(W.options(ground(F,'FEATURE_FOREST','TERRAIN_GRASS'),false)[1].RandomEventType,'RANDOM_EVENT_FOREST_FIRE')
    eq(W.options(ground(F,'FEATURE_JUNGLE','TERRAIN_PLAINS'),false)[1].RandomEventType,'RANDOM_EVENT_JUNGLE_FIRE')
    eq(W.eventFamily(GameInfo.RandomEvents.RANDOM_EVENT_JUNGLE_FIRE),'fire')
end)
test('burning or recovering forests cannot be ignited afresh',function(F,W)
    for _,f in ipairs{'FEATURE_BURNING_FOREST','FEATURE_BURNT_FOREST','FEATURE_BURNING_JUNGLE','FEATURE_BURNT_JUNGLE'} do
        eq(#W.options(ground(F,f,'TERRAIN_GRASS'),false),0)
    end
end)
test('flood requires an actual floodplain and a valid river',function(F,W)
    catalog(F,{safe[1]})
    local plot=ground(F,'FEATURE_FLOODPLAINS','TERRAIN_DESERT')
    eq(#W.options(plot,false),0)
    RiverManager.GetRiverForFloodplain=function()return 1 end;eq(#W.options(plot,false),1)
    eq(#W.options(ground(F,'FEATURE_FAKE_FLOODPLAINS','TERRAIN_DESERT'),false),0)
end)
test('volcano only uses existing ordinary volcano, never creates one',function(F,W)
    catalog(F,{safe[4]})
    eq(#W.options(ground(F,'FEATURE_VOLCANO','TERRAIN_GRASS_MOUNTAIN'),false),1)
    eq(#W.options(ground(F,'FEATURE_FOREST','TERRAIN_GRASS'),false),0)
end)
test('storms match desert tundra snow and respect both category switches',function(F,W)
    catalog(F,{safe[9],safe[11]})
    eq(W.options(ground(F,'NONE','TERRAIN_DESERT'),false)[1].RandomEventType,safe[9][1])
    F.settings.DustStormEnabled='0';eq(#W.options(F.plots[1],false),0)
    eq(W.options(ground(F,'NONE','TERRAIN_TUNDRA'),false)[1].RandomEventType,safe[11][1])
    F.settings.BlizzardEnabled='0';eq(#W.options(F.plots[1],false),0)
    F.settings.BlizzardEnabled='1';F.settings.StormEnabled='0';eq(#W.options(F.plots[1],false),0)
end)
test('late climate halt disables floods and storms but not fire or volcano',function(F,W)
    local rows={};for _,v in ipairs(safe)do rows[#rows+1]=v end
    rows[#rows+1]={'RANDOM_EVENT_SEA_LEVEL_RISE4','SEA_LEVEL'};catalog(F,rows)
    local level=GameInfo.RandomEvents.RANDOM_EVENT_SEA_LEVEL_RISE4
    level.Severity=4;level.HaltsFloodFertility=1;level.HaltsStormFertility=1
    F.climateSeverity=3;eq(W.fertileFamily(GameInfo.RandomEvents[safe[1][1]]),'flood')
    F.climateSeverity=4
    for _,i in ipairs{1,9,11} do eq(W.fertileFamily(GameInfo.RandomEvents[safe[i][1]]),nil) end
    eq(W.fertileFamily(GameInfo.RandomEvents[safe[4][1]]),'volcano')
    eq(W.fertileFamily(GameInfo.RandomEvents[safe[7][1]]),'forest')
end)
test('unreadable climate fails closed for climate-sensitive cultivation',function(F,W)
    catalog(F,safe);GameClimate.GetSeverityForLastSeaLevelEvent=nil
    eq(W.fertileFamily(GameInfo.RandomEvents[safe[1][1]]),nil)
    eq(W.fertileFamily(GameInfo.RandomEvents[safe[4][1]]),'volcano')
end)
test('automatic scheduler skips barren land instead of using tornado or comet',function(F)
    ground(F,'NONE','TERRAIN_GRASS')
    dofile(root..'/mods/minoan/Gameplay/MNS_Gameplay.lua')
    F.settings.AutoDisastersEnabled='1';F.turn=8
    GameEvents.PlayerTurnStartComplete.fire(0)
    eq(F.applyCount,0);assert(Players[0]:GetProperty('MNS_Status'):find('没有合法肥地'))
end)
test('automatic scheduler still invokes a fertile forest event',function(F)
    dofile(root..'/mods/minoan/Gameplay/MNS_Gameplay.lua')
    F.settings.AutoDisastersEnabled='1';F.turn=8
    GameEvents.PlayerTurnStartComplete.fire(0)
    eq(F.applyCount,1);eq(F.lastApplied.EventType,0)
end)
test('final invoke gate rejects an injected comet from automatic candidates',function(F)
    dofile(root..'/mods/minoan/Gameplay/MNS_Gameplay.lua')
    MNS_World.options=function()return {GameInfo.RandomEvents[1]} end
    F.settings.AutoDisastersEnabled='1';F.turn=8
    GameEvents.PlayerTurnStartComplete.fire(0)
    eq(F.applyCount,0);eq(Game:GetProperty('MNS_PendingInvocation'),nil)
end)
test('final invoke gate rejects injected comet for Oracle without charging',function(F)
    F.cities[0].district.pillaged=false
    dofile(root..'/mods/minoan/Gameplay/MNS_Gameplay.lua')
    GameEvents.MNS_Action.fire(0,{Action='Buy',Role='Oracle',CityID=0})
    local u=Players[0].units.items[F.unitSerial]
    MNS_World.options=function()return {GameInfo.RandomEvents[1]} end
    GameEvents.MNS_Action.fire(0,{Action='Cast',UnitID=u.id,PlotID=1})
    eq(F.applyCount,0);eq(u:GetProperty('MNS_Charges'),2)
end)
test('population snapshots never read or store infrastructure',function(F,W,P)
    local c=F.cities[0];F.setEstablished(c,true)
    c.GetBuildings=function()error('must not read buildings')end
    c.GetDistricts=function()error('must not read districts')end
    local s=P.snapshotCity(c)
    eq(s.population,8);eq(s.buildings,nil);eq(s.districts,nil);eq(s.improvements,nil)
end)
test('population compensation is restricted to actual affected cities',function(F,W,P)
    local c=F.cities[0];F.setEstablished(c,true);local all=P.capture();c.pop=6
    P.restore(all,{3});eq(c.pop,6)
    P.restore(all,{1});eq(c.pop,8)
end)
test('lost establishment prevents stale snapshot population compensation',function(F,W,P)
    local c=F.cities[0];F.setEstablished(c,true);local all=P.capture();c.pop=6
    F.setEstablished(c,false);P.restore(all,{1});eq(c.pop,6)
end)
test('population compensation does not delete natural growth',function(F,W,P)
    local c=F.cities[0];F.setEstablished(c,true);local all=P.capture();c.pop=10
    P.restore(all,{1});eq(c.pop,10)
end)
test('sanctuary works with gameplay location lookup despite string GetDistrict returning nil',function(F,W)
 local city=F.cities[0]
 eq(city:GetDistricts():GetDistrict('DISTRICT_MNS_SANCTUARY'),nil)
 city.district.pillaged=false;eq(W.sanctuary(city),true)
 city.district.pillaged=true;eq(W.sanctuary(city),false)
 city.district.pillaged=false;city.district.IsComplete=function()return false end
 eq(W.sanctuary(city),false)
end)

test('different flood origin confirms only when event type and requested footprint match',function(F,W)
 local pending={eventType=0,x=1,y=0}
 eq(W.invocationMatches(pending,0,2,0,{1,2}),true)
 eq(W.invocationMatches(pending,0,2,0,{2}),false)
 eq(W.invocationMatches(pending,1,2,0,{1,2}),false)
end)

test('unconfirmed automatic and manual waits expire without same-turn retry',function(F)
 dofile(root..'/mods/minoan/Gameplay/MNS_Gameplay.lua')
 F.settings.AutoDisastersEnabled='1';F.turn=8
 GameRandomEvents.ApplyEvent=function()F.applyCount=F.applyCount+1 end
 GameEvents.PlayerTurnStartComplete.fire(0)
 eq(F.applyCount,1);assert(Game:GetProperty('MNS_PendingInvocation'))
 GameEvents.PlayerTurnStartComplete.fire(0);eq(F.applyCount,1)
 F.turn=9;GameEvents.PlayerTurnStartComplete.fire(0)
 eq(F.applyCount,1);eq(Game:GetProperty('MNS_PendingInvocation'),nil)
 eq(Players[0]:GetProperty('MNS_DisasterAudit').unconfirmed,1)
 F.turn=10;GameEvents.PlayerTurnStartComplete.fire(0);eq(F.applyCount,2)
 local pending=Game:GetProperty('MNS_PendingInvocation');pending.unitID=99
 Game:SetProperty('MNS_PendingInvocation',pending)
 F.turn=20;GameEvents.PlayerTurnStartComplete.fire(0)
 eq(F.applyCount,3);eq(Game:GetProperty('MNS_PendingInvocation').unitID,nil)
end)
test('volcano and comet require the requested origin, not adjacent footprint',function(F,W)
 for _,name in ipairs{'RANDOM_EVENT_VOLCANO_GENTLE','RANDOM_EVENT_COMET_STRIKE'} do
  GameInfo.RandomEvents[0].RandomEventType=name
  eq(W.invocationMatches({eventType=0,x=1,y=0},0,2,0,{1,2}),false)
  eq(W.invocationMatches({eventType=0,x=1,y=0},0,1,0,{1,2}),true)
 end
end)
test('missing scope APIs and invalid callback coordinates never fabricate an area',function(F,W)
 GameClimate={};RiverManager={}
 for _,op in ipairs{'STORM','FLOODPLAIN','DROUGHT','VOLCANO','FIRE','COMET_STRIKE'} do
  local d={RandomEventType='RANDOM_EVENT_'..op,EffectOperatorType=op}
  eq(#W.affected(d,1,0,-1),1)
  eq(#W.affected(d,-99,0,-1),0)
 end
end)
test('city-targeted comet is not offered on ordinary land',function(F,W)
 GameInfo.RandomEvents[1].TargetCities=true
 eq(#W.options(F.plots[1],true),0)
 eq(#W.options(F.plots[3],true),1)
end)
print(count..' cultivation/native-boundary tests passed (not a game-runtime test)')
