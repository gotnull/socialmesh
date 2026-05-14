// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D47-A: `MeshCoreAutoAddConfig` value-type pins.
//
// Wire format: single byte of flag bits packed per `MeshCoreAutoAddFlag`.
// Pinned invariants:
//   - toFlagsByte / fromFlagsByte round-trip is byte-for-byte.
//   - Each flag maps to exactly one bit (no aliasing).
//   - Reserved bits (0x20..0x80) survive a round trip via the
//     `reservedBits` field — a future firmware can introduce
//     additional toggles without our parser stripping them.
//   - copyWith updates the named field, preserves others.
//   - == / hashCode treat instances with identical flag content as
//     equal (value-type semantics).

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/meshcore_constants.dart';
import 'package:socialmesh/models/meshcore_auto_add_config.dart';

void main() {
  group('MeshCoreAutoAddConfig.toFlagsByte - D47-A', () {
    test('all-off packs to 0x00', () {
      expect(const MeshCoreAutoAddConfig.off().toFlagsByte(), 0x00);
    });

    test('each flag maps to exactly one bit (no aliasing)', () {
      expect(
        const MeshCoreAutoAddConfig(overwriteOldest: true).toFlagsByte(),
        MeshCoreAutoAddFlag.overwriteOldest,
      );
      expect(
        const MeshCoreAutoAddConfig(autoAddChat: true).toFlagsByte(),
        MeshCoreAutoAddFlag.chat,
      );
      expect(
        const MeshCoreAutoAddConfig(autoAddRepeater: true).toFlagsByte(),
        MeshCoreAutoAddFlag.repeater,
      );
      expect(
        const MeshCoreAutoAddConfig(autoAddRoomServer: true).toFlagsByte(),
        MeshCoreAutoAddFlag.roomServer,
      );
      expect(
        const MeshCoreAutoAddConfig(autoAddSensor: true).toFlagsByte(),
        MeshCoreAutoAddFlag.sensor,
      );
    });

    test('all-on packs to 0x1F', () {
      const c = MeshCoreAutoAddConfig(
        overwriteOldest: true,
        autoAddChat: true,
        autoAddRepeater: true,
        autoAddRoomServer: true,
        autoAddSensor: true,
      );
      expect(c.toFlagsByte(), 0x1F);
    });

    test('reservedBits flow through on encode', () {
      const c = MeshCoreAutoAddConfig(autoAddChat: true, reservedBits: 0x60);
      // 0x02 (chat) | 0x60 (reserved) = 0x62.
      expect(c.toFlagsByte(), 0x62);
    });

    test(
      'toFlagsByte masks to a single byte (defensive against bad reserved)',
      () {
        const c = MeshCoreAutoAddConfig(reservedBits: 0xFFFFFF60);
        // Only 0xE0 mask of reservedBits should flow; & 0xFF on the
        // result clamps to a byte.
        expect(c.toFlagsByte() & 0xFF, c.toFlagsByte());
        expect(c.toFlagsByte() <= 0xFF, isTrue);
      },
    );
  });

  group('MeshCoreAutoAddConfig.fromFlagsByte - D47-A', () {
    test('0x00 → all-off', () {
      final c = MeshCoreAutoAddConfig.fromFlagsByte(0x00);
      expect(c, const MeshCoreAutoAddConfig.off());
    });

    test('0x1F → all-on, no reserved bits', () {
      final c = MeshCoreAutoAddConfig.fromFlagsByte(0x1F);
      expect(c.overwriteOldest, isTrue);
      expect(c.autoAddChat, isTrue);
      expect(c.autoAddRepeater, isTrue);
      expect(c.autoAddRoomServer, isTrue);
      expect(c.autoAddSensor, isTrue);
      expect(c.reservedBits, 0);
    });

    test('reserved bits land in reservedBits', () {
      final c = MeshCoreAutoAddConfig.fromFlagsByte(0x82);
      expect(c.autoAddChat, isTrue);
      expect(c.autoAddRepeater, isFalse);
      expect(c.reservedBits, 0x80);
    });

    test('masks to a single byte (defensive against >0xFF input)', () {
      final c = MeshCoreAutoAddConfig.fromFlagsByte(0xFF02);
      // Only the low byte matters.
      expect(c.autoAddChat, isTrue);
    });
  });

  group('MeshCoreAutoAddConfig round-trip - D47-A', () {
    test('every byte 0x00..0xFF round-trips byte-for-byte', () {
      for (var b = 0; b <= 0xFF; b++) {
        final config = MeshCoreAutoAddConfig.fromFlagsByte(b);
        expect(
          config.toFlagsByte(),
          b,
          reason:
              'byte 0x${b.toRadixString(16).padLeft(2, '0')} '
              'did not round-trip',
        );
      }
    });
  });

  group('MeshCoreAutoAddConfig.copyWith - D47-A', () {
    test('updates only the named field', () {
      const base = MeshCoreAutoAddConfig(
        autoAddChat: true,
        autoAddRepeater: true,
      );
      final updated = base.copyWith(autoAddRepeater: false);
      expect(updated.autoAddChat, isTrue);
      expect(updated.autoAddRepeater, isFalse);
      expect(updated.autoAddRoomServer, isFalse);
    });

    test('reservedBits preserved when not overridden', () {
      const base = MeshCoreAutoAddConfig(reservedBits: 0x40);
      final updated = base.copyWith(autoAddChat: true);
      expect(updated.reservedBits, 0x40);
    });
  });

  group('MeshCoreAutoAddConfig equality - D47-A', () {
    test('identical content is equal', () {
      const a = MeshCoreAutoAddConfig(autoAddChat: true, autoAddSensor: true);
      const b = MeshCoreAutoAddConfig(autoAddChat: true, autoAddSensor: true);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('differing reservedBits make instances distinct', () {
      const a = MeshCoreAutoAddConfig(autoAddChat: true);
      const b = MeshCoreAutoAddConfig(autoAddChat: true, reservedBits: 0x20);
      expect(a == b, isFalse);
    });
  });

  group('MeshCoreAutoAddConfig redaction - D47-A', () {
    test('toString never leaks the unpacked flag content', () {
      const c = MeshCoreAutoAddConfig(autoAddChat: true, autoAddRepeater: true);
      final s = c.toString();
      // No verbose field dump — only the packed byte.
      expect(s.contains('autoAddChat'), isFalse);
      expect(s.contains('overwriteOldest'), isFalse);
      // Single byte hex emitted.
      expect(RegExp(r'flags=0x[0-9a-f]{2}').hasMatch(s), isTrue);
    });
  });
}
