#!/usr/bin/env python3
"""No third-party packages. Static checks + synthetic SQLite fixtures + optional Lua tests.

This does NOT validate Firaxis' native API semantics, event timing, or 3D assets.
"""
from __future__ import annotations
import argparse
import re
import shutil
import sqlite3
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
MOD = ROOT / 'mods/minoan'

def static_checks() -> None:
    for p in list(MOD.rglob('*.xml')) + list(MOD.glob('*.modinfo')):
        ET.parse(p)
    manifest = ET.parse(MOD / 'MinoanDisasters.modinfo').getroot()
    declared = {f.text for f in manifest.find('Files')}
    actual = {p.relative_to(MOD).as_posix() for p in MOD.rglob('*') if p.suffix in ('.lua','.sql','.xml')}
    assert declared == actual, f'manifest difference: {declared ^ actual}'
    for action in ('InGameActions','FrontEndActions'):
        for f in manifest.find(action).iter('File'):
            assert f.text in declared, f'undeclared action file: {f.text}'
    text = ET.parse(MOD / 'Text/MNS_Text.xml').getroot()
    tags = {(r.attrib['Language'],r.attrib['Tag']) for r in text.find('LocalizedText')}
    for p in list(MOD.rglob('*.sql'))+list(MOD.rglob('*.lua')):
        for tag in re.findall(r'LOC_MNS_[A-Z_]+',p.read_text(encoding='utf-8')):
            for lang in ('zh_Hans_CN','en_US'):
                assert (lang,tag) in tags, f'{p}: missing {lang} {tag}'
    scripts = {p.stem for p in MOD.rglob('*.lua')}
    for p in MOD.rglob('*.lua'):
        for name in re.findall(r"include\(['\"]([^'\"]+)",p.read_text()):
            assert name in scripts, f'{p}: missing include {name}'
    print('PASS XML, mod manifest, include paths, localization references')

