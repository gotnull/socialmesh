// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/meshcore_contact.dart';
import 'package:socialmesh/services/meshcore/routing/meshcore_trace_path.dart';

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
}
