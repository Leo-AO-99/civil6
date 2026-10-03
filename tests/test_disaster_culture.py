"""Validate native rows in a real-cache memory copy, not engine probability."""
from pathlib import Path
import sqlite3
import sys

root = Path(__file__).resolve().parents[1]
source = sqlite3.connect(f'{Path(sys.argv[1]).resolve().as_uri()}?mode=ro', uri=True)
sql = (root / 'mods/minoan/Data/DisasterCulture.sql').read_text(encoding='utf-8')
for chance in (5, 1, 0):
    db = sqlite3.connect(':memory:')
    source.backup(db)
    before = db.execute('SELECT * FROM RandomEvent_Yields').fetchall()
    db.execute("INSERT OR REPLACE INTO MNS_Settings VALUES ('DisasterTileCultureChance', ?)", (str(chance),))
    db.executescript(sql)
    after = db.execute('SELECT * FROM RandomEvent_Yields').fetchall()
    assert set(before) <= set(after), 'existing yields changed'
    added = set(after) - set(before)
    columns = [r[1] for r in db.execute('PRAGMA table_info(RandomEvent_Yields)')]
    rows = [dict(zip(columns, row)) for row in added]
    assert len(rows) == (18 if chance else 0)
    assert len({r['RandomEventType'] for r in rows}) == (12 if chance else 0)
    for row in rows:
        assert row['YieldType'] == 'YIELD_CULTURE' and row['Amount'] == 1
        assert row['Percentage'] == chance
        food = db.execute('SELECT ReplaceFeature,Turn FROM RandomEvent_Yields WHERE RandomEventType=? AND FeatureType=? AND YieldType=?',
                          (row['RandomEventType'], row['FeatureType'], 'YIELD_FOOD')).fetchone()
        assert food == (row['ReplaceFeature'], row['Turn'])
        if row['RandomEventType'].endswith('_FIRE'):
            assert row['Turn'] > 0 and 'BURNT' in row['FeatureType']
    db.executescript(sql)
    assert db.execute('SELECT * FROM RandomEvent_Yields').fetchall() == after
print('PASS 12 events / 18 native culture rows; 5%, 1%, disabled; existing yields preserved')
