-- Minoan Disasters, single-player development build. All gameplay writes live here.
include('MNS_Core')
include('MNS_World')
include('MNS_Protection')
local C, W, P = MNS_Core, MNS_World, MNS_Protection
local flushing = {}
local unavailableResearch = {}
local STATE = 'MNS_Knowledge'
local function log(text) print('[MNS] ' .. tostring(text)) end
local function disasterAudit(playerID, kind, detail)
    local player = Players[playerID]
    if not player then return end
    local audit = player:GetProperty('MNS_DisasterAudit') or {}
    audit[kind] = (audit[kind] or 0) + 1
    audit.lastTurn, audit.lastKind, audit.lastDetail = Game.GetCurrentGameTurn(), kind, detail
    player:SetProperty('MNS_DisasterAudit', audit)
    print(string.format('[MNS DISASTER] turn=%d player=%d %s #%d %s',
        audit.lastTurn, playerID, kind, audit[kind], detail or ''))
end
local function status(id,text)
    local p=Players[id]
    if p and p:GetProperty('MNS_Status')~=text then p:SetProperty('MNS_Status',text) end
    if W.n('LogLevel',1)>0 then log('P'..tostring(id)..': '..text) end
end
local function state(p)
    return p:GetProperty(STATE) or {science=0,culture=0,seen={},turnCounts={},fireTurns={}}
end
local function save(p,s) p:SetProperty(STATE,s) end
local function guard(label,fn)
    return function(...)
        local ok,err=pcall(fn,...)
        if not ok then log('ERROR '..label..': '..tostring(err)) end
    end
end

-- No arbitrary tech/civic is selected by the mod. Credit only what fits the selected item.
local function researchAdapter(player,kind)
    if kind=='science' then
        local o=player:GetTechs()
        return o, 'GetResearchingTech','GetResearchCost','GetResearchProgress','ChangeCurrentResearchProgress','HasTech'
    end
    local o=player:GetCulture()
    return o, 'GetProgressingCivic','GetCultureCost','GetCulturalProgress','ChangeCurrentCulturalProgress','HasCivic'
end
local function settlePending(player,s)
    local r=s.pending
    if not r then return end
    local o,_,_,progressName,_,hasName=researchAdapter(player,r.kind)
    if not o[progressName] then error('研究进度读取 API 不可用；保留待结算记录，不猜测余额。') end
    local accepted
    if o[hasName](o,r.item) then accepted=r.amount
    else accepted=math.min(r.amount,math.max(0,o[progressName](o,r.item)-r.before)) end
    s[r.kind]=(s[r.kind] or 0)+r.amount-accepted
    s.pending=nil
    save(player,s)
end
local function flushKind(player,kind)
    local s=state(player)
    settlePending(player,s)
    local bank=s[kind] or 0
    if bank<=0 then return end
    local o,currentName,costName,progressName,changeName=researchAdapter(player,kind)
    if not o[currentName] or not o[progressName] or not o[changeName] then
        -- A property write here can schedule another research/UI update forever.
        local key=player:GetID()..':'..kind
        if not unavailableResearch[key] then
            unavailableResearch[key]=true
            log(key..'进度API不可用，奖励保留在储备；本次加载仅提示一次。')
        end
        return
    end
    local item=o[currentName](o)
    if not item or item<0 then return end
    local before=o[progressName](o,item)
    local amount=C.withdraw(bank,o[costName](o,item),before)
    -- Keep fractional rewards in the bank. A rounded native write followed by
    -- an asynchronous ResearchChanged must not repeatedly refund/retry dust.
    amount=math.floor(amount)
    if amount<=0 then return end
    local left=bank-amount
    -- Reserve before mutating progress: completion callbacks can be re-entrant.
    s[kind]=left
    s.pending={kind=kind,item=item,before=before,amount=amount}
    save(player,s)
    local ok,err=pcall(o[changeName],o,amount)
    -- Read back, not a blind refund on exceptions: an API may partially apply first.
    settlePending(player,s)
    if not ok then error(err) end
end
local function flush(playerID)
    if not W.minoan(playerID) or flushing[playerID] then return end
    flushing[playerID]=true
    local ok,err=pcall(function()
        flushKind(Players[playerID],'science')
        flushKind(Players[playerID],'culture')
    end)
    flushing[playerID]=nil
    if not ok then status(playerID,'知识储备结算失败，记录保留：'..tostring(err)) end
end

local function eventKey(eventType,x,y,id)
    if id and id>=0 then return tostring(id) end
    return table.concat({Game.GetCurrentGameTurn(),eventType,x,y},'_')
