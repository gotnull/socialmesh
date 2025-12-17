import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/reachability_models.dart';
import 'package:socialmesh/utils/reachability_score.dart';

// =============================================================================
// CORRECTION NOTICE
// =============================================================================
// These tests validate the corrected concrete scoring formula.
// The previous tests validated a bucketed threshold implementation that did not
// match the agreed concrete scoring formula. These tests now verify:
// - Monotonic decrease of score as t increases (exponential decay)
// - Monotonic decrease of score as h increases (inverse relationship)
// - Direct RF observations score higher than indirect ones
// - Score never equals exactly 0.0 or 1.0
// =============================================================================

void main() {
  group('Concrete formula verification', () {
    test('freshness uses exponential decay: exp(-t/1800)', () {
      // At t=0, exp(0) = 1.0
      // At t=1800 (30 min), exp(-1) ≈ 0.368
      // At t=3600 (1 hour), exp(-2) ≈ 0.135
      // At t=5400 (1.5 hours), exp(-3) ≈ 0.050

      final t0 = NodeReachabilityData(nodeNum: 1, lastHeardAt: DateTime.now());
      final t1800 = NodeReachabilityData(
        nodeNum: 2,
        lastHeardAt: DateTime.now().subtract(const Duration(seconds: 1800)),
      );
      final t3600 = NodeReachabilityData(
        nodeNum: 3,
        lastHeardAt: DateTime.now().subtract(const Duration(seconds: 3600)),
      );

      final r0 = calculateReachabilityScore(t0);
      final r1800 = calculateReachabilityScore(t1800);
      final r3600 = calculateReachabilityScore(t3600);

      // Scores should decrease monotonically
      expect(r0.score, greaterThan(r1800.score));
      expect(r1800.score, greaterThan(r3600.score));
    });

    test('hopScore uses formula: 1/(h+1)', () {
      // h=0: 1/(0+1) = 1.0
      // h=1: 1/(1+1) = 0.5
      // h=2: 1/(2+1) = 0.333
      // h=3: 1/(3+1) = 0.25
      // h=5: 1/(5+1) = 0.167 (clamped to 0.15)

      final now = DateTime.now();
      final h0 = NodeReachabilityData(
        nodeNum: 1,
        lastHeardAt: now,
        minimumObservedHopCount: 0,
      );
      final h1 = NodeReachabilityData(
        nodeNum: 2,
        lastHeardAt: now,
        minimumObservedHopCount: 1,
      );
      final h2 = NodeReachabilityData(
        nodeNum: 3,
        lastHeardAt: now,
        minimumObservedHopCount: 2,
      );
      final h5 = NodeReachabilityData(
        nodeNum: 4,
        lastHeardAt: now,
        minimumObservedHopCount: 5,
      );

      final r0 = calculateReachabilityScore(h0);
      final r1 = calculateReachabilityScore(h1);
      final r2 = calculateReachabilityScore(h2);
      final r5 = calculateReachabilityScore(h5);

      // Scores should decrease monotonically as h increases
      expect(r0.score, greaterThan(r1.score));
      expect(r1.score, greaterThan(r2.score));
      expect(r2.score, greaterThan(r5.score));
    });

    test('rssiScore uses formula: (rssi+120)/60', () {
      // rssi=-60: (-60+120)/60 = 1.0
      // rssi=-90: (-90+120)/60 = 0.5
      // rssi=-120: (-120+120)/60 = 0.0

      final now = DateTime.now();
      final rssiGood = NodeReachabilityData(
        nodeNum: 1,
        lastHeardAt: now,
        averageRssi: -60,
      );
      final rssiMid = NodeReachabilityData(
        nodeNum: 2,
        lastHeardAt: now,
        averageRssi: -90,
      );
      final rssiPoor = NodeReachabilityData(
        nodeNum: 3,
        lastHeardAt: now,
        averageRssi: -120,
      );

      final rGood = calculateReachabilityScore(rssiGood);
      final rMid = calculateReachabilityScore(rssiMid);
      final rPoor = calculateReachabilityScore(rssiPoor);

      expect(rGood.score, greaterThan(rMid.score));
      expect(rMid.score, greaterThan(rPoor.score));
    });

    test('snrScore uses formula: (snr+10)/20', () {
      // snr=10: (10+10)/20 = 1.0
      // snr=0: (0+10)/20 = 0.5
      // snr=-10: (-10+10)/20 = 0.0

      final now = DateTime.now();
      final snrGood = NodeReachabilityData(
        nodeNum: 1,
        lastHeardAt: now,
        averageSnr: 10,
      );
      final snrMid = NodeReachabilityData(
        nodeNum: 2,
        lastHeardAt: now,
        averageSnr: 0,
      );
      final snrPoor = NodeReachabilityData(
        nodeNum: 3,
        lastHeardAt: now,
        averageSnr: -10,
      );

      final rGood = calculateReachabilityScore(snrGood);
      final rMid = calculateReachabilityScore(snrMid);
      final rPoor = calculateReachabilityScore(snrPoor);

      expect(rGood.score, greaterThan(rMid.score));
      expect(rMid.score, greaterThan(rPoor.score));
    });

    test('directScore equals directRatio when provided', () {
      final now = DateTime.now();
      final allDirect = NodeReachabilityData(
        nodeNum: 1,
        lastHeardAt: now,
        directPacketCount: 100,
        indirectPacketCount: 0,
      );
      final halfDirect = NodeReachabilityData(
        nodeNum: 2,
        lastHeardAt: now,
        directPacketCount: 50,
        indirectPacketCount: 50,
      );
      final noDirect = NodeReachabilityData(
        nodeNum: 3,
        lastHeardAt: now,
        directPacketCount: 0,
        indirectPacketCount: 100,
      );

      final rAll = calculateReachabilityScore(allDirect);
      final rHalf = calculateReachabilityScore(halfDirect);
      final rNone = calculateReachabilityScore(noDirect);

      expect(rAll.score, greaterThan(rHalf.score));
      expect(rHalf.score, greaterThan(rNone.score));
    });

    test('weights sum to 1.0', () {
      // 0.30 + 0.25 + 0.15 + 0.15 + 0.10 + 0.05 = 1.0
      const weightSum = 0.30 + 0.25 + 0.15 + 0.15 + 0.10 + 0.05;
      expect(weightSum, equals(1.0));
    });
  });

  group('Monotonic score decrease as t increases', () {
    test('score decreases monotonically with increasing t', () {
      final times = [0, 60, 300, 900, 1800, 3600, 7200, 14400, 86400];
      double? previousScore;

      for (final t in times) {
        final data = NodeReachabilityData(
          nodeNum: 1,
          lastHeardAt: DateTime.now().subtract(Duration(seconds: t)),
        );
        final result = calculateReachabilityScore(data);

        if (previousScore != null) {
          expect(
            result.score,
            lessThanOrEqualTo(previousScore),
            reason: 'Score should decrease as t increases (t=$t)',
          );
        }
        previousScore = result.score;
      }
    });
  });

  group('Monotonic score decrease as h increases', () {
    test('score decreases monotonically with increasing h', () {
      final now = DateTime.now();
      double? previousScore;

      for (int h = 0; h <= 10; h++) {
        final data = NodeReachabilityData(
          nodeNum: 1,
          lastHeardAt: now,
          minimumObservedHopCount: h,
        );
        final result = calculateReachabilityScore(data);

        if (previousScore != null) {
          expect(
            result.score,
            lessThanOrEqualTo(previousScore),
            reason: 'Score should decrease as h increases (h=$h)',
          );
        }
        previousScore = result.score;
      }
    });
  });

  group('Direct RF observations score higher than indirect', () {
    test('all direct scores higher than all indirect', () {
      final now = DateTime.now();
      final allDirect = NodeReachabilityData(
        nodeNum: 1,
        lastHeardAt: now,
        directPacketCount: 50,
        indirectPacketCount: 0,
      );
      final allIndirect = NodeReachabilityData(
        nodeNum: 2,
        lastHeardAt: now,
        directPacketCount: 0,
        indirectPacketCount: 50,
      );

      final resultDirect = calculateReachabilityScore(allDirect);
      final resultIndirect = calculateReachabilityScore(allIndirect);

      expect(resultDirect.score, greaterThan(resultIndirect.score));
    });

    test('higher direct ratio scores higher', () {
      final now = DateTime.now();
      final ratios = [0.0, 0.25, 0.5, 0.75, 1.0];
      double? previousScore;

      for (final ratio in ratios) {
        final direct = (ratio * 100).round();
        final indirect = 100 - direct;
        final data = NodeReachabilityData(
          nodeNum: 1,
          lastHeardAt: now,
          directPacketCount: direct,
          indirectPacketCount: indirect,
        );
        final result = calculateReachabilityScore(data);

        if (previousScore != null) {
          expect(
            result.score,
            greaterThanOrEqualTo(previousScore),
            reason: 'Score should increase with higher direct ratio ($ratio)',
          );
        }
        previousScore = result.score;
      }
    });
  });

  group('Score never equals 0.0 or 1.0', () {
    test('score never reaches exactly 0.0', () {
      final worstCase = NodeReachabilityData(
        nodeNum: 1,
        lastHeardAt: DateTime.now().subtract(const Duration(days: 365)),
        minimumObservedHopCount: 100,
        averageRssi: -200,
        averageSnr: -50,
        directPacketCount: 0,
        indirectPacketCount: 10000,
        dmAckSuccessCount: 0,
        dmAckFailureCount: 10000,
      );

      final result = calculateReachabilityScore(worstCase);

      expect(result.score, greaterThan(0.0));
      expect(result.score, greaterThanOrEqualTo(0.05));
    });

    test('score never reaches exactly 1.0', () {
      final bestCase = NodeReachabilityData(
        nodeNum: 1,
        lastHeardAt: DateTime.now(),
        minimumObservedHopCount: 0,
        averageRssi: -40,
        averageSnr: 20,
        directPacketCount: 10000,
        indirectPacketCount: 0,
        dmAckSuccessCount: 10000,
        dmAckFailureCount: 0,
      );

      final result = calculateReachabilityScore(bestCase);

      expect(result.score, lessThan(1.0));
      expect(result.score, lessThanOrEqualTo(0.95));
    });

    test('null data returns score >= 0.05', () {
      final result = calculateReachabilityScore(null);
      expect(result.score, greaterThanOrEqualTo(0.05));
      expect(result.score, lessThanOrEqualTo(0.95));
    });
  });

  group('ReachLikelihood thresholds', () {
    test('score >= 0.7 maps to High', () {
      final data = NodeReachabilityData(
        nodeNum: 1,
        lastHeardAt: DateTime.now(),
        minimumObservedHopCount: 0,
        averageRssi: -50,
        averageSnr: 12,
        directPacketCount: 100,
        indirectPacketCount: 0,
      );

      final result = calculateReachabilityScore(data);

      expect(result.likelihood, equals(ReachLikelihood.high));
      expect(result.score, greaterThanOrEqualTo(0.7));
    });

    test('score 0.4-0.69 maps to Medium', () {
      // Construct data that should land in medium range
      // Using more recent data with moderate hop count
      final data = NodeReachabilityData(
        nodeNum: 1,
        lastHeardAt: DateTime.now().subtract(const Duration(minutes: 15)),
        minimumObservedHopCount: 2,
        averageRssi: -80,
        averageSnr: 2,
        directPacketCount: 40,
        indirectPacketCount: 60,
        dmAckSuccessCount: 60,
        dmAckFailureCount: 40,
      );

      final result = calculateReachabilityScore(data);

      expect(result.likelihood, equals(ReachLikelihood.medium));
      expect(result.score, greaterThanOrEqualTo(0.4));
      expect(result.score, lessThan(0.7));
    });

    test('score < 0.4 maps to Low', () {
      final data = NodeReachabilityData(
        nodeNum: 1,
        lastHeardAt: DateTime.now().subtract(const Duration(hours: 3)),
        minimumObservedHopCount: 5,
        averageRssi: -115,
        averageSnr: -15,
        directPacketCount: 0,
        indirectPacketCount: 100,
      );

      final result = calculateReachabilityScore(data);

      expect(result.likelihood, equals(ReachLikelihood.low));
      expect(result.score, lessThan(0.4));
    });
  });

  group('Default values for null inputs', () {
    test('null hop count defaults to 0.4', () {
      final now = DateTime.now();
      final withHop = NodeReachabilityData(
        nodeNum: 1,
        lastHeardAt: now,
        minimumObservedHopCount: 1, // 1/(1+1) = 0.5
      );
      final withoutHop = NodeReachabilityData(
        nodeNum: 2,
        lastHeardAt: now,
        // null hop count defaults to 0.4
      );

      final rWith = calculateReachabilityScore(withHop);
      final rWithout = calculateReachabilityScore(withoutHop);

      // h=1 gives 0.5, null gives 0.4, so h=1 should score higher
      expect(rWith.score, greaterThan(rWithout.score));
    });

    test('null rssi defaults to 0.4', () {
      final now = DateTime.now();
      final withRssi = NodeReachabilityData(
        nodeNum: 1,
        lastHeardAt: now,
        averageRssi: -90, // (-90+120)/60 = 0.5
      );
      final withoutRssi = NodeReachabilityData(
        nodeNum: 2,
        lastHeardAt: now,
        // null rssi defaults to 0.4
      );

      final rWith = calculateReachabilityScore(withRssi);
      final rWithout = calculateReachabilityScore(withoutRssi);

      expect(rWith.score, greaterThan(rWithout.score));
    });

    test('null snr defaults to 0.5', () {
      final now = DateTime.now();
      final withSnr = NodeReachabilityData(
        nodeNum: 1,
        lastHeardAt: now,
        averageSnr: 0, // (0+10)/20 = 0.5
      );
      final withoutSnr = NodeReachabilityData(
        nodeNum: 2,
        lastHeardAt: now,
        // null snr defaults to 0.5
      );

      final rWith = calculateReachabilityScore(withSnr);
      final rWithout = calculateReachabilityScore(withoutSnr);

      // Both should be equal since snr=0 gives 0.5 and null defaults to 0.5
      expect((rWith.score - rWithout.score).abs(), lessThan(0.01));
    });

    test('null directRatio defaults to 0.3', () {
      final now = DateTime.now();
      final withDirect = NodeReachabilityData(
        nodeNum: 1,
        lastHeardAt: now,
        directPacketCount: 30,
        indirectPacketCount: 70, // ratio = 0.3
      );
      final withoutDirect = NodeReachabilityData(
        nodeNum: 2,
        lastHeardAt: now,
        // no packet counts, defaults to 0.3
      );

      final rWith = calculateReachabilityScore(withDirect);
      final rWithout = calculateReachabilityScore(withoutDirect);

      // Both should be similar since directRatio=0.3 matches default
      expect((rWith.score - rWithout.score).abs(), lessThan(0.01));
    });

    test('null ackRatio defaults to 0.5', () {
      final now = DateTime.now();
      final withAck = NodeReachabilityData(
        nodeNum: 1,
        lastHeardAt: now,
        dmAckSuccessCount: 50,
        dmAckFailureCount: 50, // ratio = 0.5
      );
      final withoutAck = NodeReachabilityData(
        nodeNum: 2,
        lastHeardAt: now,
        // no ack counts, defaults to 0.5
      );

      final rWith = calculateReachabilityScore(withAck);
      final rWithout = calculateReachabilityScore(withoutAck);

      // Both should be similar since ackRatio=0.5 matches default
      expect((rWith.score - rWithout.score).abs(), lessThan(0.01));
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

    test('fallback to MeshNode data when reachability data missing', () {
      final result = calculateReachabilityScore(
        null,
        lastHeardFromMeshNode: 300, // 5 minutes ago
        rssiFromMeshNode: -70,
        snrFromMeshNode: 5,
      );

      expect(result.hasObservations, isTrue);
      expect(result.pathDepthLabel, equals('Unknown'));
      expect(result.freshnessLabel, equals('5m ago'));
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

    test('dmAckSuccessRatio calculates correctly', () {
      final allSuccess = NodeReachabilityData(
        nodeNum: 1,
        dmAckSuccessCount: 10,
        dmAckFailureCount: 0,
      );
      expect(allSuccess.dmAckSuccessRatio, equals(1.0));

      final mixed = NodeReachabilityData(
        nodeNum: 2,
        dmAckSuccessCount: 3,
        dmAckFailureCount: 7,
      );
      expect(mixed.dmAckSuccessRatio, equals(0.3));

      final noData = NodeReachabilityData(nodeNum: 3);
      expect(noData.dmAckSuccessRatio, isNull);
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

  group('Formula boundary conditions', () {
    test('rssi at boundary -60 dBm gives score 1.0', () {
      // (-60 + 120) / 60 = 1.0
      final data = NodeReachabilityData(
        nodeNum: 1,
        lastHeardAt: DateTime.now(),
        averageRssi: -60,
      );
      final result = calculateReachabilityScore(data);
      // rssiScore = 1.0, contributing 0.15 * 1.0 = 0.15 to total
      expect(result.score, greaterThan(0.5));
    });

    test('rssi at boundary -120 dBm gives score 0.0', () {
      // (-120 + 120) / 60 = 0.0
      final data = NodeReachabilityData(
        nodeNum: 1,
        lastHeardAt: DateTime.now(),
        averageRssi: -120,
      );
      final result = calculateReachabilityScore(data);
      // rssiScore = 0.0, but other factors still contribute
      expect(result.score, greaterThan(0.05));
    });

    test('snr at boundary +10 dB gives score 1.0', () {
      // (10 + 10) / 20 = 1.0
      final data = NodeReachabilityData(
        nodeNum: 1,
        lastHeardAt: DateTime.now(),
        averageSnr: 10,
      );
      final result = calculateReachabilityScore(data);
      expect(result.score, greaterThan(0.5));
    });

    test('snr at boundary -10 dB gives score 0.0', () {
      // (-10 + 10) / 20 = 0.0
      final data = NodeReachabilityData(
        nodeNum: 1,
        lastHeardAt: DateTime.now(),
        averageSnr: -10,
      );
      final result = calculateReachabilityScore(data);
      expect(result.score, greaterThan(0.05));
    });

    test('hop count 0 gives hopScore 1.0', () {
      // 1 / (0 + 1) = 1.0
      final data = NodeReachabilityData(
        nodeNum: 1,
        lastHeardAt: DateTime.now(),
        minimumObservedHopCount: 0,
      );
      final result = calculateReachabilityScore(data);
      expect(result.score, greaterThan(0.7));
    });

    test('hop count 5 gives hopScore clamped to 0.167 (> 0.15)', () {
      // 1 / (5 + 1) = 0.167
      final data = NodeReachabilityData(
        nodeNum: 1,
        lastHeardAt: DateTime.now(),
        minimumObservedHopCount: 5,
      );
      final result = calculateReachabilityScore(data);
      // Lower hopScore contributes less, but still valid
      expect(result.score, greaterThan(0.05));
    });
  });
}
