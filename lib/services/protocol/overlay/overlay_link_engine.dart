// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Overlay link engine — single-writer owner of link state.
///
/// Every mutation of an [OverlayLinkRecord] flows through this engine.
/// Mutation methods are serialised via an internal async mutex so that
/// ingress callbacks, tick callbacks, local opens, and close requests
/// cannot race each other. This is the rule the spec calls out in
/// §21.1: "single-writer persistence — one authoritative mutation
/// path per link/resource row".
///
/// The engine is deliberately minimal for P1:
///   - In-order `seq` only. Out-of-order and selective ACK land in P5.
///   - Boring ping cadence. Adaptive keepalives are a later problem.
///   - No resource transfer wiring. `LINK_DATA` is delivered to
///     consumers via the events stream, who do with it what they will.
///   - No secure envelope. §12 is deferred to v0.3.
library;

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import '../../../core/logging.dart';
import 'overlay_constants.dart';
import 'overlay_endpoint_id.dart';
import 'overlay_endpoint_manager.dart';
import 'overlay_endpoint_record.dart';
import 'overlay_handshake_signer.dart';
import 'overlay_link_codec.dart';
import 'overlay_link_egress.dart';
import 'overlay_link_models.dart';
import 'overlay_link_store.dart';
import 'overlay_secure_session_manager.dart';
import 'overlay_types.dart';

/// Wall-clock source for the engine. Defaults to
/// `DateTime.now().millisecondsSinceEpoch`; tests inject a stub to
/// drive stale/expiry transitions deterministically.
typedef OverlayLinkClock = int Function();

/// Random 4-byte link id generator. Tests inject a deterministic
/// sequence; production uses [Random.secure].
typedef OverlayLinkIdGenerator = int Function();

/// Single-writer owner of overlay link records.
class OverlayLinkEngine {
  final OverlayLinkStore _store;
  final OverlayLinkEgress _egress;
  final OverlayLinkAcceptPolicy _acceptPolicy;
  final OverlayLinkClock _clock;
  final OverlayLinkIdGenerator _linkIdGenerator;

  /// Optional identity + endpoint binding manager (P3). When set:
  /// - Outbound `LINK_OPEN` / `LINK_OPEN_OK` carry a signed body
  ///   (§24.1.1) proving endpoint identity.
  /// - Inbound link-establishment frames with non-empty payloads are
  ///   verified against their signed bodies; invalid signatures are
  ///   rejected with `authFailure`, and valid ones persist an
  ///   endpoint observation with `trustLevel=signatureVerified`.
  ///
  /// When `null`, unsigned P2 behavior is used on both send and
  /// receive — peers see empty-payload handshakes, interop with P2-
  /// only peers is preserved.
  final OverlayEndpointManager? _endpointManager;

  /// Optional v0.3 secure-session manager. When present, the engine
  /// forwards three lifecycle hooks onto it:
  ///   - `onLinkActivated` after a link transitions to `active` (via
  ///     either `_handleLinkOpen` acceptance or `_handleLinkOpenOk`).
  ///   - `onSecureInbound` for every `linkSecureInit`/`linkSecureAck`/
  ///     `linkSecureData` frame.
  ///   - `onLinkTerminated` on any terminal transition.
  /// When `null`, secure-family frames are logged and dropped (§25.7
  /// fail-closed semantics for the link).
  final OverlaySecureSessionManager? _secureSessionManager;

  final StreamController<OverlayLinkEvent> _events =
      StreamController<OverlayLinkEvent>.broadcast();

  Future<void> _mutex = Future<void>.value();
  bool _disposed = false;

  /// Construct a new engine.
  ///
  /// [acceptPolicy] is consulted for every inbound `LINK_OPEN`; the
  /// default accepts every peer, which is suitable only for unit
  /// tests. Production callers MUST provide a policy.
  OverlayLinkEngine({
    required OverlayLinkStore store,
    required OverlayLinkEgress egress,
    OverlayLinkAcceptPolicy acceptPolicy = overlayLinkAcceptAll,
    OverlayLinkClock? clock,
    OverlayLinkIdGenerator? linkIdGenerator,
    OverlayEndpointManager? endpointManager,
    OverlaySecureSessionManager? secureSessionManager,
  }) : _store = store,
       _egress = egress,
       _acceptPolicy = acceptPolicy,
       _clock = clock ?? _defaultClock,
       _linkIdGenerator = linkIdGenerator ?? _defaultLinkIdGenerator,
       _endpointManager = endpointManager,
       _secureSessionManager = secureSessionManager;

  /// Stream of engine events. Broadcast; late subscribers do not
  /// replay.
  Stream<OverlayLinkEvent> get events => _events.stream;

  static int _defaultClock() => DateTime.now().millisecondsSinceEpoch;

  static final Random _secureRandom = Random.secure();

  static int _defaultLinkIdGenerator() {
    // Exclude 0 so link_id==0 remains an unambiguous "unused" value in
    // control frames that carry no session.
    while (true) {
      final candidate = _secureRandom.nextInt(0xFFFFFFFF) + 1;
      if (candidate != 0 && candidate <= 0xFFFFFFFF) return candidate;
    }
  }

  // ---------------------------------------------------------------
  // Public mutation surface (all serialised via [_serialize]).
  // ---------------------------------------------------------------

