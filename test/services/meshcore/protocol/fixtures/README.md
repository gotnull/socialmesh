# MeshCore Protocol Fixtures

Real captured frames from MeshCore companion-radio firmware, pinned per
firmware version. Used to detect parser regressions when upstream changes
the wire format. This directory works in tandem with the upstream drift
watcher (`tools/meshcore_protocol/VERSION` +
`.github/workflows/check-meshcore-protocol.yml`):

- The watcher fires when upstream source files change.
- Fixture tests fire when our parser disagrees with bytes a real radio
  produced.

Two independent signals. Either alone is incomplete.

## Source

All fixtures must come from radios listed in
[tools/meshcore_flash/devices.yaml](../../../../tools/meshcore_flash/devices.yaml)
running an explicitly-stated firmware version. Capture method is the
runtime hex log produced by
[lib/services/meshcore/protocol/meshcore_capture.dart](../../../../lib/services/meshcore/protocol/meshcore_capture.dart),
or a TCP packet capture from the companion-radio TCP service on port
5000.

Never commit a fixture from an unverified source. Never invent bytes
and label them golden.

## Filename Convention

```
<frame-kind>__fw-<firmware-version>__<short-description>.bin
<frame-kind>__fw-<firmware-version>__<short-description>.json
```

- `<frame-kind>`: `self-info`, `contact`, `chan-msg`, `contact-msg`,
  `sync-drain`, `trace-data`, `status`, `push`, etc.
- `<firmware-version>`: literal value of `FIRMWARE_VERSION` from
  `examples/companion_radio/MyMesh.h` at capture time, with `v` and dots
  preserved (e.g. `v1.15.0`).
- `<short-description>`: lowercase-hyphenated, captures what the fixture
  proves (e.g. `eu868-region`, `with-gps`, `empty-name`).
- `.bin`: raw frame payload bytes (no transport framing, no length
  prefix).
- `.json`: optional sidecar with parsed expectations the test asserts
  against.

Example:

```
self-info__fw-v1.15.0__eu868-tracker-v2.bin
self-info__fw-v1.15.0__eu868-tracker-v2.json
contact__fw-v1.15.0__advertised.bin
sync-drain__fw-v1.15.0__no-more-messages.bin
```

## What Each Fixture Should Prove

When adding a fixture, write the assertion plainly in the sidecar JSON
or as a comment in the test. Suggested coverage targets:

| Fixture                    | Proves                                                                |
| -------------------------- | --------------------------------------------------------------------- |
| `self-info__*`             | SELF_INFO byte layout matches `MyMesh.cpp:1010+` for the named build  |
| `contact__*`               | CONTACT response decodes name + advertise path + flags correctly      |
| `chan-msg__*`              | RESP_CODE_CHANNEL_MSG_RECV / RECV_V3 round-trips                      |
| `contact-msg__*`           | RESP_CODE_CONTACT_MSG_RECV / RECV_V3 round-trips                      |
| `sync-drain__*`            | RESP_CODE_NO_MORE_MESSAGES is recognized; queued drain terminates     |
| `push-msg-waiting__*`      | PUSH_CODE_MSG_WAITING (0x83) triggers the right side-effect           |
| `push-trace-data__*`       | PUSH_CODE_TRACE_DATA (0x89) parser handles a real trace payload       |
| `unknown-opcode__*`        | A frame with a future/unrecognized opcode is dropped, not crashed     |
| `malformed__*`             | A truncated or oversize frame fails parse without throwing            |

## Updating Fixtures Safely

When upstream firmware bumps in a way that changes a wire format:

1. Reflash a test radio listed in `devices.yaml` to the new firmware
   version. Note the exact `FIRMWARE_VERSION` and `FIRMWARE_VER_CODE`
   from `examples/companion_radio/MyMesh.h` at that build.
2. Capture the affected frame using `meshcore_capture.dart`. Save as
   `<frame-kind>__fw-<new-version>__<description>.bin`.
3. Add the new fixture next to the old one. Do not delete the old
   fixture. Older firmware is still in the field; we want both to
   parse cleanly until we drop support for the older builds.
4. Update the parser if needed. Run the full fixture suite:
   `flutter test test/services/meshcore/protocol/`.
5. Bump `tools/meshcore_protocol/VERSION` to match.

## Hard Rules

- **No secrets.** No PSKs, no Ed25519 / X25519 private keys, no
  plaintext content the original sender did not consent to publish, no
  Bluetooth pairing material, no real GPS coordinates of identifiable
  people. Frames containing user-attributable plaintext must be sanitized
  before commit (replace name fields with `TestRadio` / `TestUser` and
  re-sign if signature applies, or rebuild the frame programmatically
  in-test rather than committing the capture).
- **No fictional bytes.** A fixture that did not come from a real
  firmware build is not a fixture, it is a unit test. Put it in the
  test file, not here.
- **No format-only fixtures.** Every committed fixture must be exercised
  by at least one test. An untested fixture is dead weight that rots.
- **No multi-megabyte fixtures.** If you need that much data to prove
  something, you are testing the wrong thing.

## Current State

This directory currently contains **no fixtures**. Initial captures are
required before fixture-based tests can be added. See the parent task
report for the suggested capture queue.
