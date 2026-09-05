// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/radio_scope.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;

  Directory scopeDir(String key) => Directory(p.join(root.path, 'radios', key));

  Future<void> writeScopedFile(String fileName, String contents) async {
    final path = await RadioScope.instance.databasePath(fileName);
    await File(path).writeAsString(contents);
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('radio_scope_test_');
    SharedPreferences.setMockInitialValues({});
    RadioScope.instance.debugSetRoot(root);
  });

  tearDown(() async {
    RadioScope.instance.debugSetRoot(null);
    try {
      await root.delete(recursive: true);
    } on FileSystemException {
      // Already gone.
    }
  });

  group('scope keys', () {
    test('a node scope key is the zero-padded node number in hex', () {
      expect(radioScopeKeyForNodeNum(0x1234abcd), 'node-1234abcd');
      expect(radioScopeKeyForNodeNum(0x0abc), 'node-00000abc');
    });

    test('node keys are final, device and legacy keys are provisional', () {
      expect(isProvisionalRadioScopeKey(radioScopeKeyForNodeNum(1)), isFalse);
      expect(isProvisionalRadioScopeKey(kLegacyRadioScopeKey), isTrue);
      expect(
        isProvisionalRadioScopeKey(radioScopeKeyForDeviceId('ble-uuid')),
        isTrue,
      );
    });

    test('device keys are stable and filesystem-safe', () {
      const messy = 'tcp:Meshtastic_ABCD.local:4403';
      final key = radioScopeKeyForDeviceId(messy);
      expect(key, radioScopeKeyForDeviceId(messy));
      expect(key, matches(RegExp(r'^dev-[0-9a-f]{8}$')));
      expect(key, isNot(radioScopeKeyForDeviceId('$messy ')));
    });
  });

  group('migration of pre-scoping data', () {
    test(
      'moves databases and preferences into the last radio\'s scope',
      () async {
        await File(p.join(root.path, 'messages.db')).writeAsString('A');
        await File(p.join(root.path, 'messages.db-wal')).writeAsString('A-wal');
        final cacheDir = Directory(p.join(root.path, 'cache'))
          ..createSync(recursive: true);
        await File(
          p.join(cacheDir.path, 'mesh_seen_packets.db'),
        ).writeAsString('D');

        SharedPreferences.setMockInitialValues({
          'last_my_node_num': 0x1234abcd,
          'last_device_id': 'ble-a',
          'last_device_name': 'Meshtastic_abcd',
          'nodes': '[{"nodeNum":1}]',
          'device_favorites': ['1', '2'],
        });

        await RadioScope.instance.init();

        expect(RadioScope.instance.currentKey, 'node-1234abcd');
        final scope = scopeDir('node-1234abcd');
        expect(File(p.join(scope.path, 'messages.db')).existsSync(), isTrue);
        expect(
          File(p.join(scope.path, 'messages.db-wal')).existsSync(),
          isTrue,
        );
        expect(
          File(p.join(scope.path, 'mesh_seen_packets.db')).existsSync(),
          isTrue,
        );
        expect(File(p.join(root.path, 'messages.db')).existsSync(), isFalse);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('rs/node-1234abcd/nodes'), '[{"nodeNum":1}]');
        expect(prefs.getString('nodes'), isNull);
        expect(prefs.getStringList('rs/node-1234abcd/device_favorites'), [
          '1',
          '2',
        ]);
      },
    );

    test('reconnecting the migrated device keeps its scope', () async {
      SharedPreferences.setMockInitialValues({
        'last_my_node_num': 0x1234abcd,
        'last_device_id': 'ble-a',
      });
      await RadioScope.instance.init();

      final changed = await RadioScope.instance.useDevice(deviceId: 'ble-a');

      expect(changed, isFalse);
      expect(RadioScope.instance.currentKey, 'node-1234abcd');
    });

    test(
      'creates no scope directory when there is nothing to migrate',
      () async {
        // A fresh install must not end up with an empty scope, which would
        // surface on the Radio Data screen as a radio holding no data.
        await RadioScope.instance.init();

        expect(await RadioScope.instance.list(), isEmpty);
      },
    );

    test('runs once', () async {
      SharedPreferences.setMockInitialValues({'nodes': 'first'});
      await RadioScope.instance.init();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('nodes', 'second');
      RadioScope.instance.debugSetRoot(root);
      await RadioScope.instance.init();

      expect(prefs.getString('nodes'), 'second');
    });
  });

  group('identity promotion', () {
    test(
      'promotes a provisional scope once the radio reports its id',
      () async {
        await RadioScope.instance.init();
        await RadioScope.instance.useDevice(
          deviceId: 'ble-b',
          label: 'Radio B',
        );
        final provisional = RadioScope.instance.currentKey;
        expect(provisional, radioScopeKeyForDeviceId('ble-b'));

        await writeScopedFile('messages.db', 'observed before identity');
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(RadioScope.instance.prefsKey('nodes'), 'early');

        final changed = await RadioScope.instance.useNodeNum(
          0xdeadbeef,
          deviceId: 'ble-b',
        );

        expect(changed, isTrue);
        expect(RadioScope.instance.currentKey, 'node-deadbeef');
        expect(scopeDir(provisional).existsSync(), isFalse);
        expect(
          File(
            p.join(scopeDir('node-deadbeef').path, 'messages.db'),
          ).readAsStringSync(),
          'observed before identity',
        );
        expect(prefs.getString('rs/node-deadbeef/nodes'), 'early');
        expect(prefs.getString('rs/$provisional/nodes'), isNull);
      },
    );

    test('a known device lands in its scope before connecting', () async {
      await RadioScope.instance.init();
      await RadioScope.instance.useDevice(deviceId: 'ble-b');
      await RadioScope.instance.useNodeNum(0xdeadbeef, deviceId: 'ble-b');
      await RadioScope.instance.useDevice(deviceId: 'ble-c');
      expect(RadioScope.instance.currentKey, radioScopeKeyForDeviceId('ble-c'));

      await RadioScope.instance.useDevice(deviceId: 'ble-b');

      expect(RadioScope.instance.currentKey, 'node-deadbeef');
    });

    test('adopts the existing scope when the radio is already known under '
        'another device id', () async {
      await RadioScope.instance.init();
      await RadioScope.instance.useNodeNum(0xdeadbeef);
      await writeScopedFile('messages.db', 'history');

      // Same radio, new BLE UUID: connect opens a provisional scope.
      await RadioScope.instance.useDevice(deviceId: 'ble-rotated');
      final provisional = RadioScope.instance.currentKey;
      await writeScopedFile('messages.db', '');

      await RadioScope.instance.useNodeNum(0xdeadbeef, deviceId: 'ble-rotated');

      expect(RadioScope.instance.currentKey, 'node-deadbeef');
      expect(scopeDir(provisional).existsSync(), isFalse);
      expect(
        File(
          p.join(scopeDir('node-deadbeef').path, 'messages.db'),
        ).readAsStringSync(),
        'history',
      );
    });

    test('a mismatched identity switches scope without promoting', () async {
      await RadioScope.instance.init();
      await RadioScope.instance.useNodeNum(0x1111);
      await writeScopedFile('messages.db', 'radio one');

      await RadioScope.instance.useNodeNum(0x2222);

      expect(RadioScope.instance.currentKey, 'node-00002222');
      expect(
        File(
          p.join(scopeDir('node-00001111').path, 'messages.db'),
        ).readAsStringSync(),
        'radio one',
      );
    });
  });

  // Firmware 2.8 derives the node number from the radio's public key, so a
  // radio upgraded to it reports a new number with the same key. Its
  // history must follow it rather than sit in a scope nothing selects.
  group('renumbered radios', () {
    const key = [1, 2, 3, 4, 250, 251, 252, 253];
    const otherKey = [9, 9, 9, 9];

    test('same key under a new number moves the old scope across', () async {
      await RadioScope.instance.init();
      await RadioScope.instance.useNodeNum(
        0xa6960864,
        deviceId: 'tcp:192.168.5.104:4403',
        label: 'socialmesh.app',
        ownPublicKey: key,
      );
      await writeScopedFile('messages.db', 'years of history');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('rs/node-a6960864/nodes', '[{"nodeNum":7}]');

      await RadioScope.instance.useNodeNum(
        0x6944378a,
        deviceId: 'tcp:192.168.5.104:4403',
        ownPublicKey: key,
      );

      expect(RadioScope.instance.currentKey, 'node-6944378a');
      expect(
        File(
          p.join(scopeDir('node-6944378a').path, 'messages.db'),
        ).readAsStringSync(),
        'years of history',
      );
      expect(scopeDir('node-a6960864').existsSync(), isFalse);
      expect(prefs.getString('rs/node-6944378a/nodes'), '[{"nodeNum":7}]');
      expect(prefs.getString('rs/node-a6960864/nodes'), isNull);

      // The device now maps to the new scope and the label came along.
      await RadioScope.instance.useNodeNum(0x1111);
      await RadioScope.instance.useDevice(deviceId: 'tcp:192.168.5.104:4403');
      expect(RadioScope.instance.currentKey, 'node-6944378a');
      final scopes = await RadioScope.instance.list();
      expect(
        scopes.firstWhere((s) => s.key == 'node-6944378a').label,
        'socialmesh.app',
      );
    });

    test(
      'a different key over the same TCP endpoint is another radio',
      () async {
        await RadioScope.instance.init();
        await RadioScope.instance.useNodeNum(
          0x1111,
          deviceId: 'tcp:127.0.0.1:4403',
          ownPublicKey: key,
        );
        await writeScopedFile('messages.db', 'radio one');

        await RadioScope.instance.useNodeNum(
          0x2222,
          deviceId: 'tcp:127.0.0.1:4403',
          ownPublicKey: otherKey,
        );

        expect(RadioScope.instance.currentKey, 'node-00002222');
        expect(
          File(
            p.join(scopeDir('node-00001111').path, 'messages.db'),
          ).readAsStringSync(),
          'radio one',
        );
      },
    );

    test('the key arriving after the switch folds the old scope in', () async {
      // Real ordering: the connect path lands on the new number before
      // the radio's own NodeInfo (and key) has been replayed.
      await RadioScope.instance.init();
      await RadioScope.instance.useNodeNum(0x1111, ownPublicKey: key);
      await writeScopedFile('messages.db', 'radio one');

      final switched = await RadioScope.instance.useNodeNum(
        0x2222,
        deviceId: 'tcp:10.0.0.1:4403',
      );
      expect(switched, isTrue);
      expect(RadioScope.instance.currentKey, 'node-00002222');

      final folded = await RadioScope.instance.useNodeNum(
        0x2222,
        deviceId: 'tcp:10.0.0.1:4403',
        ownPublicKey: key,
      );

      expect(folded, isTrue);
      expect(RadioScope.instance.currentKey, 'node-00002222');
      expect(
        File(
          p.join(scopeDir('node-00002222').path, 'messages.db'),
        ).readAsStringSync(),
        'radio one',
      );
      expect(scopeDir('node-00001111').existsSync(), isFalse);

      // Nothing left to fold: a repeat call with the key is a no-op.
      final again = await RadioScope.instance.useNodeNum(
        0x2222,
        ownPublicKey: key,
      );
      expect(again, isFalse);
    });

    test('a per-radio BLE identity is trusted when no key is known', () async {
      await RadioScope.instance.init();
      await RadioScope.instance.useDevice(deviceId: 'ble-uuid-0864');
      await RadioScope.instance.useNodeNum(0x1111, deviceId: 'ble-uuid-0864');
      await writeScopedFile('messages.db', 'radio one');

      await RadioScope.instance.useNodeNum(0x2222, deviceId: 'ble-uuid-0864');

      expect(RadioScope.instance.currentKey, 'node-00002222');
      expect(
        File(
          p.join(scopeDir('node-00002222').path, 'messages.db'),
        ).readAsStringSync(),
        'radio one',
      );
      expect(scopeDir('node-00001111').existsSync(), isFalse);
    });

    test(
      'a BLE identity does not move data into a scope that has its own',
      () async {
        await RadioScope.instance.init();
        await RadioScope.instance.useNodeNum(0x2222);
        await writeScopedFile(
          'messages.db',
          'existing radio two history that is well past the empty threshold '
              '${'x' * (70 * 1024)}',
        );
        await RadioScope.instance.useNodeNum(0x1111, deviceId: 'ble-uuid-0864');
        await writeScopedFile('messages.db', 'radio one');

        await RadioScope.instance.useNodeNum(0x2222, deviceId: 'ble-uuid-0864');

        expect(RadioScope.instance.currentKey, 'node-00002222');
        expect(
          File(
            p.join(scopeDir('node-00001111').path, 'messages.db'),
          ).readAsStringSync(),
          'radio one',
        );
      },
    );

    test('deleting a scope forgets its recorded key', () async {
      await RadioScope.instance.init();
      await RadioScope.instance.useNodeNum(0x1111, ownPublicKey: key);
      await writeScopedFile('messages.db', 'radio one');
      await RadioScope.instance.useNodeNum(0x3333, ownPublicKey: otherKey);

      expect(await RadioScope.instance.deleteScope('node-00001111'), isTrue);

      // A later radio with the deleted scope's key starts fresh.
      await RadioScope.instance.useNodeNum(0x4444, ownPublicKey: key);
      expect(RadioScope.instance.currentKey, 'node-00004444');
      expect(
        File(
          await RadioScope.instance.databasePath('messages.db'),
        ).existsSync(),
        isFalse,
      );
    });
  });

  group('switching', () {
    test('each radio keeps its own files across a switch and back', () async {
      await RadioScope.instance.init();

      await RadioScope.instance.useNodeNum(0xaaaa);
      await writeScopedFile('messages.db', 'from A');

      await RadioScope.instance.useNodeNum(0xbbbb);
      expect(
        File(
          await RadioScope.instance.databasePath('messages.db'),
        ).existsSync(),
        isFalse,
      );
      await writeScopedFile('messages.db', 'from B');

      await RadioScope.instance.useNodeNum(0xaaaa);
      expect(
        File(
          await RadioScope.instance.databasePath('messages.db'),
        ).readAsStringSync(),
        'from A',
      );
    });

    test('open stores are closed before the scope moves', () async {
      await RadioScope.instance.init();
      await RadioScope.instance.useNodeNum(0xaaaa);

      var closed = 0;
      final store = Object();
      RadioScope.instance.registerCloser(store, () async => closed++);

      await RadioScope.instance.useNodeNum(0xbbbb);

      expect(closed, 1);
    });

    test('a closer that throws does not block the switch', () async {
      await RadioScope.instance.init();
      await RadioScope.instance.useNodeNum(0xaaaa);
      RadioScope.instance.registerCloser(
        Object(),
        () async => throw StateError('already closed'),
      );

      await RadioScope.instance.useNodeNum(0xbbbb);

      expect(RadioScope.instance.currentKey, 'node-0000bbbb');
    });

    test('unregistered stores are not closed again', () async {
      await RadioScope.instance.init();
      await RadioScope.instance.useNodeNum(0xaaaa);
      var closed = 0;
      final store = Object();
      RadioScope.instance.registerCloser(store, () async => closed++);
      RadioScope.instance.unregisterCloser(store);

      await RadioScope.instance.useNodeNum(0xbbbb);

      expect(closed, 0);
    });

    test('the change stream reports the new scope', () async {
      await RadioScope.instance.init();
      final seen = <String>[];
      final subscription = RadioScope.instance.changes.listen(seen.add);
      addTearDown(subscription.cancel);

      await RadioScope.instance.useNodeNum(0xaaaa);
      await RadioScope.instance.useNodeNum(0xbbbb);
      await Future<void>.delayed(Duration.zero);

      expect(seen, ['node-0000aaaa', 'node-0000bbbb']);
    });
  });

  group('scoped preference reads', () {
    test('fall back to the unscoped key only while unidentified', () async {
      SharedPreferences.setMockInitialValues({'nodes': 'pre-scoping'});
      final prefs = await SharedPreferences.getInstance();
      // Deliberately not init()'d: the migration has not run yet.
      expect(
        RadioScope.instance.readScoped('nodes', prefs.getString),
        'pre-scoping',
      );

      await RadioScope.instance.useNodeNum(0xaaaa);

      expect(RadioScope.instance.readScoped('nodes', prefs.getString), isNull);
    });

    test('prefer the scoped value when both exist', () async {
      SharedPreferences.setMockInitialValues({'nodes': 'pre-scoping'});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(RadioScope.instance.prefsKey('nodes'), 'scoped');

      expect(
        RadioScope.instance.readScoped('nodes', prefs.getString),
        'scoped',
      );
    });
  });

  group('labels', () {
    test('a real advertised name survives later auto-reconnects', () async {
      await RadioScope.instance.init();
      const endpoint = 'tcp:192.168.5.104:4403';

      // Discovered over mDNS, so the connect carries the radio's own name.
      await RadioScope.instance.useDevice(deviceId: endpoint, label: '0864');
      await RadioScope.instance.useNodeNum(0xa6960864, deviceId: endpoint);
      await writeScopedFile('messages.db', 'x');
      // Auto-reconnect only knows the saved endpoint, and passes it as the
      // device "name". That must not replace the real one.
      await RadioScope.instance.useDevice(deviceId: endpoint, label: endpoint);

      final scope = (await RadioScope.instance.list()).single;
      expect(scope.label, '0864');
    });

    test('a synthetic name still seeds a radio with no name yet', () async {
      await RadioScope.instance.init();
      const endpoint = 'tcp:192.168.5.77:4403';

      await RadioScope.instance.useDevice(deviceId: endpoint, label: endpoint);
      await RadioScope.instance.useNodeNum(0xb0b0beef, deviceId: endpoint);
      await writeScopedFile('messages.db', 'x');

      final scope = (await RadioScope.instance.list()).single;
      expect(scope.label, endpoint);
    });

    test('a real name replaces a synthetic one', () async {
      await RadioScope.instance.init();
      const endpoint = 'tcp:192.168.5.77:4403';

      await RadioScope.instance.useDevice(deviceId: endpoint, label: endpoint);
      await RadioScope.instance.useNodeNum(0xb0b0beef, deviceId: endpoint);
      await RadioScope.instance.useDevice(
        deviceId: endpoint,
        label: 'Fake Radio B',
      );
      await writeScopedFile('messages.db', 'x');

      final scope = (await RadioScope.instance.list()).single;
      expect(scope.label, 'Fake Radio B');
    });
  });

  group('stored maps', () {
    test('reads entries written with the legacy NUL separator', () async {
      // An install from the build that wrote NUL-separated entries must keep
      // its device mapping, or its next connect opens a provisional scope
      // and the radio appears to have lost its data.
      SharedPreferences.setMockInitialValues({
        'radio_scope_current': 'node-a6960864',
        'radio_scope_migrated': true,
        'radio_scope_devices': ['ble-legacy\u0000node-a6960864'],
        'radio_scope_labels': ['node-a6960864\u0000Legacy Radio'],
      });
      RadioScope.instance.debugSetRoot(root);
      await RadioScope.instance.init();

      final changed = await RadioScope.instance.useDevice(
        deviceId: 'ble-legacy',
      );

      expect(changed, isFalse);
      expect(RadioScope.instance.currentKey, 'node-a6960864');
    });

    test('round-trips a label containing spaces', () async {
      await RadioScope.instance.init();
      await RadioScope.instance.useDevice(
        deviceId: 'ble-x',
        label: 'Meshtastic Base Station 1',
      );
      await RadioScope.instance.useNodeNum(0x1234, deviceId: 'ble-x');
      await writeScopedFile('messages.db', 'x');

      final scope = (await RadioScope.instance.list()).single;
      expect(scope.label, 'Meshtastic Base Station 1');
    });
  });

  group('stored profiles', () {
    test('lists every scope with its label and size', () async {
      await RadioScope.instance.init();
      await RadioScope.instance.useDevice(deviceId: 'ble-a', label: 'Radio A');
      await RadioScope.instance.useNodeNum(0xaaaa, deviceId: 'ble-a');
      await writeScopedFile('messages.db', 'x' * 128);
      await RadioScope.instance.useNodeNum(0xbbbb);
      await writeScopedFile('messages.db', 'y');

      final scopes = await RadioScope.instance.list();

      expect(
        scopes.map((s) => s.key),
        containsAll(<String>['node-0000aaaa', 'node-0000bbbb']),
      );
      final a = scopes.firstWhere((s) => s.key == 'node-0000aaaa');
      expect(a.label, 'Radio A');
      expect(a.sizeBytes, 128);
      expect(a.nodeNum, 0xaaaa);
      expect(a.isCurrent, isFalse);
      expect(
        scopes.firstWhere((s) => s.key == 'node-0000bbbb').isCurrent,
        isTrue,
      );
    });

    test('delete removes a stored profile and its preferences', () async {
      await RadioScope.instance.init();
      await RadioScope.instance.useNodeNum(0xaaaa, deviceId: 'ble-a');
      await writeScopedFile('messages.db', 'A');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(RadioScope.instance.prefsKey('nodes'), 'A');
      await RadioScope.instance.useNodeNum(0xbbbb);

      final deleted = await RadioScope.instance.deleteScope('node-0000aaaa');

      expect(deleted, isTrue);
      expect(scopeDir('node-0000aaaa').existsSync(), isFalse);
      expect(prefs.getString('rs/node-0000aaaa/nodes'), isNull);
      expect(
        (await RadioScope.instance.list()).map((s) => s.key),
        isNot(contains('node-0000aaaa')),
      );
    });

    test('delete refuses the scope in use', () async {
      await RadioScope.instance.init();
      await RadioScope.instance.useNodeNum(0xaaaa);
      await writeScopedFile('messages.db', 'A');

      final deleted = await RadioScope.instance.deleteScope('node-0000aaaa');

      expect(deleted, isFalse);
      expect(scopeDir('node-0000aaaa').existsSync(), isTrue);
    });

    test('a deleted profile is forgotten by its device mapping', () async {
      await RadioScope.instance.init();
      await RadioScope.instance.useNodeNum(0xaaaa, deviceId: 'ble-a');
      await RadioScope.instance.useNodeNum(0xbbbb);
      await RadioScope.instance.deleteScope('node-0000aaaa');

      await RadioScope.instance.useDevice(deviceId: 'ble-a');

      expect(RadioScope.instance.currentKey, radioScopeKeyForDeviceId('ble-a'));
    });
  });
}
