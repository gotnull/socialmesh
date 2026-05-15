// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D-Q2: Riverpod notifier exposing the per-app MeshCore chat
// text-scale preference. Watched by the chat screen's
// `MediaQuery(textScaler:)` override so every text widget in the
// chat tree scales uniformly. Mutations write-through to
// SharedPreferences via [MeshCoreChatTextScaleStore].
//
// Discrete UI steps live in the settings tile (D-Q2 ships
// `[0.8, 0.9, 1.0, 1.1, 1.25, 1.5, 1.8]`); the notifier itself
// accepts any value within the store's bounds.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/meshcore/storage/meshcore_chat_text_scale_store.dart';

class MeshCoreChatTextScaleNotifier extends AsyncNotifier<double> {
  MeshCoreChatTextScaleStore? _store;

  @override
  Future<double> build() async {
    final prefs = await SharedPreferences.getInstance();
    _store = MeshCoreChatTextScaleStore(prefs);
    return _store!.read();
  }

  // Update the scale and persist the clamped value. The notifier
  // mirrors the new value into its state before the storage write
  // resolves so the UI re-renders immediately; the in-flight write
  // is a side effect, not a value-blocking operation.
  Future<void> setScale(double next) async {
    final store = _store;
    if (store == null) return;
    final clamped = MeshCoreChatTextScaleStore.clamp(next);
    state = AsyncData(clamped);
    await store.write(clamped);
  }

  // Convenience for "factory default". Surfaces the same write as
  // [setScale] so listeners receive a single notification.
  Future<void> reset() => setScale(kMeshCoreChatTextScaleDefault);
}

final meshCoreChatTextScaleProvider =
    AsyncNotifierProvider<MeshCoreChatTextScaleNotifier, double>(
      MeshCoreChatTextScaleNotifier.new,
    );
