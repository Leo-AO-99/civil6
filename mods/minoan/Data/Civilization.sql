-- 克隆形态/默认数据，不复制希腊/伯里克利的 Trait。
-- 临时表 SELECT * 避免安装 DLC 后列数变化；只修改确定存在的字段。
INSERT INTO Types (Type, Kind) VALUES
('CIVILIZATION_MNS_MINOAN', 'KIND_CIVILIZATION'),
('LEADER_MNS_MINOS', 'KIND_LEADER'),
('TRAIT_CIVILIZATION_MNS_DISASTERS', 'KIND_TRAIT'),
('TRAIT_LEADER_MNS_PROTECTION', 'KIND_TRAIT'),
('TRAIT_CIVILIZATION_MNS_SANCTUARY', 'KIND_TRAIT');
INSERT INTO Traits (TraitType, Name, Description) VALUES
('TRAIT_CIVILIZATION_MNS_DISASTERS','LOC_MNS_CIV_ABILITY_NAME','LOC_MNS_CIV_ABILITY_DESCRIPTION'),
('TRAIT_LEADER_MNS_PROTECTION','LOC_MNS_LEADER_ABILITY_NAME','LOC_MNS_LEADER_ABILITY_DESCRIPTION'),
('TRAIT_CIVILIZATION_MNS_SANCTUARY','LOC_MNS_SANCTUARY_NAME','LOC_MNS_SANCTUARY_DESCRIPTION');
CREATE TEMP TABLE MNS_CopyCiv AS SELECT * FROM Civilizations WHERE CivilizationType='CIVILIZATION_GREECE';
UPDATE MNS_CopyCiv SET CivilizationType='CIVILIZATION_MNS_MINOAN',
 Name='LOC_MNS_CIV_NAME', Description='LOC_MNS_CIV_DESCRIPTION', Adjective='LOC_MNS_CIV_ADJECTIVE';
INSERT INTO Civilizations SELECT * FROM MNS_CopyCiv;
DROP TABLE MNS_CopyCiv;
CREATE TEMP TABLE MNS_CopyLeader AS SELECT * FROM Leaders WHERE LeaderType='LEADER_PERICLES';
UPDATE MNS_CopyLeader SET LeaderType='LEADER_MNS_MINOS', Name='LOC_MNS_LEADER_NAME';
INSERT INTO Leaders SELECT * FROM MNS_CopyLeader;
DROP TABLE MNS_CopyLeader;
INSERT INTO CivilizationLeaders (CivilizationType, LeaderType, CapitalName)
 VALUES ('CIVILIZATION_MNS_MINOAN','LEADER_MNS_MINOS','LOC_MNS_CITY_KNOSSOS');
INSERT INTO CivilizationTraits (CivilizationType,TraitType) VALUES
('CIVILIZATION_MNS_MINOAN','TRAIT_CIVILIZATION_MNS_DISASTERS'),
('CIVILIZATION_MNS_MINOAN','TRAIT_CIVILIZATION_MNS_SANCTUARY');
INSERT INTO LeaderTraits (LeaderType,TraitType)
 VALUES ('LEADER_MNS_MINOS','TRAIT_LEADER_MNS_PROTECTION');
INSERT INTO CityNames (CivilizationType,CityName) VALUES
('CIVILIZATION_MNS_MINOAN','LOC_MNS_CITY_KNOSSOS'),
('CIVILIZATION_MNS_MINOAN','LOC_MNS_CITY_PHAISTOS'),
('CIVILIZATION_MNS_MINOAN','LOC_MNS_CITY_MALIA'),
('CIVILIZATION_MNS_MINOAN','LOC_MNS_CITY_ZAKROS'),
('CIVILIZATION_MNS_MINOAN','LOC_MNS_CITY_GOURNIA'),
('CIVILIZATION_MNS_MINOAN','LOC_MNS_CITY_TYLISSOS'),
('CIVILIZATION_MNS_MINOAN','LOC_MNS_CITY_PALAIKASTRO'),
('CIVILIZATION_MNS_MINOAN','LOC_MNS_CITY_PETRAS');
-- Native startup bonus and start biases. No per-turn/save-load grant callbacks.
CREATE TEMP TABLE MNS_StartupSettings (
    Titles INTEGER NOT NULL CHECK(TYPEOF(Titles)='integer' AND Titles >= 0),
    VolcanoTier INTEGER NOT NULL CHECK(TYPEOF(VolcanoTier)='integer' AND VolcanoTier BETWEEN 0 AND 5),
    FloodplainTier INTEGER NOT NULL CHECK(TYPEOF(FloodplainTier)='integer' AND FloodplainTier BETWEEN 0 AND 5)
);
INSERT INTO MNS_StartupSettings VALUES (
    (SELECT Value FROM MNS_Settings WHERE Name='StartingGovernorTitles'),
    (SELECT Value FROM MNS_Settings WHERE Name='VolcanoStartBiasTier'),
    (SELECT Value FROM MNS_Settings WHERE Name='FloodplainStartBiasTier')
);
-- Player-level reward, attached exactly once to this leader. Delta is the native
-- argument. Do not attach this to every city or to global GameModifiers.
INSERT INTO Modifiers (ModifierId, ModifierType, RunOnce, Permanent)
 SELECT 'MNS_STARTING_GOVERNOR_TITLES', 'MODIFIER_PLAYER_ADJUST_GOVERNOR_POINTS', 1, 1
 FROM MNS_StartupSettings WHERE Titles > 0;
INSERT INTO ModifierArguments (ModifierId, Name, Value)
 SELECT 'MNS_STARTING_GOVERNOR_TITLES', 'Delta', Titles
 FROM MNS_StartupSettings WHERE Titles > 0;
INSERT INTO TraitModifiers (TraitType, ModifierId)
 SELECT 'TRAIT_LEADER_MNS_PROTECTION', 'MNS_STARTING_GOVERNOR_TITLES'
 FROM MNS_StartupSettings WHERE Titles > 0;

-- Preferences only: map scripts decide if/how to honor them. No forced distance,
-- terrain editing, new volcanoes, extra visibility or coastal bias.
INSERT INTO StartBiasFeatures (CivilizationType, FeatureType, Tier)
 SELECT 'CIVILIZATION_MNS_MINOAN', f.FeatureType, s.VolcanoTier
 FROM Features f CROSS JOIN MNS_StartupSettings s
 WHERE f.FeatureType='FEATURE_VOLCANO' AND s.VolcanoTier > 0;
INSERT INTO StartBiasFeatures (CivilizationType, FeatureType, Tier)
 SELECT 'CIVILIZATION_MNS_MINOAN', f.FeatureType, s.FloodplainTier
 FROM Features f CROSS JOIN MNS_StartupSettings s
 WHERE f.FeatureType IN ('FEATURE_FLOODPLAINS','FEATURE_FLOODPLAINS_GRASSLAND','FEATURE_FLOODPLAINS_PLAINS')
 AND s.FloodplainTier > 0;
DROP TABLE MNS_StartupSettings;
