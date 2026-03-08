// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/mesh_services/services/mesh_service_engine.dart';

void main() {
  group('MeshServicesHandler', () {
    group('_encodeInstanceId / _decodeInstanceId', () {
      test('roundtrip preserves short IDs', () {
        const id = 'abc123';
        final encoded = MeshServicesHandler.encodeInstanceId(id);
        expect(encoded.length, 16);
        final decoded = MeshServicesHandler.decodeInstanceId(encoded);
        expect(decoded, id);
      });

      test('roundtrip preserves 16-char IDs', () {
        const id = '0123456789abcdef';
        final encoded = MeshServicesHandler.encodeInstanceId(id);
        final decoded = MeshServicesHandler.decodeInstanceId(encoded);
        expect(decoded, id);
      });

      test('truncates IDs longer than 16 chars', () {
        const id = '0123456789abcdefGHIJ';
        final encoded = MeshServicesHandler.encodeInstanceId(id);
        final decoded = MeshServicesHandler.decodeInstanceId(encoded);
        expect(decoded.length, 16);
        expect(decoded, '0123456789abcdef');
      });

      test('zero bytes terminate decode', () {
        final bytes = Uint8List(16);
        bytes[0] = 65; // 'A'
        bytes[1] = 66; // 'B'
        // rest are zero
        final decoded = MeshServicesHandler.decodeInstanceId(bytes);
        expect(decoded, 'AB');
      });
    });

    group('_truncateUtf8', () {
      test('short string unchanged', () {
        final result = MeshServicesHandler.truncateUtf8('hello', 40);
        expect(String.fromCharCodes(result), 'hello');
      });

      test('long string truncated to maxBytes', () {
        final long = 'a' * 100;
        final result = MeshServicesHandler.truncateUtf8(long, 40);
        expect(result.length, 40);
      });

      test('empty string produces empty bytes', () {
        final result = MeshServicesHandler.truncateUtf8('', 40);
        expect(result.length, 0);
      });
    });
  });

  group('MeshServicesAction', () {
    test('action IDs are unique', () {
      final ids = {
        MeshServicesAction.listInstances,
        MeshServicesAction.getInstance,
        MeshServicesAction.interact,
      };
      expect(ids.length, 3);
    });

    test('action IDs are positive', () {
      expect(MeshServicesAction.listInstances, greaterThan(0));
      expect(MeshServicesAction.getInstance, greaterThan(0));
      expect(MeshServicesAction.interact, greaterThan(0));
    });
  });

  group('kMeshServicesInstanceServiceId', () {
    test('is not zero', () {
      expect(kMeshServicesInstanceServiceId, isNot(0));
    });

    test('is in application range', () {
      // Not in the test range (0xFFFF0000+)
      expect(kMeshServicesInstanceServiceId, lessThan(0xFFFF0000));
    });
  });
}
