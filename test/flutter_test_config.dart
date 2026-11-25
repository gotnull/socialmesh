// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/meshcore/storage/meshcore_message_store.dart';
import 'package:socialmesh/services/storage/storage_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Runs around every test file. Each test gets its own empty in-memory
// MeshCore message store and node store, as each test already gets its own
// mocked SharedPreferences. Tests of the databases themselves switch to an
// ffi database (MeshCoreMessageStore.debugUseDatabaseAt,
// NodeStorageService.debugUseDatabase).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  sqfliteFfiInit();
  setUp(MeshCoreMessageStore.debugUseInMemory);
  setUp(NodeStorageService.debugUseInMemory);
  await testMain();
}
