-- Only Minos' seven native governor variants. No UPDATE of shared Governors rows.
-- Keep the original display names, portraits, promotions and governor-level modifiers.
-- Every new type replaces exactly ONE original type (never one-to-many).
CREATE TABLE MNS_GovernorReplacements (
    OriginalGovernorType TEXT PRIMARY KEY NOT NULL,
    UniqueGovernorType TEXT UNIQUE NOT NULL
);
INSERT INTO MNS_GovernorReplacements (OriginalGovernorType, UniqueGovernorType) VALUES
('GOVERNOR_THE_DEFENDER', 'GOVERNOR_MNS_THE_DEFENDER'),
('GOVERNOR_THE_AMBASSADOR', 'GOVERNOR_MNS_THE_AMBASSADOR'),
('GOVERNOR_THE_CARDINAL', 'GOVERNOR_MNS_THE_CARDINAL'),
('GOVERNOR_THE_BUILDER', 'GOVERNOR_MNS_THE_BUILDER'),
('GOVERNOR_THE_RESOURCE_MANAGER', 'GOVERNOR_MNS_THE_RESOURCE_MANAGER'),
('GOVERNOR_THE_EDUCATOR', 'GOVERNOR_MNS_THE_EDUCATOR'),
('GOVERNOR_THE_MERCHANT', 'GOVERNOR_MNS_THE_MERCHANT');

INSERT INTO Types (Type, Kind)
    SELECT UniqueGovernorType, 'KIND_GOVERNOR' FROM MNS_GovernorReplacements;

-- Reject typos/negative speeds rather than silently casting them to zero.
CREATE TEMP TABLE MNS_GovernorSpeedValue (
    Value INTEGER NOT NULL CHECK (TYPEOF(Value) = 'integer' AND Value > 0)
);
INSERT INTO MNS_GovernorSpeedValue
    SELECT Value FROM MNS_Settings WHERE Name = 'MinoanGovernorTransitionStrength';

-- Copy complete rows so extra columns from the installed ruleset are preserved.
CREATE TEMP TABLE MNS_CopyGovernors AS
    SELECT g.* FROM Governors g
    JOIN MNS_GovernorReplacements m ON m.OriginalGovernorType = g.GovernorType;
UPDATE MNS_CopyGovernors SET
    GovernorType = (SELECT UniqueGovernorType FROM MNS_GovernorReplacements
                    WHERE OriginalGovernorType = MNS_CopyGovernors.GovernorType),
    TraitType = 'TRAIT_LEADER_MNS_PROTECTION',
    TransitionStrength = (SELECT Value FROM MNS_GovernorSpeedValue);
INSERT INTO Governors SELECT * FROM MNS_CopyGovernors;
DROP TABLE MNS_CopyGovernors;
DROP TABLE MNS_GovernorSpeedValue;

INSERT INTO GovernorReplaces (UniqueGovernorType, ReplacesGovernorType)
    SELECT UniqueGovernorType, OriginalGovernorType FROM MNS_GovernorReplacements;

-- Amani keeps her city-state assignment flag from the original main row.
-- Do not include Ibrahim, Secret Societies or governors added by other mods.
INSERT INTO Governors_XP2 (GovernorType, AssignToMajor)
    SELECT m.UniqueGovernorType, x.AssignToMajor
    FROM Governors_XP2 x JOIN MNS_GovernorReplacements m
    ON m.OriginalGovernorType = x.GovernorType;
INSERT INTO GovernorsCannotAssign (GovernorType, CannotAssign)
    SELECT m.UniqueGovernorType, x.CannotAssign
    FROM GovernorsCannotAssign x JOIN MNS_GovernorReplacements m
    ON m.OriginalGovernorType = x.GovernorType;
INSERT INTO GovernorModifiers (GovernorType, ModifierId)
    SELECT m.UniqueGovernorType, x.ModifierId
    FROM GovernorModifiers x JOIN MNS_GovernorReplacements m
    ON m.OriginalGovernorType = x.GovernorType;

-- Shared promotion definitions are intentional: preserve their full prerequisite
-- trees, modifiers and conditions, without changing any original promotion.
INSERT INTO GovernorPromotionSets (GovernorType, GovernorPromotion)
    SELECT m.UniqueGovernorType, x.GovernorPromotion
    FROM GovernorPromotionSets x JOIN MNS_GovernorReplacements m
    ON m.OriginalGovernorType = x.GovernorType;

