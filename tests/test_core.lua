local root=arg[1] or '.'
local C=dofile(root..'/mods/minoan/Gameplay/MNS_Core.lua')
local count=0
local function eq(a,b,msg)
    assert(a==b,(msg or 'not equal')..': '..tostring(a)..' ~= '..tostring(b))
end
local function test(name,f) f(); count=count+1; print('PASS '..name) end
test('reward uses yield, keeps fractions',function()
    local a,b=C.reward(41.5,50,25); eq(a,20.75); eq(b,10.375)
end)
test('negative faith cannot debit knowledge',function() local a,b=C.reward(-2,50,50); eq(a,0); eq(b,0) end)
test('withdraw caps at research remainder',function() local a,b=C.withdraw(40,100,85); eq(a,15);eq(b,25) end)
test('overflow stays when item complete',function() local a,b=C.withdraw(40,100,100);eq(a,0);eq(b,40) end)
test('small research rewards accumulate',function() local a,b=C.withdraw(.75,100,0);eq(a,.75);eq(b,0) end)
test('price ramps by purchases, not living units',function() eq(C.price(3000,1500,3),7500) end)
test('same disaster same city never pays twice',function()
    local s={}; local key={event=6,city=2}
    eq(C.credit(s,key,10,40,50,50,false,5,1),true)
    eq(C.credit(s,key,11,40,50,50,false,5,1),false);eq(s.science,20)
end)
test('one disaster may pay two affected cities',function()
    local s={};C.credit(s,{event=6,city=2},10,40,50,50,false,5,1)
    eq(C.credit(s,{event=6,city=3},10,20,50,50,false,5,1),true);eq(s.science,30)
end)
test('city-per-turn cap prevents burst spam',function()
    local s={}; C.credit(s,{event=6,city=2},10,40,50,50,false,5,1)
    eq(C.credit(s,{event=7,city=2},10,40,50,50,false,5,1),false);eq(s.science,20)
end)
test('fire spread with a new ID obeys cooldown',function()
    local s={}; C.credit(s,{event=6,city=2},10,40,50,50,true,5,1)
    eq(C.credit(s,{event=7,city=2},12,40,50,50,true,5,1),false)
    eq(C.credit(s,{event=8,city=2},15,40,50,50,true,5,1),true);eq(s.science,40)
end)
test('non-fire disasters bypass fire cooldown',function()
    local s={}; C.credit(s,{event=6,city=2},10,40,50,50,true,5,1)
    eq(C.credit(s,{event=7,city=2},11,40,50,50,false,5,1),true)
end)
local function valid()
 return {ours=true,active=true,charges=2,moves=2,alreadyCast=false,visible=true,distance=2,range=2,
         offensive=false,targetOwner=0,owner=0,atWar=false}
end
for field,val in pairs{ours=false,active=false,charges=0,moves=0,alreadyCast=true,visible=false,distance=3,targetOwner=1} do
 test('cast rejects invalid '..field,function() local v=valid();v[field]=val;eq(C.eligibleCast(v),false) end)
end
test('friendly ritual accepted',function() eq(C.eligibleCast(valid()),true) end)
test('offensive ritual requires war',function() local v=valid();v.offensive=true;v.targetOwner=1;eq(C.eligibleCast(v),false);v.atWar=true;eq(C.eligibleCast(v),true) end)
test('offensive ritual never targets own or neutral land',function() local v=valid();v.offensive=true;v.atWar=true;eq(C.eligibleCast(v),false);v.targetOwner=-1;eq(C.eligibleCast(v),false) end)
test('NaN/infinity settings use defaults',function()eq(C.number(0/0,2),2);eq(C.number(math.huge,2),2)end)
print(string.format('%d core tests passed',count))
