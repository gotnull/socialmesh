// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_frame.dart';

void main() {
  group('MeshCore path length byte', () {
    test('the low six bits count hops, the top two give the width', () {
      expect(meshCoreDecodePathLen(0x03), 3);
      expect(meshCoreDecodePathHashSize(0x03), 1);
      expect(meshCoreDecodePathLen(0x43), 3);
      expect(meshCoreDecodePathHashSize(0x43), 2);
      expect(meshCoreDecodePathLen(0x81), 1);
      expect(meshCoreDecodePathHashSize(0x81), 3);
    });

    test('0xFF is the no-path sentinel', () {
      expect(meshCoreDecodePathLen(0xFF), -1);
      expect(meshCoreDecodePathHashSize(0xFF), 1);
      expect(meshCoreEncodePathLen(-1, 1), 0xFF);
    });

    test('encoding round-trips through decoding', () {
      for (final size in [1, 2, 3]) {
        for (final hops in [0, 1, 5, 21]) {
          final b = meshCoreEncodePathLen(hops, size);
          expect(meshCoreDecodePathLen(b), hops);
          expect(meshCoreDecodePathHashSize(b), size);
        }
      }
    });
  });
}
