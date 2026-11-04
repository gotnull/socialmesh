// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/radio_scope.dart';

// A radio reports its identity several times while a connect settles, and
// each report binds the scope. The binds must run one after another: run
// together, they promote the same provisional directory more than once and
// a late one can treat the promoted directory as its own source.

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('radio_scope_concurrency_');
    SharedPreferences.setMockInitialValues({});
    RadioScope.instance.debugSetRoot(root);
    await RadioScope.instance.init();
  });

  tearDown(() async {
    RadioScope.instance.debugSetRoot(null);
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('repeated identity reports promote a new radio once and keep its '
      'data', () async {
    await RadioScope.instance.useDevice(deviceId: 'tcp:10.0.2.2:4407');
    expect(isProvisionalRadioScopeKey(RadioScope.instance.currentKey), isTrue);
    // A first connect writes a little before the identity arrives: well
    // under the size below which an existing directory counts as empty.
    final early = await RadioScope.instance.databasePath('messages.db');
    await File(early).writeAsString('first connect');

    final results = await Future.wait([
      for (var i = 0; i < 3; i++)
        RadioScope.instance.useNodeNum(
          0xd0d0f00d,
          deviceId: 'tcp:10.0.2.2:4407',
          label: '10.0.2.2:4407',
        ),
    ]);

    expect(results.where((changed) => changed), hasLength(1));
    expect(RadioScope.instance.currentKey, 'node-d0d0f00d');
    final promoted = File(
      p.join(root.path, 'radios', 'node-d0d0f00d', 'messages.db'),
    );
    expect(promoted.existsSync(), isTrue);
    expect(promoted.readAsStringSync(), 'first connect');
  });
}
