-- 外观占位：游戏内引用原版美术，不随包分发游戏资产。
CREATE TEMP TABLE MNS_CopyColor AS SELECT * FROM PlayerColors WHERE Type='LEADER_PERICLES';
UPDATE MNS_CopyColor SET Type='LEADER_MNS_MINOS';
INSERT INTO PlayerColors SELECT * FROM MNS_CopyColor;
DROP TABLE MNS_CopyColor;
