// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D34c-A — `setContactPathFromTrace` provider helper regression pins.
//
// Pinned invariants:
//   - Sends `CMD_ADD_UPDATE_CONTACT (0x09)` with `out_path_len`
//     equal to the trace hop-bytes length and the bytes copied into
//     the 64-byte path slot starting at payload offset 34/35.
//   - Preserves contact metadata: pubkey, name, advType, latitude,
//     longitude. Only `out_path_len` and `out_path` are mutated.
//   - On wire failure (no OK response), returns `false` and does
//     NOT touch the local contacts list state.
//   - On no-session, logs a redacted skip event and returns `false`.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/meshcore_constants.dart';
import 'package:socialmesh/models/meshcore_contact.dart';
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

  /// Inject a `RESP_CODE_OK (0x00)` reply so the session's
  /// `sendAndWait` completes successfully.
  void simulateOk() {
    final ok = MeshCoreFrame(
      command: MeshCoreResponses.ok,
      payload: Uint8List(0),
    );
    _rx.add(ok.toBytes());
  }

  /// Inject a `RESP_CODE_ERR` so the helper resolves to `false`.
  void simulateErr() {
    final err = MeshCoreFrame(
      command: MeshCoreResponses.err,
      payload: Uint8List.fromList([0x01]),
    );
    _rx.add(err.toBytes());
  }

  /// Inject an empty contacts-list streaming response so the post-ACK
  /// `refresh()` (which calls `session.getContacts()`) completes
  /// quickly. We don't care about the contact entries here — the
  /// D34c-A invariant under test is the OUTBOUND `0x09` payload, not
  /// the post-refresh state.
  void simulateEmptyContactsList() {
    final start = MeshCoreFrame(
      command: MeshCoreResponses.contactsStart,
      payload: Uint8List(4), // total = 0
    );
    _rx.add(start.toBytes());
    final end = MeshCoreFrame(
      command: MeshCoreResponses.endOfContacts,
      payload: Uint8List(0),
    );
    _rx.add(end.toBytes());
  }

  Future<void> dispose() async {
    await _rx.close();
  }
}

