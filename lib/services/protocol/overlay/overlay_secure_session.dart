// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Overlay v0.3 secure-session state machine.
///
/// One [OverlaySecureSession] instance per canonical overlay link.
/// Owns the ephemeral X25519 keypair, drives the 2-message handshake
/// (INIT / ACK), derives per-direction AEAD keys and nonce epochs via
/// HKDF-SHA256, wraps outbound DATA frames with
/// ChaCha20-Poly1305, unwraps inbound DATA frames with replay-window
/// protection, and does all of it while holding the invariants
/// documented in `docs/sip/OVERLAY_V0_2.md §25`.
///
/// Lifetime = canonical link lifetime. When the link reopens, the
/// engine discards the old session and builds a new one; there is no
/// in-session rekey in Phase 1.
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../../core/logging.dart';
import 'overlay_secure_codec.dart';
import 'overlay_types.dart';

/// Lifecycle states for an [OverlaySecureSession].
enum OverlaySecureSessionState {
  /// Local side has sent INIT; awaiting ACK from peer.
  awaitingAck,

  /// Local side is responder; received INIT, sent ACK, now holds keys.
  established,

  /// Initiator received a valid ACK; keys installed.
  // (alias kept separate from responder's `established` only for
  //  log clarity — both roles behave identically after this point).
  active,

  /// Terminal: handshake failed (signature, length, timeout, etc.).
  /// The associated link MUST remain usable for non-secure features.
  unavailable,
}

/// HKDF info labels. Must match `OVERLAY_V0_2.md §25.4` byte-for-byte.
const _hkdfInfoKeyI2R = 'socialmesh/overlay-v0.3/secure/i2r';
const _hkdfInfoKeyR2I = 'socialmesh/overlay-v0.3/secure/r2i';
const _hkdfInfoEpochI2R = 'socialmesh/overlay-v0.3/secure/epoch/i2r';
const _hkdfInfoEpochR2I = 'socialmesh/overlay-v0.3/secure/epoch/r2i';

/// Size of the replay sliding window (bits). Matches §25.6.
const int _replayWindowBits = 64;

/// Injectable entropy source. Tests pass a fixed-seed [Random] so
/// nonces and ephemeral keys are reproducible.
typedef SecureRandomBytes = Uint8List Function(int length);

Uint8List _defaultRandomBytes(int length) {
  final rnd = Random.secure();
  final out = Uint8List(length);
  for (var i = 0; i < length; i++) {
    out[i] = rnd.nextInt(256);
  }
  return out;
}

/// Outcome of a `wrap` call.
class OverlaySecureWrapResult {
  final Uint8List payload;
  final int seq;
  const OverlaySecureWrapResult({required this.payload, required this.seq});
}

/// Outcome of an `unwrap` call — either cleartext or a reason bucket
/// the caller can surface to counters.
enum OverlaySecureUnwrapReason {
  /// Session is not yet established.
  notEstablished,

  /// Payload was too short / malformed.
  malformed,

  /// Subtype byte was outside the known set. Strictly dropped.
  unknownSubtype,

  /// AEAD tag failed — tampered, wrong key, or AAD mismatch.
  tamper,

  /// `seq` was a duplicate or older than the sliding window.
  replay,
}

class OverlaySecureUnwrapResult {
  final Uint8List? cleartext;
  final OverlaySecureDataSubtype? subtype;
  final int? seq;
  final OverlaySecureUnwrapReason? failure;

  const OverlaySecureUnwrapResult.ok({
    required Uint8List this.cleartext,
    required this.subtype,
    required this.seq,
  }) : failure = null;

  const OverlaySecureUnwrapResult.fail(OverlaySecureUnwrapReason this.failure)
    : cleartext = null,
      subtype = null,
      seq = null;

  bool get ok => failure == null;
}

/// A single direction's replay-protection state: highest `seq` seen
/// plus a 64-bit sliding window.
class _ReplayWindow {
  int _hi = -1;
  int _bitmap = 0; // bit 0 = hi, bit 1 = hi-1, ..., bit 63 = hi-63

