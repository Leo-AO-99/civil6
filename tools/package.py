#!/usr/bin/env python3
"""Create a manually installable mod ZIP. The user chooses the installation directory."""
from pathlib import Path
import argparse
import zipfile
ROOT=Path(__file__).resolve().parents[1]
def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output',type=Path,default=ROOT/'dist/MinoanDisasters-alpha.zip')
    args=p.parse_args();args.output.parent.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(args.output,'w',compression=zipfile.ZIP_DEFLATED) as z:
        for f in sorted((ROOT/'mods/minoan').rglob('*')):
            if f.is_file():z.write(f,Path('MinoanDisasters')/f.relative_to(ROOT/'mods/minoan'))
    print(args.output.resolve())
if __name__=='__main__':main()