  /// Open a new link to [peerNodeNum].
  ///
  /// When a canonical non-terminal link already exists for [peerNodeNum]
  /// it is reused (§tie-break). On reuse, [peerCapabilitiesHint] — if
  /// supplied — overwrites the record's stored capabilities. The
  /// provider layer uses this to propagate the peer's CURRENT SIP-
  /// advertised overlay capabilities (e.g. `secureV03` toggled on
  /// today when yesterday's stored record predates that rollout) onto
  /// the canonical record without a fresh `LINK_OPEN` round-trip.
  Future<OverlayLinkRecord> openLocal({
    required Uint8List peerPersonaHint,
    required int peerNodeNum,
    OverlayLinkCapabilities localCapabilities = OverlayLinkCapabilities.none,
    OverlayLinkCapabilities? peerCapabilitiesHint,
  }) {
    return _serialize(
      () => _openLocalLocked(
        peerPersonaHint,
        peerNodeNum,
        localCapabilities,
        peerCapabilitiesHint,
      ),
    );
  }

  /// Process an inbound [frame] from [senderNodeNum].
  Future<void> handleInbound(OverlayLinkFrame frame, int senderNodeNum) {
    return _serialize(() => _handleInboundLocked(frame, senderNodeNum));
  }

  /// Periodic tick: apply stale / expiry transitions and prune old
  /// terminal rows.
  Future<void> tick() {
    return _serialize(_tickLocked);
  }

  /// Close a link with [reason]. Idempotent when the link is already
  /// terminal.
  Future<void> close(int linkId, OverlayLinkCloseReason reason) {
    return _serialize(() => _closeLocked(linkId, reason));
  }

  /// Send a `LINK_DATA` payload on [linkId]. Assigns the next
  /// monotonic `seq`, emits the frame via egress, and persists the
  /// advanced seq horizon. Returns the encoded wire bytes for the
  /// frame on success, or `null` if the link is not active or egress
  /// refused delivery.
  Future<Uint8List?> sendData(int linkId, Uint8List payload) {
    return _serialize(() => _sendDataLocked(linkId, payload));
  }

  /// Run the P1 restore procedure against whatever is in the store.
  ///
  /// Per §21.1, restore never resurrects live sessions: any record
  /// that was in `active`, `stale`, or `draining` is rewritten to
  /// `stale` so the next inbound frame (or a local close) has to
  /// re-establish activity. Records in `opening` at shutdown cannot
  /// resume mid-handshake and become `failed(timeout)`. Records past
  /// their `expiresAtMs` become `failed(timeout)` regardless of their
  /// former state. Terminal rows are left unchanged.
  Future<void> restore() {
    return _serialize(_restoreLocked);
  }

