// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/radio_scope.dart';
import 'package:socialmesh/features/tak/models/tak_event.dart';
import 'package:socialmesh/features/tak/providers/tak_providers.dart';
import 'package:socialmesh/features/tak/services/tak_database.dart';
import 'package:socialmesh/features/tak/services/tak_gateway_client.dart';
import 'package:socialmesh/providers/radio_scope_providers.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Each radio keeps its own TAK events. A radio switch replaces the store, so
// the persisted list has to follow it rather than keep the first radio's.

TakEvent _event(String uid) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return TakEvent(
    uid: uid,
    type: 'a-f-G-U-C',
    callsign: uid,
    lat: -37.7,
    lon: 145.0,
    timeUtcMs: now,
    staleUtcMs: now + const Duration(hours: 1).inMilliseconds,
    receivedUtcMs: now,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test(
    'switching radios moves the TAK list to the new radio\'s store',
    () async {
      SharedPreferences.setMockInitialValues({});
      final tempDir = await Directory.systemTemp.createTemp('tak_scope');
      RadioScope.instance.debugSetRoot(Directory(p.join(tempDir.path, 'root')));
      await RadioScope.instance.init();
      await RadioScope.instance.useNodeNum(0xaaaa);

      final firstRadio = TakDatabase(
        testDbPath: p.join(tempDir.path, 'node-0000aaaa-tak.db'),
      );
      await firstRadio.init();
      await firstRadio.upsert(_event('first-radio-unit'));
      await firstRadio.close();

      final client = TakGatewayClient(
        gatewayUrl: 'wss://tak.example.invalid',
        getAuthToken: () async => null,
      );
      final container = ProviderContainer(
        overrides: [
          takGatewayClientProvider.overrideWithValue(client),
          // Same wiring as production, with one file per scope on disk.
          takDatabaseProvider.overrideWith((ref) {
            final key = ref.watch(radioScopeProvider);
            final db = TakDatabase(
              testDbPath: p.join(tempDir.path, '$key-tak.db'),
            );
            bindStoreToRadioScope(ref, db, db.close);
            return db;
          }),
        ],
      );
      try {
        container.listen(takPersistenceNotifierProvider, (_, _) {});
        final before = await container.read(
          takPersistenceNotifierProvider.future,
        );
        expect(before.map((e) => e.uid), ['first-radio-unit']);

        await RadioScope.instance.useNodeNum(0xbbbb);
        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(
          await container.read(takPersistenceNotifierProvider.future),
          isEmpty,
        );
      } finally {
        container.dispose();
        client.dispose();
        RadioScope.instance.debugSetRoot(null);
        await tempDir.delete(recursive: true);
      }
    },
  );
}
