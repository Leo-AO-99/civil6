-- Native Japan/Russia unit-damage immunity, extended to loaded random events.
-- Player-scoped: covers civilian, support, religious and military units anywhere.
-- This prevents event unit damage; it does not recreate plots/cities deleted by comets.
INSERT INTO Modifiers (ModifierId, ModifierType)
SELECT 'MNS_UNIT_IMMUNE_' || RandomEventType, 'MODIFIER_PLAYER_ADJUST_RANDOM_EVENT_NO_UNIT_DAMAGE'
FROM RandomEvents;
INSERT INTO ModifierArguments (ModifierId, Name, Value)
SELECT 'MNS_UNIT_IMMUNE_' || RandomEventType, 'RandomEventType', RandomEventType FROM RandomEvents;
INSERT INTO ModifierArguments (ModifierId, Name, Value)
SELECT 'MNS_UNIT_IMMUNE_' || RandomEventType, 'NoDamage', 1 FROM RandomEvents;
INSERT INTO TraitModifiers (TraitType, ModifierId)
SELECT 'TRAIT_LEADER_MNS_PROTECTION', 'MNS_UNIT_IMMUNE_' || RandomEventType FROM RandomEvents;
