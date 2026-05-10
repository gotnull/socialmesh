// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D34c-B-A — wire-byte supplement for path-override writes.
//
// Pinned invariants (this file):
//   - addUpdateContact(pathLength: 0, pathBytes: empty)
//     → byte 35 == 0x00 (Force Direct)
//     → bytes 36..99 are zero-padded
//   - addUpdateContact(pathLength: 3, pathBytes: [a,b,c])
//     → byte 35 == 3
//     → bytes 36..38 == [a,b,c]
//     → bytes 39..99 are zero-padded
//
// Already pinned in `d29_session_helpers_test.dart` (NOT duplicated
// here):
//   - pathLength: -1 → byte 35 == 0xFF (Force Flood)
//   - pathLength outside [-1, 64] throws ArgumentError
//
// Offsets reflect the firmware wire layout:
//   [0]    opcode (0x09)
//   [1..32]    pubkey (32 B)
//   [33]   adv_type
//   [34]   flags
//   [35]   path_len (signed int8, two's complement)
//   [36..99]   path bytes (64 B, zero-padded)
//   [100..131] name (32 B, null-terminated)
//   [132..135] last_advert_at (u32 LE seconds)
//   [136..143] optional GPS (lat/lon i32 LE × 1e6)

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_frame.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_session.dart';

class _FakeTransport implements MeshCoreTransport {
  final _rx = StreamController<Uint8List>.broadcast();
  final List<Uint8List> sentData = [];

  @override
  Stream<Uint8List> get rawRxStream => _rx.stream;

  @override
  Future<void> sendRaw(Uint8List data) async {
    sentData.add(Uint8List.fromList(data));
  }

  @override
  bool get isConnected => true;

  void simulateReceiveFrame(MeshCoreFrame frame) {
    _rx.add(frame.toBytes());
  }

  Future<void> dispose() async {
    if (!_rx.isClosed) await _rx.close();
  }
}

Future<Uint8List> _capture({
  required _FakeTransport transport,
  required Future<void> Function(MeshCoreSession) op,
  int replyCode = 0x00,
}) async {
  final session = MeshCoreSession(transport);
  final fut = op(session);
  await Future<void>.delayed(const Duration(milliseconds: 5));
  transport.simulateReceiveFrame(
    MeshCoreFrame(command: replyCode, payload: Uint8List(0)),
  );
  await fut;
  return transport.sentData.last;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final pubKey = Uint8List.fromList(List<int>.generate(32, (i) => i + 1));

  group('D34c-B-A — addUpdateContact wire bytes for path overrides', () {
    test('Force Direct: pathLength=0, empty pathBytes → byte 35 == 0x00 '
        'and path bytes zero-padded', () async {
      final t = _FakeTransport();
      addTearDown(t.dispose);
      final wire = await _capture(
        transport: t,
        op: (s) => s.addUpdateContact(
          pubKey: pubKey,
          advType: 1,
          name: 'Alice',
          pathLength: 0,
          pathBytes: Uint8List(0),
          lastAdvertAt: DateTime.utc(2026, 5, 6, 0, 0, 0),
        ),
      );
      expect(wire[0], 0x09);
      expect(wire[35], 0x00, reason: 'Force Direct → path_len byte 0x00');
      expect(
        wire.sublist(36, 100),
        Uint8List(64),
        reason: 'path bytes [36..99] are zero-padded for direct route',
      );
    });

    test('Saved trace: pathLength=3 with explicit hop bytes [a,b,c] '
        '→ byte 35 == 3 and bytes 36..38 mirror the input', () async {
      final t = _FakeTransport();
      addTearDown(t.dispose);
      final hops = Uint8List.fromList([0xAA, 0xBB, 0xCC]);
      final wire = await _capture(
        transport: t,
        op: (s) => s.addUpdateContact(
          pubKey: pubKey,
          advType: 1,
          name: 'Bob',
          pathLength: hops.length,
          pathBytes: hops,
          lastAdvertAt: DateTime.utc(2026, 5, 6, 0, 0, 0),
        ),
      );
      expect(wire[35], 3, reason: 'path_len byte == hop count');
      expect(
        wire.sublist(36, 39),
        hops,
        reason: 'first three path bytes mirror input',
      );
      expect(
        wire.sublist(39, 100),
        Uint8List(61),
        reason: 'remaining 61 path bytes are zero-padded',
      );
    });

    test('Force Flood (pathLength=-1) and the [-1, 64] bounds check are '
        'pinned in d29_session_helpers_test.dart — not duplicated here', () {
      // Sentinel test so a future refactor that drops the D29 file
      // gets a visible cue here. The actual byte-pin lives in
      // d29_session_helpers_test.dart at the
      // "minimum payload (no GPS)" test (path_len at [35] == 0xFF).
      expect(true, isTrue);
    });
  });
}
