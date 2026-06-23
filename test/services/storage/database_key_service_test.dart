// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/storage/database_key_service.dart';

/// In-memory [FlutterSecureStorage] double. [throwOnRead]/[throwOnWrite]
/// simulate a locked keystore (iOS error -25308).
class _FakeSecureStorage extends FlutterSecureStorage {
  final Map<String, String> store = {};
  int readCount = 0;
  int writeCount = 0;
  bool throwOnRead = false;
  bool throwOnWrite = false;

  _FakeSecureStorage() : super();

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    readCount++;
    if (throwOnRead) {
      throw PlatformException(code: '-25308', message: 'keystore locked');
    }
    return store[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    writeCount++;
    if (throwOnWrite) {
      throw PlatformException(code: '-25308', message: 'keystore locked');
    }
    if (value == null) {
      store.remove(key);
    } else {
      store[key] = value;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generates a 256-bit key on first use and persists it', () async {
    final storage = _FakeSecureStorage();
    final service = DatabaseKeyService(storage: storage);

    final key = await service.getOrCreateKey();

    expect(storage.store.containsKey(DatabaseKeyService.storageKey), isTrue);
    expect(base64Decode(key).length, 32);
  });

  test('returns the same key across calls and generates only once', () async {
    final storage = _FakeSecureStorage();
    final service = DatabaseKeyService(storage: storage);

    final first = await service.getOrCreateKey();
    final second = await service.getOrCreateKey();

    expect(first, second);
    // Memoised: at most one write (the initial generation).
    expect(storage.writeCount, 1);
  });

  test('reuses an existing stored key without regenerating', () async {
    final storage = _FakeSecureStorage();
    final existing = base64Encode(List<int>.filled(32, 42));
    storage.store[DatabaseKeyService.storageKey] = existing;

    final key = await DatabaseKeyService(storage: storage).getOrCreateKey();

    expect(key, existing);
    expect(storage.writeCount, 0);
  });

  test('a locked keystore throws and never clobbers an existing key', () async {
    final storage = _FakeSecureStorage();
    final existing = base64Encode(List<int>.filled(32, 7));
    storage.store[DatabaseKeyService.storageKey] = existing;
    storage.throwOnRead = true;

    final service = DatabaseKeyService(storage: storage);

    await expectLater(
      service.getOrCreateKey(),
      throwsA(isA<DatabaseKeyUnavailableException>()),
    );
    // The real key must survive — no write happened.
    expect(storage.writeCount, 0);
    expect(storage.store[DatabaseKeyService.storageKey], existing);

    // After the lock clears, a retry succeeds with the original key.
    storage.throwOnRead = false;
    expect(await service.getOrCreateKey(), existing);
  });
}
