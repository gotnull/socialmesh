// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Tests for [OverlayResourceStore] — `overlay_transfers.db` v1.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_bitmap.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_resource_models.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_resource_store.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_types.dart';

import '_overlay_link_test_harness.dart';

Uint8List _hint(int seed) => Uint8List.fromList(List<int>.filled(8, seed));

OverlayResourceRecord _mkRecord({
  int resourceId = 0xCAFEBABE,
  int? peerSeed,
  int peerNodeNum = 42,
  int? linkId,
  OverlayResourceRole role = OverlayResourceRole.sender,
  OverlayResourceState state = OverlayResourceState.offering,
  int totalBytes = 256,
  int chunkSize = 128,
  int chunkCount = 2,
  Uint8List? sha256,
  int createdAtMs = 1_700_000_000_000,
  int? lastActivityMs,
  int? expiresAtMs,
  OverlayLinkCloseReason? closeReason,
  int? closedAtMs,
}) {
  return OverlayResourceRecord(
    resourceId: resourceId,
    peerEndpointHint: _hint(peerSeed ?? 0x77),
    peerNodeNum: peerNodeNum,
    linkId: linkId,
    role: role,
    state: state,
    totalBytes: totalBytes,
    chunkSize: chunkSize,
    chunkCount: chunkCount,
    sha256: sha256 ?? Uint8List(32),
    bitmap: OverlayBitmap.encode(const <int>{}, chunkCount),
    createdAtMs: createdAtMs,
    lastActivityMs: lastActivityMs ?? createdAtMs,
    expiresAtMs: expiresAtMs ?? createdAtMs + 72 * 60 * 60 * 1000,
    retryCount: 0,
    closeReason: closeReason,
    closedAtMs: closedAtMs,
  );
}

