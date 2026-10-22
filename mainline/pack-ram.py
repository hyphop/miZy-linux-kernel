#!/usr/bin/env python3
"""Pack legacy images for old miZy U-Boot (which has no FIT support)."""
import argparse
import json
from pathlib import Path

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('artifacts', type=Path)
a = p.parse_args()
data = bytearray()
manifest = {}
for name in ('uImage', 'bootstrap.uInitrd', 'board.dtb'):
    data.extend(b'\0' * (-len(data) % 4096))
    manifest[name] = hex(0x48000000 + len(data))
    data.extend((a.artifacts / name).read_bytes())
(a.artifacts / 'ram-legacy.bin').write_bytes(data)
(a.artifacts / 'ram-legacy.json').write_text(json.dumps(manifest, indent=2) + '\n')
print(json.dumps(manifest, indent=2))
