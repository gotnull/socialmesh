// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D-Q2: `meshCoreChatTextScaleProvider` notifier pins.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/providers/meshcore_chat_text_scale_provider.dart';
import 'package:socialmesh/services/meshcore/storage/meshcore_chat_text_scale_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('initial state hydrates the default when nothing persisted', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final value = await container.read(meshCoreChatTextScaleProvider.future);
    expect(value, kMeshCoreChatTextScaleDefault);
  });

  test('initial state hydrates from persisted value', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'meshcore_chat_text_scale': 1.25,
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final value = await container.read(meshCoreChatTextScaleProvider.future);
    expect(value, 1.25);
  });

  test('setScale updates state + persists', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(meshCoreChatTextScaleProvider.future);
    await container.read(meshCoreChatTextScaleProvider.notifier).setScale(1.5);
    expect(container.read(meshCoreChatTextScaleProvider).value, 1.5);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('meshcore_chat_text_scale'), 1.5);
  });

  test('setScale clamps below min', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(meshCoreChatTextScaleProvider.future);
    await container.read(meshCoreChatTextScaleProvider.notifier).setScale(0.1);
    expect(
      container.read(meshCoreChatTextScaleProvider).value,
      kMeshCoreChatTextScaleMin,
    );
  });

  test('setScale clamps above max', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(meshCoreChatTextScaleProvider.future);
    await container.read(meshCoreChatTextScaleProvider.notifier).setScale(99.0);
    expect(
      container.read(meshCoreChatTextScaleProvider).value,
      kMeshCoreChatTextScaleMax,
    );
  });

  test('reset returns to default', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(meshCoreChatTextScaleProvider.future);
    await container.read(meshCoreChatTextScaleProvider.notifier).setScale(1.5);
    await container.read(meshCoreChatTextScaleProvider.notifier).reset();
    expect(
      container.read(meshCoreChatTextScaleProvider).value,
      kMeshCoreChatTextScaleDefault,
    );
  });
}
