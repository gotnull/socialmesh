// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D48-A2: auto-route rotation orchestrator. Wraps a single outbound
// contact DM in a retry loop that:
//
//   1. consults `MeshCorePathHistoryStore` for saved paths,
//   2. ranks them via `selectPathForAttempt`,
//   3. writes the chosen bytes (or pathLen=-1 flood) into the
//      contact's `out_path` via `CMD_ADD_UPDATE_CONTACT 0x09`,
//   4. issues `CMD_SEND_TXT_MSG 0x02` with an incrementing `attempt`
//      byte,
//   5. registers the expected ack-hash with
//      `MeshCoreSendConfirmationRouter` and waits up to
//      `settings.retryTimeoutSeconds` for a `0x82` delivery push,
//   6. on success: bumps the path's `routeWeight` via
//      `weightAfterSuccess` and calls `recordPathSuccess`,
//   7. on timeout: penalizes via `weightAfterFailure` and calls
//      `recordPathFailure` (which evicts at weight <= 0),
//   8. loops up to `settings.maxRetries` attempts; the last attempt
//      is always flood so the message gets one final opportunity to
//      deliver.
//
// Off-state behaviour: when `settings.enabled` is false the
// orchestrator is bypassed entirely by the chat-screen gate — this
// service is never instantiated. Always-on flood remains the default.
//
// Threading: the orchestrator is single-shot per call. The chat
// screen creates one instance per outbound message (or uses a
// provider-owned singleton — either is fine because state lives in
// local fields on the call frame).
//
// Privacy: never logs raw path bytes. Counters that surface attempt
// number / weight delta / decision are fine.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../../core/logging.dart';
import '../../../core/meshcore_constants.dart';
import '../../../models/meshcore_auto_route_settings.dart';
import '../meshcore_send_rate_limiter.dart';
import '../protocol/meshcore_session.dart';
import '../storage/meshcore_path_history_store.dart';
import 'meshcore_path_selector.dart';
import 'meshcore_send_confirmation_router.dart';

/// D48-A2: outcome of a full retry-loop send. The chat screen uses
/// the discriminant to mark the message sent / failed and surface
/// attempt count in diagnostics.
class MeshCoreAutoRouteSendOutcome {
  /// `true` if any attempt's 0x82 push arrived within timeout.
  final bool delivered;

  /// Number of attempts actually issued (1..maxRetries).
  final int attempts;

  /// Bytes of the path that delivered (null = delivered on flood, or
  /// the loop exhausted without delivery).
  final Uint8List? deliveredPath;

  /// Round-trip time on the successful attempt; null on failure.
  final Duration? tripTime;

  /// Discriminates why a non-delivered outcome bailed out. `null`
  /// when `delivered` is true.
  final MeshCoreAutoRouteFailureReason? failureReason;

  const MeshCoreAutoRouteSendOutcome({
    required this.delivered,
    required this.attempts,
    this.deliveredPath,
    this.tripTime,
    this.failureReason,
  });
}

enum MeshCoreAutoRouteFailureReason {
  /// All attempts (including the final flood) timed out waiting for
  /// 0x82 delivery confirmation.
  allAttemptsTimedOut,

  /// Host-side rate limiter rejected an attempt mid-loop. The chat
  /// screen surfaces the rate-limit countdown.
  rateLimited,

  /// The firmware refused the send (sync ack never landed). Hard
  /// failure for the current attempt; loop bails out.
  firmwareSendRejected,
}

