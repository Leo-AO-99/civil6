-- No Civ VI globals in this module: arithmetic, eligibility, persistent reward bookkeeping.
MNS_Core = {}
local C = MNS_Core

function C.number(value, fallback, minimum, maximum)
    local n = tonumber(value)
    if not n or n ~= n or n == math.huge or n == -math.huge then n = fallback end
    if minimum and n < minimum then n = minimum end
    if maximum and n > maximum then n = maximum end
    return n
end

function C.reward(faith, sciencePercent, culturePercent)
    faith = C.number(faith, 0, 0)
    -- No per-event rounding: small/fractional rewards stay in the bank.
    return faith * C.number(sciencePercent, 0, 0) / 100,
           faith * C.number(culturePercent, 0, 0) / 100
end

function C.price(base, increment, purchases)
    return math.max(0, math.floor(base + increment * math.max(0, purchases)))
end

function C.withdraw(bank, cost, progress)
    bank = C.number(bank, 0, 0)
    local amount = math.min(bank, math.max(0, cost - progress))
    return amount, bank - amount
end

function C.eligibleCast(v)
    if not v.ours then return false, '不是本文明的祭司。' end
    if not v.active then return false, '仅在自己的活动回合施法。' end
    if v.charges <= 0 then return false, '祈灾次数已耗尽。' end
    if v.moves <= 0 then return false, '本回合已无行动力。' end
    if v.alreadyCast then return false, '本回合已施法。' end
    if not v.visible then return false, '目标必须当前可见，不能仅曾经探索。' end
    if v.distance > v.range then return false, '目标超出施法距离。' end
    if v.offensive then
        if v.targetOwner < 0 or v.targetOwner == v.owner or not v.atWar then
            return false, '彗星只能指向正在交战的其他玩家领土。'
        end
    elseif v.targetOwner ~= v.owner then
        return false, '神谕祭司只能在己方国土祈灾。'
    end
    return true
end

-- state is serialized in one player property, so payout + dedupe survive save/reload.
function C.credit(state, key, turn, faith, sc, cu, fire, cooldown, cap)
    state.seen = state.seen or {}
    state.turnCounts = state.turnCounts or {}
    state.fireTurns = state.fireTurns or {}
    local cityKey = tostring(key.city)
    local eventKey = tostring(key.event) .. ':' .. cityKey
    if state.seen[eventKey] then return false end
    state.seen[eventKey] = turn
    local count = state.turnCounts[cityKey]
    if not count or count.turn ~= turn then count = {turn=turn, n=0} end
    state.turnCounts[cityKey] = count
    if cap > 0 and count.n >= cap then return false end
    if fire and state.fireTurns[cityKey] and turn - state.fireTurns[cityKey] < cooldown then
        return false
    end
    local a, b = C.reward(faith, sc, cu)
    state.science = (state.science or 0) + a
    state.culture = (state.culture or 0) + b
    count.n = count.n + 1
    if fire then state.fireTurns[cityKey] = turn end
    return true, a, b
end

return C
