// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D48-A3: `MeshCorePathUpdateListener` pins.
//
// Wire layout under test (after frame.command has been stripped):
//   PUSH_CODE_PATH_UPDATED 0x81 -> payload[0..32] = pubkey
//
// Pinned invariants:
//   - A 0x81 frame with a valid 32-byte pubkey triggers a
//     `getContactByKey` fetch.
//   - The recorder is called with the contact's hex-prefix-keyed
//     pubkey and the path bytes returned by the fetch.
//   - A 0x81 frame whose payload is shorter than 32 bytes is
//     dropped silently (defensive).
//   - Frames whose command isn't 0x81 are ignored.
//   - A "miss" from `getContactByKey` (null return) does NOT call
//     the recorder.
//   - A flood-only learned route (`pathLength <= 0`) does NOT call
//     the recorder.
//   - Bursts of 0x81 for the same pubkey collapse to one fetch
//     (in-flight dedup).
//   - `dispose()` cancels the upstream subscription.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/meshcore_constants.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_frame.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_messages.dart';
import 'package:socialmesh/services/meshcore/routing/meshcore_path_update_listener.dart';

final _contactPubKey = Uint8List.fromList(
  List<int>.generate(32, (i) => 0x10 + i),
);

MeshCoreFrame _pathUpdatedFrame(Uint8List pubKey) {
  return MeshCoreFrame(
    command: MeshCorePushCodes.pathUpdated,
    payload: Uint8List.fromList(pubKey),
  );
}

MeshCoreContactInfo _contactInfoWithPath(List<int> pathBytes) {
  return MeshCoreContactInfo(
    publicKey: _contactPubKey,
    advType: 1,
    pathLength: pathBytes.length,
    lastMod: 0,
    name: 'Bob',
    pathBytes: Uint8List.fromList(pathBytes),
    rawPayload: Uint8List(0),
  );
}

class _Recorder {
  final List<({String contactPubKeyHex, Uint8List pathBytes})> calls = [];
  Future<void> call({
    required String contactPubKeyHex,
    required Uint8List pathBytes,
  }) async {
    calls.add((
      contactPubKeyHex: contactPubKeyHex,
      pathBytes: Uint8List.fromList(pathBytes),
    ));
  }
}

void main() {
  late StreamController<MeshCoreFrame> frames;
  late _Recorder recorder;

  setUp(() {
    frames = StreamController<MeshCoreFrame>.broadcast();
    recorder = _Recorder();
  });

  tearDown(() async {
    await frames.close();
  });

  group('MeshCorePathUpdateListener - D48-A3', () {
    test('0x81 with a valid pubkey triggers fetch + recorder', () async {
      final fetchCalls = <Uint8List>[];
      final listener = MeshCorePathUpdateListener.forTest(
        frameStream: frames.stream,
        getContactByKey:
            ({required Uint8List pubKey, required Duration timeout}) async {
              fetchCalls.add(Uint8List.fromList(pubKey));
              return _contactInfoWithPath([0x42, 0x43, 0x44]);
            },
        recorder: recorder.call,
      );
      addTearDown(listener.dispose);

      frames.add(_pathUpdatedFrame(_contactPubKey));
      // Drain the microtask + the in-flight refresh future.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(fetchCalls, hasLength(1));
      expect(fetchCalls.single, equals(_contactPubKey));
      expect(recorder.calls, hasLength(1));
      expect(recorder.calls.single.pathBytes, equals([0x42, 0x43, 0x44]));
      // The hex prefix should match the full pubkey lowercased.
      final expectedHex = _contactPubKey
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      expect(recorder.calls.single.contactPubKeyHex, equals(expectedHex));
    });

    test('short payload (<32 bytes) is dropped without a fetch', () async {
      final fetchCalls = <Uint8List>[];
      final listener = MeshCorePathUpdateListener.forTest(
        frameStream: frames.stream,
        getContactByKey:
            ({required Uint8List pubKey, required Duration timeout}) async {
              fetchCalls.add(pubKey);
              return null;
            },
        recorder: recorder.call,
      );
      addTearDown(listener.dispose);

      frames.add(
        MeshCoreFrame(
          command: MeshCorePushCodes.pathUpdated,
          payload: Uint8List(10),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(fetchCalls, isEmpty);
      expect(recorder.calls, isEmpty);
    });

    test('non-0x81 frame is ignored (no fetch)', () async {
      final fetchCalls = <Uint8List>[];
      final listener = MeshCorePathUpdateListener.forTest(
        frameStream: frames.stream,
        getContactByKey:
            ({required Uint8List pubKey, required Duration timeout}) async {
              fetchCalls.add(pubKey);
              return null;
            },
        recorder: recorder.call,
      );
      addTearDown(listener.dispose);

      // 0x82 has the same payload size as our 0x81 test but a
      // different command code.
      frames.add(MeshCoreFrame(command: 0x82, payload: _contactPubKey));
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(fetchCalls, isEmpty);
      expect(recorder.calls, isEmpty);
    });

    test('null fetch result (miss) does NOT call recorder', () async {
      final listener = MeshCorePathUpdateListener.forTest(
        frameStream: frames.stream,
        getContactByKey:
            ({required Uint8List pubKey, required Duration timeout}) async {
              return null;
            },
        recorder: recorder.call,
      );
      addTearDown(listener.dispose);

      frames.add(_pathUpdatedFrame(_contactPubKey));
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(recorder.calls, isEmpty);
    });

    test('flood-only learned route does NOT call recorder', () async {
      final listener = MeshCorePathUpdateListener.forTest(
        frameStream: frames.stream,
        getContactByKey:
            ({required Uint8List pubKey, required Duration timeout}) async {
              return _contactInfoWithPath(const <int>[]);
            },
        recorder: recorder.call,
      );
      addTearDown(listener.dispose);

      frames.add(_pathUpdatedFrame(_contactPubKey));
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(recorder.calls, isEmpty);
    });

    test(
      'bursts of 0x81 for the same pubkey collapse to one fetch (in-flight dedup)',
      () async {
        // Gate the fetch with a completer so we can issue a second
        // 0x81 while the first is still in flight.
        final gate = Completer<MeshCoreContactInfo?>();
        var fetchCount = 0;
        final listener = MeshCorePathUpdateListener.forTest(
          frameStream: frames.stream,
          getContactByKey:
              ({required Uint8List pubKey, required Duration timeout}) {
                fetchCount += 1;
                return gate.future;
              },
          recorder: recorder.call,
        );
        addTearDown(listener.dispose);

        frames.add(_pathUpdatedFrame(_contactPubKey));
        frames.add(_pathUpdatedFrame(_contactPubKey));
        frames.add(_pathUpdatedFrame(_contactPubKey));
        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(
          fetchCount,
          1,
          reason: 'in-flight dedup must collapse the burst to one fetch',
        );
        // Resolve the gate so the listener cleans up.
        gate.complete(_contactInfoWithPath([0x99]));
        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(recorder.calls, hasLength(1));
      },
    );

    test('dispose cancels the upstream subscription', () async {
      var fetchCount = 0;
      final listener = MeshCorePathUpdateListener.forTest(
        frameStream: frames.stream,
        getContactByKey:
            ({required Uint8List pubKey, required Duration timeout}) async {
              fetchCount += 1;
              return _contactInfoWithPath([0x42]);
            },
        recorder: recorder.call,
      );
      await listener.dispose();
      frames.add(_pathUpdatedFrame(_contactPubKey));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(fetchCount, 0);
    });
  });
}
