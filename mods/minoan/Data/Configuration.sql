-- 复制前端条目可保留每条规则集的完整字段。这里只提供风云变幻选择项。
CREATE TEMP TABLE MNS_CopyPlayer AS SELECT * FROM Players
 WHERE LeaderType='LEADER_PERICLES' AND Domain='Players:Expansion2_Players';
UPDATE MNS_CopyPlayer SET CivilizationType='CIVILIZATION_MNS_MINOAN',
 LeaderType='LEADER_MNS_MINOS',CivilizationName='LOC_MNS_CIV_NAME',LeaderName='LOC_MNS_LEADER_NAME',SortIndex=1,
 CivilizationAbilityName='LOC_MNS_CIV_ABILITY_NAME',CivilizationAbilityDescription='LOC_MNS_CIV_ABILITY_DESCRIPTION',
 LeaderAbilityName='LOC_MNS_LEADER_ABILITY_NAME',LeaderAbilityDescription='LOC_MNS_LEADER_ABILITY_DESCRIPTION';
INSERT INTO Players SELECT * FROM MNS_CopyPlayer;
DROP TABLE MNS_CopyPlayer;
