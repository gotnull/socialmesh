// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D42-B-A: `meshCorePathOverlayProvider.setInferred` integration pins.
//
// The notifier loads D39 saved entries + persisted inbound message
// paths through the real stores (backed by SharedPreferences mock
// values), runs the pure `inferRecentPathBytes` helper, and applies
// the resulting `MeshCorePathOverlay` through the existing `_apply`.
//
// Pinned invariants (this file):
//   - empty stores -> setInferred returns false; state stays null.
//   - one D39 entry that resolves drawable -> overlay applied with
//     source=inferred.
//   - one inbound message that resolves drawable -> overlay applied
//     with source=inferred.
//   - mixed evidence: newest wins per the pure helper.
//   - invalid candidates (outbound, flood, empty bytes) ignored;
//     state stays null when nothing else qualifies.
//   - non-drawable inferred candidate -> returns false AND does NOT
//     replace an existing overlay (state preserved across the failure).
//   - empty self prefix (no device identified) -> returns false; no
//     store reads attempted by user observation.
//   - successful log line is redacted: `event=path_overlay.shown
//     source=inferred hop_count=<int>` with no path bytes, no full
//     pubkey, no PSK / channel code.
//   - existing active / history setters unchanged (regression pin).

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/logging.dart';
import 'package:socialmesh/models/meshcore_contact.dart';
import 'package:socialmesh/models/meshcore_path_overlay.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_messages.dart';
import 'package:socialmesh/services/meshcore/storage/meshcore_message_store.dart';
import 'package:socialmesh/services/meshcore/storage/meshcore_path_history_store.dart';

MeshCoreContact _contact({
  required int firstByte,
  String name = '',
  double? lat,
  double? lng,
  Uint8List? path,
  int pathLength = -1,
}) {
  final pubKey = Uint8List(32);
  pubKey[0] = firstByte;
  for (int i = 1; i < 32; i++) {
    pubKey[i] = (firstByte + i) & 0xFF;
  }
  return MeshCoreContact(
    publicKey: pubKey,
    name: name,
    type: MeshCoreAdvType.repeater,
    pathLength: pathLength,
    path: path ?? Uint8List(0),
    latitude: lat,
    longitude: lng,
    lastSeen: DateTime(2026, 5, 11, 12),
  );
}

MeshCoreSelfInfo _selfInfo({double lat = 0.5, double lng = 0.7}) {
  // pubKey[0..3] dictates `meshCoreSelfPubKeyPrefix` -> '79426d8d'-shape
  // is the canonical fingerprint length the path-history store keys on.
  // We use a stable test prefix here.
  final pk = Uint8List.fromList(List.generate(32, (i) => 0xAA - i));
  return MeshCoreSelfInfo(
    advType: 1,
    txPowerDbm: 22,
    maxLoraTxPower: 22,
    pubKey: pk,
    latitude: (lat * 1e7).round(),
    longitude: (lng * 1e7).round(),
    nodeName: 'self',
    rawPayload: Uint8List(0),
  );
}

class _StubContactsNotifier extends MeshCoreContactsNotifier {
  _StubContactsNotifier(this._seed);
  final List<MeshCoreContact> _seed;
  @override
  MeshCoreContactsState build() =>
      MeshCoreContactsState(contacts: List.unmodifiable(_seed));
}

class _StubSelfInfoNotifier extends MeshCoreSelfInfoNotifier {
  _StubSelfInfoNotifier(this._info);
  final MeshCoreSelfInfo? _info;
  @override
  MeshCoreSelfInfoState build() => _info == null
      ? const MeshCoreSelfInfoState.initial()
      : MeshCoreSelfInfoState.loaded(_info);
}

ProviderContainer _container({
  required List<MeshCoreContact> contacts,
  MeshCoreSelfInfo? selfInfo,
}) {
  return ProviderContainer(
    overrides: [
      meshCoreContactsProvider.overrideWith(
        () => _StubContactsNotifier(contacts),
      ),
      meshCoreSelfInfoProvider.overrideWith(
        () => _StubSelfInfoNotifier(selfInfo),
      ),
    ],
  );
}

