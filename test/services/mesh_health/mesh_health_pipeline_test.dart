// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/mesh_health/mesh_health_analyzer.dart';
import 'package:socialmesh/services/mesh_health/mesh_health_models.dart';

/// Helper to create a [MeshTelemetry] with sensible defaults.
MeshTelemetry _telemetry({
  String nodeId = '0000abcd',
  bool isKnownNode = true,
  int hopCount = 1,
  int maxHopCount = 3,
  int payloadBytes = 80,
  int rssi = -70,
  double snr = 8.0,
  int txIntervalSec = 900,
  double reliability = 1.0,
  int airtimeMs = 210,
  int? timestamp,
}) {
  return MeshTelemetry(
    timestamp: timestamp ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
    nodeId: nodeId,
    isKnownNode: isKnownNode,
    hopCount: hopCount,
    maxHopCount: maxHopCount,
    payloadBytes: payloadBytes,
    rssi: rssi,
    snr: snr,
    txIntervalSec: txIntervalSec,
    reliability: reliability,
    airtimeMs: airtimeMs,
  );
}

void main() {
  group('MeshTelemetry construction', () {
    test('creates with all required fields', () {
      final t = _telemetry();
      expect(t.nodeId, '0000abcd');
      expect(t.isKnownNode, isTrue);
      expect(t.hopCount, 1);
      expect(t.maxHopCount, 3);
      expect(t.payloadBytes, 80);
      expect(t.rssi, -70);
      expect(t.snr, 8.0);
      expect(t.reliability, 1.0);
      expect(t.airtimeMs, 210);
    });

    test('fromJson round-trips correctly', () {
      final original = _telemetry();
      final json = original.toJson();
      final restored = MeshTelemetry.fromJson(json);

      expect(restored.nodeId, original.nodeId);
      expect(restored.hopCount, original.hopCount);
      expect(restored.rssi, original.rssi);
      expect(restored.snr, original.snr);
      expect(restored.airtimeMs, original.airtimeMs);
      expect(restored.reliability, original.reliability);
    });
  });

  group('MeshHealthAnalyzer packet ingestion', () {
    late MeshHealthAnalyzer analyzer;

    setUp(() {
      analyzer = MeshHealthAnalyzer(
        config: const MeshHealthConfig(
          windowDurationMs: 60000,
          maxPacketHistory: 500,
          snapshotIntervalMs: 100,
        ),
      );
    });

    tearDown(() {
      analyzer.dispose();
    });

    test('ingests telemetry and produces snapshot', () {
      analyzer.ingestTelemetry(_telemetry());
      final snapshot = analyzer.getSnapshot();

      expect(snapshot.totalPackets, 1);
      expect(snapshot.activeNodeCount, 1);
    });

    test('counts active nodes correctly', () {
      analyzer.ingestTelemetry(_telemetry(nodeId: 'node_aaa1'));
      analyzer.ingestTelemetry(_telemetry(nodeId: 'node_bbb2'));
      analyzer.ingestTelemetry(_telemetry(nodeId: 'node_ccc3'));
      analyzer.ingestTelemetry(_telemetry(nodeId: 'node_aaa1'));

      final snapshot = analyzer.getSnapshot();
      expect(snapshot.activeNodeCount, 3);
      expect(snapshot.totalPackets, 4);
    });

    test('computes channel utilization from airtime', () {
      // 60s window = 60000ms. Inject 100 packets * 210ms = 21000ms airtime
      // Expected utilization: (21000 / 60000) * 100 = 35%
      for (var i = 0; i < 100; i++) {
        analyzer.ingestTelemetry(
          _telemetry(nodeId: 'node_${i % 5}', airtimeMs: 210),
        );
      }

      final utilization = analyzer.computeUtilization();
      expect(utilization, closeTo(35.0, 1.0));
    });

    test('detects channel saturation at warning threshold', () {
      // Inject enough airtime to exceed 50% utilization
      // 60s window = 60000ms. Need > 30000ms airtime.
      // 200 packets * 200ms = 40000ms → ~66%
      for (var i = 0; i < 200; i++) {
        analyzer.ingestTelemetry(
          _telemetry(nodeId: 'node_${i % 3}', airtimeMs: 200),
        );
      }

      final snapshot = analyzer.getSnapshot();
      expect(snapshot.isSaturated, isTrue);
    });

    test('tracks unknown node traffic', () {
      // 8 known + 3 unknown → >10% unknown triggers issue
      for (var i = 0; i < 8; i++) {
        analyzer.ingestTelemetry(
          _telemetry(nodeId: 'known_$i', isKnownNode: true),
        );
      }
      for (var i = 0; i < 3; i++) {
        analyzer.ingestTelemetry(
          _telemetry(nodeId: 'unknown_$i', isKnownNode: false),
        );
      }

      final snapshot = analyzer.getSnapshot();
      // With 11 total packets from 11 nodes, 3 are unknown → ~27%
      expect(snapshot.unknownNodeCount, 3);
    });

    test('detects hop flooding', () {
      // Packets with hop count >= 4 (flood threshold)
      for (var i = 0; i < 5; i++) {
        analyzer.ingestTelemetry(
          _telemetry(nodeId: 'flooder', hopCount: 5, maxHopCount: 7),
        );
      }

      final stats = analyzer.getNodeStats();
      final flooder = stats.firstWhere((s) => s.nodeId == 'flooder');
      expect(flooder.isHopFlooding, isTrue);
    });

    test('detects signal degradation', () {
      // Packets with very low RSSI
      for (var i = 0; i < 5; i++) {
        analyzer.ingestTelemetry(_telemetry(nodeId: 'weak_node', rssi: -110));
      }

      final avgRssi = analyzer.computeAverageRssi();
      expect(avgRssi, lessThan(-100));
    });
  });

  group('MeshHealthAnalyzer sliding window', () {
    late MeshHealthAnalyzer analyzer;

    setUp(() {
      analyzer = MeshHealthAnalyzer(
        config: const MeshHealthConfig(
          windowDurationMs: 10000, // 10s window for faster testing
          maxPacketHistory: 100,
        ),
      );
    });

    tearDown(() {
      analyzer.dispose();
    });

    test('expires old packets from window', () {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Insert packets at "15 seconds ago" (outside 10s window)
      for (var i = 0; i < 5; i++) {
        analyzer.ingestTelemetry(
          _telemetry(nodeId: 'old_node', timestamp: now - 15),
        );
      }

      // Insert packets at "now" (inside window)
      for (var i = 0; i < 3; i++) {
        analyzer.ingestTelemetry(
          _telemetry(nodeId: 'new_node', timestamp: now),
        );
      }

      final snapshot = analyzer.getSnapshot();
      // Only the 3 recent packets should be counted
      expect(snapshot.totalPackets, 3);
    });
  });

  group('MeshHealthAnalyzer snapshots stream', () {
    late MeshHealthAnalyzer analyzer;

    setUp(() {
      analyzer = MeshHealthAnalyzer(
        config: const MeshHealthConfig(snapshotIntervalMs: 50),
      );
    });

    tearDown(() {
      analyzer.dispose();
    });

    test('emits snapshots periodically when started', () async {
      analyzer.ingestTelemetry(_telemetry());
      analyzer.start();

      final snapshots = <MeshHealthSnapshot>[];
      final sub = analyzer.snapshots.listen(snapshots.add);

      // Wait for a few snapshot intervals
      await Future<void>.delayed(const Duration(milliseconds: 200));

      analyzer.stop();
      await sub.cancel();

      expect(snapshots, isNotEmpty);
      expect(snapshots.first.totalPackets, 1);
    });

    test('stops emitting when stopped', () async {
      analyzer.ingestTelemetry(_telemetry());
      analyzer.start();

      // Wait for at least one snapshot
      await Future<void>.delayed(const Duration(milliseconds: 100));
      analyzer.stop();

      final countAfterStop = await analyzer.snapshots
          .timeout(
            const Duration(milliseconds: 150),
            onTimeout: (sink) => sink.close(),
          )
          .length;

      expect(countAfterStop, 0);
    });
  });

  group('MeshHealthAnalyzer top contributors', () {
    late MeshHealthAnalyzer analyzer;

    setUp(() {
      analyzer = MeshHealthAnalyzer();
    });

    tearDown(() {
      analyzer.dispose();
    });

    test('sorts nodes by total airtime descending', () {
      // Node A: 3 packets * 300ms = 900ms
      for (var i = 0; i < 3; i++) {
        analyzer.ingestTelemetry(_telemetry(nodeId: 'node_a', airtimeMs: 300));
      }
      // Node B: 5 packets * 100ms = 500ms
      for (var i = 0; i < 5; i++) {
        analyzer.ingestTelemetry(_telemetry(nodeId: 'node_b', airtimeMs: 100));
      }
      // Node C: 1 packet * 1000ms = 1000ms
      analyzer.ingestTelemetry(_telemetry(nodeId: 'node_c', airtimeMs: 1000));

      final contributors = analyzer.getTopContributors(limit: 3);
      expect(contributors.length, 3);
      expect(contributors[0].nodeId, 'node_c');
      expect(contributors[1].nodeId, 'node_a');
      expect(contributors[2].nodeId, 'node_b');
    });

    test('limits to requested count', () {
      for (var i = 0; i < 10; i++) {
        analyzer.ingestTelemetry(_telemetry(nodeId: 'node_$i'));
      }

      final top3 = analyzer.getTopContributors(limit: 3);
      expect(top3.length, 3);
    });
  });

  group('MeshHealthAnalyzer reliability tracking', () {
    late MeshHealthAnalyzer analyzer;

    setUp(() {
      analyzer = MeshHealthAnalyzer();
    });

    tearDown(() {
      analyzer.dispose();
    });

    test('computes average reliability from packets', () {
      analyzer.ingestTelemetry(_telemetry(reliability: 1.0));
      analyzer.ingestTelemetry(_telemetry(reliability: 0.8));
      analyzer.ingestTelemetry(_telemetry(reliability: 0.6));

      final avg = analyzer.computeAverageReliability();
      expect(avg, closeTo(0.8, 0.01));
    });

    test('snapshot reflects reliability', () {
      for (var i = 0; i < 5; i++) {
        analyzer.ingestTelemetry(_telemetry(reliability: 0.5));
      }

      final snapshot = analyzer.getSnapshot();
      expect(snapshot.avgReliability, closeTo(0.5, 0.1));
    });
  });

  group('MeshHealthAnalyzer reset', () {
    test('clears all data', () {
      final analyzer = MeshHealthAnalyzer();

      for (var i = 0; i < 10; i++) {
        analyzer.ingestTelemetry(_telemetry(nodeId: 'node_$i'));
      }

      expect(analyzer.getSnapshot().totalPackets, 10);

      analyzer.reset();

      expect(analyzer.getSnapshot().totalPackets, 0);
      expect(analyzer.getNodeStats(), isEmpty);
      expect(analyzer.getUtilizationHistory(), isEmpty);

      analyzer.dispose();
    });
  });
}
