// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/meshcore_contact.dart';
import 'package:socialmesh/services/meshcore/routing/meshcore_trace_path.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_messages.dart';

MeshCoreContact _contact(
  int first, {
  int pathLength = -1,
  int hashSize = 1,
  List<int> path = const [],
  int? override,
  List<int>? overrideBytes,
  int type = MeshCoreAdvType.repeater,
}) => MeshCoreContact(
  publicKey: Uint8List.fromList(List.generate(32, (i) => (first + i) & 0xFF)),
  name: 'Node $first',
  type: type,
  pathLength: pathLength,
  pathHashSize: hashSize,
  path: Uint8List.fromList(path),
  pathOverride: override,
  pathOverrideBytes: overrideBytes == null
      ? null
      : Uint8List.fromList(overrideBytes),
  lastSeen: DateTime(2026, 11, 24, 12),
);

void main() {
  test('a direct contact is traced to itself and back', () {
    final r = buildMeshCoreTraceRequest(
      target: _contact(0x79, pathLength: 0, type: MeshCoreAdvType.chat),
      contacts: const [],
    )!;
    expect(r.path, [0x79]);
    expect(r.flags, 0);
  });

  test('a routed contact is traced out through its repeaters and back', () {
    // Route A -> B, then the target C; the trace returns B -> A.
    final r = buildMeshCoreTraceRequest(
      target: _contact(0xC0, pathLength: 2, path: [0xA0, 0xB0]),
      contacts: const [],
    )!;
    expect(r.path, [0xA0, 0xB0, 0xC0, 0xB0, 0xA0]);
  });

  test('2-byte route hashes trace at 2 bytes', () {
    final r = buildMeshCoreTraceRequest(
      target: _contact(0xC0, pathLength: 1, hashSize: 2, path: [0xA0, 0xA1]),
      contacts: const [],
    )!;
    expect(r.flags, 1);
    expect(r.hashSize, 2);
    expect(r.path, [0xA0, 0xA1, 0xC0, 0xC1, 0xA0, 0xA1]);
  });

  test('3-byte route hashes trace at 4 bytes, expanded from contacts', () {
    final relay = _contact(0xA0); // key a0 a1 a2 a3 ...
    final r = buildMeshCoreTraceRequest(
      target: _contact(
        0xC0,
        pathLength: 1,
        hashSize: 3,
        path: [0xA0, 0xA1, 0xA2],
      ),
      contacts: [relay],
    )!;
    expect(r.flags, 2);
    expect(r.path.sublist(0, 4), [0xA0, 0xA1, 0xA2, 0xA3]);
    expect(r.path.sublist(4, 8), [0xC0, 0xC1, 0xC2, 0xC3]);
  });

  test('a 3-byte hop with no known contact cannot be traced', () {
    expect(
      buildMeshCoreTraceRequest(
        target: _contact(
          0xC0,
          pathLength: 1,
          hashSize: 3,
          path: [0xA0, 0xA1, 0xA2],
        ),
        contacts: const [],
      ),
      isNull,
    );
  });

  test('a forced path is traced instead of the learned one', () {
    final r = buildMeshCoreTraceRequest(
      target: _contact(
        0xC0,
        pathLength: 1,
        path: [0xA0],
        override: 1,
        overrideBytes: [0xB0],
      ),
      contacts: const [],
    )!;
    expect(r.path, [0xB0, 0xC0, 0xB0]);
  });

  test('a flood contact is traced directly', () {
    final r = buildMeshCoreTraceRequest(
      target: _contact(0xC0),
      contacts: const [],
    )!;
    expect(r.path, [0xC0]);
  });

  group('hand-built route', () {
    Uint8List b(List<int> v) => Uint8List.fromList(v);

    test('returns the same way without repeating the far end', () {
      final r = buildMeshCoreRouteTraceRequest(
        hops: [
          b([0xA0]),
          b([0xB0]),
          b([0xC0]),
        ],
        hashSize: 1,
        returnSameWay: true,
      )!;
      expect(r.path, [0xA0, 0xB0, 0xC0, 0xB0, 0xA0]);
      expect(r.flags, 0);
    });

    test('one way is sent exactly as built', () {
      final r = buildMeshCoreRouteTraceRequest(
        hops: [
          b([0xA0]),
          b([0xB0]),
          b([0xA0]),
        ],
        hashSize: 1,
        returnSameWay: false,
      )!;
      expect(r.path, [0xA0, 0xB0, 0xA0]);
    });

    test('a single hop returning the same way is that hop alone', () {
      final r = buildMeshCoreRouteTraceRequest(
        hops: [
          b([0xA0]),
        ],
        hashSize: 1,
        returnSameWay: true,
      )!;
      expect(r.path, [0xA0]);
    });

    test('wider hashes set path_sz', () {
      final two = buildMeshCoreRouteTraceRequest(
        hops: [
          b([0xA0, 0xA1]),
          b([0xB0, 0xB1]),
        ],
        hashSize: 2,
        returnSameWay: true,
      )!;
      expect(two.flags, 1);
      expect(two.path, [0xA0, 0xA1, 0xB0, 0xB1, 0xA0, 0xA1]);
      final four = buildMeshCoreRouteTraceRequest(
        hops: [
          b([1, 2, 3, 4]),
        ],
        hashSize: 4,
        returnSameWay: false,
      )!;
      expect(four.flags, 2);
      expect(four.hashSize, 4);
    });

    test('rejects an empty route, a bad width or a mismatched hop', () {
      expect(
        buildMeshCoreRouteTraceRequest(
          hops: const [],
          hashSize: 1,
          returnSameWay: true,
        ),
        isNull,
      );
      expect(
        buildMeshCoreRouteTraceRequest(
          hops: [
            b([1, 2, 3]),
          ],
          hashSize: 3,
          returnSameWay: false,
        ),
        isNull,
      );
      expect(
        buildMeshCoreRouteTraceRequest(
          hops: [
            b([0xA0]),
            b([0xB0, 0xB1]),
          ],
          hashSize: 1,
          returnSameWay: false,
        ),
        isNull,
      );
    });

    test('stops at the trace payload limit', () {
      // 16 one-byte hops there and 15 back is 31 bytes; 17 is 33.
      List<Uint8List> hops(int n) => [
        for (var i = 0; i < n; i++) b([i]),
      ];
      expect(
        meshCoreRouteTraceBytes(hopCount: 16, hashSize: 1, returnSameWay: true),
        31,
      );
      expect(
        buildMeshCoreRouteTraceRequest(
          hops: hops(16),
          hashSize: 1,
          returnSameWay: true,
        ),
        isNotNull,
      );
      expect(
        buildMeshCoreRouteTraceRequest(
          hops: hops(17),
          hashSize: 1,
          returnSameWay: true,
        ),
        isNull,
      );
      expect(
        buildMeshCoreRouteTraceRequest(
          hops: hops(kMeshCoreTraceMaxPathBytes),
          hashSize: 1,
          returnSameWay: false,
        ),
        isNotNull,
      );
      expect(
        meshCoreRouteTraceBytes(hopCount: 0, hashSize: 4, returnSameWay: true),
        0,
      );
    });
  });

  test('route capacity in hops for each hash size', () {
    int max(int size, bool back) =>
        meshCoreRouteTraceMaxHops(hashSize: size, returnSameWay: back);
    expect([max(1, true), max(2, true), max(4, true)], [16, 8, 4]);
    expect([max(1, false), max(2, false), max(4, false)], [32, 16, 8]);
    // The largest route at each size still fits the payload.
    for (final size in kMeshCoreTraceHashSizes) {
      for (final back in [true, false]) {
        expect(
          meshCoreRouteTraceBytes(
            hopCount: max(size, back),
            hashSize: size,
            returnSameWay: back,
          ),
          lessThanOrEqualTo(kMeshCoreTraceMaxPathBytes),
        );
        expect(
          meshCoreRouteTraceBytes(
            hopCount: max(size, back) + 1,
            hashSize: size,
            returnSameWay: back,
          ),
          greaterThan(kMeshCoreTraceMaxPathBytes),
        );
      }
    }
  });

  test('hop candidates are repeaters and rooms, newest first', () {
    final older = _contact(0xA0);
    final newer = MeshCoreContact(
      publicKey: Uint8List.fromList([0xA0, ...List.filled(31, 9)]),
      name: 'Newer',
      type: MeshCoreAdvType.room,
      pathLength: -1,
      path: Uint8List(0),
      lastSeen: DateTime(2026, 11, 25),
    );
    final chat = _contact(0xA0, type: MeshCoreAdvType.chat);
    final other = _contact(0xB0);
    final all = [older, chat, newer, other];

    expect(meshCoreTraceHopCandidates([0xA0], all), [newer, older]);
    expect(meshCoreTraceHopCandidates([0xA0, 0xA1], all), [older]);
    expect(meshCoreTraceHopCandidates([0xEE], all), isEmpty);
    expect(meshCoreTraceHopCandidates(const [], all), isEmpty);
  });
}
