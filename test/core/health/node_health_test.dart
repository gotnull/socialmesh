// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// PR-3: protocol-agnostic node-health projection (fresh / stale / offline /
// unknown). Pins the classifier boundaries against PresenceThresholds and
// the two thin protocol adapters (MeshNode, MeshCoreContact).

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/health/node_health.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/models/meshcore_contact.dart';
import 'package:socialmesh/models/presence_confidence.dart';

void main() {
  final now = DateTime(2026, 6, 15, 12, 0, 0);

  group('classifyHealth boundaries', () {
    test('null lastActivity -> unknown', () {
      expect(
        classifyHealth(lastActivity: null, now: now),
        NodeHealthState.unknown,
      );
    });

    test('implausible future timestamp -> unknown', () {
      expect(
        classifyHealth(
          lastActivity: now.add(const Duration(days: 400)),
          now: now,
        ),
        NodeHealthState.unknown,
      );
    });

    test('negative age (slightly in the future) -> unknown', () {
      expect(
        classifyHealth(
          lastActivity: now.add(const Duration(minutes: 1)),
          now: now,
        ),
        NodeHealthState.unknown,
      );
    });

    test('exactly freshWindow -> fresh', () {
      expect(
        classifyHealth(
          lastActivity: now.subtract(PresenceThresholds.freshWindow),
          now: now,
        ),
        NodeHealthState.fresh,
      );
    });

    test('just over freshWindow -> stale', () {
      expect(
        classifyHealth(
          lastActivity: now.subtract(
            PresenceThresholds.freshWindow + const Duration(seconds: 1),
          ),
          now: now,
        ),
        NodeHealthState.stale,
      );
    });

    test('exactly onlineWindow -> stale', () {
      expect(
        classifyHealth(
          lastActivity: now.subtract(PresenceThresholds.onlineWindow),
          now: now,
        ),
        NodeHealthState.stale,
      );
    });

    test('just over onlineWindow -> offline', () {
      expect(
        classifyHealth(
          lastActivity: now.subtract(
            PresenceThresholds.onlineWindow + const Duration(seconds: 1),
          ),
          now: now,
        ),
        NodeHealthState.offline,
      );
    });
  });

  group('MeshNode adapter', () {
    test('lastHeard within fresh window -> fresh', () {
      final node = MeshNode(
        nodeNum: 1,
        lastHeard: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      expect(node.healthState, NodeHealthState.fresh);
    });

    test('lastHeard 30 min ago -> stale', () {
      final node = MeshNode(
        nodeNum: 1,
        lastHeard: DateTime.now().subtract(const Duration(minutes: 30)),
      );
      expect(node.healthState, NodeHealthState.stale);
    });

    test('lastHeard 3 hours ago -> offline', () {
      final node = MeshNode(
        nodeNum: 1,
        lastHeard: DateTime.now().subtract(const Duration(hours: 3)),
      );
      expect(node.healthState, NodeHealthState.offline);
    });

    test('no lastHeard -> unknown', () {
      final node = MeshNode(nodeNum: 1);
      expect(node.healthState, NodeHealthState.unknown);
    });
  });

  group('MeshCoreContact adapter', () {
    MeshCoreContact contact({
      required DateTime lastSeen,
      required DateTime lastMessageAt,
    }) {
      return MeshCoreContact(
        publicKey: Uint8List(32),
        name: 'n',
        type: 1,
        pathLength: 0,
        path: Uint8List(0),
        lastSeen: lastSeen,
        lastMessageAt: lastMessageAt,
      );
    }

    test('uses the later of lastSeen and lastMessageAt (message newer)', () {
      // lastSeen old (offline), lastMessageAt recent (fresh) -> fresh.
      final c = contact(
        lastSeen: DateTime.now().subtract(const Duration(hours: 5)),
        lastMessageAt: DateTime.now().subtract(const Duration(minutes: 3)),
      );
      expect(c.healthState, NodeHealthState.fresh);
    });

    test('uses the later of lastSeen and lastMessageAt (seen newer)', () {
      // lastMessageAt old (offline), lastSeen recent (fresh) -> fresh.
      final c = contact(
        lastSeen: DateTime.now().subtract(const Duration(minutes: 2)),
        lastMessageAt: DateTime.now().subtract(const Duration(hours: 6)),
      );
      expect(c.healthState, NodeHealthState.fresh);
    });

    test('both old -> offline', () {
      final c = contact(
        lastSeen: DateTime.now().subtract(const Duration(hours: 4)),
        lastMessageAt: DateTime.now().subtract(const Duration(hours: 4)),
      );
      expect(c.healthState, NodeHealthState.offline);
    });
  });
}
