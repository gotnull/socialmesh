// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/socialmesh/sm_codec.dart';
import 'package:socialmesh/services/protocol/socialmesh/sm_constants.dart';
import 'package:socialmesh/services/protocol/socialmesh/sm_identity.dart';
import 'package:socialmesh/services/protocol/socialmesh/sm_presence.dart';
import 'package:socialmesh/services/protocol/socialmesh/sm_signal.dart';

void main() {
  group('SmConstants', () {
    test('portnum ranges are in private range', () {
      expect(SmPortnum.presence, greaterThanOrEqualTo(256));
      expect(SmPortnum.presence, lessThanOrEqualTo(511));
      expect(SmPortnum.signal, greaterThanOrEqualTo(256));
      expect(SmPortnum.signal, lessThanOrEqualTo(511));
      expect(SmPortnum.identity, greaterThanOrEqualTo(256));
      expect(SmPortnum.identity, lessThanOrEqualTo(511));
    });

    test('portnums do not collide with ATAK_FORWARDER', () {
      const atakForwarder = 257;
      expect(SmPortnum.presence, isNot(atakForwarder));
      expect(SmPortnum.signal, isNot(atakForwarder));
      expect(SmPortnum.identity, isNot(atakForwarder));
    });

    test('portnums are unique', () {
      final portnums = {
        SmPortnum.presence,
        SmPortnum.signal,
        SmPortnum.identity,
      };
      expect(portnums.length, 3);
    });

    test('isSocialmesh identifies correct portnums', () {
      expect(SmPortnum.isSocialmesh(SmPortnum.presence), isTrue);
      expect(SmPortnum.isSocialmesh(SmPortnum.signal), isTrue);
      expect(SmPortnum.isSocialmesh(SmPortnum.identity), isTrue);
      expect(SmPortnum.isSocialmesh(SmPortnum.legacy), isFalse);
      expect(SmPortnum.isSocialmesh(0), isFalse);
      expect(SmPortnum.isSocialmesh(257), isFalse);
      expect(SmPortnum.isSocialmesh(511), isFalse);
    });

    test('payload limits are within LoRa MTU', () {
      expect(
        SmPayloadLimit.presenceStatusMaxBytes,
        lessThan(SmPayloadLimit.loraMtu),
      );
      expect(
        SmPayloadLimit.signalContentMaxBytes,
        lessThan(SmPayloadLimit.loraMtu),
      );
    });
  });

  group('SmPresence', () {
    test('round-trip minimal packet (no optional fields)', () {
      const original = SmPresence(intent: SmPresenceIntent.available);

      final encoded = original.encode();
      expect(encoded, isNotNull);
      expect(encoded!.length, 3); // header + flags + statusLen

      final decoded = SmPresence.decode(encoded);
      expect(decoded, isNotNull);
      expect(decoded!.intent, SmPresenceIntent.available);
      expect(decoded.battery, isNull);
      expect(decoded.latitudeI, isNull);
      expect(decoded.longitudeI, isNull);
      expect(decoded.status, isNull);
    });

    test('round-trip full packet (all fields)', () {
      const original = SmPresence(
        battery: 75,
        latitudeI: 377749300, // ~37.7749 N
        longitudeI: -1224194200, // ~-122.4194 W
        intent: SmPresenceIntent.camping,
        status: 'Base camp Alpha',
      );

      final encoded = original.encode();
      expect(encoded, isNotNull);

      final decoded = SmPresence.decode(encoded!);
      expect(decoded, isNotNull);
      expect(decoded!.battery, 75);
      expect(decoded.latitudeI, 377749300);
      expect(decoded.longitudeI, -1224194200);
      expect(decoded.intent, SmPresenceIntent.camping);
      expect(decoded.status, 'Base camp Alpha');
    });

    test('round-trip with only battery', () {
      const original = SmPresence(
        battery: 42,
        intent: SmPresenceIntent.traveling,
      );

      final encoded = original.encode();
      expect(encoded, isNotNull);
      expect(encoded!.length, 4); // header + flags + battery + statusLen

      final decoded = SmPresence.decode(encoded);
      expect(decoded, isNotNull);
      expect(decoded!.battery, 42);
      expect(decoded.latitudeI, isNull);
      expect(decoded.intent, SmPresenceIntent.traveling);
    });

    test('round-trip with only location', () {
      const original = SmPresence(
        latitudeI: 0,
        longitudeI: 0,
        intent: SmPresenceIntent.relayNode,
      );

      final encoded = original.encode();
      expect(encoded, isNotNull);

      final decoded = SmPresence.decode(encoded!);
      expect(decoded, isNotNull);
      expect(decoded!.latitudeI, 0);
      expect(decoded.longitudeI, 0);
      expect(decoded.intent, SmPresenceIntent.relayNode);
    });

    test('all intent values round-trip', () {
      for (final intent in SmPresenceIntent.values) {
        final original = SmPresence(intent: intent);
        final encoded = original.encode();
        expect(encoded, isNotNull, reason: 'encode failed for $intent');
        final decoded = SmPresence.decode(encoded!);
        expect(decoded, isNotNull, reason: 'decode failed for $intent');
        expect(decoded!.intent, intent, reason: 'intent mismatch for $intent');
      }
    });

    test('battery value 255 decodes as null (reserved)', () {
      const original = SmPresence(battery: 255);
      final encoded = original.encode();
      final decoded = SmPresence.decode(encoded!);
      // 255 is the "unknown" sentinel, decoded as null
      expect(decoded!.battery, isNull);
    });

    test('status at max length encodes', () {
      final maxStatus = 'A' * SmPayloadLimit.presenceStatusMaxBytes;
      final original = SmPresence(status: maxStatus);
      final encoded = original.encode();
      expect(encoded, isNotNull);

      final decoded = SmPresence.decode(encoded!);
      expect(decoded!.status, maxStatus);
    });

    test('status exceeding max length returns null', () {
      final longStatus = 'A' * (SmPayloadLimit.presenceStatusMaxBytes + 1);
      final original = SmPresence(status: longStatus);
      expect(original.encode(), isNull);
    });

    test('max size packet fits in LoRa MTU', () {
      final maxStatus = 'A' * SmPayloadLimit.presenceStatusMaxBytes;
      const original = SmPresence(
        battery: 100,
        latitudeI: 900000000,
        longitudeI: 1800000000,
        intent: SmPresenceIntent.emergencyStandby,
        status: null,
      );
      final encoded = original.encode();
      expect(encoded, isNotNull);
      expect(encoded!.length, lessThanOrEqualTo(SmPayloadLimit.loraMtu));

      // Also test with max status
      final fullOriginal = SmPresence(
        battery: 100,
        latitudeI: 900000000,
        longitudeI: 1800000000,
        intent: SmPresenceIntent.emergencyStandby,
        status: maxStatus,
      );
      final fullEncoded = fullOriginal.encode();
      expect(fullEncoded, isNotNull);
      expect(fullEncoded!.length, lessThanOrEqualTo(SmPayloadLimit.loraMtu));
    });

    test('decode rejects empty data', () {
      expect(SmPresence.decode(Uint8List(0)), isNull);
    });

    test('decode rejects too-short data', () {
      expect(SmPresence.decode(Uint8List(1)), isNull);
      expect(SmPresence.decode(Uint8List(2)), isNull);
    });

    test('decode rejects unsupported version', () {
      // Version 15 (max), type 0
      final data = Uint8List.fromList([0xF1, 0x00, 0x00]);
      expect(SmPresence.decode(data), isNull);
    });

    test('decode rejects wrong packet kind', () {
      // kind=2 (signal) instead of kind=1 (presence)
      final data = Uint8List.fromList([0x02, 0x00, 0x00]);
      expect(SmPresence.decode(data), isNull);
      // kind=3 (identity)
      final data2 = Uint8List.fromList([0x03, 0x00, 0x00]);
      expect(SmPresence.decode(data2), isNull);
      // kind=0 (reserved)
      final data3 = Uint8List.fromList([0x00, 0x00, 0x00]);
      expect(SmPresence.decode(data3), isNull);
    });

    test('decode handles truncated location gracefully', () {
      // flags say has_location, but not enough bytes
      final data = Uint8List.fromList([0x01, 0x01, 0x00, 0x00]);
      expect(SmPresence.decode(data), isNull);
    });

    test('floating-point coordinate getters work', () {
      const p = SmPresence(latitudeI: 377749300, longitudeI: -1224194200);
      expect(p.latitude, closeTo(37.77493, 0.00001));
      expect(p.longitude, closeTo(-122.41942, 0.00001));
    });

    test('floating-point getters return null when no location', () {
      const p = SmPresence();
      expect(p.latitude, isNull);
      expect(p.longitude, isNull);
    });

    test('header byte is 0x01 (version 0, type 1)', () {
      const p = SmPresence();
      final encoded = p.encode()!;
      expect(encoded[0], 0x01);
    });

    test('unicode status round-trips', () {
      const original = SmPresence(status: 'Cafe\u0301');
      final encoded = original.encode();
      final decoded = SmPresence.decode(encoded!);
      expect(decoded!.status, 'Cafe\u0301');
    });
  });

  group('SmSignal', () {
    test('round-trip minimal packet', () {
      final original = SmSignal(signalId: 12345, content: 'Test signal');

      final encoded = original.encode();
      expect(encoded, isNotNull);

      final decoded = SmSignal.decode(encoded!);
      expect(decoded, isNotNull);
      expect(decoded!.signalId, 12345);
      expect(decoded.content, 'Test signal');
      expect(decoded.ttl, SmSignalTtl.hour1);
      expect(decoded.priority, SmSignalPriority.normal);
      expect(decoded.hasImage, isFalse);
      expect(decoded.latitudeI, isNull);
    });

    test('round-trip full packet', () {
      final original = SmSignal(
        signalId: 0x0102030405060708,
        content: 'Emergency beacon active',
        ttl: SmSignalTtl.hours24,
        priority: SmSignalPriority.emergency,
        hasImage: true,
        latitudeI: 377749300,
        longitudeI: -1224194200,
      );

      final encoded = original.encode();
      expect(encoded, isNotNull);

      final decoded = SmSignal.decode(encoded!);
      expect(decoded, isNotNull);
      expect(decoded!.signalId, 0x0102030405060708);
      expect(decoded.content, 'Emergency beacon active');
      expect(decoded.ttl, SmSignalTtl.hours24);
      expect(decoded.priority, SmSignalPriority.emergency);
      expect(decoded.hasImage, isTrue);
      expect(decoded.latitudeI, 377749300);
      expect(decoded.longitudeI, -1224194200);
    });

    test('all TTL values round-trip', () {
      for (final ttl in SmSignalTtl.values) {
        final original = SmSignal(signalId: 1, content: 'test', ttl: ttl);
        final decoded = SmSignal.decode(original.encode()!);
        expect(decoded!.ttl, ttl);
      }
    });

    test('all priority values round-trip', () {
      for (final priority in SmSignalPriority.values) {
        final original = SmSignal(
          signalId: 1,
          content: 'test',
          priority: priority,
        );
        final decoded = SmSignal.decode(original.encode()!);
        expect(decoded!.priority, priority);
      }
    });

    test('content at max length encodes', () {
      final maxContent = 'B' * SmPayloadLimit.signalContentMaxBytes;
      final original = SmSignal(signalId: 1, content: maxContent);
      final encoded = original.encode();
      expect(encoded, isNotNull);
      expect(encoded!.length, lessThanOrEqualTo(SmPayloadLimit.loraMtu));

      final decoded = SmSignal.decode(encoded);
      expect(decoded!.content, maxContent);
    });

    test('content exceeding max length returns null', () {
      final longContent = 'B' * (SmPayloadLimit.signalContentMaxBytes + 1);
      final original = SmSignal(signalId: 1, content: longContent);
      expect(original.encode(), isNull);
    });

    test('empty content round-trips', () {
      final original = SmSignal(signalId: 42, content: '');
      final decoded = SmSignal.decode(original.encode()!);
      expect(decoded!.content, '');
    });

    test('decode rejects too-short data', () {
      expect(SmSignal.decode(Uint8List(0)), isNull);
      expect(SmSignal.decode(Uint8List(5)), isNull);
      expect(SmSignal.decode(Uint8List(10)), isNull);
    });

    test('decode rejects unsupported version', () {
      final data = Uint8List.fromList([
        0xF1, 0x00, // header with version 15
        ...List.filled(9, 0), // rest of minimum packet
      ]);
      expect(SmSignal.decode(data), isNull);
    });

    test('decode rejects wrong packet kind', () {
      // kind=1 (presence) instead of kind=2 (signal)
      final data = Uint8List.fromList([
        0x01, 0x00, // header with kind=1
        ...List.filled(9, 0), // rest of minimum packet
      ]);
      expect(SmSignal.decode(data), isNull);
      // kind=3 (identity)
      final data2 = Uint8List.fromList([0x03, 0x00, ...List.filled(9, 0)]);
      expect(SmSignal.decode(data2), isNull);
    });

    test('header byte is 0x02 (version 0, type 2)', () {
      final s = SmSignal(signalId: 1, content: 'x');
      final encoded = s.encode()!;
      expect(encoded[0], 0x02);
    });

    test('generateSignalId produces non-zero values', () {
      final ids = List.generate(10, (_) => SmSignal.generateSignalId());
      expect(ids.where((id) => id != 0).length, greaterThan(0));
      // Very unlikely all are the same
      expect(ids.toSet().length, greaterThan(1));
    });

    test('smSignalTtlToDuration returns expected values', () {
      expect(
        smSignalTtlToDuration(SmSignalTtl.minutes15),
        const Duration(minutes: 15),
      );
      expect(
        smSignalTtlToDuration(SmSignalTtl.minutes30),
        const Duration(minutes: 30),
      );
      expect(
        smSignalTtlToDuration(SmSignalTtl.hour1),
        const Duration(hours: 1),
      );
      expect(
        smSignalTtlToDuration(SmSignalTtl.hours6),
        const Duration(hours: 6),
      );
      expect(
        smSignalTtlToDuration(SmSignalTtl.hours24),
        const Duration(hours: 24),
      );
    });

    test('smSignalPriorityToMeshPriority returns expected values', () {
      expect(smSignalPriorityToMeshPriority(SmSignalPriority.normal), 64);
      expect(smSignalPriorityToMeshPriority(SmSignalPriority.important), 70);
      expect(smSignalPriorityToMeshPriority(SmSignalPriority.urgent), 100);
      expect(smSignalPriorityToMeshPriority(SmSignalPriority.emergency), 110);
    });

    test('signal_id with high bit set round-trips exactly', () {
      // 0x8000000000000000 is the min negative int64 in Dart
      final original = SmSignal(signalId: -1, content: 'hi');
      final encoded = original.encode()!;
      final decoded = SmSignal.decode(encoded)!;
      expect(decoded.signalId, -1); // 0xFFFFFFFFFFFFFFFF

      // Arbitrary high-bit value
      final original2 = SmSignal(
        signalId: 0x8000000000000000.toSigned(64),
        content: 'x',
      );
      final decoded2 = SmSignal.decode(original2.encode()!)!;
      expect(decoded2.signalId, original2.signalId);
    });

    test('location with negative coordinates round-trips', () {
      final original = SmSignal(
        signalId: 99,
        content: 'South',
        latitudeI: -338688530, // ~-33.8689 S (Sydney)
        longitudeI: 1512093230, // ~151.2093 E
      );

      final decoded = SmSignal.decode(original.encode()!);
      expect(decoded!.latitudeI, -338688530);
      expect(decoded.longitudeI, 1512093230);
    });
  });

  group('SmIdentity', () {
    test('round-trip minimal packet (no optional fields)', () {
      const original = SmIdentity(sigilHash: 0xDEADBEEF);

      final encoded = original.encode();
      expect(encoded, isNotNull);
      expect(encoded!.length, 6); // header + flags + sigilHash

      final decoded = SmIdentity.decode(encoded);
      expect(decoded, isNotNull);
      expect(decoded!.sigilHash, 0xDEADBEEF);
      expect(decoded.trait, isNull);
      expect(decoded.encounterCount, isNull);
      expect(decoded.isRequest, isFalse);
      expect(decoded.isResponse, isFalse);
    });

    test('round-trip full packet', () {
      const original = SmIdentity(
        sigilHash: 0x12345678,
        trait: SmNodeTrait.sentinel,
        encounterCount: 1234,
        isResponse: true,
      );

      final encoded = original.encode();
      expect(encoded, isNotNull);
      expect(encoded!.length, 9); // header + flags + hash + trait + encounters

      final decoded = SmIdentity.decode(encoded);
      expect(decoded, isNotNull);
      expect(decoded!.sigilHash, 0x12345678);
      expect(decoded.trait, SmNodeTrait.sentinel);
      expect(decoded.encounterCount, 1234);
      expect(decoded.isResponse, isTrue);
      expect(decoded.isRequest, isFalse);
    });

    test('request flag round-trips', () {
      const original = SmIdentity(sigilHash: 0x11111111, isRequest: true);

      final decoded = SmIdentity.decode(original.encode()!);
      expect(decoded!.isRequest, isTrue);
      expect(decoded.isResponse, isFalse);
    });

    test('all trait values round-trip', () {
      for (final trait in SmNodeTrait.values) {
        final original = SmIdentity(sigilHash: 0xAAAAAAAA, trait: trait);
        final decoded = SmIdentity.decode(original.encode()!);
        expect(decoded!.trait, trait, reason: 'trait mismatch for $trait');
      }
    });

    test('encounter count at max value (65535)', () {
      const original = SmIdentity(sigilHash: 0xBBBBBBBB, encounterCount: 65535);
      final decoded = SmIdentity.decode(original.encode()!);
      expect(decoded!.encounterCount, 65535);
    });

    test('encounter count clamped above 65535', () {
      const original = SmIdentity(sigilHash: 0xCCCCCCCC, encounterCount: 70000);
      final decoded = SmIdentity.decode(original.encode()!);
      expect(decoded!.encounterCount, 65535);
    });

    test('computeSigilHash is deterministic', () {
      final hash1 = SmIdentity.computeSigilHash(123456);
      final hash2 = SmIdentity.computeSigilHash(123456);
      expect(hash1, hash2);
    });

    test('computeSigilHash produces different values for different nodes', () {
      final hash1 = SmIdentity.computeSigilHash(1);
      final hash2 = SmIdentity.computeSigilHash(2);
      expect(hash1, isNot(hash2));
    });

    test('verifySigilHash validates correctly', () {
      const nodeNum = 0x12345678;
      final hash = SmIdentity.computeSigilHash(nodeNum);
      expect(SmIdentity.verifySigilHash(hash, nodeNum), isTrue);
      expect(SmIdentity.verifySigilHash(hash, nodeNum + 1), isFalse);
    });

    test('computeSigilHash returns unsigned 32-bit', () {
      final hash = SmIdentity.computeSigilHash(0xFFFFFFFF);
      expect(hash, greaterThanOrEqualTo(0));
      expect(hash, lessThanOrEqualTo(0xFFFFFFFF));
    });

    test('decode rejects too-short data', () {
      expect(SmIdentity.decode(Uint8List(0)), isNull);
      expect(SmIdentity.decode(Uint8List(3)), isNull);
      expect(SmIdentity.decode(Uint8List(5)), isNull);
    });

    test('decode rejects unsupported version', () {
      final data = Uint8List.fromList([0xF1, 0x00, 0x00, 0x00, 0x00, 0x00]);
      expect(SmIdentity.decode(data), isNull);
    });

    test('decode rejects wrong packet kind', () {
      // kind=1 (presence) instead of kind=3 (identity)
      final data = Uint8List.fromList([0x01, 0x00, 0x00, 0x00, 0x00, 0x00]);
      expect(SmIdentity.decode(data), isNull);
      // kind=2 (signal)
      final data2 = Uint8List.fromList([0x02, 0x00, 0x00, 0x00, 0x00, 0x00]);
      expect(SmIdentity.decode(data2), isNull);
    });

    test('header byte is 0x03 (version 0, type 3)', () {
      const id = SmIdentity(sigilHash: 0);
      final encoded = id.encode()!;
      expect(encoded[0], 0x03);
    });

    test('decode handles truncated trait gracefully', () {
      // flags say has_trait, but no trait byte
      final data = Uint8List.fromList([0x03, 0x01, 0x00, 0x00, 0x00, 0x00]);
      expect(SmIdentity.decode(data), isNull);
    });

    test('decode handles truncated encounter count gracefully', () {
      // flags say has_encounters, but no encounter bytes
      final data = Uint8List.fromList([0x03, 0x02, 0x00, 0x00, 0x00, 0x00]);
      expect(SmIdentity.decode(data), isNull);
    });

    test('unknown trait index defaults to unknown', () {
      // Manually craft a packet with trait index 255 (out of range)
      final data = Uint8List.fromList([
        0x03, // header
        0x01, // flags: has_trait
        0x00, 0x00, 0x00, 0x01, // sigilHash
        0xFF, // invalid trait index
      ]);
      final decoded = SmIdentity.decode(data);
      expect(decoded, isNotNull);
      expect(decoded!.trait, SmNodeTrait.unknown);
    });

    test('all packets fit in LoRa MTU', () {
      const maxPacket = SmIdentity(
        sigilHash: 0xFFFFFFFF,
        trait: SmNodeTrait.drifter,
        encounterCount: 65535,
        isResponse: true,
      );
      final encoded = maxPacket.encode()!;
      expect(encoded.length, 9); // maximum size
      expect(encoded.length, lessThanOrEqualTo(SmPayloadLimit.loraMtu));
    });

    test('encode rejects contradictory flags (isRequest + isResponse)', () {
      const invalid = SmIdentity(
        sigilHash: 0x12345678,
        trait: SmNodeTrait.beacon,
        isRequest: true,
        isResponse: true,
      );
      expect(invalid.encode(), isNull);
    });

    test('decode rejects contradictory flags (isRequest + isResponse)', () {
      // Craft raw bytes with flags 0x0C (bits 2 + 3 set)
      final data = Uint8List.fromList([
        0x03, // header: version=0, kind=3
        0x0C, // flags: is_response=1 (bit 2), is_request=1 (bit 3)
        0x00, 0x00, 0x00, 0x01, // sigilHash
      ]);
      expect(SmIdentity.decode(data), isNull);
    });

    test('decode accepts valid flag combinations', () {
      // Unsolicited: is_request=0, is_response=0
      final unsolicited = Uint8List.fromList([
        0x03,
        0x00,
        0x00,
        0x00,
        0x00,
        0x01,
      ]);
      expect(SmIdentity.decode(unsolicited), isNotNull);
      expect(SmIdentity.decode(unsolicited)!.isRequest, isFalse);
      expect(SmIdentity.decode(unsolicited)!.isResponse, isFalse);

      // Request: is_request=1, is_response=0
      final request = Uint8List.fromList([0x03, 0x08, 0x00, 0x00, 0x00, 0x01]);
      expect(SmIdentity.decode(request), isNotNull);
      expect(SmIdentity.decode(request)!.isRequest, isTrue);
      expect(SmIdentity.decode(request)!.isResponse, isFalse);

      // Response: is_request=0, is_response=1
      final response = Uint8List.fromList([0x03, 0x04, 0x00, 0x00, 0x00, 0x01]);
      expect(SmIdentity.decode(response), isNotNull);
      expect(SmIdentity.decode(response)!.isRequest, isFalse);
      expect(SmIdentity.decode(response)!.isResponse, isTrue);
    });
  });

  group('SmCodec', () {
    test('isSocialmeshPortnum delegates correctly', () {
      expect(SmCodec.isSocialmeshPortnum(260), isTrue);
      expect(SmCodec.isSocialmeshPortnum(261), isTrue);
      expect(SmCodec.isSocialmeshPortnum(262), isTrue);
      expect(SmCodec.isSocialmeshPortnum(256), isFalse);
      expect(SmCodec.isSocialmeshPortnum(0), isFalse);
    });

    test('decode routes presence correctly', () {
      const presence = SmPresence(intent: SmPresenceIntent.available);
      final encoded = presence.encode()!;

      final packet = SmCodec.decode(SmPortnum.presence, encoded);
      expect(packet, isNotNull);
      expect(packet!.type, SmPacketType.presence);
      expect(packet.presence.intent, SmPresenceIntent.available);
    });

    test('decode routes signal correctly', () {
      final signal = SmSignal(signalId: 42, content: 'hello');
      final encoded = signal.encode()!;

      final packet = SmCodec.decode(SmPortnum.signal, encoded);
      expect(packet, isNotNull);
      expect(packet!.type, SmPacketType.signal);
      expect(packet.signal.content, 'hello');
    });

    test('decode routes identity correctly', () {
      const identity = SmIdentity(sigilHash: 0xDEAD);
      final encoded = identity.encode()!;

      final packet = SmCodec.decode(SmPortnum.identity, encoded);
      expect(packet, isNotNull);
      expect(packet!.type, SmPacketType.identity);
      expect(packet.identity.sigilHash, 0xDEAD);
    });

    test('decode returns null for unknown portnum', () {
      final data = Uint8List.fromList([0x01, 0x00, 0x00]);
      expect(SmCodec.decode(999, data), isNull);
    });

    test('decode returns null for malformed data', () {
      expect(SmCodec.decode(SmPortnum.presence, Uint8List(0)), isNull);
      expect(SmCodec.decode(SmPortnum.signal, Uint8List(0)), isNull);
      expect(SmCodec.decode(SmPortnum.identity, Uint8List(0)), isNull);
    });

    test('encode helpers produce valid packets', () {
      const p = SmPresence(intent: SmPresenceIntent.passive);
      expect(SmCodec.encodePresence(p), isNotNull);

      final s = SmSignal(signalId: 1, content: 'x');
      expect(SmCodec.encodeSignal(s), isNotNull);

      const i = SmIdentity(sigilHash: 1);
      expect(SmCodec.encodeIdentity(i), isNotNull);
    });
  });

  group('SmRateLimiter', () {
    test('allows first send', () {
      final limiter = SmRateLimiter();
      expect(limiter.canSend(SmPortnum.presence), isTrue);
      expect(limiter.canSend(SmPortnum.signal), isTrue);
      expect(limiter.canSend(SmPortnum.identity), isTrue);
    });

    test('blocks after send within interval', () {
      final limiter = SmRateLimiter();
      limiter.recordSend(SmPortnum.signal);
      expect(limiter.canSend(SmPortnum.signal), isFalse);
      // Other portnums should still be allowed
      expect(limiter.canSend(SmPortnum.presence), isTrue);
    });

    test('cooldownRemaining returns Duration.zero when no prior send', () {
      final limiter = SmRateLimiter();
      expect(limiter.cooldownRemaining(SmPortnum.presence), Duration.zero);
    });

    test('cooldownRemaining returns positive after send', () {
      final limiter = SmRateLimiter();
      limiter.recordSend(SmPortnum.presence);
      final remaining = limiter.cooldownRemaining(SmPortnum.presence);
      expect(remaining, greaterThan(Duration.zero));
    });

    test('reset clears all state', () {
      final limiter = SmRateLimiter();
      limiter.recordSend(SmPortnum.presence);
      limiter.recordSend(SmPortnum.signal);
      limiter.recordSend(SmPortnum.identity);
      limiter.reset();
      expect(limiter.canSend(SmPortnum.presence), isTrue);
      expect(limiter.canSend(SmPortnum.signal), isTrue);
      expect(limiter.canSend(SmPortnum.identity), isTrue);
    });
  });

  group('Fuzz / robustness', () {
    test('SmPresence.decode handles random bytes without crashing', () {
      final rng = Random(42); // deterministic seed
      for (var i = 0; i < 100; i++) {
        final len = rng.nextInt(50);
        final bytes = Uint8List.fromList(
          List.generate(len, (_) => rng.nextInt(256)),
        );
        // Should return null or a valid object, never throw
        SmPresence.decode(bytes);
      }
    });

    test('SmSignal.decode handles random bytes without crashing', () {
      final rng = Random(43);
      for (var i = 0; i < 100; i++) {
        final len = rng.nextInt(50);
        final bytes = Uint8List.fromList(
          List.generate(len, (_) => rng.nextInt(256)),
        );
        SmSignal.decode(bytes);
      }
    });

    test('SmIdentity.decode handles random bytes without crashing', () {
      final rng = Random(44);
      for (var i = 0; i < 100; i++) {
        final len = rng.nextInt(50);
        final bytes = Uint8List.fromList(
          List.generate(len, (_) => rng.nextInt(256)),
        );
        SmIdentity.decode(bytes);
      }
    });

    test('SmCodec.decode handles random bytes for all portnums', () {
      final rng = Random(45);
      for (final portnum in [
        SmPortnum.presence,
        SmPortnum.signal,
        SmPortnum.identity,
      ]) {
        for (var i = 0; i < 50; i++) {
          final len = rng.nextInt(50);
          final bytes = Uint8List.fromList(
            List.generate(len, (_) => rng.nextInt(256)),
          );
          SmCodec.decode(portnum, bytes);
        }
      }
    });
  });

  group('Wire format invariants', () {
    test('presence header version nibble is 0', () {
      const p = SmPresence();
      final encoded = p.encode()!;
      expect((encoded[0] >> 4) & 0x0F, 0);
    });

    test('signal header version nibble is 0', () {
      final s = SmSignal(signalId: 1, content: '');
      final encoded = s.encode()!;
      expect((encoded[0] >> 4) & 0x0F, 0);
    });

    test('identity header version nibble is 0', () {
      const i = SmIdentity(sigilHash: 0);
      final encoded = i.encode()!;
      expect((encoded[0] >> 4) & 0x0F, 0);
    });

    test('each packet type has a unique type nibble', () {
      const p = SmPresence();
      final s = SmSignal(signalId: 1, content: '');
      const i = SmIdentity(sigilHash: 0);

      final pType = p.encode()![0] & 0x0F;
      final sType = s.encode()![0] & 0x0F;
      final iType = i.encode()![0] & 0x0F;

      expect({pType, sType, iType}.length, 3);
    });

    test('sigil hash big-endian byte order', () {
      const id = SmIdentity(sigilHash: 0x01020304);
      final encoded = id.encode()!;
      // Bytes 2-5 are the sigil hash in big-endian
      expect(encoded[2], 0x01);
      expect(encoded[3], 0x02);
      expect(encoded[4], 0x03);
      expect(encoded[5], 0x04);
    });

    test('signal ID big-endian byte order', () {
      final s = SmSignal(signalId: 0x0102030405060708, content: '');
      final encoded = s.encode()!;
      // Bytes 2-9 are the signal ID in big-endian
      expect(encoded[2], 0x01);
      expect(encoded[3], 0x02);
      expect(encoded[4], 0x03);
      expect(encoded[5], 0x04);
      expect(encoded[6], 0x05);
      expect(encoded[7], 0x06);
      expect(encoded[8], 0x07);
      expect(encoded[9], 0x08);
    });
  });

  // ---------------------------------------------------------------------------
  // Wire drift guards
  //
  // These tests pin spec-critical constants and encoding invariants so that
  // docs and code cannot silently diverge. If a spec value changes, a developer
  // must consciously update both the code constant and the corresponding test.
  // ---------------------------------------------------------------------------
  group('Wire drift guards', () {
    // -- 1) Portnums (PACKET_TYPES.md "Packet Kind Values") ----------------
    test('portnum constants match spec values', () {
      expect(SmPortnum.presence, 260, reason: 'SM_PRESENCE portnum');
      expect(SmPortnum.signal, 261, reason: 'SM_SIGNAL portnum');
      expect(SmPortnum.identity, 262, reason: 'SM_IDENTITY portnum');
      expect(SmPortnum.legacy, 256, reason: 'SM_LEGACY portnum');
    });

    // -- 2) Packet kinds (hdr0 low nibble) ---------------------------------
    test('packet kind constants match spec values', () {
      expect(SmPacketKind.presence, 1, reason: 'presence kind');
      expect(SmPacketKind.signal, 2, reason: 'signal kind');
      expect(SmPacketKind.identity, 3, reason: 'identity kind');
    });

    // -- 3) Max byte lengths -----------------------------------------------
    test('payload limit constants match spec values', () {
      // PACKET_TYPES.md "SM_PRESENCE" status field: max 63 bytes
      expect(
        SmPayloadLimit.presenceStatusMaxBytes,
        63,
        reason: 'presence status max bytes',
      );
      // PACKET_TYPES.md "SM_SIGNAL" content field: max 140 bytes
      expect(
        SmPayloadLimit.signalContentMaxBytes,
        140,
        reason: 'signal content max bytes',
      );
      // PACKET_TYPES.md "Byte Budget Summary": LoRa MTU ceiling 237 B
      expect(SmPayloadLimit.loraMtu, 237, reason: 'LoRa MTU ceiling');
    });

    // -- 4a) Encoding invariants: SM_PRESENCE ------------------------------
    test('presence encodes correct hdr0 and minimum length', () {
      // PACKET_TYPES.md: hdr0 = (version << 4) | 1 = 0x01 for v0
      // Minimum: hdr0 + flags + status_len = 3 bytes
      const p = SmPresence();
      final encoded = p.encode()!;

      expect(encoded[0], 0x01, reason: 'hdr0 = version 0, kind 1');
      expect(
        encoded.length,
        greaterThanOrEqualTo(3),
        reason: 'minimum presence packet is 3 bytes',
      );
      // flags byte exists at offset 1
      expect(encoded.length, greaterThan(1), reason: 'flags byte present');
    });

    // -- 4b) Encoding invariants: SM_SIGNAL --------------------------------
    test('signal encodes correct hdr0 and minimum length', () {
      // PACKET_TYPES.md: hdr0 = (version << 4) | 2 = 0x02 for v0
      // Minimum: hdr0(1) + flags(1) + signalId(8) + contentLen(1) = 11 bytes
      final s = SmSignal(signalId: 0, content: '');
      final encoded = s.encode()!;

      expect(encoded[0], 0x02, reason: 'hdr0 = version 0, kind 2');
      expect(
        encoded.length,
        greaterThanOrEqualTo(11),
        reason: 'minimum signal packet is 11 bytes',
      );
    });

    // -- 4c) Encoding invariants: SM_IDENTITY ------------------------------
    test('identity encodes correct hdr0 and minimum length', () {
      // PACKET_TYPES.md: hdr0 = (version << 4) | 3 = 0x03 for v0
      // Minimum: hdr0(1) + flags(1) + sigilHash(4) = 6 bytes
      const i = SmIdentity(sigilHash: 0);
      final encoded = i.encode()!;

      expect(encoded[0], 0x03, reason: 'hdr0 = version 0, kind 3');
      expect(
        encoded.length,
        greaterThanOrEqualTo(6),
        reason: 'minimum identity packet is 6 bytes',
      );
    });

    // -- 4d) Decode rejects wrong kind nibble (consolidated) ---------------
    test('each decoder rejects payloads with wrong packet kind', () {
      // Presence: valid length, wrong kind (signal=2)
      expect(
        SmPresence.decode(Uint8List.fromList([0x02, 0x00, 0x00])),
        isNull,
        reason: 'presence decoder must reject kind=2',
      );
      // Signal: valid length, wrong kind (presence=1)
      expect(
        SmSignal.decode(Uint8List.fromList([0x01, 0x00, ...List.filled(9, 0)])),
        isNull,
        reason: 'signal decoder must reject kind=1',
      );
      // Identity: valid length, wrong kind (signal=2)
      expect(
        SmIdentity.decode(
          Uint8List.fromList([0x02, 0x00, 0x00, 0x00, 0x00, 0x00]),
        ),
        isNull,
        reason: 'identity decoder must reject kind=2',
      );
    });

    // -- 5a) Endianness: signal ID -----------------------------------------
    test('signal ID encodes as big-endian at offset 2', () {
      // PACKET_TYPES.md "Encoding Reference": all multi-byte ints big-endian
      final s = SmSignal(signalId: 0x0102030405060708, content: '');
      final encoded = s.encode()!;

      // Bytes 2-9: signal_id in big-endian
      expect(encoded[2], 0x01);
      expect(encoded[3], 0x02);
      expect(encoded[4], 0x03);
      expect(encoded[5], 0x04);
      expect(encoded[6], 0x05);
      expect(encoded[7], 0x06);
      expect(encoded[8], 0x07);
      expect(encoded[9], 0x08);
    });

    // -- 5b) Endianness: sigil hash ----------------------------------------
    test('sigil hash encodes as big-endian at offset 2', () {
      // PACKET_TYPES.md "Encoding Reference": uint32 big-endian
      const i = SmIdentity(sigilHash: 0x0A0B0C0D);
      final encoded = i.encode()!;

      // Bytes 2-5: sigil_hash in big-endian
      expect(encoded[2], 0x0A);
      expect(encoded[3], 0x0B);
      expect(encoded[4], 0x0C);
      expect(encoded[5], 0x0D);
    });

    // -- Protocol version --------------------------------------------------
    test('protocol version constants are consistent', () {
      expect(SmVersion.current, 0, reason: 'current version is 0');
      expect(
        SmVersion.maxSupported,
        greaterThanOrEqualTo(SmVersion.current),
        reason: 'maxSupported >= current',
      );
    });

    // -- Portnum set completeness ------------------------------------------
    test('SmPortnum.all contains exactly the 3 extension portnums', () {
      expect(SmPortnum.all, {260, 261, 262});
      expect(
        SmPortnum.all.contains(SmPortnum.legacy),
        isFalse,
        reason: 'legacy portnum is not in the extension set',
      );
    });
  });
}
