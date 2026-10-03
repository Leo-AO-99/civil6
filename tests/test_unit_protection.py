"""Run against a read-only real-cache copy in memory; not a damage simulation."""
from pathlib import Path
import sqlite3
import sys

root = Path(__file__).resolve().parents[1]
source = sqlite3.connect(f'{Path(sys.argv[1]).resolve().as_uri()}?mode=ro', uri=True)
db = sqlite3.connect(':memory:')
source.backup(db)
source.close()
before = db.execute('SELECT * FROM TraitModifiers').fetchall()
db.executescript((root / 'mods/minoan/Data/UnitProtection.sql').read_text(encoding='utf-8'))
events = {row[0] for row in db.execute('SELECT RandomEventType FROM RandomEvents')}
rows = db.execute("SELECT ModifierId,ModifierType,SubjectRequirementSetId FROM Modifiers WHERE ModifierId LIKE 'MNS_UNIT_IMMUNE_%'").fetchall()
assert len(rows) == len(events) and rows
for modifier, kind, requirement in rows:
    assert kind == 'MODIFIER_PLAYER_ADJUST_RANDOM_EVENT_NO_UNIT_DAMAGE' and requirement is None
    args = dict(db.execute('SELECT Name,Value FROM ModifierArguments WHERE ModifierId=?', (modifier,)))
    assert str(args['NoDamage']) == '1' and args['RandomEventType'] in events
    assert db.execute('SELECT TraitType FROM TraitModifiers WHERE ModifierId=?', (modifier,)).fetchall() == [('TRAIT_LEADER_MNS_PROTECTION',)]
assert db.execute("SELECT * FROM TraitModifiers WHERE ModifierId NOT LIKE 'MNS_UNIT_IMMUNE_%'").fetchall() == before
print(f'PASS {len(events)} native event immunity bindings, all-unit scope, Minos only; engine damage not tested')
