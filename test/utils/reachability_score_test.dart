import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/reachability_models.dart';
import 'package:socialmesh/utils/reachability_score.dart';

void main() {
  group('ReachLikelihood thresholds', () {
    test('score >= 0.7 maps to High', () {
      final data = NodeReachabilityData(
        nodeNum: 1,
        lastHeardAt: DateTime.now().subtract(const Duration(seconds: 30)),
        minimumObservedHopCount: 0,
        averageRssi: -50,
        averageSnr: 12,
        directPacketCount: 100,
        indirectPacketCount: 0,
      );

      final result = calculateReachabilityScore(data);

      expect(result.likelihood, equals(ReachLikelihood.high));
      expect(result.score, greaterThanOrEqualTo(0.7));
      expect(result.score, lessThan(1.0));
    });

    test('score 0.4-0.69 maps to Medium', () {
      final data = NodeReachabilityData(
        nodeNum: 1,
        lastHeardAt: DateTime.now().subtract(const Duration(hours: 2)),
        minimumObservedHopCount: 2,
        averageRssi: -90,
        averageSnr: 0,
        directPacketCount: 10,
        indirectPacketCount: 20,
      );

      final result = calculateReachabilityScore(data);

      expect(result.likelihood, equals(ReachLikelihood.medium));
      expect(result.score, greaterThanOrEqualTo(0.4));
      expect(result.score, lessThan(0.7));
    });

    test('score < 0.4 maps to Low', () {
      final data = NodeReachabilityData(
        nodeNum: 1,
        lastHeardAt: DateTime.now().subtract(const Duration(hours: 12)),
        minimumObservedHopCount: 5,
        averageRssi: -115,
        averageSnr: -15,
        directPacketCount: 1,
        indirectPacketCount: 50,
      );

      final result = calculateReachabilityScore(data);

      expect(result.likelihood, equals(ReachLikelihood.low));
      expect(result.score, lessThan(0.4));
      expect(result.score, greaterThan(0.0));
    });
  });

  group('Freshness scoring', () {
    test('very recent (< 2min) scores high', () {
      final data = NodeReachabilityData(
        nodeNum: 1,
        lastHeardAt: DateTime.now().subtract(const Duration(seconds: 30)),
      );

      final result = calculateReachabilityScore(data);

      // Freshness is 40% of score, should push toward high
      expect(result.score, greaterThan(0.5));
    });

    test('moderately recent (15min) scores medium-high', () {
      final data = NodeReachabilityData(
        nodeNum: 1,
        lastHeardAt: DateTime.now().subtract(const Duration(minutes: 15)),
      );

      final result = calculateReachabilityScore(data);

      expect(result.score, greaterThan(0.35));
      expect(result.score, lessThan(0.75));
    });

    test('stale (> 6h) scores low', () {
      final data = NodeReachabilityData(
        nodeNum: 1,
        lastHeardAt: DateTime.now().subtract(const Duration(hours: 8)),
      );

      final result = calculateReachabilityScore(data);

      expect(result.score, lessThan(0.45));
    });

    test('expired (> 24h) scores very low', () {
      final data = NodeReachabilityData(
        nodeNum: 1,
        lastHeardAt: DateTime.now().subtract(const Duration(hours: 48)),
      );

      final result = calculateReachabilityScore(data);

      expect(result.score, lessThan(0.35));
      expect(result.likelihood, equals(ReachLikelihood.low));
    });
  });

  group('Hop count scoring', () {
    test('direct RF (0 hops) scores highest', () {
      final direct = NodeReachabilityData(
        nodeNum: 1,
        lastHeardAt: DateTime.now().subtract(const Duration(minutes: 5)),
        minimumObservedHopCount: 0,
      );

      final oneHop = NodeReachabilityData(
        nodeNum: 2,
        lastHeardAt: DateTime.now().subtract(const Duration(minutes: 5)),
        minimumObservedHopCount: 1,
      );

      final resultDirect = calculateReachabilityScore(direct);
      final resultOneHop = calculateReachabilityScore(oneHop);

      expect(resultDirect.score, greaterThan(resultOneHop.score));
      expect(resultDirect.pathDepthLabel, equals('Direct RF'));
      expect(resultOneHop.pathDepthLabel, equals('Seen via 1 hop'));
    });

    test('high hop count (5+) scores low', () {
      final data = NodeReachabilityData(
        nodeNum: 1,
        lastHeardAt: DateTime.now().subtract(const Duration(minutes: 5)),
        minimumObservedHopCount: 6,
      );

      final result = calculateReachabilityScore(data);

      expect(result.pathDepthLabel, equals('Seen via 6 hops'));
    });

    test('unknown hop count treated as neutral', () {
      final withHops = NodeReachabilityData(
        nodeNum: 1,
        lastHeardAt: DateTime.now().subtract(const Duration(minutes: 5)),
        minimumObservedHopCount: 3,
      );

      final withoutHops = NodeReachabilityData(
        nodeNum: 2,
        lastHeardAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );

      final resultWith = calculateReachabilityScore(withHops);
      final resultWithout = calculateReachabilityScore(withoutHops);

      expect(resultWithout.pathDepthLabel, equals('Unknown'));
      // Should be somewhat similar since 3 hops maps to 0.5 and unknown to 0.4
      expect((resultWith.score - resultWithout.score).abs(), lessThan(0.2));
    });
  });

  group('Signal quality scoring', () {
    test('excellent RSSI (-50 dBm) scores high', () {
      final excellent = NodeReachabilityData(
        nodeNum: 1,
        lastHeardAt: DateTime.now().subtract(const Duration(minutes: 5)),
        averageRssi: -50,
      );

      final poor = NodeReachabilityData(
        nodeNum: 2,
        lastHeardAt: DateTime.now().subtract(const Duration(minutes: 5)),
        averageRssi: -115,
      );

      final resultExcellent = calculateReachabilityScore(excellent);
      final resultPoor = calculateReachabilityScore(poor);

      expect(resultExcellent.score, greaterThan(resultPoor.score));
    });

    test('excellent SNR (+12 dB) scores high', () {
      final excellent = NodeReachabilityData(
        nodeNum: 1,
        lastHeardAt: DateTime.now().subtract(const Duration(minutes: 5)),
        averageSnr: 12,
      );

      final poor = NodeReachabilityData(
        nodeNum: 2,
        lastHeardAt: DateTime.now().subtract(const Duration(minutes: 5)),
        averageSnr: -18,
      );

      final resultExcellent = calculateReachabilityScore(excellent);
      final resultPoor = calculateReachabilityScore(poor);

      expect(resultExcellent.score, greaterThan(resultPoor.score));
    });

    test('combined RSSI + SNR uses weighted average', () {
      final bothGood = NodeReachabilityData(
        nodeNum: 1,
        lastHeardAt: DateTime.now().subtract(const Duration(minutes: 5)),
        averageRssi: -60,
        averageSnr: 10,
      );

      final oneGood = NodeReachabilityData(
        nodeNum: 2,
        lastHeardAt: DateTime.now().subtract(const Duration(minutes: 5)),
        averageRssi: -60,
        averageSnr: -15,
      );

      final resultBoth = calculateReachabilityScore(bothGood);
      final resultOne = calculateReachabilityScore(oneGood);

      expect(resultBoth.score, greaterThan(resultOne.score));
    });
  });

  group('Observation pattern scoring', () {
    test('all direct packets scores higher than all indirect', () {
      final allDirect = NodeReachabilityData(
        nodeNum: 1,
        lastHeardAt: DateTime.now().subtract(const Duration(minutes: 5)),
        directPacketCount: 50,
        indirectPacketCount: 0,
      );

      final allIndirect = NodeReachabilityData(
        nodeNum: 2,
        lastHeardAt: DateTime.now().subtract(const Duration(minutes: 5)),
        directPacketCount: 0,
        indirectPacketCount: 50,
      );

      final resultDirect = calculateReachabilityScore(allDirect);
      final resultIndirect = calculateReachabilityScore(allIndirect);

      expect(resultDirect.score, greaterThan(resultIndirect.score));
    });

    test('more observations increases confidence', () {
      final fewSamples = NodeReachabilityData(
        nodeNum: 1,
        lastHeardAt: DateTime.now().subtract(const Duration(minutes: 5)),
        directPacketCount: 2,
        indirectPacketCount: 0,
      );

      final manySamples = NodeReachabilityData(
        nodeNum: 2,
        lastHeardAt: DateTime.now().subtract(const Duration(minutes: 5)),
        directPacketCount: 50,
        indirectPacketCount: 0,
      );

      final resultFew = calculateReachabilityScore(fewSamples);
      final resultMany = calculateReachabilityScore(manySamples);

      // Both should have same direct ratio (1.0), but more samples = more confidence
      expect(resultMany.score, greaterThanOrEqualTo(resultFew.score));
    });
  });

  group('Edge cases', () {
    test('null reachability data returns noData result', () {
      final result = calculateReachabilityScore(null);

      expect(result.likelihood, equals(ReachLikelihood.low));
      expect(result.hasObservations, isFalse);
      expect(result.pathDepthLabel, equals('Unknown'));
      expect(result.freshnessLabel, equals('Never'));
    });

    test('empty reachability data returns noData result', () {
      final data = NodeReachabilityData.empty(1);

      final result = calculateReachabilityScore(data);

      expect(result.likelihood, equals(ReachLikelihood.low));
      expect(result.hasObservations, isFalse);
    });

    test('score never reaches exactly 0.0', () {
      final worstCase = NodeReachabilityData(
        nodeNum: 1,
        lastHeardAt: DateTime.now().subtract(const Duration(days: 30)),
        minimumObservedHopCount: 10,
        averageRssi: -125,
        averageSnr: -25,
        directPacketCount: 0,
        indirectPacketCount: 100,
      );

      final result = calculateReachabilityScore(worstCase);

      expect(result.score, greaterThan(0.0));
    });

    test('score never reaches exactly 1.0', () {
      final bestCase = NodeReachabilityData(
        nodeNum: 1,
        lastHeardAt: DateTime.now(),
        minimumObservedHopCount: 0,
        averageRssi: -40,
        averageSnr: 20,
        directPacketCount: 1000,
        indirectPacketCount: 0,
      );

      final result = calculateReachabilityScore(bestCase);

      expect(result.score, lessThan(1.0));
    });

    test('fallback to MeshNode data when reachability data missing', () {
      final result = calculateReachabilityScore(
        null,
        lastHeardFromMeshNode: 300, // 5 minutes ago
        rssiFromMeshNode: -70,
        snrFromMeshNode: 5,
      );

      expect(result.hasObservations, isTrue);
      expect(result.pathDepthLabel, equals('Unknown')); // No hop data
      expect(result.freshnessLabel, equals('5m ago'));
      expect(result.score, greaterThan(0.4));
    });
  });

  group('Label formatting', () {
    test('freshness label formats seconds correctly', () {
      final data30s = NodeReachabilityData(
        nodeNum: 1,
        lastHeardAt: DateTime.now().subtract(const Duration(seconds: 30)),
      );
      final data5m = NodeReachabilityData(
        nodeNum: 2,
        lastHeardAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      final data2h = NodeReachabilityData(
        nodeNum: 3,
        lastHeardAt: DateTime.now().subtract(const Duration(hours: 2)),
      );
      final data3d = NodeReachabilityData(
        nodeNum: 4,
        lastHeardAt: DateTime.now().subtract(const Duration(days: 3)),
      );

      expect(
        calculateReachabilityScore(data30s).freshnessLabel,
        equals('30s ago'),
      );
      expect(
        calculateReachabilityScore(data5m).freshnessLabel,
        equals('5m ago'),
      );
      expect(
        calculateReachabilityScore(data2h).freshnessLabel,
        equals('2h ago'),
      );
      expect(
        calculateReachabilityScore(data3d).freshnessLabel,
        equals('3d ago'),
      );
    });

    test('path depth label formats hops correctly', () {
      expect(
        calculateReachabilityScore(
          NodeReachabilityData(
            nodeNum: 1,
            lastHeardAt: DateTime.now(),
            minimumObservedHopCount: 0,
          ),
        ).pathDepthLabel,
        equals('Direct RF'),
      );

      expect(
        calculateReachabilityScore(
          NodeReachabilityData(
            nodeNum: 2,
            lastHeardAt: DateTime.now(),
            minimumObservedHopCount: 1,
          ),
        ).pathDepthLabel,
        equals('Seen via 1 hop'),
      );

      expect(
        calculateReachabilityScore(
          NodeReachabilityData(
            nodeNum: 3,
            lastHeardAt: DateTime.now(),
            minimumObservedHopCount: 4,
          ),
        ).pathDepthLabel,
        equals('Seen via 4 hops'),
      );
    });
  });

  group('NodeReachabilityData', () {
    test('copyWith preserves unchanged fields', () {
      final original = NodeReachabilityData(
        nodeNum: 1,
        minimumObservedHopCount: 2,
        averageRssi: -80,
        averageSnr: 5,
        lastHeardAt: DateTime(2024, 1, 1),
        directPacketCount: 10,
        indirectPacketCount: 20,
      );

      final updated = original.copyWith(directPacketCount: 15);

      expect(updated.nodeNum, equals(1));
      expect(updated.minimumObservedHopCount, equals(2));
      expect(updated.averageRssi, equals(-80));
      expect(updated.directPacketCount, equals(15));
      expect(updated.indirectPacketCount, equals(20));
    });

    test('updateRssi uses exponential moving average', () {
      var data = NodeReachabilityData(nodeNum: 1);

      // First sample sets the value directly
      data = data.updateRssi(-80);
      expect(data.averageRssi, equals(-80));

      // Subsequent samples are averaged
      data = data.updateRssi(-60);
      // EMA: 0.3 * -60 + 0.7 * -80 = -18 + -56 = -74
      expect(data.averageRssi, closeTo(-74, 0.1));
    });

    test('updateMinHopCount only updates if lower', () {
      var data = NodeReachabilityData(nodeNum: 1, minimumObservedHopCount: 3);

      // Higher hop count should not update
      data = data.updateMinHopCount(5);
      expect(data.minimumObservedHopCount, equals(3));

      // Lower hop count should update
      data = data.updateMinHopCount(1);
      expect(data.minimumObservedHopCount, equals(1));
    });

    test('directVsIndirectRatio calculates correctly', () {
      final allDirect = NodeReachabilityData(
        nodeNum: 1,
        directPacketCount: 10,
        indirectPacketCount: 0,
      );
      expect(allDirect.directVsIndirectRatio, equals(1.0));

      final mixed = NodeReachabilityData(
        nodeNum: 2,
        directPacketCount: 3,
        indirectPacketCount: 7,
      );
      expect(mixed.directVsIndirectRatio, equals(0.3));

      final noData = NodeReachabilityData(nodeNum: 3);
      expect(noData.directVsIndirectRatio, isNull);
    });

    test('recordDirectPacket updates counters and timestamp', () {
      var data = NodeReachabilityData(nodeNum: 1);
      final before = DateTime.now();

      data = data.recordDirectPacket();

      expect(data.directPacketCount, equals(1));
      expect(data.minimumObservedHopCount, equals(0));
      expect(data.lastHeardAt, isNotNull);
      expect(
        data.lastHeardAt!.isAfter(before.subtract(const Duration(seconds: 1))),
        isTrue,
      );
    });

    test('recordIndirectPacket updates counters and hop count', () {
      var data = NodeReachabilityData(nodeNum: 1);

      data = data.recordIndirectPacket(3);

      expect(data.indirectPacketCount, equals(1));
      expect(data.minimumObservedHopCount, equals(3));
    });

    test('hasAnyData returns correct state', () {
      expect(NodeReachabilityData(nodeNum: 1).hasAnyData, isFalse);

      expect(
        NodeReachabilityData(
          nodeNum: 1,
          lastHeardAt: DateTime.now(),
        ).hasAnyData,
        isTrue,
      );

      expect(
        NodeReachabilityData(nodeNum: 1, directPacketCount: 1).hasAnyData,
        isTrue,
      );
    });
  });

  group('ReachabilityResult', () {
    test('noData factory creates proper defaults', () {
      final result = ReachabilityResult.noData();

      expect(result.score, equals(0.1));
      expect(result.likelihood, equals(ReachLikelihood.low));
      expect(result.pathDepthLabel, equals('Unknown'));
      expect(result.freshnessLabel, equals('Never'));
      expect(result.hasObservations, isFalse);
    });
  });
}
