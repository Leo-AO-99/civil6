-- 米诺斯唯一调参入口。改后重新加载 Mod；区域/数据库改动请开新档。
-- Value 用字符串存储；Lua 数值会 tonumber()。0/1 为关闭/开启。
CREATE TABLE IF NOT EXISTS MNS_Settings (
    Name TEXT PRIMARY KEY NOT NULL,
    Value TEXT NOT NULL
);
INSERT OR REPLACE INTO MNS_Settings (Name, Value) VALUES
-- 开局额外可分配的总督头衔：只发一次、不自动任命；0关闭。
('StartingGovernorTitles', '1'),
-- 出生倾向：1最强、5最弱、0关闭；不是概率，不保证固定距离有火山。
-- 只改变原生选址偏好，不造火山，不传送初始单位。
('VolcanoStartBiasTier', '1'),
('FloodplainStartBiasTier', '3'),
-- 区域成本是原圣地的百分比，不是固定锤数。
('HolySiteCostPercent', '50'),
('VolcanoBonusFaith', '2'),             -- 额外相邻；火山的原山脉相邻仍保留
('GeothermalBonusFaith', '2'),
('FloodplainBonusFaith', '1'),
-- 每个米诺斯玩家（不是每座城）独立计时；普通原生灾害照常发生。
('AutoDisastersEnabled', '1'),
('AutoMinTurns', '2'),
('AutoMaxTurns', '3'),
('AutoFirstTurn', '8'),                 -- 第8回合开始；赠送头衔需自己任命/指派总督
-- 自动灾害/神谕祭司只取肥地白名单；这些开关不会开放其他灾害。
('FireEnabled', '1'),                  -- 森林火和雨林火；保留燃烧/恢复过程
('FloodEnabled', '1'),
('VolcanoEnabled', '1'),
('StormEnabled', '1'),                -- 下列两类陆地风暴的总开关；不含龙卷风或飓风
('DustStormEnabled', '1'),
('BlizzardEnabled', '1'),
('AutoPreferProtected', '1'),           -- 优先庇护城市；没有时仍可落在其他本国土地
-- 米诺斯领袖专属七位总督的原生过渡强度；不修改其他文明。
-- 250 的目标是 2 回合，125 目标 4 回合，100 目标 5 回合；以游戏实测为准。
-- 这不是直接的回合数，不要填 1 或 2，也不要用 500 猜测一回合。
('MinoanGovernorTransitionStrength', '250'),
-- 庇护跟随原生已就位：梁的原生结构防护 + Lua仅补人口；0关闭本Mod新增防护。
-- 此开关影响SQL绑定，修改后必须重新加载数据库；不改变原版梁自身已点的晋升。
('ProtectionEnabled', '1'),
-- 一次性奖励：本城当时每回合信仰 × 百分比；不会扣信仰。
('ScienceRewardPercent', '50'),
('CultureRewardPercent', '50'),
-- Global native tile fertility for the 12 cultivation events; all civilizations benefit.
('DisasterTileCultureChance', '5'),    -- percent; 1 = 1%, 0 disables new culture rows
('RewardCityTurnCap', '1'),
('RewardRequiresSanctuary', '0'),
-- 同一原生灾害ID每城只结算一次；森火另设保守冷却，防跨ID蔓延刷奖。
('FireRewardCooldownTurns', '5'),
-- 保留原生增产概率/恢复时间，不额外加肥力，不保证每次立即或必然增产。
-- 两类祭司复用原版传教士/使徒实例及模型，在城市信仰列表购买、单位操作区施法。
('OracleFaithCost', '400'),
('OracleCostIncrease', '0'),
('OracleCharges', '2'),
('OracleRange', '2'),
('OracleMoves', '3'),
('OracleUnlockCivic', 'CIVIC_THEOLOGY'),
('OracleBaseUnit', 'UNIT_MISSIONARY'),
('ProphetFaithCost', '3000'),
('ProphetCostIncrease', '1500'),
('ProphetCharges', '1'),
('ProphetRange', '3'),
('ProphetMoves', '2'),
('ProphetUnlockCivic', 'CIVIC_COLD_WAR'),
('ProphetBaseUnit', 'UNIT_APOSTLE'),
('ProphetEnabled', '1'),              -- 仅独立手动对敌彗星；永不混入自动/内政池，0禁用购买
('CometAllowsCityCenter', '1'),
('LogLevel', '1');
