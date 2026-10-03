-- Native per-tile fertility rolls. Global by design: this table has no owner filter.
-- Copy only positive food phases, so fire rolls once in its burnt/recovery phase,
-- not at ignition and again at forest regrowth. Preserve native terrain semantics.
INSERT INTO RandomEvent_Yields
    (RandomEventType, YieldType, FeatureType, Percentage, ReplaceFeature, Amount, Turn)
SELECT y.RandomEventType, 'YIELD_CULTURE', y.FeatureType,
       MIN(100, MAX(0, CAST(s.Value AS INTEGER))), y.ReplaceFeature, 1, y.Turn
FROM RandomEvent_Yields AS y
JOIN MNS_Settings AS s ON s.Name = 'DisasterTileCultureChance'
WHERE y.YieldType = 'YIELD_FOOD' AND y.Amount > 0 AND y.Percentage > 0
  AND CAST(s.Value AS INTEGER) > 0
  AND y.RandomEventType IN (
      'RANDOM_EVENT_FLOOD_MODERATE', 'RANDOM_EVENT_FLOOD_MAJOR', 'RANDOM_EVENT_FLOOD_1000_YEAR',
      'RANDOM_EVENT_VOLCANO_GENTLE', 'RANDOM_EVENT_VOLCANO_CATASTROPHIC', 'RANDOM_EVENT_VOLCANO_MEGACOLOSSAL',
      'RANDOM_EVENT_FOREST_FIRE', 'RANDOM_EVENT_JUNGLE_FIRE',
      'RANDOM_EVENT_DUST_STORM_GRADIENT', 'RANDOM_EVENT_DUST_STORM_HABOOB',
      'RANDOM_EVENT_BLIZZARD_SIGNIFICANT', 'RANDOM_EVENT_BLIZZARD_CRIPPLING')
  AND NOT EXISTS (
      SELECT 1 FROM RandomEvent_Yields AS existing
      WHERE existing.RandomEventType = y.RandomEventType
        AND existing.FeatureType = y.FeatureType AND existing.YieldType = 'YIELD_CULTURE');
