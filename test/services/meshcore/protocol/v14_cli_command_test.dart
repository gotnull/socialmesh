// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Companion firmware v1.18.0 (FIRMWARE_VER_CODE 14) adds CMD_RUN_CLI_COMMAND
// (0x42) and RESP_CODE_CLI_REPLY (0x1D). The version code arrives in the
// DEVICE_INFO reply to the handshake's deviceQuery. Byte layouts follow
// examples/companion_radio/MyMesh.cpp at the pinned commit; these are built
// in the test, not captured, so they are not golden fixtures.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/meshcore_constants.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_frame.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_messages.dart';
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

  void receive(int command, List<int> payload) {
    _rx.add(
      MeshCoreFrame(
        command: command,
        payload: Uint8List.fromList(payload),
      ).toBytes(),
    );
  }

  Future<void> dispose() async {
    if (!_rx.isClosed) await _rx.close();
  }
}

List<int> _padded(String value, int width) {
  final bytes = utf8.encode(value);
  return [...bytes, ...List<int>.filled(width - bytes.length, 0)];
}

/// DEVICE_INFO payload as companion firmware builds it.
List<int> _deviceInfo(int verCode) => [
  verCode,
  175, // MAX_CONTACTS / 2
  40, // MAX_GROUP_CHANNELS
  0x40, 0xE2, 0x01, 0x00, // BLE pin 123456, LE
  ..._padded('15 Oct 2026', 12),
  ..._padded('Heltec Tracker V2', 40),
  ..._padded('v1.18.0', 20),
  0, // repeat enabled (v9+)
  0, // path hash mode (v10+)
];

/// Smallest SELF_INFO payload the parser accepts.
List<int> _selfInfo() => [1, 20, 22, ...List<int>.filled(32, 0xAB)];

Future<MeshCoreSession> _handshake(
  _FakeTransport t, {
  List<int>? deviceInfo,
}) async {
  final session = MeshCoreSession(t);
  final pending = session.getSelfInfo(timeout: const Duration(seconds: 2));
  await Future<void>.delayed(const Duration(milliseconds: 5));
  if (deviceInfo != null) {
    t.receive(MeshCoreResponses.deviceInfo, deviceInfo);
  }
  t.receive(MeshCoreResponses.selfInfo, _selfInfo());
  await pending;
  return session;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('parseDeviceInfo', () {
    test('reads version code and identity strings, not the BLE pin', () {
      final info = parseDeviceInfo(Uint8List.fromList(_deviceInfo(14))).value!;
      expect(info.firmwareVerCode, 14);
      expect(info.buildDate, '15 Oct 2026');
      expect(info.manufacturer, 'Heltec Tracker V2');
      expect(info.firmwareVersion, 'v1.18.0');
      expect(info.supportsCliCommands, isTrue);
    });

    test('version code 13 does not support CLI commands', () {
      final info = parseDeviceInfo(Uint8List.fromList(_deviceInfo(13))).value!;
      expect(info.supportsCliCommands, isFalse);
    });

    test('pre-v3 single-byte reply still yields the version code', () {
      final info = parseDeviceInfo(Uint8List.fromList([2])).value!;
      expect(info.firmwareVerCode, 2);
      expect(info.firmwareVersion, isNull);
    });

    test('empty payload is a parse failure', () {
      expect(parseDeviceInfo(Uint8List(0)).isFailure, isTrue);
    });
  });

  group('handshake captures DEVICE_INFO', () {
    test('a v14 radio reports CLI support', () async {
      final t = _FakeTransport();
      addTearDown(t.dispose);
      final session = await _handshake(t, deviceInfo: _deviceInfo(14));
      expect(session.deviceInfo?.firmwareVerCode, 14);
      expect(session.supportsCliCommands, isTrue);
    });

    test('a v13 radio does not', () async {
      final t = _FakeTransport();
      addTearDown(t.dispose);
      final session = await _handshake(t, deviceInfo: _deviceInfo(13));
      expect(session.supportsCliCommands, isFalse);
    });

    test('no DEVICE_INFO reply leaves CLI off and no waiter behind', () async {
      final t = _FakeTransport();
      addTearDown(t.dispose);
      final session = await _handshake(t);
      expect(session.deviceInfo, isNull);
      expect(session.supportsCliCommands, isFalse);

      // A second handshake on the same session must not collide with an
      // orphaned DEVICE_INFO waiter.
      final again = session.getSelfInfo(timeout: const Duration(seconds: 2));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      t.receive(MeshCoreResponses.deviceInfo, _deviceInfo(14));
      t.receive(MeshCoreResponses.selfInfo, _selfInfo());
      await again;
      expect(session.supportsCliCommands, isTrue);
    });
  });

  group('CLI commands', () {
    test('runCliCommand sends [0x42][text] and returns the reply', () async {
      final t = _FakeTransport();
      addTearDown(t.dispose);
      final session = await _handshake(t, deviceInfo: _deviceInfo(14));

      final pending = session.runCliCommand('get cad');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(t.sentData.last, [0x42, ...utf8.encode('get cad')]);
      t.receive(MeshCoreResponses.cliReply, utf8.encode('> on'));
      expect(await pending, '> on');
    });

    test('powerOff sends [0x42]"poweroff" without waiting', () async {
      final t = _FakeTransport();
      addTearDown(t.dispose);
      final session = await _handshake(t, deviceInfo: _deviceInfo(14));

      await session.powerOff();
      expect(t.sentData.last, [0x42, ...utf8.encode('poweroff')]);
    });

    test('older firmware is refused before anything is sent', () async {
      final t = _FakeTransport();
      addTearDown(t.dispose);
      final session = await _handshake(t, deviceInfo: _deviceInfo(13));
      final sentBefore = t.sentData.length;

      expect(() => session.runCliCommand('get cad'), throwsStateError);
      expect(session.powerOff, throwsStateError);
      expect(t.sentData.length, sentBefore);
    });
  });
}