end
local function onStarted(eventType,severity,x,y,mitigation,id)
    local def=GameInfo.RandomEvents[eventType]
    if not W.isNatural(def) then return end
    local snapshots=Game:GetProperty('MNS_DisasterSnapshots') or {}
    local key=eventKey(eventType,x,y,id)
    if not snapshots[key] then
        snapshots[key]=P.capture()
        Game:SetProperty('MNS_DisasterSnapshots',snapshots)
    end
end
local function consumeInvocation(pending)
    if pending.unitID then
        local player=Players[pending.playerID]
        local unit=player and player:GetUnits():FindID(pending.unitID)
        if unit and W.unitRole(unit)==pending.role then
            local charges=unit:GetProperty('MNS_Charges') or 0
            unit:SetProperty('MNS_Charges',math.max(0,charges-1))
            unit:SetProperty('MNS_LastCast',Game.GetCurrentGameTurn())
            UnitManager.ChangeMovesRemaining(unit,-unit:GetMovesRemaining())
            if charges<=1 then unit:SetProperty('MNS_Retire',true) end
        end
    end
    if not pending.unitID then
        disasterAudit(pending.playerID, 'confirmed', string.format('event=%s requested=(%d,%d)',
            tostring(pending.eventType), pending.x, pending.y))
    end
    Game:SetProperty('MNS_PendingInvocation',nil)
    status(pending.playerID,'灾害已确认触发。'..(pending.offensive and '彗星不产生科文返还。' or '已按受影响城市结算。'))
end
local function onOccurred(eventType,severity,x,y,mitigation,id)
    local def=GameInfo.RandomEvents[eventType]
    if not def then return end
    local key=eventKey(eventType,x,y,id)
    local pending=Game:GetProperty('MNS_PendingInvocation')
    local affectedPlots=W.affected(def,x,y,id)
    local matches=W.invocationMatches(pending,eventType,x,y,affectedPlots)
    if pending then
        log(string.format('EVENT event=%s at=(%s,%s) requested=%s at=(%s,%s) footprintMatch=%s',
            tostring(eventType),tostring(x),tostring(y),tostring(pending.eventType),
            tostring(pending.x),tostring(pending.y),tostring(matches)))
    end
    local snapshots=Game:GetProperty('MNS_DisasterSnapshots') or {}
    local before=snapshots[key] or (matches and pending.snapshots) or {}
    if W.isNatural(def) then
        -- This deliberately does not revive units, protect against comets or roll back terrain fertility.
        P.restore(before,affectedPlots)
        local oldFaith={}
        for _,s in ipairs(before) do oldFaith[s.owner..':'..s.id]=s.faith end
        local cities={}
        for _,index in ipairs(affectedPlots) do
            local city=W.plotCity(Map.GetPlotByIndex(index))
            if city and W.protected(city) then cities[city:GetOwner()..':'..city:GetID()]=city end
        end
        for cityKey,city in pairs(cities) do
            if not W.enabled('RewardRequiresSanctuary') or W.sanctuary(city) then
                local p=Players[city:GetOwner()]
                local s=state(p)
                local faith=oldFaith[cityKey] or city:GetYield(YieldTypes.FAITH)
                local paid,a,b=C.credit(s,{event=key,city=city:GetID()},Game.GetCurrentGameTurn(),faith,
                    W.n('ScienceRewardPercent',50,0),W.n('CultureRewardPercent',50,0),
                    W.eventFamily(def)=='fire',W.n('FireRewardCooldownTurns',5,0),W.n('RewardCityTurnCap',1,0))
                save(p,s)
                if paid then
                    status(city:GetOwner(),string.format('灾害奖励入库：科学 %.2f，文化 %.2f。',a,b))
                    flush(city:GetOwner())
                end
            end
        end
        if #before==0 and W.n('LogLevel',1)>0 then
            log('事件 '..key..' 无事前快照；不会用回合初人口代替灾前人口。请验证 RandomEventStarted 的游戏逻辑回调。')
        end
    end
    snapshots[key]=nil
    Game:SetProperty('MNS_DisasterSnapshots',snapshots)
    if matches then consumeInvocation(pending) end
end

