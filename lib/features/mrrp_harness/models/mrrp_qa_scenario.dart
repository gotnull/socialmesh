// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import '../../../services/protocol/sip/mrrp_codec.dart';
import '../../../services/protocol/sip/mrrp_frame.dart';
import '../../../services/protocol/sip/mrrp_types.dart';

/// Result state for a single QA step.
enum QaStepStatus { pending, pass, fail }

/// A single step in a QA scenario.
class QaStep {
  final String description;
  final String expectedOutcome;
  final bool Function(MrrpFrame? decoded) verify;

  QaStepStatus status;
  String? actualOutcome;

  QaStep({
    required this.description,
    required this.expectedOutcome,
    required this.verify,
    this.status = QaStepStatus.pending,
  });
}

/// A complete QA scenario consisting of ordered steps.
class QaScenario {
  final String name;
  final List<QaStep> steps;

  bool get passed => steps.every((s) => s.status == QaStepStatus.pass);
  bool get hasRun => steps.any((s) => s.status != QaStepStatus.pending);
  int get passedCount =>
      steps.where((s) => s.status == QaStepStatus.pass).length;

  QaScenario({required this.name, required this.steps});

  void reset() {
    for (final s in steps) {
      s.status = QaStepStatus.pending;
      s.actualOutcome = null;
    }
  }
}

// ---------------------------------------------------------------------------
// Hex helper (local copy)
// ---------------------------------------------------------------------------

Uint8List _hexToBytes(String hex) {
  final clean = hex.replaceAll(RegExp(r'\s+'), '');
  final bytes = Uint8List(clean.length ~/ 2);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return bytes;
}

// ---------------------------------------------------------------------------
// Built-in scenarios
// ---------------------------------------------------------------------------

/// Create the 8 built-in QA scenarios.
///
/// These use locally-decoded fixture data (no network) to exercise
/// the codec and type system. Scenarios that require a live peer or
/// simulated peer verify decode correctness of known-good frames.
List<QaScenario> buildQaScenarios() => [
  _discoveryDirProfile(),
  _meetupFlow(),
  _boardFlow(),
  _timeoutRetry(),
  _duplicateHandling(),
  _errorInjection(),
  _budgetExhaustion(),
  _simPeerRoundTrip(),
];

// ---------------------------------------------------------------------------
// Scenario 1: Discovery -> Directory -> Profile
// ---------------------------------------------------------------------------

