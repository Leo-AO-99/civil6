-- Deliberately synthetic Civ VI interface mock, NOT an engine emulator or real database.
local F={turn=0, properties={}, eventID=0, applyCount=0}
local root=arg[1] or '.'
function include(name) dofile(root..'/mods/minoan/Gameplay/'..name..'.lua') end
local function copy(v)
 if type(v)~='table' then return v end
 local out={};for k,x in pairs(v) do out[k]=copy(x) end;return out
end
local function properties(o)
 o.props={};function o:GetProperty(k)return copy(self.props[k])end
 function o:SetProperty(k,v)self.props[k]=copy(v)end
 return o
end
local function bus()
 return setmetatable({},{__index=function(t,k)
  local x={handlers={}};function x.Add(f)x.handlers[#x.handlers+1]=f end
  function x.fire(...)for _,f in ipairs(x.handlers)do f(...)end end
  t[k]=x;return x
 end})
end
Events=bus();GameEvents=bus()
Game=properties({})
function Game.GetCurrentGameTurn()return F.turn end
function Game.GetRandNum(n)return 0 end
GameConfiguration={IsAnyMultiplayer=function()return false end,IsHotseat=function()return false end}
YieldTypes={FAITH=5};DefenseTypes={DISTRICT_GARRISON=0,DISTRICT_OUTER=1}
local function info(rows,key)
 local t={};for i,r in ipairs(rows)do r.Index=r.Index or i-1;t[r[key]]=r;t[r.Index]=r end
 return setmetatable(t,{__call=function() local n=0;return function()n=n+1;return rows[n]end end})
end
F.info=info
F.settings={AutoDisastersEnabled='0',ProtectionEnabled='1',MinoanGovernorTransitionStrength='250',
 OracleFaithCost='400',OracleCostIncrease='0',OracleCharges='2',OracleMoves='3',OracleRange='2',OracleUnlockCivic='',OracleBaseUnit='UNIT_MISSIONARY',
 ProphetEnabled='1',ProphetFaithCost='3000',ProphetCostIncrease='1500',ProphetCharges='1',ProphetMoves='2',ProphetRange='3',ProphetUnlockCivic='',ProphetBaseUnit='UNIT_APOSTLE',
 FireEnabled='1',FloodEnabled='1',VolcanoEnabled='1',StormEnabled='1',DustStormEnabled='1',BlizzardEnabled='1',ScienceRewardPercent='50',CultureRewardPercent='50',
 FireRewardCooldownTurns='5',RewardCityTurnCap='1',CometAllowsCityCenter='1',LogLevel='0'}
local settings=setmetatable({},{__index=function(_,k)if F.settings[k] then return {Value=F.settings[k]}end end})
GameInfo={MNS_Settings=settings,
 Districts=info({{DistrictType='DISTRICT_MNS_SANCTUARY'}},'DistrictType'),
 Buildings=info({{BuildingType='BUILDING_SHRINE'}},'BuildingType'),
 Features=info({{FeatureType='FEATURE_FOREST'}},'FeatureType'),
 Terrains=info({{TerrainType='TERRAIN_GRASS'}},'TerrainType'),
 Units=info({{UnitType='UNIT_MISSIONARY',Combat=0},{UnitType='UNIT_APOSTLE',Combat=0}},'UnitType'),
 Civics=info({{CivicType='CIVIC_TEST'}},'CivicType'),
 RandomEvents=info({{RandomEventType='RANDOM_EVENT_FOREST_FIRE',EffectOperatorType='FIRE'},
 {RandomEventType='RANDOM_EVENT_COMET_STRIKE',EffectOperatorType='COMET_STRIKE'}},'RandomEventType'),
 RandomEvent_Yields=info({{RandomEventType='RANDOM_EVENT_FOREST_FIRE',YieldType='YIELD_PRODUCTION',Amount=1,Percentage=100,Turn=6}},'RandomEventType')}
local function collection(items,key)
 local o={items=items or {}};function o:FindID(id)return self.items[id]end
 function o:Members()return pairs(self.items)end
 return o
end
local function district()
 local d=properties({damage={[0]=4,[1]=6},pillaged=true})
 function d:GetID()return 0 end;function d:GetType()return 0 end
 function d:GetDamage(k)return self.damage[k]end;function d:SetDamage(k,v)self.damage[k]=v end
 function d:IsPillaged()return self.pillaged end;function d:SetPillaged(v)self.pillaged=v end
 function d:IsComplete()return true end
 return d
end
local function city(owner)
 local c=properties({owner=owner,pop=8,faith=40,district=district(),buildings={present=true,pillaged=true}})
 c.governor={};function c.governor:GetType()return 99 end;function c.governor:IsEstablished()return false end
 function c:GetAssignedGovernor()return self.governor end
 function c:GetOwner()return self.owner end;function c:GetID()return 0 end
 function c:GetX()return self.owner*3 end;function c:GetY()return 0 end
 function c:GetPopulation()return self.pop end;function c:ChangePopulation(v)self.pop=self.pop+v end
 function c:GetYield()return self.faith end;function c:GetName()return 'Mock City'end
 function c:GetDistricts()
  local ds=collection({[0]=self.district});function ds:GetDistrict(i)return self.items[i]end;return ds
 end
 function c:GetBuildings()
  local b=self.buildings;function b:HasBuilding()return self.present end
  function b:IsPillaged()return self.pillaged end;function b:SetPillaged(i,v)self.pillaged=v end;return b
 end
 function c:GetBuildQueue()return {CreateBuilding=function()c.buildings.present=true end}end
 return c
end
F.cities={[0]=city(0),[1]=city(1)}
local function research(kind)
 local o={current=-1,progress={},costs={[0]=15,[1]=50},complete={}}
 local currentName=kind=='science' and 'GetResearchingTech'or'GetProgressingCivic'
 local costName=kind=='science' and 'GetResearchCost'or'GetCultureCost'
 local progressName=kind=='science' and 'GetResearchProgress'or'GetCulturalProgress'
 local hasName=kind=='science' and 'HasTech'or'HasCivic'
 local changeName=kind=='science' and 'ChangeCurrentResearchProgress'or'ChangeCurrentCulturalProgress'
 o[currentName]=function(self)return self.current end
 o[costName]=function(self,i)return self.costs[i]end
 o[progressName]=function(self,i)return self.progress[i]or 0 end
 o[hasName]=function(self,i)return self.complete[i]or false end
 o[changeName]=function(self,v)
  local i=self.current;self.progress[i]=(self.progress[i]or 0)+v
  if self.progress[i]>=self.costs[i]then self.complete[i]=true;self.current=-1 end
  -- Exercise the exact real re-entrancy hazard.
  if kind=='science'then Events.ResearchChanged.fire(0,self.current)else Events.CivicChanged.fire(0,self.current)end
 end
 return o
end
Players={};PlayerConfigurations={};PlayersVisibility={}
for id=0,1 do
 local p=properties({id=id,faith=10000,units=collection({}),cityList=collection({[0]=F.cities[id]}),science=research('science'),culture=research('culture')})
 function p:GetID()return self.id end;function p:IsTurnActive()return true end
 function p:GetCities()return self.cityList end;function p:GetUnits()return self.units end
 function p:GetTechs()return self.science end;function p:GetCulture()return self.culture end
 function p:GetReligion()return {GetFaithBalance=function()return p.faith end,ChangeFaithBalance=function(_,v)p.faith=p.faith+v end}end
 function p:GetDiplomacy()return {IsAtWarWith=function(_,target)return F.war==true and target~=p.id end}end
 function p.units:Create(kind,x,y)
  if F.failCreate then return nil end
  F.unitSerial=(F.unitSerial or 0)+1
  local u=properties({id=F.unitSerial,owner=p.id,kind=kind,x=x,y=y,moves=2})
  function u:GetID()return self.id end;function u:GetOwner()return self.owner end
  function u:GetType()return self.kind end;function u:GetX()return self.x end;function u:GetY()return self.y end
  function u:GetMovesRemaining()return self.moves end;function u:SetName(n)self.name=n end
  self.items[u.id]=u;return u
 end
 function p.units:Destroy(u)self.items[u.id]=nil end
 Players[id]=p
 PlayerConfigurations[id]={GetCivilizationTypeName=function()return id==0 and 'CIVILIZATION_MNS_MINOAN'or'CIVILIZATION_OTHER'end}
 PlayersVisibility[id]={IsVisible=function()return not F.hidden end}
end
PlayerManager={GetAliveMajorIDs=function()return{0,1}end}
F.plots={}
for i=0,5 do
 local plot={index=i,owner=i<3 and 0 or 1,improvement=0,pillaged=true}
 function plot:GetIndex()return self.index end;function plot:GetOwner()return self.owner end
 function plot:GetX()return self.index end;function plot:GetY()return 0 end
 function plot:GetFeatureType()return 0 end;function plot:GetTerrainType()return 0 end
 function plot:GetImprovementType()return self.improvement end;function plot:IsImprovementPillaged()return self.pillaged end
 function plot:IsWater()return false end;function plot:IsNaturalWonder()return false end;function plot:IsMountain()return false end
 function plot:IsCity()return self.index==0 or self.index==3 end
 F.plots[i]=plot
end
Map={GetPlotCount=function()return 6 end,GetPlotByIndex=function(i)return F.plots[i]end,GetPlot=function(x,y)return F.plots[x]end,
 GetPlotDistance=function(x,y,x2,y2)return math.abs(x-x2)end}
Cities={GetPlotPurchaseCity=function(plot)return F.cities[plot.owner]end}
RiverManager={GetRiverForFloodplain=function()return -1 end}
Units={GetUnitsInPlot=function(plot)
 local out={};for _,p in pairs(Players)do for _,u in p:GetUnits():Members()do if u.x==plot.index then out[#out+1]=u end end end;return out
end}
UnitManager={ChangeMovesRemaining=function(u,n)u.moves=u.moves+n end}
ImprovementBuilder={SetImprovementType=function(plot,t,owner)plot.improvement=t end,
 SetImprovementPillaged=function(plot,v)plot.pillaged=v end}
GameClimate={GetSeverityForLastSeaLevelEvent=function()return F.climateSeverity or 0 end,GetOneOffPlotsByID=function(id)return F.footprint or {1,2}end}
GameRandomEvents={ApplyEvent=function(params)
 F.lastApplied=copy(params)
 F.applyCount=F.applyCount+1;F.eventID=F.eventID+1
 local id=F.eventID;local plot=F.plots[params.Location]
 Events.RandomEventStarted.fire(params.EventType,0,plot:GetX(),0,0,id)
 if F.disasterDamage then F.disasterDamage()end
 Events.RandomEventOccurred.fire(params.EventType,0,plot:GetX(),0,0,id)
end}
-- The test drives native state explicitly. This is NOT an emulation of Civ VI's
-- establishment countdown or the SQL requirement/property engine.
function F.setEstablished(city, value)
 city:SetProperty('MNS_GovernorEstablished', value and 1 or 0)
 city.governor.IsEstablished = function() return value end
end
return F
