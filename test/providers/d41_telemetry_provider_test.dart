// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D41-A: `meshCoreTelemetryProvider` regression pins.
//
// Pinned invariants:
//   - No-session path transitions to failure with reason "no_session".
//   - Missing-contact transitions to failure with reason "contact_missing".
//   - A successful telemetry round-trip transitions to success with
//     `lastResponse.readings` populated and `cooldownUntil` armed.
//   - A timeout transitions to failure with reason "timeout" and arms
//     the 10 s cooldown.
//   - A second request inside the cooldown window transitions to
//     `cooling` without sending bytes.
//   - `visibleStatus(now > cooldownUntil)` resolves cooling back to
//     `success` (when a prior response is held) or `idle` otherwise,
//     and rewrites the underlying state.
//   - Family state is per contact (refreshing contact A leaves contact
//     B untouched).

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

  /// When true, auto-respond with SENT ack + matching 0x8B telemetry
  /// push. When false (default), responses must be injected manually
  /// or the helper will time out.
  bool autoRespond = false;

  int _nextTag = 0xC0FFEE00;

  /// LPP body emitted on auto-respond. Default: voltage 4.05 V on
  /// channel 1 (`[1][116][0x01][0x95]`).
  Uint8List autoLppBody = Uint8List.fromList([1, 116, 0x01, 0x95]);

  @override
  Stream<Uint8List> get rawRxStream => _rx.stream;

  @override
  Future<void> sendRaw(Uint8List data) async {
    sent.add(Uint8List.fromList(data));
    if (!autoRespond) return;
    final frame = MeshCoreFrame.fromBytes(data);
    if (frame.command != MeshCoreCommands.sendBinaryReq) return;
    // The outbound payload is `[recipientPubKey:32 B][req_type=0x03][0x00]`.
    if (frame.payload.length < 34) return;
    if (frame.payload[32] != 0x03) return;
    final recipientPubKey = frame.payload.sublist(0, 32);
    final tag = _nextTag++;

    scheduleMicrotask(() {
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
      // PUSH_CODE_TELEMETRY_RESPONSE 0x8B layout:
      //   [reserved:u8][pubkey_prefix:6 B][cayenne_lpp_tlv...]
      final pushPayload = Uint8List(1 + 6 + autoLppBody.length);
      pushPayload[0] = 0;
      pushPayload.setRange(1, 7, recipientPubKey.sublist(0, 6));
      pushPayload.setRange(7, 7 + autoLppBody.length, autoLppBody);
      _rx.add(
        MeshCoreFrame(
          command: MeshCorePushCodes.telemetryResponse,
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

MeshCoreContact _contact({
  required Uint8List pubKey,
  String name = 'Sensor-Alpha',
  int type = MeshCoreAdvType.sensor,
}) {
  return MeshCoreContact(
    publicKey: pubKey,
    name: name,
    type: type,
    pathLength: -1,
    path: Uint8List(0),
    lastSeen: DateTime(2026, 5, 11, 12),
  );
}

Uint8List _pubkey(int seed) =>
    Uint8List.fromList(List.generate(32, (i) => (seed + i) & 0xFF));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('meshCoreTelemetryProvider - D41-A', () {
    test('no-session: transitions to failure with reason no_session', () async {
      final container = ProviderContainer(
        overrides: [meshCoreSessionProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);

      const hex =
          '0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20';
      final notifier = container.read(meshCoreTelemetryProvider(hex).notifier);
      await notifier.requestRefresh();

      final state = container.read(meshCoreTelemetryProvider(hex));
      expect(state.status, MeshCoreTelemetryStatus.failure);
      expect(state.lastError, 'no_session');
    });

    test(
      'contact missing: transitions to failure with reason contact_missing',
      () async {
        final tx = _RecordingTransport();
        addTearDown(tx.dispose);
        final session = MeshCoreSession(tx);
        addTearDown(session.dispose);

        final container = ProviderContainer(
          overrides: [meshCoreSessionProvider.overrideWithValue(session)],
        );
        addTearDown(container.dispose);

        const hex =
            '0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20';
        final notifier = container.read(
          meshCoreTelemetryProvider(hex).notifier,
        );
        await notifier.requestRefresh();

        final state = container.read(meshCoreTelemetryProvider(hex));
        expect(state.status, MeshCoreTelemetryStatus.failure);
        expect(state.lastError, 'contact_missing');
      },
    );

    test(
      'successful request: transitions to success with parsed readings',
      () async {
        final tx = _RecordingTransport()..autoRespond = true;
        addTearDown(tx.dispose);
        final session = MeshCoreSession(tx);
        addTearDown(session.dispose);

        final container = ProviderContainer(
          overrides: [meshCoreSessionProvider.overrideWithValue(session)],
        );
        addTearDown(container.dispose);

        final pubKey = _pubkey(0x11);
        final contact = _contact(pubKey: pubKey);
        container
            .read(meshCoreContactsProvider.notifier)
            .addContactLocal(contact);

        final notifier = container.read(
          meshCoreTelemetryProvider(contact.publicKeyHex).notifier,
        );
        await notifier.requestRefresh();

        final state = container.read(
          meshCoreTelemetryProvider(contact.publicKeyHex),
        );
        expect(state.status, MeshCoreTelemetryStatus.success);
        expect(state.lastResponse, isNotNull);
        expect(state.lastResponse!.readings, hasLength(1));
        expect(state.cooldownUntil, isNotNull);
        expect(state.lastError, isNull);
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

      final contact = _contact(pubKey: _pubkey(0x22));
      container
          .read(meshCoreContactsProvider.notifier)
          .addContactLocal(contact);

      // No auto-response -> the session's inner 3 s ACK timeout fires
      // and the provider records a 'timeout' failure with cooldown.
      final notifier = container.read(
        meshCoreTelemetryProvider(contact.publicKeyHex).notifier,
      );
      await notifier.requestRefresh();

      final state = container.read(
        meshCoreTelemetryProvider(contact.publicKeyHex),
      );
      expect(state.status, MeshCoreTelemetryStatus.failure);
      expect(state.lastError, 'timeout');
      expect(state.cooldownUntil, isNotNull);
    }, timeout: const Timeout(Duration(seconds: 30)));

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

      final contact = _contact(pubKey: _pubkey(0x33));
      container
          .read(meshCoreContactsProvider.notifier)
          .addContactLocal(contact);

      final notifier = container.read(
        meshCoreTelemetryProvider(contact.publicKeyHex).notifier,
      );
      await notifier.requestRefresh();
      expect(
        container.read(meshCoreTelemetryProvider(contact.publicKeyHex)).status,
        MeshCoreTelemetryStatus.success,
      );

      final sentCountBefore = tx.sent.length;
      await notifier.requestRefresh();

      final state = container.read(
        meshCoreTelemetryProvider(contact.publicKeyHex),
      );
      expect(state.status, MeshCoreTelemetryStatus.cooling);
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

      final contact = _contact(pubKey: _pubkey(0x44));
      container
          .read(meshCoreContactsProvider.notifier)
          .addContactLocal(contact);

      final notifier = container.read(
        meshCoreTelemetryProvider(contact.publicKeyHex).notifier,
      );
      await notifier.requestRefresh();
      // Second refresh -> cooling.
      await notifier.requestRefresh();
      expect(
        container.read(meshCoreTelemetryProvider(contact.publicKeyHex)).status,
        MeshCoreTelemetryStatus.cooling,
      );

      final later = DateTime.now().add(const Duration(seconds: 11));
      final visible = notifier.visibleStatus(later);
      expect(visible, MeshCoreTelemetryStatus.success);
      expect(
        container.read(meshCoreTelemetryProvider(contact.publicKeyHex)).status,
        MeshCoreTelemetryStatus.success,
      );
    });

    test('family state is per contact: refreshing contact A leaves '
        'contact B untouched', () async {
      final tx = _RecordingTransport()..autoRespond = true;
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final container = ProviderContainer(
        overrides: [meshCoreSessionProvider.overrideWithValue(session)],
      );
      addTearDown(container.dispose);

      final a = _contact(pubKey: _pubkey(0x10), name: 'Sensor-A');
      final b = _contact(pubKey: _pubkey(0x80), name: 'Sensor-B');
      container.read(meshCoreContactsProvider.notifier)
        ..addContactLocal(a)
        ..addContactLocal(b);

      final notifierA = container.read(
        meshCoreTelemetryProvider(a.publicKeyHex).notifier,
      );
      await notifierA.requestRefresh();

      expect(
        container.read(meshCoreTelemetryProvider(a.publicKeyHex)).status,
        MeshCoreTelemetryStatus.success,
      );
      expect(
        container.read(meshCoreTelemetryProvider(b.publicKeyHex)).status,
        MeshCoreTelemetryStatus.idle,
        reason: 'contact B state must NOT be touched by contact A refresh',
      );
    });
  });
}
