// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Verifies that the 32-byte 0xC3 wake preamble in `_requestConfiguration`
// is gated on `DeviceTransport.requiresWakeSequence`, NOT on
// `requiresFraming`. Pre-fix, network transport (framed but NOT
// serial-backed) received the wake preamble and the firmware interpreted
// it as a malformed framed packet. See issue #102.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/services/mesh_packet_dedupe_store.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';

class _CapabilityFakeTransport extends DeviceTransport {
  _CapabilityFakeTransport({
    required this.type,
    required this.requiresFraming,
    required this.requiresWakeSequence,
  });

  @override
  final TransportType type;

  @override
  final bool requiresFraming;

  @override
  final bool requiresWakeSequence;

  @override
  TransportReconnectMode get reconnectMode => type == TransportType.network
      ? TransportReconnectMode.directEndpoint
      : TransportReconnectMode.scanBased;

  bool connected = true;
  final List<List<int>> sent = <List<int>>[];
  final StreamController<List<int>> _dataController =
      StreamController<List<int>>.broadcast();

  @override
  DeviceConnectionState get state => connected
      ? DeviceConnectionState.connected
      : DeviceConnectionState.disconnected;

  @override
  bool get isConnected => connected;

  @override
  Stream<DeviceConnectionState> get stateStream =>
      const Stream<DeviceConnectionState>.empty();

  @override
  Stream<List<int>> get dataStream => _dataController.stream;

  @override
  Stream<DeviceInfo> scan({Duration? timeout, bool scanAll = false}) =>
      const Stream<DeviceInfo>.empty();

  @override
  Future<void> connect(DeviceInfo device) async {}

  @override
  Future<void> disconnect() async {
    connected = false;
  }

  @override
  Future<void> enableNotifications() async {}

  @override
  Future<void> pollOnce() async {}

  @override
  Future<void> send(List<int> data) async {
    sent.add(List<int>.of(data));
  }

  @override
  Future<int?> readRssi() async => null;

  @override
  Future<void> dispose() async {
    await _dataController.close();
  }
}

// Leading 32 0xC3 bytes is the wake preamble the Meshtastic serial
// protocol expects before the first framed packet on a UART link.
bool _isWakePreamble(List<int> bytes) {
  if (bytes.length != 32) return false;
  return bytes.every((b) => b == 0xC3);
}

Future<void> _withTempDirectory(Future<void> Function(String path) body) async {
  final tempDir = await Directory.systemTemp.createTemp('protocol_wake_seq');
  try {
    await body(tempDir.path);
  } finally {
    await tempDir.delete(recursive: true);
  }
}

Future<ProtocolService> _freshProtocol(
  String dir,
  DeviceTransport transport,
) async {
  final dedupeStore = MeshPacketDedupeStore(
    dbPathOverride: p.join(
      dir,
      'dedupe_${DateTime.now().microsecondsSinceEpoch}.db',
    ),
  );
  await dedupeStore.init();
  return ProtocolService(transport, dedupeStore: dedupeStore);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('_requestConfiguration wake-byte gating', () {
    test(
      'USB (requiresWakeSequence=true) sends the 32x0xC3 wake preamble',
      () async {
        await _withTempDirectory((dir) async {
          final transport = _CapabilityFakeTransport(
            type: TransportType.usb,
            requiresFraming: true,
            requiresWakeSequence: true,
          );
          final protocol = await _freshProtocol(dir, transport);
          try {
            await protocol.sendInitialConfigRequestForTest();
            await Future<void>.delayed(const Duration(milliseconds: 150));

            final wakes = transport.sent.where(_isWakePreamble).toList();
            expect(
              wakes.length,
              1,
              reason:
                  'USB/serial must emit exactly one 32-byte 0xC3 wake '
                  'preamble before the first wantConfigId.',
            );
          } finally {
            protocol.stop();
          }
        });
      },
    );

    test(
      'Network (framing=true, wake=false) does NOT send the wake preamble',
      () async {
        await _withTempDirectory((dir) async {
          final transport = _CapabilityFakeTransport(
            type: TransportType.network,
            requiresFraming: true,
            requiresWakeSequence: false,
          );
          final protocol = await _freshProtocol(dir, transport);
          try {
            await protocol.sendInitialConfigRequestForTest();
            await Future<void>.delayed(const Duration(milliseconds: 150));

            final wakes = transport.sent.where(_isWakePreamble).toList();
            expect(
              wakes,
              isEmpty,
              reason:
                  'Network/TCP must NOT receive the serial wake preamble '
                  '— PhoneAPI parses these bytes as a malformed packet.',
            );
          } finally {
            protocol.stop();
          }
        });
      },
    );

    test('BLE (framing=false) does NOT send the wake preamble', () async {
      await _withTempDirectory((dir) async {
        final transport = _CapabilityFakeTransport(
          type: TransportType.ble,
          requiresFraming: false,
          requiresWakeSequence: false,
        );
        final protocol = await _freshProtocol(dir, transport);
        try {
          await protocol.sendInitialConfigRequestForTest();
          await Future<void>.delayed(const Duration(milliseconds: 150));

          final wakes = transport.sent.where(_isWakePreamble).toList();
          expect(wakes, isEmpty);
        } finally {
          protocol.stop();
        }
      });
    });
  });

  group('network transport does not send wake bytes mid-flight', () {
    // The 32-byte wake preamble is gated entirely on
    // requiresWakeSequence — not on requiresFraming, not on type. This
    // test encodes that contract directly: a transport that claims to
    // be framed-but-PhoneAPI (our network transport shape) receives
    // only the wantConfigId, and the first byte of that first send is
    // the 0x94 frame start, NOT the 0xC3 wake byte.
    test('first byte sent on network transport is framed protobuf, '
        'not the 0xC3 wake byte', () async {
      await _withTempDirectory((dir) async {
        final transport = _CapabilityFakeTransport(
          type: TransportType.network,
          requiresFraming: true,
          requiresWakeSequence: false,
        );
        final protocol = await _freshProtocol(dir, transport);
        try {
          await protocol.sendInitialConfigRequestForTest();
          await Future<void>.delayed(const Duration(milliseconds: 150));

          expect(transport.sent, isNotEmpty);
          final firstByte = transport.sent.first.first;
          expect(
            firstByte,
            isNot(0xC3),
            reason:
                'Network transport must never emit the serial UART wake '
                'byte as the lead byte of the first send.',
          );
        } finally {
          protocol.stop();
        }
      });
    });
  });
}