QaScenario _discoveryDirProfile() {
  final advertBytes = _hexToBytes(
    '4D 52 00 01 01 00 14 00 00 00 00 00 00 00 00 00'
    '00 00 15 00'
    '02'
    '01 00 00 00 00 01 00 6D 00 00'
    '01 00 FF FF 02 01 00 8C 00 00',
  );
  final dirReqBytes = _hexToBytes(
    '4D 52 00 01 02 01 14 00 01 00 00 00 00 00 00 00'
    '00 00 00 00',
  );
  final dirRespBytes = _hexToBytes(
    '4D 52 00 01 03 02 14 00 01 00 00 00 00 00 00 00'
    '00 00 0B 00'
    '01'
    '02 00 00 00 00 01 00 7F 00 00',
  );
  final requestBytes = _hexToBytes(
    '4D 52 00 01 10 01 14 00 42 00 00 00 01 00 FF FF'
    '01 00 04 00'
    'DE AD BE EF',
  );

  return QaScenario(
    name: 'Discovery -> Directory -> Profile', // lint-allow: hardcoded-string
    steps: [
      QaStep(
        description: 'Decode SERVICE_ADVERT', // lint-allow: hardcoded-string
        expectedOutcome:
            'msg_type=0x01, 2 services', // lint-allow: hardcoded-string
        verify: (_) {
          final frame = MrrpCodec.decode(advertBytes);
          return frame != null &&
              frame.msgType == MrrpMessageType.serviceAdvert &&
              frame.payloadLen == 21;
        },
      ),
      QaStep(
        description: 'Decode SERVICE_DIR_REQ', // lint-allow: hardcoded-string
        expectedOutcome:
            'msg_type=0x02, request_id=1', // lint-allow: hardcoded-string
        verify: (_) {
          final frame = MrrpCodec.decode(dirReqBytes);
          return frame != null &&
              frame.msgType == MrrpMessageType.serviceDirReq &&
              frame.requestId == 1;
        },
      ),
      QaStep(
        description: 'Decode SERVICE_DIR_RESP', // lint-allow: hardcoded-string
        expectedOutcome:
            'msg_type=0x03, 1 service', // lint-allow: hardcoded-string
        verify: (_) {
          final frame = MrrpCodec.decode(dirRespBytes);
          return frame != null &&
              frame.msgType == MrrpMessageType.serviceDirResp &&
              frame.payloadLen == 11;
        },
      ),
      QaStep(
        description:
            'Decode REQUEST to echo.test', // lint-allow: hardcoded-string
        expectedOutcome:
            'msg_type=0x10, service=0xffff0001, 4B payload', // lint-allow: hardcoded-string
        verify: (_) {
          final frame = MrrpCodec.decode(requestBytes);
          return frame != null &&
              frame.msgType == MrrpMessageType.request &&
              frame.serviceId == 0xFFFF0001 &&
              frame.payloadLen == 4;
        },
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Scenario 2: Meetup Flow
// ---------------------------------------------------------------------------

QaScenario _meetupFlow() {
  // Meetup create uses REQUEST to meetup.v1 (service_id=0x00000001)
  final createBytes = _hexToBytes(
    '4D 52 00 01 10 01 14 00 0A 00 00 00 01 00 00 00'
    '01 00 04 00'
    'CA FE F0 0D',
  );
  final acceptBytes = _hexToBytes(
    '4D 52 00 01 11 02 14 00 0A 00 00 00 01 00 00 00'
    '01 00 02 00'
    '00 01',
  );
  final cancelBytes = _hexToBytes(
    '4D 52 00 01 13 00 14 00 0A 00 00 00 01 00 00 00'
    '01 00 00 00',
  );

  return QaScenario(
    name: 'Meetup Flow', // lint-allow: hardcoded-string
    steps: [
      QaStep(
        description: 'Create meetup request', // lint-allow: hardcoded-string
        expectedOutcome:
            'REQUEST to meetup.v1, action=create', // lint-allow: hardcoded-string
        verify: (_) {
          final frame = MrrpCodec.decode(createBytes);
          return frame != null &&
              frame.msgType == MrrpMessageType.request &&
              frame.serviceId == 0x00000001;
        },
      ),
      QaStep(
        description: 'Accept meetup response', // lint-allow: hardcoded-string
        expectedOutcome:
            'RESPONSE from meetup.v1', // lint-allow: hardcoded-string
        verify: (_) {
          final frame = MrrpCodec.decode(acceptBytes);
          return frame != null &&
              frame.msgType == MrrpMessageType.response &&
              frame.serviceId == 0x00000001;
        },
      ),
      QaStep(
        description: 'Cancel meetup', // lint-allow: hardcoded-string
        expectedOutcome:
            'CANCEL with matching request_id', // lint-allow: hardcoded-string
        verify: (_) {
          final frame = MrrpCodec.decode(cancelBytes);
          return frame != null &&
              frame.msgType == MrrpMessageType.cancel &&
              frame.requestId == 0x0A;
        },
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Scenario 3: Board Flow
// ---------------------------------------------------------------------------

QaScenario _boardFlow() {
  // Board uses service_id=0x00000003
  final postBytes = _hexToBytes(
    '4D 52 00 01 10 01 14 00 0B 00 00 00 03 00 00 00'
    '01 00 06 00'
    '48 65 6C 6C 6F 21',
  );
  final listBytes = _hexToBytes(
    '4D 52 00 01 10 01 14 00 0C 00 00 00 03 00 00 00'
    '02 00 00 00',
  );
  final listRespBytes = _hexToBytes(
    '4D 52 00 01 11 02 14 00 0C 00 00 00 03 00 00 00'
    '02 00 08 00'
    '01 06 48 65 6C 6C 6F 21',
  );

  return QaScenario(
    name: 'Board Flow', // lint-allow: hardcoded-string
    steps: [
      QaStep(
        description:
            'Post short message to board.v1', // lint-allow: hardcoded-string
        expectedOutcome:
            'REQUEST to board.v1, action=post_short', // lint-allow: hardcoded-string
        verify: (_) {
          final frame = MrrpCodec.decode(postBytes);
          return frame != null &&
              frame.msgType == MrrpMessageType.request &&
              frame.serviceId == 0x00000003 &&
              frame.payloadLen == 6;
        },
      ),
      QaStep(
        description: 'List recent posts', // lint-allow: hardcoded-string
        expectedOutcome:
            'REQUEST to board.v1, action=list_recent', // lint-allow: hardcoded-string
        verify: (_) {
          final frame = MrrpCodec.decode(listBytes);
          return frame != null &&
              frame.msgType == MrrpMessageType.request &&
              frame.serviceId == 0x00000003 &&
              frame.actionId == 0x0002;
        },
      ),
      QaStep(
        description: 'Receive list response', // lint-allow: hardcoded-string
        expectedOutcome:
            'RESPONSE from board.v1 with post data', // lint-allow: hardcoded-string
        verify: (_) {
          final frame = MrrpCodec.decode(listRespBytes);
          return frame != null &&
              frame.msgType == MrrpMessageType.response &&
              frame.serviceId == 0x00000003 &&
              frame.payloadLen > 0;
        },
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Scenario 4: Timeout -> Retry
// ---------------------------------------------------------------------------

QaScenario _timeoutRetry() {
  final requestBytes = _hexToBytes(
    '4D 52 00 01 10 01 14 00 42 00 00 00 01 00 FF FF'
    '01 00 04 00'
    'DE AD BE EF',
  );
  final errorBytes = _hexToBytes(
    '4D 52 00 01 12 06 17 00 42 00 00 00 00 00 DE AD'
    '01 00 00 00'
    '05 01 01',
  );

  return QaScenario(
    name: 'Timeout -> Retry', // lint-allow: hardcoded-string
    steps: [
      QaStep(
        description:
            'Send request to unavailable service', // lint-allow: hardcoded-string
        expectedOutcome:
            'REQUEST encodes correctly', // lint-allow: hardcoded-string
        verify: (_) {
          final frame = MrrpCodec.decode(requestBytes);
          return frame != null && frame.msgType == MrrpMessageType.request;
        },
      ),
      QaStep(
        description: 'Decode ERROR response', // lint-allow: hardcoded-string
        expectedOutcome:
            'ERROR with status NOT_FOUND, TLV status_code=1', // lint-allow: hardcoded-string
        verify: (_) {
          final frame = MrrpCodec.decode(errorBytes);
          if (frame == null || frame.msgType != MrrpMessageType.error) {
            return false;
          }
          return frame.headerExtensions.any(
            (e) => e.type == MrrpTlvType.statusCode.code && e.value[0] == 0x01,
          );
        },
      ),
      QaStep(
        description: 'Retry same request_id', // lint-allow: hardcoded-string
        expectedOutcome:
            'Same request_id=0x42 decodes', // lint-allow: hardcoded-string
        verify: (_) {
          final frame = MrrpCodec.decode(requestBytes);
          return frame != null && frame.requestId == 0x42;
        },
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Scenario 5: Duplicate Handling
// ---------------------------------------------------------------------------

QaScenario _duplicateHandling() {
  final requestBytes = _hexToBytes(
    '4D 52 00 01 10 01 14 00 42 00 00 00 01 00 FF FF'
    '01 00 04 00'
    'DE AD BE EF',
  );
  final responseBytes = _hexToBytes(
    '4D 52 00 01 11 02 14 00 42 00 00 00 01 00 FF FF'
    '01 00 04 00'
    'DE AD BE EF',
  );

  return QaScenario(
    name: 'Duplicate Handling', // lint-allow: hardcoded-string
    steps: [
      QaStep(
        description: 'First REQUEST decode', // lint-allow: hardcoded-string
        expectedOutcome:
            'Decode succeeds, request_id=0x42', // lint-allow: hardcoded-string
        verify: (_) {
          final frame = MrrpCodec.decode(requestBytes);
          return frame != null && frame.requestId == 0x42;
        },
      ),
      QaStep(
        description:
            'Duplicate REQUEST (same bytes)', // lint-allow: hardcoded-string
        expectedOutcome:
            'Decode succeeds (dedup is dispatcher-level)', // lint-allow: hardcoded-string
        verify: (_) {
          final frame = MrrpCodec.decode(requestBytes);
          return frame != null && frame.requestId == 0x42;
        },
      ),
      QaStep(
        description:
            'RESPONSE for same request_id', // lint-allow: hardcoded-string
        expectedOutcome:
            'RESPONSE decode OK, request_id matches', // lint-allow: hardcoded-string
        verify: (_) {
          final frame = MrrpCodec.decode(responseBytes);
          return frame != null &&
              frame.msgType == MrrpMessageType.response &&
              frame.requestId == 0x42;
        },
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Scenario 6: Error Injection
// ---------------------------------------------------------------------------

QaScenario _errorInjection() {
  final echoReqBytes = _hexToBytes(
    '4D 52 00 01 10 01 14 00 42 00 00 00 01 00 FF FF'
    '01 00 04 00'
    'DE AD BE EF',
  );
  final errorBytes = _hexToBytes(
    '4D 52 00 01 12 06 17 00 42 00 00 00 01 00 FF FF'
    '01 00 00 00'
    '05 01 03',
  );

  return QaScenario(
    name: 'Error Injection', // lint-allow: hardcoded-string
    steps: [
      QaStep(
        description:
            'Send echo.test request with echo_error', // lint-allow: hardcoded-string
        expectedOutcome:
            'REQUEST to echo.test decodes OK', // lint-allow: hardcoded-string
        verify: (_) {
          final frame = MrrpCodec.decode(echoReqBytes);
          return frame != null &&
              frame.msgType == MrrpMessageType.request &&
              frame.serviceId == 0xFFFF0001;
        },
      ),
      QaStep(
        description:
            'Verify ERROR response with status code', // lint-allow: hardcoded-string
        expectedOutcome:
            'ERROR decode OK, has status_code TLV', // lint-allow: hardcoded-string
        verify: (_) {
          final frame = MrrpCodec.decode(errorBytes);
          if (frame == null || frame.msgType != MrrpMessageType.error) {
            return false;
          }
          return frame.headerExtensions.any(
            (e) => e.type == MrrpTlvType.statusCode.code,
          );
        },
      ),
      QaStep(
        description:
            'Verify error service_id matches request', // lint-allow: hardcoded-string
        expectedOutcome:
            'ERROR service_id = 0xffff0001', // lint-allow: hardcoded-string
        verify: (_) {
          final frame = MrrpCodec.decode(errorBytes);
          return frame != null && frame.serviceId == 0xFFFF0001;
        },
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Scenario 7: Budget Exhaustion
// ---------------------------------------------------------------------------

QaScenario _budgetExhaustion() {
  final smallReqBytes = _hexToBytes(
    '4D 52 00 01 10 01 14 00 01 00 00 00 01 00 FF FF'
    '01 00 04 00'
    'DE AD BE EF',
  );

  return QaScenario(
    name: 'Budget Exhaustion', // lint-allow: hardcoded-string
    steps: [
      QaStep(
        description: 'Encode small REQUEST', // lint-allow: hardcoded-string
        expectedOutcome:
            'Encode produces 24 bytes', // lint-allow: hardcoded-string
        verify: (_) {
          final frame = MrrpCodec.decode(smallReqBytes);
          if (frame == null) return false;
          final encoded = MrrpCodec.encode(frame);
          return encoded != null && encoded.length == 24;
        },
      ),
      QaStep(
        description:
            'Verify max-size frame accepted', // lint-allow: hardcoded-string
        expectedOutcome:
            '215-byte frame decodes OK', // lint-allow: hardcoded-string
        verify: (_) {
          final maxFrame = Uint8List(215);
          maxFrame[0] = 0x4D;
          maxFrame[1] = 0x52;
          maxFrame[3] = 0x01;
          maxFrame[4] = 0x10;
          maxFrame[6] = 0x14;
          maxFrame[8] = 0x01;
          maxFrame[12] = 0x01;
          maxFrame[16] = 0x01;
          maxFrame[18] = 0xC3;
          final frame = MrrpCodec.decode(maxFrame);
          return frame != null;
        },
      ),
      QaStep(
        description:
            'Verify oversized frame rejected', // lint-allow: hardcoded-string
        expectedOutcome:
            '216-byte frame returns null', // lint-allow: hardcoded-string
        verify: (_) {
          final oversized = Uint8List(216);
          oversized[0] = 0x4D;
          oversized[1] = 0x52;
          oversized[3] = 0x01;
          oversized[4] = 0x10;
          oversized[6] = 0x14;
          oversized[8] = 0x01;
          oversized[12] = 0x01;
          oversized[16] = 0x01;
          oversized[18] = 0xC4;
          return MrrpCodec.decode(oversized) == null;
        },
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Scenario 8: Simulated Peer Round-Trip
// ---------------------------------------------------------------------------

QaScenario _simPeerRoundTrip() {
  final advertBytes = _hexToBytes(
    '4D 52 00 01 01 00 14 00 00 00 00 00 00 00 00 00'
    '00 00 15 00'
    '02'
    '01 00 00 00 00 01 00 6D 00 00'
    '01 00 FF FF 02 01 00 8C 00 00',
  );
  final dirRespBytes = _hexToBytes(
    '4D 52 00 01 03 02 14 00 01 00 00 00 00 00 00 00'
    '00 00 0B 00'
    '01'
    '02 00 00 00 00 01 00 7F 00 00',
  );
  final reqBytes = _hexToBytes(
    '4D 52 00 01 10 01 14 00 42 00 00 00 01 00 FF FF'
    '01 00 04 00'
    'DE AD BE EF',
  );
  final respBytes = _hexToBytes(
    '4D 52 00 01 11 02 14 00 42 00 00 00 01 00 FF FF'
    '01 00 04 00'
    'DE AD BE EF',
  );

  return QaScenario(
    name: 'Simulated Peer Round-Trip', // lint-allow: hardcoded-string
    steps: [
      QaStep(
        description:
            'Discover simulated peer (SERVICE_ADVERT)', // lint-allow: hardcoded-string
        expectedOutcome:
            'SERVICE_ADVERT with 2 services', // lint-allow: hardcoded-string
        verify: (_) {
          final frame = MrrpCodec.decode(advertBytes);
          return frame != null &&
              frame.msgType == MrrpMessageType.serviceAdvert;
        },
      ),
      QaStep(
        description: 'Get service directory', // lint-allow: hardcoded-string
        expectedOutcome:
            'SERVICE_DIR_RESP with 1 service', // lint-allow: hardcoded-string
        verify: (_) {
          final frame = MrrpCodec.decode(dirRespBytes);
          return frame != null &&
              frame.msgType == MrrpMessageType.serviceDirResp;
        },
      ),
      QaStep(
        description: 'Send echo.test REQUEST', // lint-allow: hardcoded-string
        expectedOutcome:
            'REQUEST to 0xffff0001, 4B payload', // lint-allow: hardcoded-string
        verify: (_) {
          final frame = MrrpCodec.decode(reqBytes);
          return frame != null &&
              frame.msgType == MrrpMessageType.request &&
              frame.serviceId == 0xFFFF0001 &&
              frame.payloadLen == 4;
        },
      ),
      QaStep(
        description: 'Receive echo RESPONSE', // lint-allow: hardcoded-string
        expectedOutcome:
            'RESPONSE with echoed payload', // lint-allow: hardcoded-string
        verify: (_) {
          final frame = MrrpCodec.decode(respBytes);
          return frame != null &&
              frame.msgType == MrrpMessageType.response &&
              frame.requestId == 0x42 &&
              frame.payloadLen == 4;
        },
      ),
    ],
  );
}