/// D48-A2: pure-Dart frame builder for `CMD_SEND_TXT_MSG 0x02`. Kept
/// here (rather than in the chat screen) so the orchestrator can
/// inject an `attempt` byte per retry without round-tripping through
/// the UI layer.
///
/// Wire format (must match the firmware's parser byte-for-byte):
///   [0]      txt_type = 0 (plain)
///   [1]      attempt (orchestrator bumps each retry)
///   [2..6]   timestamp_seconds (u32 LE)
///   [6..12]  recipient pub-key prefix (6 B)
///   [12..]   utf-8 text bytes
///   [last]   trailing NUL
Uint8List buildSendTextMsgPayload({
  required Uint8List recipientPubKey,
  required String text,
  required int timestampSeconds,
  required int attempt,
}) {
  final builder = BytesBuilder();
  builder.addByte(0); // txt_type = plain
  builder.addByte(attempt & 0xFF);
  builder.addByte(timestampSeconds & 0xFF);
  builder.addByte((timestampSeconds >> 8) & 0xFF);
  builder.addByte((timestampSeconds >> 16) & 0xFF);
  builder.addByte((timestampSeconds >> 24) & 0xFF);
  builder.add(recipientPubKey.sublist(0, 6));
  builder.add(utf8.encode(text));
  builder.addByte(0);
  return builder.toBytes();
}

/// D48-A2: function signature for the `CMD_ADD_UPDATE_CONTACT 0x09`
/// dependency. Mirrors `MeshCoreSession.addUpdateContact` but
/// narrowed to the fields the orchestrator drives. Extracted so the
/// orchestrator is testable without mocking a full session.
typedef MeshCoreAddUpdateContactCall =
    Future<bool> Function({
      required Uint8List pubKey,
      required int advType,
      required String name,
      required int pathLength,
      required Uint8List pathBytes,
    });

/// D48-A2: function signature for the `CMD_SEND_TXT_MSG 0x02`
/// dependency. Mirrors `MeshCoreSession.sendTextMessage` but only
/// the inputs the orchestrator drives. Defaults the timeout to the
/// 5 s sync-ack window inside the session.
typedef MeshCoreSendTextMessageCall =
    Future<MeshCoreTextSendResult> Function({
      required int command,
      required Uint8List payload,
      required int expectedResponse,
      required MeshCoreSendKind sendKind,
    });

/// D48-A2: bound to one outbound contact DM. Construct, call
/// [sendWithAutoRoute], read the outcome, discard.
class MeshCoreAutoRouteOrchestrator {
  MeshCoreAutoRouteOrchestrator({
    required MeshCoreSession session,
    required this.pathHistoryStore,
    required this.confirmationRouter,
    required this.settings,
    required this.devicePubKey,
    required this.contactPubKey,
    required this.contactAdvType,
    required this.contactName,
    DateTime Function()? clock,
  }) : _addUpdateContact = session.addUpdateContact,
       _sendTextMessage = _bindSendTextMessage(session),
       _clock = clock ?? DateTime.now;

  /// Test-only constructor that lets the caller drive
  /// `addUpdateContact` and `sendTextMessage` directly (no real
  /// session needed).
  @visibleForTesting
  MeshCoreAutoRouteOrchestrator.forTest({
    required MeshCoreAddUpdateContactCall addUpdateContact,
    required MeshCoreSendTextMessageCall sendTextMessage,
    required this.pathHistoryStore,
    required this.confirmationRouter,
    required this.settings,
    required this.devicePubKey,
    required this.contactPubKey,
    required this.contactAdvType,
    required this.contactName,
    DateTime Function()? clock,
  }) : _addUpdateContact = addUpdateContact,
       _sendTextMessage = sendTextMessage,
       _clock = clock ?? DateTime.now;

  final MeshCoreAddUpdateContactCall _addUpdateContact;
  final MeshCoreSendTextMessageCall _sendTextMessage;
  final MeshCorePathHistoryStore pathHistoryStore;
  final MeshCoreSendConfirmationRouter confirmationRouter;
  final MeshCoreAutoRouteSettings settings;

  static MeshCoreSendTextMessageCall _bindSendTextMessage(
    MeshCoreSession session,
  ) {
    return ({
      required int command,
      required Uint8List payload,
      required int expectedResponse,
      required MeshCoreSendKind sendKind,
    }) {
      return session.sendTextMessage(
        command: command,
        payload: payload,
        expectedResponse: expectedResponse,
        sendKind: sendKind,
      );
    };
  }

