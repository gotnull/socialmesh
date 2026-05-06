// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D26 — typed wire-helper byte-for-byte regression pins.
//
// Each new helper in `MeshCoreSession` (`setAdvertName`,
// `setAdvertLatLon`, `setDeviceTime`, `rebootDevice`) emits a
// specific MeshCore command frame. The exact bytes are part of the
// protocol contract with the companion-radio firmware; pin them so
// a future refactor can't silently change the encoding.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/meshcore_constants.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_frame.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_session.dart';

class _FakeTransport implements MeshCoreTransport {
  final StreamController<Uint8List> _rx =
      StreamController<Uint8List>.broadcast();
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

/// Helper: dispatch [op] on a fresh session, simulate the firmware
/// reply, then return the bytes the helper sent on the wire.
///
/// `expectedReplyCode` is the response opcode to feed back so the
/// helper's `sendAndWait` resolves. Pass `null` for fire-and-forget
/// helpers (e.g. `rebootDevice`).
Future<Uint8List> _captureWire({
  required _FakeTransport transport,
  required Future<void> Function(MeshCoreSession) op,
  int? expectedReplyCode,
}) async {
  final session = MeshCoreSession(transport);
  final f = op(session);
  // Allow the send to land before we dispatch the reply.
  await Future<void>.delayed(const Duration(milliseconds: 5));
  if (expectedReplyCode != null) {
    transport.simulateReceiveFrame(
      MeshCoreFrame(command: expectedReplyCode, payload: Uint8List(0)),
    );
  }
  await f;
  return transport.sentData.last;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('D26 setAdvertName', () {
    test('emits [0x08][UTF-8 name bytes] with no null terminator', () async {
      final t = _FakeTransport();
      addTearDown(t.dispose);
      final wire = await _captureWire(
        transport: t,
        op: (s) => s.setAdvertName('TerryDev'),
        expectedReplyCode: 0x00, // RESP_CODE_OK
      );
      expect(
        wire,
        equals(<int>[0x08, 0x54, 0x65, 0x72, 0x72, 0x79, 0x44, 0x65, 0x76]),
      );
      // Length proves the absence of a trailing null terminator.
      expect(wire.length, equals(1 + 'TerryDev'.length));
    });

    test('rejects empty names without sending', () {
      final t = _FakeTransport();
      addTearDown(t.dispose);
      final session = MeshCoreSession(t);
      expect(() => session.setAdvertName(''), throwsArgumentError);
      expect(t.sentData, isEmpty);
    });

    test('rejects names exceeding $kMeshCoreMaxNodeNameBytes UTF-8 bytes', () {
      final t = _FakeTransport();
      addTearDown(t.dispose);
      final session = MeshCoreSession(t);
      // 32-byte ASCII name (one over the limit).
      final tooLong = 'A' * (kMeshCoreMaxNodeNameBytes + 1);
      expect(() => session.setAdvertName(tooLong), throwsArgumentError);
      expect(t.sentData, isEmpty);
    });

    test('UTF-8 multi-byte chars count toward the byte budget', () {
      final t = _FakeTransport();
      addTearDown(t.dispose);
      final session = MeshCoreSession(t);
      // 'é' is 2 UTF-8 bytes. 16×'é' = 32 bytes, one over the limit.
      final tooLong = 'é' * 16;
      expect(() => session.setAdvertName(tooLong), throwsArgumentError);
    });
  });

  group('D26 setAdvertLatLon', () {
    test(
      'emits [0x0E][lat int32 LE × 1e6][lon int32 LE × 1e6] for valid coords',
      () async {
        final t = _FakeTransport();
        addTearDown(t.dispose);
        // (-37.81363, 144.96305) ~ Melbourne city. Scale 1e6 →
        // -37813630, 144963050.
        final wire = await _captureWire(
          transport: t,
          op: (s) => s.setAdvertLatLon(-37.81363, 144.96305),
          expectedReplyCode: 0x00,
        );
        expect(wire[0], equals(0x0E));
        // Decode bytes 1..4 as int32 LE.
        final latRaw = ByteData.sublistView(
          wire,
          1,
          5,
        ).getInt32(0, Endian.little);
        final lonRaw = ByteData.sublistView(
          wire,
          5,
          9,
        ).getInt32(0, Endian.little);
        expect(latRaw, equals(-37813630));
        expect(lonRaw, equals(144963050));
        expect(wire.length, equals(9));
      },
    );

    test('clear-location convention: (0, 0) emits all-zero payload', () async {
      final t = _FakeTransport();
      addTearDown(t.dispose);
      final wire = await _captureWire(
        transport: t,
        op: (s) => s.setAdvertLatLon(0, 0),
        expectedReplyCode: 0x00,
      );
      expect(wire, equals(<int>[0x0E, 0, 0, 0, 0, 0, 0, 0, 0]));
    });

    test('rejects out-of-range latitudes without sending', () {
      final t = _FakeTransport();
      addTearDown(t.dispose);
      final session = MeshCoreSession(t);
      expect(() => session.setAdvertLatLon(-91, 0), throwsArgumentError);
      expect(() => session.setAdvertLatLon(90.5, 0), throwsArgumentError);
      expect(t.sentData, isEmpty);
    });

    test('rejects out-of-range longitudes without sending', () {
      final t = _FakeTransport();
      addTearDown(t.dispose);
      final session = MeshCoreSession(t);
      expect(() => session.setAdvertLatLon(0, 181), throwsArgumentError);
      expect(() => session.setAdvertLatLon(0, -180.001), throwsArgumentError);
      expect(t.sentData, isEmpty);
    });

    test('uses 1e6 scale (NOT Meshtastic 1e7)', () async {
      final t = _FakeTransport();
      addTearDown(t.dispose);
      final wire = await _captureWire(
        transport: t,
        op: (s) => s.setAdvertLatLon(1.0, 1.0),
        expectedReplyCode: 0x00,
      );
      final latRaw = ByteData.sublistView(
        wire,
        1,
        5,
      ).getInt32(0, Endian.little);
      final lonRaw = ByteData.sublistView(
        wire,
        5,
        9,
      ).getInt32(0, Endian.little);
      // 1e6, not 1e7.
      expect(latRaw, equals(1000000));
      expect(lonRaw, equals(1000000));
    });
  });

  group('D26 setDeviceTime', () {
    test('emits [0x06][epoch_seconds uint32 LE]', () async {
      final t = _FakeTransport();
      addTearDown(t.dispose);
      // Deterministic time so the byte assertion is stable.
      final fixed = DateTime.utc(2026, 5, 6, 12, 0, 0);
      final epochSecs = fixed.millisecondsSinceEpoch ~/ 1000;
      final wire = await _captureWire(
        transport: t,
        op: (s) => s.setDeviceTime(time: fixed),
        expectedReplyCode: 0x00,
      );
      expect(wire[0], equals(0x06));
      final secs = ByteData.sublistView(wire, 1, 5).getUint32(0, Endian.little);
      expect(secs, equals(epochSecs));
      expect(wire.length, equals(5));
    });

    test('uses seconds, NOT milliseconds', () async {
      final t = _FakeTransport();
      addTearDown(t.dispose);
      final fixed = DateTime.utc(2026, 1, 1);
      final wire = await _captureWire(
        transport: t,
        op: (s) => s.setDeviceTime(time: fixed),
        expectedReplyCode: 0x00,
      );
      final secs = ByteData.sublistView(wire, 1, 5).getUint32(0, Endian.little);
      // 1767225600 is 2026-01-01 in seconds. Anything in the
      // millisecond range (~10^12) would overflow uint32 and the
      // helper would throw before reaching the wire.
      expect(secs, equals(1767225600));
    });
  });

  group('D26 rebootDevice', () {
    test(
      'emits [0x13]["reboot"] magic word and does not wait for OK',
      () async {
        final t = _FakeTransport();
        addTearDown(t.dispose);
        final session = MeshCoreSession(t);
        // No expectedReplyCode — firmware never sends OK; the helper
        // is fire-and-forget.
        await session.rebootDevice();
        expect(t.sentData, hasLength(1));
        expect(
          t.sentData.single,
          equals(<int>[0x13, 0x72, 0x65, 0x62, 0x6f, 0x6f, 0x74]),
        );
        // Pin: exactly 7 bytes — opcode + 6-byte magic word, no
        // optional data.
        expect(t.sentData.single.length, equals(7));
      },
    );
  });
}
