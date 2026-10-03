-- Game-facing read helpers. Shared by UI and gameplay; no mutations here.
include('MNS_Core')
MNS_World = {}
local W = MNS_World
local C = MNS_Core

function W.setting(name, fallback)
    local row = GameInfo.MNS_Settings and GameInfo.MNS_Settings[name]
    return row and row.Value or fallback
end
function W.n(name, fallback, low, high)
    return C.number(W.setting(name, fallback), fallback, low, high)
end
function W.enabled(name) return W.n(name, 0) ~= 0 end
function W.minoan(id)
    return PlayerConfigurations[id] and
        PlayerConfigurations[id]:GetCivilizationTypeName() == 'CIVILIZATION_MNS_MINOAN'
end
function W.city(playerID, cityID)
    local p = Players[playerID]
    return p and p:GetCities():FindID(cityID) or nil
end
function W.plotCity(plot)
    if not plot or plot:GetOwner() < 0 then return nil end
    return Cities.GetPlotPurchaseCity(plot)
end
function W.sanctuary(city)
    local def = GameInfo.Districts['DISTRICT_MNS_SANCTUARY']
    if not def or not city then return false end
    local districts, d = city:GetDistricts(), nil
    if districts.GetDistrictLocation and districts.GetDistrictAtLocation then
        -- Gameplay exposes location-based district lookup (BlackDeathScenario).
        -- Its GetDistrict(string) does not behave like the UI method.
        local x, y = districts:GetDistrictLocation(def.Index)
        if x and y and x >= 0 and y >= 0 then d = districts:GetDistrictAtLocation(x, y) end
    else
        d = districts:GetDistrict(def.DistrictType)
    end
    return d and d:IsComplete() and not d:IsPillaged() or false
end
function W.governor(city)
    -- Do not guess a governor from city proximity or historical assignment.
    if not city.GetAssignedGovernor then return nil end
    return city:GetAssignedGovernor()
end
function W.protected(city)
    if not city or not W.enabled('ProtectionEnabled') or not W.minoan(city:GetOwner()) then return false end
    -- Set and removed by the native, non-Permanent trait modifier. Never write
    -- this property in Lua, and never infer establishment from elapsed turns.
    return (tonumber(city:GetProperty('MNS_GovernorEstablished') or 0) or 0) > 0
end