  /// Our own 32-byte public key. Folded into the ack-hash so the
  /// firmware's `expected_ack_table` matches.
  final Uint8List devicePubKey;

  /// 32-byte public key of the recipient.
  final Uint8List contactPubKey;

  /// `MeshCoreContact.type` / `MeshCoreContactInfo.advType` — needed
  /// by `CMD_ADD_UPDATE_CONTACT 0x09` per attempt.
  final int contactAdvType;

  /// Display name of the recipient. The wire frame echoes this back
  /// as-is so we must pass the canonical 32-byte name string.
  final String contactName;

  final DateTime Function() _clock;

  /// Drive the retry loop for one outbound message.
  Future<MeshCoreAutoRouteSendOutcome> sendWithAutoRoute({
    required String text,
    required int timestampSeconds,
    required MeshCoreSendKind sendKind,
  }) async {
    final devicePrefix = _hexPrefix(devicePubKey, 8);
    final contactPrefix = _hexPrefix(contactPubKey, 8);

    final history = await pathHistoryStore.load(devicePrefix, contactPrefix);
    final recentSelections = <Uint8List>[];
    final maxAttempts = settings.maxRetries;

    for (var attemptIndex = 0; attemptIndex < maxAttempts; attemptIndex++) {
      // Pick the path bytes for this attempt. null = flood fallback.
      final selected = selectPathForAttempt(
        history: history,
        attemptIndex: attemptIndex,
        maxAttempts: maxAttempts,
        recentSelections: recentSelections,
        settings: settings,
        now: _clock(),
      );

      // Write the contact's out_path before sending. Flood = -1.
      final pathLen = selected == null ? -1 : selected.length;
      final pathBytes = selected ?? Uint8List(0);

      final wroteContact = await _addUpdateContact(
        pubKey: contactPubKey,
        advType: contactAdvType,
        name: contactName,
        pathLength: pathLen,
        pathBytes: pathBytes,
      );
      if (!wroteContact) {
        AppLogging.meshcore(
          'event=auto_route.attempt.addupdate_failed '
          'attempt=$attemptIndex '
          'contact=${AppLogging.publicKeyFingerprint(contactPubKey)}',
          error: true,
        );
        return MeshCoreAutoRouteSendOutcome(
          delivered: false,
          attempts: attemptIndex + 1,
          failureReason: MeshCoreAutoRouteFailureReason.firmwareSendRejected,
        );
      }

      // Compute the expected ack-hash for this attempt's wire frame
      // and register the waiter BEFORE we hit `send` so we never miss
      // a fast-arriving 0x82.
      final ackHash = computeExpectedAckHash(
        timestampSeconds: timestampSeconds,
        attempt: attemptIndex,
        text: text,
        senderPubKey: devicePubKey,
      );

      final waitFuture = confirmationRouter.waitForDelivery(
        ackHash: ackHash,
        timeout: Duration(seconds: settings.retryTimeoutSeconds),
      );

      // Issue the send. The session's rate limiter + sync-ack waiter
      // run inside `sendTextMessage`.
      final wirePayload = buildSendTextMsgPayload(
        recipientPubKey: contactPubKey,
        text: text,
        timestampSeconds: timestampSeconds,
        attempt: attemptIndex,
      );

      final sendResult = await _sendTextMessage(
        command: MeshCoreCommands.sendTxtMsg,
        payload: wirePayload,
        expectedResponse: MeshCoreResponses.sent,
        sendKind: sendKind,
      );

      if (sendResult.rateLimited) {
        AppLogging.meshcore(
          'event=auto_route.attempt.rate_limited '
          'attempt=$attemptIndex '
          'wait_ms=${sendResult.nextSendIn?.inMilliseconds}',
        );
        return MeshCoreAutoRouteSendOutcome(
          delivered: false,
          attempts: attemptIndex + 1,
          failureReason: MeshCoreAutoRouteFailureReason.rateLimited,
        );
      }

      if (sendResult.firmwareTimeout) {
        AppLogging.meshcore(
          'event=auto_route.attempt.firmware_timeout '
          'attempt=$attemptIndex '
          'path_idx=${selected == null ? "flood" : "saved"}',
          error: true,
        );
        // Treat as a failed attempt against the chosen path. Continue
        // the loop so we can fall through to flood on the final pass.
        await _recordFailureFor(selected, history, devicePrefix, contactPrefix);
        if (selected != null) {
          recentSelections.add(selected);
        }
        continue;
      }

      // Sync ack landed. Wait for the routed delivery push.
      final outcome = await waitFuture;
      if (outcome.delivered) {
        AppLogging.meshcore(
          'event=auto_route.attempt.delivered '
          'attempt=$attemptIndex '
          'path_idx=${selected == null ? "flood" : "saved"} '
          'trip_ms=${outcome.tripTime?.inMilliseconds}',
        );
        if (selected != null) {
          await _recordSuccessFor(
            selected,
            history,
            devicePrefix,
            contactPrefix,
          );
        }
        return MeshCoreAutoRouteSendOutcome(
          delivered: true,
          attempts: attemptIndex + 1,
          deliveredPath: selected,
          tripTime: outcome.tripTime,
        );
      }

      // No 0x82 within the retry window. Penalize the path (if any)
      // and continue.
      AppLogging.meshcore(
        'event=auto_route.attempt.delivery_timeout '
        'attempt=$attemptIndex '
        'path_idx=${selected == null ? "flood" : "saved"}',
        error: true,
      );
      await _recordFailureFor(selected, history, devicePrefix, contactPrefix);
      if (selected != null) {
        recentSelections.add(selected);
      }
    }

    AppLogging.meshcore(
      'event=auto_route.exhausted '
      'attempts=$maxAttempts '
      'contact=${AppLogging.publicKeyFingerprint(contactPubKey)}',
      error: true,
    );
    return MeshCoreAutoRouteSendOutcome(
      delivered: false,
      attempts: maxAttempts,
      failureReason: MeshCoreAutoRouteFailureReason.allAttemptsTimedOut,
    );
  }

