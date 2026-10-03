-- Queue and validation only; does not emulate animation or multiplayer.
local root=arg[1] or '.'
local function setup()
 local F=dofile(root..'/tests/game_mock.lua')
 GameInfo.RandomEvents=F.info({
  {RandomEventType='RANDOM_EVENT_FLOOD_MODERATE',EffectOperatorType='FLOODPLAIN'},
  {RandomEventType='RANDOM_EVENT_FLOOD_MAJOR',EffectOperatorType='FLOODPLAIN'}},'RandomEventType')
 GameInfo.RandomEvent_Yields=F.info({
  {RandomEventType='RANDOM_EVENT_FLOOD_MODERATE',YieldType='YIELD_FOOD',Amount=1,Percentage=100},
  {RandomEventType='RANDOM_EVENT_FLOOD_MAJOR',YieldType='YIELD_FOOD',Amount=1,Percentage=100}},'RandomEventType')
 GameInfo.Features=F.info({{FeatureType='FEATURE_FLOODPLAINS'}},'FeatureType')
 RiverManager.GetRiverForFloodplain=function()return 3 end
 RiverManager.GetFloodplainPlots=function()return {1,2}end
 F.cities[0].district.pillaged=false
 dofile(root..'/mods/minoan/Gameplay/MNS_Gameplay.lua')
 GameEvents.MNS_Action.fire(0,{Action='Buy',Role='Oracle',CityID=0})
 return F,Players[0],Players[0].units.items[F.unitSerial]
end
local function request(u,event)
 GameEvents.MNS_Action.fire(0,{Action='Cast',UnitID=u.id,PlotID=1,EventType=event})
end
local F,p,u=setup()
request(u,'RANDOM_EVENT_COMET_STRIKE')
assert(p:GetProperty('MNS_ScheduledCast')==nil and F.applyCount==0)
request(u,'RANDOM_EVENT_FLOOD_MAJOR')
assert(F.applyCount==0 and u:GetProperty('MNS_Charges')==2 and u.moves==0)
request(u,'RANDOM_EVENT_FLOOD_MODERATE')
assert(p:GetProperty('MNS_ScheduledCast').eventType=='RANDOM_EVENT_FLOOD_MAJOR')
-- The persistent property survives a same-turn activation without execution.
Events.PlayerTurnActivated.fire(0);assert(F.applyCount==0)
F.turn=1;Events.PlayerTurnActivated.fire(0)
assert(F.applyCount==1 and F.lastApplied.EventType==1 and u:GetProperty('MNS_Charges')==1)
Events.PlayerTurnActivated.fire(0);assert(F.applyCount==1)
assert(p:GetProperty('MNS_ScheduledCast')==nil)
F,p,u=setup();request(u,'RANDOM_EVENT_FLOOD_MAJOR')
F.plots[1].owner=1;F.turn=1;Events.PlayerTurnActivated.fire(0)
assert(F.applyCount==0 and u:GetProperty('MNS_Charges')==2 and p:GetProperty('MNS_ScheduledCast')==nil)
-- Missing culture getter must never write player properties and feed update events.
p.culture.GetCulturalProgress=nil;p:SetProperty('MNS_Knowledge',{culture=5,science=0})
local writes=0;local set=p.SetProperty
p.SetProperty=function(self,...)writes=writes+1;return set(self,...)end
for i=1,4 do Events.CivicChanged.fire(0,0)end
assert(writes==0 and p:GetProperty('MNS_Knowledge').culture==5)
print('PASS selected event, delayed single execution, duplicate rejection, changed target cancellation, culture no-write loop')

F,p,u=setup()
GameInfo.Features=F.info({{FeatureType='FEATURE_VOLCANO'}},'FeatureType')
GameInfo.RandomEvents=F.info({{RandomEventType='RANDOM_EVENT_VOLCANO_MEGACOLOSSAL',EffectOperatorType='VOLCANO'}},'RandomEventType')
GameInfo.RandomEvent_Yields=F.info({{RandomEventType='RANDOM_EVENT_VOLCANO_MEGACOLOSSAL',YieldType='YIELD_FOOD',Amount=1,Percentage=100}},'RandomEventType')
GameInfo.NamedVolcanoes=F.info({{NamedVolcanoType='NAMED_VOLCANO_TEST',Name='LOC_TEST',Index=73}},'NamedVolcanoType')
MapFeatureManager={GetNamedVolcanoes=function()return {{PlotX=1,PlotY=0,Name='LOC_TEST'}}end}
request(u,'RANDOM_EVENT_VOLCANO_MEGACOLOSSAL');F.turn=1;Events.PlayerTurnActivated.fire(0)
assert(F.applyCount==1 and F.lastApplied.NamedVolcano==73 and F.lastApplied.Location==1)
assert(u:GetProperty('MNS_Charges')==1)
F.turn=2;Events.PlayerTurnActivated.fire(0)
MapFeatureManager.GetNamedVolcanoes=function()return {}end
request(u,'RANDOM_EVENT_VOLCANO_MEGACOLOSSAL');F.turn=3;Events.PlayerTurnActivated.fire(0)
assert(F.applyCount==1 and u:GetProperty('MNS_Charges')==1)
Game:SetProperty('MNS_PendingInvocation',{unitID=u.id,playerID=0,turn=2,eventType=0,x=1,y=0})
F.turn=4;Events.PlayerTurnActivated.fire(0)
assert(Game:GetProperty('MNS_PendingInvocation')==nil and u:GetProperty('MNS_Charges')==1)
print('PASS exact named volcano, unavailable identifier refuses random eruption, stale manual wait releases without charging')
