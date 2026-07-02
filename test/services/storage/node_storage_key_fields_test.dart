// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Round-trip tests for the PKI key fields on persisted nodes. The stored
// public key is the trusted baseline for DM key-mismatch detection, so it
// must survive a save/load cycle byte-for-byte, and the mismatch flag must
// persist alongside it. Legacy records without the fields must load with
// safe defaults.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/services/storage/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NodeStorageService key-field persistence', () {
    late NodeStorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = NodeStorageService();
      await storage.init();
    });

    test(
      'publicKey bytes and keyMismatch survive a save/load round-trip',
      () async {
        final key = List<int>.generate(32, (i) => i);
        await storage.saveNode(
          MeshNode(
            nodeNum: 0x2002,
            longName: 'Peer',
            hasPublicKey: true,
            publicKey: key,
            keyMismatch: true,
          ),
        );

        final loaded = await storage.getNode(0x2002);
        expect(loaded, isNotNull);
        expect(loaded!.hasPublicKey, isTrue);
        expect(loaded.publicKey, key);
        expect(loaded.keyMismatch, isTrue);
      },
    );

    test(
      'node without a key persists null publicKey and false mismatch',
      () async {
        await storage.saveNode(MeshNode(nodeNum: 0x3003, longName: 'NoKey'));

        final loaded = await storage.getNode(0x3003);
        expect(loaded, isNotNull);
        expect(loaded!.publicKey, isNull);
        expect(loaded.keyMismatch, isFalse);
      },
    );

    test(
      'legacy persisted record without key fields loads with defaults',
      () async {
        // Simulate a record written by a build that predates the key fields.
        SharedPreferences.setMockInitialValues({
          'nodes': jsonEncode([
            {'nodeNum': 0x4004, 'longName': 'Legacy', 'hasPublicKey': true},
          ]),
        });
        storage = NodeStorageService();
        await storage.init();

        final loaded = await storage.getNode(0x4004);
        expect(loaded, isNotNull);
        expect(loaded!.publicKey, isNull);
        expect(loaded.keyMismatch, isFalse);
      },
    );
  });

  group('MeshNode copyWith key fields', () {
    test('clearPendingPublicKey nulls the pending key', () {
      final node = MeshNode(
        nodeNum: 1,
        keyMismatch: true,
        pendingPublicKey: const [1, 2, 3],
      );
      final cleared = node.copyWith(
        keyMismatch: false,
        clearPendingPublicKey: true,
      );
      expect(cleared.keyMismatch, isFalse);
      expect(cleared.pendingPublicKey, isNull);
    });

    test('copyWith preserves key fields when untouched', () {
      final node = MeshNode(
        nodeNum: 1,
        keyMismatch: true,
        pendingPublicKey: const [1, 2, 3],
      );
      final copied = node.copyWith(longName: 'Renamed');
      expect(copied.keyMismatch, isTrue);
      expect(copied.pendingPublicKey, const [1, 2, 3]);
    });
  });
}
