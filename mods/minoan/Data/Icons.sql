-- 使用游戏自身图标；占位美术不代表希腊能力被继承。
INSERT OR REPLACE INTO IconDefinitions (Name,Atlas,"Index")
 SELECT 'ICON_CIVILIZATION_MNS_MINOAN',Atlas,"Index" FROM IconDefinitions WHERE Name='ICON_CIVILIZATION_GREECE';
INSERT OR REPLACE INTO IconDefinitions (Name,Atlas,"Index")
 SELECT 'ICON_LEADER_MNS_MINOS',Atlas,"Index" FROM IconDefinitions WHERE Name='ICON_LEADER_PERICLES';
INSERT OR REPLACE INTO IconDefinitions (Name,Atlas,"Index")
 SELECT 'ICON_DISTRICT_MNS_SANCTUARY',Atlas,"Index" FROM IconDefinitions WHERE Name='ICON_DISTRICT_HOLY_SITE';
