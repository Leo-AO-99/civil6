"""Governor data contracts on synthetic SQLite fixtures, NOT a Civ VI engine test.

Column names/keys follow the published expansion schema; fixture values are invented.
The optional ExtraDlcColumn checks that cloning does not drop unknown ruleset columns.
"""
from __future__ import annotations
import sqlite3
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MOD = ROOT / 'mods/minoan'
BASE = ('THE_DEFENDER', 'THE_AMBASSADOR', 'THE_CARDINAL', 'THE_BUILDER',
        'THE_RESOURCE_MANAGER', 'THE_EDUCATOR', 'THE_MERCHANT')
PAIRS = [('GOVERNOR_' + n, 'GOVERNOR_MNS_' + n) for n in BASE]
TRAIT = 'TRAIT_LEADER_MNS_PROTECTION'
NATIVE_PROTECTION = 'REINFORCED_INFRASTRUCTURE_PREVENET_STRUCTURAL_DAMAGE'


def seed_governors(db: sqlite3.Connection) -> None:
    """Add a governor fixture to either the standalone or full-mod test database."""
    db.execute('PRAGMA foreign_keys=ON')
    db.executescript('''
CREATE TABLE IF NOT EXISTS Types(Type TEXT PRIMARY KEY, Kind TEXT);
CREATE TABLE IF NOT EXISTS Traits(TraitType TEXT PRIMARY KEY, Name TEXT, Description TEXT);
CREATE TABLE Governors(
 GovernorType TEXT PRIMARY KEY REFERENCES Types(Type), Name TEXT NOT NULL,
 Description TEXT NOT NULL, IdentityPressure INTEGER NOT NULL DEFAULT 0,
 Title TEXT NOT NULL, ShortTitle TEXT NOT NULL, TransitionStrength INTEGER NOT NULL,
 AssignCityState INTEGER NOT NULL CHECK(AssignCityState IN (0,1)), Image TEXT NOT NULL,
 PortraitImage TEXT NOT NULL, PortraitImageSelected TEXT NOT NULL,
 TraitType TEXT REFERENCES Traits(TraitType), ExtraDlcColumn TEXT);
CREATE TABLE Governors_XP2(GovernorType TEXT PRIMARY KEY REFERENCES Governors(GovernorType),
 AssignToMajor INTEGER NOT NULL CHECK(AssignToMajor IN (0,1)));
CREATE TABLE GovernorsCannotAssign(GovernorType TEXT PRIMARY KEY REFERENCES Governors(GovernorType),
 CannotAssign INTEGER NOT NULL CHECK(CannotAssign IN (0,1)));
CREATE TABLE GovernorReplaces(
 UniqueGovernorType TEXT REFERENCES Governors(GovernorType),
 ReplacesGovernorType TEXT REFERENCES Governors(GovernorType),
 PRIMARY KEY(UniqueGovernorType, ReplacesGovernorType));
CREATE TABLE GovernorPromotions(GovernorPromotionType TEXT PRIMARY KEY, Name TEXT,
 Description TEXT, Level INTEGER, "Column" INTEGER, BaseAbility INTEGER);
CREATE TABLE GovernorPromotionSets(GovernorType TEXT REFERENCES Governors(GovernorType),
 GovernorPromotion TEXT REFERENCES GovernorPromotions(GovernorPromotionType),
 PRIMARY KEY(GovernorType, GovernorPromotion));
CREATE TABLE GovernorPromotionPrereqs(
 GovernorPromotionType TEXT REFERENCES GovernorPromotions(GovernorPromotionType),
 PrereqGovernorPromotion TEXT REFERENCES GovernorPromotions(GovernorPromotionType),
 PRIMARY KEY(GovernorPromotionType, PrereqGovernorPromotion));
CREATE TABLE GovernorPromotionConditions(
 GovernorPromotionType TEXT PRIMARY KEY REFERENCES GovernorPromotions(GovernorPromotionType),
 HiddenWithoutPrereqs INTEGER NOT NULL, EarliestGameEra TEXT);
CREATE TABLE DynamicModifiers(ModifierType TEXT PRIMARY KEY REFERENCES Types(Type),
 CollectionType TEXT NOT NULL, EffectType TEXT NOT NULL);
CREATE TABLE Requirements(RequirementId TEXT PRIMARY KEY, RequirementType TEXT NOT NULL);
CREATE TABLE RequirementArguments(RequirementId TEXT REFERENCES Requirements(RequirementId),
 Name TEXT NOT NULL, Value TEXT NOT NULL, PRIMARY KEY(RequirementId, Name));
CREATE TABLE RequirementSets(RequirementSetId TEXT PRIMARY KEY, RequirementSetType TEXT);
CREATE TABLE RequirementSetRequirements(
 RequirementSetId TEXT REFERENCES RequirementSets(RequirementSetId),
 RequirementId TEXT REFERENCES Requirements(RequirementId), PRIMARY KEY(RequirementSetId, RequirementId));
CREATE TABLE Modifiers(ModifierId TEXT PRIMARY KEY, ModifierType TEXT NOT NULL,
 RunOnce INTEGER NOT NULL DEFAULT 0, Permanent INTEGER NOT NULL DEFAULT 0,
 SubjectRequirementSetId TEXT REFERENCES RequirementSets(RequirementSetId));
CREATE TABLE ModifierArguments(ModifierId TEXT REFERENCES Modifiers(ModifierId), Name TEXT, Value TEXT,
 PRIMARY KEY(ModifierId, Name));
CREATE TABLE GovernorModifiers(GovernorType TEXT REFERENCES Governors(GovernorType),
 ModifierId TEXT REFERENCES Modifiers(ModifierId), PRIMARY KEY(GovernorType,ModifierId));
CREATE TABLE GovernorPromotionModifiers(GovernorPromotionType TEXT REFERENCES GovernorPromotions(GovernorPromotionType),
 ModifierId TEXT REFERENCES Modifiers(ModifierId), PRIMARY KEY(GovernorPromotionType,ModifierId));
CREATE TABLE TraitModifiers(TraitType TEXT REFERENCES Traits(TraitType),
 ModifierId TEXT REFERENCES Modifiers(ModifierId), PRIMARY KEY(TraitType,ModifierId));
''')
    db.execute("INSERT INTO Traits VALUES('TRAIT_FIXTURE_OTHER','other','other')")
    all_types = [o for o, _ in PAIRS] + ['GOVERNOR_IBRAHIM', 'GOVERNOR_SECRET_FIXTURE', 'GOVERNOR_OTHER_MOD']
    for i, gov in enumerate(all_types):
        db.execute('INSERT INTO Types VALUES(?,?)', (gov, 'KIND_GOVERNOR'))
        db.execute('INSERT INTO Governors VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)', (
            gov, 'LOC_FIXTURE_NAME_' + gov, 'LOC_FIXTURE_DESC_' + gov, 8,
            'LOC_FIXTURE_TITLE_' + gov, 'LOC_FIXTURE_SHORT_' + gov,
            150 if gov == 'GOVERNOR_THE_DEFENDER' else 100,
            int(gov == 'GOVERNOR_THE_AMBASSADOR'), 'IMAGE_' + gov,
            'PORTRAIT_' + gov, 'SELECTED_' + gov,
            None if i < 7 else 'TRAIT_FIXTURE_OTHER', 'KEEP_' + gov))
        db.execute('INSERT INTO Governors_XP2 VALUES(?,?)', (gov, int(gov == 'GOVERNOR_IBRAHIM')))
        if gov == 'GOVERNOR_THE_BUILDER':
            db.execute('INSERT INTO GovernorsCannotAssign VALUES(?,0)', (gov,))
        if gov == 'GOVERNOR_SECRET_FIXTURE':
            db.execute('INSERT INTO GovernorsCannotAssign VALUES(?,1)', (gov,))
        effect = 'FIXTURE_MOD_' + gov
        db.execute('INSERT INTO Modifiers(ModifierId,ModifierType) VALUES(?,?)', (effect, 'FIXTURE_EFFECT'))
        db.execute('INSERT INTO GovernorModifiers VALUES(?,?)', (gov, effect))
        for j in range(6):
            promotion = gov + '_PROMOTION_' + str(j)
            db.execute('INSERT INTO Types VALUES(?,?)', (promotion, 'KIND_GOVERNOR_PROMOTION'))
            db.execute('INSERT INTO GovernorPromotions VALUES(?,?,?,?,?,?)',
                       (promotion, 'NAME_' + promotion, 'DESC_' + promotion, j // 2, j % 3, int(j == 0)))
            db.execute('INSERT INTO GovernorPromotionSets VALUES(?,?)', (gov, promotion))
            db.execute('INSERT INTO GovernorPromotionModifiers VALUES(?,?)', (promotion, effect))
            if j:
                db.execute('INSERT INTO GovernorPromotionPrereqs VALUES(?,?)',
                           (promotion, gov + '_PROMOTION_' + str((j - 1) // 2)))
        db.execute('INSERT INTO GovernorPromotionConditions VALUES(?,1,?)', (gov + '_PROMOTION_5', 'ERA_FIXTURE'))
    # Source modifier contract is real; this is still a synthetic engine fixture.
    db.execute("INSERT INTO Types VALUES('MODIFIER_GOVERNOR_ADJUST_PREVENET_STRUCTURAL_DAMAGE','KIND_MODIFIER')")
    db.execute("INSERT INTO DynamicModifiers VALUES('MODIFIER_GOVERNOR_ADJUST_PREVENET_STRUCTURAL_DAMAGE','COLLECTION_OWNER','EFFECT_ADJUST_PREVENT_STRUCTURAL_DAMAGE')")
    db.execute("INSERT INTO Modifiers(ModifierId,ModifierType) VALUES(?,'MODIFIER_GOVERNOR_ADJUST_PREVENET_STRUCTURAL_DAMAGE')", (NATIVE_PROTECTION,))
    db.execute("INSERT INTO ModifierArguments VALUES(?,'Prevent','1')", (NATIVE_PROTECTION,))
    db.execute("INSERT INTO GovernorPromotionModifiers VALUES('GOVERNOR_THE_BUILDER_PROMOTION_3',?)", (NATIVE_PROTECTION,))
    db.commit()


def load_mod(db: sqlite3.Connection, strength: str = '250', protection: str = '1') -> None:
    db.executescript((MOD / 'Config/Balance.sql').read_text())
    db.execute("UPDATE MNS_Settings SET Value=? WHERE Name='MinoanGovernorTransitionStrength'", (strength,))
    db.execute("UPDATE MNS_Settings SET Value=? WHERE Name='ProtectionEnabled'", (protection,))
    db.execute('INSERT INTO Types VALUES(?,?)', (TRAIT, 'KIND_TRAIT'))
    db.execute('INSERT INTO Traits VALUES(?,?,?)', (TRAIT, 'name', 'description'))
    db.executescript((MOD / 'Data/Governors.sql').read_text())


class GovernorSQLTests(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(':memory:')
        self.addCleanup(self.db.close)
        seed_governors(self.db)
        self.originals = self.db.execute('SELECT * FROM Governors').fetchall()
        self.unchanged_tables = {t: self.db.execute(f'SELECT * FROM {t}').fetchall() for t in (
            'GovernorPromotions', 'GovernorPromotionModifiers', 'GovernorPromotionPrereqs',
            'GovernorPromotionConditions')}
        load_mod(self.db)

    def rows(self, table, governor):
        return self.db.execute(f'SELECT * FROM {table} WHERE GovernorType=?', (governor,)).fetchall()

    def test_exactly_seven_independent_variants(self):
        self.assertEqual(self.db.execute('SELECT COUNT(*) FROM Governors').fetchone()[0], len(self.originals) + 7)
        self.assertEqual(set(self.db.execute('SELECT * FROM MNS_GovernorReplacements')), set(PAIRS))

    def test_original_governor_rows_completely_unchanged(self):
        for row in self.originals:
            self.assertEqual(self.rows('Governors', row[0]), [row])

    def test_names_portraits_titles_and_unknown_columns_preserved(self):
        for old, new in PAIRS:
            a, b = self.rows('Governors', old)[0], self.rows('Governors', new)[0]
            for i in range(len(a)):
                if i not in (0, 6, 11):
                    self.assertEqual(a[i], b[i], (old, i))

    def test_default_speed_is_250_only_on_variants(self):
        for _, new in PAIRS:
            self.assertEqual(self.rows('Governors', new)[0][6], 250)

    def test_all_variants_gated_by_minos_trait(self):
        for _, new in PAIRS:
            self.assertEqual(self.rows('Governors', new)[0][11], TRAIT)

    def test_each_variant_replaces_one_distinct_original(self):
        self.assertEqual(set(self.db.execute('SELECT * FROM GovernorReplaces')), {(n, o) for o, n in PAIRS})
        self.assertEqual(self.db.execute('SELECT MAX(n) FROM (SELECT COUNT(*) n FROM GovernorReplaces GROUP BY UniqueGovernorType)').fetchone()[0], 1)

    def test_shared_promotion_sets_preserve_skill_trees(self):
        for old, new in PAIRS:
            self.assertEqual([r[1] for r in self.rows('GovernorPromotionSets', old)],
                             [r[1] for r in self.rows('GovernorPromotionSets', new)])
        for table, before in self.unchanged_tables.items():
            self.assertEqual(self.db.execute(f'SELECT * FROM {table}').fetchall(), before)

    def test_governor_level_modifiers_copied(self):
        for old, new in PAIRS:
            self.assertEqual({r[1] for r in self.rows('GovernorModifiers', old)} | {NATIVE_PROTECTION},
                             {r[1] for r in self.rows('GovernorModifiers', new)})

    def test_native_structural_prevention_bound_only_to_seven_variants(self):
        actual = set(self.db.execute('SELECT GovernorType FROM GovernorModifiers WHERE ModifierId=?', (NATIVE_PROTECTION,)))
        self.assertEqual(actual, {(n,) for _, n in PAIRS})
        self.assertEqual(dict(self.db.execute('SELECT Name,Value FROM ModifierArguments WHERE ModifierId=?', (NATIVE_PROTECTION,))), {'Prevent': '1'})
        # No cloning or editing of the shared original Liang promotion.
        self.assertEqual(self.db.execute('SELECT GovernorPromotionType FROM GovernorPromotionModifiers WHERE ModifierId=?', (NATIVE_PROTECTION,)).fetchall(), [('GOVERNOR_THE_BUILDER_PROMOTION_3',)])

    def test_disabled_protection_does_not_bind_extra_native_effect(self):
        db = sqlite3.connect(':memory:'); self.addCleanup(db.close)
        seed_governors(db); load_mod(db, protection='0')
        self.assertEqual(db.execute('SELECT COUNT(*) FROM GovernorModifiers WHERE ModifierId=?', (NATIVE_PROTECTION,)).fetchone()[0], 0)
        self.assertEqual(db.execute('SELECT COUNT(*) FROM GovernorPromotionModifiers WHERE ModifierId=?', (NATIVE_PROTECTION,)).fetchone()[0], 1)

    def test_missing_or_changed_native_contract_is_not_silently_repaired(self):
        for change in (
            "DELETE FROM ModifierArguments WHERE Name='Prevent'",
            "UPDATE ModifierArguments SET Value='false' WHERE Name='Prevent'",
            "UPDATE DynamicModifiers SET CollectionType='COLLECTION_PLAYER_CITIES'",
            "UPDATE DynamicModifiers SET EffectType='EFFECT_WRONG'",
        ):
            with self.subTest(change=change):
                db = sqlite3.connect(':memory:'); self.addCleanup(db.close)
                seed_governors(db); db.execute(change)
                with self.assertRaises(sqlite3.IntegrityError): load_mod(db)

    def test_amani_city_state_assignment_retained(self):
        self.assertEqual(self.rows('Governors', 'GOVERNOR_MNS_THE_AMBASSADOR')[0][7], 1)
        for old, new in PAIRS:
            for table in ('Governors_XP2', 'GovernorsCannotAssign'):
                self.assertEqual([r[1:] for r in self.rows(table, old)], [r[1:] for r in self.rows(table, new)])

    def test_ibrahim_societies_other_mods_not_cloned(self):
        for name in ('IBRAHIM', 'SECRET_FIXTURE', 'OTHER_MOD'):
            self.assertFalse(self.rows('Governors', 'GOVERNOR_MNS_' + name))

    def test_native_state_marker_is_reversible_and_trait_scoped(self):
        self.assertEqual(self.db.execute("SELECT RunOnce,Permanent,SubjectRequirementSetId FROM Modifiers WHERE ModifierId='MNS_ESTABLISHED_GOVERNOR_MARKER'").fetchone(),
                         (0, 0, 'MNS_CITY_GOVERNOR_ESTABLISHED_SET'))
        self.assertEqual(self.db.execute('SELECT * FROM TraitModifiers').fetchall(), [(TRAIT, 'MNS_ESTABLISHED_GOVERNOR_MARKER')])
        args = dict(self.db.execute("SELECT Name,Value FROM RequirementArguments WHERE RequirementId='MNS_CITY_GOVERNOR_ESTABLISHED'"))
        self.assertEqual(args, {'Amount': '1', 'Established': '1'})
        self.assertEqual(dict(self.db.execute("SELECT Name,Value FROM ModifierArguments WHERE ModifierId='MNS_ESTABLISHED_GOVERNOR_MARKER'")),
                         {'Key': 'MNS_GovernorEstablished', 'Amount': '1'})

    def test_all_foreign_keys_resolve(self):
        self.assertEqual(self.db.execute('PRAGMA foreign_key_check').fetchall(), [])

    def test_tuning_changes_only_variant_native_speed(self):
        db = sqlite3.connect(':memory:'); self.addCleanup(db.close)
        seed_governors(db); before = db.execute('SELECT * FROM Governors').fetchall()
        load_mod(db, '125')
        for old, new in PAIRS:
            self.assertEqual(db.execute('SELECT TransitionStrength FROM Governors WHERE GovernorType=?', (new,)).fetchone()[0], 125)
        for row in before:
            self.assertEqual(db.execute('SELECT * FROM Governors WHERE GovernorType=?', (row[0],)).fetchone(), row)

    def test_invalid_speed_is_rejected_instead_of_cast_to_zero(self):
        for value in ('abc', '0', '-1', '2.5', ''):
            with self.subTest(value=value):
                db = sqlite3.connect(':memory:'); self.addCleanup(db.close)
                seed_governors(db)
                with self.assertRaises(sqlite3.IntegrityError):
                    load_mod(db, value)

    def test_legacy_timer_and_global_switches_removed_from_settings(self):
        names = {r[0] for r in self.db.execute('SELECT Name FROM MNS_Settings')}
        self.assertTrue({'ProtectionEstablishTurns', 'GlobalGovernorSpeedOverride', 'GlobalGovernorTransitionStrength'}.isdisjoint(names))

    def test_icon_aliases_preserve_all_original_styles(self):
        db = sqlite3.connect(':memory:'); self.addCleanup(db.close)
        db.execute('CREATE TABLE IconDefinitions(Name TEXT PRIMARY KEY, Atlas TEXT, "Index" INTEGER)')
        before = []
        for i, (old, _) in enumerate(PAIRS):
            for suffix in ('', '_FILL', '_SLOT', '_ROUND'):
                row = ('ICON_' + old + suffix, 'ATLAS_FIXTURE_' + suffix, i)
                db.execute('INSERT INTO IconDefinitions VALUES(?,?,?)', row); before.append(row)
        # An unrelated original and a new-style icon with a prefix also survive.
        db.execute("INSERT INTO IconDefinitions VALUES('ICON_GOVERNOR_OTHER_MOD','other',77)")
        db.executescript((MOD / 'Data/GovernorIcons.sql').read_text())
        self.assertEqual(db.execute('SELECT COUNT(*) FROM IconDefinitions').fetchone()[0], len(before) * 2 + 1)
        for row in before:
            self.assertEqual(db.execute('SELECT * FROM IconDefinitions WHERE Name=?', (row[0],)).fetchone(), row)
            clone = row[0].replace('GOVERNOR_', 'GOVERNOR_MNS_')
            self.assertEqual(db.execute('SELECT Atlas,"Index" FROM IconDefinitions WHERE Name=?', (clone,)).fetchone(), row[1:])
        # Re-loading icon actions is harmless, and creates no second-level clones.
        db.executescript((MOD / 'Data/GovernorIcons.sql').read_text())
        self.assertEqual(db.execute('SELECT COUNT(*) FROM IconDefinitions').fetchone()[0], len(before) * 2 + 1)


if __name__ == '__main__':
    unittest.main(verbosity=2)
