// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D34b-A1 — integration test: advert push frames flowing through the
// `MeshCoreConversationsNotifier._handleAdvertPush` path land in the
// `meshCoreDiscoveredAdvertsProvider` recent-heard feed.
//
// Pinned invariants:
//   - A `PUSH_CODE_NEW_ADVERT (0x8A)` frame with a valid 147-byte
//     contact payload records a discovered advert with `hasFullInfo`.
//   - A `PUSH_CODE_ADVERT (0x80)` frame with a 32-byte pubkey bumps an
//     existing entry's `lastHeard` (or creates a minimal stub if no
//     entry exists yet).
//   - Existing D17.C contacts-refresh side-effects are NOT regressed
//     by the new hook (we only add a call; we don't gate or replace).

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/meshcore_constants.dart';
import 'package:socialmesh/providers/meshcore_message_providers.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_frame.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_session.dart';

class _RecordingTransport implements MeshCoreTransport {
  final StreamController<Uint8List> _rx =
      StreamController<Uint8List>.broadcast();
  final List<Uint8List> sent = [];
  bool connected = true;

  @override
  Stream<Uint8List> get rawRxStream => _rx.stream;

  @override
  Future<void> sendRaw(Uint8List data) async {
    sent.add(Uint8List.fromList(data));
  }

  @override
  bool get isConnected => connected;

  void deliverFrame(MeshCoreFrame frame) {
    _rx.add(frame.toBytes());
  }

  /// Inject an empty contacts-list streaming response so the refresh()
  /// triggered by `_handleAdvertPush` completes before the test
  /// container disposes. Without this, the lingering `getContacts()`
  /// future writes to `state` after the notifier is disposed and
  /// surfaces a Riverpod async-gap exception (pre-existing bug, not
  /// caused by D34b-A1; we just need to stay clear of it).
  void simulateEmptyContactsList() {
    _rx.add(
      MeshCoreFrame(
        command: MeshCoreResponses.contactsStart,
        payload: Uint8List(4),
      ).toBytes(),
    );
    _rx.add(
      MeshCoreFrame(
        command: MeshCoreResponses.endOfContacts,
        payload: Uint8List(0),
      ).toBytes(),
    );
  }

  Future<void> dispose() async {
    await _rx.close();
  }
}

/// Build a 147-byte CONTACT response payload (the same shape
/// `PUSH_CODE_NEW_ADVERT` carries). Mirrors the helper in
/// `test/services/meshcore/protocol/parse_contact_layout_test.dart`.
Uint8List _buildContactPayload({
  required Uint8List pubKey,
  int advType = 1,
  String name = 'Discovered',
}) {
  assert(pubKey.length == 32);
  final out = Uint8List(147);
  out.setRange(0, 32, pubKey);
  out[32] = advType;
  out[33] = 0; // flags
  out[34] = 0xFF; // path_len = flood
  // path slot (35..98) zero-padded
  // name at 99..130
  final nameBytes = utf8.encode(name);
  for (var i = 0; i < nameBytes.length && i < 32; i++) {
    out[99 + i] = nameBytes[i];
  }
  // last_advert_ts / lat / lon / lastmod all zero
  return out;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('D34b-A1 advert-push → discovery integration', () {
    test('PUSH_CODE_NEW_ADVERT (0x8A) records a discovered advert', () async {
      final transport = _RecordingTransport();
      final session = MeshCoreSession(transport);
      addTearDown(() async {
        await session.dispose();
        await transport.dispose();
      });

      final container = ProviderContainer(
        overrides: [meshCoreSessionProvider.overrideWithValue(session)],
      );
      addTearDown(container.dispose);

      // Force-build the conversations notifier so it subscribes to the
      // session frame stream before we deliver the synthetic advert.
      container.read(meshCoreConversationsProvider);

      final pubKey = Uint8List.fromList(List.generate(32, (i) => i + 1));
      transport.deliverFrame(
        MeshCoreFrame(
          command: MeshCorePushCodes.newAdvert,
          payload: _buildContactPayload(pubKey: pubKey, name: 'Discovered'),
        ),
      );

      // Yield twice so the frame stream listener + recordAdvert
      // microtask both run.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      // Drain the post-handler `getContacts()` refresh by feeding an
      // empty contacts-list streaming response.
      transport.simulateEmptyContactsList();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(meshCoreDiscoveredAdvertsProvider);
      expect(state, hasLength(1));
      expect(state.first.name, 'Discovered');
      expect(state.first.hasFullInfo, isTrue);
      expect(state.first.advType, 1);
    });

    test(
      'PUSH_CODE_ADVERT (0x80) bumps lastHeard / creates minimal stub',
      () async {
        final transport = _RecordingTransport();
        final session = MeshCoreSession(transport);
        addTearDown(() async {
          await session.dispose();
          await transport.dispose();
        });

        final container = ProviderContainer(
          overrides: [meshCoreSessionProvider.overrideWithValue(session)],
        );
        addTearDown(container.dispose);

        container.read(meshCoreConversationsProvider);

        // First a 0x8A so we have a real entry to bump.
        final pubKey = Uint8List.fromList(List.generate(32, (i) => i + 1));
        transport.deliverFrame(
          MeshCoreFrame(
            command: MeshCorePushCodes.newAdvert,
            payload: _buildContactPayload(pubKey: pubKey, name: 'Discovered'),
          ),
        );
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        transport.simulateEmptyContactsList();
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        final initialLastHeard = container
            .read(meshCoreDiscoveredAdvertsProvider)
            .first
            .lastHeard;

        await Future<void>.delayed(const Duration(milliseconds: 2));

        // Now a 0x80 carrying just the pubkey.
        transport.deliverFrame(
          MeshCoreFrame(command: MeshCorePushCodes.advert, payload: pubKey),
        );
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        transport.simulateEmptyContactsList();
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final state = container.read(meshCoreDiscoveredAdvertsProvider);
        expect(state, hasLength(1), reason: 'no duplicate entry');
        expect(
          state.first.lastHeard.isAfter(initialLastHeard),
          isTrue,
          reason: '0x80 bumped lastHeard',
        );
        // Metadata preserved across the bump.
        expect(state.first.name, 'Discovered');
        expect(state.first.hasFullInfo, isTrue);
      },
    );

    test('PUSH_CODE_ADVERT (0x80) for an unknown pubkey creates a minimal '
        'stub (hasFullInfo=false, empty name)', () async {
      final transport = _RecordingTransport();
      final session = MeshCoreSession(transport);
      addTearDown(() async {
        await session.dispose();
        await transport.dispose();
      });

      final container = ProviderContainer(
        overrides: [meshCoreSessionProvider.overrideWithValue(session)],
      );
      addTearDown(container.dispose);

      container.read(meshCoreConversationsProvider);

      final unknownPubKey = Uint8List.fromList(
        List.generate(32, (i) => 0x80 + i),
      );
      transport.deliverFrame(
        MeshCoreFrame(
          command: MeshCorePushCodes.advert,
          payload: unknownPubKey,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      transport.simulateEmptyContactsList();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(meshCoreDiscoveredAdvertsProvider);
      expect(state, hasLength(1));
      expect(state.first.hasFullInfo, isFalse);
      expect(state.first.name, '');
      expect(state.first.advType, isNull);
    });
  });
}