-- Check variant availability. This engine also allows originals; the native
-- GovernorPanel extension hides those candidates for Minos. nil means UI not ready.
function W.governorRosterIssues(playerID)
    local player = Players[playerID]
    if not player or not player.GetGovernors or not GameInfo.MNS_GovernorReplacements then return nil end
    local governors = player:GetGovernors()
    if not governors or not governors.CanEverAppointGovernor then return nil end
    local issues, count = {}, 0
    local ours = W.minoan(playerID)
    for row in GameInfo.MNS_GovernorReplacements() do
        count = count + 1
        local old = GameInfo.Governors[row.OriginalGovernorType]
        local new = GameInfo.Governors[row.UniqueGovernorType]
        if not old or not new then
            issues[#issues+1] = 'Missing governor definition: ' .. row.UniqueGovernorType
        else
            local originalAllowed = governors:CanEverAppointGovernor(old.Hash)
            local uniqueAllowed = governors:CanEverAppointGovernor(new.Hash)
            if ours and not uniqueAllowed then
                issues[#issues+1] = row.OriginalGovernorType .. ': original=' .. tostring(originalAllowed)
                    .. ', minoan=' .. tostring(uniqueAllowed) .. ' (Minoan candidate must be available)'
            elseif not ours and uniqueAllowed then
                issues[#issues+1] = 'Minoan governor available to another civilization: ' .. row.UniqueGovernorType
            end
            -- Already-appointed originals indicate an old save or failed replacement.
            if ours and governors.HasGovernor and governors:HasGovernor(old.Hash) then
                issues[#issues+1] = 'Original already appointed; start a new game: ' .. row.OriginalGovernorType
            end
        end
    end
    if count ~= 7 then issues[#issues+1] = 'Expected seven governor pairs; found ' .. count end
    return issues
end
function W.unitRole(unit)
    return unit and unit:GetProperty('MNS_Role') or nil
end
function W.invocationMatches(pending, eventType, x, y, affected)
    if not pending or pending.eventType ~= eventType then return false end
    if pending.x == x and pending.y == y then return true end
    local family=W.eventFamily(GameInfo.RandomEvents[eventType])
    if family=='volcano' or family=='comet' then return false end
    -- Flood callbacks can identify another tile of the same river.
    local requested = Map.GetPlot(pending.x, pending.y)
    for _, plotID in ipairs(affected or {}) do
        if requested and requested:GetIndex() == plotID then return true end
    end
    return false
end
function W.price(player, role)
    local count = player:GetProperty('MNS_Bought_' .. role) or 0
    return C.price(W.n(role .. 'FaithCost', 0, 0), W.n(role .. 'CostIncrease', 0, 0), count)
end
function W.unlocked(player, role)
    if role == 'Prophet' and not W.enabled('ProphetEnabled') then return false end
    local name = W.setting(role .. 'UnlockCivic', '')
    if name == '' then return true end
    local row = GameInfo.Civics[name]
    return row and player:GetCulture():HasCivic(row.Index) or false
end
local function feature(plot)
    local row = GameInfo.Features[plot:GetFeatureType()]
    return row and row.FeatureType or ''
end
local function terrain(plot)
    local row = GameInfo.Terrains[plot:GetTerrainType()]
    return row and row.TerrainType or ''
end
function W.eventFamily(def)
    local s = def and def.RandomEventType or ''
    if s:find('COMET') then return 'comet' end
    if s:find('FOREST_FIRE') or s:find('JUNGLE_FIRE') then return 'fire' end
    if s:find('VOLCAN') then return 'volcano' end
    if s:find('FLOOD') and not s:find('COASTAL') then return 'flood' end
    if s:find('TORNADO') then return 'tornado' end
    if s:find('BLIZZARD') then return 'blizzard' end
    if s:find('SANDSTORM') or s:find('DUST_STORM') then return 'sandstorm' end
    if s:find('HURRICANE') then return 'hurricane' end
    if s:find('DROUGHT') then return 'drought' end
    return nil
end
function W.isNatural(def)
    local f = W.eventFamily(def)
    return f ~= nil and f ~= 'comet'
end
-- Closed list: never enroll events merely because their names contain FLOOD,
-- VOLCANO or FIRE. In particular, unit-triggered versions can lack fertility.
-- Hurricanes are intentionally out of this land-only cultivation pool.
local FERTILE_EVENTS = {
    RANDOM_EVENT_FLOOD_MODERATE = 'flood',
    RANDOM_EVENT_FLOOD_MAJOR = 'flood',
    RANDOM_EVENT_FLOOD_1000_YEAR = 'flood',
    RANDOM_EVENT_VOLCANO_GENTLE = 'volcano',
    RANDOM_EVENT_VOLCANO_CATASTROPHIC = 'volcano',
    RANDOM_EVENT_VOLCANO_MEGACOLOSSAL = 'volcano',
    RANDOM_EVENT_FOREST_FIRE = 'forest',
    RANDOM_EVENT_JUNGLE_FIRE = 'jungle',
    RANDOM_EVENT_DUST_STORM_GRADIENT = 'sandstorm',
    RANDOM_EVENT_DUST_STORM_HABOOB = 'sandstorm',
    RANDOM_EVENT_BLIZZARD_SIGNIFICANT = 'blizzard',
    RANDOM_EVENT_BLIZZARD_CRIPPLING = 'blizzard'
}
local OPERATORS = {flood='FLOODPLAIN', volcano='VOLCANO', forest='FIRE',
                   jungle='FIRE', sandstorm='STORM', blizzard='STORM'}
local function flag(value) return value == true or (tonumber(value) or 0) ~= 0 end
function W.isComet(def)
    return def ~= nil and def.EffectOperatorType == 'COMET_STRIKE' and
        (def.RandomEventType == 'RANDOM_EVENT_COMET_STRIKE' or
         def.RandomEventType == 'RANDOM_EVENT_COMET_STRIKE_TARGETED')
end
function W.climateAllowsFertility(family)
    if family ~= 'flood' and family ~= 'sandstorm' and family ~= 'blizzard' then return true end
    -- Late climate stages can HALT fertility or strip it. Never choose a known
    -- non-fertilizing flood/storm just to keep the automatic schedule running.
    if not GameClimate or not GameClimate.GetSeverityForLastSeaLevelEvent then return false end
    local severity = tonumber(GameClimate.GetSeverityForLastSeaLevelEvent())
    if not severity then return false end
    for row in GameInfo.RandomEvents() do
        if row.EffectOperatorType == 'SEA_LEVEL' and tonumber(row.Severity) and
           tonumber(row.Severity) <= severity then
            if family == 'flood' and flag(row.HaltsFloodFertility) then return false end
            if family ~= 'flood' and (flag(row.HaltsStormFertility) or
               (tonumber(row.FertilityRemovalChance) or 0) > 0) then return false end
        end
    end
    return true
end
function W.fertileFamily(def)
    local family = def and FERTILE_EVENTS[def.RandomEventType]
    if not family or def.EffectOperatorType ~= OPERATORS[family] then return nil end
    if (def.NaturalWonder and def.NaturalWonder ~= '') or flag(def.Global) or
       flag(def.IceLoss) or flag(def.HaltsFloodFertility) or flag(def.HaltsStormFertility) or
       (tonumber(def.FertilityRemovalChance) or 0) > 0 then return nil end
    -- Check the actual loaded database, not only a remembered event name.
    -- Fire's positive yields occur on later recovery turns; Amount=0 alone is NOT fertility.
    if not GameInfo.RandomEvent_Yields then return nil end
    local positive = false
    for row in GameInfo.RandomEvent_Yields() do
        if row.RandomEventType == def.RandomEventType then
            local amount, chance = tonumber(row.Amount) or 0, tonumber(row.Percentage) or 0
            if amount < 0 then return nil end
            if amount > 0 and chance > 0 and
               (row.YieldType == 'YIELD_FOOD' or row.YieldType == 'YIELD_PRODUCTION') then
                positive = true
            end
        end
    end
    return positive and W.climateAllowsFertility(family) and family or nil
end
function W.options(plot, offensive)
    local out = {}
    if not plot or plot:IsWater() or plot:IsNaturalWonder() then return out end
    local f, t = feature(plot), terrain(plot)
    for def in GameInfo.RandomEvents() do
        local family = not offensive and W.fertileFamily(def) or nil
        local valid = false
        if offensive then
            valid = W.isComet(def) and (W.enabled('CometAllowsCityCenter') or not plot:IsCity())
                and (not flag(def.TargetCities) or plot:IsCity())
        elseif family == 'volcano' and W.enabled('VolcanoEnabled') then
            valid = f == 'FEATURE_VOLCANO'
        elseif (family == 'forest' or family == 'jungle') and W.enabled('FireEnabled') then
            valid = (family == 'forest' and f == 'FEATURE_FOREST') or
                    (family == 'jungle' and f == 'FEATURE_JUNGLE')
        elseif family == 'flood' and W.enabled('FloodEnabled') then
            valid = (f == 'FEATURE_FLOODPLAINS' or f == 'FEATURE_FLOODPLAINS_GRASSLAND' or
                     f == 'FEATURE_FLOODPLAINS_PLAINS') and
                     RiverManager.GetRiverForFloodplain(plot:GetX(), plot:GetY()) >= 0
        elseif W.enabled('StormEnabled') and not plot:IsMountain() and not plot:IsCity() then
            if family == 'sandstorm' and W.enabled('DustStormEnabled') then
                valid = t == 'TERRAIN_DESERT' or t == 'TERRAIN_DESERT_HILLS'
            elseif family == 'blizzard' and W.enabled('BlizzardEnabled') then
                valid = t == 'TERRAIN_SNOW' or t == 'TERRAIN_SNOW_HILLS' or
                        t == 'TERRAIN_TUNDRA' or t == 'TERRAIN_TUNDRA_HILLS'
            end
        end
        if valid then out[#out + 1] = def end
    end
    table.sort(out, function(a,b) return a.Index < b.Index end)
    return out
end
function W.volcanoType(plot)
    if not plot or not MapFeatureManager or not MapFeatureManager.GetNamedVolcanoes
        or not GameInfo.NamedVolcanoes then return nil end
    -- Native MapLabelManager exposes coordinates and Name in these records.
    for _,volcano in pairs(MapFeatureManager.GetNamedVolcanoes() or {}) do
        if volcano.PlotX==plot:GetX() and volcano.PlotY==plot:GetY() then
            for def in GameInfo.NamedVolcanoes() do
                if def.Name==volcano.Name or (Locale and Locale.Lookup and Locale.Lookup(def.Name)==volcano.Name) then
                    return def.Index
                end
            end
        end
    end
end
function W.cometAvailable()
    for d in GameInfo.RandomEvents() do
        if W.isComet(d) then return true end
    end
    return false
end
function W.roleSpec(role)
    return {charges=W.n(role .. 'Charges',1,1), range=W.n(role .. 'Range',2,0),
            moves=W.n(role .. 'Moves',2,0), base=W.setting(role .. 'BaseUnit','UNIT_MISSIONARY')}
end
function W.validateCast(playerID, unit, plot)
    if not unit or not plot then return false, '单位或目标已不存在。' end
    local role = W.unitRole(unit)
    if role ~= 'Oracle' and role ~= 'Prophet' then return false, '未选中米诺斯祭司。' end
    local player = Players[playerID]
    local targetOwner = plot:GetOwner()
    local vis = PlayersVisibility[playerID]
    local spec = W.roleSpec(role)
    local ok, reason = C.eligibleCast {
        ours=W.minoan(playerID) and unit:GetOwner() == playerID,
        active=player:IsTurnActive(),
        charges=unit:GetProperty('MNS_Charges') or 0,
        moves=unit:GetMovesRemaining(),
        alreadyCast=unit:GetProperty('MNS_LastCast') == Game.GetCurrentGameTurn(),
        visible=vis and vis:IsVisible(plot:GetX(),plot:GetY()),
        distance=Map.GetPlotDistance(unit:GetX(),unit:GetY(),plot:GetX(),plot:GetY()),
        range=spec.range, offensive=role == 'Prophet', targetOwner=targetOwner, owner=playerID,
        atWar=targetOwner >= 0 and player:GetDiplomacy():IsAtWarWith(targetOwner)
    }
    if not ok then return false, reason end
    if #W.options(plot, role == 'Prophet') == 0 then
        return false, role == 'Prophet' and '彗星数据未加载或目标不合法；请检查天启内容。' or '这个地块没有符合白名单且有增产数据的肥地灾害。'
    end
    return true
end
-- Resolve actual footprints using native event-specific APIs, not a guessed radius.
function W.affected(def, x, y, eventID)
    local origin=x and y and Map.GetPlot(x,y)
    if not origin then return {} end
    local f = W.eventFamily(def)
    local plots
    if f == 'flood' and RiverManager and RiverManager.GetRiverForFloodplain and RiverManager.GetFloodplainPlots then
        local river = RiverManager.GetRiverForFloodplain(x,y)
        if river and river >= 0 then plots = RiverManager.GetFloodplainPlots(river) end
    elseif def.EffectOperatorType == 'STORM' and GameClimate and GameClimate.GetActiveStormIDAtPlot and GameClimate.GetStormPlotsByID then
        local storm = GameClimate.GetActiveStormIDAtPlot(x,y)
        if storm and storm >= 0 then plots = GameClimate.GetStormPlotsByID(storm) end
    elseif f == 'drought' and GameClimate and GameClimate.GetActiveDroughtIDAtPlot and GameClimate.GetDroughtPlotsByID then
        local drought = GameClimate.GetActiveDroughtIDAtPlot(x,y)
        if drought and drought >= 0 then plots = GameClimate.GetDroughtPlotsByID(drought) end
    end
    if not plots or #plots == 0 then
        if eventID and eventID>=0 and GameClimate and GameClimate.GetOneOffPlotsByID then plots = GameClimate.GetOneOffPlotsByID(eventID) end
    end
    -- Safe conservative fallback: report only the start tile, never an invented blast radius.
    if not plots or #plots == 0 then plots = {origin:GetIndex()} end
    local ids, seen = {}, {}
    for _,v in ipairs(plots) do
        local id = type(v) == 'number' and v or (v.GetIndex and v:GetIndex())
        if id and not seen[id] then ids[#ids+1]=id; seen[id]=true end
    end
    return ids
end
return W
