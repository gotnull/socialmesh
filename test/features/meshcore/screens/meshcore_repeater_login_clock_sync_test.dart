// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// The per-repeater "auto clock sync on login" setting sends `clock sync`
// after an admin login, and nothing when it is off.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/features/meshcore/screens/meshcore_repeater_login_dialog.dart';
import 'package:socialmesh/models/meshcore_contact.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_messages.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_session.dart';
import 'package:socialmesh/services/meshcore/storage/meshcore_admin_auto_clock_sync_store.dart';

class _NullTransport implements MeshCoreTransport {
  @override
  Stream<Uint8List> get rawRxStream => const Stream.empty();

  @override
  Future<void> sendRaw(Uint8List data) async {}

  @override
  bool get isConnected => true;
}

class _CliSession extends MeshCoreSession {
  _CliSession() : super(_NullTransport());

  final List<(String, String)> sent = [];

  @override
  Future<MeshCoreCliResult> sendCliCommand({
    required Uint8List pubKey,
    required String command,
    required String prefixToken,
    int attempt = 0,
    int? timestampSeconds,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    sent.add((command, prefixToken));
    return MeshCoreCliResult.ok(
      response: 'OK - clock set: 06:30 - 28/11/2026 UTC',
    );
  }
}

final _repeater = MeshCoreContact(
  publicKey: Uint8List.fromList(List<int>.generate(32, (i) => i + 1)),
  name: 'Ridge',
  type: MeshCoreAdvType.repeater,
  pathLength: -1,
  path: Uint8List(0),
  lastSeen: DateTime(2026, 11, 28),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('sends clock sync when the repeater has it switched on', () async {
    final prefs = await SharedPreferences.getInstance();
    await MeshCoreAdminAutoClockSyncStore(prefs)
        .setEnabled(_repeater.publicKeyHex, true);
    final session = _CliSession();

    await syncMeshCoreRepeaterClockAfterLogin(session, _repeater);

    expect(session.sent, [('clock sync', 'FF|')]);
  });

  test('sends nothing when it is off', () async {
    final session = _CliSession();

    await syncMeshCoreRepeaterClockAfterLogin(session, _repeater);

    expect(session.sent, isEmpty);
  });

  test('the setting is per repeater', () async {
    final prefs = await SharedPreferences.getInstance();
    await MeshCoreAdminAutoClockSyncStore(prefs).setEnabled('ffeeddcc', true);
    final session = _CliSession();

    await syncMeshCoreRepeaterClockAfterLogin(session, _repeater);

    expect(session.sent, isEmpty);
  });
}