  /// Try to accept [seq]. Returns true if accepted (and the window is
  /// updated); false on duplicate or too-old.
  bool accept(int seq) {
    if (_hi < 0) {
      _hi = seq;
      _bitmap = 1;
      return true;
    }
    if (seq > _hi) {
      final shift = seq - _hi;
      if (shift >= _replayWindowBits) {
        _bitmap = 1;
      } else {
        _bitmap = ((_bitmap << shift) | 1) & ((1 << _replayWindowBits) - 1);
      }
      _hi = seq;
      return true;
    }
    final offset = _hi - seq;
    if (offset >= _replayWindowBits) return false; // too old
    final mask = 1 << offset;
    if ((_bitmap & mask) != 0) return false; // duplicate
    _bitmap |= mask;
    return true;
  }
}

/// Overlay v0.3 secure-session driver. One per canonical overlay link.
///
/// Construct with role (`initiator: true` on the side that sent the
/// first LINK_OPEN) + the local Ed25519 signer + the peer's Ed25519
/// public key (already verified via LINK_OPEN / LINK_OPEN_OK). The
/// rest of the state flows through `start`, `handleInit`, and
/// `handleAck`.
class OverlaySecureSession {
  /// Current wire schema. Sessions started under a different version
  /// MUST NOT interoperate.
  static const int protocolVersion = overlaySecureSchemaVersion;

  final int linkId;
  final Uint8List initEndpointId;
  final Uint8List respEndpointId;
  final Uint8List localPersonaPubEd;
  final Uint8List peerPersonaPubEd;
  final Future<Uint8List> Function(Uint8List message) sign;
  final bool initiator;
  final SecureRandomBytes _random;

  OverlaySecureSessionState _state = OverlaySecureSessionState.unavailable;
  OverlaySecureSessionState get state => _state;

  /// True once AEAD keys have been derived (either side).
  bool get isEstablished =>
      _state == OverlaySecureSessionState.active ||
      _state == OverlaySecureSessionState.established;

  // Ephemeral keypair — generated on start.
  SimpleKeyPair? _myEphemeralKp;
  Uint8List? _myX25519Pub;
  Uint8List? _peerX25519Pub;
  Uint8List? _myNonce;
  Uint8List? _peerNonce;

  // Derived key/epoch state.
  SecretKey? _kI2R;
  SecretKey? _kR2I;
  int _epochI2R = 0;
  int _epochR2I = 0;

  // Outbound counter per direction. Each side writes on one and reads
  // the other; the helpers below resolve direction by role.
  int _txSeq = 0;
  final _ReplayWindow _rxWindow = _ReplayWindow();

  /// Highest sequence number the u32 nonce field can carry. Reusing a
  /// deterministic nonce under the same key is catastrophic for the
  /// AEAD, so the counter must never wrap; at exhaustion the session
  /// is discarded and the next outbound renegotiates fresh keys.
  static const int maxTxSeq = 0xFFFFFFFF;

  /// Whether the outbound counter is spent. [wrap] throws past this
  /// point; callers should drop the session instead of sending.
  bool get isSeqExhausted => _txSeq > maxTxSeq;

  /// Test-only: position the outbound counter to exercise exhaustion.
  @visibleForTesting
  void debugSetTxSeq(int value) {
    _txSeq = value;
  }

  OverlaySecureSession({
    required this.linkId,
    required this.initEndpointId,
    required this.respEndpointId,
    required this.localPersonaPubEd,
    required this.peerPersonaPubEd,
    required this.sign,
    required this.initiator,
    SecureRandomBytes? random,
  }) : _random = random ?? _defaultRandomBytes;

  // -----------------------------------------------------------------
  // Handshake
  // -----------------------------------------------------------------

