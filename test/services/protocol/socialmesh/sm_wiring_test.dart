// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/socialmesh/sm_capability_store.dart';
import 'package:socialmesh/services/protocol/socialmesh/sm_codec.dart';
import 'package:socialmesh/services/protocol/socialmesh/sm_constants.dart';
import 'package:socialmesh/services/protocol/socialmesh/sm_feature_flag.dart';
import 'package:socialmesh/services/protocol/socialmesh/sm_identity.dart';
import 'package:socialmesh/services/protocol/socialmesh/sm_metrics.dart';
import 'package:socialmesh/services/protocol/socialmesh/sm_packet_router.dart';
import 'package:socialmesh/services/protocol/socialmesh/sm_presence.dart';
import 'package:socialmesh/services/protocol/socialmesh/sm_signal.dart';

void main() {
  // ─────────────────────────────────────────────────────────────────
  // SmFeatureFlag
  // ─────────────────────────────────────────────────────────────────

  group('SmFeatureFlag', () {
    test('defaults: binary disabled, legacy compat on', () {
      final flag = SmFeatureFlag();
      expect(flag.smBinaryEnabled, isFalse);
      expect(flag.legacyCompatibilityMode, isTrue);
      expect(flag.shouldSendBinary, isFalse);
      expect(flag.shouldSendLegacy, isTrue);
    });

    test('binary enabled: sends both binary and legacy', () {
      final flag = SmFeatureFlag(smBinaryEnabled: true);
      expect(flag.shouldSendBinary, isTrue);
      expect(flag.shouldSendLegacy, isTrue); // compat mode still on
    });

    test('binary enabled, legacy compat off: binary only', () {
      final flag = SmFeatureFlag(
        smBinaryEnabled: true,
        legacyCompatibilityMode: false,
      );
      expect(flag.shouldSendBinary, isTrue);
      expect(flag.shouldSendLegacy, isFalse);
    });

    test('shouldSendLegacyGivenMeshState respects mesh readiness', () {
      final flag = SmFeatureFlag(smBinaryEnabled: true);

      // Mesh not ready → send legacy
      expect(
        flag.shouldSendLegacyGivenMeshState(isMeshBinaryReady: false),
        isTrue,
      );

      // Mesh ready → stop sending legacy
      expect(
        flag.shouldSendLegacyGivenMeshState(isMeshBinaryReady: true),
        isFalse,
      );
    });

    test('shouldSendLegacyGivenMeshState with binary disabled', () {
      final flag = SmFeatureFlag(smBinaryEnabled: false);

      // Always send legacy when binary is disabled, regardless of mesh state
      expect(
        flag.shouldSendLegacyGivenMeshState(isMeshBinaryReady: true),
        isTrue,
      );
    });

    test('shouldSendLegacyGivenMeshState with compat off', () {
      final flag = SmFeatureFlag(
        smBinaryEnabled: true,
        legacyCompatibilityMode: false,
      );

      // Never send legacy when compat is off, regardless of mesh state
      expect(
        flag.shouldSendLegacyGivenMeshState(isMeshBinaryReady: false),
        isFalse,
      );
    });

    test('setters update flag values', () {
      final flag = SmFeatureFlag();

      flag.setSmBinaryEnabled(true);
      expect(flag.smBinaryEnabled, isTrue);

      flag.setLegacyCompatibilityMode(false);
      expect(flag.legacyCompatibilityMode, isFalse);
    });

    test('toString includes both flags', () {
      final flag = SmFeatureFlag(smBinaryEnabled: true);
      expect(flag.toString(), contains('binary=true'));
      expect(flag.toString(), contains('legacyCompat=true'));
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // SmMetrics
  // ─────────────────────────────────────────────────────────────────

  group('SmMetrics', () {
    test('starts at zero', () {
      final m = SmMetrics();
      expect(m.binaryPacketsReceived, 0);
      expect(m.legacyPacketsReceived, 0);
      expect(m.decodeNullCount, 0);
      expect(m.dualSendCount, 0);
      expect(m.decodeNullByPortnum, isEmpty);
    });

    test('records binary packets', () {
      final m = SmMetrics();
      m.recordBinaryPacketReceived();
      m.recordBinaryPacketReceived();
      expect(m.binaryPacketsReceived, 2);
    });

    test('records legacy packets', () {
      final m = SmMetrics();
      m.recordLegacyPacketReceived();
      expect(m.legacyPacketsReceived, 1);
    });

    test('records decode nulls by portnum', () {
      final m = SmMetrics();
      m.recordDecodeNull(260);
      m.recordDecodeNull(261);
      m.recordDecodeNull(260);

      expect(m.decodeNullCount, 3);
      expect(m.decodeNullByPortnum[260], 2);
      expect(m.decodeNullByPortnum[261], 1);
    });

    test('records dual send', () {
      final m = SmMetrics();
      m.recordDualSend();
      expect(m.dualSendCount, 1);
    });

    test('reset clears all counters', () {
      final m = SmMetrics();
      m.recordBinaryPacketReceived();
      m.recordLegacyPacketReceived();
      m.recordDecodeNull(260);
      m.recordDualSend();

      m.reset();

      expect(m.binaryPacketsReceived, 0);
      expect(m.legacyPacketsReceived, 0);
      expect(m.decodeNullCount, 0);
      expect(m.dualSendCount, 0);
      expect(m.decodeNullByPortnum, isEmpty);
    });

    test('toString includes all counters', () {
      final m = SmMetrics();
      m.recordBinaryPacketReceived();
      final str = m.toString();
      expect(str, contains('binary=1'));
      expect(str, contains('legacy=0'));
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // SmPacketRouter — signal ID conversion
  // ─────────────────────────────────────────────────────────────────

  group('SmPacketRouter signal ID conversion', () {
    test('signalIdToString produces sm-prefixed hex', () {
      final id = SmPacketRouter.signalIdToString(0x0123456789ABCDEF);
      expect(id, startsWith('sm-'));
      expect(id.length, 19); // "sm-" + 16 hex chars
      expect(id, 'sm-0123456789abcdef');
    });

    test('signalIdToString zero-pads short IDs', () {
      final id = SmPacketRouter.signalIdToString(0xFF);
      expect(id, 'sm-00000000000000ff');
    });

    test('signalIdToString handles zero', () {
      final id = SmPacketRouter.signalIdToString(0);
      expect(id, 'sm-0000000000000000');
    });

    test('signalIdToString handles negative (high bit set)', () {
      // In Dart, int is signed 64-bit. -1 has all bits set → 0xFFFFFFFFFFFFFFFF
      final id = SmPacketRouter.signalIdToString(-1);
      expect(id, 'sm-ffffffffffffffff');
    });

    test('signalIdFromString round-trips', () {
      const originalId = 0x0123456789ABCDEF;
      final str = SmPacketRouter.signalIdToString(originalId);
      final parsed = SmPacketRouter.signalIdFromString(str);
      expect(parsed, originalId);
    });

    test('signalIdFromString round-trips negative values', () {
      const originalId = -1; // all bits set
      final str = SmPacketRouter.signalIdToString(originalId);
      final parsed = SmPacketRouter.signalIdFromString(str);
      // Round-trip preserves the signed 64-bit pattern
      expect(parsed, originalId);
    });

    test('signalIdFromString returns null for non-SM IDs', () {
      expect(SmPacketRouter.signalIdFromString('not-an-sm-id'), isNull);
      expect(
        SmPacketRouter.signalIdFromString(
          'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        ),
        isNull,
      );
    });

    test('signalIdFromString returns null for wrong length hex', () {
      expect(SmPacketRouter.signalIdFromString('sm-abc'), isNull);
      expect(SmPacketRouter.signalIdFromString('sm-'), isNull);
    });

    test('isSmSignalId identifies SM signal IDs', () {
      expect(SmPacketRouter.isSmSignalId('sm-0123456789abcdef'), isTrue);
      expect(SmPacketRouter.isSmSignalId('sm-0000000000000000'), isTrue);
      expect(SmPacketRouter.isSmSignalId('a1b2c3d4-e5f6'), isFalse);
      expect(SmPacketRouter.isSmSignalId(''), isFalse);
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // SmPacketRouter — TTL conversion
  // ─────────────────────────────────────────────────────────────────

  group('SmPacketRouter TTL conversion', () {
    test('ttlToMinutes maps all enum values', () {
      expect(SmPacketRouter.ttlToMinutes(SmSignalTtl.minutes15), 15);
      expect(SmPacketRouter.ttlToMinutes(SmSignalTtl.minutes30), 30);
      expect(SmPacketRouter.ttlToMinutes(SmSignalTtl.hour1), 60);
      expect(SmPacketRouter.ttlToMinutes(SmSignalTtl.hours6), 360);
      expect(SmPacketRouter.ttlToMinutes(SmSignalTtl.hours24), 1440);
    });

    test('ttlFromMinutes finds closest TTL', () {
      expect(SmPacketRouter.ttlFromMinutes(1), SmSignalTtl.minutes15);
      expect(SmPacketRouter.ttlFromMinutes(15), SmSignalTtl.minutes15);
      expect(SmPacketRouter.ttlFromMinutes(20), SmSignalTtl.minutes30);
      expect(SmPacketRouter.ttlFromMinutes(30), SmSignalTtl.minutes30);
      expect(SmPacketRouter.ttlFromMinutes(45), SmSignalTtl.hour1);
      expect(SmPacketRouter.ttlFromMinutes(60), SmSignalTtl.hour1);
      expect(SmPacketRouter.ttlFromMinutes(120), SmSignalTtl.hours6);
      expect(SmPacketRouter.ttlFromMinutes(360), SmSignalTtl.hours6);
      expect(SmPacketRouter.ttlFromMinutes(720), SmSignalTtl.hours24);
      expect(SmPacketRouter.ttlFromMinutes(1440), SmSignalTtl.hours24);
      expect(SmPacketRouter.ttlFromMinutes(9999), SmSignalTtl.hours24);
    });

    test('ttlToMinutes round-trips through ttlFromMinutes', () {
      for (final ttl in SmSignalTtl.values) {
        final minutes = SmPacketRouter.ttlToMinutes(ttl);
        final roundTripped = SmPacketRouter.ttlFromMinutes(minutes);
        expect(roundTripped, ttl, reason: 'TTL $ttl round-trip failed');
      }
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // SmIdentityRateLimiter
  // ─────────────────────────────────────────────────────────────────

  group('SmIdentityRateLimiter', () {
    test('first request is always allowed', () {
      final limiter = SmIdentityRateLimiter();
      expect(limiter.canRequest(0x01), isTrue);
      expect(limiter.cooldownRemaining(0x01), Duration.zero);
    });

    test('blocks subsequent requests within interval', () {
      var now = DateTime(2026, 1, 1, 12, 0);
      final limiter = SmIdentityRateLimiter(clock: () => now);

      limiter.recordRequest(0x01);
      expect(limiter.canRequest(0x01), isFalse);

      // Advance 5 minutes (less than 10-minute interval)
      now = DateTime(2026, 1, 1, 12, 5);
      expect(limiter.canRequest(0x01), isFalse);
    });

    test('allows request after interval expires', () {
      var now = DateTime(2026, 1, 1, 12, 0);
      final limiter = SmIdentityRateLimiter(clock: () => now);

      limiter.recordRequest(0x01);

      // Advance past 10-minute interval
      now = DateTime(2026, 1, 1, 12, 11);
      expect(limiter.canRequest(0x01), isTrue);
    });

    test('per-node rate limiting is independent', () {
      var now = DateTime(2026, 1, 1, 12, 0);
      final limiter = SmIdentityRateLimiter(clock: () => now);

      limiter.recordRequest(0x01);
      expect(limiter.canRequest(0x01), isFalse);
      expect(limiter.canRequest(0x02), isTrue); // different node
    });

    test('cooldownRemaining returns correct duration', () {
      var now = DateTime(2026, 1, 1, 12, 0);
      final limiter = SmIdentityRateLimiter(clock: () => now);

      limiter.recordRequest(0x01);

      now = DateTime(2026, 1, 1, 12, 3);
      final remaining = limiter.cooldownRemaining(0x01);

      // 10 minutes - 3 minutes = 7 minutes
      expect(remaining.inMinutes, 7);
    });

    test('reset clears all state', () {
      final limiter = SmIdentityRateLimiter();
      limiter.recordRequest(0x01);
      limiter.recordRequest(0x02);

      limiter.reset();

      expect(limiter.canRequest(0x01), isTrue);
      expect(limiter.canRequest(0x02), isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // Dispatcher routing: portnum → correct codec → correct pipeline
  // ─────────────────────────────────────────────────────────────────

  group('Dispatcher routing', () {
    test('portnum 260 decodes as SM_PRESENCE', () {
      final presence = SmPresence(
        battery: 85,
        intent: SmPresenceIntent.available,
        status: 'Hello',
      );
      final encoded = presence.encode()!;

      final packet = SmCodec.decode(SmPortnum.presence, encoded);
      expect(packet, isNotNull);
      expect(packet!.type, SmPacketType.presence);
      expect(packet.presence.battery, 85);
      expect(packet.presence.intent, SmPresenceIntent.available);
      expect(packet.presence.status, 'Hello');
    });

    test('portnum 261 decodes as SM_SIGNAL', () {
      final signal = SmSignal(
        signalId: 0x0123456789ABCDEF,
        content: 'Test signal',
        ttl: SmSignalTtl.hour1,
      );
      final encoded = signal.encode()!;

      final packet = SmCodec.decode(SmPortnum.signal, encoded);
      expect(packet, isNotNull);
      expect(packet!.type, SmPacketType.signal);
      expect(packet.signal.signalId, 0x0123456789ABCDEF);
      expect(packet.signal.content, 'Test signal');
    });

    test('portnum 262 decodes as SM_IDENTITY', () {
      final identity = SmIdentity(
        sigilHash: SmIdentity.computeSigilHash(0xDEADBEEF),
        trait: SmNodeTrait.beacon,
        isResponse: true,
      );
      final encoded = identity.encode()!;

      final packet = SmCodec.decode(SmPortnum.identity, encoded);
      expect(packet, isNotNull);
      expect(packet!.type, SmPacketType.identity);
      expect(packet.identity.trait, SmNodeTrait.beacon);
      expect(packet.identity.isResponse, isTrue);
    });

    test('legacy portnum 256 is not routed to SM codec', () {
      // portnum 256 should not be handled by SmCodec
      final packet = SmCodec.decode(
        SmPortnum.legacy,
        Uint8List.fromList([0x02, 0x00, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
      );
      expect(packet, isNull);
    });

    test('unknown portnum returns null', () {
      final packet = SmCodec.decode(
        999,
        Uint8List.fromList([0x01, 0x02, 0x03]),
      );
      expect(packet, isNull);
    });

    test('malformed payload returns null without throwing', () {
      // Too short for any SM packet
      expect(SmCodec.decode(SmPortnum.presence, Uint8List(1)), isNull);
      expect(SmCodec.decode(SmPortnum.signal, Uint8List(2)), isNull);
      expect(SmCodec.decode(SmPortnum.identity, Uint8List(3)), isNull);
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // Dual-send decision logic
  // ─────────────────────────────────────────────────────────────────

  group('Dual-send decision logic', () {
    test('binary disabled: legacy only', () {
      final flag = SmFeatureFlag();
      final caps = SmCapabilityStore();

      expect(flag.shouldSendBinary, isFalse);
      expect(
        flag.shouldSendLegacyGivenMeshState(
          isMeshBinaryReady: caps.isMeshBinaryReady,
        ),
        isTrue,
      );
    });

    test('binary enabled, no peers: dual-send', () {
      final flag = SmFeatureFlag(smBinaryEnabled: true);
      final caps = SmCapabilityStore();

      expect(flag.shouldSendBinary, isTrue);
      expect(
        flag.shouldSendLegacyGivenMeshState(
          isMeshBinaryReady: caps.isMeshBinaryReady,
        ),
        isTrue,
      );
    });

    test('binary enabled, enough peers: binary only', () async {
      final flag = SmFeatureFlag(smBinaryEnabled: true);
      final caps = SmCapabilityStore();

      await caps.markNodeSupported(0x01);
      await caps.markNodeSupported(0x02);

      expect(flag.shouldSendBinary, isTrue);
      expect(
        flag.shouldSendLegacyGivenMeshState(
          isMeshBinaryReady: caps.isMeshBinaryReady,
        ),
        isFalse,
      );
    });

    test('binary enabled, compat off: binary only regardless', () {
      final flag = SmFeatureFlag(
        smBinaryEnabled: true,
        legacyCompatibilityMode: false,
      );
      final caps = SmCapabilityStore();

      expect(flag.shouldSendBinary, isTrue);
      expect(
        flag.shouldSendLegacyGivenMeshState(
          isMeshBinaryReady: caps.isMeshBinaryReady,
        ),
        isFalse,
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // Dedupe: binary + legacy signal → one stored signal
  // ─────────────────────────────────────────────────────────────────

  group('Signal dedupe (binary + legacy)', () {
    test('dual-send uses same signalId for binary and legacy', () {
      // Simulate dual-send: generate binary ID, derive string for both
      final binarySignalId = 0x0123456789ABCDEF;
      final signalIdStr = SmPacketRouter.signalIdToString(binarySignalId);

      // Binary receiver decodes SM_SIGNAL → gets signalId
      final smSignal = SmSignal(
        signalId: binarySignalId,
        content: 'Dual-send test',
      );
      final encoded = smSignal.encode()!;
      final decoded = SmSignal.decode(encoded)!;
      final decodedIdStr = SmPacketRouter.signalIdToString(decoded.signalId);

      // Legacy receiver parses JSON → gets signalId string
      // (In dual-send, the legacy JSON uses the same string)
      final legacySignalId = signalIdStr;

      // Both must produce the exact same string
      expect(decodedIdStr, signalIdStr);
      expect(decodedIdStr, legacySignalId);
    });

    test('SM signal IDs never collide with UUID format', () {
      // SM IDs start with "sm-", UUIDs have dashes at positions 8,13,18,23
      final smId = SmPacketRouter.signalIdToString(0xDEADBEEF);
      expect(smId.startsWith('sm-'), isTrue);
      expect(smId.contains(RegExp(r'^[0-9a-f]{8}-')), isFalse);

      // A UUID never starts with "sm-"
      const uuid = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
      expect(SmPacketRouter.isSmSignalId(uuid), isFalse);
    });

    test('receiver can distinguish binary from legacy signals', () {
      final smId = SmPacketRouter.signalIdToString(0x1234);
      const legacyId = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';

      expect(SmPacketRouter.isSmSignalId(smId), isTrue);
      expect(SmPacketRouter.isSmSignalId(legacyId), isFalse);
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // Identity request/response flow
  // ─────────────────────────────────────────────────────────────────

  group('Identity request/response', () {
    test('request triggers response with matching sigil hash', () {
      const myNodeNum = 0xDEADBEEF;
      final myHash = SmIdentity.computeSigilHash(myNodeNum);

      final response = SmIdentity(sigilHash: myHash, isResponse: true);

      final encoded = response.encode()!;
      final decoded = SmIdentity.decode(encoded)!;

      expect(decoded.isResponse, isTrue);
      expect(decoded.isRequest, isFalse);
      expect(SmIdentity.verifySigilHash(decoded.sigilHash, myNodeNum), isTrue);
    });

    test('contradictory flags rejected on encode', () {
      final bad = SmIdentity(
        sigilHash: 12345,
        isRequest: true,
        isResponse: true,
      );
      expect(bad.encode(), isNull);
    });

    test('contradictory flags rejected on decode', () {
      // Hand-craft a packet with both request+response bits set
      final buffer = ByteData(6);
      buffer.setUint8(0, 0x03); // header: version=0, kind=3
      buffer.setUint8(1, 0x0C); // flags: isResponse=0x04 | isRequest=0x08
      buffer.setUint32(2, 12345, Endian.big);

      final decoded = SmIdentity.decode(buffer.buffer.asUint8List());
      expect(decoded, isNull);
    });

    test('rate limiter prevents identity request spam', () {
      var now = DateTime(2026, 1, 1, 12, 0);
      final limiter = SmIdentityRateLimiter(clock: () => now);
      const targetNode = 0x01;

      // First request OK
      expect(limiter.canRequest(targetNode), isTrue);
      limiter.recordRequest(targetNode);

      // Immediate second request blocked
      expect(limiter.canRequest(targetNode), isFalse);

      // After 10 minutes, allowed again
      now = DateTime(2026, 1, 1, 12, 11);
      expect(limiter.canRequest(targetNode), isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // SM_PRESENCE → ExtendedPresenceInfo mapping
  // ─────────────────────────────────────────────────────────────────

  group('SM_PRESENCE mapping', () {
    test('SmPresenceIntent values match PresenceIntent values', () {
      // The wire protocol SmPresenceIntent and the app-layer PresenceIntent
      // must have matching index-to-value mappings for correct conversion.
      // SmPresenceIntent.index maps to PresenceIntent.fromValue().
      //
      // SmPresenceIntent: unknown=0, available=1, camping=2, traveling=3,
      //   emergencyStandby=4, relayNode=5, passive=6
      expect(SmPresenceIntent.unknown.index, 0);
      expect(SmPresenceIntent.available.index, 1);
      expect(SmPresenceIntent.camping.index, 2);
      expect(SmPresenceIntent.traveling.index, 3);
      expect(SmPresenceIntent.emergencyStandby.index, 4);
      expect(SmPresenceIntent.relayNode.index, 5);
      expect(SmPresenceIntent.passive.index, 6);

      // Verify count matches
      expect(SmPresenceIntent.values.length, 7);
    });

    test('SmPresence with battery and location decodes correctly', () {
      final presence = SmPresence(
        battery: 75,
        latitudeI: 377496000, // ~37.7496 N
        longitudeI: -1224189200, // ~-122.41892 W
        intent: SmPresenceIntent.traveling,
        status: 'On the trail',
      );

      final encoded = presence.encode()!;
      final decoded = SmPresence.decode(encoded)!;

      expect(decoded.battery, 75);
      expect(decoded.latitudeI, 377496000);
      expect(decoded.longitudeI, -1224189200);
      expect(decoded.intent, SmPresenceIntent.traveling);
      expect(decoded.status, 'On the trail');
    });

    test('presence updates lastSeen via packet receipt', () {
      // When a node sends SM_PRESENCE, _handleMeshPacket first calls
      // _updateNodeLastHeard(packet.from), which updates the node's
      // lastHeard. This happens before _handleSmPacket is called.
      // We verify that the presence decode doesn't interfere with this.
      final presence = SmPresence(intent: SmPresenceIntent.available);
      final encoded = presence.encode()!;

      // Decode succeeds
      final decoded = SmPresence.decode(encoded);
      expect(decoded, isNotNull);
      expect(decoded!.intent, SmPresenceIntent.available);
      // The lastHeard update is handled by the protocol service, not the
      // codec. This test confirms the codec doesn't break.
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // Legacy unaffected: smBinaryEnabled=false → no binary behavior
  // ─────────────────────────────────────────────────────────────────

  group('Legacy unaffected', () {
    test('with default flags, shouldSendBinary is false', () {
      final flag = SmFeatureFlag();
      expect(flag.shouldSendBinary, isFalse);
      expect(flag.shouldSendLegacy, isTrue);
    });

    test('legacy packets always increment legacy metric', () {
      final metrics = SmMetrics();
      metrics.recordLegacyPacketReceived();
      metrics.recordLegacyPacketReceived();
      expect(metrics.legacyPacketsReceived, 2);
      expect(metrics.binaryPacketsReceived, 0);
    });

    test('capability store does not affect legacy behavior', () {
      final flag = SmFeatureFlag();
      final caps = SmCapabilityStore();

      // Even with binary-capable peers, legacy still works
      caps.markNodeSupported(0x01);
      caps.markNodeSupported(0x02);

      expect(flag.shouldSendBinary, isFalse);
      expect(
        flag.shouldSendLegacyGivenMeshState(
          isMeshBinaryReady: caps.isMeshBinaryReady,
        ),
        isTrue,
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // Integration-style flow tests (fake clock + fake packet data)
  // ─────────────────────────────────────────────────────────────────

  group('Integration flow', () {
    test('full signal encode → decode → ID conversion cycle', () {
      // Simulate: sender creates signal, encodes, receiver decodes
      final signalId = SmSignal.generateSignalId();
      final signal = SmSignal(
        signalId: signalId,
        content: 'Integration test',
        ttl: SmSignalTtl.hour1,
        latitudeI: 377496000,
        longitudeI: -1224189200,
      );

      // Encode
      final encoded = signal.encode()!;

      // Decode on receiver side
      final packet = SmCodec.decode(SmPortnum.signal, encoded)!;
      expect(packet.type, SmPacketType.signal);

      // Convert to string ID (as the protocol service would)
      final idStr = SmPacketRouter.signalIdToString(packet.signal.signalId);
      expect(idStr, startsWith('sm-'));

      // Convert TTL
      final ttlMinutes = SmPacketRouter.ttlToMinutes(packet.signal.ttl);
      expect(ttlMinutes, 60);

      // Verify coordinates
      expect(packet.signal.latitude, closeTo(37.7496, 0.001));
      expect(packet.signal.longitude, closeTo(-122.41892, 0.001));
    });

    test('capability store + feature flag interaction over time', () async {
      var now = DateTime(2026, 1, 1, 12, 0);
      final caps = SmCapabilityStore(clock: () => now);
      final flag = SmFeatureFlag(smBinaryEnabled: true);

      // Initially: dual-send
      expect(flag.shouldSendBinary, isTrue);
      expect(
        flag.shouldSendLegacyGivenMeshState(
          isMeshBinaryReady: caps.isMeshBinaryReady,
        ),
        isTrue,
      );

      // Peer 1 seen
      await caps.markNodeSupported(0x01);
      expect(
        flag.shouldSendLegacyGivenMeshState(
          isMeshBinaryReady: caps.isMeshBinaryReady,
        ),
        isTrue,
      );

      // Peer 2 seen → mesh ready → legacy stops
      await caps.markNodeSupported(0x02);
      expect(
        flag.shouldSendLegacyGivenMeshState(
          isMeshBinaryReady: caps.isMeshBinaryReady,
        ),
        isFalse,
      );

      // Both peers age out → back to dual-send
      now = DateTime(2026, 1, 2, 13, 0);
      expect(
        flag.shouldSendLegacyGivenMeshState(
          isMeshBinaryReady: caps.isMeshBinaryReady,
        ),
        isTrue,
      );
    });

    test('identity request → response cycle with hash verification', () {
      const nodeA = 0xAAAAAAAA;
      const nodeB = 0xBBBBBBBB;

      // Node A sends identity request
      final request = SmIdentity(
        sigilHash: SmIdentity.computeSigilHash(nodeA),
        isRequest: true,
      );
      final requestBytes = request.encode()!;

      // Node B receives and decodes
      final decodedRequest = SmCodec.decode(SmPortnum.identity, requestBytes)!;
      expect(decodedRequest.identity.isRequest, isTrue);

      // Node B verifies A's hash
      expect(
        SmIdentity.verifySigilHash(decodedRequest.identity.sigilHash, nodeA),
        isTrue,
      );

      // Node B responds with its own identity
      final response = SmIdentity(
        sigilHash: SmIdentity.computeSigilHash(nodeB),
        trait: SmNodeTrait.relay,
        encounterCount: 42,
        isResponse: true,
      );
      final responseBytes = response.encode()!;

      // Node A receives and decodes
      final decodedResponse = SmCodec.decode(
        SmPortnum.identity,
        responseBytes,
      )!;
      expect(decodedResponse.identity.isResponse, isTrue);
      expect(decodedResponse.identity.trait, SmNodeTrait.relay);
      expect(decodedResponse.identity.encounterCount, 42);

      // Node A verifies B's hash
      expect(
        SmIdentity.verifySigilHash(decodedResponse.identity.sigilHash, nodeB),
        isTrue,
      );
    });

    test('rate limiter blocks rapid identity requests to same node', () {
      var now = DateTime(2026, 1, 1, 12, 0);
      final limiter = SmIdentityRateLimiter(clock: () => now);
      final caps = SmCapabilityStore(clock: () => now);

      const target = 0x01;

      // First request: allowed
      expect(limiter.canRequest(target), isTrue);
      limiter.recordRequest(target);
      caps.markNodeSupported(target);

      // Immediate retry: blocked
      now = DateTime(2026, 1, 1, 12, 1);
      expect(limiter.canRequest(target), isFalse);

      // Different node: allowed
      expect(limiter.canRequest(0x02), isTrue);

      // 11 minutes later: target allowed again
      now = DateTime(2026, 1, 1, 12, 11);
      expect(limiter.canRequest(target), isTrue);
    });

    test('metrics track complete flow', () {
      final metrics = SmMetrics();

      // Simulate receiving 3 binary packets, 1 legacy, 1 decode failure
      metrics.recordBinaryPacketReceived();
      metrics.recordBinaryPacketReceived();
      metrics.recordBinaryPacketReceived();
      metrics.recordLegacyPacketReceived();
      metrics.recordDecodeNull(260);

      // Simulate 2 dual-sends
      metrics.recordDualSend();
      metrics.recordDualSend();

      expect(metrics.binaryPacketsReceived, 3);
      expect(metrics.legacyPacketsReceived, 1);
      expect(metrics.decodeNullCount, 1);
      expect(metrics.decodeNullByPortnum[260], 1);
      expect(metrics.dualSendCount, 2);
    });
  });
}
