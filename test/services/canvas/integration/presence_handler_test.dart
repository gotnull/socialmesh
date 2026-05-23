// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// P4 — inbound presence handler integration tests.
//
// Source of truth: docs/canvas/CANVAS_PRESENCE_V0_1.md §5 + invariants
// P1, P2, P6, P7, P8. Uses a real sqflite database via
// sqflite_common_ffi so the no-write invariant (presence MUST NOT
// touch cell / applied_op / pending_op) is verifiable by inspecting
// the actual tables after each applyInbound call.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:socialmesh/services/canvas/canvas_codec.dart';
import 'package:socialmesh/services/canvas/canvas_constants.dart';
import 'package:socialmesh/services/canvas/canvas_database.dart';
import 'package:socialmesh/services/canvas/canvas_inbound_limiter.dart';
import 'package:socialmesh/services/canvas/canvas_models.dart';
import 'package:socialmesh/services/canvas/canvas_repository.dart';
import 'package:socialmesh/services/canvas/mrrp_service_canvas.dart';
import 'package:socialmesh/services/canvas/presence_cache.dart';
import 'package:socialmesh/services/canvas/presence_models.dart';

int _testDbSeq = 0;
final int _testPid = pid;

String _uniqueTestDbPath(String label) {
  final dir = Directory.systemTemp.path;
  return p.join(dir, 'canvas_p4_${label}_${_testPid}_${_testDbSeq++}.db');
}

class _FakeClock {
  int _ms;
  _FakeClock(this._ms);
  int now() => _ms;
  void advance(Duration d) => _ms += d.inMilliseconds;
}

class _CallRecorder {
  final List<int> calls = <int>[];
  void call(int canvasLocalId) => calls.add(canvasLocalId);
}

Future<
  ({
    CanvasDatabase db,
    CanvasRepository repo,
    _FakeClock clock,
    PresenceCache cache,
    _CallRecorder presenceChanged,
    _CallRecorder cellApplied,
    MrrpServiceCanvas handler,
  })
>
_buildHandler({
  String label = 'presence',
  CanvasInboundLimiter? limiter,
}) async {
  final db = CanvasDatabase(testDbPath: _uniqueTestDbPath(label));
  await db.init();
  final repo = CanvasRepository(db);
  final clock = _FakeClock(DateTime(2026, 6, 1).millisecondsSinceEpoch);
  final cache = PresenceCache();
  final presenceChanged = _CallRecorder();
  final cellApplied = _CallRecorder();
  final handler = MrrpServiceCanvas(
    repository: repo,
    limiter: limiter,
    nowMs: clock.now,
    presenceCache: cache,
    onPresenceChanged: presenceChanged.call,
    onCellApplied: cellApplied.call,
  );
  return (
    db: db,
    repo: repo,
    clock: clock,
    cache: cache,
    presenceChanged: presenceChanged,
    cellApplied: cellApplied,
    handler: handler,
  );
}

int _nowSec(_FakeClock c) => c.now() ~/ 1000;

Uint8List _presence({
  required int canvasId,
  required int author,
  required PresenceState state,
  required int emitTs,
  int ttlSeconds = 180,
}) {
  return CanvasCodec.encodePresence(
    CanvasPresenceOp(
      canvasId: canvasId,
      authorId: author,
      state: state,
      emitTs: emitTs,
      ttlSeconds: ttlSeconds,
    ),
  )!;
}

