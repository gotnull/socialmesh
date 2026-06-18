// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Thin controller for OUTBOUND Incident Mode (Help Mode) actions.
///
/// Responsibilities: allocate local incident id / per-sender seq, build
/// [IncidentEvent]s with the LOCAL node identity, persist them locally FIRST
/// (so a failed send never loses the event), compute eligible recipients
/// (Handshake-trusted AND advertising `incidentHelpV1`), encode via
/// [SppIncidentModeCodec], and hand the encoded frame to the transport ONLY
/// when at least one eligible recipient exists.
///
/// It deliberately does not project lifecycle state -- that is the reducer's
/// job (read back via the store). It performs no notifications and no location
/// escalation.
///
/// Transport note: the SIP/MRRP transport is broadcast-only (there is no
/// unicast). Eligibility therefore gates the DECISION to transmit, not the
/// wire addressing; the receiver-side Handshake-trust gate (PR-7A) plus the
/// `incidentHelpV1` capability advertisement are the actual boundary -- an
/// untrusted or non-capable node drops the frame. When no eligible recipient
/// exists, nothing is transmitted (the event is still persisted locally).
///
/// Plan: docs/engineering/INCIDENT_MODE_SIP_MRRP_PLAN.md (PR-7B)
library;

import 'dart:math';
import 'dart:typed_data';

import '../../../core/logging.dart';
import '../../../services/protocol/sip/sip_types.dart';
import '../../../services/protocol/sip/spp_incident_mode_codec.dart';
import '../models/incident_mode_models.dart';
import 'help_location_policy.dart';
import 'incident_mode_store.dart';

/// A discovered peer's node id + advertised SIP feature bitmap.
typedef IncidentPeer = ({int nodeId, int features});

/// Shared CSPRNG for default incident-id allocation.
final Random _incidentIdRng = Random.secure();

/// Default incident-id generator: a cryptographically-strong random u32 in
/// `[1, 0xFFFFFFFE]`, avoiding the reserved sentinels `0` and `0xFFFFFFFF`.
///
/// Mesh-originated incident ids must be random (not monotonic / timestamp /
/// user-entered) so independently-originating devices do not collide.
int defaultIncidentIdGenerator() => 1 + _incidentIdRng.nextInt(0xFFFFFFFE);

/// Outcome of an outbound Incident Mode action.
class IncidentSendOutcome {
  final int incidentId;
  final int seq;

  /// Whether a new local row was persisted (false if it was a duplicate).
  final bool persisted;

  /// Eligible recipients at send time (trusted + capable).
  final List<int> recipients;

  /// Whether the encoded frame was handed to the transport.
  final bool transmitted;

  /// True when a fresh incident id could not be allocated (collision retries
  /// exhausted). When true, nothing was persisted or sent.
  final bool idAllocationFailed;

  const IncidentSendOutcome({
    required this.incidentId,
    required this.seq,
    required this.persisted,
    required this.recipients,
    required this.transmitted,
    this.idAllocationFailed = false,
  });

  /// A safe failure outcome: no id allocated, nothing persisted or sent.
  const IncidentSendOutcome.allocationFailed()
    : incidentId = 0,
      seq = 0,
      persisted = false,
      recipients = const [],
      transmitted = false,
      idAllocationFailed = true;

  /// Whether any eligible recipient existed at send time.
  bool get hadEligibleRecipients => recipients.isNotEmpty;
}

/// Sends an encoded help event to the mesh. Returns whether the frame was
/// handed to the transport. The [recipients] are the eligible peers; the
/// implementation may broadcast once (the transport is broadcast-only) and use
/// the list only for the decision and safe logging.
typedef SendHelpEvent =
    Future<bool> Function(Uint8List payload, List<int> recipients);

class IncidentHelpController {
  /// Maximum incident-id allocation attempts before giving up (collision
  /// retries). Random u32 collisions against the local store are astronomically
  /// unlikely; this is a safety bound.
  static const int maxIdAllocationTries = 8;

