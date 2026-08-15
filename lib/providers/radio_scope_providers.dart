// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Provider surface for per-radio storage scoping.
//
// [radioScopeProvider] holds the scope key currently in effect. Every storage
// provider watches it, so a scope change tears the open stores down and lets
// them reopen against the new radio's files - which is also what makes the
// notifiers hydrating off those stores reload the new radio's data.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging.dart';
import '../core/radio_scope.dart';

/// The radio scope key currently in effect.
///
/// Watch this from any provider that opens scoped storage. Do not mutate it
/// directly: the scope follows the connected radio, and [RadioScope] is what
/// closes the open stores before the files move.
class RadioScopeNotifier extends Notifier<String> {
  StreamSubscription<String>? _subscription;

  @override
  String build() {
    _subscription = RadioScope.instance.changes.listen((key) {
      if (!ref.mounted) return;
      AppLogging.storage('RADIO SCOPE: providers rebuilding for scope $key');
      state = key;
    });
    ref.onDispose(() {
      _subscription?.cancel();
      _subscription = null;
    });
    return RadioScope.instance.currentKey;
  }
}

final radioScopeProvider = NotifierProvider<RadioScopeNotifier, String>(
  RadioScopeNotifier.new,
);

/// Registers [store] with the scope so it is closed before a scope change,
/// and unregisters it when the owning provider disposes.
///
/// Every provider that opens a radio-scoped store must call this. A store
/// that is not registered keeps its file handle open across the switch and
/// goes on writing the previous radio's data.
void bindStoreToRadioScope(
  Ref ref,
  Object store,
  Future<void> Function() close,
) {
  RadioScope.instance.registerCloser(store, close);
  ref.onDispose(() {
    RadioScope.instance.unregisterCloser(store);
    unawaited(close());
  });
}