  /// Initiator: produce the `LINK_SECURE_INIT` payload to send.
  /// Transitions state to [OverlaySecureSessionState.awaitingAck].
  Future<Uint8List> start() async {
    if (!initiator) {
      throw StateError('start() may only be called on the initiator side');
    }
    if (_state != OverlaySecureSessionState.unavailable) {
      throw StateError('start() called in state=$_state');
    }
    await _generateEphemeral();
    _myNonce = _random(16);

    final transcript = OverlaySecureCodec.buildTranscriptInit(
      version: protocolVersion,
      linkId: linkId,
      initEndpointId: initEndpointId,
      respEndpointId: respEndpointId,
      initX25519Pub: _myX25519Pub!,
      nonceI: _myNonce!,
    );
    final sig = await sign(transcript);

    _state = OverlaySecureSessionState.awaitingAck;
    AppLogging.overlay(
      'SECURE_INIT built linkId=0x${linkId.toRadixString(16)} '
      'epId=${_hex(initEndpointId)}',
    );
    return OverlaySecureCodec.encodeInit(
      version: protocolVersion,
      initEndpointId: initEndpointId,
      initX25519Pub: _myX25519Pub!,
      nonceI: _myNonce!,
      signature: sig,
    );
  }

  /// Responder: ingest an inbound INIT payload and build the ACK to
  /// return. On signature failure / version mismatch returns null and
  /// transitions to [OverlaySecureSessionState.unavailable].
  Future<Uint8List?> handleInit(Uint8List initPayload) async {
    if (initiator) {
      throw StateError('handleInit() may only be called on the responder side');
    }
    if (_state != OverlaySecureSessionState.unavailable) {
      return _fail('handleInit in state=$_state');
    }

    final init = OverlaySecureCodec.decodeInit(initPayload);
    if (init == null) return _fail('INIT decode');
    if (init.version != protocolVersion) {
      return _fail('INIT version=${init.version}');
    }

    // Bind the payload's claimed init endpoint to our cached peer ID.
    if (!_constTimeEq(init.initEndpointId, initEndpointId)) {
      return _fail('INIT init_ep_id mismatch');
    }

    // Verify the initiator's signature over the initiator-side
    // transcript.
    final transcriptInit = OverlaySecureCodec.buildTranscriptInit(
      version: protocolVersion,
      linkId: linkId,
      initEndpointId: initEndpointId,
      respEndpointId: respEndpointId,
      initX25519Pub: init.initX25519Pub,
      nonceI: init.nonceI,
    );
    final sigOk = await _verifyEd25519(
      message: transcriptInit,
      signature: init.signature,
      publicKey: peerPersonaPubEd,
    );
    if (!sigOk) return _fail('INIT signature');

    // Cache peer contributions.
    _peerX25519Pub = init.initX25519Pub;
    _peerNonce = init.nonceI;

    // Generate responder's ephemeral + nonce.
    await _generateEphemeral();
    _myNonce = _random(16);

    // Build full transcript (both sides now known) and sign.
    final transcriptFull = OverlaySecureCodec.buildTranscriptFull(
      version: protocolVersion,
      linkId: linkId,
      initEndpointId: initEndpointId,
      respEndpointId: respEndpointId,
      initX25519Pub: _peerX25519Pub!,
      respX25519Pub: _myX25519Pub!,
      nonceI: _peerNonce!,
      nonceR: _myNonce!,
    );
    final sig = await sign(transcriptFull);

    // Derive keys + install session state.
    await _installKeys(transcriptFull);

    _state = OverlaySecureSessionState.established;
    AppLogging.overlay(
      'SECURE_ACK built linkId=0x${linkId.toRadixString(16)} '
      'epId=${_hex(respEndpointId)}',
    );
    return OverlaySecureCodec.encodeAck(
      version: protocolVersion,
      respEndpointId: respEndpointId,
      respX25519Pub: _myX25519Pub!,
      nonceR: _myNonce!,
      signature: sig,
    );
  }

