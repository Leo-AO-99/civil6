-- Exercise the actual lens helper against an additive native-layer stand-in.
local root=arg[1] or '.'
local file=assert(io.open(root..'/mods/minoan/UI/MNS_Panel.lua','r'))
local source=file:read('*a');file:close()
local helper=source:match('(local targetLayer=.-)function MNS_CheckGovernors')
local cells,on,writes={},false,0
UILens={CreateLensLayerHash=function()return 1 end,
 IsLayerOn=function()return on end,
 ClearLayerHexes=function()cells={}end,
 ToggleLayerOff=function()on=false end,ToggleLayerOn=function()on=true end,
 SetLayerHexesArea=function(_,_,plots)writes=writes+1;for _,id in ipairs(plots)do cells[id]=true end end}
Game={GetLocalPlayer=function()return 0 end}
UI={LookAtPlot=function()end}
local hidden=false
Controls={TargetPicker={SetHide=function(_,value)hidden=value end}}
local highlight,close=assert(load(helper..' return highlightTarget,closePreview'))()
local function plot(i)return{GetIndex=function()return i end}end
highlight(plot(1));highlight(plot(1));assert(writes==1)
highlight(plot(2));assert(cells[2] and not cells[1])
close();assert(next(cells)==nil and not on and hidden)
close();highlight(plot(3));assert(cells[3] and not cells[2])
highlight(nil);assert(next(cells)==nil and not on)
print('PASS changing target clears old hex, unchanged refresh does not redraw, close clears lens')
