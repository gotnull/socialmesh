// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/waypoints/models/mesh_waypoint.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';

void main() {
  group('MeshWaypoint', () {
    final receivedAt = DateTime.fromMillisecondsSinceEpoch(1700000000000);

    test('fromEvent maps fields and resolves isMine', () {
      final event = MeshWaypointEvent(
        id: 42,
        latitude: 37.7749,
        longitude: -122.4194,
        expire: 0,
        lockedTo: 0,
        name: 'Camp',
        description: 'Base',
        icon: 0x1F4CD,
        fromNodeNum: 0x1234,
        isDelete: false,
        receivedAt: receivedAt,
      );

      final mine = MeshWaypoint.fromEvent(event, myNodeNum: 0x1234);
      expect(mine.isMine, isTrue);
      expect(mine.id, 42);
      expect(mine.name, 'Camp');
      expect(mine.icon, 0x1F4CD);

      final other = MeshWaypoint.fromEvent(event, myNodeNum: 0x9999);
      expect(other.isMine, isFalse);
    });

    test('toMap / fromMap round-trips every field', () {
      final original = MeshWaypoint(
        id: 7,
        latitude: 1.5,
        longitude: -2.5,
        expire: 1700001234,
        lockedTo: 0xABCD,
        name: 'Pin',
        description: 'desc',
        icon: 0x1F525,
        sourceNodeNum: 0x1111,
        receivedAt: _zero,
        isMine: true,
      );

      final restored = MeshWaypoint.fromMap(original.toMap());
      expect(restored.id, original.id);
      expect(restored.latitude, original.latitude);
      expect(restored.longitude, original.longitude);
      expect(restored.expire, original.expire);
      expect(restored.lockedTo, original.lockedTo);
      expect(restored.name, original.name);
      expect(restored.description, original.description);
      expect(restored.icon, original.icon);
      expect(restored.sourceNodeNum, original.sourceNodeNum);
      expect(restored.isMine, original.isMine);
      expect(
        restored.receivedAt.millisecondsSinceEpoch,
        original.receivedAt.millisecondsSinceEpoch,
      );
    });

    test('isLocked reflects lockedTo', () {
      expect(_wp(lockedTo: 0).isLocked, isFalse);
      expect(_wp(lockedTo: 5).isLocked, isTrue);
    });

    test('expire semantics: 0 = never, 1 = delete sentinel, >1 = real', () {
      expect(_wp(expire: 0).hasExpiry, isFalse);
      expect(_wp(expire: 0).isExpired, isFalse);
      // Sentinel is not a real expiry.
      expect(_wp(expire: 1).hasExpiry, isFalse);
      expect(_wp(expire: 1).isExpired, isFalse);
      // Past real expiry.
      final past = DateTime.now().millisecondsSinceEpoch ~/ 1000 - 100;
      expect(_wp(expire: past).isExpired, isTrue);
      // Future real expiry.
      final future = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 10000;
      expect(_wp(expire: future).hasExpiry, isTrue);
      expect(_wp(expire: future).isExpired, isFalse);
    });

    test('iconEmoji renders glyph and empty for 0', () {
      expect(_wp(icon: 0).iconEmoji, '');
      expect(_wp(icon: 0x1F4CD).iconEmoji, '📍');
    });

    test('hasRenderableIcon gates non-zero valid scalars', () {
      expect(_wp(icon: 0).hasRenderableIcon, isFalse);
      expect(_wp(icon: 0x1F4CD).hasRenderableIcon, isTrue);
    });

    test('malformed icon scalars fall back instead of crashing render', () {
      // A peer fully controls the wire `icon`; a surrogate half or out-of-range
      // scalar would form malformed UTF-16 and crash the paragraph builder.
      for (final bad in [0xD800, 0xDBFF, 0xDC00, 0xDFFF, 0x110000, -1]) {
        expect(_wp(icon: bad).hasRenderableIcon, isFalse, reason: '$bad');
        expect(_wp(icon: bad).iconEmoji, '', reason: '$bad');
      }
    });
  });
}

final _zero = DateTime.fromMillisecondsSinceEpoch(0);

MeshWaypoint _wp({int expire = 0, int lockedTo = 0, int icon = 0}) {
  return MeshWaypoint(
    id: 1,
    latitude: 0,
    longitude: 0,
    expire: expire,
    lockedTo: lockedTo,
    icon: icon,
    sourceNodeNum: 0,
    receivedAt: _zero,
  );
}
