// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D42-A - meshCorePathOverlayProvider tests.
//
// Pinned invariants:
//   - Initial state is null.
//   - setActive builds an overlay from a contact's live firmware
//     path (or pathOverrideBytes) + the contacts list + selfInfo.
//   - setFromHistory builds an overlay from explicit hop bytes.
//   - A new set replaces the old overlay (single overlay at a time).
//   - clear() returns state to null.
//   - setActive / setFromHistory return false when the overlay is
//     not drawable; state stays null.
//   - Log surface is redacted: `path_overlay.shown source=<wire>
//     hop_count=<int>` only - never the actual path bytes, never a
//     full pubkey.

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/logging.dart';
import 'package:socialmesh/models/meshcore_contact.dart';
import 'package:socialmesh/models/meshcore_path_overlay.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_messages.dart';

MeshCoreContact _contact({
  required int firstByte,
  String name = '',
  double? lat,
  double? lng,
  Uint8List? path,
  int pathLength = -1,
  int? pathOverride,
  Uint8List? pathOverrideBytes,
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
    pathOverride: pathOverride,
    pathOverrideBytes: pathOverrideBytes,
    latitude: lat,
    longitude: lng,
    lastSeen: DateTime(2026, 5, 11, 12),
  );
}

MeshCoreSelfInfo _selfInfo({double lat = 0.5, double lng = 0.7}) {
  return MeshCoreSelfInfo(
    advType: 1,
    txPowerDbm: 22,
    maxLoraTxPower: 22,
    pubKey: Uint8List.fromList(List.generate(32, (i) => 0xAA - i)),
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AppLogging.reset();
  });

  group('meshCorePathOverlayProvider', () {
    test('initial state is null', () {
      final c = _container(contacts: const []);
      addTearDown(c.dispose);
      expect(c.read(meshCorePathOverlayProvider), isNull);
    });

    test('setActive builds + persists an overlay', () {
      final hop = _contact(firstByte: 0x11, lat: 10.0, lng: 20.0);
      final target = _contact(
        firstByte: 0x99,
        lat: 50.0,
        lng: 60.0,
        pathLength: 1,
        path: Uint8List.fromList([0x11]),
      );
      final c = _container(
        contacts: [hop, target],
        selfInfo: _selfInfo(lat: 0.5, lng: 0.7),
      );
      addTearDown(c.dispose);
      final ok = c.read(meshCorePathOverlayProvider.notifier).setActive(target);
      expect(ok, isTrue);
      final overlay = c.read(meshCorePathOverlayProvider)!;
      expect(overlay.source, MeshCorePathOverlaySource.active);
      expect(overlay.contactPubKeyHex, target.publicKeyHex);
      expect(overlay.hops, hasLength(1));
      expect(overlay.knownHopCount, 1);
    });

    test('setActive returns false on a flood path; state stays null', () {
      final target = _contact(firstByte: 0x99, lat: 50.0, lng: 60.0);
      final c = _container(contacts: [target]);
      addTearDown(c.dispose);
      final ok = c.read(meshCorePathOverlayProvider.notifier).setActive(target);
      expect(ok, isFalse);
      expect(c.read(meshCorePathOverlayProvider), isNull);
    });

    test('setActive returns false when no coordinate data is drawable', () {
      // Direct route (pathLength == 0) with NO self position and NO
      // target position -> nothing to draw.
      final target = _contact(firstByte: 0x99, pathLength: 0);
      final c = _container(contacts: [target]);
      addTearDown(c.dispose);
      final ok = c.read(meshCorePathOverlayProvider.notifier).setActive(target);
      expect(ok, isFalse);
      expect(c.read(meshCorePathOverlayProvider), isNull);
    });

    test('setFromHistory builds + persists an overlay', () {
      final hop = _contact(firstByte: 0x11, lat: 10.0, lng: 20.0);
      final target = _contact(firstByte: 0x99, lat: 50.0, lng: 60.0);
      final c = _container(
        contacts: [hop, target],
        selfInfo: _selfInfo(lat: 0.5, lng: 0.7),
      );
      addTearDown(c.dispose);
      final ok = c
          .read(meshCorePathOverlayProvider.notifier)
          .setFromHistory(target, Uint8List.fromList([0x11]));
      expect(ok, isTrue);
      final overlay = c.read(meshCorePathOverlayProvider)!;
      expect(overlay.source, MeshCorePathOverlaySource.history);
      expect(overlay.hops, hasLength(1));
    });

    test('a new set replaces the old overlay', () {
      final hop = _contact(firstByte: 0x11, lat: 10.0, lng: 20.0);
      final target = _contact(
        firstByte: 0x99,
        lat: 50.0,
        lng: 60.0,
        pathLength: 1,
        path: Uint8List.fromList([0x11]),
      );
      final c = _container(
        contacts: [hop, target],
        selfInfo: _selfInfo(lat: 0.5, lng: 0.7),
      );
      addTearDown(c.dispose);
      c.read(meshCorePathOverlayProvider.notifier).setActive(target);
      final before = c.read(meshCorePathOverlayProvider)!;
      expect(before.source, MeshCorePathOverlaySource.active);

      c
          .read(meshCorePathOverlayProvider.notifier)
          .setFromHistory(target, Uint8List.fromList([0x11]));
      final after = c.read(meshCorePathOverlayProvider)!;
      expect(after.source, MeshCorePathOverlaySource.history);
      expect(identical(before, after), isFalse);
    });

    test('clear() returns state to null', () {
      final hop = _contact(firstByte: 0x11, lat: 10.0, lng: 20.0);
      final target = _contact(
        firstByte: 0x99,
        lat: 50.0,
        lng: 60.0,
        pathLength: 1,
        path: Uint8List.fromList([0x11]),
      );
      final c = _container(
        contacts: [hop, target],
        selfInfo: _selfInfo(lat: 0.5, lng: 0.7),
      );
      addTearDown(c.dispose);
      c.read(meshCorePathOverlayProvider.notifier).setActive(target);
      expect(c.read(meshCorePathOverlayProvider), isNotNull);
      c.read(meshCorePathOverlayProvider.notifier).clear();
      expect(c.read(meshCorePathOverlayProvider), isNull);
    });
  });

  group('redacted log surface', () {
    test('shown / cleared logs carry hop_count + source only', () {
      final captured = <String>[];
      AppLogging.setAppLogSink((_, _, msg) => captured.add(msg));
      addTearDown(() => AppLogging.setAppLogSink((_, _, _) {}));

      final hop = _contact(firstByte: 0xab, lat: 10.0, lng: 20.0);
      final target = _contact(
        firstByte: 0xcd,
        lat: 50.0,
        lng: 60.0,
        pathLength: 2,
        path: Uint8List.fromList([0xab, 0xef]),
      );
      final c = _container(
        contacts: [hop, target],
        selfInfo: _selfInfo(lat: 0.5, lng: 0.7),
      );
      addTearDown(c.dispose);
      c.read(meshCorePathOverlayProvider.notifier).setActive(target);
      c.read(meshCorePathOverlayProvider.notifier).clear();

      final shown = captured
          .where((m) => m.contains('path_overlay.shown'))
          .toList();
      final cleared = captured
          .where((m) => m.contains('path_overlay.cleared'))
          .toList();
      expect(shown, isNotEmpty);
      expect(cleared, isNotEmpty);
      final s = shown.last;
      expect(s, contains('source=active'));
      expect(s, contains('hop_count=2'));

      // Redaction: nothing in any line resembles a full pubkey, a PSK,
      // or a long raw byte run. The single 4-byte hex prefix from a
      // pubkey fingerprint helper is permitted elsewhere - we just
      // verify the overlay log family does not surface anything
      // longer than 16 hex chars.
      for (final line in shown.followedBy(cleared)) {
        final hexHits = RegExp(r'\b[0-9a-fA-F]{17,}\b').allMatches(line);
        expect(
          hexHits,
          isEmpty,
          reason: 'overlay log line "$line" leaks a long hex run',
        );
      }
    });
  });
}
