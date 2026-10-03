-- Read-only UI: execute-script requests contain IDs, never money/reward amounts.
include('MNS_World')
local W=MNS_World
local targets,selected,selectedUnit={},1,nil
local confirmPlot=nil
local collapsed=false
local refresh
local governorChecked, governorWarning = false, nil
-- FireTuner: select this UI context, then call MNS_CheckGovernors().
function MNS_CheckGovernors()
    local id = Game.GetLocalPlayer()
    if id == nil or id < 0 then return nil end
    local issues = W.governorRosterIssues(id)
    if issues == nil then return nil end
    governorChecked = true
    governorWarning = #issues > 0 and '总督替换检查失败：请勿继续正式档，详见 Lua.log。' or nil
    print('[MNS GOVERNORS] appointment filter: ' .. (#issues == 0 and 'PASS' or 'FAIL'))
    for _, message in ipairs(issues) do print('[MNS GOVERNORS] ' .. message) end
    for _, city in Players[id]:GetCities():Members() do
        local g = W.governor(city)
        local established = g and g.IsEstablished and g:IsEstablished() or false
        local marker = (tonumber(city:GetProperty('MNS_GovernorEstablished')) or 0) > 0
        print('[MNS GOVERNORS] city=' .. city:GetID() .. ' UI established=' .. tostring(established)
            .. ', native marker=' .. tostring(marker))
    end
    return #issues == 0
end
local function request(args)
    args.OnStart='MNS_Action'
    UI.RequestPlayerOperation(Game.GetLocalPlayer(),PlayerOperations.EXECUTE_SCRIPT,args)
end
local function buy(role)
    local city=UI.GetHeadSelectedCity()
    if city then request{Action='Buy',Role=role,CityID=city:GetID()} end
end
local function updateTarget()
    local plot=targets[selected]
    Controls.Target:SetText(plot and string.format('%d/%d  坐标(%d,%d)%s',selected,#targets,plot:GetX(),plot:GetY(),
        plot:IsCity() and '[NEWLINE]城市中心' or '') or '没有合法可见目标')
    Controls.Cast:SetDisabled(plot==nil)
    Controls.Previous:SetDisabled(#targets<2)
    Controls.Next:SetDisabled(#targets<2)
    Controls.CastText:SetText(confirmPlot and '再次点击：确认毁灭该地块！' or '在此祈灾 / 召唤彗星')
end
local function cast()
    local plot=targets[selected]
    local unit=UI.GetHeadSelectedUnit()
    if not plot or not unit then return end
    if W.unitRole(unit)=='Prophet' and confirmPlot~=plot:GetIndex() then
        confirmPlot=plot:GetIndex(); updateTarget(); return
    end
    request{Action='Cast',UnitID=unit:GetID(),PlotID=plot:GetIndex()}
    confirmPlot=nil
end
refresh=function()
    local id=Game.GetLocalPlayer()
    local p=Players[id]
    if not p or not W.minoan(id) then ContextPtr:SetHide(true); return end
    ContextPtr:SetHide(false)
    if not governorChecked then MNS_CheckGovernors() end
    local s=p:GetProperty('MNS_Knowledge') or {}
    local city=UI.GetHeadSelectedCity()
    local cityText=city and Locale.Lookup(city:GetName()) or '先选一座己方城市购买祭司'
    local protect=city and (W.protected(city) and ' · 庇护生效' or ' · 未受庇护') or ''
    Controls.Summary:SetText(string.format('%s%s[NEWLINE]知识储备：科学 %.2f / 文化 %.2f',cityText,protect,s.science or 0,s.culture or 0))
    for _,role in ipairs({'Oracle','Prophet'}) do
        local cost=W.price(p,role)
        Controls['Buy'..role..'Text']:SetText((role=='Oracle' and '神谕祭司' or '末日先知')..'  '..cost..' [ICON_Faith]')
        local can=city and city:GetOwner()==id and W.sanctuary(city) and W.unlocked(p,role)
            and p:GetReligion():GetFaithBalance()>=cost
            and (role~='Prophet' or W.cometAvailable()) and p:IsTurnActive()
        Controls['Buy'..role]:SetDisabled(not can)
    end
    local unit=UI.GetHeadSelectedUnit()
    local role=unit and W.unitRole(unit)
    local oldPlot=targets[selected] and targets[selected]:GetIndex()
    if not unit or unit:GetID()~=selectedUnit then confirmPlot=nil; oldPlot=nil end
    selectedUnit=unit and unit:GetID()
    targets={}; selected=1
    if role=='Oracle' or role=='Prophet' then
        local spec=W.roleSpec(role)
        Controls.UnitInfo:SetText((role=='Oracle' and '神谕祭司' or '末日先知')..' · 剩余 '..tostring(unit:GetProperty('MNS_Charges') or 0)..' 次[NEWLINE]距离 '..spec.range..' 格；目标起点不会自动居中镜头。')
        for i=0,Map.GetPlotCount()-1 do
            local plot=Map.GetPlotByIndex(i)
            if Map.GetPlotDistance(unit:GetX(),unit:GetY(),plot:GetX(),plot:GetY())<=spec.range then
                local ok=W.validateCast(id,unit,plot)
                if ok then
                    targets[#targets+1]=plot
                    if oldPlot==i then selected=#targets end
                end
            end
        end
    else Controls.UnitInfo:SetText('选中本面板购买的祭司后，切换下方目标地块。') end
    if confirmPlot and (not targets[selected] or targets[selected]:GetIndex()~=confirmPlot) then confirmPlot=nil end
    Controls.Status:SetText(governorWarning or p:GetProperty('MNS_Status') or '区域成本/倍率/价格均在 Config/Balance.sql 修改。')
    updateTarget()
end
local function step(delta)
    if #targets==0 then return end
    selected=((selected-1+delta)%#targets)+1
    confirmPlot=nil
    updateTarget()
    local plot=targets[selected]
    if UI.LookAtPlot then UI.LookAtPlot(plot) end
end
local function safeRefresh()
    local ok,err=pcall(refresh)
    if not ok then print('[MNS UI] '..tostring(err)) end
end
Controls.BuyOracle:RegisterCallback(Mouse.eLClick,function() buy('Oracle') end)
Controls.BuyProphet:RegisterCallback(Mouse.eLClick,function() buy('Prophet') end)
Controls.Cast:RegisterCallback(Mouse.eLClick,cast)
Controls.Previous:RegisterCallback(Mouse.eLClick,function() step(-1) end)
Controls.Next:RegisterCallback(Mouse.eLClick,function() step(1) end)
Controls.Toggle:RegisterCallback(Mouse.eLClick,function()
    collapsed=not collapsed
    Controls.Body:SetHide(collapsed)
    Controls.Panel:SetSizeY(collapsed and 44 or 430)
end)
Events.UnitSelectionChanged.Add(safeRefresh)
Events.CitySelectionChanged.Add(safeRefresh)
Events.LocalPlayerTurnBegin.Add(safeRefresh)
Events.GameCoreEventPublishComplete.Add(safeRefresh)
ContextPtr:SetInitHandler(safeRefresh)
