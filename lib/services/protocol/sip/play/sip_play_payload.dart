// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'sip_play_constants.dart';

/// Decoded representation of a SIP Play v1 envelope.
///
/// Immutable. The framework never mutates an envelope after decode —
/// the engine consumes a stream of envelopes and derives game state
/// by pure replay (see [`sip_play_engine.dart`]).
///
/// `gameType` is exposed as a raw [int] so unknown / reserved codes
/// survive the codec layer without being silently coerced — the
/// engine and renderers branch on whether the registry knows the id
/// and fall back to a safe "unsupported" entry when it does not.
class SipPlayEnvelope {
  /// Wire `typeAndVersion` byte. Always [SipPlayConstants.envelopeTypeAndVersionV1]
  /// for v1; receivers MUST drop any other value at the codec layer.
  final int typeAndVersion;

  /// Raw `gameType` byte. Use [knownGameType] to resolve it to the
  /// strongly-typed [SipPlayGameType] enum, or null when unknown.
  final int gameTypeCode;

  /// Per-(sessionTag, peer pair) game id. Big-endian u16 on the wire.
  final int instanceId;

  /// Decoded action. Null on the wire is impossible — receivers
  /// reject unknown action codes at decode time. Held as the strong
  /// enum for ergonomics in the engine layer.
  final SipPlayAction action;

  /// Strict per-instance monotonic sequence. Receivers enforce
  /// `incoming.seq == currentSeq + 1` and treat anything else as a
  /// drop (duplicate / replay / out-of-order).
  final int seq;

  /// Game-specific payload bytes. May be empty (e.g. `offer`,
  /// `accept`, `decline`, `resign`). The codec validates length
  /// against the registered game's declared budget; the framework
  /// itself enforces only the absolute [SipPlayConstants.maxEnvelopeBytes]
  /// ceiling.
  final Uint8List gamePayload;

  const SipPlayEnvelope({
    required this.typeAndVersion,
    required this.gameTypeCode,
    required this.instanceId,
    required this.action,
    required this.seq,
    required this.gamePayload,
  });

  /// Resolve [gameTypeCode] to its enum, or null if the receiver does
  /// not have a registered handler. Renderers fall back to the
  /// "unsupported game" UX when this returns null.
  SipPlayGameType? get knownGameType => SipPlayGameType.fromCode(gameTypeCode);
}

/// Outcome of decoding a wire byte sequence into a [SipPlayEnvelope].
///
/// The codec never throws — every error case is reported as one of
/// the [SipPlayDecodeError] variants so receivers can drop+log
/// silently without a `try/catch` at the dispatch layer.
class SipPlayDecodeResult {
  final SipPlayEnvelope? envelope;
  final SipPlayDecodeError? error;

  const SipPlayDecodeResult.ok(SipPlayEnvelope e) : envelope = e, error = null;

  const SipPlayDecodeResult.fail(SipPlayDecodeError e)
    : envelope = null,
      error = e;

  bool get isOk => envelope != null;
}

/// Reasons a SIP Play envelope can fail to decode. None of these
/// conditions cause exceptions — receivers map them to drop+log
/// outcomes and surface a safe fallback in the UI for the unsupported
/// branches.
enum SipPlayDecodeError {
  /// Fewer than [SipPlayConstants.envelopeHeaderBytes] bytes provided.
  truncatedHeader,

  /// Header parses but the declared game-payload length plus header
  /// exceeds the per-game budget or the framework ceiling.
  payloadTooLarge,

  /// `typeAndVersion` byte was not [SipPlayConstants.envelopeTypeAndVersionV1].
  unsupportedVersion,

  /// `action` byte did not match any known [SipPlayAction] value.
  unknownAction,

  /// Game-payload bytes failed the per-game codec's own validation
  /// (e.g. TTT cell out of range). The envelope header parsed fine —
  /// only the inner payload is invalid.
  malformedGamePayload,
}
