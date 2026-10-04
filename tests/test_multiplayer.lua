-- Replay the same core events/operations with different local-player contexts.
-- This detects local-context dependencies, not real engine/network determinism.
local root=arg[1] or '.'
local F=dofile(root..'/tests/game_mock.lua')
GameConfiguration.IsAnyMultiplayer=function() return true end
Game.GetLocalPlayer=function() return tonumber(arg[2]) or 0 end
ExposedMembers=setmetatable({},{__index=function() error('local UI access in gameplay') end})
PlayerConfigurations[1].GetCivilizationTypeName=function()return 'CIVILIZATION_MNS_MINOAN'end
F.settings.AutoDisastersEnabled='1'
F.settings.AutoFirstTurn='8'
local randomCalls=0
Game.GetRandNum=function(n)randomCalls=randomCalls+1;return (randomCalls-1)%n end
dofile(root..'/mods/minoan/Gameplay/MNS_Gameplay.lua')
assert(#GameEvents.PlayerTurnStartComplete.handlers==1)
assert(#Events.PlayerTurnActivated.handlers==0)
local function action(id,args)GameEvents.MNS_Action.fire(id,args)end
for id=0,1 do
    F.cities[id].district.pillaged=false
    action(id,{Action='Buy',Role='Oracle',CityID=0})
    assert(Players[id].faith==9600)
end
local p=Players[0]
local u=p.units.items[1]
action(1,{Action='Cast',UnitID=u.id,PlotID=1})
assert(not Players[1]:GetProperty('MNS_ScheduledCast'))
action(0,{Action='Cast',UnitID=u.id,PlotID=1})
F.turn=1
GameEvents.PlayerTurnStartComplete.fire(0)
GameEvents.PlayerTurnStartComplete.fire(0)
assert(F.applyCount==1 and u:GetProperty('MNS_Charges')==1)
F.turn=8
GameEvents.PlayerTurnStartComplete.fire(0)
GameEvents.PlayerTurnStartComplete.fire(1)
assert(F.applyCount==3)
local culture=p.culture
culture.GetCulturalProgress=nil
culture.current=1
p:SetProperty('MNS_Knowledge',{science=0,culture=12.5})
local cmd={Action='CultureSnapshot',CivicID=1,Progress=0,Turn=7,Revision=0,Serial=0}
action(0,cmd);assert(not p:GetProperty('MNS_Knowledge').pending) -- Old turn.
cmd.Turn=8;cmd.Revision=99
action(0,cmd);assert(not p:GetProperty('MNS_Knowledge').pending) -- Old revision.
cmd.Revision=0;action(0,cmd)
assert(culture.progress[1]==12)
action(0,cmd);assert(culture.progress[1]==12) -- Replay cannot spend twice.
cmd.Serial=1;cmd.Progress=12;action(0,cmd)
assert(not p:GetProperty('MNS_Knowledge').pending)
assert(p:GetProperty('MNS_Knowledge').culture==0.5)
RESULT=table.concat({F.applyCount,randomCalls,Players[0].faith,Players[1].faith,
    Players[0]:GetProperty('MNS_NextDisasterTurn'),Players[1]:GetProperty('MNS_NextDisasterTurn'),
    culture.progress[1],p:GetProperty('MNS_Knowledge').culture},'|')
print('PASS multiplayer replay, two Minos players, core scheduling, ownership and duplicate guards')
