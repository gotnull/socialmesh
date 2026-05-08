// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/features/nodedex/models/nodedex_entry.dart';
import 'package:socialmesh/features/nodedex/models/observation_source.dart';
import 'package:socialmesh/features/nodedex/providers/nodedex_providers.dart';
import 'package:socialmesh/features/nodedex/providers/nodedex_radio_compatibility_provider.dart';
import 'package:socialmesh/features/nodedex/services/radio_compatibility.dart';
import 'package:socialmesh/features/nodedex/services/sigil_generator.dart';
import 'package:socialmesh/generated/meshtastic/config.pb.dart' as config_pb;
import 'package:socialmesh/generated/meshtastic/config.pbenum.dart'
    as config_pbenum;
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/mesh_capacity_provider.dart';

class _TestNodesNotifier extends NodesNotifier {
  final Map<int, MeshNode> _initial;
  _TestNodesNotifier([this._initial = const {}]);

  @override
  Map<int, MeshNode> build() => _initial;

  void setNodes(Map<int, MeshNode> nodes) => state = nodes;
}

NodeDexEntry _entry({
  int nodeNum = 0xACB22B4,
  int? lastObservedOnPreset,
  ObservationSource? lastObservationSource,
  int? lastHopsAway,
  double? lastObservedFrequencyOffset,
}) {
  return NodeDexEntry(
    nodeNum: nodeNum,
    firstSeen: DateTime(2026, 5, 1),
    lastSeen: DateTime(2026, 5, 8),
    sigil: SigilGenerator.generate(nodeNum),
    lastObservedOnPreset: lastObservedOnPreset,
    lastObservationSource: lastObservationSource,
    lastHopsAway: lastHopsAway,
    lastObservedFrequencyOffset: lastObservedFrequencyOffset,
  );
}

config_pb.Config_LoRaConfig _loraConfig({
  config_pbenum.Config_LoRaConfig_ModemPreset preset =
      config_pbenum.Config_LoRaConfig_ModemPreset.LONG_FAST,
}) {
  return config_pb.Config_LoRaConfig()..modemPreset = preset;
}

/// Build a container and let the StreamProvider override deliver its
/// initial value before returning. The bare ProviderContainer ctor does
/// NOT pump the event queue, so a subsequent synchronous read of the
/// StreamProvider sees `AsyncLoading` (and `.value` is null) until the
/// microtask runs. Each test awaits this helper.
Future<ProviderContainer> _makeContainer({
  required NodeDexEntry entry,
  required bool isSelf,
  config_pb.Config_LoRaConfig? localConfig,
  Map<int, MeshNode> liveNodes = const {},
}) async {
  final nodesNotifier = _TestNodesNotifier(liveNodes);
  final container = ProviderContainer(
    overrides: [
      nodesProvider.overrideWith(() => nodesNotifier),
      // Override the canonical-entry lookup directly so we don't have to
      // boot the full NodeDexNotifier just to seed one row.
      nodeDexEntryProvider(entry.nodeNum).overrideWithValue(entry),
      nodeDexIsSelfProvider(entry.nodeNum).overrideWithValue(isSelf),
      currentLoraConfigProvider.overrideWith(
        (ref) => Stream<config_pb.Config_LoRaConfig?>.value(localConfig),
      ),
    ],
  );
  // Subscribe + pump so the StreamProvider's initial-value emission lands
  // before we read synchronously. Without this, AsyncValue is still in
  // its loading state and `.value` is null, which the helper would
  // misclassify as "no radio connected".
  container.listen(currentLoraConfigProvider, (_, _) {});
  await Future<void>.delayed(Duration.zero);
  return container;
}

