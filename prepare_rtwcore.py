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

# RTWCore still includes a removed Intel umbrella header. Include the
# declarations actually used by RTWCore and its power-management unit.
header = root / 'rtw/RTWCore.hpp'
contents = header.read_text()
obsolete = '#include "itlhdr.h"'
replacement = '#include <net80211/ieee80211_ioctl.h>\n#include <sys/CTimeout.hpp>'
assert obsolete in contents or replacement in contents, 'Unexpected RTWCore header'
if obsolete in contents:
    contents = contents.replace(obsolete, replacement, 1)
    header.write_text(contents)

# Do not distribute upstream example networks or passwords in the build.
info_path = root / 'rtw/Info.plist'
info = plistlib.loads(info_path.read_bytes())
personality = info['IOKitPersonalities']['RTWCore']
assert personality['IOClass'] == 'RTWCore'
assert '0xb85210ec' in personality['IOPCIPrimaryMatch'].lower()
personality['WiFiConfig'] = {}
info_path.write_bytes(plistlib.dumps(info, sort_keys=False))
print('Prepared RTWCore archive phase and removed example network credentials.')
