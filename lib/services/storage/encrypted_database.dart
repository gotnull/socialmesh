// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_sqlcipher/sqflite.dart' as cipher;

import '../../core/logging.dart';
import 'database_key_service.dart';
import 'database_migration.dart';

/// Whether at-rest encryption is available on the current platform. Only the
/// mobile targets ship the SQLCipher native library; unit tests and desktop run
/// through the plain `sqflite_common_ffi` factory, where databases are opened
/// unencrypted (the test fixtures contain no real user data).
bool get _encryptionSupported =>
    !kIsWeb && (Platform.isAndroid || Platform.isIOS);

/// Drop-in replacement for `sqflite`'s `openDatabase` that transparently
/// encrypts the database at rest with SQLCipher, keyed by [DatabaseKeyService].
///
/// On first open of an existing plaintext database the file is migrated in
/// place to an encrypted file (rows preserved). If that migration fails the
/// plaintext file is left untouched and opened unencrypted for this session,
/// and the migration is retried on the next launch — user data is never lost.
///
/// On non-mobile platforms (tests/desktop) this falls back to a plain
/// unencrypted open so CI needs no SQLCipher build.
Future<sqflite.Database> openEncryptedDatabase(
  String path, {
  required int version,
  sqflite.OnDatabaseConfigureFn? onConfigure,
  sqflite.OnDatabaseCreateFn? onCreate,
  sqflite.OnDatabaseVersionChangeFn? onUpgrade,
  sqflite.OnDatabaseVersionChangeFn? onDowngrade,
  sqflite.OnDatabaseOpenFn? onOpen,
  DatabaseKeyService? keyService,
}) async {
  if (!_encryptionSupported) {
    return sqflite.openDatabase(
      path,
      version: version,
      onConfigure: onConfigure,
      onCreate: onCreate,
      onUpgrade: onUpgrade,
      onDowngrade: onDowngrade,
      onOpen: onOpen,
    );
  }

  // Throws DatabaseKeyUnavailableException if the keystore is locked before the
  // first post-boot unlock. The caller defers and retries — an encrypted file
  // cannot be opened without its key.
  final key = await (keyService ?? DatabaseKeyService.instance)
      .getOrCreateKey();

  var openEncrypted = true;
  try {
    await recoverInterruptedMigration(path);
    if (await isPlaintextSqlite(path)) {
      await migratePlaintextToEncrypted(
        path: path,
        key: key,
        debugName: _basename(path),
      );
    }
  } catch (e) {
    // Keep the plaintext file intact, open it unencrypted this session, and
    // retry the migration next launch.
    AppLogging.storage(
      'openEncryptedDatabase: migration failed for ${_basename(path)}, '
      'opening plaintext fallback ($e)',
    );
    openEncrypted = false;
  }

  return cipher.openDatabase(
    path,
    password: openEncrypted ? key : null,
    version: version,
    onConfigure: onConfigure,
    onCreate: onCreate,
    onUpgrade: onUpgrade,
    onDowngrade: onDowngrade,
    onOpen: onOpen,
  );
}

String _basename(String path) => path.split('/').last;
