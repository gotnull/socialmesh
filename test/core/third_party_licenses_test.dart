// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/third_party_licenses.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'registerThirdPartyLicenses surfaces every bundled notice with its text',
    () async {
      registerThirdPartyLicenses();

      final entries = await LicenseRegistry.licenses.toList();
      final byPackage = <String, String>{};
      for (final entry in entries) {
        final text = entry.paragraphs.map((p) => p.text).join('\n');
        for (final package in entry.packages) {
          byPackage[package] = text;
        }
      }

      expect(
        byPackage['Inter (font)'],
        allOf(
          contains('Copyright 2020 The Inter Project Authors'),
          contains('SIL OPEN FONT LICENSE Version 1.1'),
        ),
      );
      expect(
        byPackage['JetBrains Mono (font)'],
        allOf(
          contains('Copyright 2020 The JetBrains Mono Project Authors'),
          contains('SIL OPEN FONT LICENSE Version 1.1'),
        ),
      );
      expect(
        byPackage['Caveat (font)'],
        allOf(
          contains('Copyright 2014 The Caveat Project Authors'),
          contains('SIL OPEN FONT LICENSE Version 1.1'),
        ),
      );
      expect(
        byPackage['Codec2 (speech codec)'],
        allOf(
          contains('David Rowe'),
          contains('GNU LESSER GENERAL PUBLIC LICENSE'),
          contains('Version 2.1, February 1999'),
        ),
      );
      expect(
        byPackage['vs_node_view'],
        allOf(
          contains('Copyright 2024 Cunibon'),
          contains('Redistribution and use in source and binary forms'),
        ),
      );
      expect(
        byPackage['Meshtastic protobufs'],
        allOf(contains('Meshtastic LLC'), contains('GPL-3.0-only')),
      );
    },
  );
}
