#!/bin/bash

# Refresh the bundled Meshtastic hardware catalog from upstream.
#
# Source: https://api.meshtastic.org/resource/deviceHardware
# Target: assets/device_hardware.json (loaded at app startup by
#         lib/services/firmware/device_hardware_catalog.dart)
#
# After running, the script reports:
#   1. Net change in record count.
#   2. Architecture-classification mismatches between the new JSON and our
#      Dart supplement (lib/services/firmware/device_hardware_catalog.dart).
#      A new mismatch means upstream now disagrees with what we hard-coded
#      for an hwModel that previously was not in the JSON — verify the
#      supplement entry and either trust upstream (delete it) or open a
#      bug report.
#   3. Supplement entries that are now redundant (the JSON covers them
#      with the same architecture). Safe to remove from the supplement
#      const map.
#
# Run after every Meshtastic protobuf bump (.github/workflows/check-protobufs.yml)
# and periodically in between, since upstream refreshes the table out of band
# of protobuf releases.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ASSET_PATH="$PROJECT_ROOT/assets/device_hardware.json"
URL='https://api.meshtastic.org/resource/deviceHardware'

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

if ! command -v python3 &> /dev/null; then
    print_error "python3 is required to diff the catalog. Install Python 3."
    exit 1
fi

OLD_COUNT=0
if [ -f "$ASSET_PATH" ]; then
    OLD_COUNT=$(python3 -c "import json; print(len(json.load(open('$ASSET_PATH'))))")
fi

print_status "Fetching upstream catalog from $URL ..."
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

if ! curl -fsSL -o "$TMP" "$URL"; then
    print_error "Fetch failed — leaving existing $ASSET_PATH untouched."
    exit 1
fi

# Validate JSON shape before overwriting.
if ! python3 -c "import json; d = json.load(open('$TMP')); assert isinstance(d, list) and d, 'expected non-empty array'" 2>/dev/null; then
    print_error "Fetched payload is not a non-empty JSON array. Aborting."
    exit 1
fi

NEW_COUNT=$(python3 -c "import json; print(len(json.load(open('$TMP'))))")

mkdir -p "$(dirname "$ASSET_PATH")"
cp "$TMP" "$ASSET_PATH"
print_success "Wrote $NEW_COUNT records to $ASSET_PATH (was $OLD_COUNT)."

print_status "Diffing against the Dart supplement ..."

python3 - "$ASSET_PATH" "$PROJECT_ROOT/lib/services/firmware/device_hardware_catalog.dart" <<'PY'
import json
import re
import sys

asset_path, dart_path = sys.argv[1], sys.argv[2]

# Map upstream architecture string → Dart enum identifier (must match
# DeviceHardwareCatalog._archFromString in the Dart source).
arch_map = {
    'esp32': 'esp32',
    'esp32-c3': 'esp32c3',
    'esp32-c6': 'esp32c6',
    'esp32-s3': 'esp32s3',
    'nrf52840': 'nrf52840',
    'rp2040': 'rp2040',
    'rp2350': 'rp2350',
    'stm32': 'stm32',
    'stm32wl': 'stm32',
    'portduino': 'unknown',
}

with open(asset_path) as f:
    catalog = json.load(f)
json_arch = {x['hwModel']: arch_map.get(x.get('architecture'), x.get('architecture'))
             for x in catalog if isinstance(x.get('hwModel'), int)}

with open(dart_path) as f:
    dart = f.read()

# Parse the _supplement map. Match `\d+: DeviceArchitecture.<name>,` lines.
supplement = {}
in_supplement = False
for line in dart.splitlines():
    if '_supplement' in line and 'const' in line:
        in_supplement = True
        continue
    if not in_supplement:
        continue
    m = re.match(r'\s*(\d+):\s*DeviceArchitecture\.(\w+),', line)
    if m:
        supplement[int(m.group(1))] = m.group(2)
    if line.strip() == '};':
        break

mismatches = []
redundant = []
for hwm, sup_arch in supplement.items():
    j = json_arch.get(hwm)
    if j is None:
        continue
    if j == sup_arch:
        redundant.append(hwm)
    else:
        mismatches.append((hwm, sup_arch, j))

if mismatches:
    print()
    print('⚠️  Architecture mismatches (supplement vs upstream JSON):')
    for hwm, sup, j in sorted(mismatches):
        print(f'    hwModel {hwm}: supplement says {sup}, upstream JSON says {j}')
    print('    → JSON wins at runtime; remove the supplement entry to clear this.')
else:
    print('✅ No supplement vs JSON architecture mismatches.')

if redundant:
    print()
    print('🧹 Redundant supplement entries (JSON now agrees and covers them):')
    for hwm in sorted(redundant):
        print(f'    hwModel {hwm} ({supplement[hwm]})')
    print('    → Safe to delete from _supplement in device_hardware_catalog.dart.')
else:
    print('✅ No redundant supplement entries.')

# Also report supplement gaps: hwModels not in protobufs may indicate stale
# supplement entries, but that's covered by the protobuf parity test. Skip.
PY

print_success "Done. Review the diff above before committing assets/device_hardware.json."
