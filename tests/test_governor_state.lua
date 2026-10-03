-- Native engine state is supplied explicitly. These tests do not simulate
-- TransitionStrength, GovernorReplaces or SQL requirement evaluation.
local root=arg[1] or '.'
local F=dofile(root..'/tests/game_mock.lua')
dofile(root..'/mods/minoan/Gameplay/MNS_World.lua')
local W=MNS_World
local city=F.cities[0]
local count=0
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function test(name,fn) fn(); count=count+1; print('PASS '..name) end

test('nil city and absent native marker are not protected',function()
 eq(W.protected(nil),false);eq(W.protected(city),false)
end)

test('native getter returning no Lua values is not protected',function()
 local getter=city.GetProperty
 city.GetProperty=function()end
 eq(W.protected(city),false)
 city.GetProperty=getter
end)
test('old assignment timer never activates protection',function()
 F.turn=100;city:SetProperty('MNS_Assignment',{governor=99,turn=0})
 eq(W.protected(city),false)
end)
test('UI governor availability cannot override native marker',function()
 city.governor.IsEstablished=function()return true end
 eq(W.protected(city),false)
end)
test('native marker works without any UI-only governor getter',function()
 local getter=city.GetAssignedGovernor;city.GetAssignedGovernor=nil
 city:SetProperty('MNS_GovernorEstablished',1);eq(W.protected(city),true)
 city.GetAssignedGovernor=getter
end)
test('removal neutralization and transition markers revoke protection',function()
 -- Each is an explicit engine-provided state, not a simulated spy/assignment.
 for _,v in ipairs({0,'0',-1,'invalid'}) do
  city:SetProperty('MNS_GovernorEstablished',v);eq(W.protected(city),false)
 end
 city:SetProperty('MNS_GovernorEstablished',nil);eq(W.protected(city),false)
end)
test('serialization roundtrip retains active marker',function()
 city:SetProperty('MNS_GovernorEstablished','1');eq(W.protected(city),true)
 local saved=city:GetProperty('MNS_GovernorEstablished')
 city:SetProperty('MNS_GovernorEstablished',nil);eq(W.protected(city),false)
 city:SetProperty('MNS_GovernorEstablished',saved);eq(W.protected(city),true)
end)
test('other civilization never receives Minoan protection',function()
 F.cities[1]:SetProperty('MNS_GovernorEstablished',1)
 eq(W.protected(F.cities[1]),false)
end)
test('protection switch disables protection without changing native state',function()
 F.settings.ProtectionEnabled='0';eq(W.protected(city),false)
 eq(city:GetProperty('MNS_GovernorEstablished'),'1')
 F.settings.ProtectionEnabled='1';eq(W.protected(city),true)
end)
test('diagnostic absent outside supported UI returns unknown not pass',function()
 eq(W.governorRosterIssues(0),nil)
end)

local names={'THE_DEFENDER','THE_AMBASSADOR','THE_CARDINAL','THE_BUILDER',
 'THE_RESOURCE_MANAGER','THE_EDUCATOR','THE_MERCHANT'}
local rows={}
local governors,allowed,appointed={},{},{}
for i,n in ipairs(names) do
 local old,new='GOVERNOR_'..n,'GOVERNOR_MNS_'..n
 rows[i]={OriginalGovernorType=old,UniqueGovernorType=new}
 governors[old]={Hash=i};governors[new]={Hash=i+100}
 allowed[i]=false;allowed[i+100]=true
end
GameInfo.Governors=governors
GameInfo.MNS_GovernorReplacements=setmetatable({}, {__call=function()
 local i=0;return function()i=i+1;return rows[i]end
end})
local api={CanEverAppointGovernor=function(_,hash)return allowed[hash] or false end,
 HasGovernor=function(_,hash)return appointed[hash] or false end}
Players[0].GetGovernors=function()return api end
Players[1].GetGovernors=function()return api end

test('diagnostic accepts all seven one-to-one engine-filtered pairs',function()
 eq(#W.governorRosterIssues(0),0)
end)
test('diagnostic tolerates originals that are filtered by the native panel extension',function()
 for i=2,7 do allowed[i]=true end
 eq(#W.governorRosterIssues(0),0)
 for i=2,7 do allowed[i]=false end
end)
test('diagnostic detects unavailable clone',function()
 allowed[101]=false;eq(#W.governorRosterIssues(0),1);allowed[101]=true
end)
test('diagnostic rejects already-appointed original from old save',function()
 appointed[1]=true;eq(#W.governorRosterIssues(0),1);appointed[1]=false
end)
test('diagnostic catches variant leakage into other civilization',function()
 eq(#W.governorRosterIssues(1),7)
 for i=1,7 do allowed[i]=true;allowed[i+100]=false end
 eq(#W.governorRosterIssues(1),0)
end)
test('diagnostic does not count other civilization own unique replacements as an error',function()
 allowed[1]=false;eq(#W.governorRosterIssues(1),0)
end)
test('native panel hides original candidates only for Minos, preserving variants',function()
 local added=0
 include=function(name)eq(name,'GovernorPanel');AddGovernorCandidate=function()added=added+1 end end
 Game.GetLocalPlayer=function()return 0 end
 local leader='LEADER_MNS_MINOS'
 PlayerConfigurations[0].GetLeaderTypeName=function()return leader end
 for _,row in ipairs(rows)do GameInfo.MNS_GovernorReplacements[row.OriginalGovernorType]=row end
 dofile(root..'/mods/minoan/UI/MNS_GovernorPanel.lua')
 for _,row in ipairs(rows)do
  AddGovernorCandidate({GovernorType=row.OriginalGovernorType},true)
  AddGovernorCandidate({GovernorType=row.UniqueGovernorType},true)
 end
 eq(added,7)
 leader='LEADER_OTHER'
 for _,row in ipairs(rows)do AddGovernorCandidate({GovernorType=row.OriginalGovernorType},true)end
 eq(added,14)
end)
print(count..' governor state/diagnostic mock tests passed (not a game-runtime test)')
