// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// MeshCanvas participation / onboarding / presence-sharing provider
// graph.
//
// Source of truth: docs/canvas/CANVAS_PARTICIPATION_V0_1.md §4.
//
// Public surface:
//   - meshCanvasParticipationStoreProvider — opens SharedPreferences
//     and wraps it in the typed store.
//   - meshCanvasParticipationProvider — AsyncNotifier holding the
//     three-boolean state. Exposes opinionated transitions
//     (chooseLocalOnly / joinMeshCanvas / markOnboardingSeen /
//     setParticipationEnabled / setPresenceSharingEnabled) so callers
//     can't accidentally violate the mutation invariants.
//   - Three cheap Provider<bool> selectors — let widgets read just
//     the bit they need without re-running on unrelated flips.
//     Selectors return `false` while the underlying notifier is
//     loading (conservative default == "not opted in").
//
// Mutation invariants (CANVAS_PARTICIPATION_V0_1.md §2.2):
//   - Setting participationEnabled = false forces
//     presenceSharingEnabled = false.
//   - Setting presenceSharingEnabled = true while
//     participationEnabled = false is silently dropped (logged at
//     debug); the UI never offers this combo.
//   - onboardingSeen is monotonic: once `true`, no public method on
//     this notifier flips it back to `false`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/logging.dart';
import '../../../services/canvas/canvas_participation_models.dart';
import '../../../services/canvas/canvas_participation_store.dart';

/// FutureProvider that opens `SharedPreferences` and wraps it in the
/// typed [MeshCanvasParticipationStore]. Process-singleton via the
/// SharedPreferences cache; no dispose work needed.
final meshCanvasParticipationStoreProvider =
    FutureProvider<MeshCanvasParticipationStore>((ref) async {
      final prefs = await SharedPreferences.getInstance();
      return MeshCanvasParticipationStore(prefs);
    });

/// AsyncNotifier owning the three-boolean participation state.
///
/// Build path reads the persisted settings on first access. Every
/// mutator method:
///   1. Builds the next state from the current state + the requested
///      change, applying the invariant rules.
///   2. Writes to the store.
///   3. Sets `state = AsyncData(next)`.
///
/// We update `state` AFTER the write so a transient write failure
/// can't leave the UI ahead of disk. If the write throws, the
/// notifier's existing state is preserved and the caller sees the
/// exception (currently unwound at the boundary; UI surfaces don't
/// catch).
class MeshCanvasParticipationNotifier
    extends AsyncNotifier<MeshCanvasParticipationSettings> {
  MeshCanvasParticipationStore? _store;

  @override
  Future<MeshCanvasParticipationSettings> build() async {
    final store = await ref.watch(meshCanvasParticipationStoreProvider.future);
    _store = store;
    return store.readSettings();
  }

  /// Mark first-run onboarding as seen WITHOUT opting in to mesh
  /// participation or presence sharing. Used by the onboarding
  /// sheet's "Explore locally" path.
  Future<void> chooseLocalOnly() async {
    await _apply(
      const MeshCanvasParticipationSettings(
        onboardingSeen: true,
        participationEnabled: false,
        presenceSharingEnabled: false,
      ),
      reason: 'chooseLocalOnly',
    );
  }

  /// Mark first-run onboarding as seen AND opt in to mesh
  /// participation. Presence sharing stays off until the user enables
  /// it explicitly via the settings sheet (per
  /// CANVAS_PARTICIPATION_V0_1.md §5.5).
  Future<void> joinMeshCanvas() async {
    await _apply(
      const MeshCanvasParticipationSettings(
        onboardingSeen: true,
        participationEnabled: true,
        presenceSharingEnabled: false,
      ),
      reason: 'joinMeshCanvas',
    );
  }

  /// Flip onboarding to `true` without touching the other bits.
  /// Idempotent — repeated calls are no-ops once the flag is set.
  /// Used for cases where the user lands on the onboarding sheet via
  /// "Replay onboarding" and dismisses without picking a CTA: we
  /// still record that the sheet has been seen at least once.
  Future<void> markOnboardingSeen() async {
    final current = state.asData?.value;
    if (current == null || current.onboardingSeen) return;
    await _apply(
      current.copyWith(onboardingSeen: true),
      reason: 'markOnboardingSeen',
    );
  }

  /// Set the mesh participation toggle. When [enabled] is `false`,
  /// presence sharing is forced off too (CANVAS_PARTICIPATION_V0_1.md
  /// §2.2: "sharing without participation is meaningless").
  Future<void> setParticipationEnabled(bool enabled) async {
    final current = state.asData?.value;
    if (current == null) return;
    final next = current.copyWith(
      participationEnabled: enabled,
      presenceSharingEnabled: enabled ? current.presenceSharingEnabled : false,
    );
    if (next == current) return;
    await _apply(next, reason: 'setParticipationEnabled=$enabled');
  }

  /// Set the presence sharing toggle. When the current state has
  /// participation off, enabling sharing is silently dropped (logged
  /// at debug) — the UI prevents this combination but defence in
  /// depth rejects programmatic mistakes.
  Future<void> setPresenceSharingEnabled(bool enabled) async {
    final current = state.asData?.value;
    if (current == null) return;
    if (enabled && !current.participationEnabled) {
      AppLogging.meshCanvas(
        'participation: rejecting setPresenceSharingEnabled(true) — '
        'participation is disabled',
      );
      return;
    }
    if (current.presenceSharingEnabled == enabled) return;
    await _apply(
      current.copyWith(presenceSharingEnabled: enabled),
      reason: 'setPresenceSharingEnabled=$enabled',
    );
  }

  Future<void> _apply(
    MeshCanvasParticipationSettings next, {
    required String reason,
  }) async {
    final store = _store;
    if (store == null) return;
    await store.writeSettings(next);
    state = AsyncData(next);
    AppLogging.meshCanvas(
      'participation: $reason → onboarding=${next.onboardingSeen} '
      'participation=${next.participationEnabled} '
      'sharing=${next.presenceSharingEnabled}',
    );
  }
}

final meshCanvasParticipationProvider =
    AsyncNotifierProvider<
      MeshCanvasParticipationNotifier,
      MeshCanvasParticipationSettings
    >(MeshCanvasParticipationNotifier.new);

/// True iff the first-run onboarding sheet has been shown. Returns
/// `false` while the underlying notifier is loading; this is
/// intentional — the overview screen treats "loading" as "not yet
/// seen" and waits for the AsyncData before deciding whether to
/// surface the sheet (avoids a flicker where the screen renders the
/// channel list before onboarding fires).
final meshCanvasOnboardingSeenProvider = Provider<bool>((ref) {
  final asyncSettings = ref.watch(meshCanvasParticipationProvider);
  return asyncSettings.asData?.value.onboardingSeen ?? false;
});

/// True iff the user has opted into mesh participation. Returns
/// `false` while loading — conservative default, matches the
/// CANVAS_PARTICIPATION_V0_1.md §4 selector rule.
final meshCanvasParticipationEnabledProvider = Provider<bool>((ref) {
  final asyncSettings = ref.watch(meshCanvasParticipationProvider);
  return asyncSettings.asData?.value.participationEnabled ?? false;
});

/// True iff the user has opted into broadcasting presence frames.
/// Returns `false` while loading.
final meshCanvasPresenceSharingEnabledProvider = Provider<bool>((ref) {
  final asyncSettings = ref.watch(meshCanvasParticipationProvider);
  return asyncSettings.asData?.value.presenceSharingEnabled ?? false;
});
