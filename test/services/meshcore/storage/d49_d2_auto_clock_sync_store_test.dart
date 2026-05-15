// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D49-D2: `MeshCoreAdminAutoClockSyncStore` pins.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/services/meshcore/storage/meshcore_admin_auto_clock_sync_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('default value is false for any pubKey', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = MeshCoreAdminAutoClockSyncStore(prefs);
    expect(store.isEnabled('aabbcc'), isFalse);
    expect(store.isEnabled('zzzzzz'), isFalse);
  });

  test('setEnabled persists per pubKey', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = MeshCoreAdminAutoClockSyncStore(prefs);
    await store.setEnabled('aabbcc', true);
    expect(store.isEnabled('aabbcc'), isTrue);
    expect(store.isEnabled('zzzzzz'), isFalse);
  });

  test('toggle off after on returns false', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = MeshCoreAdminAutoClockSyncStore(prefs);
    await store.setEnabled('aabbcc', true);
    await store.setEnabled('aabbcc', false);
    expect(store.isEnabled('aabbcc'), isFalse);
  });

  test('values for different pubKeys are independent', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = MeshCoreAdminAutoClockSyncStore(prefs);
    await store.setEnabled('aaaa', true);
    await store.setEnabled('bbbb', false);
    expect(store.isEnabled('aaaa'), isTrue);
    expect(store.isEnabled('bbbb'), isFalse);
  });
}
