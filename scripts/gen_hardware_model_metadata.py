#!/usr/bin/env python3
"""Generate lib/generated/meshtastic/hardware_model_metadata.dart from mesh.proto.

The Dart protobuf plugin does not emit enum value options, so the
`oem_fixed_gps` flag on HardwareModel values (field_metadata.proto) never
reaches the generated enum. This reads it straight from the proto so the
proto stays the only place the list is maintained.

Run by scripts/generate_protos.sh after protoc; safe to run on its own.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROTO = ROOT / "protos" / "meshtastic" / "mesh.proto"
OUT = ROOT / "lib" / "generated" / "meshtastic" / "hardware_model_metadata.dart"

# One enum value: NAME = N, optionally followed by [options] before the ';'.
VALUE = re.compile(r"(\w+)\s*=\s*(\d+)\s*(\[[^\]]*\])?\s*;", re.S)


def hardware_model_body(text: str) -> str:
    match = re.search(r"\benum\s+HardwareModel\s*\{", text)
    if not match:
        sys.exit("HardwareModel enum not found in %s" % PROTO)
    depth, start = 1, match.end()
    for i in range(start, len(text)):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                return text[start:i]
    sys.exit("HardwareModel enum is not closed in %s" % PROTO)


def strip_comments(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    return re.sub(r"//[^\n]*", "", text)


def main() -> None:
    body = strip_comments(hardware_model_body(PROTO.read_text()))
    fixed = []
    for name, number, options in VALUE.findall(body):
        if options and re.search(r"\boem_fixed_gps\s*:\s*true\b", options):
            fixed.append((int(number), name))
    if not fixed:
        sys.exit("no HardwareModel value carries oem_fixed_gps in %s" % PROTO)
    fixed.sort()

    lines = [
        "// This is a generated file - do not edit.",
        "//",
        "// Generated from meshtastic/mesh.proto by",
        "// scripts/gen_hardware_model_metadata.py.",
        "",
        "/// HardwareModel values tagged `oem_fixed_gps` in mesh.proto: boards whose",
        "/// maker wires the GPS to fixed pins, so the GPS pin settings do not apply.",
        "const Set<int> kOemFixedGpsHardwareModels = {",
    ]
    lines += ["  %d, // %s" % (number, name) for number, name in fixed]
    lines += ["};", ""]
    OUT.write_text("\n".join(lines))
    print("Wrote %s (%d oem_fixed_gps models)" % (OUT.relative_to(ROOT), len(fixed)))


if __name__ == "__main__":
    main()