local function invoke(playerID,plot,def,unit)
    if Game:GetProperty('MNS_PendingInvocation') then
        return false,'前一次灾害尚未收到原生确认，禁止重复施法。检查 Lua.log。'
    end
    if not GameRandomEvents or not GameRandomEvents.ApplyEvent then return false,'缺少风云变幻灾害 API。' end
    -- Final gameplay-side gate. Offensive authorization comes from the UNIT ROLE,
    -- never from an event that slipped into an automatic/Oracle candidate list.
    local offensive=unit ~= nil and W.unitRole(unit)=='Prophet'
    if (offensive and not W.isComet(def)) or (not offensive and not W.fertileFamily(def)) then
        return false,'事件不在该用途的白名单中，未提交灾害。'
    end
    local pending={playerID=playerID,eventType=def.Index,x=plot:GetX(),y=plot:GetY(),
                   turn=Game.GetCurrentGameTurn(),offensive=offensive,
                   snapshots=not offensive and P.capture() or {}}
    if unit then pending.unitID=unit:GetID(); pending.role=W.unitRole(unit) end
    local params={EventType=def.Index,Location=plot:GetIndex(),NamedRiver=-1,NamedVolcano=-1}
    if W.eventFamily(def)=='flood' then
        params.NamedRiver=RiverManager.GetRiverForFloodplain(plot:GetX(),plot:GetY())
        if not params.NamedRiver or params.NamedRiver<0 then
            return false,'目标已没有合法河流，未触发、未扣次数。'
        end
    elseif W.eventFamily(def)=='volcano' then
        local volcano=W.volcanoType(plot)
        if volcano==nil or volcano<0 then
            return false,'无法定位这座火山的原生编号，未触发、未扣次数；不会改在随机火山喷发。'
        end
        params.NamedVolcano=volcano
    end
    log(string.format('INVOKE event=%s target=(%d,%d) river=%d volcano=%d',
        def.RandomEventType,plot:GetX(),plot:GetY(),params.NamedRiver,params.NamedVolcano))
    -- Location is always explicit. No random fallback elsewhere in the world.
    if not unit then
        disasterAudit(playerID,'attempted', string.format('event=%s target=(%d,%d) plot=%d river=%d',
            def.RandomEventType,plot:GetX(),plot:GetY(),plot:GetIndex(),params.NamedRiver))
    end
    Game:SetProperty('MNS_PendingInvocation',pending)
    local ok,err=pcall(GameRandomEvents.ApplyEvent,params)
    if not ok then
        -- Keep the lock: a thrown native call may have partially applied. Never cast a second event automatically.
        status(playerID,'灾害调用报错，已锁定重试避免重复事件：'..tostring(err))
        if not unit then disasterAudit(playerID,'failed',tostring(err)) end
        return false,'灾害调用失败；请保留日志并重载施法前存档。'
    end
    if Game:GetProperty('MNS_PendingInvocation') then
        status(playerID,'已提交灾害，等待原生 RandomEventOccurred 确认；未扣次数。若不继续，请保留日志。')
    end
    return true
end

local function buy(playerID,cityID,role)
    if role~='Oracle' and role~='Prophet' then return false,'未知祭司类型。' end
    local p=Players[playerID]
    if not p or not W.minoan(playerID) or not p:IsTurnActive() then return false,'不是米诺斯的活动回合。' end
    if not W.unlocked(p,role) then return false,'尚未解锁该祭司。' end
    if role=='Prophet' and not W.cometAvailable() then return false,'当前规则集未加载彗星事件，禁止花费信仰。' end
    local city=W.city(playerID,cityID)
    if not city or not W.sanctuary(city) then return false,'请选择一座有已完成且未受损峰顶圣所的己方城市。' end
    local religion=p:GetReligion()
    local cost=W.price(p,role)
    if religion:GetFaithBalance()<cost then return false,'信仰不足。' end
    -- Avoid creating into an occupied civilian/religious slot.
    local occupied=Units.GetUnitsInPlot(Map.GetPlot(city:GetX(),city:GetY()))
    for _,u in ipairs(occupied or {}) do
        local d=GameInfo.Units[u:GetTypeHash()]
        if d and (d.Combat or 0)==0 and (d.RangedCombat or 0)==0 then
            return false,'请先移走城市中心的平民/宗教单位。'
        end
    end
    local spec=W.roleSpec(role)
    local def=GameInfo.Units[spec.base]
    if not def then return false,'基础单位数据未加载。' end
    local unit=UnitManager.InitUnit(playerID,spec.base,city:GetX(),city:GetY())
    if not unit then return false,'单位创建失败，没有扣费。' end
    local initialized,initError=pcall(function()
        unit:SetProperty('MNS_Role',role)
        unit:SetProperty('MNS_Charges',spec.charges)
        -- Gameplay has no Unit:SetName on this build. The custom UI labels the role.
        UnitManager.ChangeMovesRemaining(unit,spec.moves-unit:GetMovesRemaining())
    end)
    if not initialized then
        UnitManager.Kill(unit)
        log('购买初始化失败，撤销新单位：'..tostring(initError))
        return false,'祭司初始化失败，没有扣费。'
    end
    religion:ChangeFaithBalance(-cost)
    p:SetProperty('MNS_Bought_'..role,(p:GetProperty('MNS_Bought_'..role) or 0)+1)
    return true,'祭司已购买；选中它，点击单位操作区的祭司按钮施法。'
