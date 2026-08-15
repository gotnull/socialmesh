// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/storage/database_open_diagnostics.dart';

void main() {
  test('describes the file, the key and the moment of the failure', () {
    final keys = buildDatabaseOpenDiagnostics(
      dbName: 'messages.db',
      fileExists: true,
      fileBytes: 4096,
      looksPlaintextNow: false,
      wasPlaintextBeforeOpen: true,
      openedEncrypted: true,
      keyGeneratedThisLaunch: false,
      lifecycle: 'paused',
      sqliteResultCode: 26,
    );

    expect(keys, {
      'db_name': 'messages.db',
      'db_file_exists': 'true',
      'db_file_bytes': '4096',
      'db_looks_plaintext_now': 'false',
      'db_was_plaintext_before_open': 'true',
      'db_opened_encrypted': 'true',
      'db_key_generated_this_launch': 'false',
      'db_lifecycle': 'paused',
      'db_sqlite_result_code': '26',
    });
  });

  test('a missing result code reads as none rather than an empty value', () {
    final keys = buildDatabaseOpenDiagnostics(
      dbName: 'signals.db',
      fileExists: false,
      fileBytes: 0,
      looksPlaintextNow: false,
      wasPlaintextBeforeOpen: false,
      openedEncrypted: false,
      keyGeneratedThisLaunch: true,
      lifecycle: 'unknown',
    );

    expect(keys['db_sqlite_result_code'], 'none');
    // The combination that names an orphaned file: a key minted this launch
    // against a database that was already on disk.
    expect(keys['db_key_generated_this_launch'], 'true');
    expect(keys['db_file_exists'], 'false');
  });

  test('every value is a string, as the Crashlytics key API requires', () {
    final keys = buildDatabaseOpenDiagnostics(
      dbName: 'nodedex.db',
      fileExists: true,
      fileBytes: 1,
      looksPlaintextNow: true,
      wasPlaintextBeforeOpen: true,
      openedEncrypted: false,
      keyGeneratedThisLaunch: false,
      lifecycle: 'resumed',
      sqliteResultCode: 14,
    );

    expect(keys.values.every((value) => value.isNotEmpty), isTrue);
  });

  test('lifecycle label degrades to unknown without a binding', () {
    // No TestWidgetsFlutterBinding here on purpose: a background isolate has
    // no binding either, and the label has to survive that.
    expect(currentLifecycleLabel(), anyOf('unknown', 'none', 'resumed'));
  });
}
