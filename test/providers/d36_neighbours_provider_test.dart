// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D36-A: `meshCoreNeighborsProvider` regression pins.
//
// Pinned invariants:
//   - No-session path transitions to failure with reason "no_session".
//   - Missing-contact transitions to failure with reason "contact_missing".
//   - A successful request transitions to success with the parsed list.
//   - A timeout transitions to failure with reason "timeout" and arms
//     the 10 s cooldown.
//   - A second request inside the cooldown window transitions to
//     `cooling` without sending bytes.
//   - The cooldown elapses cleanly (visibleStatus returns to idle or
//     success once `now > cooldownUntil`).
//   - Family state is per repeater (state in one family entry does
//     not leak into another).

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
  bool _connected = true;

  /// When true, auto-respond with SENT ack + matching neighbours push.
  /// When false (default), responses must be injected manually.
  bool autoRespond = false;

  /// Counter for tag values handed out to auto-respond requests.
  int _nextTag = 0xC0FFEE00;

  /// Optional list of neighbour rows the auto-respond push will
  /// include. Default = 1 neighbour with simple values.
  List<({Uint8List prefix, int lastHeardSecs, int snrRaw})> autoRows = [
    (
      prefix: Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF]),
      lastHeardSecs: 42,
      snrRaw: 24,
    ),
  ];

  @override
  Stream<Uint8List> get rawRxStream => _rx.stream;

  @override
  Future<void> sendRaw(Uint8List data) async {
    sent.add(Uint8List.fromList(data));
    if (!autoRespond) return;
    final frame = MeshCoreFrame.fromBytes(data);
    if (frame.command != MeshCoreCommands.sendBinaryReq) return;
    final tag = _nextTag++;

    scheduleMicrotask(() {
      // SENT ack.
      final ack = Uint8List(9);
      final bd = ByteData.sublistView(ack);
      ack[0] = 0; // route_type
      bd.setUint32(1, tag, Endian.little);
      bd.setUint32(5, 1500, Endian.little);
      _rx.add(
        MeshCoreFrame(command: MeshCoreResponses.sent, payload: ack).toBytes(),
      );
    });

    scheduleMicrotask(() {
      // Push response with the same tag.
      final body = BytesBuilder();
      final header = Uint8List(4);
      ByteData.sublistView(header)
        ..setUint16(0, autoRows.length, Endian.little)
        ..setUint16(2, autoRows.length, Endian.little);
      body.add(header);
      for (final r in autoRows) {
        body.add(r.prefix);
        final rec = ByteData(5)
          ..setUint32(0, r.lastHeardSecs, Endian.little)
          ..setInt8(4, r.snrRaw);
        body.add(rec.buffer.asUint8List());
      }
      final neighboursPayload = body.toBytes();

      final pushPayload = Uint8List(5 + neighboursPayload.length);
      pushPayload[0] = 0; // reserved
      ByteData.sublistView(pushPayload).setUint32(1, tag, Endian.little);
      pushPayload.setRange(5, 5 + neighboursPayload.length, neighboursPayload);

      _rx.add(
        MeshCoreFrame(
          command: MeshCorePushCodes.binaryResponse,
          payload: pushPayload,
        ).toBytes(),
      );
    });
  }

  @override
  bool get isConnected => _connected;

  Future<void> dispose() async {
    _connected = false;
    await _rx.close();
  }
}

MeshCoreContact _repeater({
  required Uint8List pubKey,
  String name = 'Repeater-Alpha',
}) {
  return MeshCoreContact(
    publicKey: pubKey,
    name: name,
    type: MeshCoreAdvType.repeater,
    pathLength: -1,
    path: Uint8List(0),
    lastSeen: DateTime(2026, 5, 11, 12),
  );
}

