"""Startup SQL contracts; not a native grant/save-load or map-generator test."""
from pathlib import Path
import sqlite3
import unittest

MOD = Path(__file__).resolve().parents[1] / 'mods/minoan'
CIV = 'CIVILIZATION_MNS_MINOAN'
BONUS = 'MNS_STARTING_GOVERNOR_TITLES'
SCHEMA = '''
PRAGMA foreign_keys=ON;
CREATE TABLE Types(Type TEXT PRIMARY KEY, Kind TEXT);
CREATE TABLE Traits(TraitType TEXT PRIMARY KEY, Name TEXT, Description TEXT);
CREATE TABLE Civilizations(CivilizationType TEXT PRIMARY KEY, Name TEXT, Description TEXT, Adjective TEXT);
CREATE TABLE Leaders(LeaderType TEXT PRIMARY KEY, Name TEXT);
CREATE TABLE CivilizationLeaders(CivilizationType TEXT, LeaderType TEXT, CapitalName TEXT);
CREATE TABLE CivilizationTraits(CivilizationType TEXT,TraitType TEXT);
CREATE TABLE LeaderTraits(LeaderType TEXT,TraitType TEXT);
CREATE TABLE CityNames(CivilizationType TEXT,CityName TEXT);
CREATE TABLE Features(FeatureType TEXT PRIMARY KEY);
CREATE TABLE StartBiasFeatures(CivilizationType TEXT REFERENCES Civilizations(CivilizationType),
 FeatureType TEXT REFERENCES Features(FeatureType), Tier INTEGER NOT NULL CHECK(Tier BETWEEN 1 AND 5),
 PRIMARY KEY(CivilizationType,FeatureType));
CREATE TABLE Modifiers(ModifierId TEXT PRIMARY KEY, ModifierType TEXT REFERENCES Types(Type),
 RunOnce INTEGER, Permanent INTEGER);
CREATE TABLE ModifierArguments(ModifierId TEXT REFERENCES Modifiers(ModifierId), Name TEXT, Value TEXT,
 PRIMARY KEY(ModifierId,Name));
CREATE TABLE TraitModifiers(TraitType TEXT REFERENCES Traits(TraitType),
 ModifierId TEXT REFERENCES Modifiers(ModifierId),PRIMARY KEY(TraitType,ModifierId));
INSERT INTO Types VALUES('MODIFIER_PLAYER_ADJUST_GOVERNOR_POINTS','KIND_MODIFIER');
INSERT INTO Civilizations VALUES('CIVILIZATION_GREECE','Greece','Greece','Greek');
INSERT INTO Leaders VALUES('LEADER_PERICLES','Pericles');
INSERT INTO Features VALUES('FEATURE_VOLCANO'),('FEATURE_FLOODPLAINS'),
 ('FEATURE_FLOODPLAINS_GRASSLAND'),('FEATURE_FLOODPLAINS_PLAINS'),('FEATURE_FOREST');
INSERT INTO StartBiasFeatures VALUES('CIVILIZATION_GREECE','FEATURE_FOREST',4);
'''