  /// Initiator: ingest the peer's ACK payload. Returns true if keys
  /// were installed and the session became active; false on any
  /// verify failure (state moves to
  /// [OverlaySecureSessionState.unavailable]).
  Future<bool> handleAck(Uint8List ackPayload) async {
    if (!initiator) {
      throw StateError('handleAck() may only be called on the initiator side');
    }
    if (_state != OverlaySecureSessionState.awaitingAck) {
      _fail('handleAck in state=$_state');
      return false;
    }

    final ack = OverlaySecureCodec.decodeAck(ackPayload);
    if (ack == null) {
      _fail('ACK decode');
      return false;
    }
    if (ack.version != protocolVersion) {
      _fail('ACK version=${ack.version}');
      return false;
    }
    if (!_constTimeEq(ack.respEndpointId, respEndpointId)) {
      _fail('ACK resp_ep_id mismatch');
      return false;
    }

    // Reconstruct full transcript and verify responder's signature.
    final transcriptFull = OverlaySecureCodec.buildTranscriptFull(
      version: protocolVersion,
      linkId: linkId,
      initEndpointId: initEndpointId,
      respEndpointId: respEndpointId,
      initX25519Pub: _myX25519Pub!,
      respX25519Pub: ack.respX25519Pub,
      nonceI: _myNonce!,
      nonceR: ack.nonceR,
    );
    final sigOk = await _verifyEd25519(
      message: transcriptFull,
      signature: ack.signature,
      publicKey: peerPersonaPubEd,
    );
    if (!sigOk) {
      _fail('ACK signature');
      return false;
    }

    _peerX25519Pub = ack.respX25519Pub;
    _peerNonce = ack.nonceR;

    await _installKeys(transcriptFull);
    _state = OverlaySecureSessionState.active;
    AppLogging.overlay(
      'SECURE_ACTIVE linkId=0x${linkId.toRadixString(16)} initiator',
    );
    return true;
  }

  // -----------------------------------------------------------------
  // Data wrap / unwrap
  // -----------------------------------------------------------------

  /// Encrypt [cleartext] under the local outbound key and return the
  /// encoded `LINK_SECURE_DATA` payload ready for the engine to send.
  Future<OverlaySecureWrapResult> wrap({
    required Uint8List cleartext,
    OverlaySecureDataSubtype subtype = OverlaySecureDataSubtype.generic,
  }) async {
    if (!isEstablished) {
      throw StateError('wrap() before session established');
    }
    final seq = _txSeq;
    if (seq > maxTxSeq) {
      throw StateError('wrap() seq counter exhausted (u32)');
    }
    _txSeq = seq + 1;

    final key = initiator ? _kI2R! : _kR2I!;
    final epoch = initiator ? _epochI2R : _epochR2I;
    final nonce = OverlaySecureCodec.buildAeadNonce(epochDir: epoch, seq: seq);
    final aad = OverlaySecureCodec.buildAead(
      subtype: subtype.code,
      linkId: linkId,
      seq: seq,
      initEndpointId: initEndpointId,
      respEndpointId: respEndpointId,
    );

    final box = await Chacha20.poly1305Aead().encrypt(
      cleartext,
      secretKey: key,
      nonce: nonce,
      aad: aad,
    );

    final payload = OverlaySecureCodec.encodeData(
      subtype: subtype.code,
      seq: seq,
      aeadTag: Uint8List.fromList(box.mac.bytes),
      ciphertext: Uint8List.fromList(box.cipherText),
    );
    return OverlaySecureWrapResult(payload: payload, seq: seq);
  }

  /// Decrypt an inbound `LINK_SECURE_DATA` payload. Every failure path
  /// surfaces a reason — callers increment the matching counter and
  /// MUST NOT close the link.
  Future<OverlaySecureUnwrapResult> unwrap(Uint8List dataPayload) async {
    if (!isEstablished) {
      return const OverlaySecureUnwrapResult.fail(
        OverlaySecureUnwrapReason.notEstablished,
      );
    }
    final data = OverlaySecureCodec.decodeData(dataPayload);
    if (data == null) {
      return const OverlaySecureUnwrapResult.fail(
        OverlaySecureUnwrapReason.malformed,
      );
    }
    if (data.subtype == null) {
      AppLogging.overlay(
        'SECURE_DATA unknown subtype=0x${data.rawSubtype.toRadixString(16)} '
        'linkId=0x${linkId.toRadixString(16)}',
      );
      return const OverlaySecureUnwrapResult.fail(
        OverlaySecureUnwrapReason.unknownSubtype,
      );
    }
    if (!_rxWindow.accept(data.seq)) {
      return const OverlaySecureUnwrapResult.fail(
        OverlaySecureUnwrapReason.replay,
      );
    }

    final key = initiator ? _kR2I! : _kI2R!;
    final epoch = initiator ? _epochR2I : _epochI2R;
    final nonce = OverlaySecureCodec.buildAeadNonce(
      epochDir: epoch,
      seq: data.seq,
    );
    final aad = OverlaySecureCodec.buildAead(
      subtype: data.rawSubtype,
      linkId: linkId,
      seq: data.seq,
      initEndpointId: initEndpointId,
      respEndpointId: respEndpointId,
    );

    try {
      final clear = await Chacha20.poly1305Aead().decrypt(
        SecretBox(data.ciphertext, nonce: nonce, mac: Mac(data.aeadTag)),
        secretKey: key,
        aad: aad,
      );
      return OverlaySecureUnwrapResult.ok(
        cleartext: Uint8List.fromList(clear),
        subtype: data.subtype!,
        seq: data.seq,
      );
    } catch (_) {
      return const OverlaySecureUnwrapResult.fail(
        OverlaySecureUnwrapReason.tamper,
      );
    }
  }

