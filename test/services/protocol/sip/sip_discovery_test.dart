// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/sip/sip_codec.dart';
import 'package:socialmesh/services/protocol/sip/sip_constants.dart';
import 'package:socialmesh/services/protocol/sip/sip_discovery.dart';
import 'package:socialmesh/services/protocol/sip/sip_frame.dart';
import 'package:socialmesh/services/protocol/sip/sip_messages_cap.dart';
import 'package:socialmesh/services/protocol/sip/sip_rate_limiter.dart';
import 'package:socialmesh/services/protocol/sip/sip_types.dart';

void main() {
  late SipRateLimiter rateLimiter;
  late SipDiscovery discovery;
  late int nowMs;

  setUp(() {
    nowMs = 1700000000000;
    rateLimiter = SipRateLimiter(
      clock: () => DateTime.fromMillisecondsSinceEpoch(nowMs),
    );
    discovery = SipDiscovery(
      rateLimiter: rateLimiter,
      localNodeId: 0xAAAA,
      clock: () => nowMs,
      beaconJitterMs: 0, // Deterministic for testing.
    );
    // Enable discoverable so functional tests aren't blocked by privacy gate.
    discovery.isDiscoverable = true;
  });

  group('SipDiscovery', () {
    group('CAP_BEACON', () {
      test('buildBeacon produces valid frame', () {
        final outbound = discovery.buildBeacon(force: true);
        expect(outbound, isNotNull);
        expect(outbound!.encoded.length, greaterThan(0));

        final decoded = SipCodec.decode(outbound.encoded);
        expect(decoded, isNotNull);
        expect(decoded!.msgType, SipMessageType.capBeacon);

        final beacon = SipCapMessages.decodeCapBeacon(decoded.payload);
        expect(beacon, isNotNull);
        expect(beacon!.features, SipFeatureBits.allV01);
        expect(beacon.deviceClass, 1);
        expect(beacon.mtuHint, SipConstants.sipMaxPayload);
      });

      test('buildBeacon rate-limited by interval', () {
        final first = discovery.buildBeacon(force: true);
        expect(first, isNotNull);

        // Immediately after, should be null (not enough time elapsed).
        final second = discovery.buildBeacon();
        expect(second, isNull);
      });

      test('buildBeacon allowed after interval', () {
        final first = discovery.buildBeacon(force: true);
        expect(first, isNotNull);

        nowMs += 301 * 1000; // Past the 300s interval.

        final second = discovery.buildBeacon();
        expect(second, isNotNull);
      });

      test('buildBeacon suppressed when budget exhausted', () {
        // Exhaust the budget.
        while (rateLimiter.canSend(32)) {
          rateLimiter.recordSend(32);
        }

        final outbound = discovery.buildBeacon(force: true);
        expect(outbound, isNull);
      });

      test('buildBeacon records send against budget', () {
        final before = rateLimiter.remainingBytes;
        final outbound = discovery.buildBeacon(force: true);
        expect(outbound, isNotNull);
        expect(rateLimiter.remainingBytes, lessThan(before));
      });
    });

    group('ROLLCALL_REQ', () {
      test('buildRollcallReq produces valid frame', () {
        final outbound = discovery.buildRollcallReq();
        expect(outbound, isNotNull);

        final decoded = SipCodec.decode(outbound!.encoded);
        expect(decoded, isNotNull);
        expect(decoded!.msgType, SipMessageType.rollcallReq);
        expect(decoded.payloadLen, 0);
      });

      test('buildRollcallReq rate-limited to 1 per 60s', () {
        final first = discovery.buildRollcallReq();
        expect(first, isNotNull);

        nowMs += 30 * 1000; // Only 30s.

        final second = discovery.buildRollcallReq();
        expect(second, isNull);
      });

      test('buildRollcallReq allowed after cooldown', () {
        final first = discovery.buildRollcallReq();
        expect(first, isNotNull);

        // Advance past cooldown (60s) + max jitter (5s).
        nowMs += 66 * 1000;

        final second = discovery.buildRollcallReq();
        expect(second, isNotNull);
      });
    });

    group('ROLLCALL_RESP', () {
      test('buildRollcallResp produces valid frame', () {
        final outbound = discovery.buildRollcallResp(0xBBBB);
        expect(outbound, isNotNull);

        final decoded = SipCodec.decode(outbound!.encoded);
        expect(decoded, isNotNull);
        expect(decoded!.msgType, SipMessageType.rollcallResp);
        expect(decoded.flags & SipFlags.isResponse, isNonZero);
      });

      test('buildRollcallResp rate-limited per peer', () {
        final first = discovery.buildRollcallResp(0xBBBB);
        expect(first, isNotNull);

        // Same peer within 60s -> null.
        nowMs += 30 * 1000;
        final second = discovery.buildRollcallResp(0xBBBB);
        expect(second, isNull);

        // Different peer -> allowed.
        final third = discovery.buildRollcallResp(0xCCCC);
        expect(third, isNotNull);
      });

      test('handleRollcallReq ignores self', () {
        final result = discovery.handleRollcallReq(0xAAAA); // Local node.
        expect(result, isNull);
      });

      test('handleRollcallReq produces response for remote peer', () {
        final result = discovery.handleRollcallReq(0xBBBB);
        expect(result, isNotNull);
      });
    });

    group('Inbound handling', () {
      SipFrame makeBeaconFrame(int features) {
        final beacon = SipCapBeacon(
          features: features,
          deviceClass: 1,
          maxProtoMinor: 1,
          mtuHint: 215,
          rxWindowS: 10,
        );
        final payload = SipCapMessages.encodeCapBeacon(beacon);
        return SipFrame(
          versionMajor: 0,
          versionMinor: 1,
          msgType: SipMessageType.capBeacon,
          flags: 0,
          headerLen: SipConstants.sipWrapperMin,
          sessionId: 0,
          nonce: 12345,
          timestampS: nowMs ~/ 1000,
          payloadLen: payload.length,
          payload: payload,
        );
      }

      test('handleBeacon adds peer to cache', () {
        final frame = makeBeaconFrame(SipFeatureBits.allV01);
        discovery.handleBeacon(frame, 0xBBBB);

        expect(discovery.peerCount, 1);
        final peer = discovery.getPeer(0xBBBB);
        expect(peer, isNotNull);
        expect(peer!.features, SipFeatureBits.allV01);
        expect(peer.supportsSip1, isTrue);
        expect(peer.supportsSip3, isTrue);
      });

      test('handleBeacon updates existing peer', () {
        final frame1 = makeBeaconFrame(SipFeatureBits.sip0);
        discovery.handleBeacon(frame1, 0xBBBB);
        expect(discovery.getPeer(0xBBBB)!.features, SipFeatureBits.sip0);

        nowMs += 1000;

        final frame2 = makeBeaconFrame(SipFeatureBits.allV01);
        discovery.handleBeacon(frame2, 0xBBBB);

        // Still 1 peer, but updated.
        expect(discovery.peerCount, 1);
        expect(discovery.getPeer(0xBBBB)!.features, SipFeatureBits.allV01);
      });

      test('handleRollcallResp adds peer to cache', () {
        final beacon = SipCapBeacon(
          features: SipFeatureBits.allV01,
          deviceClass: 1,
          maxProtoMinor: 1,
          mtuHint: 215,
          rxWindowS: 10,
        );
        final resp = SipRollcallResp(
          capabilities: beacon,
          capsHash: SipCapMessages.computeCapsHash(beacon),
        );
        final payload = SipCapMessages.encodeRollcallResp(resp);

        final frame = SipFrame(
          versionMajor: 0,
          versionMinor: 1,
          msgType: SipMessageType.rollcallResp,
          flags: SipFlags.isResponse,
          headerLen: SipConstants.sipWrapperMin,
          sessionId: 0,
          nonce: 12345,
          timestampS: nowMs ~/ 1000,
          payloadLen: payload.length,
          payload: payload,
        );

        discovery.handleRollcallResp(frame, 0xCCCC);
        expect(discovery.peerCount, 1);
        expect(discovery.getPeer(0xCCCC), isNotNull);
      });
    });

    group('Cache management', () {
      test('evicts oldest when full', () {
        // Create a discovery with maxPeers=3.
        final small = SipDiscovery(
          rateLimiter: rateLimiter,
          localNodeId: 0xAAAA,
          clock: () => nowMs,
          maxPeers: 3,
        );

        for (var i = 0; i < 3; i++) {
          nowMs += 1000;
          final beacon = SipCapBeacon(
            features: SipFeatureBits.allV01,
            deviceClass: 1,
            maxProtoMinor: 1,
            mtuHint: 215,
            rxWindowS: 10,
          );
          final payload = SipCapMessages.encodeCapBeacon(beacon);
          final frame = SipFrame(
            versionMajor: 0,
            versionMinor: 1,
            msgType: SipMessageType.capBeacon,
            flags: 0,
            headerLen: SipConstants.sipWrapperMin,
            sessionId: 0,
            nonce: i,
            timestampS: nowMs ~/ 1000,
            payloadLen: payload.length,
            payload: payload,
          );
          small.handleBeacon(frame, 0x1000 + i);
        }

        expect(small.peerCount, 3);

        // Add one more -> should evict oldest (0x1000).
        nowMs += 1000;
        final beacon = SipCapBeacon(
          features: SipFeatureBits.allV01,
          deviceClass: 1,
          maxProtoMinor: 1,
          mtuHint: 215,
          rxWindowS: 10,
        );
        final payload = SipCapMessages.encodeCapBeacon(beacon);
        final frame = SipFrame(
          versionMajor: 0,
          versionMinor: 1,
          msgType: SipMessageType.capBeacon,
          flags: 0,
          headerLen: SipConstants.sipWrapperMin,
          sessionId: 0,
          nonce: 999,
          timestampS: nowMs ~/ 1000,
          payloadLen: payload.length,
          payload: payload,
        );
        small.handleBeacon(frame, 0x9999);

        expect(small.peerCount, 3);
        expect(small.getPeer(0x1000), isNull); // Evicted.
        expect(small.getPeer(0x9999), isNotNull);
      });

      test('evictExpired removes stale entries', () {
        final beacon = SipCapBeacon(
          features: SipFeatureBits.allV01,
          deviceClass: 1,
          maxProtoMinor: 1,
          mtuHint: 215,
          rxWindowS: 10,
        );
        final payload = SipCapMessages.encodeCapBeacon(beacon);
        final frame = SipFrame(
          versionMajor: 0,
          versionMinor: 1,
          msgType: SipMessageType.capBeacon,
          flags: 0,
          headerLen: SipConstants.sipWrapperMin,
          sessionId: 0,
          nonce: 1,
          timestampS: nowMs ~/ 1000,
          payloadLen: payload.length,
          payload: payload,
        );
        discovery.handleBeacon(frame, 0xBBBB);
        expect(discovery.peerCount, 1);

        // Advance past 24h TTL.
        nowMs += 25 * 60 * 60 * 1000;

        final evicted = discovery.evictExpired();
        expect(evicted, 1);
        expect(discovery.peerCount, 0);
      });

      test('isLocalNode returns true for local', () {
        expect(discovery.isLocalNode(0xAAAA), isTrue);
        expect(discovery.isLocalNode(0xBBBB), isFalse);
      });
    });

    group('SipPeerCapability', () {
      test('supportsSip1 and supportsSip3 flags', () {
        final full = SipPeerCapability(
          nodeId: 1,
          features: SipFeatureBits.allV01,
          deviceClass: 1,
          maxProtoMinor: 1,
          mtuHint: 215,
          rxWindowS: 10,
          capsHash: 0,
          lastSeenMs: 0,
        );
        expect(full.supportsSip1, isTrue);
        expect(full.supportsSip3, isTrue);

        final sip0Only = SipPeerCapability(
          nodeId: 2,
          features: SipFeatureBits.sip0,
          deviceClass: 1,
          maxProtoMinor: 1,
          mtuHint: 215,
          rxWindowS: 10,
          capsHash: 0,
          lastSeenMs: 0,
        );
        expect(sip0Only.supportsSip1, isFalse);
        expect(sip0Only.supportsSip3, isFalse);
      });
    });
  });
}
