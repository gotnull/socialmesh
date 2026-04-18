// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Restore / expiry / GC tests for [OverlayResourceEngine].
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_bitmap.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_constants.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_resource_egress.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_resource_engine.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_resource_models.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_resource_store.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_types.dart';

import '_overlay_link_test_harness.dart';

Uint8List _hint(int seed) => Uint8List.fromList(List<int>.filled(8, seed));

OverlayResourceRecord _seedRow({
  required int resourceId,
  required OverlayResourceState state,
  required OverlayResourceRole role,
  required int nowMs,
  int? expiresAtMs,
  int? closedAtMs,
  OverlayLinkCloseReason? closeReason,
  int chunkCount = 2,
}) {
  return OverlayResourceRecord(
    resourceId: resourceId,
    peerEndpointHint: _hint(0x33),
    peerNodeNum: 1,
    role: role,
    state: state,
    totalBytes: 128 * chunkCount,
    chunkSize: 128,
    chunkCount: chunkCount,
    sha256: Uint8List(32),
    bitmap: OverlayBitmap.encode(const <int>{0}, chunkCount),
    createdAtMs: nowMs - 1_000,
    lastActivityMs: nowMs - 1_000,
    expiresAtMs:
        expiresAtMs ??
        nowMs + OverlayResourceConstants.partialRetentionSec * 1000,
    retryCount: 0,
    closeReason: closeReason,
    closedAtMs: closedAtMs,
  );
}

Future<OverlayResourceEngine> _buildEngine(
  OverlayResourceStore store, {
  required int Function() clock,
}) async {
  return OverlayResourceEngine(
    store: store,
    egress: RecordingOverlayResourceEgress(),
    clock: clock,
  );
}

