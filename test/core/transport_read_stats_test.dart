// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/transport.dart';

// TransportReadStats is the per-phase read window behind the
// HANDSHAKE_STATS session line. The ratio of reads to frames and the
// latency spread are what the line exists to expose, so both are pinned.
void main() {
  test('empty window reports zeros without dividing by zero', () {
    const stats = TransportReadStats.empty;
    expect(stats.reads, 0);
    expect(stats.emptyReads, 0);
    expect(stats.notifyReads, 0);
    expect(stats.latencyAvgMs, 0);
    expect(
      stats.describe(),
      'reads=0 dataReads=0 emptyReads=0 bytes=0 notifyReads=0 pollReads=0 '
      'readLatencyMs=min:0 avg:0 max:0',
    );
  });

  test('recordRead folds data, empty, poll and notify reads separately', () {
    final stats = TransportReadStats.empty
        .recordRead(byteCount: 120, latencyMs: 40, viaPoll: false)
        .recordRead(byteCount: 0, latencyMs: 400, viaPoll: true)
        .recordRead(byteCount: 80, latencyMs: 100, viaPoll: false);

    expect(stats.reads, 3);
    expect(stats.dataReads, 2);
    expect(stats.emptyReads, 1);
    expect(stats.bytes, 200);
    expect(stats.pollReads, 1);
    expect(stats.notifyReads, 2);
    expect(stats.latencyMinMs, 40);
    expect(stats.latencyMaxMs, 400);
    expect(stats.latencyAvgMs, 180);
  });

  test('first read seeds the minimum instead of keeping zero', () {
    final stats = TransportReadStats.empty.recordRead(
      byteCount: 10,
      latencyMs: 250,
      viaPoll: false,
    );
    expect(stats.latencyMinMs, 250);
    expect(stats.latencyMaxMs, 250);
  });

  test('describe renders the key=value form the session log carries', () {
    final stats = TransportReadStats.empty
        .recordRead(byteCount: 50, latencyMs: 30, viaPoll: true)
        .recordRead(byteCount: 0, latencyMs: 70, viaPoll: false);
    expect(
      stats.describe(),
      'reads=2 dataReads=1 emptyReads=1 bytes=50 notifyReads=1 pollReads=1 '
      'readLatencyMs=min:30 avg:50 max:70',
    );
  });
}
