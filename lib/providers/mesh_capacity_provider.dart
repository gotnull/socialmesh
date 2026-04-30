// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Mesh Capacity Advisor — Riverpod wiring.
//
// Watches the existing node graph + the device's modem preset and runs
// the pure [MeshCapacityAdvisor] to produce a [MeshCapacitySnapshot].
// No business logic here — the provider is a thin reactive bridge so
// the UI can subscribe to recommendations without knowing about
// ProtocolService streams.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging.dart';
import '../generated/meshtastic/config.pb.dart' as config_pb;
import '../models/mesh_models.dart';
import '../services/mesh_capacity/mesh_capacity_advisor.dart';
import '../services/mesh_capacity/mesh_capacity_models.dart';
import 'app_providers.dart';

/// Streams the device's currently active LoRa config. Mirrors the
/// existing [deviceRegionProvider] pattern: emits the cached config
/// from [ProtocolService] immediately if available, then forwards
/// future updates from `loraConfigStream`.
final currentLoraConfigProvider = StreamProvider<config_pb.Config_LoRaConfig?>((
  ref,
) async* {
  final protocol = ref.watch(protocolServiceProvider);
  yield protocol.currentLoraConfig;
  await for (final config in protocol.loraConfigStream) {
    yield config;
  }
});

class MeshCapacitySnapshotNotifier extends Notifier<MeshCapacitySnapshot> {
  static const MeshCapacityAdvisor _advisor = MeshCapacityAdvisor();

  // Canonical advisor-state dedupe key. Every screen / card consumer of
  // the snapshot rebuilds many times per second as nodes update — but
  // logging is only useful when the *advisor's verdict* changes, not
  // when an individual node count ticks. Active node counts (5/15/60m)
  // are intentionally NOT in the key so high-cadence histogram updates
  // don't spam the log. See feedback in the original PR.
  String? _lastLogKey;

  @override
  MeshCapacitySnapshot build() {
    final nodes = ref.watch(nodesProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);
    final loraConfig = ref.watch(currentLoraConfigProvider).value;

    final snapshot = _advisor.evaluate(
      nodes: nodes.values,
      myNodeNum: myNodeNum,
      preset: loraConfig?.modemPreset,
      now: DateTime.now(),
    );

    final key = _stateKey(snapshot);
    if (key != _lastLogKey) {
      AppLogging.meshCapacity(
        'state changed pressureLevel=${snapshot.pressureLevel.name} '
        'currentPreset=${snapshot.currentModemPreset?.name ?? 'unknown'} '
        'reasonCode=${snapshot.recommendation.reasonCode.name} '
        'shouldShowCard=${snapshot.recommendation.shouldShowCard} '
        'suggestedPreset=${snapshot.recommendation.suggestedPreset?.name ?? 'none'} '
        'activeRfNodes15m=${snapshot.activeRfNodes15m}',
      );
      _lastLogKey = key;
    }

    return snapshot;
  }

  static String _stateKey(MeshCapacitySnapshot s) =>
      '${s.pressureLevel.name}|'
      '${s.currentModemPreset?.name ?? 'unknown'}|'
      '${s.recommendation.reasonCode.name}|'
      '${s.recommendation.shouldShowCard}';
}

final meshCapacitySnapshotProvider =
    NotifierProvider<MeshCapacitySnapshotNotifier, MeshCapacitySnapshot>(
      MeshCapacitySnapshotNotifier.new,
    );

/// Tracks reason codes the user has dismissed for the current session.
/// In-memory only — restarting the app re-surfaces a still-applicable
/// recommendation, which is the desired behaviour for capacity advice
/// (the network may have changed between sessions).
class MeshCapacityDismissalNotifier
    extends Notifier<Set<MeshCapacityReasonCode>> {
  @override
  Set<MeshCapacityReasonCode> build() => const <MeshCapacityReasonCode>{};

  void dismiss(MeshCapacityReasonCode reason) {
    if (state.contains(reason)) return;
    state = {...state, reason};
    AppLogging.meshCapacity('card dismissed reasonCode=${reason.name}');
  }

  bool isDismissed(MeshCapacityReasonCode reason) => state.contains(reason);
}

final meshCapacityDismissalProvider =
    NotifierProvider<
      MeshCapacityDismissalNotifier,
      Set<MeshCapacityReasonCode>
    >(MeshCapacityDismissalNotifier.new);

/// Whether the advisor card should currently be visible. Combines the
/// snapshot's `shouldShowCard` flag with the dismissal set.
final meshCapacityCardVisibleProvider = Provider<bool>((ref) {
  final snapshot = ref.watch(meshCapacitySnapshotProvider);
  if (!snapshot.recommendation.shouldShowCard) return false;
  final dismissed = ref.watch(meshCapacityDismissalProvider);
  return !dismissed.contains(snapshot.recommendation.reasonCode);
});

/// Test seam — exposes the pure advisor for any consumer that needs
/// to compute a snapshot without going through the provider graph.
MeshCapacityAdvisor meshCapacityAdvisorForTest() => const MeshCapacityAdvisor();

/// Helper for callers that have a node iterable already (e.g. tests).
MeshCapacitySnapshot evaluateMeshCapacityForTest({
  required Iterable<MeshNode> nodes,
  required int? myNodeNum,
  required config_pb.Config_LoRaConfig? loraConfig,
  required DateTime now,
}) => const MeshCapacityAdvisor().evaluate(
  nodes: nodes,
  myNodeNum: myNodeNum,
  preset: loraConfig?.modemPreset,
  now: now,
);
