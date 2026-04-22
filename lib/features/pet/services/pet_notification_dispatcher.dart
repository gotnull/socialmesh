// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Pet notifications — dispatcher + durable per-owner dedupe ledger.
//
// v1 categories (actionable care + major milestones only):
//   - stage transitions (hatch, adolescence, branch resolution, maturation,
//     dormant). One notification per transition timestamp.
//   - sickness onset. One per onset; next sickness only notifies after a
//     purge resets the flag.
//   - attention call start. One per call (keyed by startedAt); replaced
//     by the next call, not duplicated.
//
// v1 explicit exclusions:
//   - stat drops, mood shifts, hygiene spawns, action outcomes, sleep
//     edges that don't require action, remote peer updates.
//
// Dedupe rules are durable (SharedPreferences). A provider rebuild, app
// resume, cold restart, or long-gap catch-up must not re-emit a
// notification that was already delivered.
//
// Catch-up staleness: when `advanceTo` crosses many care ticks we can
// end up with `recentEvents` containing a burst of callStarted /
// sicknessOnset / callMissed entries. The dispatcher gates each
// candidate behind a "still relevant now?" check — only the current,
// live state is notified. For stage transitions we notify only the
// latest (post-burst) transition.

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/logging.dart';
import '../../../services/notifications/notification_service.dart';
import '../models/care_event.dart';
import '../models/pet_enums.dart';
import '../models/pet_state.dart';
import 'pet_animation_tracker.dart';

/// Durable per-owner ledger of what the dispatcher has already notified.
/// Keys are scoped by ownerNodeNum so a device swap starts fresh.
class PetNotificationLedger {
  final SharedPreferences _prefs;

  PetNotificationLedger(this._prefs);

  static String _stageKey(int owner) =>
      'pet.notified.stageAt.$owner'; // lint-allow: hardcoded-string
  static String _sicknessKey(int owner) =>
      'pet.notified.sicknessAt.$owner'; // lint-allow: hardcoded-string
  static String _callKey(int owner) =>
      'pet.notified.callAt.$owner'; // lint-allow: hardcoded-string

  DateTime? _readMs(String key) {
    final ms = _prefs.getInt(key);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
  }

  Future<void> _writeMs(String key, DateTime at) async {
    await _prefs.setInt(key, at.toUtc().millisecondsSinceEpoch);
  }

  Future<void> _clear(String key) async {
    await _prefs.remove(key);
  }

  // ---- Stage transitions ----------------------------------------------

  DateTime? stageNotifiedAt(int owner) => _readMs(_stageKey(owner));

  Future<void> markStageNotifiedAt(int owner, DateTime at) =>
      _writeMs(_stageKey(owner), at);

  // ---- Sickness onset --------------------------------------------------

  DateTime? sicknessNotifiedAt(int owner) => _readMs(_sicknessKey(owner));

  Future<void> markSicknessNotifiedAt(int owner, DateTime at) =>
      _writeMs(_sicknessKey(owner), at);

  Future<void> clearSicknessNotification(int owner) =>
      _clear(_sicknessKey(owner));

  // ---- Attention call --------------------------------------------------

  DateTime? callNotifiedAt(int owner) => _readMs(_callKey(owner));

  Future<void> markCallNotifiedAt(int owner, DateTime at) =>
      _writeMs(_callKey(owner), at);

  Future<void> clearCallNotification(int owner) => _clear(_callKey(owner));
}

/// The decision a single dispatch pass made — useful for logging and
/// for tests that want to assert on outcome without mocking the
/// notification layer.
enum PetNotificationDecision {
  none,
  stageTransition,
  sicknessOnset,
  attentionCall,
  suppressedStale,
  suppressedDedupe,
}

/// Adapter around [NotificationService] so tests can inject a fake.
abstract class PetNotificationSink {
  Future<void> sendStageTransition({
    required PetStage toStage,
    required PetBranch branch,
    required int ownerNodeNum,
  });
  Future<void> sendSicknessOnset({required int ownerNodeNum});
  Future<void> sendAttentionCall({
    required CallReason reason,
    required int ownerNodeNum,
  });
}

/// Production sink — wraps [NotificationService]'s singleton.
class DefaultPetNotificationSink implements PetNotificationSink {
  const DefaultPetNotificationSink();

  @override
  Future<void> sendStageTransition({
    required PetStage toStage,
    required PetBranch branch,
    required int ownerNodeNum,
  }) => NotificationService().showPetStageTransitionNotification(
    toStage: toStage,
    branch: branch,
    ownerNodeNum: ownerNodeNum,
  );

  @override
  Future<void> sendSicknessOnset({required int ownerNodeNum}) =>
      NotificationService().showPetSicknessNotification(
        ownerNodeNum: ownerNodeNum,
      );

  @override
  Future<void> sendAttentionCall({
    required CallReason reason,
    required int ownerNodeNum,
  }) => NotificationService().showPetAttentionCallNotification(
    reason: reason,
    ownerNodeNum: ownerNodeNum,
  );
}

