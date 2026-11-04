// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/radio_scope.dart';

// Handing a lost or replaced radio's data to a new radio: the data moves
// whole, the old radio is forgotten, and nothing the new radio stored of
// its own is ever overwritten.

void main() {
  late Directory root;

  const oldRadio = 0x0000aaaa; // node-0000aaaa
  const newRadio = 0x0000bbbb; // node-0000bbbb
  const third = 0x0000cccc; // node-0000cccc
  const oldKey = 'node-0000aaaa';
  const newKey = 'node-0000bbbb';
  const thirdKey = 'node-0000cccc';

  File scopedFile(String key, String name) =>
      File(p.join(root.path, 'radios', key, name));

  // Writes [bytes] of history into the active scope.
  Future<void> writeHistory(int bytes) async {
    final path = await RadioScope.instance.databasePath('messages.db');
    await File(path).writeAsBytes(List.filled(bytes, 1));
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('radio_scope_move_');
    SharedPreferences.setMockInitialValues({});
    RadioScope.instance.debugSetRoot(root);
    await RadioScope.instance.init();
  });

  tearDown(() async {
    RadioScope.instance.debugSetRoot(null);
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('moves the data to a radio with nothing stored and forgets the old '
      'radio', () async {
    await RadioScope.instance.useNodeNum(
      oldRadio,
      deviceId: 'ble:old',
      label: 'Old',
    );
    await writeHistory(200 * 1024);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(RadioScope.instance.prefsKey('nodes'), 'old nodes');
    await RadioScope.instance.useNodeNum(
      newRadio,
      deviceId: 'ble:new',
      label: 'New',
    );
    await prefs.setString(RadioScope.instance.prefsKey('nodes'), 'new nodes');

    expect(
      await RadioScope.instance.moveScope(from: oldKey, into: newKey),
      isTrue,
    );

    expect(RadioScope.instance.currentKey, newKey);
    expect(scopedFile(newKey, 'messages.db').lengthSync(), 200 * 1024);
    expect(scopedFile(oldKey, 'messages.db').existsSync(), isFalse);
    expect(prefs.getString(RadioScope.instance.prefsKey('nodes')), 'old nodes');

    final scopes = await RadioScope.instance.list();
    expect(scopes.map((s) => s.key), [newKey]);
    expect(scopes.single.label, 'New');

    // The old radio's device id no longer leads anywhere; reconnecting it
    // starts a fresh dataset rather than reopening the moved one.
    await RadioScope.instance.useDevice(deviceId: 'ble:old');
    expect(RadioScope.instance.currentKey, isNot(newKey));
  });

  test('a new radio already sharing the old one takes the data over', () async {
    await RadioScope.instance.useNodeNum(oldRadio);
    await writeHistory(200 * 1024);
    await RadioScope.instance.useNodeNum(newRadio);
    await RadioScope.instance.shareScope(key: newKey, into: oldKey);
    expect(RadioScope.instance.currentKey, oldKey);
    expect(await RadioScope.instance.currentScopeIsShared(), isTrue);

    expect(
      await RadioScope.instance.moveScope(from: oldKey, into: newKey),
      isTrue,
    );

    expect(RadioScope.instance.currentKey, newKey);
    expect(scopedFile(newKey, 'messages.db').lengthSync(), 200 * 1024);
    expect(await RadioScope.instance.currentScopeIsShared(), isFalse);
    final scopes = await RadioScope.instance.list();
    expect(scopes.single.sharesWith, isNull);
  });

  test('radios that shared the old radio share the new one', () async {
    await RadioScope.instance.useNodeNum(oldRadio);
    await writeHistory(200 * 1024);
    await RadioScope.instance.useNodeNum(third);
    await RadioScope.instance.useNodeNum(newRadio);
    await RadioScope.instance.shareScope(key: thirdKey, into: oldKey);

    expect(
      await RadioScope.instance.moveScope(from: oldKey, into: newKey),
      isTrue,
    );

    final scopes = await RadioScope.instance.list();
    expect(scopes.firstWhere((s) => s.key == thirdKey).sharesWith, newKey);
  });

  test('sets aside what the new radio stored itself', () async {
    await RadioScope.instance.useNodeNum(oldRadio);
    await writeHistory(200 * 1024);
    await RadioScope.instance.useNodeNum(newRadio, label: 'New');
    await writeHistory(100 * 1024);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(RadioScope.instance.prefsKey('nodes'), 'new nodes');

    expect(
      await RadioScope.instance.moveScope(from: oldKey, into: newKey),
      isTrue,
    );

    expect(scopedFile(newKey, 'messages.db').lengthSync(), 200 * 1024);
    final scopes = await RadioScope.instance.list();
    final aside = scopes.singleWhere((s) => s.isSetAside);
    expect(aside.label, 'New');
    expect(aside.nodeNum, isNull);
    expect(scopedFile(aside.key, 'messages.db').lengthSync(), 100 * 1024);
    // Its node list went with it; the old radio had none to bring.
    expect(prefs.getString(RadioScope.instance.prefsKey('nodes')), isNull);

    // The set-aside data is listed only to be kept or deleted.
    expect(await RadioScope.instance.deleteScope(aside.key), isTrue);
    expect((await RadioScope.instance.list()).map((s) => s.key), [newKey]);
  });

  test('refuses to move the data of the radio connected now', () async {
    await RadioScope.instance.useNodeNum(newRadio);
    await RadioScope.instance.useNodeNum(oldRadio);
    await writeHistory(200 * 1024);

    expect(
      await RadioScope.instance.moveScope(from: oldKey, into: newKey),
      isFalse,
    );
    expect(RadioScope.instance.currentKey, oldKey);
  });

  test('refuses a radio that shares a third radio', () async {
    await RadioScope.instance.useNodeNum(oldRadio);
    await writeHistory(200 * 1024);
    await RadioScope.instance.useNodeNum(third);
    await RadioScope.instance.useNodeNum(newRadio);
    await RadioScope.instance.shareScope(key: newKey, into: thirdKey);

    expect(
      await RadioScope.instance.moveScope(from: oldKey, into: newKey),
      isFalse,
    );
  });
}
