-- Reproduce queued callbacks with an integer-valued native progress setter.
-- This is a stress model, not evidence of the actual engine's numeric precision.
local root=arg[1] or '.'
dofile(root..'/tests/game_mock.lua')
local p=Players[0]
local queued,calls=0,0
p.science.current=1
p.science.ChangeCurrentResearchProgress=function(self,amount)
    calls=calls+1
    self.progress[1]=(self.progress[1] or 0)+math.floor(amount)
    queued=queued+1
end
dofile(root..'/mods/minoan/Gameplay/MNS_Gameplay.lua')
p:SetProperty('MNS_Knowledge',{science=4.41,culture=0})
Events.ResearchChanged.fire(0,1)
for i=1,10 do
    if queued==0 then break end
    queued=queued-1
    Events.ResearchChanged.fire(0,1)
end
assert(queued==0 and calls==1,'fractional refund keeps scheduling research callbacks')
assert(p.science.progress[1]==4)
assert(math.abs(p:GetProperty('MNS_Knowledge').science-0.41)<0.00001)
print('PASS fractional bank retained without repeated research mutation')