end
local function cast(playerID,unitID,plotID,eventType)
    local p=Players[playerID]
    local unit=p and p:GetUnits():FindID(unitID)
    local plot=Map.GetPlotByIndex(plotID)
    local ok,err=W.validateCast(playerID,unit,plot)
    if not ok then return false,err end
    if p:GetProperty('MNS_ScheduledCast') or Game:GetProperty('MNS_PendingInvocation') then
        return false,'已有预约或灾害正在处理，请完成后再预约。'
    end
    local choices=W.options(plot,W.unitRole(unit)=='Prophet')
    local def
    for _,choice in ipairs(choices) do
        if choice.RandomEventType==eventType or (eventType==nil and #choices==1) then def=choice;break end
    end
    if not def or (W.unitRole(unit)~='Prophet' and not W.fertileFamily(def)) then
        return false,'请选择该地块当前合法的灾害。'
    end
    p:SetProperty('MNS_ScheduledCast',{unitID=unitID,plotID=plotID,eventType=def.RandomEventType,
        role=W.unitRole(unit),dueTurn=Game.GetCurrentGameTurn()+1})
    UnitManager.ChangeMovesRemaining(unit,-unit:GetMovesRemaining())
    return true,'已预约下一回合在所选地块触发所选灾害；本回合移动力已用尽，成功确认后扣次数。'
end
local function runScheduled(playerID,now)
    local p=Players[playerID]
    local job=p:GetProperty('MNS_ScheduledCast')
    if not job or now<job.dueTurn then return false end
    -- Remove before any native callback: loading or re-entry must not cast twice.
    p:SetProperty('MNS_ScheduledCast',nil)
    local unit=p:GetUnits():FindID(job.unitID)
    local plot=Map.GetPlotByIndex(job.plotID)
    local ok,reason=W.validateCast(playerID,unit,plot)
    local def
    if ok and W.unitRole(unit)==job.role then
        for _,choice in ipairs(W.options(plot,job.role=='Prophet')) do
            if choice.RandomEventType==job.eventType then def=choice;break end
        end
    end
    if not def then
        status(playerID,'预约取消，未扣次数：'..(reason or '目标条件或所选灾害已变化。'))
        return true
    end
    log('SCHEDULED turn='..now..' event='..job.eventType..' plot='..job.plotID)
    local applied,message=invoke(playerID,plot,def,unit)
    if not applied then status(playerID,message) end
    return true
end
local function request(playerID,args)
    -- UI sends identifiers only; faith, charges, unlocks, war, visibility and distance are re-read here.
    if type(args)~='table' or not W.minoan(playerID) then return end
    -- These UI helpers can be absent in the gameplay Lua context.
    if (GameConfiguration.IsAnyMultiplayer and GameConfiguration.IsAnyMultiplayer())
        or (GameConfiguration.IsHotseat and GameConfiguration.IsHotseat()) then
        status(playerID,'本开发版暂不支持联机/热座，未执行操作。'); return
    end
    local ok,message
    if args.Action=='Retire' then
        local id=tonumber(args.UnitID)
        local unit=id and Players[playerID]:GetUnits():FindID(id)
        local role=W.unitRole(unit)
        if unit and unit:GetOwner()==playerID and (role=='Oracle' or role=='Prophet')
            and unit:GetProperty('MNS_Retire') and (unit:GetProperty('MNS_Charges') or 0)<=0 then
            UnitManager.Kill(unit)
        end
        return
    elseif args.Action=='Buy' then ok,message=buy(playerID,tonumber(args.CityID),args.Role)
    elseif args.Action=='Cast' then
        local uid,pid=tonumber(args.UnitID),tonumber(args.PlotID)
        if not uid or not pid or pid<0 or pid>=Map.GetPlotCount() then return end
        if args.EventType~=nil and type(args.EventType)~='string' then return end
        ok,message=cast(playerID,uid,pid,args.EventType)
    else return end
    if message then
        local text=(ok and '' or '未执行：')..message
        status(playerID,text)
        if args.Action=='Buy' then Players[playerID]:SetProperty('MNS_PurchaseStatus',text) end
    end
end
local function turn(playerID)
    if not W.minoan(playerID) then return end
    flush(playerID)
    local p=Players[playerID]
    local now=Game.GetCurrentGameTurn()
    if p:GetProperty('MNS_LastTurn')==now then return end
    p:SetProperty('MNS_LastTurn',now)
    -- Restore configured movement budget only for our scripted unit variants.
    for _,u in p:GetUnits():Members() do
        local role=W.unitRole(u)
        if (role=='Oracle' or role=='Prophet') and not u:GetProperty('MNS_Retire') then
            UnitManager.ChangeMovesRemaining(u,W.roleSpec(role).moves-u:GetMovesRemaining())
        end
    end
    local pending=Game:GetProperty('MNS_PendingInvocation')
    if pending and now > pending.turn then
        -- Missing target confirmation must not permanently block future casts.
        -- Do not spend a charge or replay the old request; auto keeps its schedule.
        if pending.unitID then
            status(pending.playerID,'上次预约未在目标处得到确认，已解除等待，未扣次数；请重新选择目标。')
        else
            disasterAudit(pending.playerID,'unconfirmed',string.format('submittedTurn=%d event=%s target=(%d,%d)',
                pending.turn,tostring(pending.eventType),pending.x,pending.y))
        end
        Game:SetProperty('MNS_PendingInvocation',nil)
        pending=nil
    end
    if pending then return end
    if runScheduled(playerID,now) then return end
    if not W.enabled('AutoDisastersEnabled') then return end
    local nextTurn=p:GetProperty('MNS_NextDisasterTurn') or W.n('AutoFirstTurn',8,0)
    if now<nextTurn then return end
    local lo=math.floor(W.n('AutoMinTurns',2,1))
    local hi=math.floor(W.n('AutoMaxTurns',3,lo))
    p:SetProperty('MNS_NextDisasterTurn',now+lo+Game.GetRandNum(hi-lo+1,'MNS interval'))
    local preferred,others={},{}
    for i=0,Map.GetPlotCount()-1 do
        local plot=Map.GetPlotByIndex(i)
        if plot:GetOwner()==playerID then
            local opts=W.options(plot,false)
            if #opts>0 then
                local city=W.plotCity(plot)
                local list=city and W.protected(city) and preferred or others
                list[#list+1]={plot=plot,opts=opts}
            end
        end
    end
    local candidates
    if W.enabled('AutoPreferProtected') and #preferred>0 then candidates=preferred
    else
        candidates=others
        for _,entry in ipairs(preferred) do candidates[#candidates+1]=entry end
    end
    if #candidates==0 then
        disasterAudit(playerID,'skipped','no eligible owned tile')
        status(playerID,'本次没有合法肥地灾害起点，跳过；不退回龙卷风、陨石或其他毁地事件。'); return
    end
    local entry=candidates[Game.GetRandNum(#candidates,'MNS owned plot')+1]
    local def=entry.opts[Game.GetRandNum(#entry.opts,'MNS automatic event')+1]
    local ok, message=invoke(playerID,entry.plot,def,nil)
    if not ok then disasterAudit(playerID,'rejected',message); status(playerID,message) end
end

-- Explicit diagnostics; registration alone does not prove the game's callback timing.
local function initialize()
    -- Gameplay may not expose the multiplayer helpers available to UI scripts.
    if (GameConfiguration.IsAnyMultiplayer and GameConfiguration.IsAnyMultiplayer())
        or (GameConfiguration.IsHotseat and GameConfiguration.IsHotseat()) then
        log('此版本仅支持单人；Gameplay脚本未启用。'); return
    end
    if not GameInfo.MNS_Settings then log('ERROR: MNS_Settings 不存在；检查 Database.log。'); return end
    Events.PlayerTurnActivated.Add(guard('PlayerTurnActivated',turn))
    Events.ResearchChanged.Add(guard('ResearchChanged',flush))
    Events.CivicChanged.Add(guard('CivicChanged',flush))
    Events.RandomEventStarted.Add(guard('RandomEventStarted',onStarted))
    Events.RandomEventOccurred.Add(guard('RandomEventOccurred',onOccurred))
    GameEvents.MNS_Action.Add(guard('MNS_Action',request))
    log('Loaded Alpha 4: native structure protection; population-only compensation; closed cultivation pool. Comet records='..tostring(W.cometAvailable())..'; in-game validation required.')
end
initialize()
