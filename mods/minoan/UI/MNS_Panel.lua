-- Extend native city/selected-unit controls; Gameplay validates every request.
include('MNS_World')
local W = MNS_World
local faithList, faithScroll, noFaithContent, actionStack, actionsParent
local targets, selected, selectedUnit = {}, 1, nil
local confirmPlot, pickerOpen, lastError = nil, false, nil
local governorChecked = false
local disasterChoices, disasterIndex, chosenEvent = {}, 1, nil
local targetLayer=UILens.CreateLensLayerHash('Hex_Coloring_Great_People')
local highlightedPlot=nil
local function highlightTarget(plot)
    local index=plot and plot:GetIndex() or nil
    if not index then
        if highlightedPlot~=nil then
            UILens.ClearLayerHexes(targetLayer)
            UILens.ToggleLayerOff(targetLayer)
            highlightedPlot=nil
        end
        return
    end
    if highlightedPlot==index and UILens.IsLayerOn(targetLayer) then return end
    UILens.ClearLayerHexes(targetLayer)
    UILens.SetLayerHexesArea(targetLayer,Game.GetLocalPlayer(),{index},{{'Great_People',index}})
    UILens.ToggleLayerOn(targetLayer)
    if highlightedPlot~=index then UI.LookAtPlot(plot) end
    highlightedPlot=index
end
local function closePreview()
    pickerOpen=false;confirmPlot=nil
    highlightTarget(nil)
    Controls.TargetPicker:SetHide(true)
end