  /// Safety latch (delegates to [HelpLocationPolicy], the single source of
  /// truth). Precise [IncidentLocation] MUST NOT be transmitted over the
  /// current broadcast-only, channel-encrypted-only MRRP path -- any
  /// same-channel node could decode it. This controller intentionally exposes
  /// NO location-emitting method. Precise-location sending may be enabled ONLY
  /// behind a recipient-sealed payload path AND a dedicated capability/flag.
  /// See docs/engineering/INCIDENT_MODE_SIP_MRRP_PLAN.md (Location policy).
  static bool get preciseLocationSendingSupported =>
      HelpLocationPolicy.preciseLocationSendingSupported;

  final IncidentModeStore _store;
  final Future<void> Function() _ensureStoreReady;
  final int Function() _localNodeId;
  final List<IncidentPeer> Function() _discoveredPeers;
  final bool Function(int nodeId) _isTrusted;
  final SendHelpEvent _sendHelpEvent;
  final DateTime Function() _clock;
  final int Function() _idGenerator;

  IncidentHelpController({
    required IncidentModeStore store,
    required Future<void> Function() ensureStoreReady,
    required int Function() localNodeId,
    required List<IncidentPeer> Function() discoveredPeers,
    required bool Function(int nodeId) isTrusted,
    required SendHelpEvent sendHelpEvent,
    DateTime Function()? clock,
    int Function()? idGenerator,
  }) : _store = store,
       _ensureStoreReady = ensureStoreReady,
       _localNodeId = localNodeId,
       _discoveredPeers = discoveredPeers,
       _isTrusted = isTrusted,
       _sendHelpEvent = sendHelpEvent,
       _clock = clock ?? (() => DateTime.now().toUtc()),
       _idGenerator = idGenerator ?? defaultIncidentIdGenerator;

  /// Peers eligible to receive help events: Handshake-trusted AND advertising
  /// [SipFeatureBits.incidentHelpV1]. Merely-seen / same-channel / has-pubkey
  /// peers are excluded.
  List<int> eligibleRecipients() {
    return [
      for (final p in _discoveredPeers())
        if (_isTrusted(p.nodeId) &&
            (p.features & SipFeatureBits.incidentHelpV1) != 0)
          p.nodeId,
    ];
  }

  /// Raise a new help request. Allocates a fresh RANDOM incident id (collision-
  /// checked against the local store, bounded retries). Returns
  /// [IncidentSendOutcome.allocationFailed] if a free id cannot be found, in
  /// which case nothing is persisted or sent.
  Future<IncidentSendOutcome> createHelpRequest({
    IncidentQuickUpdate? initialStatus,
    DateTime? expiresAt,
  }) async {
    await _ensureStoreReady();
    final incidentId = await _allocateIncidentId();
    if (incidentId == null) {
      AppLogging.incidents(
        'IncidentMode: incident id allocation exhausted', // lint-allow: hardcoded-string
      );
      return const IncidentSendOutcome.allocationFailed();
    }
    final outcome = await _emit(
      incidentId: incidentId,
      type: IncidentEventType.create,
      expiresAt: expiresAt,
    );
    if (initialStatus != null && initialStatus.isRequesterCode) {
      await sendRequesterStatus(incidentId: incidentId, code: initialStatus);
    }
    return outcome;
  }

  /// Allocates a fresh random incident id not already present in the local
  /// store. Skips reserved sentinels (0, 0xFFFFFFFF). Returns null if no free
  /// id is found within [maxIdAllocationTries].
  Future<int?> _allocateIncidentId() async {
    for (var i = 0; i < maxIdAllocationTries; i++) {
      final candidate = _idGenerator();
      if (candidate <= 0 || candidate >= 0xFFFFFFFF) continue;
      final existing = await _store.getIncidentEvents(candidate);
      if (existing.isEmpty) return candidate;
    }
    return null;
  }

  Future<IncidentSendOutcome> sendRequesterStatus({
    required int incidentId,
    required IncidentQuickUpdate code,
  }) => _emit(
    incidentId: incidentId,
    type: IncidentEventType.requesterStatus,
    quickUpdate: code,
  );

