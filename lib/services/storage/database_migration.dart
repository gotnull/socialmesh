// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:convert';
import 'dart:io';

import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../core/logging.dart';

/// The 16-byte magic header that prefixes every unencrypted SQLite file: the
/// ASCII text "SQLite format 3" followed by a single NUL byte. A
/// SQLCipher-encrypted file has an encrypted header, so the absence of this
/// magic means the file is already encrypted (or does not exist / is empty).
final List<int> _sqliteMagic = [...utf8.encode('SQLite format 3'), 0];

/// Returns true when [path] is an existing, unencrypted SQLite database - i.e.
/// it still needs to be migrated to an encrypted file.
Future<bool> isPlaintextSqlite(String path) async {
  final file = File(path);
  if (!await file.exists()) return false;
  final raf = await file.open();
  try {
    final header = await raf.read(_sqliteMagic.length);
    if (header.length < _sqliteMagic.length) return false;
    for (var i = 0; i < _sqliteMagic.length; i++) {
      if (header[i] != _sqliteMagic[i]) return false;
    }
    return true;
  } finally {
    await raf.close();
  }
}

/// Recovers from a migration whose final file swap was interrupted by a crash
/// or kill. Must be called BEFORE [isPlaintextSqlite]/[migratePlaintextToEncrypted]
/// so a half-completed swap is resolved without losing data:
///
/// - temp present + original missing → the swap was interrupted after the
///   plaintext file was deleted; the temp holds the complete encrypted copy, so
///   promote it into place.
/// - temp present + original present → the temp is an incomplete export from a
///   migration that never swapped; the original is intact, so discard the temp.
Future<void> recoverInterruptedMigration(String path) async {
  final tmpPath = '$path.enc.tmp';
  if (!await File(tmpPath).exists()) return;

  if (!await File(path).exists()) {
    await _deleteIfExists('$path-wal');
    await _deleteIfExists('$path-shm');
    await File(tmpPath).rename(path);
    AppLogging.storage(
      'DB migration: recovered interrupted swap for ${_basename(path)}',
    );
  } else {
    await _deleteIfExists(tmpPath);
    await _deleteIfExists('$tmpPath-wal');
    await _deleteIfExists('$tmpPath-shm');
  }
}

String _basename(String path) => path.split('/').last;

/// Escapes a value for inline use inside a single-quoted SQL string literal by
/// doubling embedded single quotes. Used only for the ATTACH ... KEY statement,
/// where the SQLCipher passphrase and the app-controlled temp path are inlined.
String _sqlQuote(String value) => "'${value.replaceAll("'", "''")}'";

/// Migrates the plaintext SQLite database at [path] to a SQLCipher-encrypted
/// database in place, keyed with [key], preserving all rows.
///
/// Uses SQLCipher's canonical `sqlcipher_export()` path: open the plaintext
/// source (no passphrase → SQLCipher behaves as plain SQLite), ATTACH a new
/// keyed database, export, then atomically swap the encrypted file over the
/// original.
///
/// Throws on failure WITHOUT touching the original plaintext file, so the
/// caller can fall back to an unencrypted open this session and retry the
/// migration on the next launch - user data is never lost.
Future<void> migratePlaintextToEncrypted({
  required String path,
  required String key,
  required String debugName,
}) async {
  final tmpPath = '$path.enc.tmp';

  // Remove any stale temp file from a previously interrupted migration.
  await _deleteIfExists(tmpPath);
  await _deleteIfExists('$tmpPath-wal');
  await _deleteIfExists('$tmpPath-shm');

  // Open the source WITHOUT a passphrase. With no PRAGMA key issued, SQLCipher
  // reads the existing plaintext database normally and checkpoints any WAL.
  final source = await openDatabase(path);
  try {
    // sqlcipher_export() copies schema + data but NOT the schema-version header.
    // Carry user_version across explicitly, otherwise the encrypted database
    // opens at version 0 and the app re-runs onCreate over already-migrated
    // tables ("table ... already exists").
    final userVersion =
        Sqflite.firstIntValue(await source.rawQuery('PRAGMA user_version')) ??
        0;

    await source.execute(
      'ATTACH DATABASE ${_sqlQuote(tmpPath)} AS encrypted KEY ${_sqlQuote(key)}',
    );
    await source.rawQuery("SELECT sqlcipher_export('encrypted')");
    await source.execute('PRAGMA encrypted.user_version = $userVersion');
    await source.execute('DETACH DATABASE encrypted');
  } finally {
    await source.close();
  }

  // Swap: drop the plaintext original (and its WAL sidecars), promote the
  // encrypted temp file into its place.
  await _deleteIfExists('$path-wal');
  await _deleteIfExists('$path-shm');
  await File(path).delete();
  await File(tmpPath).rename(path);

  AppLogging.storage('DB migration: encrypted $debugName in place');
}

Future<void> _deleteIfExists(String path) async {
  final file = File(path);
  if (await file.exists()) {
    await file.delete();
  }
}