/// Pre-seed the contacts notifier with a single test contact whose
/// metadata we'll check is preserved across the path-set call.
MeshCoreContact _seedContact() {
  final pub = Uint8List.fromList(List.generate(32, (i) => i + 1)); // 0x01..0x20
  return MeshCoreContact(
    publicKey: pub,
    name: 'WisMeshCore',
    type: MeshCoreAdvType.chat,
    pathLength: -1,
    path: Uint8List(0),
    latitude: 51.408,
    longitude: -0.1234,
    lastSeen: DateTime.now(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('setContactPathFromTrace (D34c-A provider helper)', () {
    test('OK ack: emits 0x09 with hopBytes copied to out_path slot, '
        'preserves contact metadata', () async {
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

      final notifier = container.read(meshCoreContactsProvider.notifier);
      final contact = _seedContact();
      notifier.addContactLocal(contact);

      // Simulate the firmware's OK response immediately after the
      // call hits the wire. `sendAndWait` blocks on the broadcast
      // stream so we listen-then-fire from a microtask.
      final hopBytes = Uint8List.fromList([0xAB, 0xCD, 0xEF]);
      final future = notifier.setContactPathFromTrace(
        publicKeyHex: contact.publicKeyHex,
        hopBytes: hopBytes,
      );
      // Yield once so the wire frame lands in transport.sent before
      // we inject the OK response.
      await Future<void>.delayed(Duration.zero);
      transport.simulateOk();
      // The helper then triggers `refresh()` which calls
      // `getContacts()` — feed it an empty contacts-list stream so
      // the future completes promptly.
      await Future<void>.delayed(Duration.zero);
      transport.simulateEmptyContactsList();
      final ok = await future;

      expect(ok, isTrue);
      expect(transport.sent, isNotEmpty);

      // The transport now holds two frames: 0x09 add-update-contact
      // followed by 0x04 get-contacts (from the post-ACK refresh).
      // Pick the add-update-contact frame explicitly.
      final addUpdateRaw = transport.sent.firstWhere(
        (b) =>
            MeshCoreFrame.fromBytes(b).command ==
            MeshCoreCommands.addUpdateContact,
      );
      final frame = MeshCoreFrame.fromBytes(addUpdateRaw);
      expect(frame.command, equals(MeshCoreCommands.addUpdateContact));
      final payload = frame.payload;
      // pubkey at offsets 0..31
      expect(
        payload.sublist(0, 32),
        equals(contact.publicKey),
        reason: 'pubkey must be preserved verbatim',
      );
      expect(payload[32], equals(MeshCoreAdvType.chat));
      // flags at 33 — helper writes 0x00 by D34c-A contract
      expect(payload[33], equals(0));
      // out_path_len at 34
      expect(
        payload[34],
        equals(hopBytes.length),
        reason: 'out_path_len must equal hopBytes.length',
      );
      // out_path bytes at 35..(35+N-1)
      expect(payload.sublist(35, 35 + hopBytes.length), equals(hopBytes));
      // remaining path slot (offset 35+N..98) should be zero-padded
      for (var i = 35 + hopBytes.length; i < 99; i++) {
        expect(
          payload[i],
          equals(0),
          reason: 'path slot tail must be zero-padded at offset $i',
        );
      }
      // Name at 99..130 — first 11 bytes of "WisMeshCore"
      expect(
        String.fromCharCodes(payload.sublist(99, 99 + 11)),
        equals('WisMeshCore'),
      );
      // GPS present (143-byte payload — preserves lat+lon)
      expect(
        payload.length,
        equals(143),
        reason: 'GPS-bearing payload is 143 bytes',
      );
    });

    test(
      'non-OK ack: returns false and does NOT mutate the contacts list',
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

        final notifier = container.read(meshCoreContactsProvider.notifier);
        final contact = _seedContact();
        notifier.addContactLocal(contact);
        final beforeContacts = container
            .read(meshCoreContactsProvider)
            .contacts;
        expect(beforeContacts, hasLength(1));

        final future = notifier.setContactPathFromTrace(
          publicKeyHex: contact.publicKeyHex,
          hopBytes: Uint8List.fromList([0xAB]),
        );
        await Future<void>.delayed(Duration.zero);
        transport.simulateErr();
        final ok = await future;

        expect(ok, isFalse);
        // Local state must remain identical (no premature mutation).
        final afterContacts = container.read(meshCoreContactsProvider).contacts;
        expect(afterContacts, hasLength(1));
        expect(
          afterContacts.first.publicKeyHex,
          beforeContacts.first.publicKeyHex,
        );
        expect(
          afterContacts.first.pathLength,
          beforeContacts.first.pathLength,
          reason: 'pathLength must NOT change on failure',
        );
      },
    );

    test(
      'empty hopBytes: emits 0x09 with out_path_len = 0 (direct route)',
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

        final notifier = container.read(meshCoreContactsProvider.notifier);
        final contact = _seedContact();
        notifier.addContactLocal(contact);

        final future = notifier.setContactPathFromTrace(
          publicKeyHex: contact.publicKeyHex,
          hopBytes: Uint8List(0),
        );
        await Future<void>.delayed(Duration.zero);
        transport.simulateOk();
        await Future<void>.delayed(Duration.zero);
        transport.simulateEmptyContactsList();
        final ok = await future;
        expect(ok, isTrue);

        final addUpdateRaw = transport.sent.firstWhere(
          (b) =>
              MeshCoreFrame.fromBytes(b).command ==
              MeshCoreCommands.addUpdateContact,
        );
        final frame = MeshCoreFrame.fromBytes(addUpdateRaw);
        expect(frame.payload[34], equals(0));
        // entire path slot zero-padded
        for (var i = 35; i < 99; i++) {
          expect(frame.payload[i], equals(0));
        }
      },
    );

    test('no session: returns false and does not mutate state', () async {
      final container = ProviderContainer(
        overrides: [meshCoreSessionProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(meshCoreContactsProvider.notifier);
      final contact = _seedContact();
      notifier.addContactLocal(contact);
      final before = container.read(meshCoreContactsProvider).contacts;

      final ok = await notifier.setContactPathFromTrace(
        publicKeyHex: contact.publicKeyHex,
        hopBytes: Uint8List.fromList([0xAB]),
      );
      expect(ok, isFalse);
      final after = container.read(meshCoreContactsProvider).contacts;
      expect(after, equals(before));
    });

    test('unknown publicKey throws ArgumentError', () async {
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

      final notifier = container.read(meshCoreContactsProvider.notifier);
      // No contacts seeded — lookup fails.
      expect(
        () => notifier.setContactPathFromTrace(
          publicKeyHex: 'aabbccdd' * 8,
          hopBytes: Uint8List.fromList([0xAB]),
        ),
        throwsArgumentError,
      );
    });
  });
}
