// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Shared test helpers for the overlay link engine test suite.
///
/// Provides:
/// - `initFfi()`: one-time sqflite_common_ffi bootstrap (idempotent).
/// - `FakeClock`: injectable monotonic clock so tests can drive stale
///   and expiry transitions without relying on wall time.
/// - `SequenceLinkIdGen`: deterministic link-id generator.
/// - `openInMemoryStore()`: factory for a ready-to-use in-memory store.
///
/// This file is underscore-prefixed so it isn't picked up as a test
/// entrypoint itself; it only exports helpers.
library;

import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:socialmesh/services/protocol/overlay/overlay_endpoint_store.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_link_store.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_resource_store.dart';

bool _ffiInitialised = false;

/// Initialise sqflite_common_ffi exactly once. Safe to call from every
/// test's `setUpAll`.
void initFfi() {
  if (_ffiInitialised) return;
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  _ffiInitialised = true;
}

/// Open a brand-new isolated [OverlayLinkStore] backed by a unique
/// tempfile. Registers `addTearDown` cleanup so the file is deleted
/// even when the test fails before reaching `await store.close()`.
///
/// We use tempfiles rather than `inMemoryDatabasePath` because
/// sqflite_common_ffi shares `:memory:` state between opens under
/// some configurations, which breaks test isolation.
Future<OverlayLinkStore> openInMemoryStore() async {
  initFfi();
  final dir = Directory.systemTemp.createTempSync('overlay_link_test_');
  final path = p.join(dir.path, 'links.db');
  final store = OverlayLinkStore(testDbPath: path);
  await store.init();
  addTearDown(() async {
    try {
      await store.close();
    } catch (_) {}
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  });
  return store;
}

/// Open a brand-new isolated [OverlayResourceStore] backed by a unique
/// tempfile.
Future<OverlayResourceStore> openInMemoryResourceStore() async {
  initFfi();
  final dir = Directory.systemTemp.createTempSync('overlay_resource_test_');
  final path = p.join(dir.path, 'overlay_transfers.db');
  final store = OverlayResourceStore(testDbPath: path);
  await store.init();
  addTearDown(() async {
    try {
      await store.close();
    } catch (_) {}
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  });
  return store;
}

/// Open a brand-new isolated [OverlayEndpointStore] backed by a
/// unique tempfile. Mirror of [openInMemoryStore].
Future<OverlayEndpointStore> openInMemoryEndpointStore() async {
  initFfi();
  final dir = Directory.systemTemp.createTempSync('overlay_endpoint_test_');
  final path = p.join(dir.path, 'endpoints.db');
  final store = OverlayEndpointStore(testDbPath: path);
  await store.init();
  addTearDown(() async {
    try {
      await store.close();
    } catch (_) {}
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  });
  return store;
}

/// Deterministic monotonic clock used by the engine in tests.
///
/// `advanceMs` moves the clock forward by the requested delta; each
/// call to [now] returns the current value.
class FakeClock {
  int _nowMs;

  FakeClock({int initialMs = 1_700_000_000_000}) : _nowMs = initialMs;

  /// The current fake wall-clock ms.
  int now() => _nowMs;

  /// Advance by [deltaMs]. No effect when [deltaMs] is zero or
  /// negative.
  void advanceMs(int deltaMs) {
    if (deltaMs > 0) _nowMs += deltaMs;
  }

  /// Set an absolute value (useful for tests that need a specific
  /// epoch boundary).
  void setMs(int value) => _nowMs = value;
}

/// Minimal in-memory fake for [FlutterSecureStorage]. Implements only
/// the read/write/delete surface the overlay identity code uses.
/// Signatures intentionally mirror the 10.x API (`AppleOptions` for
/// both `iOptions` and `mOptions`).
class FakeSecureStorage implements FlutterSecureStorage {
  final Map<String, String> _map = {};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _map[key];

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
    if (value == null) {
      _map.remove(key);
    } else {
      _map[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _map.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Deterministic link-id generator. Each call returns the next value
/// in [seeds]; throws if the sequence is exhausted.
class SequenceLinkIdGen {
  final List<int> _seeds;
  int _cursor = 0;

  SequenceLinkIdGen(List<int> seeds) : _seeds = List<int>.from(seeds);

  /// Pull the next id.
  int next() {
    if (_cursor >= _seeds.length) {
      throw StateError('SequenceLinkIdGen exhausted');
    }
    return _seeds[_cursor++];
  }
}
