// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Tests for [OverlayLinkStore] — schema v1 persistence.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_link_models.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_link_store.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_types.dart';

import '_overlay_link_test_harness.dart';

OverlayLinkRecord _mkRecord({
  int linkId = 0x01020304,
  OverlayLinkState state = OverlayLinkState.active,
  int openedAtMs = 1_700_000_000_000,
  int? lastActivityMs,
  int? expiresAtMs,
  int txNextSeq = 0,
  int txAckHi = 0,
  int rxExpectedSeq = 0,
  OverlayLinkCloseReason? closeReason,
  int? closedAtMs,
  OverlayLinkCapabilities capabilities = OverlayLinkCapabilities.none,
  bool isInitiator = true,
  Uint8List? peerPersonaHint,
  int peerNodeNum = 0xAA,
}) {
  final hint =
      peerPersonaHint ?? Uint8List.fromList(<int>[1, 2, 3, 4, 5, 6, 7, 8]);
  return OverlayLinkRecord(
    linkId: linkId,
    peerPersonaHint: hint,
    peerNodeNum: peerNodeNum,
    state: state,
    isInitiator: isInitiator,
    capabilities: capabilities,
    openedAtMs: openedAtMs,
    lastActivityMs: lastActivityMs ?? openedAtMs,
    expiresAtMs: expiresAtMs ?? openedAtMs + 24 * 60 * 60 * 1000,
    txNextSeq: txNextSeq,
    txAckHi: txAckHi,
    rxExpectedSeq: rxExpectedSeq,
    retryCount: 0,
    closeReason: closeReason,
    closedAtMs: closedAtMs,
  );
}

void main() {
  setUpAll(initFfi);

  group('OverlayLinkStore init + schema', () {
    test('initialises and reports isOpen', () async {
      final store = await openInMemoryStore();
      expect(store.isOpen, isTrue);
      await store.close();
      expect(store.isOpen, isFalse);
    });

    test('querying before init() throws StateError', () {
      final store = OverlayLinkStore(testDbPath: ':memory:');
      expect(() => store.getByLinkId(1), throwsStateError);
    });
  });

  group('OverlayLinkStore CRUD', () {
    test('upsert + getByLinkId roundtrip', () async {
      final store = await openInMemoryStore();
      final record = _mkRecord(
        capabilities: const OverlayLinkCapabilities(
          supportedFeatures:
              OverlayCapabilityFeature.linkV02 |
              OverlayCapabilityFeature.resourceV02,
          maxChunkBytes: 128,
          maxResourceBytes: 65535,
        ),
        txNextSeq: 10,
        txAckHi: 5,
        rxExpectedSeq: 7,
      );
      await store.upsert(record);

      final loaded = await store.getByLinkId(record.linkId);
      expect(loaded, isNotNull);
      expect(loaded!.linkId, record.linkId);
      expect(loaded.state, OverlayLinkState.active);
      expect(loaded.capabilities.supportsLink, isTrue);
      expect(loaded.capabilities.maxChunkBytes, 128);
      expect(loaded.capabilities.maxResourceBytes, 65535);
      expect(loaded.txNextSeq, 10);
      expect(loaded.txAckHi, 5);
      expect(loaded.rxExpectedSeq, 7);
      expect(loaded.peerPersonaHint, record.peerPersonaHint);

      await store.close();
    });

    test('upsert overwrites on conflict (state + ack horizons)', () async {
      final store = await openInMemoryStore();
      final a = _mkRecord(state: OverlayLinkState.opening);
      await store.upsert(a);
      final b = a.copyWith(state: OverlayLinkState.active, txAckHi: 99);
      await store.upsert(b);

      final loaded = await store.getByLinkId(a.linkId);
      expect(loaded!.state, OverlayLinkState.active);
      expect(loaded.txAckHi, 99);
      await store.close();
    });

    test('getActiveForPeer returns non-terminal record only', () async {
      final store = await openInMemoryStore();
      final hint = Uint8List.fromList(<int>[9, 9, 9, 9, 9, 9, 9, 9]);
      final closed = _mkRecord(
        linkId: 1,
        peerPersonaHint: hint,
        state: OverlayLinkState.closed,
        closeReason: OverlayLinkCloseReason.normal,
        closedAtMs: 1_700_000_000_000,
      );
      final active = _mkRecord(
        linkId: 2,
        peerPersonaHint: hint,
        state: OverlayLinkState.active,
      );
      await store.upsert(closed);
      await store.upsert(active);

      final found = await store.getActiveForPeer(hint);
      expect(found, isNotNull);
      expect(found!.linkId, 2);
      await store.close();
    });

    test('loadAll / loadNonTerminal partition correctly', () async {
      final store = await openInMemoryStore();
      await store.upsert(_mkRecord(linkId: 1, state: OverlayLinkState.active));
      await store.upsert(_mkRecord(linkId: 2, state: OverlayLinkState.stale));
      await store.upsert(
        _mkRecord(
          linkId: 3,
          state: OverlayLinkState.closed,
          closeReason: OverlayLinkCloseReason.normal,
          closedAtMs: 1,
        ),
      );
      await store.upsert(
        _mkRecord(
          linkId: 4,
          state: OverlayLinkState.failed,
          closeReason: OverlayLinkCloseReason.timeout,
          closedAtMs: 1,
        ),
      );
      expect(await store.count(), 4);
      final nonTerminal = await store.loadNonTerminal();
      expect(nonTerminal.map((r) => r.linkId), unorderedEquals([1, 2]));
      final all = await store.loadAll();
      expect(all, hasLength(4));
      await store.close();
    });

    test(
      'pruneClosedOlderThan deletes only terminal rows past cutoff',
      () async {
        final store = await openInMemoryStore();
        await store.upsert(
          _mkRecord(
            linkId: 1,
            state: OverlayLinkState.closed,
            closeReason: OverlayLinkCloseReason.normal,
            closedAtMs: 1_000,
          ),
        );
        await store.upsert(
          _mkRecord(
            linkId: 2,
            state: OverlayLinkState.failed,
            closeReason: OverlayLinkCloseReason.timeout,
            closedAtMs: 5_000,
          ),
        );
        await store.upsert(
          _mkRecord(linkId: 3, state: OverlayLinkState.active),
        );
        final deleted = await store.pruneClosedOlderThan(4_000);
        expect(deleted, 1);
        expect(await store.getByLinkId(1), isNull);
        expect(await store.getByLinkId(2), isNotNull);
        expect(await store.getByLinkId(3), isNotNull);
        await store.close();
      },
    );

    test('delete removes a row', () async {
      final store = await openInMemoryStore();
      final r = _mkRecord();
      await store.upsert(r);
      await store.delete(r.linkId);
      expect(await store.getByLinkId(r.linkId), isNull);
      await store.close();
    });
  });
}
