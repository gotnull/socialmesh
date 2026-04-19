// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Integration tests for [OverlaySecureSession] covering the
/// invariants listed in `docs/sip/OVERLAY_V0_2.md §25.11`:
///
/// - handshake round-trip produces matching established sessions
/// - wrap / unwrap round-trip preserves cleartext
/// - replay-window rejects duplicates and too-old seq
/// - tampered ciphertext fails AEAD verify
/// - wrong-signer INIT / ACK is rejected
/// - wrong-link binding (mismatched endpoint id in AAD) fails
/// - re-open rekey: a second session has a distinct key space
library;

import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_endpoint_id.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_secure_codec.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_secure_session.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_types.dart';

class _Persona {
  final SimpleKeyPair keypair;
  final Uint8List publicKey;
  final Uint8List endpointId;

  _Persona({
    required this.keypair,
    required this.publicKey,
    required this.endpointId,
  });

  Future<Uint8List> sign(Uint8List message) async {
    final sig = await Ed25519().sign(message, keyPair: keypair);
    return Uint8List.fromList(sig.bytes);
  }
}

Future<_Persona> _buildPersona() async {
  final kp = await Ed25519().newKeyPair();
  final pub = await kp.extractPublicKey();
  final pubBytes = Uint8List.fromList(pub.bytes);
  final epId = await OverlayEndpointId.personaHint(pubBytes);
  return _Persona(keypair: kp, publicKey: pubBytes, endpointId: epId);
}

OverlaySecureSession _initSession(
  _Persona local,
  _Persona peer, {
  required int linkId,
  required Uint8List initEndpointId,
  required Uint8List respEndpointId,
  required bool initiator,
}) {
  return OverlaySecureSession(
    linkId: linkId,
    initEndpointId: initEndpointId,
    respEndpointId: respEndpointId,
    localPersonaPubEd: local.publicKey,
    peerPersonaPubEd: peer.publicKey,
    sign: local.sign,
    initiator: initiator,
  );
}