/// Decides which (if any) notifications to fire for the observed state
/// transition. Pure logic except for [sink] (tested via fakes) and
/// [ledger] (tested via in-memory SharedPreferences).
class PetNotificationDispatcher {
  final PetNotificationLedger ledger;
  final PetNotificationSink sink;

  /// Transitions older than this are considered stale on resume — the
  /// milestone moment has already passed and a notification would be
  /// confusing.
  final Duration stageStalenessWindow;

  /// Optional gate for OS-level notification suppression. When provided
  /// and returning true, the dispatcher STILL takes the dedupe claim
  /// (so the notification is treated as delivered) but does NOT emit a
  /// system notification — the user is already looking at NodePet and
  /// the in-app banner / hatch overlay is a better signal. Leave null
  /// in tests to exercise the full fire path.
  final bool Function()? isAppInForeground;

  PetNotificationDispatcher({
    required this.ledger,
    required this.sink,
    this.stageStalenessWindow = const Duration(hours: 6),
    this.isAppInForeground,
  });

  bool get _suppressForForeground =>
      isAppInForeground != null && isAppInForeground!();

  // ---- Synchronous claim maps -----------------------------------------
  //
  // The persistent [ledger] lives in SharedPreferences. Marking it is
  // async, so two concurrent `onStateTransition` calls can both pass the
  // ledger check, both enter their respective `await sink.send...`, and
  // both fire a notification before either writes. In production this
  // surfaces as the same "Pet hatched" notification repeating every
  // animation-ticker emit.
  //
  // The in-memory claim maps dedupe synchronously BEFORE any `await`.
  // They're authoritative within a single app session; the persistent
  // [ledger] backs them for cold-start durability. Clears wipe both.
  final Map<int, DateTime> _stageClaims = {};
  final Map<int, DateTime> _sicknessClaims = {};
  final Map<int, DateTime> _callClaims = {};

  /// Inspect a provider-layer transition from [previous] to [current].
  /// Returns the list of decisions made (for logging + test assertions).
  /// Safe to call repeatedly with identical states — dedupe prevents
  /// duplicate emissions.
  Future<List<PetNotificationDecision>> onStateTransition({
    required PetState? previous,
    required PetState current,
    required DateTime now,
  }) async {
    final decisions = <PetNotificationDecision>[];

    // ---- Stage transition ---------------------------------------------
    // Use the animation-tracker-style "latest unacknowledged" shape:
    // during catch-up we may cross multiple boundaries and only the
    // most recent matters for the user.
    final latestStage = _latestStageAdvancedEvent(current);
    if (latestStage != null) {
      final decision = await _maybeFireStage(
        current: current,
        event: latestStage,
        now: now,
      );
      decisions.add(decision);
    }

    // ---- Sickness onset ----------------------------------------------
    final sicknessDecision = await _maybeFireSickness(
      previous: previous,
      current: current,
    );
    decisions.add(sicknessDecision);

    // ---- Attention call start ----------------------------------------
    final callDecision = await _maybeFireAttentionCall(
      current: current,
      now: now,
    );
    decisions.add(callDecision);

    return decisions;
  }

  // ---- Stage --------------------------------------------------------

  CareEvent? _latestStageAdvancedEvent(PetState s) {
    CareEvent? best;
    for (final e in s.recentEvents) {
      // Egg→juvenile emits `hatched`; every other transition emits
      // `stageAdvanced`. Treat both as stage-transition signals for
      // notification purposes.
      if (e.kind != CareEventKind.stageAdvanced &&
          e.kind != CareEventKind.hatched) {
        continue;
      }
      if (best == null || e.at.isAfter(best.at)) best = e;
    }
    return best;
  }

  Future<PetNotificationDecision> _maybeFireStage({
    required PetState current,
    required CareEvent event,
    required DateTime now,
  }) async {
    // Dedupe against the in-memory claim FIRST — this is the
    // synchronous guard that prevents concurrent dispatches from
    // both passing the check. The persistent ledger is the same
    // watermark, bootstrapped from disk on first use this session.
    final claimed =
        _stageClaims[current.ownerNodeNum] ??
        ledger.stageNotifiedAt(current.ownerNodeNum);
    if (claimed != null && !event.at.isAfter(claimed)) {
      return PetNotificationDecision.suppressedDedupe;
    }

    // Stale gate: if the latest transition is older than the window and
    // the pet isn't dormant, the moment has passed. We still advance
    // the watermark so we don't re-examine it on every rebuild, but we
    // don't emit a user-facing notification for something that happened
    // hours ago.
    final age = now.difference(event.at);
    if (age > stageStalenessWindow && current.stage != PetStage.dormant) {
      _stageClaims[current.ownerNodeNum] = event.at;
      await ledger.markStageNotifiedAt(current.ownerNodeNum, event.at);
      AppLogging.pet(
        'PetNotificationDispatcher: stage transition suppressed '
        '(stale, age=${age.inMinutes}min) '
        'toStage=${current.stage.name}',
      );
      return PetNotificationDecision.suppressedStale;
    }

    // Claim SYNCHRONOUSLY before the async dispatch so any concurrent
    // call sees the claim and returns suppressedDedupe. Persist to the
    // ledger as well, but don't wait for it — the in-memory claim is
    // the authority within this session.
    _stageClaims[current.ownerNodeNum] = event.at;
    final persist = ledger.markStageNotifiedAt(current.ownerNodeNum, event.at);

    // Foreground suppression: the user is already looking at NodePet
    // (that's how the notification bridge got activated). An OS banner
    // on top of the in-app banner is noise. We still took the dedupe
    // claim above so a later backgrounded event doesn't re-fire.
    if (_suppressForForeground) {
      await persist;
      AppLogging.pet(
        'PetNotificationDispatcher: stage transition suppressed '
        '(app in foreground) toStage=${current.stage.name}',
      );
      return PetNotificationDecision.stageTransition;
    }

    await sink.sendStageTransition(
      toStage: current.stage,
      branch: current.branch,
      ownerNodeNum: current.ownerNodeNum,
    );
    await persist;
    AppLogging.pet(
      'PetNotificationDispatcher: notified stage transition '
      'toStage=${current.stage.name} branch=${current.branch.name} '
      'at=${event.at.toIso8601String()}',
    );
    return PetNotificationDecision.stageTransition;
  }

