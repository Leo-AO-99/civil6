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
    -- Convert before the game's TYPEOF check, preserving invalid-value rejection.
    SELECT CASE WHEN Value = CAST(Value AS INTEGER) THEN CAST(Value AS INTEGER) END
    FROM MNS_Settings WHERE Name = 'MinoanGovernorTransitionStrength';

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

-- Seed the original tree membership; private copies are created below while
-- preserving prerequisites, effects and conditions of the original promotions.
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

-- Validate Liang's original structural-prevention modifier before attaching it
-- through private governor base promotions. No shared promotion is modified.
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

-- Native Liang uses GovernorPromotionModifiers, not GovernorModifiers. Give
-- Minos private copies of the existing tree so the base ability can carry the
-- same effect without granting it to other civilizations or adding a title.
CREATE TEMP TABLE MNS_PromotionMap AS
SELECT DISTINCT s.GovernorPromotion AS OriginalType, 'MNS_' || s.GovernorPromotion AS NewType
FROM GovernorPromotionSets s JOIN MNS_GovernorReplacements m ON s.GovernorType=m.UniqueGovernorType;
INSERT INTO Types (Type,Kind) SELECT NewType,'KIND_GOVERNOR_PROMOTION' FROM MNS_PromotionMap;
CREATE TEMP TABLE MNS_CopyPromotions AS
SELECT p.* FROM GovernorPromotions p JOIN MNS_PromotionMap m ON p.GovernorPromotionType=m.OriginalType;
UPDATE MNS_CopyPromotions SET GovernorPromotionType=(SELECT NewType FROM MNS_PromotionMap WHERE OriginalType=GovernorPromotionType);
INSERT INTO GovernorPromotions SELECT * FROM MNS_CopyPromotions;
DROP TABLE MNS_CopyPromotions;
INSERT INTO GovernorPromotionModifiers (GovernorPromotionType,ModifierId)
SELECT m.NewType,p.ModifierId FROM GovernorPromotionModifiers p JOIN MNS_PromotionMap m ON p.GovernorPromotionType=m.OriginalType;
INSERT INTO GovernorPromotionPrereqs (GovernorPromotionType,PrereqGovernorPromotion)
SELECT m.NewType,COALESCE(n.NewType,p.PrereqGovernorPromotion)
FROM GovernorPromotionPrereqs p JOIN MNS_PromotionMap m ON p.GovernorPromotionType=m.OriginalType
LEFT JOIN MNS_PromotionMap n ON p.PrereqGovernorPromotion=n.OriginalType;
INSERT INTO GovernorPromotionConditions (GovernorPromotionType,HiddenWithoutPrereqs,EarliestGameEra)
SELECT m.NewType,p.HiddenWithoutPrereqs,p.EarliestGameEra
FROM GovernorPromotionConditions p JOIN MNS_PromotionMap m ON p.GovernorPromotionType=m.OriginalType;
UPDATE GovernorPromotionSets SET GovernorPromotion=(SELECT NewType FROM MNS_PromotionMap WHERE OriginalType=GovernorPromotion)
WHERE GovernorType IN (SELECT UniqueGovernorType FROM MNS_GovernorReplacements);

INSERT INTO GovernorPromotionModifiers (GovernorPromotionType, ModifierId)
SELECT p.GovernorPromotionType, 'REINFORCED_INFRASTRUCTURE_PREVENET_STRUCTURAL_DAMAGE'
FROM GovernorPromotions p JOIN MNS_PromotionMap m ON p.GovernorPromotionType=m.NewType
WHERE CAST((SELECT Value FROM MNS_Settings WHERE Name='ProtectionEnabled') AS INTEGER)<>0
  AND p.BaseAbility=1
  AND NOT EXISTS (
    SELECT 1 FROM GovernorPromotionModifiers g WHERE g.GovernorPromotionType=p.GovernorPromotionType
      AND g.ModifierId='REINFORCED_INFRASTRUCTURE_PREVENET_STRUCTURAL_DAMAGE'
  );
DROP TABLE MNS_PromotionMap;