void main() {
  // Reset the per-nodeNum log dedupe between tests so each test sees a
  // clean classification cache.
  setUp(() {
    debugLastLoggedStatus.clear();
  });

  test(
    'matching local + persisted RF observation → likelyReachableOnRf',
    () async {
      final preset =
          config_pbenum.Config_LoRaConfig_ModemPreset.LONG_FAST.value;
      final container = await _makeContainer(
        entry: _entry(
          lastObservedOnPreset: preset,
          lastObservationSource: ObservationSource.directRf,
          lastHopsAway: 0,
        ),
        isSelf: false,
        localConfig: _loraConfig(),
      );
      addTearDown(container.dispose);

      final summary = container.read(
        nodeDexRadioCompatibilityProvider(0xACB22B4),
      );
      expect(summary, isNotNull);
      expect(summary!.status, NodeDexReachabilityStatus.likelyReachableOnRf);
    },
  );

  test('local preset change flips status to differentPreset', () async {
    final preset = config_pbenum.Config_LoRaConfig_ModemPreset.LONG_FAST.value;
    // Start with a stream we can drive — emit two successive configs.
    final controller = StreamController<config_pb.Config_LoRaConfig?>();
    addTearDown(controller.close);

    final nodesNotifier = _TestNodesNotifier(const {});
    final container = ProviderContainer(
      overrides: [
        nodesProvider.overrideWith(() => nodesNotifier),
        nodeDexEntryProvider(0xACB22B4).overrideWithValue(
          _entry(
            lastObservedOnPreset: preset,
            lastObservationSource: ObservationSource.directRf,
            lastHopsAway: 0,
          ),
        ),
        nodeDexIsSelfProvider(0xACB22B4).overrideWithValue(false),
        currentLoraConfigProvider.overrideWith((ref) => controller.stream),
      ],
    );
    addTearDown(container.dispose);

    // Subscribe to the StreamProvider BEFORE pushing the first event so
    // the controller's buffered value reaches the override; without this
    // the provider doesn't subscribe until the first read of the derived
    // provider, by which point the value has been buffered but the
    // microtask delivering it lands after our expect.
    container.listen(currentLoraConfigProvider, (_, _) {});
    container.listen(nodeDexRadioCompatibilityProvider(0xACB22B4), (_, _) {});

    // 1. Match.
    controller.add(_loraConfig());
    await Future<void>.delayed(Duration.zero);
    final firstSummary = container.read(
      nodeDexRadioCompatibilityProvider(0xACB22B4),
    );
    expect(firstSummary, isNotNull);
    expect(firstSummary!.status, NodeDexReachabilityStatus.likelyReachableOnRf);

    // 2. Switch local preset.
    controller.add(
      _loraConfig(
        preset: config_pbenum.Config_LoRaConfig_ModemPreset.MEDIUM_FAST,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    final secondSummary = container.read(
      nodeDexRadioCompatibilityProvider(0xACB22B4),
    );
    expect(secondSummary, isNotNull);
    expect(secondSummary!.status, NodeDexReachabilityStatus.differentPreset);
  });

  test(
    'no live MeshNode + no persisted source → falls through to preset compare',
    () async {
      final preset =
          config_pbenum.Config_LoRaConfig_ModemPreset.LONG_FAST.value;
      final container = await _makeContainer(
        entry: _entry(lastObservedOnPreset: preset),
        isSelf: false,
        localConfig: _loraConfig(),
        // No live node — provider falls back to "no fallback".
      );
      addTearDown(container.dispose);

      final summary = container.read(
        nodeDexRadioCompatibilityProvider(0xACB22B4),
      );
      expect(summary, isNotNull);
      expect(
        summary!.status,
        NodeDexReachabilityStatus.likelyReachableOnRf,
        reason:
            'Without persisted or live source/hops we still match presets and '
            'do not invent an MQTT/relay claim.',
      );
    },
  );

  test('live MeshNode with viaMqtt=true → indirectOrMqttObservation', () async {
    final preset = config_pbenum.Config_LoRaConfig_ModemPreset.LONG_FAST.value;
    final liveNode = MeshNode(
      nodeNum: 0xACB22B4,
      viaMqtt: true,
      hopCount: null,
    );
    final container = await _makeContainer(
      // Persisted source intentionally null so the live fallback runs.
      entry: _entry(lastObservedOnPreset: preset),
      isSelf: false,
      localConfig: _loraConfig(),
      liveNodes: {0xACB22B4: liveNode},
    );
    addTearDown(container.dispose);

    final summary = container.read(
      nodeDexRadioCompatibilityProvider(0xACB22B4),
    );
    expect(
      summary!.status,
      NodeDexReachabilityStatus.indirectOrMqttObservation,
    );
    expect(summary.observationSource, ObservationSource.mqtt);
  });

  test('isSelf → selfNode (card hidden by widget layer)', () async {
    final preset = config_pbenum.Config_LoRaConfig_ModemPreset.LONG_FAST.value;
    final container = await _makeContainer(
      entry: _entry(lastObservedOnPreset: preset),
      isSelf: true,
      localConfig: _loraConfig(),
    );
    addTearDown(container.dispose);

    final summary = container.read(
      nodeDexRadioCompatibilityProvider(0xACB22B4),
    );
    expect(summary!.status, NodeDexReachabilityStatus.selfNode);
    expect(summary.isSelf, isTrue);
  });

  test(
    'localConfig null → localRadioUnknown but persisted observation rows kept',
    () async {
      final preset =
          config_pbenum.Config_LoRaConfig_ModemPreset.LONG_FAST.value;
      final container = await _makeContainer(
        entry: _entry(
          lastObservedOnPreset: preset,
          lastObservationSource: ObservationSource.directRf,
          lastHopsAway: 0,
        ),
        isSelf: false,
        localConfig: null,
      );
      addTearDown(container.dispose);

      final summary = container.read(
        nodeDexRadioCompatibilityProvider(0xACB22B4),
      );
      expect(summary!.status, NodeDexReachabilityStatus.localRadioUnknown);
      expect(summary.lastObservedOnPreset, preset);
      expect(summary.observationSource, ObservationSource.directRf);
      expect(summary.hopsAway, 0);
    },
  );

  test('returns null when entry does not exist', () async {
    // Build a container that never provides an entry override for the
    // requested node — nodeDexEntryProvider falls back to the real
    // family provider which returns null for an unknown node.
    final nodesNotifier = _TestNodesNotifier(const {});
    final container = ProviderContainer(
      overrides: [
        nodesProvider.overrideWith(() => nodesNotifier),
        // Force the entry-by-node-num lookup to null without hitting
        // the SQLite-backed nodeDexProvider.
        nodeDexEntryProvider(42).overrideWithValue(null),
        nodeDexIsSelfProvider(42).overrideWithValue(false),
        currentLoraConfigProvider.overrideWith(
          (ref) => Stream<config_pb.Config_LoRaConfig?>.value(_loraConfig()),
        ),
      ],
    );
    container.listen(currentLoraConfigProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    addTearDown(container.dispose);

    final summary = container.read(nodeDexRadioCompatibilityProvider(42));
    expect(summary, isNull);
  });
}