  /// Acknowledge a help request WITHOUT committing to respond. Emits a `seen`
  /// event (it surfaced locally); it does not make the local node a responder.
  Future<IncidentSendOutcome> acknowledge({required int incidentId}) =>
      _emit(incidentId: incidentId, type: IncidentEventType.seen);

  Future<IncidentSendOutcome> acceptHelpRequest({required int incidentId}) =>
      _emit(incidentId: incidentId, type: IncidentEventType.responderAccept);

  Future<IncidentSendOutcome> sendResponderStatus({
    required int incidentId,
    required IncidentQuickUpdate code,
  }) => _emit(
    incidentId: incidentId,
    type: IncidentEventType.responderStatus,
    quickUpdate: code,
  );

  Future<IncidentSendOutcome> leaveResponse({required int incidentId}) =>
      _emit(incidentId: incidentId, type: IncidentEventType.responderLeave);

  /// "I'm safe" -> resolve (terminal resolvedSafe). Distinct from cancel.
  Future<IncidentSendOutcome> resolveSafe({required int incidentId}) =>
      _emit(incidentId: incidentId, type: IncidentEventType.resolve);

  /// "Cancel request" -> false-alarm cancel (terminal cancelled). Distinct
  /// from resolve. Note: the `falseAlarm` quick status does NOT terminate.
  Future<IncidentSendOutcome> cancelRequest({required int incidentId}) =>
      _emit(incidentId: incidentId, type: IncidentEventType.cancel);

  Future<IncidentSendOutcome> _emit({
    required int incidentId,
    required IncidentEventType type,
    IncidentQuickUpdate? quickUpdate,
    DateTime? expiresAt,
  }) async {
    await _ensureStoreReady();
    final node = _localNodeId();
    final seq = await _store.nextLocalSeq(incidentId, node);
    final event = IncidentEvent(
      incidentId: incidentId,
      workflowKind: IncidentWorkflowKind.helpRequest,
      type: type,
      senderNodeId: node, // local node identity, never user-entered
      seq: seq,
      timestamp: _clock(),
      receivedAt: _clock(),
      quickUpdate: quickUpdate,
      expiresAt: expiresAt,
    );

    // Persist locally FIRST: a send failure must never erase the local event.
    final persisted = await _store.ingestEvent(event);

    final recipients = eligibleRecipients();
    if (recipients.isEmpty) {
      // Diagnostic: explain WHY there were no eligible recipients, per peer, so
      // "no trusted responders" can be traced to trust vs capability vs no peers
      // discovered. Node ids only (acceptable per the beta logging policy); no
      // body text or location. Gated by INCIDENTS_LOGGING_ENABLED.
      final peers = _discoveredPeers();
      AppLogging.incidents(
        'IncidentMode: no eligible recipients - discoveredPeers=${peers.length} '
        '[${peers.map((p) => '${p.nodeId}'
            ':trusted=${_isTrusted(p.nodeId)}'
            ':capable=${(p.features & SipFeatureBits.incidentHelpV1) != 0}').join(', ')}]', // lint-allow: hardcoded-string
      );
    }
    var transmitted = false;
    if (recipients.isNotEmpty) {
      final payload = SppIncidentModeCodec.encode(event);
      if (payload != null) {
        try {
          transmitted = await _sendHelpEvent(payload, recipients);
        } catch (e) {
          transmitted = false;
          AppLogging.incidents(
            'IncidentMode: outbound send failed: $e', // lint-allow: hardcoded-string
          );
        }
      }
    }

    AppLogging.incidents(
      'IncidentMode: outbound incident=$incidentId type=${type.name} seq=$seq '
      'recipients=${recipients.length} persisted=$persisted '
      'transmitted=$transmitted', // lint-allow: hardcoded-string
    );

    return IncidentSendOutcome(
      incidentId: incidentId,
      seq: seq,
      persisted: persisted,
      recipients: recipients,
      transmitted: transmitted,
    );
  }
}
