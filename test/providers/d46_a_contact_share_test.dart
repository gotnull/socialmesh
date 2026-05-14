// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D46-A: `meshCoreContactsProvider` share/export/import integration
// pins.
//
// Pinned invariants:
//   - broadcastSelfContact: returns true on RESP_CODE_OK, false on
//     no-session / empty self-info.
//   - exportContactUrl: returns canonical `meshcore://<hex>` URL on
//     RESP_CODE_EXPORT_CONTACT, null on no-session / firmware error.
//   - previewContactImport: returns a modern preview for valid
//     `meshcore://<hex>`, a legacy preview for `<pubkeyhex>:<name>`,
//     null for garbage.
//   - commitContactImport modern path drives `CMD_IMPORT_CONTACT 0x12`.
//   - commitContactImport legacy path drives `CMD_ADD_UPDATE_CONTACT
//     0x09` (the D29 fallback because the legacy form cannot
//     reconstruct a canonical frame).
//   - Pubkey fingerprint on the preview is 8 hex chars; never the
//     full 64-char hex.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/meshcore_constants.dart';
import 'package:socialmesh/models/meshcore_contact.dart';
import 'package:socialmesh/models/meshcore_contact_import_preview.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_contact_url.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_frame.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_messages.dart';
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

  void simulateOk() {
    _rx.add(
      MeshCoreFrame(
        command: MeshCoreResponses.ok,
        payload: Uint8List(0),
      ).toBytes(),
    );
  }

  void simulateErr() {
    _rx.add(
      MeshCoreFrame(
        command: MeshCoreResponses.err,
        payload: Uint8List(0),
      ).toBytes(),
    );
  }

  void simulateExportContact(Uint8List frame) {
    _rx.add(
      MeshCoreFrame(
        command: MeshCoreResponses.exportContact,
        payload: frame,
      ).toBytes(),
    );
  }

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
    _connected = false;
    await _rx.close();
  }
}

class _StubSelfInfoNotifier extends MeshCoreSelfInfoNotifier {
  _StubSelfInfoNotifier(this._info);
  final MeshCoreSelfInfo? _info;
  @override
  MeshCoreSelfInfoState build() => _info == null
      ? const MeshCoreSelfInfoState.initial()
      : MeshCoreSelfInfoState.loaded(_info);
}

MeshCoreSelfInfo _selfInfoWithPubKey(int seed) {
  final pk = Uint8List.fromList(List.generate(32, (i) => (seed + i) & 0xFF));
  return MeshCoreSelfInfo(
    advType: 1,
    txPowerDbm: 22,
    maxLoraTxPower: 22,
    pubKey: pk,
    nodeName: 'self',
    rawPayload: Uint8List(0),
  );
}

/// Build a deterministic 135-byte canonical contact frame that
/// passes `parseContact`. Used to drive `MeshCoreContactUrl.encode`
/// in tests so the preview path can be exercised end-to-end.
Uint8List _validContactFrame({
  required Uint8List pubKey,
  required String name,
  int advType = 1,
  int flags = 0,
  int pathLen = 0,
  int lastAdvertTs = 1_700_000_000,
}) {
  final frame = Uint8List(135);
  final bd = ByteData.sublistView(frame);
  // 0..31: pubKey
  frame.setRange(0, 32, pubKey);
  // 32: advType
  frame[32] = advType;
  // 33: flags
  frame[33] = flags;
  // 34: plen
  frame[34] = pathLen;
  // 35..98: path (64 B, zero-padded)
  // 99..130: name (32 B, null-padded)
  final nameBytes = name.codeUnits;
  for (int i = 0; i < nameBytes.length && i < 32; i++) {
    frame[99 + i] = nameBytes[i];
  }
  // 131..134: last_advert_ts (uint32 LE)
  bd.setUint32(131, lastAdvertTs, Endian.little);
  return frame;
}

