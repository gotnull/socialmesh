// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/generated/meshtastic/config.pbenum.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/services/mesh_capacity/mesh_capacity_advisor.dart';
import 'package:socialmesh/services/mesh_capacity/mesh_capacity_models.dart';

void main() {
  const advisor = MeshCapacityAdvisor();
  final now = DateTime.utc(2026, 4, 30, 12, 0, 0);

  MeshNode buildNode({
    required int nodeNum,
    Duration? heardAgo,
    bool viaMqtt = false,
  }) {
    return MeshNode(
      nodeNum: nodeNum,
      lastHeard: heardAgo == null ? null : now.subtract(heardAgo),
      viaMqtt: viaMqtt,
    );
  }

  List<MeshNode> rfNodes(int count, {Duration? heardAgo}) {
    return List.generate(
      count,
      (i) => buildNode(
        nodeNum: 1000 + i,
        heardAgo: heardAgo ?? const Duration(minutes: 3),
      ),
    );
  }

  group('MeshCapacityAdvisor.evaluate', () {
    test('LongFast with sparse nodes returns healthy / no card', () {
      final snapshot = advisor.evaluate(
        nodes: rfNodes(5),
        myNodeNum: 1,
        preset: Config_LoRaConfig_ModemPreset.LONG_FAST,
        now: now,
      );
      expect(snapshot.pressureLevel, MeshCapacityPressureLevel.healthy);
      expect(snapshot.recommendation.shouldShowCard, isFalse);
      expect(
        snapshot.recommendation.reasonCode,
        MeshCapacityReasonCode.healthyForPreset,
      );
    });

    test('LongFast with 40 active RF nodes returns congested advisory', () {
      final snapshot = advisor.evaluate(
        nodes: rfNodes(40),
        myNodeNum: 1,
        preset: Config_LoRaConfig_ModemPreset.LONG_FAST,
        now: now,
      );
      expect(snapshot.pressureLevel, MeshCapacityPressureLevel.congested);
      expect(snapshot.recommendation.shouldShowCard, isTrue);
      expect(
        snapshot.recommendation.severity,
        MeshCapacityRecommendationSeverity.advisory,
      );
      expect(
        snapshot.recommendation.reasonCode,
        MeshCapacityReasonCode.longPresetDenseMesh,
      );
      expect(
        snapshot.recommendation.suggestedPreset,
        Config_LoRaConfig_ModemPreset.MEDIUM_FAST,
      );
    });

    test(
      'LongFast with 70+ active RF nodes returns capacityLimited warning',
      () {
        final snapshot = advisor.evaluate(
          nodes: rfNodes(72),
          myNodeNum: 1,
          preset: Config_LoRaConfig_ModemPreset.LONG_FAST,
          now: now,
        );
        expect(
          snapshot.pressureLevel,
          MeshCapacityPressureLevel.capacityLimited,
        );
        expect(snapshot.recommendation.shouldShowCard, isTrue);
        expect(
          snapshot.recommendation.severity,
          MeshCapacityRecommendationSeverity.warning,
        );
        expect(
          snapshot.recommendation.reasonCode,
          MeshCapacityReasonCode.longPresetDenseMesh,
        );
        expect(
          snapshot.recommendation.suggestedPreset,
          Config_LoRaConfig_ModemPreset.SHORT_FAST,
        );
      },
    );

    test('LongSlow warns earlier than LongFast at 25 nodes', () {
      // 25 nodes is healthy on LongFast (busy starts at 25 inclusive),
      // but LongSlow has long since crossed congested at 20.
      final long25 = advisor.evaluate(
        nodes: rfNodes(25),
        myNodeNum: 1,
        preset: Config_LoRaConfig_ModemPreset.LONG_SLOW,
        now: now,
      );
      expect(long25.pressureLevel, MeshCapacityPressureLevel.congested);

      final fast25 = advisor.evaluate(
        nodes: rfNodes(25),
        myNodeNum: 1,
        preset: Config_LoRaConfig_ModemPreset.LONG_FAST,
        now: now,
      );
      expect(fast25.pressureLevel, MeshCapacityPressureLevel.busy);
    });

    test('MediumFast tolerates more density than LongFast', () {
      // 50 nodes is congested on LongFast but still healthy on MediumFast.
      final long50 = advisor.evaluate(
        nodes: rfNodes(50),
        myNodeNum: 1,
        preset: Config_LoRaConfig_ModemPreset.LONG_FAST,
        now: now,
      );
      expect(long50.pressureLevel, MeshCapacityPressureLevel.congested);

      final medium50 = advisor.evaluate(
        nodes: rfNodes(50),
        myNodeNum: 1,
        preset: Config_LoRaConfig_ModemPreset.MEDIUM_FAST,
        now: now,
      );
      expect(medium50.pressureLevel, MeshCapacityPressureLevel.healthy);
    });

    test('ShortFast does not nag at moderate density', () {
      final snapshot = advisor.evaluate(
        nodes: rfNodes(100),
        myNodeNum: 1,
        preset: Config_LoRaConfig_ModemPreset.SHORT_FAST,
        now: now,
      );
      expect(snapshot.pressureLevel, MeshCapacityPressureLevel.healthy);
      expect(snapshot.recommendation.shouldShowCard, isFalse);
    });

    test(
      'Unknown preset returns presetUnknown and no concrete suggested preset',
      () {
        final snapshot = advisor.evaluate(
          nodes: rfNodes(30),
          myNodeNum: 1,
          preset: null,
          now: now,
        );
        expect(snapshot.pressureLevel, MeshCapacityPressureLevel.unknown);
        expect(snapshot.hasPresetInfo, isFalse);
        expect(
          snapshot.recommendation.reasonCode,
          MeshCapacityReasonCode.presetUnknown,
        );
        expect(snapshot.recommendation.suggestedPreset, isNull);
        expect(snapshot.recommendation.shouldShowCard, isTrue);
      },
    );

    test('Insufficient data returns insufficientData / no card', () {
      // No RF nodes: only self + a viaMqtt node.
      final snapshot = advisor.evaluate(
        nodes: [
          buildNode(nodeNum: 1, heardAgo: const Duration(minutes: 1)),
          buildNode(
            nodeNum: 2,
            heardAgo: const Duration(minutes: 2),
            viaMqtt: true,
          ),
        ],
        myNodeNum: 1,
        preset: Config_LoRaConfig_ModemPreset.LONG_FAST,
        now: now,
      );
      expect(snapshot.activeRfNodes15m, 0);
      expect(snapshot.hasSufficientSignalData, isFalse);
      expect(
        snapshot.recommendation.reasonCode,
        MeshCapacityReasonCode.insufficientData,
      );
      expect(snapshot.recommendation.shouldShowCard, isFalse);
    });

    test('Total known nodes alone does not trigger warning if recent active '
        'RF nodes are low', () {
      // 200 stale-NodeDB entries (heard 6 hours ago) + 5 fresh.
      final stale = List.generate(
        200,
        (i) => buildNode(nodeNum: 5000 + i, heardAgo: const Duration(hours: 6)),
      );
      final fresh = rfNodes(5);
      final snapshot = advisor.evaluate(
        nodes: [...stale, ...fresh],
        myNodeNum: 1,
        preset: Config_LoRaConfig_ModemPreset.LONG_FAST,
        now: now,
      );
      expect(snapshot.totalKnownNodes, 205);
      expect(snapshot.activeRfNodes15m, 5);
      expect(snapshot.pressureLevel, MeshCapacityPressureLevel.healthy);
      expect(snapshot.recommendation.shouldShowCard, isFalse);
    });

    test('MQTT-only nodes are not counted as RF-active', () {
      final mqttOnly = List.generate(
        50,
        (i) => buildNode(
          nodeNum: 7000 + i,
          heardAgo: const Duration(minutes: 4),
          viaMqtt: true,
        ),
      );
      final snapshot = advisor.evaluate(
        nodes: mqttOnly,
        myNodeNum: 1,
        preset: Config_LoRaConfig_ModemPreset.LONG_FAST,
        now: now,
      );
      expect(snapshot.activeRfNodes15m, 0);
      expect(
        snapshot.recommendation.reasonCode,
        MeshCapacityReasonCode.insufficientData,
      );
      expect(snapshot.recommendation.shouldShowCard, isFalse);
    });

    test('Suggested preset for dense LongFast is MediumFast (congested)', () {
      final snapshot = advisor.evaluate(
        nodes: rfNodes(45),
        myNodeNum: 1,
        preset: Config_LoRaConfig_ModemPreset.LONG_FAST,
        now: now,
      );
      expect(
        snapshot.recommendation.suggestedPreset,
        Config_LoRaConfig_ModemPreset.MEDIUM_FAST,
      );
    });

    test(
      'Suggested preset for capacity-limited LongFast escalates to ShortFast',
      () {
        final snapshot = advisor.evaluate(
          nodes: rfNodes(80),
          myNodeNum: 1,
          preset: Config_LoRaConfig_ModemPreset.LONG_FAST,
          now: now,
        );
        expect(
          snapshot.recommendation.suggestedPreset,
          Config_LoRaConfig_ModemPreset.SHORT_FAST,
        );
      },
    );

    test('ShortTurbo is never recommended casually', () {
      // Even at extreme density on a long preset, the advisor must not
      // suggest ShortTurbo. Range of densities tested: 70..2000.
      for (final density in [70, 150, 400, 1000, 2000]) {
        final snapshot = advisor.evaluate(
          nodes: rfNodes(density),
          myNodeNum: 1,
          preset: Config_LoRaConfig_ModemPreset.LONG_FAST,
          now: now,
        );
        expect(
          snapshot.recommendation.suggestedPreset,
          isNot(Config_LoRaConfig_ModemPreset.SHORT_TURBO),
          reason:
              'ShortTurbo should never be a casual recommendation '
              '(density=$density)',
        );
      }
    });

    test('Recommendation reason code is stable / deterministic', () {
      // Same inputs => identical reason code across many calls.
      MeshCapacityReasonCode? prior;
      for (var i = 0; i < 10; i++) {
        final snapshot = advisor.evaluate(
          nodes: rfNodes(45),
          myNodeNum: 1,
          preset: Config_LoRaConfig_ModemPreset.LONG_FAST,
          now: now,
        );
        prior ??= snapshot.recommendation.reasonCode;
        expect(snapshot.recommendation.reasonCode, prior);
      }
    });

    test('Boundary tests: LongFast thresholds [busy=25, cong=40, cap=70]', () {
      MeshCapacityPressureLevel level(int n) => advisor
          .evaluate(
            nodes: rfNodes(n),
            myNodeNum: 1,
            preset: Config_LoRaConfig_ModemPreset.LONG_FAST,
            now: now,
          )
          .pressureLevel;

      expect(level(24), MeshCapacityPressureLevel.healthy);
      expect(level(25), MeshCapacityPressureLevel.busy);
      expect(level(39), MeshCapacityPressureLevel.busy);
      expect(level(40), MeshCapacityPressureLevel.congested);
      expect(level(69), MeshCapacityPressureLevel.congested);
      expect(level(70), MeshCapacityPressureLevel.capacityLimited);
    });

    test('Self node is excluded from active density', () {
      // 26 nodes total, but one of them is "self". 25 RF-actives → busy.
      final nodes = List.generate(
        26,
        (i) =>
            buildNode(nodeNum: 1000 + i, heardAgo: const Duration(minutes: 3)),
      );
      final snapshot = advisor.evaluate(
        nodes: nodes,
        myNodeNum: 1000,
        preset: Config_LoRaConfig_ModemPreset.LONG_FAST,
        now: now,
      );
      expect(snapshot.activeRfNodes15m, 25);
      expect(snapshot.pressureLevel, MeshCapacityPressureLevel.busy);
    });

    test('5 / 15 / 60 minute windows are populated correctly', () {
      final nodes = [
        buildNode(nodeNum: 1, heardAgo: const Duration(minutes: 2)), // 5/15/60
        buildNode(nodeNum: 2, heardAgo: const Duration(minutes: 12)), // 15/60
        buildNode(nodeNum: 3, heardAgo: const Duration(minutes: 45)), // 60
        buildNode(nodeNum: 4, heardAgo: const Duration(hours: 4)), // none
      ];
      final snapshot = advisor.evaluate(
        nodes: nodes,
        myNodeNum: 999,
        preset: Config_LoRaConfig_ModemPreset.LONG_FAST,
        now: now,
      );
      expect(snapshot.activeRfNodes5m, 1);
      expect(snapshot.activeRfNodes15m, 2);
      expect(snapshot.activeRfNodes60m, 3);
      expect(snapshot.totalKnownNodes, 4);
    });

    test('ShortFast at very high density surfaces event-like density', () {
      final snapshot = advisor.evaluate(
        nodes: rfNodes(600),
        myNodeNum: 1,
        preset: Config_LoRaConfig_ModemPreset.SHORT_FAST,
        now: now,
      );
      expect(snapshot.pressureLevel, MeshCapacityPressureLevel.capacityLimited);
      expect(
        snapshot.recommendation.reasonCode,
        MeshCapacityReasonCode.veryDenseEventLikeMesh,
      );
      expect(snapshot.recommendation.suggestedPreset, isNull);
    });
  });
}
