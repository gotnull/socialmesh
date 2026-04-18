// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Restore-semantics tests for OverlayLinkEngine (no-phantom-open).
///
/// Each test writes a record directly to the store, then calls
/// `engine.restore()` and asserts the post-restore state. The engine
/// never "resurrects" a session — active/stale/draining are always
/// downgraded to `stale`, `opening` is abandoned to `failed`, terminal
/// rows are untouched, and expired rows become `failed`.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_constants.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_link_egress.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_link_engine.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_link_models.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_types.dart';

import '_overlay_link_test_harness.dart';

OverlayLinkRecord _seed({
  required int linkId,
  required OverlayLinkState state,
  required int nowMs,
  OverlayLinkCloseReason? closeReason,
  int? closedAtMs,
  int? expiresAtMs,
  int? lastActivityMs,
  OverlayLinkCapabilities capabilities = OverlayLinkCapabilities.none,
}) => OverlayLinkRecord(
  linkId: linkId,
  peerPersonaHint: Uint8List.fromList(<int>[linkId, 0, 0, 0, 0, 0, 0, 0]),
  peerNodeNum: 0xFF,
  state: state,
  isInitiator: true,
  capabilities: capabilities,
  openedAtMs: nowMs - 1_000,
  lastActivityMs: lastActivityMs ?? nowMs - 1_000,
  expiresAtMs:
      expiresAtMs ?? nowMs + OverlayLinkConstants.linkMaxLifetimeSec * 1000,
  txNextSeq: 7,
  txAckHi: 6,
  rxExpectedSeq: 5,
  retryCount: 0,
  closeReason: closeReason,
  closedAtMs: closedAtMs,
);

