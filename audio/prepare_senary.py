#!/usr/bin/env python3
"""Experimental ID-match prototype; borrowed CX8070 routing is NOT board-qualified."""
import copy
import plistlib
import shutil
import struct
import sys
from pathlib import Path

root = Path(sys.argv[1])
source = root / "Resources/CX8070"
target = root / "Resources/Senary1F87"
old_codec, new_codec = 0x1F86, 0x1F87
old_full, new_full = 0x14F11F86, 0x14F11F87
assert not target.exists(), "Refusing to overwrite an existing prototype"
info = plistlib.loads((source / "Info.plist").read_bytes())
assert info["CodecID"] == old_codec
shutil.copytree(source, target)
info["CodecID"] = new_codec
info["CodecName"] = "Senary1F87-experimental"
info["Author"] = "Experimental CX8070 resource adaptation; routing unvalidated"
patch_count = 0
for patch in info["Patches"]:
    data = patch["Replace"]
    count = data.count(struct.pack("<I", old_full))
    if count:
        patch["Replace"] = data.replace(struct.pack("<I", old_full), struct.pack("<I", new_full))
        patch_count += count
assert patch_count == 1, f"Unexpected codec patch count: {patch_count}"
(target / "Info.plist").write_bytes(plistlib.dumps(info, sort_keys=False))
changed_layouts = []
for path in target.glob("*.xml"):
    text = path.read_text()
    if str(old_full) in text:
        text = text.replace(str(old_full), str(new_full))
        path.write_text(text)
        changed_layouts.append(path.name)
    plistlib.loads(b'<?xml version="1.0"?><plist version="1.0">' + text.encode() + b'</plist>')
assert set(changed_layouts) == {"layout15.xml", "layout21.xml"}
# Stale packed resources must not survive copied source directories.
for pattern in ("*.zlib", "*.md5"):
    for path in target.glob(pattern):
        path.unlink()
pin_path = root / "Resources/PinConfigs.kext/Contents/Info.plist"
pins = plistlib.loads(pin_path.read_bytes())
arrays = []
def walk(node):
    if isinstance(node, dict):
        for value in node.values():
            walk(value)
    elif isinstance(node, list):
        if any(isinstance(x, dict) and x.get("CodecID") == old_full for x in node):
            arrays.append(node)
        for value in list(node):
            walk(value)
walk(pins)
assert len(arrays) == 1
entries = [copy.deepcopy(x) for x in arrays[0] if isinstance(x, dict) and x.get("CodecID") == old_full]
assert {x["LayoutID"] for x in entries} == {15, 21}
for entry in entries:
    entry["CodecID"] = new_full
    entry["Codec"] = "EXPERIMENTAL Senary 14F1:1F87; borrowed CX8070 routing"
    arrays[0].append(entry)
pin_path.write_bytes(plistlib.dumps(pins, sort_keys=False))
assert plistlib.loads((source / "Info.plist").read_bytes())["CodecID"] == old_codec
assert sum(x.get("CodecID") == new_full for x in arrays[0] if isinstance(x, dict)) == 2
print("Validated: new 1F87 resource, layout 15/21 codec IDs, AppleHDA patch, two pin configurations.")
print("Original 1F86 resource retained. Real speaker/mic routing is not yet validated.")
