// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/sip/sip_codec.dart';
import 'package:socialmesh/services/protocol/sip/sip_frame.dart';
import 'package:socialmesh/services/protocol/sip/sip_identity.dart';
import 'package:socialmesh/services/protocol/sip/sip_identity_store.dart';
import 'package:socialmesh/services/protocol/sip/sip_keypair.dart';
import 'package:socialmesh/services/protocol/sip/sip_messages_id.dart';
import 'package:socialmesh/services/protocol/sip/sip_types.dart';

/// In-memory fake for [FlutterSecureStorage] (v10.0.0 API).
class _FakeSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _store = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      _store[key] = value;
    } else {
      _store.remove(key);
    }
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _store[key];

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _store.remove(key);
}

/// Create a test keypair backed by in-memory storage.
Future<SipKeypair> _createTestKeypair() async {
  final kp = SipKeypair(storage: _FakeSecureStorage(), algorithm: Ed25519());
  await kp.ensureInitialized();
  return kp;
}

void main() {
  group('SipIdMessages', () {
    group('ID_REQ', () {
      test('encode/decode round-trip - basic mode', () {
        final req = SipIdReq(mode: SipIdRequestMode.basic);
        final encoded = SipIdMessages.encodeIdReq(req);
        expect(encoded.length, 2);

        final decoded = SipIdMessages.decodeIdReq(encoded);
        expect(decoded, isNotNull);
        expect(decoded!.mode, SipIdRequestMode.basic);
      });

      test('encode/decode round-trip - full mode', () {
        final req = SipIdReq(mode: SipIdRequestMode.full);
        final encoded = SipIdMessages.encodeIdReq(req);
        final decoded = SipIdMessages.decodeIdReq(encoded);
        expect(decoded!.mode, SipIdRequestMode.full);
      });

      test('decode rejects short payload', () {
        final decoded = SipIdMessages.decodeIdReq(Uint8List(1));
        expect(decoded, isNull);
      });

      test('decode rejects unknown mode', () {
        final payload = Uint8List.fromList([0xFF, 0x00]);
        final decoded = SipIdMessages.decodeIdReq(payload);
        expect(decoded, isNull);
      });
    });

    group('ID_CLAIM', () {
      test('encode/decode round-trip without signature', () {
        final pubkey = Uint8List(32);
        for (var i = 0; i < 32; i++) {
          pubkey[i] = i;
        }
        final personaId = Uint8List(16);
        for (var i = 0; i < 16; i++) {
          personaId[i] = i + 100;
        }

        final claim = SipIdClaim(
          keyType: sipSigTypeEd25519,
          displayName: 'Alice',
          status: 'Hello mesh',
          deviceModel: 'T-Beam v1.1',
          createdAt: 1700000000,
          personaId: personaId,
          pubkey: pubkey,
          claimTtlS: 86400,
        );

        final encoded = SipIdMessages.encodeIdClaim(claim);
        final decoded = SipIdMessages.decodeIdClaim(encoded);

        expect(decoded, isNotNull);
        expect(decoded!.keyType, sipSigTypeEd25519);
        expect(decoded.displayName, 'Alice');
        expect(decoded.status, 'Hello mesh');
        expect(decoded.deviceModel, 'T-Beam v1.1');
        expect(decoded.createdAt, 1700000000);
        expect(decoded.pubkey, pubkey);
        expect(decoded.personaId, personaId);
        expect(decoded.claimTtlS, 86400);
      });

      test('encode/decode round-trip with signature trailer', () {
        final pubkey = Uint8List(32);
        for (var i = 0; i < 32; i++) {
          pubkey[i] = i;
        }
        final personaId = Uint8List(16);
        for (var i = 0; i < 16; i++) {
          personaId[i] = i + 100;
        }

        final claim = SipIdClaim(
          keyType: sipSigTypeEd25519,
          displayName: 'Bob',
          status: '',
          deviceModel: '',
          createdAt: 1700000000,
          personaId: personaId,
          pubkey: pubkey,
          claimTtlS: 3600,
        );

        final claimPayload = SipIdMessages.encodeIdClaim(claim);
        final fakeSig = Uint8List(64);
        for (var i = 0; i < 64; i++) {
          fakeSig[i] = 0xAA;
        }
        final withSig = SipIdMessages.appendSignature(claimPayload, fakeSig);

        final decoded = SipIdMessages.decodeIdClaim(withSig, hasSig: true);
        expect(decoded, isNotNull);
        expect(decoded!.displayName, 'Bob');
        expect(decoded.claimTtlS, 3600);

        final sigData = SipIdMessages.extractSignature(withSig);
        expect(sigData, isNotNull);
        expect(sigData!.sigType, sipSigTypeEd25519);
        expect(sigData.sigLen, sipSigLenEd25519);
        expect(sigData.signature.length, 64);
        expect(sigData.signature.every((b) => b == 0xAA), isTrue);
      });

      test('decode rejects too-short payload', () {
        final decoded = SipIdMessages.decodeIdClaim(Uint8List(10));
        expect(decoded, isNull);
      });

      test('empty display name, status, device model', () {
        final pubkey = Uint8List(32);
        final personaId = Uint8List(16);

        final claim = SipIdClaim(
          keyType: sipSigTypeEd25519,
          displayName: '',
          status: '',
          deviceModel: '',
          createdAt: 0,
          personaId: personaId,
          pubkey: pubkey,
          claimTtlS: 0,
        );

        final encoded = SipIdMessages.encodeIdClaim(claim);
        final decoded = SipIdMessages.decodeIdClaim(encoded);
        expect(decoded, isNotNull);
        expect(decoded!.displayName, '');
        expect(decoded.status, '');
        expect(decoded.deviceModel, '');
      });
    });

    group('Signature helpers', () {
      test('buildSignedData concatenates header and payload', () {
        final header = Uint8List.fromList([1, 2, 3]);
        final payload = Uint8List.fromList([4, 5, 6, 7]);
        final result = SipIdMessages.buildSignedData(header, payload);
        expect(result.length, 7);
        expect(result, Uint8List.fromList([1, 2, 3, 4, 5, 6, 7]));
      });

      test('extractSignature returns null for short payload', () {
        expect(SipIdMessages.extractSignature(Uint8List(10)), isNull);
      });
    });
  });

  group('SipIdentityHandler', () {
    late SipKeypair aliceKp;
    late SipKeypair bobKp;
    late SipIdentityStore aliceStore;
    late SipIdentityStore bobStore;
    late SipIdentityHandler aliceHandler;
    late SipIdentityHandler bobHandler;
    late int nowMs;

    setUp(() async {
      nowMs = 1700000000000;
      aliceKp = await _createTestKeypair();
      bobKp = await _createTestKeypair();

      aliceStore = SipIdentityStore(clock: () => nowMs);
      bobStore = SipIdentityStore(clock: () => nowMs);

      aliceHandler = SipIdentityHandler(
        keypair: aliceKp,
        store: aliceStore,
        localNodeId: 0xAAAA,
        displayName: 'Alice',
        status: 'On the mesh',
        deviceModel: 'T-Beam',
        claimTtlS: 86400,
        clock: () => nowMs,
      );

      bobHandler = SipIdentityHandler(
        keypair: bobKp,
        store: bobStore,
        localNodeId: 0xBBBB,
        displayName: 'Bob',
        status: '',
        deviceModel: 'Heltec',
        claimTtlS: 86400,
        clock: () => nowMs,
      );

      // Enable privacy gates for testing.
      aliceHandler.isProfileSharingEnabled = true;
      bobHandler.isProfileSharingEnabled = true;
    });

    test('buildIdReq produces valid frame', () {
      final outbound = aliceHandler.buildIdReq();
      expect(outbound, isNotNull);
      expect(outbound!.encoded.length, greaterThan(0));

      final decoded = SipCodec.decode(outbound.encoded);
      expect(decoded, isNotNull);
      expect(decoded!.msgType, SipMessageType.idReq);
    });

    test('buildIdClaim produces signed frame', () async {
      final outbound = await aliceHandler.buildIdClaim(peerNodeId: 0xBBBB);
      expect(outbound, isNotNull);

      final decoded = SipCodec.decode(outbound!.encoded);
      expect(decoded, isNotNull);
      expect(decoded!.msgType, SipMessageType.idClaim);
      expect(decoded.flags & SipFlags.hasSignature, isNonZero);

      // Verify the claim decodes.
      final claim = SipIdMessages.decodeIdClaim(decoded.payload, hasSig: true);
      expect(claim, isNotNull);
      expect(claim!.displayName, 'Alice');
    });

    test('buildIdClaim rate-limited for same peer within 300s', () async {
      final first = await aliceHandler.buildIdClaim(peerNodeId: 0xBBBB);
      expect(first, isNotNull);

      nowMs += 100 * 1000; // Only 100s.

      final second = await aliceHandler.buildIdClaim(peerNodeId: 0xBBBB);
      expect(second, isNull);
    });

    test('buildIdClaim allowed for same peer after 300s', () async {
      final first = await aliceHandler.buildIdClaim(peerNodeId: 0xBBBB);
      expect(first, isNotNull);

      nowMs += 301 * 1000;

      final second = await aliceHandler.buildIdClaim(peerNodeId: 0xBBBB);
      expect(second, isNotNull);
    });

    test('full identity exchange: Alice -> Bob', () async {
      // Alice sends ID_CLAIM to Bob.
      final claimOut = await aliceHandler.buildIdClaim(peerNodeId: 0xBBBB);
      expect(claimOut, isNotNull);

      final decoded = SipCodec.decode(claimOut!.encoded)!;

      // Bob receives and verifies Alice's claim.
      final result = await bobHandler.handleInboundClaim(
        frame: decoded,
        rawFrameBytes: claimOut.encoded,
        senderNodeId: 0xAAAA,
      );

      expect(result, isNotNull);
      expect(result!.signatureValid, isTrue);
      expect(result.state, SipIdentityState.verifiedTofu);
      expect(result.claim.displayName, 'Alice');

      // Bob's store has Alice's identity.
      final aliceRecord = bobStore.getByNodeId(0xAAAA);
      expect(aliceRecord, isNotNull);
      expect(aliceRecord!.state, SipIdentityState.verifiedTofu);
    });

    test('handleInboundReq responds with ID_RESP', () async {
      // Alice sends ID_REQ.
      final reqOut = aliceHandler.buildIdReq();
      final reqFrame = SipCodec.decode(reqOut!.encoded)!;

      // Bob handles the ID_REQ and responds.
      final respOut = await bobHandler.handleInboundReq(
        frame: reqFrame,
        senderNodeId: 0xAAAA,
      );

      expect(respOut, isNotNull);
      final respDecoded = SipCodec.decode(respOut!.encoded)!;
      expect(respDecoded.msgType, SipMessageType.idResp);
    });

    test('signature verification fails with wrong pubkey', () async {
      // Alice sends a claim.
      final claimOut = await aliceHandler.buildIdClaim(peerNodeId: 0xBBBB);
      final decoded = SipCodec.decode(claimOut!.encoded)!;

      // Tamper: modify a byte in the payload (corrupt the signature target).
      final tamperedPayload = Uint8List.fromList(decoded.payload);
      if (tamperedPayload.length > 10) {
        tamperedPayload[5] ^= 0xFF;
      }

      final tamperedFrame = decoded.copyWith(payload: tamperedPayload);

      // Build tampered raw bytes.
      final tamperedEncoded = SipCodec.encode(tamperedFrame);
      expect(tamperedEncoded, isNotNull);

      final result = await bobHandler.handleInboundClaim(
        frame: tamperedFrame,
        rawFrameBytes: tamperedEncoded!,
        senderNodeId: 0xAAAA,
      );

      // Signature should fail because the data was tampered.
      expect(result, isNotNull);
      expect(result!.signatureValid, isFalse);
      expect(result.state, SipIdentityState.unverified);
    });
  });
}

/// Extension to allow copying a frame with modified payload.
extension _SipFrameCopy on SipFrame {
  SipFrame copyWith({Uint8List? payload}) {
    return SipFrame(
      versionMajor: versionMajor,
      versionMinor: versionMinor,
      msgType: msgType,
      flags: flags,
      headerLen: headerLen,
      sessionId: sessionId,
      nonce: nonce,
      timestampS: timestampS,
      payloadLen: payload?.length ?? payloadLen,
      payload: payload ?? this.payload,
      headerExtensions: headerExtensions,
    );
  }
}
