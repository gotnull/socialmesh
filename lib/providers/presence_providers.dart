// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/logging.dart';
import '../models/mesh_models.dart';
import '../models/node_encounter.dart';
import '../models/presence_confidence.dart';
import '../providers/app_providers.dart';
import '../features/automations/automation_providers.dart';
import '../services/extended_presence_service.dart';

final presenceClockProvider = Provider<DateTime Function()>(
  (_) => DateTime.now,
);

/// Provider for extended presence service (singleton)
/// NOTE: Service must be initialized before use via _ensureInit() internally
final extendedPresenceServiceProvider = Provider<ExtendedPresenceService>((
  ref,
) {
  final service = ExtendedPresenceService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Ensure extended presence service is initialized (for eager loading on app start)
final extendedPresenceInitProvider = FutureProvider<void>((ref) async {
  final service = ref.watch(extendedPresenceServiceProvider);
  await service.init();
});

/// Provider for node encounter history service (local-only)
final nodeEncounterServiceProvider = Provider<NodeEncounterService>((ref) {
  final service = NodeEncounterService(
    read: (key) async {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    },
    write: (key, value) async {
      final prefs = await SharedPreferences.getInstance();
      return prefs.setString(key, value);
    },
  );
  ref.onDispose(() => service.flush());
  return service;
});

/// Provider for a specific node's encounter history
final nodeEncounterProvider = Provider.family<NodeEncounter?, int>((
  ref,
  nodeNum,
) {
  final service = ref.watch(nodeEncounterServiceProvider);
  return service.getEncounter(nodeNum);
});

/// Provider for frequent nodes (sorted by encounter count)
final frequentNodesProvider = Provider<List<NodeEncounter>>((ref) {
  final service = ref.watch(nodeEncounterServiceProvider);
  return service.getFrequentNodes();
});

/// Provider for my extended presence info
final myExtendedPresenceProvider = FutureProvider<ExtendedPresenceInfo>((
  ref,
) async {
  final service = ref.watch(extendedPresenceServiceProvider);
  await service.init();
  return service.getMyPresenceInfo();
});

/// Stream provider that listens to remote presence updates for live reactivity.
/// Watching this provider causes rebuilds when any node's presence changes.
final remotePresenceUpdatesProvider =
    StreamProvider<(int nodeNum, ExtendedPresenceInfo info)>((ref) {
      final service = ref.watch(extendedPresenceServiceProvider);
      return service.remoteUpdates;
    });

/// Provider for a specific node's extended presence info.
/// Rebuilds reactively when remote presence updates arrive.
final nodeExtendedPresenceProvider = Provider.family<ExtendedPresenceInfo?, int>((
  ref,
  nodeNum,
) {
  // Ensure service is initialized by depending on init provider
  ref.watch(extendedPresenceInitProvider);
  // Watch updates stream for live reactivity - rebuild when any update arrives
  // Only trigger rebuild for THIS node's updates
  ref.listen(remotePresenceUpdatesProvider, (_, next) {
    next.whenData((update) {
      if (update.$1 == nodeNum) {
        ref.invalidateSelf();
      }
    });
  });
  final service = ref.watch(extendedPresenceServiceProvider);
  return service.getRemotePresence(nodeNum);
});

@immutable
class NodePresence {
  final MeshNode node;
  final PresenceConfidence confidence;
  final Duration? timeSinceLastHeard;
  final double? signalQuality;
  final ExtendedPresenceInfo? extendedInfo;
  final NodeEncounter? encounter;
  final bool isBackNearby;

  const NodePresence({
    required this.node,
    required this.confidence,
    this.timeSinceLastHeard,
    this.signalQuality,
    this.extendedInfo,
    this.encounter,
    this.isBackNearby = false,
  });

  /// Derived fuzzy last-seen bucket from timeSinceLastHeard.
  LastSeenBucket get lastSeenBucket =>
      LastSeenBucket.fromDuration(timeSinceLastHeard);

  /// Derived confidence tier from presence confidence.
  ConfidenceTier get confidenceTier =>
      ConfidenceTier.fromConfidence(confidence);

  NodePresence copyWith({
    MeshNode? node,
    PresenceConfidence? confidence,
    Duration? timeSinceLastHeard,
    double? signalQuality,
    ExtendedPresenceInfo? extendedInfo,
    NodeEncounter? encounter,
    bool? isBackNearby,
  }) {
    return NodePresence(
      node: node ?? this.node,
      confidence: confidence ?? this.confidence,
      timeSinceLastHeard: timeSinceLastHeard ?? this.timeSinceLastHeard,
      signalQuality: signalQuality ?? this.signalQuality,
      extendedInfo: extendedInfo ?? this.extendedInfo,
      encounter: encounter ?? this.encounter,
      isBackNearby: isBackNearby ?? this.isBackNearby,
    );
  }
}

final presenceMapProvider =
    NotifierProvider<PresenceNotifier, Map<int, NodePresence>>(
      PresenceNotifier.new,
    );

final presenceForNodeProvider = Provider.family<NodePresence?, int>((
  ref,
  nodeNum,
) {
  final map = ref.watch(presenceMapProvider);
  return map[nodeNum];
});

final presenceListProvider = Provider<List<NodePresence>>((ref) {
  final map = ref.watch(presenceMapProvider);
  final myNodeNum = ref.watch(myNodeNumProvider);
  final list = map.values
      .where((presence) => presence.node.nodeNum != myNodeNum)
      .toList();

  list.sort((a, b) {
    final statusCompare = a.confidence.index.compareTo(b.confidence.index);
    if (statusCompare != 0) return statusCompare;
    final aTime = a.timeSinceLastHeard?.inSeconds ?? 1 << 30;
    final bTime = b.timeSinceLastHeard?.inSeconds ?? 1 << 30;
    return aTime.compareTo(bTime);
  });

  return list;
});

final presenceSummaryProvider = Provider<Map<PresenceConfidence, int>>((ref) {
  final presences = ref.watch(presenceListProvider);
  final counts = <PresenceConfidence, int>{
    PresenceConfidence.active: 0,
    PresenceConfidence.fading: 0,
    PresenceConfidence.stale: 0,
    PresenceConfidence.unknown: 0,
  };

  for (final presence in presences) {
    counts[presence.confidence] = (counts[presence.confidence] ?? 0) + 1;
  }

  return counts;
});

PresenceConfidence presenceConfidenceFor(
  Map<int, NodePresence> presenceMap,
  MeshNode node,
) {
  final presence = presenceMap[node.nodeNum];
  if (presence != null) return presence.confidence;
  return PresenceCalculator.fromLastHeard(node.lastHeard, now: DateTime.now());
}

Duration? lastHeardAgeFor(Map<int, NodePresence> presenceMap, MeshNode node) {
  final presence = presenceMap[node.nodeNum];
  if (presence != null) return presence.timeSinceLastHeard;
  final heard = node.lastHeard;
  if (heard == null) return null;
  return DateTime.now().difference(heard);
}

class PresenceNotifier extends Notifier<Map<int, NodePresence>> {
  static const Duration _tickInterval = Duration(seconds: 30);

  Timer? _timer;
  final Map<int, PresenceConfidence> _lastConfidence = {};
  final Set<int> _backNearbyShown =
      {}; // Track nodes shown as "back nearby" this session

  @override
  Map<int, NodePresence> build() {
    ref.onDispose(() => _timer?.cancel());
    _timer ??= Timer.periodic(_tickInterval, (_) => _recompute());

    ref.listen<Map<int, MeshNode>>(
      nodesProvider,
      (previous, next) => _recompute(),
    );

    final initial = _compute(
      ref.read(nodesProvider),
      ref.read(presenceClockProvider)(),
      logTransitions: false,
    );
    return initial;
  }

  void _recompute() {
    final nodes = ref.read(nodesProvider);
    state = _compute(
      nodes,
      ref.read(presenceClockProvider)(),
      logTransitions: true,
    );
  }

  Map<int, NodePresence> _compute(
    Map<int, MeshNode> nodes,
    DateTime now, {
    required bool logTransitions,
  }) {
    final next = <int, NodePresence>{};
    final seenNodes = <int>{};
    final extendedService = ref.read(extendedPresenceServiceProvider);
    final encounterService = ref.read(nodeEncounterServiceProvider);

    for (final node in nodes.values) {
      final confidence = PresenceCalculator.fromLastHeard(
        node.lastHeard,
        now: now,
      );
      final age = node.lastHeard != null
          ? now.difference(node.lastHeard!)
          : null;
      final signalQuality = _calculateSignalQuality(node);
      final extendedInfo = extendedService.getRemotePresence(node.nodeNum);

      // Get previous encounter state before recording
      final previousEncounter = encounterService.getEncounter(node.nodeNum);

      // Check if this is a "back nearby" node (>48h absence, now active)
      final isBackNearby =
          confidence == PresenceConfidence.active &&
          previousEncounter != null &&
          !_backNearbyShown.contains(node.nodeNum) &&
          now.difference(previousEncounter.lastSeen).inHours > 48;

      if (isBackNearby) {
        _backNearbyShown.add(node.nodeNum);
      }

      // Record encounter for active nodes
      if (confidence == PresenceConfidence.active) {
        unawaited(encounterService.recordObservation(node.nodeNum, now: now));
      }
      final encounter = encounterService.getEncounter(node.nodeNum);

      next[node.nodeNum] = NodePresence(
        node: node,
        confidence: confidence,
        timeSinceLastHeard: age,
        signalQuality: signalQuality,
        extendedInfo: extendedInfo,
        encounter: encounter,
        isBackNearby: isBackNearby,
      );

      if (logTransitions) {
        final previous = _lastConfidence[node.nodeNum];
        if (previous != confidence) {
          final lastHeardMillis = node.lastHeard?.millisecondsSinceEpoch;
          AppLogging.nodes(
            'PRESENCE_UPDATE node=${node.nodeNum} lastHeard=${lastHeardMillis ?? 'null'} state=${confidence.name}',
          );
          if (previous != null) {
            unawaited(_handleTransition(node, previous, confidence));
          }
        }
      }

      _lastConfidence[node.nodeNum] = confidence;
      seenNodes.add(node.nodeNum);
    }

    _lastConfidence.removeWhere((nodeNum, _) => !seenNodes.contains(nodeNum));

    return next;
  }

  @visibleForTesting
  void recomputeNow() => _recompute();

  Future<void> _handleTransition(
    MeshNode node,
    PresenceConfidence previous,
    PresenceConfidence current,
  ) async {
    final ifttt = ref.read(iftttServiceProvider);
    await ifttt.processPresenceUpdate(
      node,
      previous: previous,
      current: current,
    );

    final automation = ref.read(automationEngineProvider);
    await automation.processPresenceUpdate(
      node,
      previous: previous,
      current: current,
    );
  }

  double? _calculateSignalQuality(MeshNode node) {
    final snr = node.snr;
    if (snr == null) return null;
    final normalized = (snr + 20) / 30;
    return normalized.clamp(0.0, 1.0);
  }
}
