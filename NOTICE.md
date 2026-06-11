# Third-Party Notices

This file contains attribution notices for third-party software and assets used in SocialMesh. The same notices are surfaced to end users on the in-app license page (Settings > Open Source), registered via `lib/core/third_party_licenses.dart`.

## Meshtastic Protobufs

This application uses protocol buffer definitions from the Meshtastic project.

- **Project:** Meshtastic
- **Repository:** https://github.com/meshtastic/protobufs
- **License:** GPL-3.0-only
- **Copyright:** Copyright © Meshtastic LLC

The Meshtastic protobufs are used to communicate with Meshtastic mesh radio devices over BLE and USB serial connections. Generated Dart bindings live in `lib/generated/meshtastic/` and inherit the GPL-3.0-only license of their source `.proto` files.

## Protocol Buffers

This application uses Google Protocol Buffers for serialization.

- **Project:** Protocol Buffers
- **Repository:** https://github.com/protocolbuffers/protobuf
- **License:** BSD-3-Clause
- **Copyright:** Copyright © Google LLC

## Codec2

This application uses the Codec2 speech codec to compress voice messages for transmission over LoRa mesh networks.

- **Project:** Codec2
- **Repository:** https://github.com/drowe67/codec2 (version 1.2.0)
- **License:** LGPL-2.1-or-later
- **Copyright:** Copyright © David Rowe and contributors

Unmodified Codec2 v1.2.0 source files and the build scripts used to produce the bundled binaries are included in this repository (`ios/codec2/`, `android/app/src/main/jni/codec2/`, `macos/codec2/`). See `docs/legal/CODEC2_LGPL_COMPLIANCE.md` for the full compliance statement and `licenses/LGPL-2.1` / `assets/licenses/codec2-LGPL-2.1.txt` for the license text.

## Fonts

The bundled font families in `assets/fonts/` are licensed under the SIL Open Font License, Version 1.1. The full OFL text for each family is bundled in `assets/licenses/` and shown on the in-app license page.

- **Inter** - Copyright 2020 The Inter Project Authors (https://github.com/rsms/inter) - OFL-1.1
- **JetBrains Mono** - Copyright 2020 The JetBrains Mono Project Authors (https://github.com/JetBrains/JetBrainsMono) - OFL-1.1
- **Caveat** - Copyright 2014 The Caveat Project Authors (https://github.com/googlefonts/caveat) - OFL-1.1

## vs_node_view (vendored)

A vendored copy of the vs_node_view package lives at `lib/core/visual_flow/vs_node_view/`.

- **Author:** Cunibon
- **License:** BSD-3-Clause
- **Copyright:** Copyright 2024 Cunibon

The original license text is retained at `lib/core/visual_flow/vs_node_view/LICENSE` and bundled at `assets/licenses/vs_node_view-LICENSE.txt`.

## Sound Effects

The SIP Play and handshake sound effects in `assets/sounds/sip_play/` are sourced from Pixabay under the Pixabay Content License (commercial use permitted, attribution not required). Per-file provenance: `assets/sounds/sip_play/ATTRIBUTION.md`.

## Nothing GlyphMatrix SDK

`android/app/libs/glyph-matrix-sdk-1.0.aar` (Nothing Technology Limited) provides Glyph Matrix support on Nothing Phone devices. It is distributed via the Nothing Developer Programme; the aar does not embed a license text. See `docs/legal/third_party_license_audit.md` for status.

## Flutter and Dart Packages

This application is built with Flutter and uses open-source Dart packages from pub.dev. The complete set of package licenses is embedded in the application by the Flutter build (NOTICES) and is viewable in-app under Settings > Open Source.

Notable packages:

- `flutter_blue_plus` - FlutterBluePlus License v1.4 (custom; commercial use licensed - the developer holds an Inventor commercial license)
- `protobuf` (Dart) - BSD-3-Clause
- `flutter_riverpod` - MIT
- `sqflite` - BSD-2-Clause
- `flutter_map` - BSD-3-Clause

For a complete list of dependencies and their licenses, run:

```bash
flutter pub deps
```