Uint8List _pubkey(int seed) =>
    Uint8List.fromList(List.generate(32, (i) => seed + i));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('meshCoreNeighborsProvider - D36-A', () {
    test('no-session: transitions to failure with reason no_session', () async {
      final container = ProviderContainer(
        overrides: [meshCoreSessionProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);

      const hex =
          '0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20';
      final notifier = container.read(meshCoreNeighborsProvider(hex).notifier);
      await notifier.requestRefresh();

      final state = container.read(meshCoreNeighborsProvider(hex));
      expect(state.status, MeshCoreNeighborsStatus.failure);
      expect(state.lastError, 'no_session');
    });

    test('contact missing: transitions to failure with '
        'reason contact_missing', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final container = ProviderContainer(
        overrides: [meshCoreSessionProvider.overrideWithValue(session)],
      );
      addTearDown(container.dispose);

      // No contact seeded -> notifier can't find the pubkey.
      const hex =
          '0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20';
      final notifier = container.read(meshCoreNeighborsProvider(hex).notifier);
      await notifier.requestRefresh();

      final state = container.read(meshCoreNeighborsProvider(hex));
      expect(state.status, MeshCoreNeighborsStatus.failure);
      expect(state.lastError, 'contact_missing');
    });

    test(
      'successful request: transitions to success with parsed list',
      () async {
        final tx = _RecordingTransport()..autoRespond = true;
        addTearDown(tx.dispose);
        final session = MeshCoreSession(tx);
        addTearDown(session.dispose);

        final container = ProviderContainer(
          overrides: [meshCoreSessionProvider.overrideWithValue(session)],
        );
        addTearDown(container.dispose);

        final pubKey = _pubkey(1);
        final contact = _repeater(pubKey: pubKey);
        container
            .read(meshCoreContactsProvider.notifier)
            .addContactLocal(contact);

        final notifier = container.read(
          meshCoreNeighborsProvider(contact.publicKeyHex).notifier,
        );
        await notifier.requestRefresh();

        final state = container.read(
          meshCoreNeighborsProvider(contact.publicKeyHex),
        );
        expect(state.status, MeshCoreNeighborsStatus.success);
        expect(state.lastResponse, isNotNull);
        expect(state.lastResponse!.reportedCount, 1);
        expect(state.lastResponse!.results, hasLength(1));
        expect(state.lastResponse!.results.first.snrQuarter, 24);
        expect(state.cooldownUntil, isNotNull);
      },
    );

    test('timeout: transitions to failure with reason "timeout" and arms '
        'the cooldown', () async {
      final tx = _RecordingTransport(); // autoRespond = false
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final container = ProviderContainer(
        overrides: [meshCoreSessionProvider.overrideWithValue(session)],
      );
      addTearDown(container.dispose);

      final contact = _repeater(pubKey: _pubkey(2));
      container
          .read(meshCoreContactsProvider.notifier)
          .addContactLocal(contact);

      // No auto-response -> session sees no SENT ack -> timeout.
      // The helper's inner 3 s ACK timeout fires; provider records
      // a 'timeout' failure and arms the cooldown.
      final notifier = container.read(
        meshCoreNeighborsProvider(contact.publicKeyHex).notifier,
      );
      await notifier.requestRefresh();

      final state = container.read(
        meshCoreNeighborsProvider(contact.publicKeyHex),
      );
      expect(state.status, MeshCoreNeighborsStatus.failure);
      expect(state.lastError, 'timeout');
      expect(state.cooldownUntil, isNotNull);
    });

    test('cooldown: second request inside the 10 s window transitions '
        'to cooling without sending bytes', () async {
      final tx = _RecordingTransport()..autoRespond = true;
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final container = ProviderContainer(
        overrides: [meshCoreSessionProvider.overrideWithValue(session)],
      );
      addTearDown(container.dispose);

      final contact = _repeater(pubKey: _pubkey(3));
      container
          .read(meshCoreContactsProvider.notifier)
          .addContactLocal(contact);

      final notifier = container.read(
        meshCoreNeighborsProvider(contact.publicKeyHex).notifier,
      );
      await notifier.requestRefresh();
      expect(
        container.read(meshCoreNeighborsProvider(contact.publicKeyHex)).status,
        MeshCoreNeighborsStatus.success,
      );

      final sentCountBefore = tx.sent.length;
      await notifier.requestRefresh();

      final state = container.read(
        meshCoreNeighborsProvider(contact.publicKeyHex),
      );
      expect(state.status, MeshCoreNeighborsStatus.cooling);
      expect(
        tx.sent.length,
        sentCountBefore,
        reason: 'cooldown must NOT issue a new wire send',
      );
    });

    test('visibleStatus(now): cooling clears to success once the '
        'cooldown timestamp has elapsed', () async {
      final tx = _RecordingTransport()..autoRespond = true;
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final container = ProviderContainer(
        overrides: [meshCoreSessionProvider.overrideWithValue(session)],
      );
      addTearDown(container.dispose);

      final contact = _repeater(pubKey: _pubkey(4));
      container
          .read(meshCoreContactsProvider.notifier)
          .addContactLocal(contact);

      final notifier = container.read(
        meshCoreNeighborsProvider(contact.publicKeyHex).notifier,
      );
      await notifier.requestRefresh();
      // Second refresh -> cooling.
      await notifier.requestRefresh();
      expect(
        container.read(meshCoreNeighborsProvider(contact.publicKeyHex)).status,
        MeshCoreNeighborsStatus.cooling,
      );

      // 11 s in the future: cooldown has elapsed.
      final later = DateTime.now().add(const Duration(seconds: 11));
      final visible = notifier.visibleStatus(later);
      expect(visible, MeshCoreNeighborsStatus.success);
      // Confirm the underlying state was rewritten.
      expect(
        container.read(meshCoreNeighborsProvider(contact.publicKeyHex)).status,
        MeshCoreNeighborsStatus.success,
      );
    });

    test('family state is per repeater: refreshing repeater A leaves '
        'repeater B untouched', () async {
      final tx = _RecordingTransport()..autoRespond = true;
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final container = ProviderContainer(
        overrides: [meshCoreSessionProvider.overrideWithValue(session)],
      );
      addTearDown(container.dispose);

      final a = _repeater(pubKey: _pubkey(10), name: 'Repeater-A');
      final b = _repeater(pubKey: _pubkey(20), name: 'Repeater-B');
      container.read(meshCoreContactsProvider.notifier)
        ..addContactLocal(a)
        ..addContactLocal(b);

      final notifierA = container.read(
        meshCoreNeighborsProvider(a.publicKeyHex).notifier,
      );
      await notifierA.requestRefresh();

      expect(
        container.read(meshCoreNeighborsProvider(a.publicKeyHex)).status,
        MeshCoreNeighborsStatus.success,
      );
      expect(
        container.read(meshCoreNeighborsProvider(b.publicKeyHex)).status,
        MeshCoreNeighborsStatus.idle,
        reason: 'Repeater-B state must NOT be touched by Repeater-A refresh',
      );
    });
  });
}
