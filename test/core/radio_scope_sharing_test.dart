// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/radio_scope.dart';

void main() {
  late Directory root;

  const home = 0xa6960864; // node-a6960864
  const mobile = 0x6944378a; // node-6944378a
  const third = 0x00001111; // node-00001111

  Directory scopeDir(String key) => Directory(p.join(root.path, 'radios', key));

  Future<void> writeScopedFile(String name, String contents) async {
    final path = await RadioScope.instance.databasePath(name);
    await File(path).writeAsString(contents);
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('radio_scope_sharing_');
    SharedPreferences.setMockInitialValues({});
    RadioScope.instance.debugSetRoot(root);
    await RadioScope.instance.init();
  });

  tearDown(() async {
    RadioScope.instance.debugSetRoot(null);
    if (await root.exists()) await root.delete(recursive: true);
  });

  group('shared datasets', () {
    test('a sharing radio reads and writes the shared scope', () async {
      await RadioScope.instance.useNodeNum(home, label: 'Home');
      await writeScopedFile('messages.db', 'home history');
      await RadioScope.instance.useNodeNum(mobile, label: 'Mobile');
      await writeScopedFile('messages.db', 'mobile history');

      final shared = await RadioScope.instance.shareScope(
        key: 'node-6944378a',
        into: 'node-a6960864',
      );
      expect(shared, isTrue);
      // The mobile radio is the one connected, so the session moves at once.
      expect(RadioScope.instance.currentKey, 'node-a6960864');

      // Reconnecting the mobile radio lands on the shared scope, while its
      // own bookkeeping stays with its identity.
      await RadioScope.instance.useNodeNum(home);
      await RadioScope.instance.useNodeNum(
        mobile,
        deviceId: 'ble:mobile-uuid',
        label: 'Mobile 2',
      );
      expect(RadioScope.instance.currentKey, 'node-a6960864');
      expect(
        File(
          p.join(scopeDir('node-a6960864').path, 'messages.db'),
        ).readAsStringSync(),
        'home history',
      );
      // Nothing was merged or lost: the mobile radio's own data still exists.
      expect(
        File(
          p.join(scopeDir('node-6944378a').path, 'messages.db'),
        ).readAsStringSync(),
        'mobile history',
      );

      final scopes = await RadioScope.instance.list();
      final mobileInfo = scopes.firstWhere((s) => s.key == 'node-6944378a');
      expect(mobileInfo.sharesWith, 'node-a6960864');
      expect(mobileInfo.label, 'Mobile 2');
      expect(mobileInfo.isCurrent, isFalse);
      expect(
        scopes.firstWhere((s) => s.key == 'node-a6960864').sharesWith,
        isNull,
      );
    });

    test('device ids of a sharing radio resolve to the shared scope', () async {
      await RadioScope.instance.useNodeNum(home);
      await RadioScope.instance.useNodeNum(mobile, deviceId: 'ble:mobile');
      await RadioScope.instance.shareScope(
        key: 'node-6944378a',
        into: 'node-a6960864',
      );
      await RadioScope.instance.useNodeNum(third);
      expect(RadioScope.instance.currentKey, 'node-00001111');

      await RadioScope.instance.useDevice(deviceId: 'ble:mobile');
      expect(RadioScope.instance.currentKey, 'node-a6960864');
    });

    test('stopSharing returns the radio to its own data', () async {
      await RadioScope.instance.useNodeNum(home);
      await RadioScope.instance.useNodeNum(mobile);
      await RadioScope.instance.shareScope(
        key: 'node-6944378a',
        into: 'node-a6960864',
      );
      expect(RadioScope.instance.currentKey, 'node-a6960864');

      expect(await RadioScope.instance.stopSharing('node-6944378a'), isTrue);
      // The mobile radio is still the connected one, so it moves back.
      expect(RadioScope.instance.currentKey, 'node-6944378a');
      expect(await RadioScope.instance.stopSharing('node-6944378a'), isFalse);

      final scopes = await RadioScope.instance.list();
      expect(scopes.every((s) => s.sharesWith == null), isTrue);
    });

    test('sharing into a sharing radio follows the chain', () async {
      await RadioScope.instance.useNodeNum(home);
      await writeScopedFile('messages.db', 'home');
      await RadioScope.instance.useNodeNum(mobile);
      await writeScopedFile('messages.db', 'mobile');
      await RadioScope.instance.useNodeNum(third);
      await writeScopedFile('messages.db', 'third');
      await RadioScope.instance.shareScope(
        key: 'node-6944378a',
        into: 'node-a6960864',
      );
      await RadioScope.instance.shareScope(
        key: 'node-00001111',
        into: 'node-6944378a',
      );
      final scopes = await RadioScope.instance.list();
      expect(
        scopes.firstWhere((s) => s.key == 'node-00001111').sharesWith,
        'node-a6960864',
      );
      expect(RadioScope.instance.currentKey, 'node-a6960864');
    });

    test('re-pointing a scope others share carries them along', () async {
      await RadioScope.instance.useNodeNum(home);
      await writeScopedFile('messages.db', 'home');
      await RadioScope.instance.useNodeNum(mobile);
      await writeScopedFile('messages.db', 'mobile');
      await RadioScope.instance.useNodeNum(third);
      await writeScopedFile('messages.db', 'third');
      await RadioScope.instance.shareScope(
        key: 'node-00001111',
        into: 'node-6944378a',
      );
      await RadioScope.instance.shareScope(
        key: 'node-6944378a',
        into: 'node-a6960864',
      );
      final scopes = await RadioScope.instance.list();
      expect(
        scopes.firstWhere((s) => s.key == 'node-00001111').sharesWith,
        'node-a6960864',
      );
    });

    test('invalid requests are refused', () async {
      await RadioScope.instance.useNodeNum(home);
      await RadioScope.instance.useNodeNum(mobile);
      expect(
        await RadioScope.instance.shareScope(
          key: 'node-6944378a',
          into: 'node-6944378a',
        ),
        isFalse,
      );
      expect(
        await RadioScope.instance.shareScope(
          key: 'dev-deadbeef',
          into: 'node-a6960864',
        ),
        isFalse,
      );
      expect(
        await RadioScope.instance.shareScope(
          key: 'node-6944378a',
          into: kLegacyRadioScopeKey,
        ),
        isFalse,
      );
    });

    test('deleting a shared dataset ends the arrangements on it', () async {
      await RadioScope.instance.useNodeNum(home);
      await writeScopedFile('messages.db', 'home');
      await RadioScope.instance.useNodeNum(mobile);
      await writeScopedFile('messages.db', 'mobile');
      await RadioScope.instance.shareScope(
        key: 'node-6944378a',
        into: 'node-a6960864',
      );
      // Move the session elsewhere so the home scope can be deleted.
      await RadioScope.instance.useNodeNum(third);
      await writeScopedFile('messages.db', 'third');

      expect(await RadioScope.instance.deleteScope('node-a6960864'), isTrue);
      final scopes = await RadioScope.instance.list();
      expect(
        scopes.firstWhere((s) => s.key == 'node-6944378a').sharesWith,
        isNull,
      );
      await RadioScope.instance.useNodeNum(mobile);
      expect(RadioScope.instance.currentKey, 'node-6944378a');
    });

    test('a fresh connect folds its provisional directory away', () async {
      await RadioScope.instance.useNodeNum(home);
      await RadioScope.instance.useNodeNum(mobile);
      await RadioScope.instance.shareScope(
        key: 'node-6944378a',
        into: 'node-a6960864',
      );
      await RadioScope.instance.useNodeNum(third);

      // Unknown device id: a provisional scope opens, then the identity
      // arrives and resolves to the shared dataset.
      await RadioScope.instance.useDevice(deviceId: 'ble:new-uuid');
      final provisional = RadioScope.instance.currentKey;
      expect(isProvisionalRadioScopeKey(provisional), isTrue);
      await writeScopedFile('messages.db', '');
      await RadioScope.instance.useNodeNum(mobile, deviceId: 'ble:new-uuid');

      expect(RadioScope.instance.currentKey, 'node-a6960864');
      expect(scopeDir(provisional).existsSync(), isFalse);
    });
  });
}