void main() {
  setUpAll(initFfi);

  group('OverlayResourceStore lifecycle', () {
    test('init + close', () async {
      final s = await openInMemoryResourceStore();
      expect(s.isOpen, isTrue);
      await s.close();
      expect(s.isOpen, isFalse);
    });

    test('querying before init throws', () {
      final s = OverlayResourceStore(testDbPath: ':memory:');
      expect(() => s.getTransfer(_hint(1), 1), throwsStateError);
    });
  });

  group('Transfer CRUD', () {
    test('upsertTransfer + getTransfer roundtrip', () async {
      final s = await openInMemoryResourceStore();
      final r = _mkRecord(linkId: 0xABCDEF01, peerSeed: 0x12);
      await s.upsertTransfer(r);
      final loaded = await s.getTransfer(_hint(0x12), r.resourceId);
      expect(loaded, isNotNull);
      expect(loaded!.resourceId, r.resourceId);
      expect(loaded.linkId, 0xABCDEF01);
      expect(loaded.state, OverlayResourceState.offering);
      expect(loaded.sha256, equals(r.sha256));
    });

    test('upsert replaces on (peer_endpoint_hint, resource_id) PK', () async {
      final s = await openInMemoryResourceStore();
      final a = _mkRecord(state: OverlayResourceState.offering, peerSeed: 5);
      await s.upsertTransfer(a);
      final b = a.copyWith(state: OverlayResourceState.transferring);
      await s.upsertTransfer(b);
      final loaded = await s.getTransfer(_hint(5), a.resourceId);
      expect(loaded!.state, OverlayResourceState.transferring);
      expect(await s.transferCount(), 1);
    });

    test('same resourceId across different peers are distinct rows', () async {
      final s = await openInMemoryResourceStore();
      await s.upsertTransfer(_mkRecord(peerSeed: 1, resourceId: 99));
      await s.upsertTransfer(_mkRecord(peerSeed: 2, resourceId: 99));
      expect(await s.transferCount(), 2);
    });

    test('loadResumable returns only transferring+receiving', () async {
      final s = await openInMemoryResourceStore();
      await s.upsertTransfer(
        _mkRecord(resourceId: 1, state: OverlayResourceState.transferring),
      );
      await s.upsertTransfer(
        _mkRecord(
          resourceId: 2,
          state: OverlayResourceState.receiving,
          role: OverlayResourceRole.receiver,
          peerSeed: 2,
        ),
      );
      await s.upsertTransfer(
        _mkRecord(
          resourceId: 3,
          state: OverlayResourceState.offering,
          peerSeed: 3,
        ),
      );
      await s.upsertTransfer(
        _mkRecord(
          resourceId: 4,
          state: OverlayResourceState.complete,
          peerSeed: 4,
          closedAtMs: 1,
        ),
      );
      final resumable = await s.loadResumable();
      expect(resumable.map((r) => r.resourceId), unorderedEquals([1, 2]));
    });

    test('loadNonTerminal excludes terminals', () async {
      final s = await openInMemoryResourceStore();
      await s.upsertTransfer(_mkRecord(resourceId: 1));
      await s.upsertTransfer(
        _mkRecord(
          resourceId: 2,
          state: OverlayResourceState.complete,
          closedAtMs: 1,
          peerSeed: 2,
        ),
      );
      await s.upsertTransfer(
        _mkRecord(
          resourceId: 3,
          state: OverlayResourceState.corrupt,
          closedAtMs: 1,
          peerSeed: 3,
        ),
      );
      final rows = await s.loadNonTerminal();
      expect(rows.map((r) => r.resourceId), equals([1]));
    });

    test('pruneTerminalOlderThan removes rows + their chunks', () async {
      final s = await openInMemoryResourceStore();
      final hint = _hint(9);
      await s.upsertTransfer(
        _mkRecord(
          resourceId: 1,
          peerSeed: 9,
          state: OverlayResourceState.complete,
          closedAtMs: 1_000,
        ),
      );
      await s.putChunk(
        peerEndpointHint: hint,
        resourceId: 1,
        chunkIndex: 0,
        data: Uint8List.fromList([1, 2, 3]),
      );
      await s.upsertTransfer(
        _mkRecord(
          resourceId: 2,
          peerSeed: 9,
          state: OverlayResourceState.failed,
          closedAtMs: 9_000,
        ),
      );
      final deleted = await s.pruneTerminalOlderThan(5_000);
      expect(deleted, 1);
      expect(await s.getTransfer(hint, 1), isNull);
      expect(await s.chunkCount(peerEndpointHint: hint, resourceId: 1), 0);
      expect(await s.getTransfer(hint, 2), isNotNull);
    });

    test('deleteTransfer removes transfer + its chunks', () async {
      final s = await openInMemoryResourceStore();
      final hint = _hint(4);
      await s.upsertTransfer(_mkRecord(peerSeed: 4));
      await s.putChunk(
        peerEndpointHint: hint,
        resourceId: 0xCAFEBABE,
        chunkIndex: 0,
        data: Uint8List.fromList([9, 9, 9]),
      );
      await s.deleteTransfer(hint, 0xCAFEBABE);
      expect(await s.getTransfer(hint, 0xCAFEBABE), isNull);
      expect(
        await s.chunkCount(peerEndpointHint: hint, resourceId: 0xCAFEBABE),
        0,
      );
    });
  });

  group('Chunk CRUD', () {
    test('putChunk + getChunk roundtrip', () async {
      final s = await openInMemoryResourceStore();
      await s.putChunk(
        peerEndpointHint: _hint(3),
        resourceId: 1,
        chunkIndex: 0,
        data: Uint8List.fromList([0xAA, 0xBB]),
      );
      final got = await s.getChunk(
        peerEndpointHint: _hint(3),
        resourceId: 1,
        chunkIndex: 0,
      );
      expect(got, equals(Uint8List.fromList([0xAA, 0xBB])));
    });

    test('assembleResource returns null if any chunk is missing', () async {
      final s = await openInMemoryResourceStore();
      await s.putChunk(
        peerEndpointHint: _hint(3),
        resourceId: 1,
        chunkIndex: 0,
        data: Uint8List.fromList([1]),
      );
      // Missing chunk 1.
      final assembled = await s.assembleResource(
        peerEndpointHint: _hint(3),
        resourceId: 1,
        chunkCount: 2,
      );
      expect(assembled, isNull);
    });

    test('assembleResource concatenates in index order', () async {
      final s = await openInMemoryResourceStore();
      await s.putChunk(
        peerEndpointHint: _hint(3),
        resourceId: 1,
        chunkIndex: 1,
        data: Uint8List.fromList([0xCC, 0xDD]),
      );
      await s.putChunk(
        peerEndpointHint: _hint(3),
        resourceId: 1,
        chunkIndex: 0,
        data: Uint8List.fromList([0xAA, 0xBB]),
      );
      final assembled = await s.assembleResource(
        peerEndpointHint: _hint(3),
        resourceId: 1,
        chunkCount: 2,
      );
      expect(assembled, equals(Uint8List.fromList([0xAA, 0xBB, 0xCC, 0xDD])));
    });
  });
}
