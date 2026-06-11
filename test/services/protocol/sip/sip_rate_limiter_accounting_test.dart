// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Pins the airtime-budget single-accounting contract at the
// ProtocolService boundary:
// - sendSipGated deducts the wire size exactly once,
// - sendSipPacket (the pre-accounted path used by builders and overlay
//   egress, which charge the limiter themselves) deducts nothing,
// - an exhausted budget suppresses the send entirely (no wire bytes).
// Double deduction would silently halve the shared 1024B/60s budget;
// zero deduction would let gated paths bypass it.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/generated/meshtastic/mesh.pb.dart' as pb;
import 'package:socialmesh/services/protocol/protocol_service.dart';
import 'package:socialmesh/services/protocol/sip/sip_rate_limiter.dart';
import 'package:socialmesh/services/protocol/sip/sip_types.dart';

class _CountingTransport implements DeviceTransport {
  final List<List<int>> sent = [];
  final StreamController<List<int>> _data = StreamController.broadcast();

  @override
  TransportType get type => TransportType.ble;

  @override
  bool get requiresFraming => false;

  @override
  bool get requiresWakeSequence => false;

  @override
  TransportReconnectMode get reconnectMode => TransportReconnectMode.scanBased;

  @override
  DeviceConnectionState get state => DeviceConnectionState.connected;

  @override
  bool get isConnected => true;

  @override
  Stream<DeviceConnectionState> get stateStream => const Stream.empty();

  @override
  Stream<List<int>> get dataStream => _data.stream;

  @override
  Stream<DeviceInfo> scan({Duration? timeout, bool scanAll = false}) =>
      const Stream.empty();

  @override
  Future<void> connect(DeviceInfo device) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> send(List<int> data) async {
    sent.add(List<int>.of(data));
  }

  @override
  Future<void> refreshNotifications() async {}

  @override
  Future<void> pollOnce() async {}

  @override
  Future<void> enableNotifications() async {}

  @override
  Future<int?> readRssi() async => null;

  @override
  String? get bleModelNumber => null;

  @override
  String? get bleManufacturerName => null;

  @override
  Future<void> dispose() async {
    await _data.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _CountingTransport transport;
  late ProtocolService protocol;
  late SipRateLimiter limiter;

  setUp(() async {
    transport = _CountingTransport();
    protocol = ProtocolService(transport);
    await protocol.handleIncomingPacket(
      pb.FromRadio(myInfo: pb.MyNodeInfo(myNodeNum: 0xAAAA)).writeToBuffer(),
    );
    protocol.debugForceReadinessForTesting(OperationalReadiness.ready);
    limiter = SipRateLimiter(clock: () => DateTime(2026, 6, 11, 12));
    protocol.attachSipRateLimiter(limiter);
  });

  tearDown(() async {
    protocol.dispose();
    await transport.dispose();
  });

  test('sendSipGated deducts the wire size exactly once', () async {
    final payload = Uint8List.fromList(List.filled(100, 0x42));
    final before = limiter.remainingBytes;

    final ok = await protocol.sendSipGated(payload, SipMessageType.hsHello);

    expect(ok, isTrue);
    expect(transport.sent, hasLength(1));
    expect(
      before - limiter.remainingBytes,
      payload.length,
      reason:
          'Exactly the wire size must be deducted: more means a double '
          'count, less means a budget bypass.',
    );
  });

  test('sendSipPacket deducts nothing (callers pre-account)', () async {
    final payload = Uint8List.fromList(List.filled(80, 0x24));
    final before = limiter.remainingBytes;

    final ok = await protocol.sendSipPacket(payload);

    expect(ok, isTrue);
    expect(transport.sent, hasLength(1));
    expect(
      limiter.remainingBytes,
      before,
      reason:
          'The pre-accounted path must not deduct again; builders and '
          'overlay egress already charged the limiter.',
    );
  });

  test('an exhausted budget suppresses the gated send entirely', () async {
    // Drain the budget with one large accounted send.
    limiter.recordSend(limiter.remainingBytes);
    expect(limiter.remainingBytes, 0);

    final payload = Uint8List.fromList(List.filled(50, 0x99));
    final ok = await protocol.sendSipGated(payload, SipMessageType.hsHello);

    expect(ok, isFalse);
    expect(
      transport.sent,
      isEmpty,
      reason: 'A refused send must put zero bytes on the air.',
    );
  });
}
