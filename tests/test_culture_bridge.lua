local root=arg[1] or '.'
dofile(root..'/tests/game_mock.lua')
local p=Players[0]
local culture=p.culture
culture.current=0
culture.progress[0]=5
culture.GetCulturalProgress=nil -- Match the real Gameplay API limitation.
local ui={current=0,progress={[0]=5,[1]=0}}
ExposedMembers=setmetatable({},{__index=function() error('Gameplay must not read local UI') end})
local writes=0
local native=culture.ChangeCurrentCulturalProgress
culture.ChangeCurrentCulturalProgress=function(self,amount)
    writes=writes+1
    native(self,amount)
end
local function load()
    for _,event in ipairs({'ResearchChanged','CivicChanged','RandomEventStarted','RandomEventOccurred'}) do
        Events[event].handlers={}
    end
    GameEvents.MNS_Action.handlers={}
    GameEvents.PlayerTurnStartComplete.handlers={}
    dofile(root..'/mods/minoan/Gameplay/MNS_Gameplay.lua')
end
local function flush()
    local s=p:GetProperty('MNS_Knowledge') or {}
    local r=s.pending
    local item=r and r.item or ui.current
    GameEvents.MNS_Action.fire(0,{Action='CultureSnapshot',CivicID=item,
        Progress=ui.progress[item] or 0,Turn=Game.GetCurrentGameTurn(),
        Revision=p:GetProperty('MNS_CultureRevision') or 0,
        Serial=r and (r.serial or 0) or (s.cultureSerial or 0)})
end
local function bank() return p:GetProperty('MNS_Knowledge') end
load()
p:SetProperty('MNS_Knowledge',{science=0,culture=59.5})
flush()
assert(writes==1 and culture:HasCivic(0))
assert(bank().culture==49.5 and bank().pending.amount==10)
flush() -- Completed civic acknowledges the reserved amount, even before UI catches up.
assert(not bank().pending and bank().culture==49.5)
culture.current=1
flush() -- UI still shows the previous civic: do not write to an unchecked target.
assert(writes==1)
ui.current=1
flush()
assert(writes==2 and culture.progress[1]==49 and bank().culture==0.5)
for i=1,5 do flush() end -- Stale UI must never refund and duplicate the payout.
assert(writes==2 and bank().pending.amount==49)
load() -- Reserved payout survives a script reload with the same saved state.
flush()
assert(writes==2 and bank().pending)
ui.progress[1]=49
flush()
assert(not bank().pending and bank().culture==0.5 and writes==2)
local s=bank();s.culture=s.culture+0.5;p:SetProperty('MNS_Knowledge',s)
flush()
assert(writes==3 and culture:HasCivic(1))
flush()
assert(bank().culture==0 and not bank().pending)
print('PASS synchronized culture snapshots: overflow, fractions, stale UI, reload and no duplicate payout')