class StartupSQLTests(unittest.TestCase):
    def load(self, overrides=None, missing=None, no_volcano=False):
        db = sqlite3.connect(':memory:')
        self.addCleanup(db.close)
        db.executescript(SCHEMA)
        db.executescript((MOD / 'Config/Balance.sql').read_text(encoding='utf-8'))
        for name, value in (overrides or {}).items():
            db.execute('UPDATE MNS_Settings SET Value=? WHERE Name=?', (value, name))
        if missing:
            db.execute('DELETE FROM MNS_Settings WHERE Name=?', (missing,))
        if no_volcano:
            db.execute("DELETE FROM Features WHERE FeatureType='FEATURE_VOLCANO'")
        db.executescript((MOD / 'Data/Civilization.sql').read_text(encoding='utf-8'))
        self.assertEqual(db.execute('PRAGMA foreign_key_check').fetchall(), [])
        return db

    def biases(self, db):
        return dict(db.execute('SELECT FeatureType,Tier FROM StartBiasFeatures WHERE CivilizationType=?', (CIV,)))

    def test_default_one_title_correct_native_argument(self):
        db = self.load()
        self.assertEqual(db.execute('SELECT Name,Value FROM ModifierArguments WHERE ModifierId=?',
                                    (BONUS,)).fetchall(), [('Delta', '1')])

    def test_native_once_and_permanent_flags(self):
        db = self.load()
        self.assertEqual(db.execute('SELECT ModifierType,RunOnce,Permanent FROM Modifiers WHERE ModifierId=?',
                                    (BONUS,)).fetchone(), ('MODIFIER_PLAYER_ADJUST_GOVERNOR_POINTS', 1, 1))

    def test_bonus_bound_once_only_to_minos_leader(self):
        db = self.load()
        self.assertEqual(db.execute('SELECT * FROM TraitModifiers').fetchall(),
                         [('TRAIT_LEADER_MNS_PROTECTION', BONUS)])
        self.assertEqual(db.execute('SELECT LeaderType FROM LeaderTraits WHERE TraitType=?',
                                    ('TRAIT_LEADER_MNS_PROTECTION',)).fetchall(), [('LEADER_MNS_MINOS',)])

    def test_zero_disables_bonus_without_orphan_arguments(self):
        db = self.load({'StartingGovernorTitles': '0'})
        for table in ('Modifiers', 'ModifierArguments', 'TraitModifiers'):
            self.assertEqual(db.execute(f'SELECT COUNT(*) FROM {table}').fetchone()[0], 0)

    def test_title_count_configurable(self):
        db = self.load({'StartingGovernorTitles': '3'})
        self.assertEqual(db.execute('SELECT Value FROM ModifierArguments WHERE ModifierId=?',
                                    (BONUS,)).fetchone()[0], '3')

    def test_default_volcano_first_priority_floodplains_secondary(self):
        self.assertEqual(self.biases(self.load()), {
            'FEATURE_VOLCANO': 1, 'FEATURE_FLOODPLAINS': 3,
            'FEATURE_FLOODPLAINS_GRASSLAND': 3, 'FEATURE_FLOODPLAINS_PLAINS': 3})

    def test_other_civilizations_unchanged(self):
        db = self.load()
        self.assertEqual(db.execute('SELECT * FROM StartBiasFeatures WHERE CivilizationType<>?',
                                    (CIV,)).fetchall(), [('CIVILIZATION_GREECE', 'FEATURE_FOREST', 4)])

    def test_bias_strength_configurable(self):
        result = self.biases(self.load({'VolcanoStartBiasTier': '2', 'FloodplainStartBiasTier': '5'}))
        self.assertEqual(result['FEATURE_VOLCANO'], 2)
        self.assertEqual({v for k, v in result.items() if 'FLOODPLAINS' in k}, {5})

    def test_zero_bias_skips_rows_not_native_tier_zero(self):
        db = self.load({'VolcanoStartBiasTier': '0'})
        self.assertNotIn('FEATURE_VOLCANO', self.biases(db))
        self.assertEqual(len(self.biases(db)), 3)
        self.assertEqual(self.biases(self.load({'VolcanoStartBiasTier': '0', 'FloodplainStartBiasTier': '0'})), {})

    def test_missing_feature_is_not_created(self):
        db = self.load(no_volcano=True)
        self.assertNotIn('FEATURE_VOLCANO', self.biases(db))
        self.assertEqual(db.execute("SELECT COUNT(*) FROM Features WHERE FeatureType='FEATURE_VOLCANO'").fetchone()[0], 0)

    def test_invalid_settings_rejected(self):
        for key in ('StartingGovernorTitles', 'VolcanoStartBiasTier', 'FloodplainStartBiasTier'):
            for value in ('oops', '-1', '1.5', ''):
                with self.subTest(key=key, value=value), self.assertRaises(sqlite3.IntegrityError):
                    self.load({key: value})
        for key in ('VolcanoStartBiasTier', 'FloodplainStartBiasTier'):
            with self.subTest(key=key), self.assertRaises(sqlite3.IntegrityError):
                self.load({key: '6'})

    def test_missing_settings_rejected(self):
        for key in ('StartingGovernorTitles', 'VolcanoStartBiasTier', 'FloodplainStartBiasTier'):
            with self.subTest(key=key), self.assertRaises(sqlite3.IntegrityError):
                self.load(missing=key)


if __name__ == '__main__':
    unittest.main(verbosity=2)