  /// Close the events stream. Does not close the underlying store
  /// (ownership remains with the caller).
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _events.close();
  }

  // ---------------------------------------------------------------
  // Private locked implementations.
  // ---------------------------------------------------------------

  Future<T> _serialize<T>(Future<T> Function() fn) {
    if (_disposed) {
      return Future<T>.error(StateError('OverlayLinkEngine has been disposed'));
    }
    final prior = _mutex;
    final completer = Completer<T>();
    _mutex = prior.then((_) async {
      try {
        completer.complete(await fn());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  Future<OverlayLinkRecord> _openLocalLocked(
    Uint8List peerPersonaHint,
    int peerNodeNum,
    OverlayLinkCapabilities capabilities,
    OverlayLinkCapabilities? peerCapabilitiesHint,
  ) async {
    // Canonical-link rule: at most one non-terminal link per peer
    // node. The lookup is by `peerNodeNum` rather than
    // `peerPersonaHint` because at auto-open time the caller may only
    // know a synthetic hint (the peer's real persona hint arrives
    // inside the signed LINK_OPEN body). Looking up by node num
    // bridges the synthetic/real view so initiator and responder
    // records for the same peer converge on one canonical link.
    //
    // If a non-terminal record already exists for this peer — whether
    // from a prior openLocal, a restored record, or an inbound
    // LINK_OPEN the responder path already accepted — reuse it. No
    // second LINK_OPEN is fired; the sim-open race handling in
    // `_handleLinkOpen` picks the deterministic winner when both
    // sides race.
    final nodeMatches = await _store.getNonTerminalForPeerNode(peerNodeNum);
    if (nodeMatches.isNotEmpty) {
      final canonical = nodeMatches.first;
      AppLogging.overlay(
        'openLocal reused canonical linkId=0x${canonical.linkId.toRadixString(16)} '
        'peer=$peerNodeNum state=${canonical.state.name}',
      );
      // A successful caller-side `openLocal` is a strong signal that
      // the peer is reachable RIGHT NOW — SIP handshake just
      // completed, user is actively trying to talk to them. Promote a
      // `stale` canonical (typically restored from a prior run, per
      // §21.1) back to `active` and refresh activity so downstream
      // consumers — chiefly the secure-session manager — see a live
      // link.
      final refreshedNow = _clock();
      var promoted = canonical;
      final needsPromotion = canonical.state != OverlayLinkState.active;
      final capsChanged =
          peerCapabilitiesHint != null &&
          peerCapabilitiesHint.supportedFeatures !=
              canonical.capabilities.supportedFeatures;
      if (needsPromotion || capsChanged) {
        promoted = canonical.copyWith(
          state: OverlayLinkState.active,
          lastActivityMs: refreshedNow,
          capabilities: peerCapabilitiesHint ?? canonical.capabilities,
        );
        await _store.upsert(promoted);
        AppLogging.overlay(
          'canonical promoted to active linkId=0x${canonical.linkId.toRadixString(16)} '
          'from=${canonical.state.name} '
          'caps=0x${promoted.capabilities.supportedFeatures.toRadixString(16)}',
        );
        _emit(
          OverlayLinkEvent(
            kind: OverlayLinkEventKind.activated,
            record: promoted,
          ),
        );
      }
      // Fire secure-activation hook so an auto-init can attach even
      // when the link was already in memory. The manager itself is
      // idempotent on the session-exists case.
      await _notifySecureActivated(promoted);
      return promoted;
    }

    final now = _clock();
    final linkId = _linkIdGenerator();
    final record = OverlayLinkRecord(
      linkId: linkId,
      peerPersonaHint: Uint8List.fromList(peerPersonaHint),
      peerNodeNum: peerNodeNum,
      state: OverlayLinkState.opening,
      isInitiator: true,
      capabilities: capabilities,
      openedAtMs: now,
      lastActivityMs: now,
      expiresAtMs: now + OverlayLinkConstants.linkMaxLifetimeSec * 1000,
      txNextSeq: 0,
      txAckHi: 0,
      rxExpectedSeq: 0,
      retryCount: 0,
    );
    await _store.upsert(record);
    AppLogging.overlay(
      'LINK_OPEN local linkId=0x${linkId.toRadixString(16)} '
      'peer=$peerNodeNum',
    );
    _emit(OverlayLinkEvent(kind: OverlayLinkEventKind.opened, record: record));
    final body = await _buildSignedHandshakeBody(capabilities);
    await _sendFrame(
      _newLinkFrame(
        msgType: OverlayLinkMsgType.linkOpen,
        record: record,
        payload: body,
        flagsExtra: OverlayLinkFlags.ackRequired,
      ),
      peerNodeNum,
    );
    return record;
  }

  Future<void> _handleInboundLocked(
    OverlayLinkFrame frame,
    int senderNodeNum,
  ) async {
    final now = _clock();
    switch (frame.msgType) {
      case OverlayLinkMsgType.linkOpen:
        await _handleLinkOpen(frame, senderNodeNum, now);
      case OverlayLinkMsgType.linkOpenOk:
        await _handleLinkOpenOk(frame, now);
      case OverlayLinkMsgType.linkOpenNo:
        await _handleLinkOpenNo(frame, now);
      case OverlayLinkMsgType.linkPing:
        await _handleLinkPing(frame, now);
      case OverlayLinkMsgType.linkPong:
        await _handleLinkPong(frame, now);
      case OverlayLinkMsgType.linkData:
        await _handleLinkData(frame, now);
      case OverlayLinkMsgType.linkAck:
        await _handleLinkAck(frame, now);
      case OverlayLinkMsgType.linkClose:
        await _handleLinkClose(frame, now);
      case OverlayLinkMsgType.linkSecureInit:
      case OverlayLinkMsgType.linkSecureAck:
      case OverlayLinkMsgType.linkSecureData:
        // v0.3 secure-session frames. Forwarded to the optional
        // secure-session manager; engine state is not affected. When
        // no manager is attached (flag off or unsigned-only peer),
        // the frames are logged and dropped per §25.7 fail-closed.
        final mgr = _secureSessionManager;
        if (mgr == null) {
          AppLogging.overlay(
            'SECURE drop: ${frame.msgType.name} with no session manager '
            'linkId=0x${frame.linkId.toRadixString(16)}',
          );
          return;
        }
        await mgr.onSecureInbound(frame, senderNodeNum);
    }
  }

  Future<void> _handleLinkOpen(
    OverlayLinkFrame frame,
    int senderNodeNum,
    int now,
  ) async {
    final existing = await _store.getByLinkId(frame.linkId);
    if (existing != null && !existing.isTerminal) {
      AppLogging.overlay(
        'LINK_OPEN collision linkId=0x${frame.linkId.toRadixString(16)}',
      );
      await _sendFrame(
        _newLinkFrame(
          msgType: OverlayLinkMsgType.linkOpenNo,
          record: existing,
          payload: Uint8List.fromList(<int>[
            OverlayLinkCloseReason.collision.code,
          ]),
        ),
        senderNodeNum,
      );
      return;
    }

    // P3: verify signed body before running policy/accept.
    final verify = await _verifyInboundHandshake(frame, senderNodeNum);
    if (!verify.valid) {
      AppLogging.overlay(
        'LINK_OPEN rejected linkId=0x${frame.linkId.toRadixString(16)} '
        'reason=${verify.reason?.name} detail=${verify.detail}',
      );
      await _sendFrame(
        _buildRejectionFrame(
          linkId: frame.linkId,
          reason: verify.reason ?? OverlayLinkCloseReason.authFailure,
        ),
        senderNodeNum,
      );
      _emit(
        OverlayLinkEvent(
          kind: OverlayLinkEventKind.rejected,
          record: _syntheticRejectionRecord(frame, senderNodeNum, now),
          detail: 'auth:${verify.detail}',
        ),
      );
      return;
    }

    final peerHint = verify.endpoint?.personaHint ?? _extractPeerHint(frame);
    final observedCaps = verify.body != null
        ? OverlayLinkCapabilities(
            supportedFeatures: verify.body!.capabilityBitset,
          )
        : OverlayLinkCapabilities.none;

    // Canonical-link tie-break: if we already hold a non-terminal
    // record for this peer node num whose `linkId` differs from the
    // incoming frame's, both sides raced `openLocal` (sim-open). Pick
    // the deterministic winner: lower `linkId` wins.
    //
    // - Incoming wins → supersede our existing record(s), accept the
    //   incoming as the responder side of the canonical link.
    // - Existing wins → silently drop the incoming LINK_OPEN. The peer
    //   will see our (lower) LINK_OPEN, apply the same rule, and
    //   converge on our record.
    //
    // Same-linkId collisions are handled earlier by the `getByLinkId`
    // check above, so `competing` only contains records with a
    // different `linkId`.
    final peerMatches = await _store.getNonTerminalForPeerNode(senderNodeNum);
    final competing = peerMatches
        .where((r) => r.linkId != frame.linkId)
        .toList();
    if (competing.isNotEmpty) {
      final existingHasLower = competing.any((r) => r.linkId < frame.linkId);
      if (existingHasLower) {
        AppLogging.overlay(
          'LINK_OPEN tie-break loss: incoming '
          'linkId=0x${frame.linkId.toRadixString(16)} yields to existing '
          '(lower linkId) for peer=$senderNodeNum',
        );
        return;
      }
      // Incoming is the new canonical. Supersede every higher-linkId
      // non-terminal record locally. No LINK_CLOSE is emitted: the
      // peer is about to see our LINK_OPEN (if it hasn't already),
      // apply the same tie-break, and discard its own loser.
      for (final c in competing) {
        final superseded = c.copyWith(
          state: OverlayLinkState.failed,
          closeReason: OverlayLinkCloseReason.collision,
          closedAtMs: now,
          lastActivityMs: now,
        );
        await _store.upsert(superseded);
        AppLogging.overlay(
          'LINK_OPEN tie-break supersede '
          'linkId=0x${c.linkId.toRadixString(16)} by incoming '
          '0x${frame.linkId.toRadixString(16)} for peer=$senderNodeNum',
        );
        _emit(
          OverlayLinkEvent(
            kind: OverlayLinkEventKind.terminated,
            record: superseded,
            detail: 'tie_break_superseded',
          ),
        );
      }
      // Fall through to the responder-accept path.
    }

    final candidate = OverlayLinkRecord(
      linkId: frame.linkId,
      peerPersonaHint: Uint8List.fromList(peerHint),
      peerNodeNum: senderNodeNum,
      state: OverlayLinkState.opening,
      isInitiator: false,
      capabilities: observedCaps,
      openedAtMs: now,
      lastActivityMs: now,
      expiresAtMs: now + OverlayLinkConstants.linkMaxLifetimeSec * 1000,
      txNextSeq: 0,
      txAckHi: 0,
      rxExpectedSeq: (frame.seq + 1) & 0xFFFF,
      retryCount: 0,
    );

    final declineReason = _acceptPolicy(candidate);
    if (declineReason != null) {
      AppLogging.overlay(
        'LINK_OPEN declined linkId=0x${frame.linkId.toRadixString(16)} '
        'reason=${declineReason.name}',
      );
      await _sendFrame(
        _newLinkFrame(
          msgType: OverlayLinkMsgType.linkOpenNo,
          record: candidate,
          payload: Uint8List.fromList(<int>[declineReason.code]),
        ),
        senderNodeNum,
      );
      _emit(
        OverlayLinkEvent(
          kind: OverlayLinkEventKind.rejected,
          record: candidate,
          detail: declineReason.name,
        ),
      );
      return;
    }

    final activated = candidate.copyWith(state: OverlayLinkState.active);
    await _store.upsert(activated);
    AppLogging.overlay(
      'LINK_OPEN accepted linkId=0x${frame.linkId.toRadixString(16)} '
      'peer=$senderNodeNum signed=${verify.body != null}',
    );
    final responseBody = await _buildSignedHandshakeBody(
      activated.capabilities,
    );
    await _sendFrame(
      _newLinkFrame(
        msgType: OverlayLinkMsgType.linkOpenOk,
        record: activated,
        payload: responseBody,
      ),
      senderNodeNum,
    );
    _emit(
      OverlayLinkEvent(kind: OverlayLinkEventKind.opened, record: activated),
    );
    _emit(
      OverlayLinkEvent(kind: OverlayLinkEventKind.activated, record: activated),
    );
    await _notifySecureActivated(activated);
  }

  Future<void> _handleLinkOpenOk(OverlayLinkFrame frame, int now) async {
    final existing = await _store.getByLinkId(frame.linkId);
    if (existing == null || existing.state != OverlayLinkState.opening) {
      AppLogging.overlay(
        'LINK_OPEN_OK dropped linkId=0x${frame.linkId.toRadixString(16)} '
        'state=${existing?.state.name}',
      );
      return;
    }

    // P3: verify signed body symmetrically with LINK_OPEN.
    final verify = await _verifyInboundHandshake(frame, existing.peerNodeNum);
    if (!verify.valid) {
      AppLogging.overlay(
        'LINK_OPEN_OK rejected linkId=0x${frame.linkId.toRadixString(16)} '
        'reason=${verify.reason?.name} detail=${verify.detail}',
      );
      final failed = existing.copyWith(
        state: OverlayLinkState.failed,
        closeReason: verify.reason ?? OverlayLinkCloseReason.authFailure,
        closedAtMs: now,
        lastActivityMs: now,
      );
      await _store.upsert(failed);
      _emit(
        OverlayLinkEvent(
          kind: OverlayLinkEventKind.terminated,
          record: failed,
          detail: 'auth:${verify.detail}',
        ),
      );
      return;
    }

    final peerHint = verify.endpoint?.personaHint ?? existing.peerPersonaHint;
    final capabilities = verify.body != null
        ? OverlayLinkCapabilities(
            supportedFeatures: verify.body!.capabilityBitset,
          )
        : existing.capabilities;
    final updated = existing.copyWith(
      state: OverlayLinkState.active,
      lastActivityMs: now,
      rxExpectedSeq: (frame.seq + 1) & 0xFFFF,
      retryCount: 0,
      capabilities: capabilities,
    );
    // `peer_persona_hint` is the only link-record field that stays
    // tied to identity. Rewrite it via a fresh record rather than
    // `copyWith` since `copyWith` does not expose that column.
    final bound = OverlayLinkRecord(
      linkId: updated.linkId,
      peerPersonaHint: Uint8List.fromList(peerHint),
      peerNodeNum: updated.peerNodeNum,
      state: updated.state,
      isInitiator: updated.isInitiator,
      capabilities: updated.capabilities,
      openedAtMs: updated.openedAtMs,
      lastActivityMs: updated.lastActivityMs,
      expiresAtMs: updated.expiresAtMs,
      txNextSeq: updated.txNextSeq,
      txAckHi: updated.txAckHi,
      rxExpectedSeq: updated.rxExpectedSeq,
      retryCount: updated.retryCount,
      closeReason: updated.closeReason,
      closedAtMs: updated.closedAtMs,
    );
    await _store.upsert(bound);
    AppLogging.overlay(
      'LINK_OPEN_OK linkId=0x${frame.linkId.toRadixString(16)} '
      'now active signed=${verify.body != null}',
    );
    _emit(
      OverlayLinkEvent(kind: OverlayLinkEventKind.activated, record: bound),
    );
    await _notifySecureActivated(bound);
  }

  Future<void> _handleLinkOpenNo(OverlayLinkFrame frame, int now) async {
    final existing = await _store.getByLinkId(frame.linkId);
    if (existing == null || existing.state != OverlayLinkState.opening) {
      return;
    }
    final reason = frame.payload.isEmpty
        ? OverlayLinkCloseReason.unsupported
        : OverlayLinkCloseReason.fromCode(frame.payload[0]) ??
              OverlayLinkCloseReason.unsupported;
    final failed = existing.copyWith(
      state: OverlayLinkState.failed,
      closeReason: reason,
      closedAtMs: now,
      lastActivityMs: now,
    );
    await _store.upsert(failed);
    AppLogging.overlay(
      'LINK_OPEN_NO linkId=0x${frame.linkId.toRadixString(16)} '
      'reason=${reason.name}',
    );
    _emit(
      OverlayLinkEvent(
        kind: OverlayLinkEventKind.terminated,
        record: failed,
        detail: reason.name,
      ),
    );
  }

  Future<void> _handleLinkPing(OverlayLinkFrame frame, int now) async {
    final existing = await _store.getByLinkId(frame.linkId);
    if (existing == null || existing.isTerminal) return;
    await _sendFrame(
      _newLinkFrame(msgType: OverlayLinkMsgType.linkPong, record: existing),
      existing.peerNodeNum,
    );
    await _refreshActivity(existing, now);
  }

  Future<void> _handleLinkPong(OverlayLinkFrame frame, int now) async {
    final existing = await _store.getByLinkId(frame.linkId);
    if (existing == null || existing.isTerminal) return;
    await _refreshActivity(existing, now);
  }

  Future<void> _handleLinkData(OverlayLinkFrame frame, int now) async {
    final existing = await _store.getByLinkId(frame.linkId);
    if (existing == null || existing.isTerminal) {
      AppLogging.overlay(
        'LINK_DATA dropped: no record for '
        'linkId=0x${frame.linkId.toRadixString(16)}',
      );
      return;
    }
    if (frame.seq != existing.rxExpectedSeq) {
      AppLogging.overlay(
        'LINK_DATA dedupe drop linkId=0x${frame.linkId.toRadixString(16)} '
        'seq=${frame.seq} expected=${existing.rxExpectedSeq}',
      );
      _emit(
        OverlayLinkEvent(
          kind: OverlayLinkEventKind.dataDropped,
          record: existing,
          detail: frame.seq < existing.rxExpectedSeq
              ? 'duplicate'
              : 'future_seq',
        ),
      );
      return;
    }
    final advanced = existing.copyWith(
      rxExpectedSeq: (frame.seq + 1) & 0xFFFF,
      lastActivityMs: now,
      state: existing.state == OverlayLinkState.stale
          ? OverlayLinkState.active
          : existing.state,
    );
    await _store.upsert(advanced);
    _emit(
      OverlayLinkEvent(
        kind: OverlayLinkEventKind.dataDelivered,
        record: advanced,
        payload: frame.payload,
      ),
    );
    if ((frame.flags & OverlayLinkFlags.ackRequired) != 0) {
      await _sendFrame(
        _newLinkFrame(msgType: OverlayLinkMsgType.linkAck, record: advanced),
        advanced.peerNodeNum,
      );
    }
  }

  Future<void> _handleLinkAck(OverlayLinkFrame frame, int now) async {
    final existing = await _store.getByLinkId(frame.linkId);
    if (existing == null || existing.isTerminal) return;
    final newAck = _ackAdvance(existing.txAckHi, frame.ackHi);
    final updated = existing.copyWith(
      txAckHi: newAck,
      lastActivityMs: now,
      state: existing.state == OverlayLinkState.stale
          ? OverlayLinkState.active
          : existing.state,
    );
    await _store.upsert(updated);
  }

  Future<void> _handleLinkClose(OverlayLinkFrame frame, int now) async {
    final existing = await _store.getByLinkId(frame.linkId);
    if (existing == null || existing.isTerminal) return;
    final reason = frame.payload.isEmpty
        ? OverlayLinkCloseReason.normal
        : OverlayLinkCloseReason.fromCode(frame.payload[0]) ??
              OverlayLinkCloseReason.normal;
    final closed = existing.copyWith(
      state: OverlayLinkState.closed,
      closeReason: reason,
      closedAtMs: now,
      lastActivityMs: now,
    );
    await _store.upsert(closed);
    AppLogging.overlay(
      'LINK_CLOSE remote linkId=0x${frame.linkId.toRadixString(16)} '
      'reason=${reason.name}',
    );
    _emit(
      OverlayLinkEvent(
        kind: OverlayLinkEventKind.terminated,
        record: closed,
        detail: reason.name,
      ),
    );
  }

  Future<void> _tickLocked() async {
    final now = _clock();
    final rows = await _store.loadNonTerminal();
    for (final r in rows) {
      // Expiry dominates all other transitions.
      if (now >= r.expiresAtMs) {
        final failed = r.copyWith(
          state: OverlayLinkState.failed,
          closeReason: OverlayLinkCloseReason.timeout,
          closedAtMs: now,
          lastActivityMs: now,
        );
        await _store.upsert(failed);
        AppLogging.overlay(
          'LINK expired linkId=0x${r.linkId.toRadixString(16)}',
        );
        _emit(
          OverlayLinkEvent(
            kind: OverlayLinkEventKind.terminated,
            record: failed,
            detail: 'expired',
          ),
        );
        continue;
      }
      final idleMs = now - r.lastActivityMs;
      final staleMs = OverlayLinkConstants.staleThresholdSec * 1000;
      if (r.state == OverlayLinkState.active && idleMs >= staleMs) {
        final staled = r.copyWith(
          state: OverlayLinkState.stale,
          lastActivityMs: r.lastActivityMs,
        );
        await _store.upsert(staled);
        AppLogging.overlay(
          'LINK stale linkId=0x${r.linkId.toRadixString(16)} '
          'idle=${idleMs}ms',
        );
        _emit(
          OverlayLinkEvent(kind: OverlayLinkEventKind.staled, record: staled),
        );
      } else if (r.state == OverlayLinkState.stale && idleMs >= 2 * staleMs) {
        final failed = r.copyWith(
          state: OverlayLinkState.failed,
          closeReason: OverlayLinkCloseReason.timeout,
          closedAtMs: now,
          lastActivityMs: now,
        );
        await _store.upsert(failed);
        AppLogging.overlay(
          'LINK stale->failed linkId=0x${r.linkId.toRadixString(16)}',
        );
        _emit(
          OverlayLinkEvent(
            kind: OverlayLinkEventKind.terminated,
            record: failed,
            detail: 'stale_timeout',
          ),
        );
      }
    }

    // GC closed/failed rows past the retention window.
    final cutoff = now - OverlayLinkConstants.closedRetentionSec * 1000;
    final pruned = await _store.pruneClosedOlderThan(cutoff);
    if (pruned > 0) {
      AppLogging.overlay('LINK GC removed $pruned closed rows');
    }
  }

  Future<void> _closeLocked(int linkId, OverlayLinkCloseReason reason) async {
    final existing = await _store.getByLinkId(linkId);
    if (existing == null || existing.isTerminal) return;
    final now = _clock();
    final closed = existing.copyWith(
      state: OverlayLinkState.closed,
      closeReason: reason,
      closedAtMs: now,
      lastActivityMs: now,
    );
    await _store.upsert(closed);
    AppLogging.overlay(
      'LINK_CLOSE local linkId=0x${linkId.toRadixString(16)} '
      'reason=${reason.name}',
    );
    await _sendFrame(
      _newLinkFrame(
        msgType: OverlayLinkMsgType.linkClose,
        record: closed,
        payload: Uint8List.fromList(<int>[reason.code]),
      ),
      closed.peerNodeNum,
    );
    _emit(
      OverlayLinkEvent(
        kind: OverlayLinkEventKind.terminated,
        record: closed,
        detail: reason.name,
      ),
    );
  }

  Future<Uint8List?> _sendDataLocked(int linkId, Uint8List payload) async {
    final existing = await _store.getByLinkId(linkId);
    if (existing == null || existing.state != OverlayLinkState.active) {
      AppLogging.overlay(
        'sendData refused linkId=0x${linkId.toRadixString(16)} '
        'state=${existing?.state.name}',
      );
      return null;
    }
    if (payload.length > OverlayLinkConstants.payloadCeilUnsigned) {
      AppLogging.overlay(
        'sendData rejected: payload=${payload.length} exceeds unsigned ceiling',
      );
      return null;
    }
    final frame = OverlayLinkFrame(
      msgType: OverlayLinkMsgType.linkData,
      flags: OverlayLinkFlags.linkFrame,
      requestId: 0,
      serviceId: 0,
      actionId: 0,
      payloadLen: payload.length,
      linkId: linkId,
      seq: existing.txNextSeq,
      ackHi: (existing.rxExpectedSeq - 1) & 0xFFFF,
      payload: payload,
    );
    final wire = OverlayLinkCodec.encode(frame);
    if (wire == null) return null;

    final delivered = await _egress.send(frame, existing.peerNodeNum);
    if (!delivered) {
      AppLogging.overlay(
        'sendData transport refused linkId=0x${linkId.toRadixString(16)}',
      );
      return null;
    }
    final now = _clock();
    final advanced = existing.copyWith(
      txNextSeq: (existing.txNextSeq + 1) & 0xFFFF,
      lastActivityMs: now,
    );
    await _store.upsert(advanced);
    return wire;
  }

  Future<void> _restoreLocked() async {
    final rows = await _store.loadAll();
    final now = _clock();
    for (final r in rows) {
      if (r.isTerminal) continue;

      if (now >= r.expiresAtMs) {
        final failed = r.copyWith(
          state: OverlayLinkState.failed,
          closeReason: OverlayLinkCloseReason.timeout,
          closedAtMs: now,
          lastActivityMs: now,
        );
        await _store.upsert(failed);
        _emit(
          OverlayLinkEvent(
            kind: OverlayLinkEventKind.restored,
            record: failed,
            detail: 'expired',
          ),
        );
        continue;
      }

      switch (r.state) {
        case OverlayLinkState.opening:
          // A half-open handshake cannot be continued across restart.
          final failed = r.copyWith(
            state: OverlayLinkState.failed,
            closeReason: OverlayLinkCloseReason.timeout,
            closedAtMs: now,
            lastActivityMs: now,
          );
          await _store.upsert(failed);
          _emit(
            OverlayLinkEvent(
              kind: OverlayLinkEventKind.restored,
              record: failed,
              detail: 'opening_abandoned',
            ),
          );
        case OverlayLinkState.active:
        case OverlayLinkState.stale:
        case OverlayLinkState.draining:
          // Per §21.1 (no-phantom-open rule): surviving records are
          // downgraded to `stale` so fresh peer traffic must re-prove
          // liveness before `active` is reasserted.
          final staled = r.copyWith(state: OverlayLinkState.stale);
          await _store.upsert(staled);
          _emit(
            OverlayLinkEvent(
              kind: OverlayLinkEventKind.restored,
              record: staled,
              detail: 'downgraded_to_stale',
            ),
          );
        case OverlayLinkState.idle:
        case OverlayLinkState.closed:
        case OverlayLinkState.failed:
          // idle is transient and should not be persisted; terminal
          // states are left alone.
          break;
      }
    }
  }

  // ---------------------------------------------------------------
  // Helpers.
  // ---------------------------------------------------------------

  Future<void> _refreshActivity(OverlayLinkRecord existing, int now) async {
    final newState = existing.state == OverlayLinkState.stale
        ? OverlayLinkState.active
        : existing.state;
    if (newState == existing.state && existing.lastActivityMs == now) return;
    final updated = existing.copyWith(lastActivityMs: now, state: newState);
    await _store.upsert(updated);
    if (newState == OverlayLinkState.active &&
        existing.state == OverlayLinkState.stale) {
      _emit(
        OverlayLinkEvent(kind: OverlayLinkEventKind.activated, record: updated),
      );
    }
  }

  OverlayLinkFrame _newLinkFrame({
    required OverlayLinkMsgType msgType,
    required OverlayLinkRecord record,
    Uint8List? payload,
    int flagsExtra = 0,
  }) {
    final body = payload ?? Uint8List(0);
    return OverlayLinkFrame(
      msgType: msgType,
      flags: OverlayLinkFlags.linkFrame | flagsExtra,
      requestId: 0,
      serviceId: 0,
      actionId: 0,
      payloadLen: body.length,
      linkId: record.linkId,
      seq: record.txNextSeq,
      ackHi: (record.rxExpectedSeq - 1) & 0xFFFF,
      payload: body,
    );
  }

  Future<bool> _sendFrame(OverlayLinkFrame frame, int peerNodeNum) async {
    if (_disposed) return false;
    try {
      return await _egress.send(frame, peerNodeNum);
    } catch (e) {
      AppLogging.overlay('egress error: $e');
      return false;
    }
  }

  /// Narrow-window forward progress for `ack_hi`.
  ///
  /// Treats [candidate] as more recent than [current] if it sits in
  /// the forward half of the 16-bit space. Mirrors the conservative
  /// P1 rule: we trust `ack_hi` only when it is monotonically ahead;
  /// wrap past the midpoint is treated as stale and ignored.
  int _ackAdvance(int current, int candidate) {
    final diff = (candidate - current) & 0xFFFF;
    if (diff == 0) return current;
    if (diff < 0x8000) return candidate;
    return current;
  }

  Uint8List _extractPeerHint(OverlayLinkFrame frame) {
    // P1 does not carry an explicit persona hint inside LINK_OPEN; the
    // 4-byte linkId plus the sender node num is sufficient scope for
    // the P1 engine. A placeholder 8-byte hint derived from the linkId
    // + sender keeps the schema column non-null until P3 (identity
    // binding) replaces it with the real persona hint.
    final out = Uint8List(8);
    final bd = ByteData.view(out.buffer);
    bd.setUint32(0, frame.linkId, Endian.little);
    bd.setUint32(4, frame.requestId, Endian.little);
    return out;
  }

  void _emit(OverlayLinkEvent event) {
    if (_events.isClosed) return;
    _events.add(event);
    // Forward terminal transitions onto the secure-session manager so
    // it can drop in-memory keys for this link. No-op when no manager
    // is attached.
    if (event.kind == OverlayLinkEventKind.terminated) {
      _secureSessionManager?.onLinkTerminated(event.record.linkId);
    }
  }

  /// Forward an `active` transition to the secure-session manager.
  /// Invoked from both `_handleLinkOpen` (responder path, direct
  /// transition to active) and `_handleLinkOpenOk` (initiator path).
  /// No-op when no manager is attached.
  Future<void> _notifySecureActivated(OverlayLinkRecord record) async {
    final mgr = _secureSessionManager;
    if (mgr == null) return;
    try {
      await mgr.onLinkActivated(record);
    } catch (e, st) {
      AppLogging.overlay(
        'SECURE onLinkActivated threw (ignored, link unaffected) '
        'linkId=0x${record.linkId.toRadixString(16)}: $e\n$st',
      );
    }
  }

  // ---------------------------------------------------------------
  // P3 handshake helpers.
  //
  // [_buildSignedHandshakeBody] produces the 110-byte signed payload
  // described in spec §24.1.1 when an endpoint manager is attached.
  // When no manager is set, returns null — the outbound frame keeps
  // the P2 empty-body shape, which a v0.2 peer still understands.
  //
  // [_verifyInboundHandshake] is the symmetric receive-side helper:
  // it decodes and verifies a signed body, records the peer's
  // endpoint observation, and returns a structured result that the
  // caller uses to decide accept/reject.
  // ---------------------------------------------------------------

  Future<Uint8List?> _buildSignedHandshakeBody(
    OverlayLinkCapabilities capabilities,
  ) async {
    final mgr = _endpointManager;
    if (mgr == null) return null;
    final signedRegion = OverlayHandshakeCodec.buildSignedRegion(
      flags: overlayHandshakeFlagCapabilityPresent,
      senderPublicKey: mgr.localPublicKey(),
      capabilityBitset: capabilities.supportedFeatures,
      nonce: OverlayHandshakeCodec.generateNonce(),
    );
    final signature = await mgr.sign(signedRegion);
    return OverlayHandshakeCodec.encode(
      signedRegion: signedRegion,
      signature: signature,
    );
  }

  Future<_HandshakeVerifyResult> _verifyInboundHandshake(
    OverlayLinkFrame frame,
    int senderNodeNum,
  ) async {
    final mgr = _endpointManager;
    // If no manager is attached, identity binding is disabled. Accept
    // regardless of payload shape — the engine behaves as it did in P2.
    if (mgr == null) return _HandshakeVerifyResult.acceptUnsigned();

    // Unsigned peers (P2 interop): empty payload → accept without
    // endpoint binding. This is the explicit "mixed signed/unsigned
    // peer rules follow spec exactly" path (§24.1.2 step 1).
    if (frame.payload.isEmpty) {
      return _HandshakeVerifyResult.acceptUnsigned();
    }

    final decoded = OverlayHandshakeCodec.decode(frame.payload);
    if (!decoded.isOk) {
      OverlayHandshakeCodec.logDecodeFailure(decoded);
      return _HandshakeVerifyResult.reject(
        OverlayLinkCloseReason.authFailure,
        'decode:${decoded.error?.name}',
      );
    }
    final body = decoded.body!;
    final signedRegion = OverlayHandshakeCodec.buildSignedRegion(
      flags: body.flags,
      senderPublicKey: body.senderPublicKey,
      capabilityBitset: body.capabilityBitset,
      nonce: body.nonce,
    );
    final sigOk = await mgr.verify(
      signedRegion,
      body.signature,
      body.senderPublicKey,
    );
    if (!sigOk) {
      return _HandshakeVerifyResult.reject(
        OverlayLinkCloseReason.authFailure,
        'signature_invalid',
      );
    }
    final endpointId = await OverlayEndpointId.deriveRoot(body.senderPublicKey);
    final record = await mgr.recordObservation(
      endpointId: endpointId,
      personaPubEd: body.senderPublicKey,
      peerNodeNum: senderNodeNum,
      supportedFeatures: body.capabilityBitset,
      trustLevel: OverlayEndpointTrustLevel.signatureVerified,
      source: OverlayEndpointObservationSource.linkFrame,
    );
    return _HandshakeVerifyResult.acceptSigned(body, record);
  }

  OverlayLinkFrame _buildRejectionFrame({
    required int linkId,
    required OverlayLinkCloseReason reason,
  }) {
    final payload = Uint8List.fromList(<int>[reason.code]);
    return OverlayLinkFrame(
      msgType: OverlayLinkMsgType.linkOpenNo,
      flags: OverlayLinkFlags.linkFrame,
      requestId: 0,
      serviceId: 0,
      actionId: 0,
      payloadLen: payload.length,
      linkId: linkId,
      seq: 0,
      ackHi: 0,
      payload: payload,
    );
  }

  OverlayLinkRecord _syntheticRejectionRecord(
    OverlayLinkFrame frame,
    int senderNodeNum,
    int now,
  ) {
    return OverlayLinkRecord(
      linkId: frame.linkId,
      peerPersonaHint: _extractPeerHint(frame),
      peerNodeNum: senderNodeNum,
      state: OverlayLinkState.failed,
      isInitiator: false,
      capabilities: OverlayLinkCapabilities.none,
      openedAtMs: now,
      lastActivityMs: now,
      expiresAtMs: now,
      txNextSeq: 0,
      txAckHi: 0,
      rxExpectedSeq: 0,
      retryCount: 0,
      closeReason: OverlayLinkCloseReason.authFailure,
      closedAtMs: now,
    );
  }
}

/// Result of [OverlayLinkEngine._verifyInboundHandshake].
class _HandshakeVerifyResult {
  /// True if the link-establishment frame should be accepted.
  final bool valid;

  /// Decoded body when the peer sent one; `null` for unsigned peers.
  final OverlayHandshakeBody? body;

  /// Persisted endpoint record for signature-verified peers; `null`
  /// for unsigned or failed verifications.
  final OverlayEndpointRecord? endpoint;

  /// Rejection reason when `valid=false`.
  final OverlayLinkCloseReason? reason;

  /// Diagnostic detail string (never null when `valid=false`).
  final String? detail;

  const _HandshakeVerifyResult._({
    required this.valid,
    this.body,
    this.endpoint,
    this.reason,
    this.detail,
  });

  factory _HandshakeVerifyResult.acceptUnsigned() =>
      const _HandshakeVerifyResult._(valid: true);

  factory _HandshakeVerifyResult.acceptSigned(
    OverlayHandshakeBody body,
    OverlayEndpointRecord endpoint,
  ) => _HandshakeVerifyResult._(valid: true, body: body, endpoint: endpoint);

  factory _HandshakeVerifyResult.reject(
    OverlayLinkCloseReason reason,
    String detail,
  ) => _HandshakeVerifyResult._(valid: false, reason: reason, detail: detail);
}
