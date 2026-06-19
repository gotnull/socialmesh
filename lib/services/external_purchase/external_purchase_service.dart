// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Service layer for the external (fallback) purchase pipeline.
//
// Responsibilities:
//   - Wrap the five Cloud Functions in
//     backend/functions/src/external_checkout.ts.
//   - Maintain a stable per-install identity for unauthenticated callers.
//   - Drive the post-redirect polling state machine that flips the
//     "Confirming your unlock…" UI into a successful unlock.
//   - Persist active entitlements locally so a cold start without
//     network still surfaces previously-confirmed unlocks.
//
// CRITICAL SECURITY RULE (also enforced server-side):
//   The deep-link return alone NEVER unlocks anything. Only entries
//   in `external_entitlements/*` written by the BMC webhook unlock
//   features. The deep link only kicks off the polling that asks
//   the backend whether the webhook has landed yet.

import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logging.dart';
import 'device_install_id.dart';
import 'external_entitlement.dart';
import 'external_entitlement_cache.dart';

/// Snapshot of the in-flight deep-link confirmation state.
///
/// The UI reads this via [ExternalPurchaseService.confirmationStream].
/// `idle` is the resting state; `confirming` is shown after a deep link
/// comes back with a sessionId we recognise; `succeeded` and `failed`
/// are terminal and clear back to `idle` after the UI has consumed them.
enum ConfirmationStage { idle, confirming, succeeded, failed }

class ConfirmationState {
  final ConfirmationStage stage;
  final String? sessionId;
  final String? productId;
  final List<String> grantedProductIds;
  final String? errorMessage;

  const ConfirmationState({
    required this.stage,
    this.sessionId,
    this.productId,
    this.grantedProductIds = const [],
    this.errorMessage,
  });

  static const idle = ConfirmationState(stage: ConfirmationStage.idle);

