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

/// Identity scope of the radio the session is bound to, or null before any
/// radio has been bound this launch.
///
/// Distinct from [radioScopeProvider]: when two radios share one dataset,
/// switching between them changes this without changing the scope.
class RadioScopeIdentityNotifier extends Notifier<String?> {
  StreamSubscription<String>? _subscription;

  @override
  String? build() {
    _subscription = RadioScope.instance.identityChanges.listen((key) {
      if (!ref.mounted) return;
      state = key;
    });
    ref.onDispose(() {
      _subscription?.cancel();
      _subscription = null;
    });
    return RadioScope.instance.connectedKey;
  }
}

final radioScopeIdentityProvider =
    NotifierProvider<RadioScopeIdentityNotifier, String?>(
      RadioScopeIdentityNotifier.new,
    );

/// Stored radio profiles, largest first. Consumed by the Radio Data screen;
/// invalidate it after deleting a profile to refresh the list. Refetches on
/// a scope change and on a connected-radio change, since the list marks
/// both and a switch between radios sharing one dataset only causes the
/// latter.
final radioScopeListProvider = FutureProvider<List<RadioScopeInfo>>((
  ref,
) async {
  ref.watch(radioScopeProvider);
  ref.watch(radioScopeIdentityProvider);
  return RadioScope.instance.list();
});

/// Whether the dataset in effect is shared with another radio, which decides
/// what Reset Node Database clears. Auto-disposed so each visit to Device
/// Management reads it afresh after a sharing change on Radio Profiles.
final currentRadioScopeSharedProvider = FutureProvider.autoDispose<bool>((ref) {
  ref.watch(radioScopeProvider);
  ref.watch(radioScopeIdentityProvider);
  return RadioScope.instance.currentScopeIsShared();
});

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