-- Native, reversible SQL -> Lua established-state marker. Gameplay governor
-- getters are not reliably exposed; an assignment timer is NOT a substitute.
-- One appointment/base title is sufficient. Established=1 must be satisfied.
INSERT INTO Types (Type, Kind) VALUES
    ('MODIFIER_MNS_CITIES_GOVERNOR_STATE', 'KIND_MODIFIER');
INSERT INTO DynamicModifiers (ModifierType, CollectionType, EffectType) VALUES
    ('MODIFIER_MNS_CITIES_GOVERNOR_STATE', 'COLLECTION_PLAYER_CITIES', 'EFFECT_ADJUST_CITY_PROPERTY');
INSERT INTO Requirements (RequirementId, RequirementType) VALUES
    ('MNS_CITY_GOVERNOR_ESTABLISHED', 'REQUIREMENT_CITY_HAS_GOVERNOR_WITH_X_TITLES');
INSERT INTO RequirementArguments (RequirementId, Name, Value) VALUES
    ('MNS_CITY_GOVERNOR_ESTABLISHED', 'Amount', '1'),
    ('MNS_CITY_GOVERNOR_ESTABLISHED', 'Established', '1');
INSERT INTO RequirementSets (RequirementSetId, RequirementSetType) VALUES
    ('MNS_CITY_GOVERNOR_ESTABLISHED_SET', 'REQUIREMENTSET_TEST_ALL');
INSERT INTO RequirementSetRequirements (RequirementSetId, RequirementId) VALUES
    ('MNS_CITY_GOVERNOR_ESTABLISHED_SET', 'MNS_CITY_GOVERNOR_ESTABLISHED');
INSERT INTO Modifiers (ModifierId, ModifierType, RunOnce, Permanent, SubjectRequirementSetId) VALUES
    ('MNS_ESTABLISHED_GOVERNOR_MARKER', 'MODIFIER_MNS_CITIES_GOVERNOR_STATE', 0, 0,
     'MNS_CITY_GOVERNOR_ESTABLISHED_SET');
INSERT INTO ModifierArguments (ModifierId, Name, Value) VALUES
    ('MNS_ESTABLISHED_GOVERNOR_MARKER', 'Key', 'MNS_GovernorEstablished'),
    ('MNS_ESTABLISHED_GOVERNOR_MARKER', 'Amount', '1');
INSERT INTO TraitModifiers (TraitType, ModifierId) VALUES
    ('TRAIT_LEADER_MNS_PROTECTION', 'MNS_ESTABLISHED_GOVERNOR_MARKER');

-- Reuse Liang's original structural-prevention modifier on the UNIQUE governor
-- objects, NOT on the player or a building. No shared promotion is modified.
-- No extra title is needed. Native governor establishment controls activation.
-- Missing/overridden native definitions must be investigated, not hidden by Lua repairs.
CREATE TEMP TABLE MNS_NativeProtectionRequired (Present INTEGER CHECK (Present = 1));
INSERT INTO MNS_NativeProtectionRequired
SELECT CASE WHEN CAST((SELECT Value FROM MNS_Settings WHERE Name='ProtectionEnabled') AS INTEGER)=0
 OR EXISTS (
    SELECT 1 FROM Modifiers m JOIN DynamicModifiers d ON d.ModifierType=m.ModifierType
    JOIN ModifierArguments a ON a.ModifierId=m.ModifierId
    WHERE m.ModifierId='REINFORCED_INFRASTRUCTURE_PREVENET_STRUCTURAL_DAMAGE'
      AND d.EffectType='EFFECT_ADJUST_PREVENT_STRUCTURAL_DAMAGE'
      AND d.CollectionType='COLLECTION_OWNER'
      AND a.Name='Prevent' AND LOWER(a.Value) IN ('1','true')
 ) THEN 1 ELSE 0 END;
DROP TABLE MNS_NativeProtectionRequired;

INSERT INTO GovernorModifiers (GovernorType, ModifierId)
SELECT m.UniqueGovernorType, 'REINFORCED_INFRASTRUCTURE_PREVENET_STRUCTURAL_DAMAGE'
FROM MNS_GovernorReplacements m
WHERE CAST((SELECT Value FROM MNS_Settings WHERE Name='ProtectionEnabled') AS INTEGER)<>0
  AND NOT EXISTS (
    SELECT 1 FROM GovernorModifiers g WHERE g.GovernorType=m.UniqueGovernorType
      AND g.ModifierId='REINFORCED_INFRASTRUCTURE_PREVENET_STRUCTURAL_DAMAGE'
  );
