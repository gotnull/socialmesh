// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Pins the AEAD seq-exhaustion contract for the secure session:
// deterministic nonces (epoch_dir || 0 || seq) mean the u32 counter must
// never wrap under one key. The final seq value still wraps a frame the
// peer can decrypt; past that, wrap() throws and isSeqExhausted reports
// the session as spent so callers drop it and renegotiate fresh keys.

import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_endpoint_id.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_secure_session.dart';

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

Future<(OverlaySecureSession, OverlaySecureSession)> _establishedPair() async {
  final a = await _buildPersona();
  final b = await _buildPersona();
  const linkId = 0x0BADF00D;

  final initiator = OverlaySecureSession(
    linkId: linkId,
    initEndpointId: a.endpointId,
    respEndpointId: b.endpointId,
    localPersonaPubEd: a.publicKey,
    peerPersonaPubEd: b.publicKey,
    sign: a.sign,
    initiator: true,
  );
  final responder = OverlaySecureSession(
    linkId: linkId,
    initEndpointId: a.endpointId,
    respEndpointId: b.endpointId,
    localPersonaPubEd: b.publicKey,
    peerPersonaPubEd: a.publicKey,
    sign: b.sign,
    initiator: false,
  );

  final initPayload = await initiator.start();
  final ackPayload = await responder.handleInit(initPayload);
  expect(ackPayload, isNotNull);
  expect(await initiator.handleAck(ackPayload!), isTrue);
  return (initiator, responder);
}

void main() {
  test('the final u32 seq still wraps a decryptable frame; past it wrap() '
      'throws and isSeqExhausted reports the session spent', () async {
    final (initiator, responder) = await _establishedPair();

    initiator.debugSetTxSeq(OverlaySecureSession.maxTxSeq);
    expect(initiator.isSeqExhausted, isFalse);

    final cleartext = Uint8List.fromList('last frame'.codeUnits);
    final wrapped = await initiator.wrap(cleartext: cleartext);
    expect(wrapped.seq, OverlaySecureSession.maxTxSeq);

    // The peer accepts the boundary frame. The replay window tracks the
    // highest seq seen, so the jump from 0 to maxTxSeq is in-window.
    final rx = await responder.unwrap(wrapped.payload);
    expect(
      rx.ok,
      isTrue,
      reason: 'Boundary-seq frame must decrypt: ${rx.failure}',
    );
    expect(rx.cleartext, cleartext);

    // Counter is now spent: no further wrap may reuse a nonce.
    expect(initiator.isSeqExhausted, isTrue);
    await expectLater(initiator.wrap(cleartext: cleartext), throwsStateError);
    // Still established: only the tx counter is spent. The manager layer
    // owns dropping the session.
    expect(initiator.isEstablished, isTrue);
  });

  test('a fresh session starts with an unspent counter at seq 0', () async {
    final (initiator, _) = await _establishedPair();
    expect(initiator.isSeqExhausted, isFalse);
    final wrapped = await initiator.wrap(
      cleartext: Uint8List.fromList('first'.codeUnits),
    );
    expect(wrapped.seq, 0);
  });
}
