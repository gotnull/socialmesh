// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Watch-originated send dispatch. Public watch_companion files MUST NOT
// import this file outside the composing service. The directory path
// enforces the protocol-isolation invariant; the protocol-isolation
// test fails the build if it leaks.
//
// Provider trace (call chain on the Dart side):
//
//   iOS bridge (Slice 4)
//     -> watchCompanionServiceProvider              (public)
//        -> ComposingWatchCompanionService.handleIntent
//           -> watchSendFacadeProvider              (this file, internal)
//              -> guards (feature flag, canned key, readiness, channel)
//              -> meshtasticChannelSendProvider  (this file, internal)
//                 -> protocolServiceProvider
//                    -> ProtocolService.sendMessage(text, to, channel, ...)
//                       -> _assertOperational + transport.send
//              -> meshCoreChannelSendProvider    (this file, internal)
//                 -> meshCoreSessionProvider
//                    -> meshCoreBuildSendChannelTextFrame(...)
//                    -> MeshCoreSession.sendTextMessage(...)
//                       -> MeshCoreSendRateLimiter + transport.write
//
// Both protocol paths reach the SAME entry points the on-phone composer
// uses (`ProtocolService.sendMessage`, `MeshCoreSession.sendTextMessage`)
// so readiness, consent, rate-limiting, and TX-result reporting all
// happen once, in the canonical place. The facade does not duplicate
// those gates and must never bypass them.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socialmesh/core/logging.dart';
import 'package:socialmesh/core/meshcore_constants.dart';
import 'package:socialmesh/l10n/l10n_utils.dart';
import 'package:socialmesh/models/mesh_models.dart' show Message, MessageSource;
import 'package:socialmesh/providers/app_providers.dart'
    show
        ActiveProtocol,
        activeProtocolProvider,
        messagesProvider,
        protocolServiceProvider;
import 'package:socialmesh/providers/meshcore_providers.dart'
    show meshCoreSessionProvider;
import 'package:socialmesh/services/meshcore/meshcore_send_rate_limiter.dart'
    show MeshCoreSendKind;
import 'package:socialmesh/services/meshcore/protocol/meshcore_session.dart'
    show MeshCoreTextSendResult;
import 'package:socialmesh/services/meshcore/protocol/meshcore_text_frame_builders.dart'
    show meshCoreBuildSendChannelTextFrame;

import '../models/watch_companion_canned_messages.dart';
import '../models/watch_companion_connection_state.dart';
import '../models/watch_companion_intent.dart';
import '../models/watch_companion_intent_result.dart';
import '../watch_companion_providers.dart'
    show watchCompanionFeatureFlagsProvider, watchDefaultChannelIndexProvider;
import 'watch_canned_messages_composer.dart';
import 'watch_channels_facade.dart';
import 'watch_readiness_facade.dart';

/// Function signature for issuing a Meshtastic channel-broadcast text
/// send. Allows tests to override the send call without standing up a
/// real ProtocolService instance.
typedef MeshtasticChannelSend =
    Future<int> Function({
      required String text,
      required int channelIndex,
      int? replyId,
    });

/// Function signature for issuing a MeshCore channel-broadcast text
/// send. Returns the full `MeshCoreTextSendResult` so the facade can
/// translate rate-limited / firmware-timeout outcomes into structured
/// diagnostic reasons.
typedef MeshCoreChannelSend =
    Future<MeshCoreTextSendResult> Function({
      required String text,
      required int channelIndex,
    });

/// Default Meshtastic channel-send. Reads [protocolServiceProvider] and
/// invokes the same `ProtocolService.sendMessage` entry point the phone
/// composer at `lib/features/messaging/messaging_screen.dart:1761`
/// calls for channel broadcasts. `to=0xFFFFFFFF` is the Meshtastic
/// broadcast address. `MessageSource.manual` is chosen for parity with
/// the phone composer; future work may add a dedicated
/// `MessageSource.watch` once the messages-DB attribution story is
/// settled (out of scope for this slice).
final meshtasticChannelSendProvider = Provider<MeshtasticChannelSend>((ref) {
  return ({required String text, required int channelIndex, int? replyId}) {
    final protocol = ref.read(protocolServiceProvider);
    return protocol.sendMessage(
      text: text,
      to: 0xFFFFFFFF,
      channel: channelIndex,
      wantAck: true,
      replyId: replyId,
      source: MessageSource.manual,
    );
  };
});