void main() {
  group('OverlaySecureSession handshake', () {
    test('two-message handshake establishes matching keys on both sides '
        'and wrap/unwrap round-trips', () async {
      final a = await _buildPersona();
      final b = await _buildPersona();
      const linkId = 0x0BADF00D;

      final initiator = _initSession(
        a,
        b,
        linkId: linkId,
        initEndpointId: a.endpointId,
        respEndpointId: b.endpointId,
        initiator: true,
      );
      final responder = _initSession(
        b,
        a,
        linkId: linkId,
        initEndpointId: a.endpointId,
        respEndpointId: b.endpointId,
        initiator: false,
      );

      final initPayload = await initiator.start();
      final ackPayload = await responder.handleInit(initPayload);
      expect(ackPayload, isNotNull);
      final ackOk = await initiator.handleAck(ackPayload!);
      expect(ackOk, isTrue);
      expect(initiator.isEstablished, isTrue);
      expect(responder.isEstablished, isTrue);

      // Initiator → responder.
      final msg1 = Uint8List.fromList('hello mesh'.codeUnits);
      final wrapped1 = await initiator.wrap(cleartext: msg1);
      expect(wrapped1.seq, 0);
      final rx1 = await responder.unwrap(wrapped1.payload);
      expect(rx1.ok, isTrue);
      expect(rx1.cleartext, msg1);
      expect(rx1.subtype, OverlaySecureDataSubtype.generic);

      // Responder → initiator.
      final msg2 = Uint8List.fromList('reply'.codeUnits);
      final wrapped2 = await responder.wrap(
        cleartext: msg2,
        subtype: OverlaySecureDataSubtype.dmText,
      );
      expect(wrapped2.seq, 0); // responder's own direction counter
      final rx2 = await initiator.unwrap(wrapped2.payload);
      expect(rx2.ok, isTrue);
      expect(rx2.cleartext, msg2);
      expect(rx2.subtype, OverlaySecureDataSubtype.dmText);
    });

    test(
      'wrong-signer INIT is rejected and session becomes unavailable',
      () async {
        final a = await _buildPersona();
        final b = await _buildPersona();
        final attacker = await _buildPersona();

        final responder = _initSession(
          b,
          a, // expects A's Ed25519 key for peer verification
          linkId: 1,
          initEndpointId: a.endpointId,
          respEndpointId: b.endpointId,
          initiator: false,
        );

        // Attacker signs a transcript claiming to be A.
        final spoof = _initSession(
          attacker,
          b,
          linkId: 1,
          initEndpointId: a.endpointId, // lies about identity
          respEndpointId: b.endpointId,
          initiator: true,
        );

        final spoofedInit = await spoof.start();
        final ack = await responder.handleInit(spoofedInit);
        expect(ack, isNull);
        expect(responder.state, OverlaySecureSessionState.unavailable);
      },
    );

    test(
      'wrong-signer ACK is rejected; initiator becomes unavailable',
      () async {
        final a = await _buildPersona();
        final b = await _buildPersona();
        final attacker = await _buildPersona();

        final initiator = _initSession(
          a,
          b,
          linkId: 2,
          initEndpointId: a.endpointId,
          respEndpointId: b.endpointId,
          initiator: true,
        );
        final fakeResponder = _initSession(
          attacker,
          a,
          linkId: 2,
          initEndpointId: a.endpointId,
          respEndpointId: b.endpointId, // claims to be B
          initiator: false,
        );

        final init = await initiator.start();
        final ack = await fakeResponder.handleInit(init);
        expect(ack, isNotNull);

        final accepted = await initiator.handleAck(ack!);
        expect(accepted, isFalse);
        expect(initiator.state, OverlaySecureSessionState.unavailable);
      },
    );

    test(
      'handleInit rejects payload with mismatched init_endpoint_id',
      () async {
        final a = await _buildPersona();
        final b = await _buildPersona();

        final responder = _initSession(
          b,
          a,
          linkId: 3,
          initEndpointId: a.endpointId,
          respEndpointId: b.endpointId,
          initiator: false,
        );

        // Hand-craft a payload whose ep id claims to be something else.
        final fakeEndpointId = Uint8List.fromList(List<int>.filled(8, 0x99));
        final rogueSession = _initSession(
          a,
          b,
          linkId: 3,
          initEndpointId: fakeEndpointId,
          respEndpointId: b.endpointId,
          initiator: true,
        );
        final rogueInit = await rogueSession.start();

        final ack = await responder.handleInit(rogueInit);
        expect(ack, isNull);
        expect(responder.state, OverlaySecureSessionState.unavailable);
      },
    );
  });

  group('OverlaySecureSession data-frame integrity', () {
    Future<({OverlaySecureSession i, OverlaySecureSession r})> pair() async {
      final a = await _buildPersona();
      final b = await _buildPersona();
      const linkId = 0xC0FFEE;
      final initiator = _initSession(
        a,
        b,
        linkId: linkId,
        initEndpointId: a.endpointId,
        respEndpointId: b.endpointId,
        initiator: true,
      );
      final responder = _initSession(
        b,
        a,
        linkId: linkId,
        initEndpointId: a.endpointId,
        respEndpointId: b.endpointId,
        initiator: false,
      );
      final init = await initiator.start();
      final ack = await responder.handleInit(init);
      await initiator.handleAck(ack!);
      return (i: initiator, r: responder);
    }

    test('tampered ciphertext fails AEAD and returns tamper reason', () async {
      final s = await pair();
      final wrapped = await s.i.wrap(
        cleartext: Uint8List.fromList(<int>[1, 2, 3, 4, 5]),
      );
      final tampered = Uint8List.fromList(wrapped.payload);
      // Flip the last ciphertext byte (after the 21-byte header).
      tampered[tampered.length - 1] ^= 0x01;
      final rx = await s.r.unwrap(tampered);
      expect(rx.ok, isFalse);
      expect(rx.failure, OverlaySecureUnwrapReason.tamper);
    });

    test('tampered AAD-protected field (subtype swap to another known code) '
        'fails AEAD', () async {
      final s = await pair();
      final wrapped = await s.i.wrap(
        cleartext: Uint8List.fromList(<int>[9, 9, 9]),
      );
      final tampered = Uint8List.fromList(wrapped.payload);
      // Swap subtype from 0x01 (generic) → 0x02 (dm_text). Both are
      // known so the unknown-subtype short-circuit does not fire;
      // the AEAD then fails because AAD binds the subtype byte.
      expect(tampered[0], OverlaySecureDataSubtype.generic.code);
      tampered[0] = OverlaySecureDataSubtype.dmText.code;
      final rx = await s.r.unwrap(tampered);
      expect(rx.ok, isFalse);
      expect(rx.failure, OverlaySecureUnwrapReason.tamper);
    });

    test('unknown subtype is strictly rejected before AEAD', () async {
      final s = await pair();
      // Craft a frame with subtype 0xEF using the real tag from the
      // real session — still fails, but via unknownSubtype (checked
      // first).
      final wrapped = await s.i.wrap(cleartext: Uint8List.fromList(<int>[0]));
      final mangled = Uint8List.fromList(wrapped.payload);
      mangled[0] = 0xEF;
      final rx = await s.r.unwrap(mangled);
      expect(rx.failure, OverlaySecureUnwrapReason.unknownSubtype);
    });

    test(
      'replay: same frame twice is rejected on the second attempt',
      () async {
        final s = await pair();
        final wrapped = await s.i.wrap(
          cleartext: Uint8List.fromList(<int>[1, 2]),
        );
        final first = await s.r.unwrap(wrapped.payload);
        expect(first.ok, isTrue);
        final second = await s.r.unwrap(wrapped.payload);
        expect(second.failure, OverlaySecureUnwrapReason.replay);
      },
    );

    test(
      'replay: out-of-order within window accepted; too-old rejected',
      () async {
        final s = await pair();
        // Send 70 frames to advance the high-water mark well beyond 64.
        final wrappeds = <OverlaySecureWrapResult>[];
        for (var i = 0; i < 70; i++) {
          wrappeds.add(await s.i.wrap(cleartext: Uint8List.fromList(<int>[i])));
        }
        // Receiver takes the newest first to move `hi` high.
        final newest = await s.r.unwrap(wrappeds.last.payload);
        expect(newest.ok, isTrue);

        // An in-window seq (69 - 10 = 59) is still acceptable.
        final inWindow = await s.r.unwrap(wrappeds[59].payload);
        expect(inWindow.ok, isTrue);

        // A too-old seq (0) falls outside the 64-entry window → replay.
        final tooOld = await s.r.unwrap(wrappeds[0].payload);
        expect(tooOld.failure, OverlaySecureUnwrapReason.replay);
      },
    );

    test('unwrap before established returns notEstablished', () async {
      final a = await _buildPersona();
      final b = await _buildPersona();
      final responder = _initSession(
        b,
        a,
        linkId: 4,
        initEndpointId: a.endpointId,
        respEndpointId: b.endpointId,
        initiator: false,
      );
      final rx = await responder.unwrap(
        OverlaySecureCodec.encodeData(
          subtype: 0x01,
          seq: 0,
          aeadTag: Uint8List(16),
          ciphertext: Uint8List(4),
        ),
      );
      expect(rx.failure, OverlaySecureUnwrapReason.notEstablished);
    });
  });

  group('OverlaySecureSession link binding', () {
    test('a DATA frame authored under linkId=X does not decrypt under '
        'linkId=Y (AAD binding)', () async {
      final a = await _buildPersona();
      final b = await _buildPersona();

      // First session: linkId = 100.
      final i1 = _initSession(
        a,
        b,
        linkId: 100,
        initEndpointId: a.endpointId,
        respEndpointId: b.endpointId,
        initiator: true,
      );
      final r1 = _initSession(
        b,
        a,
        linkId: 100,
        initEndpointId: a.endpointId,
        respEndpointId: b.endpointId,
        initiator: false,
      );
      await r1.handleInit(await i1.start()).then((ack) => i1.handleAck(ack!));
      final wrapped = await i1.wrap(
        cleartext: Uint8List.fromList(<int>[7, 7, 7]),
      );

      // Second session: linkId = 200, otherwise identical endpoints.
      final i2 = _initSession(
        a,
        b,
        linkId: 200,
        initEndpointId: a.endpointId,
        respEndpointId: b.endpointId,
        initiator: true,
      );
      final r2 = _initSession(
        b,
        a,
        linkId: 200,
        initEndpointId: a.endpointId,
        respEndpointId: b.endpointId,
        initiator: false,
      );
      await r2.handleInit(await i2.start()).then((ack) => i2.handleAck(ack!));

      // Responder on session 2 tries to decrypt frame from session 1
      // → fails because AAD includes linkId and keys differ.
      final rx = await r2.unwrap(wrapped.payload);
      expect(rx.ok, isFalse);
      expect(rx.failure, OverlaySecureUnwrapReason.tamper);
    });

    test('re-open rekey: a fresh session derives different keys even '
        'with identical identities and linkId', () async {
      final a = await _buildPersona();
      final b = await _buildPersona();
      const linkId = 0x99;

      Future<Uint8List> runSession() async {
        final i = _initSession(
          a,
          b,
          linkId: linkId,
          initEndpointId: a.endpointId,
          respEndpointId: b.endpointId,
          initiator: true,
        );
        final r = _initSession(
          b,
          a,
          linkId: linkId,
          initEndpointId: a.endpointId,
          respEndpointId: b.endpointId,
          initiator: false,
        );
        await r.handleInit(await i.start()).then((ack) => i.handleAck(ack!));
        final wrapped = await i.wrap(
          cleartext: Uint8List.fromList(<int>[0xAB, 0xCD]),
        );
        return wrapped.payload;
      }

      final payload1 = await runSession();
      final payload2 = await runSession();

      // Both are well-formed and the same seq (0) — but AEAD tags and
      // ciphertexts MUST differ because ephemeral keys + nonces
      // differ. Otherwise we'd have forward-secrecy loss.
      expect(payload1, isNot(equals(payload2)));
    });
  });
}