  ConfirmationState copyWith({
    ConfirmationStage? stage,
    String? sessionId,
    String? productId,
    List<String>? grantedProductIds,
    String? errorMessage,
  }) {
    return ConfirmationState(
      stage: stage ?? this.stage,
      sessionId: sessionId ?? this.sessionId,
      productId: productId ?? this.productId,
      grantedProductIds: grantedProductIds ?? this.grantedProductIds,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Tunables for the post-redirect polling state machine.
///
/// Defaults: poll every 2 s for up to 60 s (= 30 attempts). Most
/// webhook deliveries land within ~3 s in practice; the 60 s ceiling
/// is generous enough to absorb a slow BMC delivery without the
/// "Confirming…" overlay feeling stuck.
class PollingPolicy {
  final Duration interval;
  final Duration maxDuration;

  const PollingPolicy({
    this.interval = const Duration(seconds: 2),
    this.maxDuration = const Duration(seconds: 60),
  });

  static const fast = PollingPolicy(
    interval: Duration(milliseconds: 500),
    maxDuration: Duration(seconds: 5),
  );
}

/// Thin wrapper over `FirebaseFunctions.httpsCallable`. Extracted so
/// tests can swap in a fake without touching the SDK singleton.
abstract class CallableInvoker {
  Future<Map<String, dynamic>> call(String name, Map<String, dynamic> data);

  static CallableInvoker firebase() => _FirebaseCallableInvoker();
}

class _FirebaseCallableInvoker implements CallableInvoker {
  @override
  Future<Map<String, dynamic>> call(
    String name,
    Map<String, dynamic> data,
  ) async {
    final result = await FirebaseFunctions.instance
        .httpsCallable(name)
        .call<Map<String, dynamic>>(data);
    return Map<String, dynamic>.from(result.data);
  }
}

class ExternalPurchaseService {
  final SharedPreferences _prefs;
  final ExternalEntitlementCache _cache;
  final CallableInvoker _invoker;
  final PollingPolicy _pollingPolicy;

  final _confirmationController =
      StreamController<ConfirmationState>.broadcast();
  ConfirmationState _confirmationState = ConfirmationState.idle;

  // Broadcasts every cache update so Riverpod's externalEntitlementsProvider
  // can re-emit without manual invalidation. Fires after refreshEntitlements
  // writes the cache; consumers receive the fresh active-product-id set.
  final _activeProductIdsController = StreamController<Set<String>>.broadcast();

  Timer? _pollTimer;
  DateTime? _pollDeadline;
  String? _pollingSessionId;

  ExternalPurchaseService({
    required this._prefs,
    required this._cache,
    CallableInvoker? invoker,
    this._pollingPolicy = const PollingPolicy(),
  }) : _invoker = invoker ?? CallableInvoker.firebase();

  Stream<ConfirmationState> get confirmationStream =>
      _confirmationController.stream;

  /// Broadcast of the active product-id set after each cache write.
  ///
  /// Riverpod's `externalEntitlementsProvider` listens to this so the UI
  /// flips to "unlocked" the instant `refreshEntitlements` completes,
  /// without depending on `ref.invalidate` from a specific call site
  /// (Stripe payment, BMC webhook, unlock code redemption all funnel
  /// through the same refresh path and therefore the same emit).
  Stream<Set<String>> get activeProductIdsStream =>
      _activeProductIdsController.stream;

  ConfirmationState get currentConfirmation => _confirmationState;

  ExternalEntitlementCache get cache => _cache;

  /// Cached entitlements, used by the providers' synchronous checks.
  Set<String> get cachedActiveProductIds => _cache.activeProductIds();

  // ---------------------------------------------------------------------------
  // Identity
  // ---------------------------------------------------------------------------

  /// Snapshot of the caller's identity sent to the backend on every
  /// callable invocation.
  ///
  /// **Always** includes `deviceInstallId`, regardless of Firebase auth
  /// state. External entitlements are intentionally device-scoped
  /// (same model as native iOS/Android IAP — purchases live on the
  /// install, not the account). Skipping the uid path entirely
  /// eliminates a class of bugs where Firebase Anonymous Auth
  /// completes between sequential calls and the backend resolves a
  /// different owner per call (entitlement written under
  /// `install_<uuid>` but queried under `uid_<anon-uid>` → zero
  /// matches). The auth token is still attached automatically by
  /// `httpsCallable.call` for users who happen to be signed in; the
  /// backend treats `deviceInstallId` as the canonical owner key when
  /// present and uses `uid` only as a defensive fallback.
  Future<Map<String, dynamic>> _identityPayload() async {
    final installId = await DeviceInstallId.read(_prefs);
    return {'deviceInstallId': installId};
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Create a server-side checkout session for [productId].
  ///
  /// [provider] picks the external payment provider. When omitted, the
  /// backend picks its active default (Stripe wins over BMC). Callers
  /// should pass it explicitly so a future change to the default
  /// doesn't silently re-route in-progress purchase intents.
  ///
  /// [subjectKind] + [licenseOrgId] gate the slice-7 self-serve
  /// org-pack path. When [subjectKind] is `'org'`, the request carries
  /// `subjectKind: 'org'` and (when provided) `licenseOrgId: <value>`
  /// so the backend can validate ownership and the Stripe webhook
  /// (slice 5a) can create the matching `license_orgs/{licenseOrgId}`
  /// doc + org-owned entitlement.  When [subjectKind] is null or
  /// `'user'`, the org keys are omitted entirely - existing personal
  /// checkouts remain wire-identical to pre-slice-8 callers. The
  /// backend rejects malformed / anonymous / reserved-namespace
  /// org-pack requests with a `FunctionsException`; callers map
  /// those exactly as they did before.
  ///
  /// Throws if the backend rejects the productId (unknown product) or
  /// if the call fails for transport reasons. Callers should catch and
  /// surface a generic "couldn't start checkout" message.
  Future<CheckoutSessionDescriptor> createCheckout(
    String productId, {
    String? provider,
    String? subjectKind,
    String? licenseOrgId,
    String? licenseOrgName,
  }) async {
    final isOrgPack = subjectKind == 'org';
    AppLogging.purchase(
      '[ExternalPurchaseService] createCheckout productId=$productId '
      'provider=${provider ?? '<default>'} '
      'subjectKind=${isOrgPack ? 'org' : 'user'}',
    );
    final identity = await _identityPayload();
    final response = await _invoker.call('createExternalCheckout', {
      'productId': productId,
      if (provider != null) 'provider': provider,
      // Org metadata only when the caller explicitly opted in. The
      // server treats absent `subjectKind` as `'user'`, so personal
      // calls stay wire-identical to pre-slice-8 behaviour.
      if (isOrgPack) 'subjectKind': 'org',
      if (isOrgPack && licenseOrgId != null) 'licenseOrgId': licenseOrgId,
      if (isOrgPack && licenseOrgName != null) 'licenseOrgName': licenseOrgName,
      ...identity,
    });
    final descriptor = CheckoutSessionDescriptor.fromJson(response);
    AppLogging.purchase(
      '[ExternalPurchaseService] checkout_created sessionId=${descriptor.sessionId} '
      'reference=${descriptor.referenceCode} '
      'amount=${descriptor.expectedAmount} ${descriptor.currency}',
    );
    return descriptor;
  }

  /// One-shot status read for a session. Used by polling and by the
  /// confirmation overlay's manual "check now" affordance.
  Future<CheckoutSessionStatus> pollStatus(String sessionId) async {
    final response = await _invoker.call('getCheckoutStatus', {
      'sessionId': sessionId,
    });
    return CheckoutSessionStatus.fromJson(response);
  }

  /// Pull the latest entitlements from the backend and replace the
  /// local cache. Failures are logged and swallowed — the cache stays
  /// authoritative offline.
  Future<List<ExternalEntitlement>> refreshEntitlements() async {
    AppLogging.purchase('[ExternalPurchaseService] refreshEntitlements');
    try {
      final identity = await _identityPayload();
      final response = await _invoker.call('getExternalEntitlements', identity);
      // The cloud_functions plugin decodes nested JSON objects as
      // `Map<Object?, Object?>`, NOT `Map<String, dynamic>`. A naive
      // `whereType<Map<String, dynamic>>()` would silently drop every
      // entitlement and return 0 — which is exactly the bug we hit
      // with Simon's redemption (server granted, server returned 1
      // entitlement, but the client cast filtered it out and the UI
      // never showed the unlock). Use `Map<String, dynamic>.from(...)`
      // to coerce each element instead.
      final entitlementsRaw = (response['entitlements'] as List?) ?? const [];
      final list = entitlementsRaw
          .map(
            (e) => ExternalEntitlement.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
      await _cache.write(list);
      AppLogging.purchase(
        '[ExternalPurchaseService] entitlement_loaded count=${list.length}',
      );
      // Notify Riverpod so the UI can flip to unlocked immediately. The
      // active set is what consumers actually care about; the full list
      // is returned for callers that need provenance details.
      _activeProductIdsController.add(_cache.activeProductIds());
      return list;
    } catch (e) {
      AppLogging.purchase(
        '[ExternalPurchaseService] refreshEntitlements failed: $e — '
        'cache remains authoritative',
      );
      return _cache.read();
    }
  }

  /// Redeem a support-issued unlock code OR a group / community
  /// licensing seat code.
  ///
  /// Prefix-routed: `LSEAT-...` codes call `redeemLicenseSeatCode`
  /// (writes `org_seat_allocations/` + `license_orgs/{orgId}/members/{uid}`,
  /// returns the seat's productId so the existing UI can show
  /// "unlocked X" without caring about the licensing-vs-personal axis).
  /// Everything else falls through to the existing `redeemUnlockCode`
  /// path (writes `external_entitlements/`).
  ///
  /// Returns the granted product ids on success. Throws on invalid /
  /// expired / exhausted codes - callers map the FunctionsException
  /// codes to user-facing messages.
  Future<List<String>> redeemCode(String code) async {
    if (_isLicenseSeatCode(code)) {
      return _redeemLicenseSeatCode(code);
    }
    return _redeemUnlockCode(code);
  }

  /// Personal-pack code path (existing). Matches `SM-XXXX-XXXX` and
  /// any non-licensing prefix.
  Future<List<String>> _redeemUnlockCode(String code) async {
    AppLogging.purchase('[ExternalPurchaseService] redeemCode kind=personal');
    final identity = await _identityPayload();
    final response = await _invoker.call('redeemUnlockCode', {
      'code': code,
      ...identity,
    });
    final productIds = (response['productIds'] as List)
        .map((e) => e as String)
        .toList();
    AppLogging.purchase(
      '[ExternalPurchaseService] unlock_code_redeemed count=${productIds.length}',
    );
    // Refresh so the cache reflects the new entitlements immediately.
    await refreshEntitlements();
    return productIds;
  }

  /// License seat code path (slice 4b). Calls `redeemLicenseSeatCode`
  /// which transactionally allocates a seat and creates / updates a
  /// member doc inside `license_orgs/`. Backend is idempotent on
  /// `(uid, licenseOrgId, productId)`: a replay returns
  /// `alreadyAllocated: true` without burning a seat-use.
  Future<List<String>> _redeemLicenseSeatCode(String code) async {
    AppLogging.purchase(
      '[ExternalPurchaseService] redeemCode kind=license_seat',
    );
    // No deviceInstallId on this path: licensing is uid-scoped, the
    // backend rejects anonymous callers, and adding device identity
    // would muddy the audit trail without unlocking anything.
    final response = await _invoker.call('redeemLicenseSeatCode', {
      'code': code,
    });
    final productId = response['productId'] as String;
    final alreadyAllocated = response['alreadyAllocated'] as bool? ?? false;
    AppLogging.purchase(
      '[ExternalPurchaseService] license_seat_redeemed '
      'alreadyAllocated=$alreadyAllocated',
    );
    // Refresh so the user / seat providers and the cache filter
    // re-derive with the new allocation. The Firestore streams behind
    // `currentUserLicenseOrgIdsProvider` and
    // `currentUserSeatAllocationsProvider` also pick up the change,
    // but kicking the entitlement cache here means the gate flips at
    // the same time as the personal-code path's flip.
    await refreshEntitlements();
    return [productId];
  }

  /// Codes starting with `LSEAT-` (case-insensitive, whitespace
  /// tolerant) route through the licensing path. Anything else - empty
  /// strings included - stays on the existing personal-pack path,
  /// which already handles those failure modes.
  static bool _isLicenseSeatCode(String code) {
    final normalised = code.trim().toUpperCase();
    return normalised.startsWith('LSEAT-') || normalised.startsWith('LSEAT ');
  }

  /// Bind every entitlement currently owned by this install to the
  /// signed-in Firebase Auth account. Idempotent - safe to call on
  /// every sign-in / link-with-credential transition.
  ///
  /// Returns the list of product ids that were freshly claimed (does
  /// not include already-claimed ones). The Firestore mirror means
  /// future `refreshEntitlements()` calls return the union of install
  /// + uid entitlements, so reinstall / new device sign-in restores
  /// transparently.
  ///
  /// Quiet no-op when the caller is not signed in - the backend
  /// rejects with `unauthenticated` and we swallow the error. Callers
  /// should not gate UI on this method's outcome.
  Future<List<String>> claimEntitlementsToAccount() async {
    AppLogging.purchase('[ExternalPurchaseService] claimEntitlementsToAccount');
    try {
      final installId = await DeviceInstallId.read(_prefs);
      final response = await _invoker.call('claimEntitlementsToAccount', {
        'deviceInstallId': installId,
      });
      final claimed = (response['productIds'] as List? ?? const [])
          .map((e) => e as String)
          .toList();
      final claimedCount = response['claimedCount'] as int? ?? 0;
      final alreadyCount = response['alreadyClaimedCount'] as int? ?? 0;
      AppLogging.purchase(
        '[ExternalPurchaseService] account_claim '
        'claimed=$claimedCount alreadyClaimed=$alreadyCount '
        'productIds=$claimed',
      );
      if (claimedCount > 0) {
        // New uid-scoped entitlements just landed in Firestore.
        // Refresh so the cache + activeProductIdsStream reflect them.
        await refreshEntitlements();
      }
      return claimed;
    } catch (e) {
      AppLogging.purchase(
        '[ExternalPurchaseService] claimEntitlementsToAccount failed '
        '(non-fatal, will retry on next sign-in): $e',
      );
      return const [];
    }
  }

  // ---------------------------------------------------------------------------
  // Deep-link return + polling
  // ---------------------------------------------------------------------------

  /// Entry point from the deep-link router. The redirect alone never
  /// unlocks anything — this just kicks off the polling loop that
  /// queries the backend until the webhook has flipped the session.
  void handleDeepLink(String sessionId) {
    if (sessionId.isEmpty) {
      AppLogging.purchase(
        '[ExternalPurchaseService] handleDeepLink: empty sessionId, ignoring',
      );
      return;
    }
    if (_pollingSessionId == sessionId &&
        _confirmationState.stage == ConfirmationStage.confirming) {
      // Re-firing the deep link while we're already polling the same
      // session is a no-op; the user probably came back via the
      // browser tab a second time.
      return;
    }
    AppLogging.purchase(
      '[ExternalPurchaseService] redirect_received sessionId=$sessionId',
    );
    _emit(
      _confirmationState.copyWith(
        stage: ConfirmationStage.confirming,
        sessionId: sessionId,
        errorMessage: null,
      ),
    );
    _startPolling(sessionId);
  }

  void _startPolling(String sessionId) {
    _stopPolling();
    _pollingSessionId = sessionId;
    _pollDeadline = DateTime.now().add(_pollingPolicy.maxDuration);
    AppLogging.purchase(
      '[ExternalPurchaseService] polling_started sessionId=$sessionId '
      'interval=${_pollingPolicy.interval.inMilliseconds}ms '
      'deadline=${_pollDeadline!.toIso8601String()}',
    );
    // Immediate first tick so a webhook that landed before the user
    // returned doesn't wait an extra interval to be seen.
    unawaited(_pollOnce());
    _pollTimer = Timer.periodic(_pollingPolicy.interval, (_) => _pollOnce());
  }

  Future<void> _pollOnce() async {
    final sessionId = _pollingSessionId;
    if (sessionId == null) return;
    try {
      final status = await pollStatus(sessionId);
      switch (status.status) {
        case CheckoutStatus.paid:
          await _onPolledSuccess(status);
          return;
        case CheckoutStatus.failed:
        case CheckoutStatus.expired:
          _onPolledFailure(status.status);
          return;
        case CheckoutStatus.pending:
        case CheckoutStatus.unknown:
          // Keep polling unless we've passed the deadline.
          break;
      }
    } catch (e) {
      AppLogging.purchase(
        '[ExternalPurchaseService] pollOnce error: $e — continuing',
      );
    }

    final deadline = _pollDeadline;
    if (deadline != null && DateTime.now().isAfter(deadline)) {
      _onPolledFailure(CheckoutStatus.expired);
    }
  }

  Future<void> _onPolledSuccess(CheckoutSessionStatus status) async {
    // Dedup concurrent in-flight pollOnce cycles: Timer.periodic fires
    // at the 2s interval, and a slow network read can leave a second
    // _pollOnce already enqueued when the first one returns paid. Both
    // would otherwise call _onPolledSuccess and double the
    // refreshEntitlements + Firestore writes. _stopPolling below nulls
    // _pollingSessionId, so the second invocation bails here.
    if (_pollingSessionId == null) {
      AppLogging.purchase(
        '[ExternalPurchaseService] payment_confirmed dedup '
        'sessionId=${status.sessionId} — already handled by prior poll cycle',
      );
      return;
    }
    AppLogging.purchase(
      '[ExternalPurchaseService] payment_confirmed sessionId=${status.sessionId} '
      'productId=${status.productId} grants=${status.grantedProductIds}',
    );
    _stopPolling();
    // Refresh the entitlement cache so the UI flips to "unlocked"
    // before the success state is announced.
    await refreshEntitlements();
    _emit(
      _confirmationState.copyWith(
        stage: ConfirmationStage.succeeded,
        sessionId: status.sessionId,
        productId: status.productId,
        grantedProductIds: status.grantedProductIds,
        errorMessage: null,
      ),
    );
    AppLogging.purchase(
      '[ExternalPurchaseService] unlock_completed sessionId=${status.sessionId}',
    );
  }

  void _onPolledFailure(CheckoutStatus terminal) {
    // Same dedup as _onPolledSuccess (see comment there).
    if (_pollingSessionId == null) {
      return;
    }
    AppLogging.purchase(
      '[ExternalPurchaseService] polling_terminal status=$terminal '
      'sessionId=$_pollingSessionId',
    );
    _stopPolling();
    _emit(
      _confirmationState.copyWith(
        stage: ConfirmationStage.failed,
        errorMessage: terminal.name,
      ),
    );
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _pollDeadline = null;
    _pollingSessionId = null;
  }

  /// Acknowledge a terminal confirmation so the overlay can dismiss.
  void acknowledgeConfirmation() {
    if (_confirmationState.stage == ConfirmationStage.idle) return;
    _emit(ConfirmationState.idle);
  }

  void _emit(ConfirmationState next) {
    _confirmationState = next;
    _confirmationController.add(next);
  }

  /// Stop the polling loop and close the broadcast stream. Wired via
  /// `ref.onDispose` in the provider factory.
  Future<void> dispose() async {
    _stopPolling();
    await _confirmationController.close();
    await _activeProductIdsController.close();
  }
}