/// Default MeshCore channel-send. Reads [meshCoreSessionProvider],
/// builds the frame via the public helper at
/// `lib/services/meshcore/protocol/meshcore_text_frame_builders.dart`
/// (the same helper the phone composer calls), then invokes
/// `MeshCoreSession.sendTextMessage` which is rate-limiter gated.
///
/// When the session is null (transport not yet attached), surfaces a
/// `firmwareTimeout` result so the facade can map it to a clean
/// `send_failed` diagnostic without throwing.
final meshCoreChannelSendProvider = Provider<MeshCoreChannelSend>((ref) {
  return ({required String text, required int channelIndex}) async {
    final session = ref.read(meshCoreSessionProvider);
    if (session == null) {
      return MeshCoreTextSendResult.firmwareTimeout();
    }
    final timestampS = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final frame = meshCoreBuildSendChannelTextFrame(
      channelIndex: channelIndex,
      text: text,
      timestampS: timestampS,
    );
    return session.sendTextMessage(
      command: frame.command,
      payload: frame.payload,
      expectedResponse: MeshCoreResponses.ok,
      timeout: const Duration(seconds: 5),
      sendKind: MeshCoreSendKind.plainChannel,
    );
  };
});

/// The send facade itself. Single public method: [dispatch]. The
/// composing service forwards every Watch intent here.
class WatchSendFacade {
  WatchSendFacade(this._ref);

  final Ref _ref;

  Future<WatchCompanionIntentResult> dispatch(
    WatchCompanionIntent intent,
  ) async {
    AppLogging.watchCompanion(
      'intent received: type=${intent.type.name} '
      'channel=${intent.target.channelIndex} canned=${intent.payload.cannedKey} '
      'req=${intent.requestId}',
    );

    // 1. Feature flag kill switch. Master gate.
    final flags = _ref.read(watchCompanionFeatureFlagsProvider);
    if (!flags.enabled) {
      AppLogging.watchCompanion(
        'intent rejected: feature_disabled req=${intent.requestId}',
      );
      return _reject(intent, 'feature_disabled');
    }

    switch (intent.type) {
      case WatchCompanionIntentType.refreshSnapshot:
        // Refresh is an ACK-only intent. The snapshot stream rebuilds
        // automatically when any upstream provider fires, so there is
        // no work to do beyond logging and acknowledging.
        AppLogging.watchCompanion(
          'refreshSnapshot acked req=${intent.requestId}',
        );
        return _accept(intent);

      case WatchCompanionIntentType.quickMessage:
      case WatchCompanionIntentType.sendImOk:
        return _handleCannedSend(intent);
    }
  }

