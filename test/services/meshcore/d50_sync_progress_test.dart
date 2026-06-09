// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// MO-4 / MO-2: roster-sync progress reporting.
//
// Pinned invariants:
//   - `getContacts(onProgress:)` parses the firmware v3+ `CONTACTS_START`
//     (0x02) u32-LE total and reports `(0, total)` once, then
//     `(received, total)` per CONTACT (0x03) frame.
//   - When `CONTACTS_START` carries no count (older firmware, payload
//     < 4 bytes), `total` is reported as `null` (indeterminate).
//   - `getChannels(onProgress:)` reports `(i + 1, maxChannels)` per slot.

import 'dart:async';
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

  /// Optional auto-responder: invoked with each outbound command byte; any
  /// frames it returns are injected back on the RX stream (used to drive
  /// `getChannels` slot-by-slot without real 2s timeouts).
  List<Uint8List> Function(int command)? autoRespond;

  @override
  Stream<Uint8List> get rawRxStream => _rx.stream;

  @override
  Future<void> sendRaw(Uint8List data) async {
    sent.add(Uint8List.fromList(data));
    final responder = autoRespond;
    if (responder != null && data.isNotEmpty) {
      for (final reply in responder(data[0])) {
        Future<void>.microtask(() {
          if (_connected) _rx.add(reply);
        });
      }
    }
  }

  @override
  bool get isConnected => _connected;

  void inject(Uint8List bytes) => _rx.add(bytes);

  Future<void> dispose() async {
    _connected = false;
    await _rx.close();
  }
}

Uint8List _contactsStart({int? total}) {
  if (total == null) {
    return MeshCoreFrame(
      command: MeshCoreResponses.contactsStart,
      payload: Uint8List(0),
    ).toBytes();
  }
  final payload = Uint8List(4);
  ByteData.sublistView(payload).setUint32(0, total, Endian.little);
  return MeshCoreFrame(
    command: MeshCoreResponses.contactsStart,
    payload: payload,
  ).toBytes();
}

// Minimal-but-valid CONTACT payload (135 bytes): pubkey, adv_type=chat,
// flags, path_len=0, 64 B path, 32 B name, last_advert_ts.
Uint8List _contactFrame(int seed, String name) {
  final payload = Uint8List(135);
  for (var i = 0; i < 32; i++) {
    payload[i] = (seed + i) & 0xFF;
  }
  payload[32] = 0x01; // adv_type = chat
  payload[33] = 0x00; // flags
  payload[34] = 0x00; // path_len
  final nameBytes = name.codeUnits;
  payload.setRange(99, 99 + nameBytes.length, nameBytes);
  ByteData.sublistView(payload).setUint32(131, 1, Endian.little);
  return MeshCoreFrame(
    command: MeshCoreResponses.contact,
    payload: payload,
  ).toBytes();
}

Uint8List _endOfContacts() => MeshCoreFrame(
  command: MeshCoreResponses.endOfContacts,
  payload: Uint8List(0),
).toBytes();

Future<void> _pump() => Future<void>.delayed(Duration.zero);

void main() {
  group('MO-2/MO-4: getContacts() sync progress', () {
    test('reports (0,total) then per-contact with the v3+ count', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final progress = <(int, int?)>[];
      final fut = session.getContacts(
        onProgress: (received, total) => progress.add((received, total)),
      );
      await _pump();

      tx.inject(_contactsStart(total: 3));
      await _pump();
      tx.inject(_contactFrame(0x10, 'Alpha'));
      await _pump();
      tx.inject(_contactFrame(0x40, 'Bravo'));
      await _pump();
      tx.inject(_contactFrame(0x70, 'Charlie'));
      await _pump();
      tx.inject(_endOfContacts());

      final contacts = await fut;
      expect(contacts, hasLength(3));
      expect(progress, equals([(0, 3), (1, 3), (2, 3), (3, 3)]));
    });

    test('reports null total when CONTACTS_START omits the count', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final progress = <(int, int?)>[];
      final fut = session.getContacts(
        onProgress: (received, total) => progress.add((received, total)),
      );
      await _pump();

      tx.inject(_contactsStart(total: null));
      await _pump();
      tx.inject(_contactFrame(0x10, 'Alpha'));
      await _pump();
      tx.inject(_contactFrame(0x40, 'Bravo'));
      await _pump();
      tx.inject(_endOfContacts());

      await fut;
      expect(progress, equals([(0, null), (1, null), (2, null)]));
    });
  });

  group('MO-4: getChannels() sync progress', () {
    test('reports (i+1, maxChannels) per probed slot', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      // Reply to each CMD_GET_CHANNEL with a (non-parsing) channelInfo so the
      // per-slot sendAndWait resolves immediately instead of timing out.
      tx.autoRespond = (command) {
        if (command == MeshCoreCommands.getChannel) {
          return [
            MeshCoreFrame(
              command: MeshCoreResponses.channelInfo,
              payload: Uint8List(0),
            ).toBytes(),
          ];
        }
        return const [];
      };
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final progress = <(int, int)>[];
      await session.getChannels(
        maxChannels: 3,
        onProgress: (received, total) => progress.add((received, total)),
      );

      expect(progress, equals([(1, 3), (2, 3), (3, 3)]));
    });
  });
}