  // ---- Sickness -----------------------------------------------------

  Future<PetNotificationDecision> _maybeFireSickness({
    required PetState? previous,
    required PetState current,
  }) async {
    // When recovered, clear both the claim and the ledger so the NEXT
    // onset notifies again.
    if (!current.isSick) {
      if (_sicknessClaims.remove(current.ownerNodeNum) != null ||
          ledger.sicknessNotifiedAt(current.ownerNodeNum) != null) {
        await ledger.clearSicknessNotification(current.ownerNodeNum);
      }
      return PetNotificationDecision.none;
    }
    final latestOnset = _latestEvent(current, CareEventKind.sicknessOnset);
    if (latestOnset == null) return PetNotificationDecision.none;
    final claimed =
        _sicknessClaims[current.ownerNodeNum] ??
        ledger.sicknessNotifiedAt(current.ownerNodeNum);
    if (claimed != null && !latestOnset.at.isAfter(claimed)) {
      return PetNotificationDecision.suppressedDedupe;
    }
    // Claim SYNCHRONOUSLY before the async dispatch.
    _sicknessClaims[current.ownerNodeNum] = latestOnset.at;
    final persist = ledger.markSicknessNotifiedAt(
      current.ownerNodeNum,
      latestOnset.at,
    );
    if (_suppressForForeground) {
      await persist;
      AppLogging.pet(
        'PetNotificationDispatcher: sickness onset suppressed '
        '(app in foreground)',
      );
      return PetNotificationDecision.sicknessOnset;
    }
    await sink.sendSicknessOnset(ownerNodeNum: current.ownerNodeNum);
    await persist;
    AppLogging.pet(
      'PetNotificationDispatcher: notified sickness onset '
      'at=${latestOnset.at.toIso8601String()}',
    );
    return PetNotificationDecision.sicknessOnset;
  }

  // ---- Attention call ----------------------------------------------

  Future<PetNotificationDecision> _maybeFireAttentionCall({
    required PetState current,
    required DateTime now,
  }) async {
    final call = current.activeCall;
    if (call == null) {
      if (_callClaims.remove(current.ownerNodeNum) != null ||
          ledger.callNotifiedAt(current.ownerNodeNum) != null) {
        await ledger.clearCallNotification(current.ownerNodeNum);
      }
      return PetNotificationDecision.none;
    }
    if (call.hasExpired(now)) {
      return PetNotificationDecision.suppressedStale;
    }
    final claimed =
        _callClaims[current.ownerNodeNum] ??
        ledger.callNotifiedAt(current.ownerNodeNum);
    if (claimed != null && !call.startedAt.isAfter(claimed)) {
      return PetNotificationDecision.suppressedDedupe;
    }
    // Claim SYNCHRONOUSLY before the async dispatch.
    _callClaims[current.ownerNodeNum] = call.startedAt;
    final persist = ledger.markCallNotifiedAt(
      current.ownerNodeNum,
      call.startedAt,
    );
    if (_suppressForForeground) {
      await persist;
      AppLogging.pet(
        'PetNotificationDispatcher: attention call suppressed '
        '(app in foreground)',
      );
      return PetNotificationDecision.attentionCall;
    }
    await sink.sendAttentionCall(
      reason: call.reason,
      ownerNodeNum: current.ownerNodeNum,
    );
    await persist;
    AppLogging.pet(
      'PetNotificationDispatcher: notified attention call '
      'reason=${call.reason.name} at=${call.startedAt.toIso8601String()}',
    );
    return PetNotificationDecision.attentionCall;
  }

  // ---- Helpers ------------------------------------------------------

  CareEvent? _latestEvent(PetState s, CareEventKind kind) {
    CareEvent? best;
    for (final e in s.recentEvents) {
      if (e.kind != kind) continue;
      if (best == null || e.at.isAfter(best.at)) best = e;
    }
    return best;
  }
}

/// Re-export for callers that want to classify the transition kind for
/// copy selection.
PetTransitionKind classifyStage(PetStage resulting) =>
    classifyTransitionByResultingStage(resulting);
