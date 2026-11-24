// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// The radio tells the app when it evicts a contact to make room
// (PUSH_CODE_CONTACT_DELETED 0x8F) and when a new contact did not fit
// (PUSH_CODE_CONTACTS_FULL 0x90).

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/meshcore_constants.dart';
import 'package:socialmesh/models/meshcore_contact.dart';
import 'package:socialmesh/providers/app_lifecycle_provider.dart';
import 'package:socialmesh/providers/meshcore_message_providers.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_frame.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_session.dart';

class _FakeTransport implements MeshCoreTransport {
  final _rx = StreamController<Uint8List>.broadcast();
  bool _connected = true;

  @override
  Stream<Uint8List> get rawRxStream => _rx.stream;

  @override
  Future<void> sendRaw(Uint8List data) async {}

  @override
  bool get isConnected => _connected;

  void emit(MeshCoreFrame frame) => _rx.add(frame.toBytes());

  Future<void> dispose() async {
    _connected = false;
    await _rx.close();
  }
}

Uint8List _key(int first) =>
    Uint8List.fromList(List.generate(32, (i) => (first + i) & 0xFF));

MeshCoreContact _contact(String name, int first) => MeshCoreContact(
  publicKey: _key(first),
  name: name,
  type: MeshCoreAdvType.chat,
  pathLength: -1,
  path: Uint8List(0),
  lastSeen: DateTime(2026, 11, 24, 12),
);

class _Roster extends MeshCoreContactsNotifier {
  @override
  MeshCoreContactsState build() => MeshCoreContactsState(
    contacts: [_contact('Coburg Hill', 0x30), _contact('Werribee South', 0x40)],
    lastRefresh: DateTime(2026, 11, 24),
  );
}

class _Foreground extends AppLifecycleNotifier {
  @override
  bool build() => true;
}

Future<void> _pumpUntil(bool Function() done) async {
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  while (!done() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeTransport transport;
  late ProviderContainer c;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    transport = _FakeTransport();
    c = ProviderContainer(
      overrides: [
        meshCoreSessionProvider.overrideWithValue(MeshCoreSession(transport)),
        appLifecycleProvider.overrideWith(_Foreground.new),
        meshCoreContactsProvider.overrideWith(_Roster.new),
      ],
    );
    c.read(meshCoreConversationsProvider);
  });

  tearDown(() async {
    c.dispose();
    await transport.dispose();
  });

  test(
    'contacts full sets the flag; the radio evicting one clears it',
    () async {
      transport.emit(
        MeshCoreFrame(
          command: MeshCorePushCodes.contactsFull,
          payload: Uint8List(0),
        ),
      );
      await _pumpUntil(() => c.read(meshCoreContactsProvider).storageFull);
      expect(c.read(meshCoreContactsProvider).storageFull, isTrue);

      transport.emit(
        MeshCoreFrame(
          command: MeshCorePushCodes.contactDeleted,
          payload: _key(0x30),
        ),
      );
      await _pumpUntil(
        () => c.read(meshCoreContactsProvider).contacts.length == 1,
      );
      final state = c.read(meshCoreContactsProvider);
      expect(state.contacts.single.name, 'Werribee South');
      expect(state.storageFull, isFalse);
    },
  );

  test('a short contact deleted frame changes nothing', () async {
    transport.emit(
      MeshCoreFrame(
        command: MeshCorePushCodes.contactDeleted,
        payload: Uint8List(8),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(c.read(meshCoreContactsProvider).contacts, hasLength(2));
  });
}
