#!/usr/bin/env python3
"""Prepare the pinned upstream RTWCore target; this does not port Airport ABI."""
import pathlib
import plistlib
import re
import sys

root = pathlib.Path(sys.argv[1]).resolve()
project = root / 'AirportRTW.xcodeproj/project.pbxproj'
text = project.read_text()
start = text.index('024A07AB23FCBC3C009FBA6C /* RTWCore */ = {')
end = text.index('\n\t\t};', start)
target = text[start:end]
phase = 'A89C00012F00000000000001 /* Build RTW89 C Archive */'
assert phase + ' = {' in text, 'Expected upstream archive build phase missing'
if phase not in target:
    target = target.replace('buildPhases = (', 'buildPhases = (\n\t\t\t\t' + phase + ',', 1)
    text = text[:start] + target + text[end:]
project.write_text(text)

# Do not distribute upstream example networks or passwords in the build.
info_path = root / 'rtw/Info.plist'
info = plistlib.loads(info_path.read_bytes())
personality = info['IOKitPersonalities']['RTWCore']
assert personality['IOClass'] == 'RTWCore'
assert '0xb85210ec' in personality['IOPCIPrimaryMatch'].lower()
personality['WiFiConfig'] = {}
info_path.write_bytes(plistlib.dumps(info, sort_keys=False))
print('Prepared RTWCore archive phase and removed example network credentials.')
