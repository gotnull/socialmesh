// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Round-trip tests for the firmware capability flags on persisted nodes.
// The XEdDSA capability gates the packet signature policy block on the
// security screen, so it must survive a save/load cycle, and legacy
// records without the field must load with it off.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/services/storage/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NodeStorageService capability-field persistence', () {
    late NodeStorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = NodeStorageService();
      await storage.init();
    });

    test('hasXeddsa survives a save/load round-trip', () async {
      await storage.saveNode(
        MeshNode(nodeNum: 0x4004, longName: 'Signer', hasXeddsa: true),
      );

      final loaded = await storage.loadNodes();
      final node = loaded.singleWhere((n) => n.nodeNum == 0x4004);
      expect(node.hasXeddsa, isTrue);
    });

    test('a node saved without the capability loads with it off', () async {
      await storage.saveNode(MeshNode(nodeNum: 0x5005, longName: 'Legacy'));

      final loaded = await storage.loadNodes();
      final node = loaded.singleWhere((n) => n.nodeNum == 0x5005);
      expect(node.hasXeddsa, isFalse);
    });

    test('copyWith preserves hasXeddsa when untouched', () {
      final node = MeshNode(nodeNum: 0x6006, hasXeddsa: true);
      expect(node.copyWith(longName: 'Renamed').hasXeddsa, isTrue);
      expect(node.copyWith(hasXeddsa: false).hasXeddsa, isFalse);
    });
  });
}
