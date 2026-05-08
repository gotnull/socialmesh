// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/nodedex/models/nodedex_entry.dart';
import 'package:socialmesh/features/nodedex/models/observation_source.dart';
import 'package:socialmesh/features/nodedex/services/radio_compatibility.dart';
import 'package:socialmesh/generated/meshtastic/config.pb.dart' as config_pb;
import 'package:socialmesh/generated/meshtastic/config.pbenum.dart'
    as config_pbenum;

void main() {
  // ===========================================================================
  // Helpers
  // ===========================================================================

  NodeDexEntry baseEntry({
    int? lastObservedOnPreset,
    double? lastObservedFrequencyOffset,
    ObservationSource? lastObservationSource,
    int? lastHopsAway,
  }) {
    return NodeDexEntry(
      nodeNum: 0xACB22B4,
      firstSeen: DateTime(2026, 5, 1),
      lastSeen: DateTime(2026, 5, 8),
      lastObservedOnPreset: lastObservedOnPreset,
      lastObservedFrequencyOffset: lastObservedFrequencyOffset,
      lastObservationSource: lastObservationSource,
      lastHopsAway: lastHopsAway,
    );
  }

  config_pb.Config_LoRaConfig loraConfigWith({
    config_pbenum.Config_LoRaConfig_ModemPreset preset =
        config_pbenum.Config_LoRaConfig_ModemPreset.LONG_FAST,
    double frequencyOffset = 0.0,
  }) {
    final cfg = config_pb.Config_LoRaConfig()..modemPreset = preset;
    if (frequencyOffset != 0.0) {
      cfg.frequencyOffset = frequencyOffset;
    }
    return cfg;
  }

  // ===========================================================================
  // Decision-order coverage
  // ===========================================================================

  group('evaluateRadioCompatibility — decision order', () {
    test('isSelf wins over everything → selfNode', () {
      final summary = evaluateRadioCompatibility(
        entry: baseEntry(
          lastObservedOnPreset:
              config_pbenum.Config_LoRaConfig_ModemPreset.LONG_FAST.value,
          lastObservationSource: ObservationSource.directRf,
          lastHopsAway: 0,
        ),
        localConfig: loraConfigWith(),
        isSelf: true,
      );

      expect(summary.status, NodeDexReachabilityStatus.selfNode);
      expect(summary.isSelf, isTrue);
    });

    test('localConfig == null → localRadioUnknown but persisted rows kept', () {
      final summary = evaluateRadioCompatibility(
        entry: baseEntry(
          lastObservedOnPreset:
              config_pbenum.Config_LoRaConfig_ModemPreset.MEDIUM_FAST.value,
          lastObservationSource: ObservationSource.directRf,
          lastHopsAway: 0,
        ),
        localConfig: null,
        isSelf: false,
      );

      expect(summary.status, NodeDexReachabilityStatus.localRadioUnknown);
      // Critical: disconnected does NOT throw away the persisted context.
      expect(
        summary.lastObservedOnPreset,
        config_pbenum.Config_LoRaConfig_ModemPreset.MEDIUM_FAST.value,
      );
      expect(summary.observationSource, ObservationSource.directRf);
      expect(summary.hopsAway, 0);
      // Local-now fields stay null because there's no radio.
      expect(summary.localPresetNow, isNull);
      expect(summary.localFrequencyOffsetNow, isNull);
    });

    test(
      'mqtt source short-circuits even when presets match → indirectOrMqttObservation',
      () {
        final preset =
            config_pbenum.Config_LoRaConfig_ModemPreset.LONG_FAST.value;
        final summary = evaluateRadioCompatibility(
          entry: baseEntry(
            lastObservedOnPreset: preset,
            lastObservationSource: ObservationSource.mqtt,
          ),
          localConfig: loraConfigWith(
            preset: config_pbenum.Config_LoRaConfig_ModemPreset.LONG_FAST,
          ),
          isSelf: false,
        );

        expect(
          summary.status,
          NodeDexReachabilityStatus.indirectOrMqttObservation,
        );
      },
    );

    test('hopsAway > 0 short-circuits → indirectOrMqttObservation', () {
      final preset =
          config_pbenum.Config_LoRaConfig_ModemPreset.LONG_FAST.value;
      final summary = evaluateRadioCompatibility(
        entry: baseEntry(
          lastObservedOnPreset: preset,
          lastObservationSource: ObservationSource.indirectRf,
          lastHopsAway: 2,
        ),
        localConfig: loraConfigWith(),
        isSelf: false,
      );

      expect(
        summary.status,
        NodeDexReachabilityStatus.indirectOrMqttObservation,
      );
      expect(summary.hopsAway, 2);
    });

    test('lastObservedOnPreset == null → unknown', () {
      final summary = evaluateRadioCompatibility(
        entry: baseEntry(
          lastObservationSource: ObservationSource.directRf,
          lastHopsAway: 0,
        ),
        localConfig: loraConfigWith(),
        isSelf: false,
      );

      expect(summary.status, NodeDexReachabilityStatus.unknown);
    });

    test('preset mismatch → differentPreset', () {
      final summary = evaluateRadioCompatibility(
        entry: baseEntry(
          lastObservedOnPreset:
              config_pbenum.Config_LoRaConfig_ModemPreset.MEDIUM_FAST.value,
          lastObservationSource: ObservationSource.directRf,
          lastHopsAway: 0,
        ),
        localConfig: loraConfigWith(
          preset: config_pbenum.Config_LoRaConfig_ModemPreset.LONG_FAST,
        ),
        isSelf: false,
      );

      expect(summary.status, NodeDexReachabilityStatus.differentPreset);
    });

    test(
      'same preset + frequency offset diff > epsilon → differentFrequencyOffset',
      () {
        final preset =
            config_pbenum.Config_LoRaConfig_ModemPreset.LONG_FAST.value;
        final summary = evaluateRadioCompatibility(
          entry: baseEntry(
            lastObservedOnPreset: preset,
            lastObservedFrequencyOffset: 50.0,
            lastObservationSource: ObservationSource.directRf,
            lastHopsAway: 0,
          ),
          localConfig: loraConfigWith(frequencyOffset: 75.0),
          isSelf: false,
        );

        expect(
          summary.status,
          NodeDexReachabilityStatus.differentFrequencyOffset,
        );
      },
    );

    test(
      'same preset + same offset + directRf + hops 0 → likelyReachableOnRf',
      () {
        final preset =
            config_pbenum.Config_LoRaConfig_ModemPreset.LONG_FAST.value;
        final summary = evaluateRadioCompatibility(
          entry: baseEntry(
            lastObservedOnPreset: preset,
            lastObservedFrequencyOffset: 50.0,
            lastObservationSource: ObservationSource.directRf,
            lastHopsAway: 0,
          ),
          localConfig: loraConfigWith(frequencyOffset: 50.0),
          isSelf: false,
        );

        expect(summary.status, NodeDexReachabilityStatus.likelyReachableOnRf);
      },
    );
  });

  // ===========================================================================
  // Live-fallback path
  // ===========================================================================

  group('evaluateRadioCompatibility — live MeshNode fallback', () {
    test(
      'entry source null, live viaMqtt true → indirectOrMqttObservation',
      () {
        final preset =
            config_pbenum.Config_LoRaConfig_ModemPreset.LONG_FAST.value;
        final summary = evaluateRadioCompatibility(
          entry: baseEntry(lastObservedOnPreset: preset),
          localConfig: loraConfigWith(),
          isSelf: false,
          liveFallback: const LiveObservationFallback(
            viaMqtt: true,
            hopCount: null,
          ),
        );

        expect(
          summary.status,
          NodeDexReachabilityStatus.indirectOrMqttObservation,
        );
        expect(summary.observationSource, ObservationSource.mqtt);
      },
    );

    test(
      'entry source null, live hopCount > 0 → indirectOrMqttObservation',
      () {
        final preset =
            config_pbenum.Config_LoRaConfig_ModemPreset.LONG_FAST.value;
        final summary = evaluateRadioCompatibility(
          entry: baseEntry(lastObservedOnPreset: preset),
          localConfig: loraConfigWith(),
          isSelf: false,
          liveFallback: const LiveObservationFallback(
            viaMqtt: false,
            hopCount: 3,
          ),
        );

        expect(
          summary.status,
          NodeDexReachabilityStatus.indirectOrMqttObservation,
        );
        expect(summary.hopsAway, 3);
      },
    );

    test(
      'entry source null, live viaMqtt false + hops 0 → likelyReachableOnRf',
      () {
        final preset =
            config_pbenum.Config_LoRaConfig_ModemPreset.LONG_FAST.value;
        final summary = evaluateRadioCompatibility(
          entry: baseEntry(lastObservedOnPreset: preset),
          localConfig: loraConfigWith(),
          isSelf: false,
          liveFallback: const LiveObservationFallback(
            viaMqtt: false,
            hopCount: 0,
          ),
        );

        expect(summary.status, NodeDexReachabilityStatus.likelyReachableOnRf);
        expect(summary.observationSource, ObservationSource.directRf);
      },
    );

    test('persisted source wins over live fallback when both present', () {
      // Persisted says RF, live (later, possibly) says MQTT.
      // Persisted reflects the actual last observation; live is just
      // the current model state. Persisted MUST win.
      final preset =
          config_pbenum.Config_LoRaConfig_ModemPreset.LONG_FAST.value;
      final summary = evaluateRadioCompatibility(
        entry: baseEntry(
          lastObservedOnPreset: preset,
          lastObservationSource: ObservationSource.directRf,
          lastHopsAway: 0,
        ),
        localConfig: loraConfigWith(),
        isSelf: false,
        liveFallback: const LiveObservationFallback(viaMqtt: true, hopCount: 5),
      );

      expect(summary.status, NodeDexReachabilityStatus.likelyReachableOnRf);
      expect(summary.observationSource, ObservationSource.directRf);
      expect(summary.hopsAway, 0);
    });

    test(
      'no fallback and no persisted source → unknown source, classified by preset',
      () {
        final preset =
            config_pbenum.Config_LoRaConfig_ModemPreset.LONG_FAST.value;
        final summary = evaluateRadioCompatibility(
          entry: baseEntry(lastObservedOnPreset: preset),
          localConfig: loraConfigWith(),
          isSelf: false,
        );

        // No source/hops information either way — falls through to the
        // preset comparison and matches → likelyReachableOnRf. Honest:
        // we have no MQTT/relay signal so we don't claim one.
        expect(summary.status, NodeDexReachabilityStatus.likelyReachableOnRf);
        expect(summary.observationSource, isNull);
        expect(summary.hopsAway, isNull);
      },
    );
  });

  // ===========================================================================
  // Honest unknowns: never become false mismatches
  // ===========================================================================

  group('evaluateRadioCompatibility — honest unknowns', () {
    test(
      'lastObservedFrequencyOffset null + matching preset → likelyReachableOnRf',
      () {
        final preset =
            config_pbenum.Config_LoRaConfig_ModemPreset.LONG_FAST.value;
        final summary = evaluateRadioCompatibility(
          entry: baseEntry(
            lastObservedOnPreset: preset,
            // No persisted offset.
            lastObservationSource: ObservationSource.directRf,
            lastHopsAway: 0,
          ),
          // Local has a non-zero offset.
          localConfig: loraConfigWith(frequencyOffset: 75.0),
          isSelf: false,
        );

        // Helper does NOT flip to differentFrequencyOffset just because
        // local has an offset and persisted is null — that would be a
        // false mismatch.
        expect(summary.status, NodeDexReachabilityStatus.likelyReachableOnRf);
      },
    );

    test(
      'localConfig has zero offset + persisted has non-zero → no false mismatch',
      () {
        final preset =
            config_pbenum.Config_LoRaConfig_ModemPreset.LONG_FAST.value;
        final summary = evaluateRadioCompatibility(
          entry: baseEntry(
            lastObservedOnPreset: preset,
            lastObservedFrequencyOffset: 50.0,
            lastObservationSource: ObservationSource.directRf,
            lastHopsAway: 0,
          ),
          // Local offset is 0.0 (suppressed by helper to null).
          localConfig: loraConfigWith(frequencyOffset: 0.0),
          isSelf: false,
        );

        // Local-now is treated as unknown offset, not "zero != 50",
        // so we don't flip to differentFrequencyOffset.
        expect(summary.status, NodeDexReachabilityStatus.likelyReachableOnRf);
        expect(summary.localFrequencyOffsetNow, isNull);
      },
    );

    test(
      'frequency offset diff below epsilon (1.0 Hz) → likelyReachableOnRf',
      () {
        final preset =
            config_pbenum.Config_LoRaConfig_ModemPreset.LONG_FAST.value;
        final summary = evaluateRadioCompatibility(
          entry: baseEntry(
            lastObservedOnPreset: preset,
            lastObservedFrequencyOffset: 50.0,
            lastObservationSource: ObservationSource.directRf,
            lastHopsAway: 0,
          ),
          localConfig: loraConfigWith(frequencyOffset: 50.4),
          isSelf: false,
        );

        expect(summary.status, NodeDexReachabilityStatus.likelyReachableOnRf);
      },
    );
  });
}
