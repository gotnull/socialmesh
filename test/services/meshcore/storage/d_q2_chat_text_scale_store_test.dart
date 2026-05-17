// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D-Q2: `MeshCoreChatTextScaleStore` pins.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/services/meshcore/storage/meshcore_chat_text_scale_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('default read is 1.0 when no value persisted', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = MeshCoreChatTextScaleStore(prefs);
    expect(store.read(), kMeshCoreChatTextScaleDefault);
    expect(kMeshCoreChatTextScaleDefault, 1.0);
  });

  test('write + read round-trips a mid-range value', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = MeshCoreChatTextScaleStore(prefs);
    await store.write(1.25);
    expect(store.read(), 1.25);
  });

  test('write clamps below 0.8', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = MeshCoreChatTextScaleStore(prefs);
    await store.write(0.5);
    expect(store.read(), kMeshCoreChatTextScaleMin);
    expect(kMeshCoreChatTextScaleMin, 0.8);
  });

  test('write clamps above the canonical max (1.5)', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = MeshCoreChatTextScaleStore(prefs);
    await store.write(3.5);
    expect(store.read(), kMeshCoreChatTextScaleMax);
    expect(kMeshCoreChatTextScaleMax, 1.5);
  });

  test('clamp helper is pure', () {
    expect(MeshCoreChatTextScaleStore.clamp(0.0), 0.8);
    expect(MeshCoreChatTextScaleStore.clamp(1.0), 1.0);
    expect(MeshCoreChatTextScaleStore.clamp(1.5), 1.5);
    expect(MeshCoreChatTextScaleStore.clamp(99.0), 1.5);
  });

  test(
    'read clamps an out-of-range persisted value (forward-compat)',
    () async {
      // A future schema bump might widen the range; if a user downgrades
      // we want a sane value, not a 4x giant font.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'meshcore_chat_text_scale': 4.0,
      });
      final prefs = await SharedPreferences.getInstance();
      final store = MeshCoreChatTextScaleStore(prefs);
      expect(store.read(), kMeshCoreChatTextScaleMax);
    },
  );
}