ProviderContainer _container({
  required MeshCoreSession? session,
  MeshCoreSelfInfo? selfInfo,
}) {
  return ProviderContainer(
    overrides: [
      meshCoreSessionProvider.overrideWithValue(session),
      meshCoreSelfInfoProvider.overrideWith(
        () => _StubSelfInfoNotifier(selfInfo),
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('broadcastSelfContact - D46-A', () {
    test('no session: returns false', () async {
      final c = _container(session: null);
      addTearDown(c.dispose);
      final ok = await c
          .read(meshCoreContactsProvider.notifier)
          .broadcastSelfContact();
      expect(ok, isFalse);
    });

    test('no self-info: returns false', () async {
      final tx = _RecordingTransport();
      final session = MeshCoreSession(tx);
      addTearDown(() async {
        await session.dispose();
        await tx.dispose();
      });
      final c = _container(session: session, selfInfo: null);
      addTearDown(c.dispose);

      final ok = await c
          .read(meshCoreContactsProvider.notifier)
          .broadcastSelfContact();
      expect(ok, isFalse);
      expect(tx.sent, isEmpty);
    });

    test(
      'happy path: drives CMD_SHARE_CONTACT (0x10) and returns true',
      () async {
        final tx = _RecordingTransport();
        final session = MeshCoreSession(tx);
        addTearDown(() async {
          await session.dispose();
          await tx.dispose();
        });
        final selfInfo = _selfInfoWithPubKey(0xA0);
        final c = _container(session: session, selfInfo: selfInfo);
        addTearDown(c.dispose);

        final fut = c
            .read(meshCoreContactsProvider.notifier)
            .broadcastSelfContact();
        await Future<void>.delayed(Duration.zero);
        tx.simulateOk();
        expect(await fut, isTrue);

        final sent = tx.sent
            .map(MeshCoreFrame.fromBytes)
            .where((f) => f.command == MeshCoreCommands.shareContact)
            .toList();
        expect(sent, hasLength(1));
        expect(sent.single.payload, equals(selfInfo.pubKey));
      },
    );
  });

  group('exportContactUrl - D46-A', () {
    test('returns meshcore://<hex> on RESP_CODE_EXPORT_CONTACT', () async {
      final tx = _RecordingTransport();
      final session = MeshCoreSession(tx);
      addTearDown(() async {
        await session.dispose();
        await tx.dispose();
      });
      final c = _container(session: session);
      addTearDown(c.dispose);

      final contact = MeshCoreContact(
        publicKey: Uint8List.fromList(List.generate(32, (i) => i)),
        name: 'Alice',
        type: MeshCoreAdvType.chat,
        pathLength: -1,
        path: Uint8List(0),
        lastSeen: DateTime.now(),
      );
      final frame = _validContactFrame(
        pubKey: contact.publicKey,
        name: contact.name,
      );

      final fut = c
          .read(meshCoreContactsProvider.notifier)
          .exportContactUrl(contact);
      await Future<void>.delayed(Duration.zero);
      tx.simulateExportContact(frame);
      final url = await fut;
      expect(url, isNotNull);
      expect(url!.startsWith('meshcore://'), isTrue);
      // Round-trips back to the same bytes.
      expect(MeshCoreContactUrl.decode(url), equals(frame));
    });

    test('returns null on no session', () async {
      final c = _container(session: null);
      addTearDown(c.dispose);
      final url = await c
          .read(meshCoreContactsProvider.notifier)
          .exportContactUrl(
            MeshCoreContact(
              publicKey: Uint8List(32),
              name: '',
              type: 1,
              pathLength: -1,
              path: Uint8List(0),
              lastSeen: DateTime.now(),
            ),
          );
      expect(url, isNull);
    });

    test('returns null when firmware response is short / malformed', () async {
      final tx = _RecordingTransport();
      final session = MeshCoreSession(tx);
      addTearDown(() async {
        await session.dispose();
        await tx.dispose();
      });
      final c = _container(session: session);
      addTearDown(c.dispose);

      final contact = MeshCoreContact(
        publicKey: Uint8List.fromList(List.generate(32, (i) => i + 1)),
        name: 'Bob',
        type: 1,
        pathLength: -1,
        path: Uint8List(0),
        lastSeen: DateTime.now(),
      );
      final fut = c
          .read(meshCoreContactsProvider.notifier)
          .exportContactUrl(contact);
      await Future<void>.delayed(Duration.zero);
      // Inject a malformed 100-byte response.
      tx.simulateExportContact(Uint8List(100));
      expect(await fut, isNull);
    });
  });

  group('previewContactImport - D46-A', () {
    test('parses valid meshcore://<hex> into a modern preview', () async {
      final c = _container(session: null);
      addTearDown(c.dispose);

      final pk = Uint8List.fromList(
        List.generate(32, (i) => (0xC0 + i) & 0xFF),
      );
      final frame = _validContactFrame(pubKey: pk, name: 'Carla');
      final url = MeshCoreContactUrl.encode(frame);

      final preview = c
          .read(meshCoreContactsProvider.notifier)
          .previewContactImport(url);
      expect(preview, isNotNull);
      expect(preview!.format, MeshCoreContactImportFormat.modern);
      expect(preview.contact.name, 'Carla');
      expect(preview.pubKeyFingerprint8.length, 8);
      // Never embeds the full 64-char pubkey.
      expect(preview.pubKeyFingerprint8.length, isNot(64));
      expect(preview.frameBytes, equals(frame));
      expect(preview.isFullFrame, isTrue);
    });

    test('parses legacy <pubkeyhex>:<name> into a legacy preview', () async {
      final c = _container(session: null);
      addTearDown(c.dispose);

      final pkHex = List.generate(64, (i) => (i % 16).toRadixString(16)).join();
      final preview = c
          .read(meshCoreContactsProvider.notifier)
          .previewContactImport('$pkHex:Dora');
      expect(preview, isNotNull);
      expect(preview!.format, MeshCoreContactImportFormat.legacy);
      expect(preview.contact.name, 'Dora');
      expect(preview.frameBytes, isNull);
      expect(preview.isFullFrame, isFalse);
    });

    test('garbage input returns null', () async {
      final c = _container(session: null);
      addTearDown(c.dispose);
      final n = c.read(meshCoreContactsProvider.notifier);
      expect(n.previewContactImport(''), isNull);
      expect(n.previewContactImport('   '), isNull);
      expect(n.previewContactImport('not a url'), isNull);
      expect(n.previewContactImport('meshcore://nothex'), isNull);
    });
  });

  group('commitContactImport - D46-A', () {
    test('modern preview drives CMD_IMPORT_CONTACT 0x12', () async {
      final tx = _RecordingTransport();
      final session = MeshCoreSession(tx);
      addTearDown(() async {
        await session.dispose();
        await tx.dispose();
      });
      final c = _container(session: session);
      addTearDown(c.dispose);

      final pk = Uint8List.fromList(List.generate(32, (i) => i + 5));
      final frame = _validContactFrame(pubKey: pk, name: 'Eli');
      final url = MeshCoreContactUrl.encode(frame);
      final preview = c
          .read(meshCoreContactsProvider.notifier)
          .previewContactImport(url)!;

      final fut = c
          .read(meshCoreContactsProvider.notifier)
          .commitContactImport(preview);
      await Future<void>.delayed(Duration.zero);
      tx.simulateOk();
      await Future<void>.delayed(Duration.zero);
      tx.simulateEmptyContactsList();
      expect(await fut, isTrue);

      final imports = tx.sent
          .map(MeshCoreFrame.fromBytes)
          .where((f) => f.command == MeshCoreCommands.importContact)
          .toList();
      expect(imports, hasLength(1));
      // Wire payload is the canonical frame verbatim.
      expect(imports.single.payload, equals(frame));
    });

    test('legacy preview falls back to CMD_ADD_UPDATE_CONTACT 0x09', () async {
      final tx = _RecordingTransport();
      final session = MeshCoreSession(tx);
      addTearDown(() async {
        await session.dispose();
        await tx.dispose();
      });
      final c = _container(session: session);
      addTearDown(c.dispose);

      final pkHex = '0' * 64;
      final preview = c
          .read(meshCoreContactsProvider.notifier)
          .previewContactImport('$pkHex:Fay')!;

      final fut = c
          .read(meshCoreContactsProvider.notifier)
          .commitContactImport(preview);
      await Future<void>.delayed(Duration.zero);
      tx.simulateOk();
      await Future<void>.delayed(Duration.zero);
      tx.simulateEmptyContactsList();
      expect(await fut, isTrue);

      final imports = tx.sent
          .map(MeshCoreFrame.fromBytes)
          .where((f) => f.command == MeshCoreCommands.importContact)
          .toList();
      expect(imports, isEmpty);
      final upserts = tx.sent
          .map(MeshCoreFrame.fromBytes)
          .where((f) => f.command == MeshCoreCommands.addUpdateContact)
          .toList();
      expect(upserts, hasLength(1));
    });
  });
}
