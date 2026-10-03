-- Icon database is separate from Gameplay. Mirror the explicit seven-type map.
-- Alias every matching original icon (normal/FILL/SLOT/etc.); do not copy assets.
CREATE TEMP TABLE MNS_GovernorIconMap (OriginalType TEXT, NewType TEXT);
INSERT INTO MNS_GovernorIconMap VALUES
('GOVERNOR_THE_DEFENDER', 'GOVERNOR_MNS_THE_DEFENDER'),
('GOVERNOR_THE_AMBASSADOR', 'GOVERNOR_MNS_THE_AMBASSADOR'),
('GOVERNOR_THE_CARDINAL', 'GOVERNOR_MNS_THE_CARDINAL'),
('GOVERNOR_THE_BUILDER', 'GOVERNOR_MNS_THE_BUILDER'),
('GOVERNOR_THE_RESOURCE_MANAGER', 'GOVERNOR_MNS_THE_RESOURCE_MANAGER'),
('GOVERNOR_THE_EDUCATOR', 'GOVERNOR_MNS_THE_EDUCATOR'),
('GOVERNOR_THE_MERCHANT', 'GOVERNOR_MNS_THE_MERCHANT');
INSERT OR REPLACE INTO IconDefinitions (Name, Atlas, "Index")
    SELECT REPLACE(i.Name, m.OriginalType, m.NewType), i.Atlas, i."Index"
    FROM IconDefinitions i JOIN MNS_GovernorIconMap m
    ON INSTR(i.Name, m.OriginalType) > 0;
DROP TABLE MNS_GovernorIconMap;