  Future<void> _recordSuccessFor(
    Uint8List selected,
    List<MeshCorePathHistoryEntry> history,
    String devicePrefix,
    String contactPrefix,
  ) async {
    final entry = _findEntry(history, selected);
    if (entry == null) return;
    final next = weightAfterSuccess(entry.routeWeight, settings);
    await pathHistoryStore.recordPathSuccess(
      devicePubKeyPrefix: devicePrefix,
      contactPubKeyPrefix: contactPrefix,
      pathBytes: selected,
      newWeight: next,
      now: _clock(),
    );
  }

  Future<void> _recordFailureFor(
    Uint8List? selected,
    List<MeshCorePathHistoryEntry> history,
    String devicePrefix,
    String contactPrefix,
  ) async {
    if (selected == null) return;
    final entry = _findEntry(history, selected);
    if (entry == null) return;
    final next = weightAfterFailure(entry.routeWeight, settings);
    await pathHistoryStore.recordPathFailure(
      devicePubKeyPrefix: devicePrefix,
      contactPubKeyPrefix: contactPrefix,
      pathBytes: selected,
      newWeight: next,
    );
  }

  static MeshCorePathHistoryEntry? _findEntry(
    List<MeshCorePathHistoryEntry> history,
    Uint8List bytes,
  ) {
    for (final entry in history) {
      if (entry.bytes.length != bytes.length) continue;
      var match = true;
      for (var i = 0; i < bytes.length; i++) {
        if (entry.bytes[i] != bytes[i]) {
          match = false;
          break;
        }
      }
      if (match) return entry;
    }
    return null;
  }

  static String _hexPrefix(Uint8List bytes, int byteCount) {
    final n = bytes.length < byteCount ? bytes.length : byteCount;
    final buf = StringBuffer();
    for (var i = 0; i < n; i++) {
      buf.write(bytes[i].toRadixString(16).padLeft(2, '0'));
    }
    return buf.toString();
  }
}