function MNS_CheckGovernors()
    local id = Game.GetLocalPlayer()
    if id == nil or id < 0 then return nil end
    local issues = W.governorRosterIssues(id)
    if issues == nil then return nil end
    governorChecked = true
    print('[MNS GOVERNORS] variant availability: ' .. (#issues == 0 and 'PASS' or 'FAIL'))
    for _, message in ipairs(issues) do print('[MNS GOVERNORS] ' .. message) end
    return #issues == 0
end

local function attach()
    if not faithList then
        faithList = ContextPtr:LookUpControl('/InGame/ProductionPanel/PurchaseFaithList')
        if faithList then
            Controls.FaithPurchases:ChangeParent(faithList)
            faithScroll = ContextPtr:LookUpControl('/InGame/ProductionPanel/PurchaseFaithListScroll')
            noFaithContent = ContextPtr:LookUpControl('/InGame/ProductionPanel/NoFaithContent')
            print('[MNS UI] Faith purchase entries attached to ProductionPanel.')
        end
    end
    if not actionStack then
        actionStack = ContextPtr:LookUpControl('/InGame/UnitPanel/StandardActionsStack')
        local unitPanel = ContextPtr:LookUpControl('/InGame/UnitPanel')
        if actionStack and unitPanel then
            Controls.PriestAction:ChangeParent(actionStack)
            Controls.TargetPicker:ChangeParent(unitPanel)
            actionsParent = ContextPtr:LookUpControl('/InGame/UnitPanel/ActionsStack')
            print('[MNS UI] Priest action attached to UnitPanel.')
        else actionStack = nil end
    end
end

local function request(args)
    args.OnStart = 'MNS_Action'
    UI.RequestPlayerOperation(Game.GetLocalPlayer(), PlayerOperations.EXECUTE_SCRIPT, args)
end
local retiring={}
local function retireSpentUnits(player)
    if not player or not W.minoan(player:GetID()) or UI.IsGameCoreBusy() then return end
    for _,unit in player:GetUnits():Members() do
        local id=unit:GetID()
        if unit:GetProperty('MNS_Retire') and not retiring[id] then
            -- Selection must be cleared before gameplay deletes the object.
            retiring[id]=true
            local selected=UI.GetHeadSelectedUnit()
            if selected and selected:GetOwner()==player:GetID() and selected:GetID()==id then
                closePreview()
                UI.DeselectAllUnits()
            end
            request{Action='Retire',UnitID=id}
        end
    end
end

local function purchaseReason(player, city, role)
    if not city or city:GetOwner() ~= player:GetID() then return '请先选择己方城市。' end
    if not W.sanctuary(city) then return '需要已完成且未受损的峰顶圣所。' end
    if not W.unlocked(player, role) then
        local civic = GameInfo.Civics[W.setting(role .. 'UnlockCivic', '')]
        return '尚未解锁' .. (civic and Locale.Lookup(civic.Name) or '所需市政') .. '。'
    end
    if role == 'Prophet' and not W.cometAvailable() then return '当前规则集没有加载彗星灾害。' end
    if not player:IsTurnActive() then return '请在自己的回合购买。' end
    if player:GetReligion():GetFaithBalance() < W.price(player, role) then return '信仰不足。' end
end

local function buy(role)
    local id = Game.GetLocalPlayer()
    local player, city = Players[id], UI.GetHeadSelectedCity()
    if not player or not W.minoan(id) or purchaseReason(player, city, role) then return end
    Controls.PurchaseStatus:SetText('已请求购买，请留意城市中心。')
    request{Action='Buy', Role=role, CityID=city:GetID()}
end

local function refreshPurchases(player)
    local city = UI.GetHeadSelectedCity()
    local show = faithList ~= nil and player ~= nil and W.minoan(player:GetID())
        and city ~= nil and city:GetOwner() == player:GetID()
    Controls.FaithPurchases:SetHide(not show)
    if show then
        for _, role in ipairs({'Oracle', 'Prophet'}) do
            local button = Controls['Buy' .. role]
            local enabled = role ~= 'Prophet' or W.enabled('ProphetEnabled')
            button:SetHide(not enabled)
            if enabled then
                local reason = purchaseReason(player, city, role)
                Controls[role .. 'Cost']:SetText(W.price(player, role) .. ' [ICON_Faith]')
                Controls[role .. 'Icon']:SetIcon('ICON_' .. W.roleSpec(role).base)
                button:SetDisabled(reason ~= nil)
                button:SetToolTipString(reason or (role == 'Oracle'
                    and '购买神谕祭司：在己方领土祈求肥地灾害。'
                    or '购买末日先知：对交战文明的领土召唤彗星。'))
                button:SetAlpha(reason and 0.5 or 1)
            end
        end
        Controls.PurchaseStatus:SetText(player:GetProperty('MNS_PurchaseStatus') or '祭司需要城市中心没有其他平民或宗教单位。')
        Controls.FaithPurchases:CalculateSize()
        if noFaithContent then noFaithContent:SetHide(true) end
    end
    if faithList then faithList:CalculateSize(); faithList:ReprocessAnchoring() end
    if faithScroll then faithScroll:CalculateSize() end
end

local function updateTarget()
    local plot = targets[selected]
    highlightTarget(pickerOpen and plot or nil)
    local unit = UI.GetHeadSelectedUnit()
    disasterChoices = plot and unit and W.options(plot,W.unitRole(unit)=='Prophet') or {}
    disasterIndex=1
    for i,def in ipairs(disasterChoices) do if def.RandomEventType==chosenEvent then disasterIndex=i end end
    local disaster=disasterChoices[disasterIndex]
    chosenEvent=disaster and disaster.RandomEventType or nil
    Controls.DisasterName:SetText(disaster and (disasterIndex..'/'..#disasterChoices..' '..Locale.Lookup(disaster.Name or disaster.RandomEventType)) or '没有合法灾害')
    Controls.DisasterPrevious:SetDisabled(#disasterChoices<2)
    Controls.DisasterNext:SetDisabled(#disasterChoices<2)
    Controls.Target:SetText(plot and string.format('%d/%d  (%d,%d)%s', selected, #targets,
        plot:GetX(), plot:GetY(), plot:IsCity() and '[NEWLINE]城市中心 · 地图高亮格' or '[NEWLINE]地图高亮格') or '没有合法可见目标')
    local player=Players[Game.GetLocalPlayer()]
    Controls.Cast:SetDisabled(plot == nil or disaster == nil or (player and player:GetProperty('MNS_ScheduledCast')~=nil))
    Controls.Previous:SetDisabled(#targets < 2)
    Controls.Next:SetDisabled(#targets < 2)
    Controls.CastText:SetText(confirmPlot and '再次点击：确认召唤彗星'
        or (unit and W.unitRole(unit) == 'Prophet' and '预约下回合彗星' or '预约下回合祈灾'))
end

local function refreshUnit(player)
    local unit = UI.GetHeadSelectedUnit()
    local role = unit and W.unitRole(unit)
    local show = actionStack ~= nil and player ~= nil and W.minoan(player:GetID())
        and player:IsTurnActive() and not UI.IsGameCoreBusy()
        and unit ~= nil and unit:GetOwner() == player:GetID() and (role == 'Oracle' or role == 'Prophet')
    local key = show and (unit:GetOwner() .. ':' .. unit:GetID()) or nil
    if key ~= selectedUnit then pickerOpen = false; confirmPlot = nil; chosenEvent=nil end
    selectedUnit = key
    Controls.PriestAction:SetHide(not show)
    Controls.TargetPicker:SetHide(not show or not pickerOpen)
    if not show or not pickerOpen then highlightTarget(nil) end
    if actionStack then actionStack:CalculateSize(); actionStack:ReprocessAnchoring() end
    if actionsParent then actionsParent:CalculateSize(); actionsParent:ReprocessAnchoring() end
    if not show then return end
    Controls.PriestIcon:SetIcon('ICON_' .. W.roleSpec(role).base)
    Controls.PriestAction:SetToolTipString(role == 'Oracle' and '神谕祭司：选择地块祈灾' or '末日先知：选择彗星目标')
    if not pickerOpen then return end
    local spec = W.roleSpec(role)
    local oldPlot = targets[selected] and targets[selected]:GetIndex()
    targets = {}; selected = 1
    Controls.UnitInfo:SetText((role == 'Oracle' and '神谕祭司' or '末日先知') .. ' · 剩余 '
        .. tostring(unit:GetProperty('MNS_Charges') or 0) .. ' 次[NEWLINE]施法范围 ' .. spec.range .. ' 格')
    for i = 0, Map.GetPlotCount() - 1 do
        local plot = Map.GetPlotByIndex(i)
        if Map.GetPlotDistance(unit:GetX(), unit:GetY(), plot:GetX(), plot:GetY()) <= spec.range
            and W.validateCast(player:GetID(), unit, plot) then
            targets[#targets + 1] = plot
            if oldPlot == i then selected = #targets end
        end
    end
    if confirmPlot and (not targets[selected] or targets[selected]:GetIndex() ~= confirmPlot) then confirmPlot = nil end
    Controls.Status:SetText(player:GetProperty('MNS_Status') or '切换目标后点击施法。')
    updateTarget()
end

local function refresh()
    attach()
    local id = Game.GetLocalPlayer()
    local player = id ~= nil and id >= 0 and Players[id] or nil
    retireSpentUnits(player)
    refreshPurchases(player)
    refreshUnit(player)
    if player and W.minoan(id) and not governorChecked then
        local ok, err = pcall(MNS_CheckGovernors)
        if not ok then governorChecked = true; print('[MNS GOVERNORS] ' .. tostring(err)) end
    end
end
local function safeRefresh()
    local ok, err = pcall(refresh)
    if ok then lastError = nil; return end
    -- Fail closed: an error must never leave an unresponsive map overlay.
    Controls.FaithPurchases:SetHide(true)
    Controls.PriestAction:SetHide(true)
    Controls.TargetPicker:SetHide(true)
    highlightTarget(nil)
    if err ~= lastError then print('[MNS UI] ' .. tostring(err)); lastError = err end
end
local function step(delta)
    if #targets == 0 then return end
    selected = ((selected - 1 + delta) % #targets) + 1
    confirmPlot = nil
    chosenEvent = nil
    updateTarget()
    local plot = targets[selected]
    if UI.LookAtPlot then UI.LookAtPlot(plot) end
end
local function cast()
    local unit, plot = UI.GetHeadSelectedUnit(), targets[selected]
    if not unit or not plot or not chosenEvent then return end
    if W.unitRole(unit) == 'Prophet' and confirmPlot ~= plot:GetIndex() then
        confirmPlot = plot:GetIndex(); updateTarget(); return
    end
    request{Action='Cast', UnitID=unit:GetID(), PlotID=plot:GetIndex(), EventType=chosenEvent}
    confirmPlot = nil
    pickerOpen=false
    safeRefresh()
end
local function chooseDisaster(delta)
    if #disasterChoices==0 then return end
    disasterIndex=((disasterIndex-1+delta)%#disasterChoices)+1
    chosenEvent=disasterChoices[disasterIndex].RandomEventType
    confirmPlot=nil
    updateTarget()
end

Controls.BuyOracle:RegisterCallback(Mouse.eLClick, function() buy('Oracle') end)
Controls.BuyProphet:RegisterCallback(Mouse.eLClick, function() buy('Prophet') end)
Controls.PriestAction:RegisterCallback(Mouse.eLClick, function() pickerOpen = not pickerOpen; safeRefresh() end)
Controls.ClosePicker:RegisterCallback(Mouse.eLClick, closePreview)
Controls.Previous:RegisterCallback(Mouse.eLClick, function() step(-1) end)
Controls.Next:RegisterCallback(Mouse.eLClick, function() step(1) end)
Controls.Cast:RegisterCallback(Mouse.eLClick, cast)
Controls.DisasterPrevious:RegisterCallback(Mouse.eLClick,function()chooseDisaster(-1)end)
Controls.DisasterNext:RegisterCallback(Mouse.eLClick,function()chooseDisaster(1)end)
Events.UnitSelectionChanged.Add(safeRefresh)
Events.CitySelectionChanged.Add(safeRefresh)
Events.LocalPlayerTurnBegin.Add(safeRefresh)
Events.LocalPlayerTurnEnd.Add(closePreview)
Events.InterfaceModeChanged.Add(closePreview)
Events.UnitSelectionChanged.Add(closePreview)
Events.GameCoreEventPublishComplete.Add(safeRefresh)
Events.LoadGameViewStateDone.Add(safeRefresh)
ContextPtr:SetInitHandler(safeRefresh)