void main() {
  setUpAll(initFfi);

  test('active → stale (no phantom open)', () async {
    final store = await openInMemoryStore();
    final clock = FakeClock();
    final engine = OverlayLinkEngine(
      store: store,
      egress: RecordingOverlayLinkEgress(),
      clock: clock.now,
    );
    await store.upsert(
      _seed(linkId: 1, state: OverlayLinkState.active, nowMs: clock.now()),
    );
    await engine.restore();
    expect((await store.getByLinkId(1))!.state, OverlayLinkState.stale);
    await engine.dispose();
    await store.close();
  });

  test('stale → stale (unchanged)', () async {
    final store = await openInMemoryStore();
    final clock = FakeClock();
    final engine = OverlayLinkEngine(
      store: store,
      egress: RecordingOverlayLinkEgress(),
      clock: clock.now,
    );
    await store.upsert(
      _seed(linkId: 2, state: OverlayLinkState.stale, nowMs: clock.now()),
    );
    await engine.restore();
    expect((await store.getByLinkId(2))!.state, OverlayLinkState.stale);
    await engine.dispose();
    await store.close();
  });

  test('draining → stale', () async {
    final store = await openInMemoryStore();
    final clock = FakeClock();
    final engine = OverlayLinkEngine(
      store: store,
      egress: RecordingOverlayLinkEgress(),
      clock: clock.now,
    );
    await store.upsert(
      _seed(linkId: 3, state: OverlayLinkState.draining, nowMs: clock.now()),
    );
    await engine.restore();
    expect((await store.getByLinkId(3))!.state, OverlayLinkState.stale);
    await engine.dispose();
    await store.close();
  });

  test('opening → failed(timeout)', () async {
    final store = await openInMemoryStore();
    final clock = FakeClock();
    final engine = OverlayLinkEngine(
      store: store,
      egress: RecordingOverlayLinkEgress(),
      clock: clock.now,
    );
    await store.upsert(
      _seed(linkId: 4, state: OverlayLinkState.opening, nowMs: clock.now()),
    );
    await engine.restore();
    final loaded = await store.getByLinkId(4);
    expect(loaded!.state, OverlayLinkState.failed);
    expect(loaded.closeReason, OverlayLinkCloseReason.timeout);
    await engine.dispose();
    await store.close();
  });

  test('closed/failed rows unchanged by restore', () async {
    final store = await openInMemoryStore();
    final clock = FakeClock();
    final engine = OverlayLinkEngine(
      store: store,
      egress: RecordingOverlayLinkEgress(),
      clock: clock.now,
    );
    await store.upsert(
      _seed(
        linkId: 5,
        state: OverlayLinkState.closed,
        nowMs: clock.now(),
        closeReason: OverlayLinkCloseReason.normal,
        closedAtMs: clock.now() - 500,
      ),
    );
    await store.upsert(
      _seed(
        linkId: 6,
        state: OverlayLinkState.failed,
        nowMs: clock.now(),
        closeReason: OverlayLinkCloseReason.timeout,
        closedAtMs: clock.now() - 500,
      ),
    );
    await engine.restore();
    expect((await store.getByLinkId(5))!.state, OverlayLinkState.closed);
    expect((await store.getByLinkId(6))!.state, OverlayLinkState.failed);
    await engine.dispose();
    await store.close();
  });

  test('expired record → failed(timeout) regardless of prior state', () async {
    final store = await openInMemoryStore();
    final clock = FakeClock();
    final engine = OverlayLinkEngine(
      store: store,
      egress: RecordingOverlayLinkEgress(),
      clock: clock.now,
    );
    await store.upsert(
      _seed(
        linkId: 7,
        state: OverlayLinkState.active,
        nowMs: clock.now(),
        expiresAtMs: clock.now() - 1, // already expired
      ),
    );
    await engine.restore();
    final loaded = await store.getByLinkId(7);
    expect(loaded!.state, OverlayLinkState.failed);
    expect(loaded.closeReason, OverlayLinkCloseReason.timeout);
    await engine.dispose();
    await store.close();
  });

  test(
    'seq horizons + capabilities survive restore verbatim (until transition)',
    () async {
      final store = await openInMemoryStore();
      final clock = FakeClock();
      final engine = OverlayLinkEngine(
        store: store,
        egress: RecordingOverlayLinkEgress(),
        clock: clock.now,
      );
      await store.upsert(
        _seed(
          linkId: 8,
          state: OverlayLinkState.active,
          nowMs: clock.now(),
          capabilities: const OverlayLinkCapabilities(
            supportedFeatures: OverlayCapabilityFeature.linkV02,
            maxChunkBytes: 128,
          ),
        ),
      );
      await engine.restore();
      final loaded = await store.getByLinkId(8);
      // state downgraded...
      expect(loaded!.state, OverlayLinkState.stale);
      // but horizons and capabilities are preserved for a later re-activation.
      expect(loaded.txNextSeq, 7);
      expect(loaded.txAckHi, 6);
      expect(loaded.rxExpectedSeq, 5);
      expect(loaded.capabilities.supportsLink, isTrue);
      expect(loaded.capabilities.maxChunkBytes, 128);
      await engine.dispose();
      await store.close();
    },
  );

  test('restore emits a `restored` event per affected row', () async {
    final store = await openInMemoryStore();
    final clock = FakeClock();
    final engine = OverlayLinkEngine(
      store: store,
      egress: RecordingOverlayLinkEgress(),
      clock: clock.now,
    );
    await store.upsert(
      _seed(linkId: 9, state: OverlayLinkState.active, nowMs: clock.now()),
    );
    await store.upsert(
      _seed(linkId: 10, state: OverlayLinkState.opening, nowMs: clock.now()),
    );
    final events = <OverlayLinkEvent>[];
    final sub = engine.events.listen(events.add);
    await engine.restore();
    final restored = events
        .where((e) => e.kind == OverlayLinkEventKind.restored)
        .toList();
    expect(restored, hasLength(2));
    await sub.cancel();
    await engine.dispose();
    await store.close();
  });
}