  // -----------------------------------------------------------------
  // Internals
  // -----------------------------------------------------------------

  Future<void> _generateEphemeral() async {
    final kp = await X25519().newKeyPair();
    final pub = await kp.extractPublicKey();
    _myEphemeralKp = kp;
    _myX25519Pub = Uint8List.fromList(pub.bytes);
  }

  Future<void> _installKeys(Uint8List transcriptFull) async {
    final sha = await Sha256().hash(transcriptFull);
    final transcriptHash = Uint8List.fromList(sha.bytes);

    final shared = await X25519().sharedSecretKey(
      keyPair: _myEphemeralKp!,
      remotePublicKey: SimplePublicKey(
        _peerX25519Pub!,
        type: KeyPairType.x25519,
      ),
    );

    // `package:cryptography`'s `Hkdf.deriveKey` performs Extract then
    // Expand internally. `nonce` is the salt to Extract; `info` binds
    // the output to a specific usage label.
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

    _kI2R = await hkdf.deriveKey(
      secretKey: shared,
      nonce: transcriptHash,
      info: _asciiBytes(_hkdfInfoKeyI2R),
    );
    _kR2I = await hkdf.deriveKey(
      secretKey: shared,
      nonce: transcriptHash,
      info: _asciiBytes(_hkdfInfoKeyR2I),
    );

    final epochI2R = await Hkdf(hmac: Hmac.sha256(), outputLength: 4).deriveKey(
      secretKey: shared,
      nonce: transcriptHash,
      info: _asciiBytes(_hkdfInfoEpochI2R),
    );
    final epochR2I = await Hkdf(hmac: Hmac.sha256(), outputLength: 4).deriveKey(
      secretKey: shared,
      nonce: transcriptHash,
      info: _asciiBytes(_hkdfInfoEpochR2I),
    );

    _epochI2R = _u32FromBytes(await epochI2R.extractBytes());
    _epochR2I = _u32FromBytes(await epochR2I.extractBytes());
  }

  Future<bool> _verifyEd25519({
    required Uint8List message,
    required Uint8List signature,
    required Uint8List publicKey,
  }) async {
    if (publicKey.length != 32) return false;
    if (signature.length != 64) return false;
    final sig = Signature(
      signature,
      publicKey: SimplePublicKey(publicKey, type: KeyPairType.ed25519),
    );
    return Ed25519().verify(message, signature: sig);
  }

  Null _fail(String reason) {
    AppLogging.overlay(
      'SECURE fail linkId=0x${linkId.toRadixString(16)} reason=$reason',
    );
    _state = OverlaySecureSessionState.unavailable;
    _myEphemeralKp = null;
    _myX25519Pub = null;
    _peerX25519Pub = null;
    _myNonce = null;
    _peerNonce = null;
    _kI2R = null;
    _kR2I = null;
    return null;
  }

  static bool _constTimeEq(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  static Uint8List _asciiBytes(String s) => Uint8List.fromList(s.codeUnits);

  static int _u32FromBytes(List<int> bytes) {
    return ((bytes[0] & 0xFF) << 24) |
        ((bytes[1] & 0xFF) << 16) |
        ((bytes[2] & 0xFF) << 8) |
        (bytes[3] & 0xFF);
  }

  static String _hex(Uint8List b) =>
      b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
}
