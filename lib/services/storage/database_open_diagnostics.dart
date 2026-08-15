// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Diagnostics attached to a failed database open.
//
// A SQLCipher open that fails reaches Crashlytics as `open_failed <path>` with
// no result code and no clue whether the file was there, what it looked like,
// or which key was handed to it. Those three answers separate the candidate
// causes - a key that does not match the file, a file the platform will not
// hand over yet, and a half-finished plaintext migration - and none of them
// can be told apart after the fact.
//
// Policy: this module only sets custom keys and logs. It MUST NOT call
// recordError. The failure already propagates to AppErrorHandler, which
// reports it; reporting here as well would split one failure across two
// Crashlytics issues.

import 'dart:io' show File;

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding;

import '../../core/logging.dart';
import 'database_migration.dart';

/// Builds the Crashlytics custom keys describing a failed open.
///
/// Pure so the shape can be asserted in tests without Firebase or a file
/// system. Values are strings because custom keys are read as filters in the
/// dashboard, where a stringly-typed value groups predictably.
Map<String, String> buildDatabaseOpenDiagnostics({
  required String dbName,
  required bool fileExists,
  required int fileBytes,
  required bool looksPlaintextNow,
  required bool wasPlaintextBeforeOpen,
  required bool openedEncrypted,
  required bool keyGeneratedThisLaunch,
  required String lifecycle,
  int? sqliteResultCode,
}) => {
  'db_name': dbName,
  'db_file_exists': '$fileExists',
  'db_file_bytes': '$fileBytes',
  'db_looks_plaintext_now': '$looksPlaintextNow',
  'db_was_plaintext_before_open': '$wasPlaintextBeforeOpen',
  'db_opened_encrypted': '$openedEncrypted',
  'db_key_generated_this_launch': '$keyGeneratedThisLaunch',
  'db_lifecycle': lifecycle,
  'db_sqlite_result_code': sqliteResultCode?.toString() ?? 'none',
};

/// Reads the app lifecycle state, or `unknown` when there is no binding —
/// a background isolate has none, and that is itself worth knowing.
String currentLifecycleLabel() {
  try {
    return WidgetsBinding.instance.lifecycleState?.name ?? 'none';
  } catch (_) {
    return 'unknown';
  }
}

/// Gathers what the file looks like at the moment the open failed and attaches
/// it to the session as Crashlytics custom keys.
Future<void> recordDatabaseOpenFailure({
  required String path,
  required bool openedEncrypted,
  required bool wasPlaintextBeforeOpen,
  required bool keyGeneratedThisLaunch,
  int? sqliteResultCode,
}) async {
  final dbName = path.split('/').last;

  var fileExists = false;
  var fileBytes = 0;
  var looksPlaintextNow = false;
  try {
    final file = File(path);
    fileExists = await file.exists();
    if (fileExists) {
      fileBytes = await file.length();
      looksPlaintextNow = await isPlaintextSqlite(path);
    }
  } catch (_) {
    // The stat itself can fail on a file the platform is withholding, which
    // is a finding rather than an error: the keys below still say what was
    // reachable, and fileExists stays false.
  }

  final diagnostics = buildDatabaseOpenDiagnostics(
    dbName: dbName,
    fileExists: fileExists,
    fileBytes: fileBytes,
    looksPlaintextNow: looksPlaintextNow,
    wasPlaintextBeforeOpen: wasPlaintextBeforeOpen,
    openedEncrypted: openedEncrypted,
    keyGeneratedThisLaunch: keyGeneratedThisLaunch,
    lifecycle: currentLifecycleLabel(),
    sqliteResultCode: sqliteResultCode,
  );

  AppLogging.storage('Database open failed: $diagnostics');

  try {
    for (final entry in diagnostics.entries) {
      FirebaseCrashlytics.instance.setCustomKey(entry.key, entry.value);
    }
  } catch (_) {
    // Crashlytics not initialised (tests, early boot). The log line above is
    // the whole record in that case.
  }
}