Future<CanvasSummary> _seedMeshCanvas(
  CanvasRepository repo, {
  required int canvasId,
  required int channelIndex,
  String name = 'Test',
}) {
  return repo.getOrCreateMeshCanvas(
    canvasId: canvasId,
    channelIndex: channelIndex,
    name: name,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('P4 inbound presence — happy path', () {
    test(
      'valid viewing frame upserts cache and fires onPresenceChanged',
      () async {
        final h = await _buildHandler(label: 'viewing');
        try {
          final canvas = await _seedMeshCanvas(
            h.repo,
            canvasId: 0xC0DECAFE12345678,
            channelIndex: 3,
          );
          final report = await h.handler.applyInbound(
            canvasPayload: _presence(
              canvasId: 0xC0DECAFE12345678,
              author: 0xAA01,
              state: PresenceState.viewing,
              emitTs: _nowSec(h.clock),
            ),
            senderNodeId: 0xAA01,
            channelIndex: 3,
          );
          expect(report.outcome, CanvasInboundOutcome.acceptedNoOp);
          final entries = h.cache.entriesForCanvas(canvas.localId);
          expect(entries, hasLength(1));
          expect(entries.single.state, PresenceState.viewing);
          expect(entries.single.source, PresenceSource.radio);
          expect(entries.single.nodeNum, 0xAA01);
          expect(h.presenceChanged.calls, [canvas.localId]);
        } finally {
          await h.db.close();
        }
      },
    );

    test('active and painting states upsert correctly', () async {
      final h = await _buildHandler(label: 'multistate');
      try {
        final canvas = await _seedMeshCanvas(
          h.repo,
          canvasId: 0xC0DE,
          channelIndex: 1,
        );
        await h.handler.applyInbound(
          canvasPayload: _presence(
            canvasId: 0xC0DE,
            author: 0xAA,
            state: PresenceState.active,
            emitTs: _nowSec(h.clock),
          ),
          senderNodeId: 0xAA,
          channelIndex: 1,
        );
        await h.handler.applyInbound(
          canvasPayload: _presence(
            canvasId: 0xC0DE,
            author: 0xBB,
            state: PresenceState.painting,
            emitTs: _nowSec(h.clock),
          ),
          senderNodeId: 0xBB,
          channelIndex: 1,
        );
        final counts = h.cache.countsForCanvas(canvas.localId);
        expect(counts.active, 1);
        expect(counts.painting, 1);
        expect(counts.viewing, 0);
        expect(h.presenceChanged.calls, [canvas.localId, canvas.localId]);
      } finally {
        await h.db.close();
      }
    });

    test(
      'leaving evicts the matching cache entry and fires the callback',
      () async {
        final h = await _buildHandler(label: 'leaving');
        try {
          final canvas = await _seedMeshCanvas(
            h.repo,
            canvasId: 0xC0DE,
            channelIndex: 0,
          );
          await h.handler.applyInbound(
            canvasPayload: _presence(
              canvasId: 0xC0DE,
              author: 0xCC,
              state: PresenceState.viewing,
              emitTs: _nowSec(h.clock),
            ),
            senderNodeId: 0xCC,
            channelIndex: 0,
          );
          expect(h.cache.entriesForCanvas(canvas.localId), hasLength(1));
          // Reset the callback log to assert the second invocation only.
          h.presenceChanged.calls.clear();

          await h.handler.applyInbound(
            canvasPayload: _presence(
              canvasId: 0xC0DE,
              author: 0xCC,
              state: PresenceState.leaving,
              emitTs: _nowSec(h.clock) + 1,
            ),
            senderNodeId: 0xCC,
            channelIndex: 0,
          );
          expect(h.cache.entriesForCanvas(canvas.localId), isEmpty);
          expect(h.presenceChanged.calls, [canvas.localId]);
        } finally {
          await h.db.close();
        }
      },
    );
  });

  group('P4 inbound presence — onPresenceChanged firing rules', () {
    test('callback fires ONLY when the cache actually mutated', () async {
      final h = await _buildHandler(label: 'mutated');
      try {
        final canvas = await _seedMeshCanvas(
          h.repo,
          canvasId: 0xC0DE,
          channelIndex: 0,
        );
        final t0 = _nowSec(h.clock);
        // First frame: insert. mutated=true.
        await h.handler.applyInbound(
          canvasPayload: _presence(
            canvasId: 0xC0DE,
            author: 0xAA,
            state: PresenceState.painting,
            emitTs: t0,
          ),
          senderNodeId: 0xAA,
          channelIndex: 0,
        );
        expect(h.presenceChanged.calls, [canvas.localId]);

        // Older emit_ts for the same key: cache LWW rejects.
        // mutated=false → no callback.
        await h.handler.applyInbound(
          canvasPayload: _presence(
            canvasId: 0xC0DE,
            author: 0xAA,
            state: PresenceState.painting,
            emitTs: t0 - 1,
          ),
          senderNodeId: 0xAA,
          channelIndex: 0,
        );
        expect(h.presenceChanged.calls, [canvas.localId]);

        // Downgrade for the same key within TTL: cache rejects.
        await h.handler.applyInbound(
          canvasPayload: _presence(
            canvasId: 0xC0DE,
            author: 0xAA,
            state: PresenceState.viewing,
            emitTs: t0 + 60,
          ),
          senderNodeId: 0xAA,
          channelIndex: 0,
        );
        expect(h.presenceChanged.calls, [canvas.localId]);
      } finally {
        await h.db.close();
      }
    });

    test(
      'duplicate inbound from same author refreshes cache (LWW per P2)',
      () async {
        final h = await _buildHandler(label: 'duplicate');
        try {
          final canvas = await _seedMeshCanvas(
            h.repo,
            canvasId: 0xC0DE,
            channelIndex: 0,
          );
          final t0 = _nowSec(h.clock);
          await h.handler.applyInbound(
            canvasPayload: _presence(
              canvasId: 0xC0DE,
              author: 0xAA,
              state: PresenceState.viewing,
              emitTs: t0,
            ),
            senderNodeId: 0xAA,
            channelIndex: 0,
          );
          final firstLastSeen = h.cache
              .entriesForCanvas(canvas.localId)
              .single
              .lastSeenMs;

          h.clock.advance(const Duration(seconds: 30));
          await h.handler.applyInbound(
            canvasPayload: _presence(
              canvasId: 0xC0DE,
              author: 0xAA,
              state: PresenceState.viewing,
              emitTs: t0 + 30,
            ),
            senderNodeId: 0xAA,
            channelIndex: 0,
          );
          final secondLastSeen = h.cache
              .entriesForCanvas(canvas.localId)
              .single
              .lastSeenMs;
          expect(secondLastSeen, greaterThan(firstLastSeen));
        } finally {
          await h.db.close();
        }
      },
    );

    test('downgrade is rejected by cache (no mutation, no callback)', () async {
      final h = await _buildHandler(label: 'downgrade');
      try {
        final canvas = await _seedMeshCanvas(
          h.repo,
          canvasId: 0xC0DE,
          channelIndex: 0,
        );
        final t0 = _nowSec(h.clock);
        await h.handler.applyInbound(
          canvasPayload: _presence(
            canvasId: 0xC0DE,
            author: 0xAA,
            state: PresenceState.painting,
            emitTs: t0,
          ),
          senderNodeId: 0xAA,
          channelIndex: 0,
        );
        h.presenceChanged.calls.clear();
        await h.handler.applyInbound(
          canvasPayload: _presence(
            canvasId: 0xC0DE,
            author: 0xAA,
            state: PresenceState.viewing,
            emitTs: t0 + 60,
          ),
          senderNodeId: 0xAA,
          channelIndex: 0,
        );
        expect(
          h.cache.entriesForCanvas(canvas.localId).single.state,
          PresenceState.painting,
        );
        expect(h.presenceChanged.calls, isEmpty);
      } finally {
        await h.db.close();
      }
    });
  });

  group('P4 inbound presence — drops without canvas mutation', () {
    test('unknown canvas_id does NOT auto-create a canvas row '
        '(P6 invariant)', () async {
      final h = await _buildHandler(label: 'unknown');
      try {
        final canvasesBefore = (await h.repo.listCanvases(
          scope: CanvasScope.mesh,
        )).length;

        final report = await h.handler.applyInbound(
          canvasPayload: _presence(
            canvasId: 0xDEAD,
            author: 0xAA,
            state: PresenceState.viewing,
            emitTs: _nowSec(h.clock),
          ),
          senderNodeId: 0xAA,
          channelIndex: 0,
        );
        expect(report.outcome, CanvasInboundOutcome.noChannelContext);
        final canvasesAfter = (await h.repo.listCanvases(
          scope: CanvasScope.mesh,
        )).length;
        expect(canvasesAfter, canvasesBefore);
        expect(h.presenceChanged.calls, isEmpty);
      } finally {
        await h.db.close();
      }
    });

    test('canvas_id 0 (local canvas sentinel) is rejected', () async {
      final h = await _buildHandler(label: 'localcanvas');
      try {
        final report = await h.handler.applyInbound(
          canvasPayload: _presence(
            canvasId: kLocalCanvasIdSentinel,
            author: 0xAA,
            state: PresenceState.viewing,
            emitTs: _nowSec(h.clock),
          ),
          senderNodeId: 0xAA,
          channelIndex: 0,
        );
        expect(report.outcome, CanvasInboundOutcome.noChannelContext);
        expect(h.presenceChanged.calls, isEmpty);
      } finally {
        await h.db.close();
      }
    });

    test(
      'channel context unknown (dispatcher path) drops without mutation',
      () async {
        final h = await _buildHandler(label: 'dispatcher');
        try {
          await _seedMeshCanvas(h.repo, canvasId: 0xC0DE, channelIndex: 0);
          final report = await h.handler.applyInbound(
            canvasPayload: _presence(
              canvasId: 0xC0DE,
              author: 0xAA,
              state: PresenceState.viewing,
              emitTs: _nowSec(h.clock),
            ),
            senderNodeId: 0xAA,
            channelIndex: kCanvasChannelIndexUnknown,
          );
          expect(report.outcome, CanvasInboundOutcome.noChannelContext);
          expect(h.presenceChanged.calls, isEmpty);
        } finally {
          await h.db.close();
        }
      },
    );

    test('out-of-range channelIndex drops without mutation', () async {
      final h = await _buildHandler(label: 'channelbounds');
      try {
        await _seedMeshCanvas(h.repo, canvasId: 0xC0DE, channelIndex: 0);
        final report = await h.handler.applyInbound(
          canvasPayload: _presence(
            canvasId: 0xC0DE,
            author: 0xAA,
            state: PresenceState.viewing,
            emitTs: _nowSec(h.clock),
          ),
          senderNodeId: 0xAA,
          channelIndex: CanvasLimits.channelIndexMax + 1,
        );
        expect(report.outcome, CanvasInboundOutcome.noChannelContext);
        expect(h.presenceChanged.calls, isEmpty);
      } finally {
        await h.db.close();
      }
    });

    test('emit_ts more than 5 minutes in the past is rejected', () async {
      final h = await _buildHandler(label: 'past');
      try {
        await _seedMeshCanvas(h.repo, canvasId: 0xC0DE, channelIndex: 0);
        final report = await h.handler.applyInbound(
          canvasPayload: _presence(
            canvasId: 0xC0DE,
            author: 0xAA,
            state: PresenceState.viewing,
            emitTs: _nowSec(h.clock) - 301,
          ),
          senderNodeId: 0xAA,
          channelIndex: 0,
        );
        expect(report.outcome, CanvasInboundOutcome.staleReplayWindow);
        expect(h.presenceChanged.calls, isEmpty);
      } finally {
        await h.db.close();
      }
    });

    test('emit_ts more than 5 minutes in the future is rejected', () async {
      final h = await _buildHandler(label: 'future');
      try {
        await _seedMeshCanvas(h.repo, canvasId: 0xC0DE, channelIndex: 0);
        final report = await h.handler.applyInbound(
          canvasPayload: _presence(
            canvasId: 0xC0DE,
            author: 0xAA,
            state: PresenceState.viewing,
            emitTs: _nowSec(h.clock) + 301,
          ),
          senderNodeId: 0xAA,
          channelIndex: 0,
        );
        expect(report.outcome, CanvasInboundOutcome.staleReplayWindow);
        expect(h.presenceChanged.calls, isEmpty);
      } finally {
        await h.db.close();
      }
    });

    test(
      'anonymous_author flag set on the wire is rejected at decode',
      () async {
        final h = await _buildHandler(label: 'anon');
        try {
          await _seedMeshCanvas(h.repo, canvasId: 0xC0DE, channelIndex: 0);
          // Hand-craft a payload with the anonymous_author flag bit set.
          final payload = CanvasCodec.encodePresence(
            const CanvasPresenceOp(
              canvasId: 0xC0DE,
              authorId: 0xAA,
              state: PresenceState.viewing,
              emitTs: 0,
              ttlSeconds: 180,
            ),
          )!;
          // Set bit1 of the flags byte at offset 3.
          payload[3] = 0x02;
          final report = await h.handler.applyInbound(
            canvasPayload: payload,
            senderNodeId: 0xAA,
            channelIndex: 0,
          );
          expect(report.outcome, CanvasInboundOutcome.decodeFailed);
          expect(h.presenceChanged.calls, isEmpty);
        } finally {
          await h.db.close();
        }
      },
    );

    test(
      'malformed (truncated) payload drops with decodeFailed, no crash',
      () async {
        final h = await _buildHandler(label: 'truncated');
        try {
          final full = _presence(
            canvasId: 0xC0DE,
            author: 0xAA,
            state: PresenceState.viewing,
            emitTs: _nowSec(h.clock),
          );
          // Truncate to 16 bytes (below the 24-byte presence size).
          // Note: the inbound limiter looks at sniffAction(); a 16-byte
          // payload still has a recognisable common prefix so the action
          // dispatch reaches _handlePresence which then rejects decode.
          final truncated = Uint8List.fromList(full.sublist(0, 16));
          final report = await h.handler.applyInbound(
            canvasPayload: truncated,
            senderNodeId: 0xAA,
            channelIndex: 0,
          );
          expect(report.outcome, CanvasInboundOutcome.decodeFailed);
          expect(h.presenceChanged.calls, isEmpty);
        } finally {
          await h.db.close();
        }
      },
    );

    test(
      'payload that fails sniffAction drops at the top of applyInbound',
      () async {
        final h = await _buildHandler(label: 'wrongmagic');
        try {
          final payload = Uint8List(24);
          payload[0] = 0xAB; // wrong magic
          final report = await h.handler.applyInbound(
            canvasPayload: payload,
            senderNodeId: 0xAA,
            channelIndex: 0,
          );
          expect(report.outcome, CanvasInboundOutcome.decodeFailed);
          expect(h.presenceChanged.calls, isEmpty);
        } finally {
          await h.db.close();
        }
      },
    );
  });

  group('P4 inbound presence — canonical state isolation '
      '(P1, P2 invariants)', () {
    test('presence apply does NOT create cell rows', () async {
      final h = await _buildHandler(label: 'nocells');
      try {
        final canvas = await _seedMeshCanvas(
          h.repo,
          canvasId: 0xC0DE,
          channelIndex: 0,
        );
        final cellsBefore = (await h.repo.getCanvasCells(
          canvas.localId,
        )).length;

        await h.handler.applyInbound(
          canvasPayload: _presence(
            canvasId: 0xC0DE,
            author: 0xAA,
            state: PresenceState.painting,
            emitTs: _nowSec(h.clock),
          ),
          senderNodeId: 0xAA,
          channelIndex: 0,
        );
        final cellsAfter = (await h.repo.getCanvasCells(canvas.localId)).length;
        expect(cellsAfter, cellsBefore);
      } finally {
        await h.db.close();
      }
    });

    test('presence apply does NOT create applied_op rows', () async {
      final h = await _buildHandler(label: 'noappliedop');
      try {
        final canvas = await _seedMeshCanvas(
          h.repo,
          canvasId: 0xC0DE,
          channelIndex: 0,
        );
        final opsBefore = (await h.repo.getRecentAppliedOps(
          canvas.localId,
          limit: 100,
        )).length;

        await h.handler.applyInbound(
          canvasPayload: _presence(
            canvasId: 0xC0DE,
            author: 0xAA,
            state: PresenceState.painting,
            emitTs: _nowSec(h.clock),
          ),
          senderNodeId: 0xAA,
          channelIndex: 0,
        );
        final opsAfter = (await h.repo.getRecentAppliedOps(
          canvas.localId,
          limit: 100,
        )).length;
        expect(opsAfter, opsBefore);
      } finally {
        await h.db.close();
      }
    });

    test('presence apply does NOT create pending_op rows', () async {
      final h = await _buildHandler(label: 'nopending');
      try {
        final canvas = await _seedMeshCanvas(
          h.repo,
          canvasId: 0xC0DE,
          channelIndex: 0,
        );
        final pendingBefore = (await h.repo.getPendingOpsForCanvas(
          canvas.localId,
        )).length;

        await h.handler.applyInbound(
          canvasPayload: _presence(
            canvasId: 0xC0DE,
            author: 0xAA,
            state: PresenceState.painting,
            emitTs: _nowSec(h.clock),
          ),
          senderNodeId: 0xAA,
          channelIndex: 0,
        );
        final pendingAfter = (await h.repo.getPendingOpsForCanvas(
          canvas.localId,
        )).length;
        expect(pendingAfter, pendingBefore);
      } finally {
        await h.db.close();
      }
    });

    test(
      'presence apply does NOT invalidate global_digest or tile_digests',
      () async {
        final h = await _buildHandler(label: 'nodigest');
        try {
          final canvas = await _seedMeshCanvas(
            h.repo,
            canvasId: 0xC0DE,
            channelIndex: 0,
          );
          // Seed deterministic digest values directly so we can detect
          // any mutation by the presence path.
          final global = Uint8List(CanvasDigestSizes.globalBytes)
            ..fillRange(0, CanvasDigestSizes.globalBytes, 0xA5);
          final tiles = Uint8List(CanvasDigestSizes.tilesConcatenatedBytes)
            ..fillRange(0, CanvasDigestSizes.tilesConcatenatedBytes, 0x5A);
          await h.repo.updateCanvasDigests(
            canvasLocalId: canvas.localId,
            globalDigest: global,
            tileDigests: tiles,
          );

          await h.handler.applyInbound(
            canvasPayload: _presence(
              canvasId: 0xC0DE,
              author: 0xAA,
              state: PresenceState.painting,
              emitTs: _nowSec(h.clock),
            ),
            senderNodeId: 0xAA,
            channelIndex: 0,
          );

          final refreshed = (await h.repo.getCanvasByLocalId(canvas.localId))!;
          expect(refreshed.globalDigest, equals(global));
          expect(refreshed.tileDigests, equals(tiles));
        } finally {
          await h.db.close();
        }
      },
    );
  });

  group('P4 inbound presence — per-sender rate limiting', () {
    test('13th presence from one sender in 60 s is dropped; other senders '
        'unaffected', () async {
      final h = await _buildHandler(label: 'ratelimit');
      try {
        final canvas = await _seedMeshCanvas(
          h.repo,
          canvasId: 0xC0DE,
          channelIndex: 0,
        );
        const sender = 0xAA;
        // Send 12 presence frames from `sender` within the 60 s window.
        for (
          var i = 0;
          i < CanvasInboundLimiter.defaultCapPerSenderPer60s;
          i++
        ) {
          final report = await h.handler.applyInbound(
            canvasPayload: _presence(
              canvasId: 0xC0DE,
              author: sender,
              // Vary state across the window to avoid hitting the
              // cache's no-downgrade gate.
              state: PresenceState.painting,
              emitTs: _nowSec(h.clock) + i,
            ),
            senderNodeId: sender,
            channelIndex: 0,
          );
          expect(report.outcome, CanvasInboundOutcome.acceptedNoOp);
        }
        // 13th frame from the same sender: limiter drops.
        final overflow = await h.handler.applyInbound(
          canvasPayload: _presence(
            canvasId: 0xC0DE,
            author: sender,
            state: PresenceState.painting,
            emitTs: _nowSec(h.clock) + 12,
          ),
          senderNodeId: sender,
          channelIndex: 0,
        );
        expect(overflow.outcome, CanvasInboundOutcome.rateLimited);

        // Different sender at the same instant is fine.
        const otherSender = 0xBB;
        final other = await h.handler.applyInbound(
          canvasPayload: _presence(
            canvasId: 0xC0DE,
            author: otherSender,
            state: PresenceState.viewing,
            emitTs: _nowSec(h.clock),
          ),
          senderNodeId: otherSender,
          channelIndex: 0,
        );
        expect(other.outcome, CanvasInboundOutcome.acceptedNoOp);
        expect(h.cache.entriesForCanvas(canvas.localId), hasLength(2));
      } finally {
        await h.db.close();
      }
    });
  });

  group('P4 — when no presence cache is injected (legacy/test path)', () {
    test('inbound presence decodes and validates but is a no-op '
        'without crashing', () async {
      final db = CanvasDatabase(testDbPath: _uniqueTestDbPath('nocache'));
      await db.init();
      try {
        final repo = CanvasRepository(db);
        final clock = _FakeClock(DateTime(2026, 6, 1).millisecondsSinceEpoch);
        final handler = MrrpServiceCanvas(
          repository: repo,
          nowMs: clock.now,
          // No presenceCache, no onPresenceChanged.
        );
        await _seedMeshCanvas(repo, canvasId: 0xC0DE, channelIndex: 0);
        final report = await handler.applyInbound(
          canvasPayload: _presence(
            canvasId: 0xC0DE,
            author: 0xAA,
            state: PresenceState.viewing,
            emitTs: clock.now() ~/ 1000,
          ),
          senderNodeId: 0xAA,
          channelIndex: 0,
        );
        expect(report.outcome, CanvasInboundOutcome.acceptedNoOp);
      } finally {
        await db.close();
      }
    });
  });
}