  Future<WatchCompanionIntentResult> _handleCannedSend(
    WatchCompanionIntent intent,
  ) async {
    // 2. Resolve the canned key. `sendImOk` is sugar for
    // `quickMessage` with `cannedKey="im_ok"`; if the payload omits a
    // key for sendImOk we substitute the canonical key. Freeform text
    // is intentionally NOT supported in v1.
    String? cannedKey = intent.payload.cannedKey;
    if (intent.type == WatchCompanionIntentType.sendImOk) {
      cannedKey = WatchCompanionCannedMessageKeys.imOk;
    }
    if (cannedKey == null ||
        !WatchCompanionCannedMessageKeys.isKnown(cannedKey)) {
      AppLogging.watchCompanion(
        'intent rejected: canned_key_unknown=$cannedKey req=${intent.requestId}',
      );
      return _reject(intent, 'canned_key_unknown');
    }

    // Body text comes from the canned-messages composer, resolved
    // against the active phone locale. Looking up by key is total
    // because we just validated the key above.
    final cannedMessages = buildCannedMessages(safeL10n());
    final text = cannedMessages.firstWhere((m) => m.key == cannedKey).label;

    // 3. Readiness gate. The phone-side protocol services also enforce
    // readiness internally (Meshtastic via `_assertOperational`, MeshCore
    // via session-null + rate-limiter), but rejecting here first keeps
    // the user-visible diagnostic clean and avoids a wasted call.
    final readiness = _ref.read(watchReadinessFacadeProvider);
    if (readiness.status != WatchCompanionConnectionStatus.ready) {
      AppLogging.watchCompanion(
        'intent rejected: readiness_not_ready '
        '(status=${readiness.status.name}) req=${intent.requestId}',
      );
      return _reject(intent, 'readiness_not_ready');
    }

    // 4. Channel resolution. Intent target wins; falls back to the
    // persisted Watch default channel if the intent did not specify
    // one.
    final defaultChannel = _ref.read(watchDefaultChannelIndexProvider);
    final channelIndex = intent.target.channelIndex ?? defaultChannel;

    // 5. Validate the chosen channel actually exists on the active
    // protocol. Watch surface lists the channels in the snapshot so a
    // mismatched index here implies a stale Watch or a snapshot
    // generated against a different protocol.
    final channels = _ref.read(watchChannelsFacadeProvider);
    if (channels.isEmpty || !channels.any((c) => c.index == channelIndex)) {
      AppLogging.watchCompanion(
        'intent rejected: channel_unavailable '
        '(requested=$channelIndex available=${channels.length}) '
        'req=${intent.requestId}',
      );
      return _reject(intent, 'channel_unavailable');
    }

    // 6. Route to protocol-specific send. The Watch UI is fully
    // protocol-neutral; the branch happens once, here, against the
    // active protocol the user has already chosen on the phone.
    final activeProtocol = _ref.read(activeProtocolProvider);
    switch (activeProtocol) {
      case ActiveProtocol.none:
        AppLogging.watchCompanion(
          'intent rejected: protocol_not_active req=${intent.requestId}',
        );
        return _reject(intent, 'protocol_not_active');

      case ActiveProtocol.meshtastic:
        // Resolve an optional reply target. Unresolvable ids degrade to a
        // plain broadcast (replyId null) rather than failing the send — the
        // user's canned message still goes out, only the threading is lost.
        final replyId = _resolveReplyId(intent.payload.replyToMessageId);
        if (intent.payload.replyToMessageId != null && replyId == null) {
          AppLogging.watchCompanion(
            'reply_unresolved_fallback: id=${intent.payload.replyToMessageId} '
            'req=${intent.requestId}',
          );
        }
        AppLogging.watchCompanion(
          'send path: meshtastic channel=$channelIndex '
          'len=${text.length} replyId=$replyId req=${intent.requestId}',
        );
        try {
          final send = _ref.read(meshtasticChannelSendProvider);
          final packetId = await send(
            text: text,
            channelIndex: channelIndex,
            replyId: replyId,
          );
          AppLogging.watchCompanion(
            'send success: meshtastic packetId=$packetId req=${intent.requestId}',
          );
          return _accept(intent);
        } catch (e) {
          AppLogging.watchCompanion(
            'send failure: meshtastic error=$e req=${intent.requestId}',
          );
          return _reject(intent, 'send_failed:${e.runtimeType}');
        }

      case ActiveProtocol.meshcore:
        // MeshCore has no wire-level reply concept. A reply intent degrades
        // to a normal channel broadcast — never fake threading via text.
        if (intent.payload.replyToMessageId != null) {
          AppLogging.watchCompanion(
            'reply_dropped_meshcore: id=${intent.payload.replyToMessageId} '
            'req=${intent.requestId}',
          );
        }
        AppLogging.watchCompanion(
          'send path: meshcore channel=$channelIndex '
          'len=${text.length} req=${intent.requestId}',
        );
        try {
          final send = _ref.read(meshCoreChannelSendProvider);
          final result = await send(text: text, channelIndex: channelIndex);
          if (result.rateLimited) {
            AppLogging.watchCompanion(
              'send rate-limited: meshcore nextSendIn=${result.nextSendIn} '
              'req=${intent.requestId}',
            );
            return _reject(intent, 'rate_limited');
          }
          if (result.firmwareTimeout) {
            AppLogging.watchCompanion(
              'send timeout: meshcore (no firmware ack) req=${intent.requestId}',
            );
            return _reject(intent, 'firmware_timeout');
          }
          AppLogging.watchCompanion(
            'send success: meshcore req=${intent.requestId}',
          );
          return _accept(intent);
        } catch (e) {
          AppLogging.watchCompanion(
            'send failure: meshcore error=$e req=${intent.requestId}',
          );
          return _reject(intent, 'send_failed:${e.runtimeType}');
        }
    }
  }

  /// Resolve a Watch-supplied reply-target id (the inbox row's wire-stable
  /// `id`) to a Meshtastic packet id. Tries the live message store first, then
  /// falls back to parsing the `pkt-<fromHex>-<pktHex>` deterministic-id form
  /// (see [Message.deterministicId]). Returns null when unresolvable.
  int? _resolveReplyId(String? replyToMessageId) {
    if (replyToMessageId == null || replyToMessageId.isEmpty) return null;

    final messages = _ref.read(messagesProvider);
    for (final m in messages) {
      if (m.id == replyToMessageId && m.packetId != null) {
        return m.packetId;
      }
    }

    // Fallback: parse `pkt-<fromHex>-<pktHex>`; the trailing segment is the
    // packet id in hex. Tolerates messages aged out of the in-memory store.
    final parts = replyToMessageId.split('-');
    if (parts.length == 3 && parts[0] == 'pkt') {
      final pkt = int.tryParse(parts[2], radix: 16);
      if (pkt != null && pkt != 0) return pkt;
    }
    return null;
  }

  WatchCompanionIntentResult _accept(WatchCompanionIntent intent) {
    return WatchCompanionIntentResult(
      requestId: intent.requestId,
      accepted: true,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  WatchCompanionIntentResult _reject(
    WatchCompanionIntent intent,
    String diagnosticReason,
  ) {
    return WatchCompanionIntentResult(
      requestId: intent.requestId,
      accepted: false,
      diagnosticReason: diagnosticReason,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
    );
  }
}

/// Provider handle for the [WatchSendFacade]. Consumed by the composing
/// service so all intent dispatch flows through one place.
final watchSendFacadeProvider = Provider<WatchSendFacade>((ref) {
  return WatchSendFacade(ref);
});