def db_checks() -> None:
    db=sqlite3.connect(':memory:')
    db.executescript('''
CREATE TABLE Types(Type TEXT PRIMARY KEY,Kind TEXT);
CREATE TABLE Traits(TraitType TEXT PRIMARY KEY,Name TEXT,Description TEXT);
CREATE TABLE Civilizations(CivilizationType TEXT PRIMARY KEY,Name TEXT,Description TEXT,Adjective TEXT,ExtraDlcColumn TEXT);
INSERT INTO Civilizations VALUES('CIVILIZATION_GREECE','Greece','Greece','Greek','preserve-me');
CREATE TABLE Leaders(LeaderType TEXT PRIMARY KEY,Name TEXT,InheritFrom TEXT);
INSERT INTO Leaders VALUES('LEADER_PERICLES','Pericles','LEADER_DEFAULT');
CREATE TABLE CivilizationLeaders(CivilizationType TEXT,LeaderType TEXT,CapitalName TEXT);
CREATE TABLE CivilizationTraits(CivilizationType TEXT,TraitType TEXT);
CREATE TABLE LeaderTraits(LeaderType TEXT,TraitType TEXT);
CREATE TABLE CityNames(CivilizationType TEXT,CityName TEXT);
CREATE TABLE StartBiasFeatures(CivilizationType TEXT,FeatureType TEXT,Tier INTEGER);
CREATE TABLE Features(FeatureType TEXT PRIMARY KEY);
INSERT INTO Features VALUES('FEATURE_VOLCANO'),('FEATURE_GEOTHERMAL_FISSURE'),('FEATURE_FLOODPLAINS'),('FEATURE_FLOODPLAINS_GRASSLAND'),('FEATURE_FLOODPLAINS_PLAINS');
CREATE TABLE Districts(DistrictType TEXT PRIMARY KEY,Name TEXT,Description TEXT,TraitType TEXT,Cost INTEGER,ExtraDlcColumn TEXT);
INSERT INTO Districts VALUES('DISTRICT_HOLY_SITE','Holy Site','Description',NULL,54,'preserve-me');
CREATE TABLE DistrictReplaces(CivUniqueDistrictType TEXT,ReplacesDistrictType TEXT);
CREATE TABLE District_Adjacencies(DistrictType TEXT,YieldChangeId TEXT);
INSERT INTO District_Adjacencies VALUES('DISTRICT_HOLY_SITE','Mountains_Faith');
CREATE TABLE District_GreatPersonPoints(DistrictType TEXT,GreatPersonClassType TEXT,PointsPerTurn INTEGER);
INSERT INTO District_GreatPersonPoints VALUES('DISTRICT_HOLY_SITE','GREAT_PERSON_CLASS_PROPHET',1);
CREATE TABLE District_TradeRouteYields(DistrictType TEXT,YieldType TEXT,YieldChangeAsOrigin INTEGER,YieldChangeAsDomesticDestination INTEGER,YieldChangeAsInternationalDestination INTEGER);
INSERT INTO District_TradeRouteYields VALUES('DISTRICT_HOLY_SITE','YIELD_FAITH',0,0,1);
CREATE TABLE District_CitizenYieldChanges(DistrictType TEXT,YieldType TEXT,YieldChange INTEGER);
INSERT INTO District_CitizenYieldChanges VALUES('DISTRICT_HOLY_SITE','YIELD_FAITH',2);
CREATE TABLE Adjacency_YieldChanges(ID TEXT PRIMARY KEY,Description TEXT,YieldType TEXT,YieldChange INTEGER,TilesRequired INTEGER,AdjacentFeature TEXT);
''')
    sys.path.insert(0, str(ROOT / 'tests'))
    from test_governors import seed_governors
    seed_governors(db)
    for file in ('Config/Balance.sql','Data/Civilization.sql','Data/Governors.sql','Data/District.sql'):
        db.executescript((MOD/file).read_text())
    def one(q): return db.execute(q).fetchone()[0]
    assert one("SELECT Cost FROM Districts WHERE DistrictType='DISTRICT_MNS_SANCTUARY'")==27
    assert one("SELECT Cost FROM Districts WHERE DistrictType='DISTRICT_HOLY_SITE'")==54
    assert one("SELECT PointsPerTurn FROM District_GreatPersonPoints WHERE DistrictType='DISTRICT_MNS_SANCTUARY'")==1
    assert one("SELECT ExtraDlcColumn FROM Civilizations WHERE CivilizationType='CIVILIZATION_MNS_MINOAN'")=='preserve-me'
    assert one("SELECT TransitionStrength FROM Governors WHERE GovernorType='GOVERNOR_THE_BUILDER'")==100
    assert one("SELECT COUNT(*) FROM District_Adjacencies WHERE DistrictType='DISTRICT_MNS_SANCTUARY'")==6
    settings=dict(db.execute('SELECT Name,Value FROM MNS_Settings'))
    assert float(settings['AutoMinTurns'])>=1
    assert float(settings['AutoMaxTurns'])>=float(settings['AutoMinTurns'])
    for key in ('HolySiteCostPercent','OracleCharges','ProphetCharges'):
        assert float(settings[key])>0
    assert settings['MinoanGovernorTransitionStrength']=='250'
    for key in ('ScienceRewardPercent','CultureRewardPercent','OracleFaithCost','ProphetFaithCost','ProphetCostIncrease'):
        assert float(settings[key])>=0
    # Different database/context for setup screen.
    config=sqlite3.connect(':memory:')
    config.executescript('''CREATE TABLE Players(Domain TEXT, CivilizationType TEXT, LeaderType TEXT,
CivilizationName TEXT, LeaderName TEXT, CivilizationAbilityName TEXT,CivilizationAbilityDescription TEXT,
LeaderAbilityName TEXT,LeaderAbilityDescription TEXT,Portrait TEXT,
PRIMARY KEY(Domain,CivilizationType,LeaderType));
INSERT INTO Players VALUES('Players:Expansion2_Players','CIVILIZATION_GREECE','LEADER_PERICLES','Greece','Pericles','a','b','c','d','Pericles');
INSERT INTO Players VALUES('Players:StandardPlayers','CIVILIZATION_GREECE','LEADER_PERICLES','Greece','Pericles','a','b','c','d','Pericles');''')
    config.executescript((MOD/'Data/Configuration.sql').read_text())
    rows=config.execute("SELECT Domain,Portrait FROM Players WHERE LeaderType='LEADER_MNS_MINOS'").fetchall()
    assert rows==[('Players:Expansion2_Players','Pericles')]
    icons=sqlite3.connect(':memory:')
    icons.executescript('''CREATE TABLE IconDefinitions(Name TEXT PRIMARY KEY,Atlas TEXT,"Index" INTEGER);
INSERT INTO IconDefinitions VALUES('ICON_CIVILIZATION_GREECE','c',1),('ICON_LEADER_PERICLES','l',2),('ICON_DISTRICT_HOLY_SITE','d',3);''')
    icons.executescript((MOD/'Data/Icons.sql').read_text())
    assert icons.execute("SELECT COUNT(*) FROM IconDefinitions WHERE Name LIKE '%MNS%'").fetchone()[0]==3
    colors=sqlite3.connect(':memory:')
    colors.executescript("CREATE TABLE PlayerColors(Type TEXT PRIMARY KEY,Usage TEXT,PrimaryColor TEXT,SecondaryColor TEXT); INSERT INTO PlayerColors VALUES('LEADER_PERICLES','Unique','blue','white');")
    colors.executescript((MOD/'Data/Colors.sql').read_text())
    assert colors.execute("SELECT PrimaryColor FROM PlayerColors WHERE Type='LEADER_MNS_MINOS'").fetchone()[0]=='blue'
    print('PASS SQL on synthetic fixtures: costs, points, copied columns, scope, config/icons/colors')

def lua_checks(required: bool) -> None:
    lua=next((shutil.which(n) for n in ('lua5.4','lua','texlua') if shutil.which(n)),None)
    compiler=next((shutil.which(n) for n in ('luac5.4','luac','texluac') if shutil.which(n)),None)
    if compiler:
        for p in MOD.rglob('*.lua'):
            subprocess.run([compiler,'-p',str(p)],check=True,cwd=ROOT)
        print('PASS all Lua files parse')
    if not lua:
        if required: raise RuntimeError('Lua is required; install Lua 5.3/5.4 or TeX Lua.')
        print('SKIP Lua tests: interpreter unavailable'); return
    for script in ('test_core.lua','test_gameplay.lua','test_governor_state.lua','test_disasters.lua'):
        subprocess.run([lua,str(ROOT/'tests'/script),str(ROOT)],check=True,cwd=ROOT)

def main() -> None:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--require-lua',action='store_true')
    args=parser.parse_args()
    static_checks(); db_checks()
    subprocess.run([sys.executable, str(ROOT / 'tests/test_governors.py')], check=True, cwd=ROOT)
    subprocess.run([sys.executable, str(ROOT / 'tests/test_startup.py')], check=True, cwd=ROOT)
    lua_checks(args.require_lua)
    print('Validation complete. No Civ VI engine was run.')
if __name__=='__main__':
    try: main()
    except (AssertionError,sqlite3.Error,ET.ParseError,subprocess.CalledProcessError,RuntimeError) as e:
        print(f'FAIL: {e}',file=sys.stderr);sys.exit(1)
