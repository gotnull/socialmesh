// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/generate_client_env.dart';

void main() {
  test('client env generation copies only explicitly allowlisted keys', () {
    final generated = generateClientEnv(
      sourceContents: 'PUBLIC_FLAG=true\nSERVER_SECRET=do-not-copy\n',
      allowlist: {'PUBLIC_FLAG'},
    );

    expect(generated, contains('PUBLIC_FLAG=true'));
    expect(generated, isNot(contains('SERVER_SECRET')));
    expect(generated, isNot(contains('do-not-copy')));
  });

  test('client env allowlist rejects prohibited server configuration', () {
    expect(
      () => parseClientEnvAllowlist('APP_BASE_URL\nADMIN_UIDS\n'),
      throwsFormatException,
    );
  });

  test('Flutter bundles the generated client env, never the raw env', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('    - .env.client\n'));
    expect(pubspec, isNot(contains('    - .env\n')));
  });

  test('allowlist covers every literal production dotenv read', () {
    final allowlist = parseClientEnvAllowlist(
      File(defaultClientEnvAllowlist).readAsStringSync(),
    );
    final discovered = discoverProductionClientEnvKeys(Directory('lib'));
    expect(discovered.difference(allowlist), isEmpty);
  });

  test('generated client env contains no prohibited key names', () {
    final generatedFile = File(defaultClientEnvOutput);
    expect(
      generatedFile.existsSync(),
      isTrue,
      reason: 'Run dart run tool/generate_client_env.dart before tests.',
    );
    final generatedKeys = generatedFile
        .readAsLinesSync()
        .where((line) => line.isNotEmpty && !line.startsWith('#'))
        .map((line) => line.split('=').first)
        .toSet();
    for (final key in prohibitedClientEnvKeys) {
      expect(generatedKeys, isNot(contains(key)), reason: key);
    }
  });
}
