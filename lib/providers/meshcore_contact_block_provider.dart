// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D-Q8: Riverpod 3.x state layer for the per-contact block list.
// Reads the SharedPreferences-backed store on build and exposes a
// `AsyncNotifier<Set<String>>` whose state is the lowercase-hex
// set of blocked pubkeys.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/meshcore/storage/meshcore_contact_block_store.dart';

class MeshCoreContactBlockNotifier extends AsyncNotifier<Set<String>> {
  MeshCoreContactBlockStore? _store;

  @override
  Future<Set<String>> build() async {
    final prefs = await SharedPreferences.getInstance();
    _store = MeshCoreContactBlockStore(prefs);
    return _store!.read();
  }

  Future<void> block(String pubKeyHex) async {
    final current = state.value ?? const {};
    final next = MeshCoreContactBlockStore.blockIn(current, pubKeyHex);
    if (identical(next, current)) return;
    state = AsyncData(next);
    await _store?.write(next);
  }

  Future<void> unblock(String pubKeyHex) async {
    final current = state.value ?? const {};
    final next = MeshCoreContactBlockStore.unblockIn(current, pubKeyHex);
    if (identical(next, current)) return;
    state = AsyncData(next);
    await _store?.write(next);
  }

  /// Synchronous block check. Returns false until the AsyncNotifier
  /// has hydrated from SharedPreferences (effectively "not blocked"
  /// during the first frame after app launch, which is fine — the
  /// block-list is rarely empty for users who use the feature, and
  /// missing a single notification on cold-start is acceptable).
  bool isBlocked(String pubKeyHex) {
    final current = state.value;
    if (current == null) return false;
    return current.contains(pubKeyHex.toLowerCase());
  }
}

final meshCoreContactBlockProvider =
    AsyncNotifierProvider<MeshCoreContactBlockNotifier, Set<String>>(
      MeshCoreContactBlockNotifier.new,
    );
