// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// NodeDex Radio Compatibility Provider — derived view that joins the
// canonical NodeDex entry, the local radio's current LoRa config, the
// live MeshNode (for fallback transport classification), and the
// "is this self?" identity provider into a single
// NodeDexRadioCompatibilitySummary the detail screen can consume.
//
// Pure logic lives in services/radio_compatibility.dart. This provider's
// only job is to plumb four streams into that helper and dedupe the
// status-change log to one line per transition.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/mesh_capacity_provider.dart';
import '../services/radio_compatibility.dart';
import 'nodedex_providers.dart';

/// Per-`nodeNum` cache of the last-emitted reachability status. Used to
/// dedupe the AppLogging.nodeDex status-change line so that rebuilds
/// (theme, accessibility, unrelated provider tick) don't spam logs on
/// busy meshes. Visible for testing.
final Map<int, NodeDexReachabilityStatus> debugLastLoggedStatus =
    <int, NodeDexReachabilityStatus>{};

/// Derived radio compatibility summary for a NodeDex entry.
///
/// Returns `null` when the entry has not yet been discovered (mirrors
/// [nodeDexEntryProvider]). Self nodes return a summary with status
/// [NodeDexReachabilityStatus.selfNode]; the UI hides the card in that
/// case rather than special-casing null here.
final nodeDexRadioCompatibilityProvider =
    Provider.family<NodeDexRadioCompatibilitySummary?, int>((ref, nodeNum) {
      final entry = ref.watch(nodeDexEntryProvider(nodeNum));
      if (entry == null) return null;

      final isSelf = ref.watch(nodeDexIsSelfProvider(nodeNum));
      final localConfig = ref.watch(currentLoraConfigProvider).value;

      // Live MeshNode fallback: when the entry has no persisted
      // observation source / hop count (legacy entries from before v12),
      // we infer from the live model. If the live model is also missing,
      // both fields stay null and the helper falls back to "unknown".
      final liveNode = ref.watch(nodesProvider)[nodeNum];
      final liveFallback = liveNode == null
          ? null
          : LiveObservationFallback(
              viaMqtt: liveNode.viaMqtt,
              hopCount: liveNode.hopCount,
            );

      final summary = evaluateRadioCompatibility(
        entry: entry,
        localConfig: localConfig,
        isSelf: isSelf,
        liveFallback: liveFallback,
      );

      // Dedupe status-change logging: only emit when the classification
      // for this node has actually changed since last evaluation.
      final lastLogged = debugLastLoggedStatus[nodeNum];
      if (lastLogged != summary.status) {
        debugLastLoggedStatus[nodeNum] = summary.status;
        AppLogging.nodeDex(
          'Reachability for !${nodeNum.toRadixString(16).toUpperCase()}: '
          '${summary.status.name} '
          '(localPreset: ${summary.localPresetNow ?? "n/a"}, '
          'observedOn: ${summary.lastObservedOnPreset ?? "n/a"}, '
          'source: ${summary.observationSource?.name ?? "n/a"}, '
          'hops: ${summary.hopsAway ?? "n/a"})',
        );
      }

      return summary;
    });
