// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Commercialisation audit — verification of the direct-link SNR gate.
//
// Pins the invariant enforced inline in
// `MeshCoreConversationsNotifier._handleIncomingContactMessage`
// (lib/providers/meshcore_message_providers.dart): a contact's SNR is
// recorded ONLY when the inbound frame was received directly, i.e.
//
//     parsed.snrQuarter != null && parsed.pathLen == 0
//
// The firmware path_len byte is 0 for a direct (0-relay) reception,
// 1..N when repeated through N relays, and 0xFF when the path is
// unknown / not yet established. For a repeated or unknown-path
// message the measured SNR belongs to the last repeater, not the
// sending contact, so it must NOT be attributed. This mirrors the
// Meshtastic direct-RF gate on rxRssi/rxSnr.
//
// Scope / what proves what (this is the established house pattern, see
// test/providers/d33_inbound_reply_envelope_test.dart): rather than
// pumping the notifier through a full ProviderContainer + frame-stream
// scaffold, we drive the REAL parser (`parseContactMessage`) with the
// exact firmware-shaped payloads the handler sees, then evaluate the
// exact gate predicate against the parser output. The sink itself
// (`MeshCoreContactsNotifier.recordSnrFromPrefix`) is independently
// proven in test/providers/meshcore_snr_record_test.dart. Together
// these cover input parsing + the gate decision + the recording sink.
//
// NOTE (RSSI): this MeshCore inbound path does not attribute a
// per-contact RSSI at all — RSSI only surfaces as device-wide radio
// stats (`lastRssiDbm`). So this file verifies SNR gating only and
// makes no claim about RSSI gating.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/meshcore_constants.dart';
import 'package:socialmesh/features/meshcore/parsers/meshcore_message_frame_parser.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_frame.dart';

/// Build a V3 contact-receive payload:
/// [snr][rsv1][rsv2][prefix:6][path][txt][ts:u32 LE][text].
Uint8List _v3ContactPayload({
  required int snrQuarter,
  required List<int> senderPrefix,
  required int pathLen,
}) {
  assert(senderPrefix.length == 6, 'sender prefix must be 6 bytes');
  final body = BytesBuilder();
  body.addByte(snrQuarter & 0xFF);
  body.addByte(0);
  body.addByte(0);
  body.add(senderPrefix);
  body.addByte(pathLen);
  body.addByte(0); // txtType = TXT_TYPE_PLAIN
  final ts = ByteData(4)..setUint32(0, 1_700_000_000, Endian.little);
  body.add(ts.buffer.asUint8List());
  body.add(Uint8List.fromList('hello'.codeUnits));
  return body.toBytes();
}

/// Build a legacy contact-receive payload (no SNR field):
/// [prefix:6][path][txt][ts:u32 LE][text].
Uint8List _legacyContactPayload({
  required List<int> senderPrefix,
  required int pathLen,
}) {
  assert(senderPrefix.length == 6, 'sender prefix must be 6 bytes');
  final body = BytesBuilder();
  body.add(senderPrefix);
  body.addByte(pathLen);
  body.addByte(0); // txtType
  final ts = ByteData(4)..setUint32(0, 1_700_000_000, Endian.little);
  body.add(ts.buffer.asUint8List());
  body.add(Uint8List.fromList('hello'.codeUnits));
  return body.toBytes();
}

const _prefix = <int>[0x79, 0x42, 0x6D, 0x8D, 0xB8, 0xFD];

/// Parse a frame and evaluate the EXACT gate predicate the inbound
/// contact-message handler applies before calling
/// `recordSnrFromPrefix`. Returns true when the contact's SNR would be
/// recorded.
bool _snrWouldBeRecorded(MeshCoreFrame frame) {
  final result = MeshCoreMessageFrameParser.parseContactMessage(frame);
  expect(result.ok, isTrue, reason: result.rejectReason);
  final parsed = result.value!;
  return parsed.snrQuarter != null && parsed.pathLen == 0;
}

MeshCoreFrame _v3Frame({required int snrQuarter, required int pathLen}) =>
    MeshCoreFrame(
      command: MeshCoreResponses.contactMsgRecvV3,
      payload: _v3ContactPayload(
        snrQuarter: snrQuarter,
        senderPrefix: _prefix,
        pathLen: pathLen,
      ),
    );

void main() {
  group('direct-link SNR gate (path_len semantics)', () {
    test('records SNR for a direct frame (path_len == 0)', () {
      expect(_snrWouldBeRecorded(_v3Frame(snrQuarter: 36, pathLen: 0)), isTrue);
    });

    test('does NOT record SNR for a relayed frame (path_len == 1)', () {
      expect(
        _snrWouldBeRecorded(_v3Frame(snrQuarter: 36, pathLen: 1)),
        isFalse,
      );
    });

    test('does NOT record SNR for a multi-relay frame (path_len == 5)', () {
      expect(
        _snrWouldBeRecorded(_v3Frame(snrQuarter: 36, pathLen: 5)),
        isFalse,
      );
    });

    test('does NOT record SNR for an unknown-path frame (path_len == 0xFF) — '
        '0xFF is not treated as direct', () {
      final recorded = _snrWouldBeRecorded(
        _v3Frame(snrQuarter: 36, pathLen: 0xFF),
      );
      expect(recorded, isFalse);
    });

    test('parser preserves the raw 0xFF path byte (never aliased to 0)', () {
      final result = MeshCoreMessageFrameParser.parseContactMessage(
        _v3Frame(snrQuarter: 36, pathLen: 0xFF),
      );
      expect(result.value!.pathLen, 0xFF);
    });

    test(
      'does NOT record when SNR is absent even on a direct legacy frame',
      () {
        final frame = MeshCoreFrame(
          command: MeshCoreResponses.contactMsgRecv,
          payload: _legacyContactPayload(senderPrefix: _prefix, pathLen: 0),
        );
        // Legacy contact frames carry no SNR field → snrQuarter is null.
        final result = MeshCoreMessageFrameParser.parseContactMessage(frame);
        expect(result.value!.snrQuarter, isNull);
        expect(_snrWouldBeRecorded(frame), isFalse);
      },
    );

    test('signed SNR is preserved and still gates on path_len', () {
      // Negative SNR (-2 dB) on a direct frame still records.
      expect(_snrWouldBeRecorded(_v3Frame(snrQuarter: -8, pathLen: 0)), isTrue);
      // Same negative SNR on a relayed frame does not.
      expect(
        _snrWouldBeRecorded(_v3Frame(snrQuarter: -8, pathLen: 2)),
        isFalse,
      );
    });
  });
}