void main() {
  setUpAll(initFfi);

  test('restore: transferring stays transferring (sender-resumable)', () async {
    final store = await openInMemoryResourceStore();
    final clock = FakeClock();
    final engine = await _buildEngine(store, clock: clock.now);
    await store.upsertTransfer(
      _seedRow(
        resourceId: 1,
        state: OverlayResourceState.transferring,
        role: OverlayResourceRole.sender,
        nowMs: clock.now(),
      ),
    );
    await engine.restore();
    final loaded = await store.getTransfer(_hint(0x33), 1);
    expect(loaded!.state, OverlayResourceState.transferring);
    await engine.dispose();
  });

  test('restore: receiving stays receiving (receiver-resumable)', () async {
    final store = await openInMemoryResourceStore();
    final clock = FakeClock();
    final engine = await _buildEngine(store, clock: clock.now);
    await store.upsertTransfer(
      _seedRow(
        resourceId: 2,
        state: OverlayResourceState.receiving,
        role: OverlayResourceRole.receiver,
        nowMs: clock.now(),
      ),
    );
    await engine.restore();
    final loaded = await store.getTransfer(_hint(0x33), 2);
    expect(loaded!.state, OverlayResourceState.receiving);
    // Bitmap preserved.
    expect(OverlayBitmap.popcount(loaded.bitmap, loaded.chunkCount), 1);
    await engine.dispose();
  });

  test('restore: offering, negotiating, accepting, evaluating, '
      'awaitingVerify, verifying → failed(timeout)', () async {
    final store = await openInMemoryResourceStore();
    final clock = FakeClock();
    final engine = await _buildEngine(store, clock: clock.now);
    final nonResumable = [
      (3, OverlayResourceState.offering),
      (4, OverlayResourceState.negotiating),
      (5, OverlayResourceState.accepting),
      (6, OverlayResourceState.evaluating),
      (7, OverlayResourceState.awaitingVerify),
      (8, OverlayResourceState.verifying),
    ];
    for (final (id, state) in nonResumable) {
      await store.upsertTransfer(
        _seedRow(
          resourceId: id,
          state: state,
          role: OverlayResourceRole.sender,
          nowMs: clock.now(),
        ),
      );
    }
    await engine.restore();
    for (final (id, _) in nonResumable) {
      final loaded = await store.getTransfer(_hint(0x33), id);
      expect(loaded!.state, OverlayResourceState.failed, reason: 'id=$id');
      expect(loaded.closeReason, OverlayLinkCloseReason.timeout);
    }
    await engine.dispose();
  });

  test('restore: expired resumable → failed(timeout)', () async {
    final store = await openInMemoryResourceStore();
    final clock = FakeClock();
    final engine = await _buildEngine(store, clock: clock.now);
    await store.upsertTransfer(
      _seedRow(
        resourceId: 9,
        state: OverlayResourceState.receiving,
        role: OverlayResourceRole.receiver,
        nowMs: clock.now(),
        expiresAtMs: clock.now() - 1, // already expired
      ),
    );
    await engine.restore();
    final loaded = await store.getTransfer(_hint(0x33), 9);
    expect(loaded!.state, OverlayResourceState.failed);
    expect(loaded.closeReason, OverlayLinkCloseReason.timeout);
    await engine.dispose();
  });

  test('restore: terminal rows are untouched', () async {
    final store = await openInMemoryResourceStore();
    final clock = FakeClock();
    final engine = await _buildEngine(store, clock: clock.now);
    await store.upsertTransfer(
      _seedRow(
        resourceId: 10,
        state: OverlayResourceState.complete,
        role: OverlayResourceRole.sender,
        nowMs: clock.now(),
        closedAtMs: clock.now() - 500,
        closeReason: OverlayLinkCloseReason.normal,
      ),
    );
    await engine.restore();
    final loaded = await store.getTransfer(_hint(0x33), 10);
    expect(loaded!.state, OverlayResourceState.complete);
    await engine.dispose();
  });

  test(
    'tick: non-terminal past expiresAt transitions to failed(timeout)',
    () async {
      final store = await openInMemoryResourceStore();
      final clock = FakeClock();
      final engine = await _buildEngine(store, clock: clock.now);
      await store.upsertTransfer(
        _seedRow(
          resourceId: 11,
          state: OverlayResourceState.receiving,
          role: OverlayResourceRole.receiver,
          nowMs: clock.now(),
        ),
      );
      clock.advanceMs(OverlayResourceConstants.partialRetentionSec * 1000 + 1);
      await engine.tick();
      final loaded = await store.getTransfer(_hint(0x33), 11);
      expect(loaded!.state, OverlayResourceState.failed);
      await engine.dispose();
    },
  );

  test('tick: GCs terminal rows past completeMetaRetentionSec', () async {
    final store = await openInMemoryResourceStore();
    final clock = FakeClock();
    final engine = await _buildEngine(store, clock: clock.now);
    // Seed a long-past complete row + its chunks.
    final oldComplete = _seedRow(
      resourceId: 12,
      state: OverlayResourceState.complete,
      role: OverlayResourceRole.receiver,
      nowMs:
          clock.now() -
          (OverlayResourceConstants.completeMetaRetentionSec * 1000 + 60_000),
      closedAtMs:
          clock.now() -
          (OverlayResourceConstants.completeMetaRetentionSec * 1000 + 60_000),
      closeReason: OverlayLinkCloseReason.normal,
    );
    await store.upsertTransfer(oldComplete);
    await store.putChunk(
      peerEndpointHint: oldComplete.peerEndpointHint,
      resourceId: oldComplete.resourceId,
      chunkIndex: 0,
      data: Uint8List.fromList([1, 2, 3]),
    );
    await engine.tick();
    expect(await store.getTransfer(oldComplete.peerEndpointHint, 12), isNull);
    expect(
      await store.chunkCount(
        peerEndpointHint: oldComplete.peerEndpointHint,
        resourceId: 12,
      ),
      0,
    );
    await engine.dispose();
  });

  test('close(localAbort) transitions to cancelled and emits ABORT', () async {
    final store = await openInMemoryResourceStore();
    final egress = RecordingOverlayResourceEgress();
    final clock = FakeClock();
    final engine = OverlayResourceEngine(
      store: store,
      egress: egress,
      clock: clock.now,
    );
    await store.upsertTransfer(
      _seedRow(
        resourceId: 13,
        state: OverlayResourceState.transferring,
        role: OverlayResourceRole.sender,
        nowMs: clock.now(),
      ),
    );
    await engine.close(peerEndpointHint: _hint(0x33), resourceId: 13);
    final loaded = await store.getTransfer(_hint(0x33), 13);
    expect(loaded!.state, OverlayResourceState.cancelled);
    expect(egress.sent.single.frame.type, OverlayResourceMsgType.abort);
    await engine.dispose();
  });
}
