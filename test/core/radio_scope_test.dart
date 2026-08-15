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