Future<void> _seedSavedPath(
  ProviderContainer c,
  MeshCoreSelfInfo selfInfo,
  MeshCoreContact contact, {
  required List<int> bytes,
  required DateTime lastUsedAt,
}) async {
  final store = c.read(meshCorePathHistoryStoreProvider);
  final selfPrefix = meshCoreSelfPubKeyPrefix(selfInfo);
  final contactPrefix = meshCoreContactPubKeyPrefix(contact.publicKeyHex);
  await store.save(selfPrefix, contactPrefix, [
    MeshCorePathHistoryEntry(
      id: 'seed-${lastUsedAt.millisecondsSinceEpoch}',
      bytes: Uint8List.fromList(bytes),
      len: bytes.length,
      source: MeshCorePathSource.trace,
      createdAt: lastUsedAt,
      lastUsedAt: lastUsedAt,
    ),
  ]);
}

Future<void> _seedInboundMessage(
  MeshCoreContact contact, {
  required String id,
  required List<int> pathBytes,
  required int pathLength,
  required DateTime timestamp,
  bool isOutgoing = false,
}) async {
  final store = MeshCoreMessageStore();
  await store.init();
  await store.addContactMessage(
    contact.publicKeyHex,
    MeshCoreStoredMessage(
      id: id,
      senderKey: Uint8List.fromList(List<int>.generate(32, (i) => i)),
      text: 'msg',
      timestamp: timestamp,
      isOutgoing: isOutgoing,
      pathBytes: Uint8List.fromList(pathBytes),
      pathLength: pathLength,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppLogging.reset();
  });

  group('meshCorePathOverlayProvider.setInferred - D42-B-A', () {
    test('no evidence: returns false and state stays null', () async {
      final target = _contact(firstByte: 0x99, lat: 5.0, lng: 6.0);
      final c = _container(contacts: [target], selfInfo: _selfInfo());
      addTearDown(c.dispose);

      final ok = await c
          .read(meshCorePathOverlayProvider.notifier)
          .setInferred(target);
      expect(ok, isFalse);
      expect(c.read(meshCorePathOverlayProvider), isNull);
    });

    test('one D39 saved entry resolves -> applies inferred overlay', () async {
      final hopA = _contact(firstByte: 0x11, lat: 1.0, lng: 2.0);
      final target = _contact(firstByte: 0x99, lat: 5.0, lng: 6.0);
      final self = _selfInfo();
      final c = _container(contacts: [hopA, target], selfInfo: self);
      addTearDown(c.dispose);

      await _seedSavedPath(
        c,
        self,
        target,
        bytes: [0x11],
        lastUsedAt: DateTime.utc(2026, 5, 12, 9),
      );

      final ok = await c
          .read(meshCorePathOverlayProvider.notifier)
          .setInferred(target);
      expect(ok, isTrue);
      final overlay = c.read(meshCorePathOverlayProvider);
      expect(overlay, isNotNull);
      expect(overlay!.source, MeshCorePathOverlaySource.inferred);
      expect(overlay.hops.single.byte, 0x11);
    });

    test(
      'one inbound persisted message resolves -> applies inferred overlay',
      () async {
        final hopA = _contact(firstByte: 0x22, lat: 1.0, lng: 2.0);
        final target = _contact(firstByte: 0x99, lat: 5.0, lng: 6.0);
        final self = _selfInfo();
        final c = _container(contacts: [hopA, target], selfInfo: self);
        addTearDown(c.dispose);

        await _seedInboundMessage(
          target,
          id: 'i1',
          pathBytes: [0x22],
          pathLength: 1,
          timestamp: DateTime.utc(2026, 5, 12, 10),
        );

        final ok = await c
            .read(meshCorePathOverlayProvider.notifier)
            .setInferred(target);
        expect(ok, isTrue);
        final overlay = c.read(meshCorePathOverlayProvider);
        expect(overlay!.source, MeshCorePathOverlaySource.inferred);
        expect(overlay.hops.single.byte, 0x22);
      },
    );

    test('mixed evidence: newest message beats older D39 entry', () async {
      final hopFromSaved = _contact(firstByte: 0x11, lat: 1.0, lng: 2.0);
      final hopFromMessage = _contact(firstByte: 0x22, lat: 3.0, lng: 4.0);
      final target = _contact(firstByte: 0x99, lat: 5.0, lng: 6.0);
      final self = _selfInfo();
      final c = _container(
        contacts: [hopFromSaved, hopFromMessage, target],
        selfInfo: self,
      );
      addTearDown(c.dispose);

      await _seedSavedPath(
        c,
        self,
        target,
        bytes: [0x11],
        lastUsedAt: DateTime.utc(2026, 5, 11, 9),
      );
      await _seedInboundMessage(
        target,
        id: 'i1',
        pathBytes: [0x22],
        pathLength: 1,
        timestamp: DateTime.utc(2026, 5, 12, 9),
      );

      final ok = await c
          .read(meshCorePathOverlayProvider.notifier)
          .setInferred(target);
      expect(ok, isTrue);
      final overlay = c.read(meshCorePathOverlayProvider);
      expect(overlay!.source, MeshCorePathOverlaySource.inferred);
      // 0x22 is the newer inbound-message hop.
      expect(overlay.hops.single.byte, 0x22);
    });

    test('only invalid candidates (outbound + flood + empty) -> false, '
        'state stays null', () async {
      final target = _contact(firstByte: 0x99, lat: 5.0, lng: 6.0);
      final self = _selfInfo();
      final c = _container(contacts: [target], selfInfo: self);
      addTearDown(c.dispose);

      // Outbound message — ignored.
      await _seedInboundMessage(
        target,
        id: 'o1',
        pathBytes: [0x11],
        pathLength: 1,
        timestamp: DateTime.utc(2026, 5, 12, 9),
        isOutgoing: true,
      );
      // Flood (pathLength = -1) — ignored.
      await _seedInboundMessage(
        target,
        id: 'i-flood',
        pathBytes: [0x22],
        pathLength: -1,
        timestamp: DateTime.utc(2026, 5, 12, 10),
      );
      // Empty pathBytes — ignored.
      await _seedInboundMessage(
        target,
        id: 'i-empty',
        pathBytes: const [],
        pathLength: 1,
        timestamp: DateTime.utc(2026, 5, 12, 11),
      );

      final ok = await c
          .read(meshCorePathOverlayProvider.notifier)
          .setInferred(target);
      expect(ok, isFalse);
      expect(c.read(meshCorePathOverlayProvider), isNull);
    });

    test(
      'non-drawable inferred candidate does NOT replace an existing overlay',
      () async {
        final knownHop = _contact(firstByte: 0x11, lat: 1.0, lng: 2.0);
        // Target has no location AND the inferred hop byte does not
        // resolve. Self also has no location. Nothing draws.
        final target = _contact(firstByte: 0x99);
        final c = _container(contacts: [knownHop, target], selfInfo: null);
        addTearDown(c.dispose);

        // Seed an active overlay first using a SEPARATE contact that
        // DOES resolve to something drawable.
        final activeTarget = _contact(
          firstByte: 0xCD,
          lat: 1.0,
          lng: 1.0,
          path: Uint8List.fromList([0x11]),
          pathLength: 1,
        );
        // setActive needs selfInfo for an origin; override the container
        // with one that has both contacts and a real self.
        final c2 = _container(
          contacts: [knownHop, target, activeTarget],
          selfInfo: _selfInfo(),
        );
        addTearDown(c2.dispose);

        final activeOk = c2
            .read(meshCorePathOverlayProvider.notifier)
            .setActive(activeTarget);
        expect(activeOk, isTrue);
        final before = c2.read(meshCorePathOverlayProvider);
        expect(before, isNotNull);
        expect(before!.source, MeshCorePathOverlaySource.active);

        // Seed an inferred candidate that won't be drawable for the
        // unrelated target.
        await _seedInboundMessage(
          target,
          id: 'i1',
          pathBytes: [0x77], // resolves to no contact
          pathLength: 1,
          timestamp: DateTime.utc(2026, 5, 12, 10),
        );

        final ok = await c2
            .read(meshCorePathOverlayProvider.notifier)
            .setInferred(target);
        expect(ok, isFalse);
        final after = c2.read(meshCorePathOverlayProvider);
        // The active overlay survived.
        expect(after, isNotNull);
        expect(after!.source, MeshCorePathOverlaySource.active);
        expect(after.contactPubKeyHex, activeTarget.publicKeyHex);
      },
    );

    test(
      'empty self prefix (no device identified) -> false; state unchanged',
      () async {
        final target = _contact(firstByte: 0x99, lat: 5.0, lng: 6.0);
        // selfInfo with EMPTY pubKey produces an empty self-prefix
        // through meshCoreSelfPubKeyPrefix.
        final self = MeshCoreSelfInfo(
          advType: 1,
          txPowerDbm: 22,
          maxLoraTxPower: 22,
          pubKey: Uint8List(0),
          latitude: 0,
          longitude: 0,
          nodeName: '',
          rawPayload: Uint8List(0),
        );
        final c = _container(contacts: [target], selfInfo: self);
        addTearDown(c.dispose);

        final ok = await c
            .read(meshCorePathOverlayProvider.notifier)
            .setInferred(target);
        expect(ok, isFalse);
        expect(c.read(meshCorePathOverlayProvider), isNull);
      },
    );

    test('successful log line is redacted: source=inferred, no path bytes, '
        'no full pubkey', () async {
      final hopA = _contact(firstByte: 0x11, lat: 1.0, lng: 2.0);
      final target = _contact(firstByte: 0x99, lat: 5.0, lng: 6.0);
      final self = _selfInfo();
      final c = _container(contacts: [hopA, target], selfInfo: self);
      addTearDown(c.dispose);

      await _seedSavedPath(
        c,
        self,
        target,
        bytes: [0x11],
        lastUsedAt: DateTime.utc(2026, 5, 12, 9),
      );

      final history = <String>[];
      AppLogging.setAppLogSink((_, _, msg) => history.add(msg));
      addTearDown(() => AppLogging.setAppLogSink((_, _, _) {}));

      final ok = await c
          .read(meshCorePathOverlayProvider.notifier)
          .setInferred(target);
      expect(ok, isTrue);

      final shownLines = history
          .where((l) => l.contains('event=path_overlay.shown'))
          .toList();
      expect(shownLines, hasLength(1));
      final shown = shownLines.single;
      expect(shown, contains('source=inferred'));
      expect(shown, contains('hop_count=1'));
      // No 32 or 64-char hex run (no pubkey leak).
      expect(RegExp(r'[0-9a-fA-F]{32}').hasMatch(shown), isFalse);
      expect(RegExp(r'[0-9a-fA-F]{64}').hasMatch(shown), isFalse);
      // No long base64 runs (envelope content).
      expect(RegExp(r'[A-Za-z0-9+/_-]{24,}={0,2}').hasMatch(shown), isFalse);
    });

    test('existing setActive / setFromHistory remain unchanged after the new '
        'method lands', () async {
      final hopA = _contact(firstByte: 0x11, lat: 1.0, lng: 2.0);
      final target = _contact(
        firstByte: 0x99,
        lat: 5.0,
        lng: 6.0,
        path: Uint8List.fromList([0x11]),
        pathLength: 1,
      );
      final c = _container(contacts: [hopA, target], selfInfo: _selfInfo());
      addTearDown(c.dispose);

      final activeOk = c
          .read(meshCorePathOverlayProvider.notifier)
          .setActive(target);
      expect(activeOk, isTrue);
      expect(
        c.read(meshCorePathOverlayProvider)!.source,
        MeshCorePathOverlaySource.active,
      );

      final historyOk = c
          .read(meshCorePathOverlayProvider.notifier)
          .setFromHistory(target, Uint8List.fromList([0x11]));
      expect(historyOk, isTrue);
      expect(
        c.read(meshCorePathOverlayProvider)!.source,
        MeshCorePathOverlaySource.history,
      );
    });
  });
}
