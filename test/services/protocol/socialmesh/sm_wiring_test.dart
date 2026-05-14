// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/socialmesh/sm_codec.dart';
import 'package:socialmesh/services/protocol/socialmesh/sm_constants.dart';
import 'package:socialmesh/services/protocol/socialmesh/sm_identity.dart';
import 'package:socialmesh/services/protocol/socialmesh/sm_metrics.dart';
import 'package:socialmesh/services/protocol/socialmesh/sm_packet_router.dart';
import 'package:socialmesh/services/protocol/socialmesh/sm_presence.dart';
import 'package:socialmesh/services/protocol/socialmesh/sm_signal.dart';

void main() {
  group('SmMetrics', () {
    test('starts at zero', () {
      final m = SmMetrics();
      expect(m.binaryPacketsReceived, 0);
      expect(m.decodeNullCount, 0);
      expect(m.decodeNullByPortnum, isEmpty);
    });

    test('records binary packets', () {
      final m = SmMetrics();
      m.recordBinaryPacketReceived();
      m.recordBinaryPacketReceived();
      expect(m.binaryPacketsReceived, 2);
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

    test('reset clears all counters', () {
      final m = SmMetrics();
      m.recordBinaryPacketReceived();
      m.recordDecodeNull(260);

      m.reset();

      expect(m.binaryPacketsReceived, 0);
      expect(m.decodeNullCount, 0);
      expect(m.decodeNullByPortnum, isEmpty);
    });

    test('toString includes counters', () {
      final m = SmMetrics();
      m.recordBinaryPacketReceived();
      final str = m.toString();
      expect(str, contains('binary=1'));
      expect(str, contains('decodeNull=0'));
    });
  });

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
      const originalId = -1;
      final str = SmPacketRouter.signalIdToString(originalId);
      final parsed = SmPacketRouter.signalIdFromString(str);
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

    test('SM signal IDs never collide with UUID format', () {
      final smId = SmPacketRouter.signalIdToString(0xDEADBEEF);
      expect(smId.startsWith('sm-'), isTrue);
      expect(smId.contains(RegExp(r'^[0-9a-f]{8}-')), isFalse);

      const uuid = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
      expect(SmPacketRouter.isSmSignalId(uuid), isFalse);
    });
  });

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

      now = DateTime(2026, 1, 1, 12, 5);
      expect(limiter.canRequest(0x01), isFalse);
    });

    test('allows request after interval expires', () {
      var now = DateTime(2026, 1, 1, 12, 0);
      final limiter = SmIdentityRateLimiter(clock: () => now);

      limiter.recordRequest(0x01);

      now = DateTime(2026, 1, 1, 12, 11);
      expect(limiter.canRequest(0x01), isTrue);
    });

    test('per-node rate limiting is independent', () {
      var now = DateTime(2026, 1, 1, 12, 0);
      final limiter = SmIdentityRateLimiter(clock: () => now);

      limiter.recordRequest(0x01);
      expect(limiter.canRequest(0x01), isFalse);
      expect(limiter.canRequest(0x02), isTrue);
    });

    test('cooldownRemaining returns correct duration', () {
      var now = DateTime(2026, 1, 1, 12, 0);
      final limiter = SmIdentityRateLimiter(clock: () => now);

      limiter.recordRequest(0x01);

      now = DateTime(2026, 1, 1, 12, 3);
      final remaining = limiter.cooldownRemaining(0x01);

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

    test('unknown portnum returns null', () {
      final packet = SmCodec.decode(
        999,
        Uint8List.fromList([0x01, 0x02, 0x03]),
      );
      expect(packet, isNull);
    });

    test('malformed payload returns null without throwing', () {
      expect(SmCodec.decode(SmPortnum.presence, Uint8List(1)), isNull);
      expect(SmCodec.decode(SmPortnum.signal, Uint8List(2)), isNull);
      expect(SmCodec.decode(SmPortnum.identity, Uint8List(3)), isNull);
    });
  });

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

      expect(limiter.canRequest(targetNode), isTrue);
      limiter.recordRequest(targetNode);

      expect(limiter.canRequest(targetNode), isFalse);

      now = DateTime(2026, 1, 1, 12, 11);
      expect(limiter.canRequest(targetNode), isTrue);
    });
  });

  group('SM_PRESENCE mapping', () {
    test('SmPresenceIntent values match PresenceIntent values', () {
      // SmPresenceIntent: unknown=0, available=1, camping=2, traveling=3,
      //   emergencyStandby=4, relayNode=5, passive=6
      expect(SmPresenceIntent.unknown.index, 0);
      expect(SmPresenceIntent.available.index, 1);
      expect(SmPresenceIntent.camping.index, 2);
      expect(SmPresenceIntent.traveling.index, 3);
      expect(SmPresenceIntent.emergencyStandby.index, 4);
      expect(SmPresenceIntent.relayNode.index, 5);
      expect(SmPresenceIntent.passive.index, 6);
      expect(SmPresenceIntent.values.length, 7);
    });

    test('SmPresence with battery and location decodes correctly', () {
      final presence = SmPresence(
        battery: 75,
        latitudeI: 377496000,
        longitudeI: -1224189200,
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
  });

  group('Integration flow', () {
    test('full signal encode then decode then ID conversion cycle', () {
      final signalId = SmSignal.generateSignalId();
      final signal = SmSignal(
        signalId: signalId,
        content: 'Integration test',
        ttl: SmSignalTtl.hour1,
        latitudeI: 377496000,
        longitudeI: -1224189200,
      );

      final encoded = signal.encode()!;

      final packet = SmCodec.decode(SmPortnum.signal, encoded)!;
      expect(packet.type, SmPacketType.signal);

      final idStr = SmPacketRouter.signalIdToString(packet.signal.signalId);
      expect(idStr, startsWith('sm-'));

      final ttlMinutes = SmPacketRouter.ttlToMinutes(packet.signal.ttl);
      expect(ttlMinutes, 60);

      expect(packet.signal.latitude, closeTo(37.7496, 0.001));
      expect(packet.signal.longitude, closeTo(-122.41892, 0.001));
    });

    test('identity request → response cycle with hash verification', () {
      const nodeA = 0xAAAAAAAA;
      const nodeB = 0xBBBBBBBB;

      final request = SmIdentity(
        sigilHash: SmIdentity.computeSigilHash(nodeA),
        isRequest: true,
      );
      final requestBytes = request.encode()!;

      final decodedRequest = SmCodec.decode(SmPortnum.identity, requestBytes)!;
      expect(decodedRequest.identity.isRequest, isTrue);

      expect(
        SmIdentity.verifySigilHash(decodedRequest.identity.sigilHash, nodeA),
        isTrue,
      );

      final response = SmIdentity(
        sigilHash: SmIdentity.computeSigilHash(nodeB),
        trait: SmNodeTrait.relay,
        encounterCount: 42,
        isResponse: true,
      );
      final responseBytes = response.encode()!;

      final decodedResponse = SmCodec.decode(
        SmPortnum.identity,
        responseBytes,
      )!;
      expect(decodedResponse.identity.isResponse, isTrue);
      expect(decodedResponse.identity.trait, SmNodeTrait.relay);
      expect(decodedResponse.identity.encounterCount, 42);

      expect(
        SmIdentity.verifySigilHash(decodedResponse.identity.sigilHash, nodeB),
        isTrue,
      );
    });

    test('rate limiter blocks rapid identity requests to same node', () {
      var now = DateTime(2026, 1, 1, 12, 0);
      final limiter = SmIdentityRateLimiter(clock: () => now);

      const target = 0x01;

      expect(limiter.canRequest(target), isTrue);
      limiter.recordRequest(target);

      now = DateTime(2026, 1, 1, 12, 1);
      expect(limiter.canRequest(target), isFalse);

      expect(limiter.canRequest(0x02), isTrue);

      now = DateTime(2026, 1, 1, 12, 11);
      expect(limiter.canRequest(target), isTrue);
    });

    test('metrics track receive + decode-failure flow', () {
      final metrics = SmMetrics();

      metrics.recordBinaryPacketReceived();
      metrics.recordBinaryPacketReceived();
      metrics.recordBinaryPacketReceived();
      metrics.recordDecodeNull(260);

      expect(metrics.binaryPacketsReceived, 3);
      expect(metrics.decodeNullCount, 1);
      expect(metrics.decodeNullByPortnum[260], 1);
    });
  });
}
