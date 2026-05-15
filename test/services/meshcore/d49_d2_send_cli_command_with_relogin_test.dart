// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D49-D2: `MeshCoreSession.sendCliCommandWithReLogin` pins.
//
// Pinned invariants:
//   - First-call ok        -> returns ok, no login fires.
//   - First-call timeout, login ok, retry ok      -> returns ok.
//   - First-call timeout, login ok, retry timeout -> returns timeout.
//   - First-call timeout, login fail              -> returns the
//     ORIGINAL timeout (not the login-fail).
//   - Retry uses a fresh prefix token via the optional builder hook
//     so the wrapper does not collide its own correlation key.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/meshcore_constants.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_frame.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_session.dart';

class _RecordingTransport implements MeshCoreTransport {
  final StreamController<Uint8List> _rx =
      StreamController<Uint8List>.broadcast();
  final List<Uint8List> sent = [];
  bool _connected = true;

  @override
  Stream<Uint8List> get rawRxStream => _rx.stream;

  @override
  Future<void> sendRaw(Uint8List data) async {
    sent.add(Uint8List.fromList(data));
  }

  @override
  bool get isConnected => _connected;

  void inject(Uint8List bytes) {
    _rx.add(bytes);
  }

  Future<void> dispose() async {
    _connected = false;
    await _rx.close();
  }
}

final _pubKey = Uint8List.fromList(List<int>.generate(32, (i) => 0x10 + i));

Uint8List _cliReplyFrame(Uint8List pubKey, String text) {
  final textBytes = utf8.encode(text);
  final payload = Uint8List(6 + 1 + 1 + 4 + textBytes.length + 1);
  for (var i = 0; i < 6; i++) {
    payload[i] = pubKey[i];
  }
  // path_len, txt_type, ts:4 are zero by default.
  payload[7] = MeshCoreTextTypes.cliData;
  for (var i = 0; i < textBytes.length; i++) {
    payload[12 + i] = textBytes[i];
  }
  return MeshCoreFrame(
    command: MeshCoreResponses.contactMsgRecv,
    payload: payload,
  ).toBytes();
}

Uint8List _loginSuccessFrame(Uint8List pubKey, {required bool admin}) {
  final payload = Uint8List(7);
  payload[0] = admin ? 1 : 0;
  for (var i = 0; i < 6; i++) {
    payload[1 + i] = pubKey[i];
  }
  return MeshCoreFrame(
    command: MeshCorePushCodes.loginSuccess,
    payload: payload,
  ).toBytes();
}

Uint8List _loginFailFrame(Uint8List pubKey) {
  final payload = Uint8List(7);
  for (var i = 0; i < 6; i++) {
    payload[1 + i] = pubKey[i];
  }
  return MeshCoreFrame(
    command: MeshCorePushCodes.loginFail,
    payload: payload,
  ).toBytes();
}

void main() {
  group('sendCliCommandWithReLogin - D49-D2', () {
    test('first-call ok returns ok without invoking login', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final fut = session.sendCliCommandWithReLogin(
        pubKey: _pubKey,
        password: 'secret',
        command: 'ver',
        prefixToken: '01|',
        timestampSeconds: 0,
      );
      await Future<void>.delayed(Duration.zero);
      // First-call reply with the same token -> ok.
      tx.inject(_cliReplyFrame(_pubKey, '01|v1.7.0'));

      final result = await fut;
      expect(result.ok, isTrue);
      expect(result.response, 'v1.7.0');
      // Only the CLI command should have been sent on the wire;
      // no login frame.
      final loginFrames = tx.sent.where((f) {
        if (f.isEmpty) return false;
        final decoded = MeshCoreFrame.fromBytes(f);
        return decoded.command == MeshCoreCommands.sendLogin;
      }).toList();
      expect(loginFrames, isEmpty);
    });

    test('timeout + login ok + retry ok returns ok', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final fut = session.sendCliCommandWithReLogin(
        pubKey: _pubKey,
        password: 'secret',
        command: 'ver',
        prefixToken: '02|',
        timestampSeconds: 0,
        timeout: const Duration(milliseconds: 100),
        loginTimeout: const Duration(milliseconds: 100),
        retryPrefixTokenBuilder: () => '99|',
      );
      // Let the first CLI call time out, then respond to the login
      // with success, then respond to the retry CLI with ok.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      tx.inject(_loginSuccessFrame(_pubKey, admin: true));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      tx.inject(_cliReplyFrame(_pubKey, '99|v1.7.0-retry'));

      final result = await fut;
      expect(result.ok, isTrue);
      expect(result.response, 'v1.7.0-retry');
    });

    test('timeout + login ok + retry timeout returns timeout', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final fut = session.sendCliCommandWithReLogin(
        pubKey: _pubKey,
        password: 'secret',
        command: 'ver',
        prefixToken: '03|',
        timestampSeconds: 0,
        timeout: const Duration(milliseconds: 80),
        loginTimeout: const Duration(milliseconds: 80),
        retryPrefixTokenBuilder: () => '98|',
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      tx.inject(_loginSuccessFrame(_pubKey, admin: true));
      // Do NOT inject a retry reply; let the second CLI call time
      // out on its own.

      final result = await fut;
      expect(result.firmwareTimeout, isTrue);
    });

    test('timeout + login fail returns ORIGINAL timeout', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final fut = session.sendCliCommandWithReLogin(
        pubKey: _pubKey,
        password: 'wrong',
        command: 'ver',
        prefixToken: '04|',
        timestampSeconds: 0,
        timeout: const Duration(milliseconds: 80),
        loginTimeout: const Duration(milliseconds: 80),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      tx.inject(_loginFailFrame(_pubKey));

      final result = await fut;
      expect(result.firmwareTimeout, isTrue);
    });
  });
}
