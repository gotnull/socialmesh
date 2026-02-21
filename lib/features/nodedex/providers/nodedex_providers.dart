// SPDX-License-Identifier: GPL-3.0-or-later
import '../../../features/nodes/node_display_name_resolver.dart';

// NodeDex Providers — Riverpod 3.x state management for the mesh field journal.
//
// Provider hierarchy:
//
// nodeDexStoreProvider (FutureProvider)
//   └── nodeDexProvider (NotifierProvider) — source of truth for all entries
//         ├── nodeDexEntryProvider(int) — single entry lookup
//         ├── nodeDexStatsProvider — aggregate statistics
//         ├── nodeDexTraitProvider(int) — computed trait for a node
//         ├── nodeDexSortedEntriesProvider — sorted list for UI
//         └── nodeDexConstellationProvider — graph data for constellation view
//
// The nodeDexProvider listens to nodesProvider for automatic discovery
// tracking. When a new node appears or an existing node updates, the
// NodeDex entry is created or refreshed without any user action.
//
// Storage: SQLite via NodeDexSqliteStore.
// Cloud Sync: optional outbox-based sync via NodeDexSyncService.

import 'dart:async' show Timer, unawaited;

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import '../../../core/logging.dart';
import '../../../models/mesh_models.dart';
import '../../../models/presence_confidence.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/cloud_sync_entitlement_providers.dart';
import '../../../providers/signal_providers.dart';
import '../models/import_preview.dart';
import '../models/node_activity_event.dart';
import '../models/nodedex_entry.dart';
import '../services/nodedex_database.dart';
import '../services/nodedex_sqlite_store.dart';
import '../services/nodedex_sync_service.dart';
import '../services/field_note_generator.dart';
import '../services/node_summary_engine.dart';
import '../services/patina_score.dart';
import '../services/progressive_disclosure.dart';
import '../services/sigil_generator.dart';
import '../services/trait_engine.dart';
import '../services/trust_score.dart';

// =============================================================================
// Storage Provider
// =============================================================================

/// Provides the NodeDex SQLite database instance.
final nodeDexDatabaseProvider = Provider<NodeDexDatabase>((ref) {
  final db = NodeDexDatabase();
  ref.onDispose(() {
    db.close();
  });
  return db;
});

/// Provides an initialized NodeDexSqliteStore instance.
///
/// The store is initialized once and shared across all providers.
final nodeDexStoreProvider = FutureProvider<NodeDexSqliteStore>((ref) async {
  final db = ref.watch(nodeDexDatabaseProvider);
  final store = NodeDexSqliteStore(db);
  await store.init();
  // Auto-prune excess entries (>10,000) on startup
  await store.pruneExcessEntries();

  ref.onDispose(() {
    store.flush();
  });

  return store;
});

/// Provides the NodeDex Cloud Sync service.
///
/// Enabled/disabled based on the user's Cloud Sync entitlement.
final nodeDexSyncServiceProvider = Provider<NodeDexSyncService?>((ref) {
  final storeAsync = ref.watch(nodeDexStoreProvider);
  final store = storeAsync.asData?.value;
  if (store == null) return null;

  final syncService = NodeDexSyncService(store);

  // Watch cloud sync entitlement to enable/disable.
  final canWrite = ref.watch(canCloudSyncWriteProvider);
  syncService.setEnabled(canWrite);

  ref.onDispose(() async {
    await syncService.dispose();
  });

  return syncService;
});

// =============================================================================
// Core NodeDex Provider
// =============================================================================

/// The source of truth for all NodeDex entries.
///
/// This notifier:
/// - Loads entries from persistent storage on init
/// - Listens to nodesProvider for automatic discovery tracking
/// - Updates encounter records when nodes are re-seen
/// - Tracks co-seen relationships for the constellation
/// - Persists changes via debounced writes to NodeDexSqliteStore
///
/// All UI components read from this provider for NodeDex data.
class NodeDexNotifier extends Notifier<Map<int, NodeDexEntry>> {
  NodeDexSqliteStore? _store;
  Timer? _coSeenTimer;

  /// Snapshot of the last known state, used during dispose when
  /// accessing [state] is forbidden by Riverpod's lifecycle rules.
  Map<int, NodeDexEntry>? _lastKnownState;

  /// Set of node numbers seen in the current session, used for
  /// co-seen relationship tracking.
  final Set<int> _sessionSeenNodes = {};

  /// Tracks the last encounter time per node to implement cooldown.
  final Map<int, DateTime> _lastEncounterTime = {};

  /// Minimum gap between encounter recordings for the same node.
  /// Override via [encounterCooldownOverride] in tests.
  static Duration _defaultEncounterCooldown = const Duration(minutes: 5);

  /// Interval for co-seen relationship batch updates.
  /// Override via [coSeenFlushIntervalOverride] in tests.
  static Duration _defaultCoSeenFlushInterval = const Duration(minutes: 2);

  /// Test-only override for encounter cooldown duration.
  @visibleForTesting
  static set encounterCooldownOverride(Duration value) =>
      _defaultEncounterCooldown = value;

  /// Test-only override for co-seen flush interval.
  @visibleForTesting
  static set coSeenFlushIntervalOverride(Duration value) =>
      _defaultCoSeenFlushInterval = value;

  /// Test-only: reset durations to production defaults.
  @visibleForTesting
  static void resetTestOverrides() {
    _defaultEncounterCooldown = const Duration(minutes: 5);
    _defaultCoSeenFlushInterval = const Duration(minutes: 2);
  }

  /// Test-only: manually trigger co-seen relationship flush.
  @visibleForTesting
  void flushCoSeenForTest() => _flushCoSeenRelationships();

  @override
  Map<int, NodeDexEntry> build() {
    final storeAsync = ref.watch(nodeDexStoreProvider);
    _store = storeAsync.asData?.value;

    // Activate sync service (reads entitlement, enables/disables).
    // Wire up onPullApplied so remote data reloads into the UI.
    final syncService = ref.watch(nodeDexSyncServiceProvider);
    syncService?.onPullApplied = (appliedCount) {
      if (!ref.mounted || _store == null) return;
      AppLogging.nodeDex(
        'Sync pull applied $appliedCount entries — reloading state',
      );
      _reloadFromStore();
    };

    // Listen to node changes for automatic discovery tracking.
    ref.listen<Map<int, MeshNode>>(nodesProvider, (previous, next) {
      if (!ref.mounted) return;
      _handleNodesUpdate(previous ?? {}, next);
    });

    ref.onDispose(() {
      _coSeenTimer?.cancel();
      // Use persistOnly to avoid setting state during dispose, which
      // would violate Riverpod's lifecycle rules.
      _flushCoSeenRelationships(persistOnly: true);
      _store?.flush();
    });

    // Initialize: load from storage and sync with current nodes.
    _init();

    return {};
  }

  Duration get _encounterCooldown => _defaultEncounterCooldown;
  Duration get _coSeenFlushInterval => _defaultCoSeenFlushInterval;

  Future<void> _init() async {
    if (_store == null) return;

    try {
      AppLogging.nodeDex('Initializing — loading entries from storage');
      final entries = await _store!.loadAllAsMap();
      if (!ref.mounted) return;

      state = entries;
      _lastKnownState = entries;

      AppLogging.nodeDex('Loaded ${entries.length} entries from storage');

      // Sync with current nodes to pick up any that were discovered
      // while NodeDex was not loaded.
      final currentNodes = ref.read(nodesProvider);
      if (currentNodes.isNotEmpty) {
        _handleNodesUpdate({}, currentNodes);
      }

      // Start periodic co-seen relationship flush.
      _coSeenTimer?.cancel();
      _coSeenTimer = Timer.periodic(_coSeenFlushInterval, (_) {
        if (ref.mounted) {
          _flushCoSeenRelationships();
        }
      });

      AppLogging.nodeDex(
        'Init complete — ${entries.length} entries, '
        'co-seen flush interval: ${_coSeenFlushInterval.inSeconds}s',
      );
    } catch (e, stack) {
      AppLogging.nodeDex('Error initializing: $e');
      AppLogging.storage('NodeDex: Error initializing: $e\n$stack');
    }
  }

  /// Handle node updates from the Meshtastic protocol layer.
  ///
  /// Creates new entries for newly discovered nodes and updates
  /// encounter records for re-seen nodes.
  void _handleNodesUpdate(
    Map<int, MeshNode> previous,
    Map<int, MeshNode> current,
  ) {
    if (_store == null) return;

    final myNodeNum = ref.read(myNodeNumProvider);
    final updated = Map<int, NodeDexEntry>.from(state);
    var changed = false;

    for (final entry in current.entries) {
      final nodeNum = entry.key;
      final node = entry.value;

      // Skip nodes with nodeNum 0 (invalid).
      if (nodeNum == 0) continue;

      // Own node gets a NodeDex entry (so it appears in "Your Device"
      // section and has a correct sigil), but we skip encounter counting
      // and co-seen tracking — you're always with your own device so
      // those metrics are meaningless and would pollute the graph.
      // When the user switches to a different device, the previous
      // device naturally moves to "Discovered Nodes" because
      // myNodeNumProvider changes to the newly connected device.
      final isOwnNode = nodeNum == myNodeNum;

      final existing = updated[nodeNum];
      final now = clock.now();

      // Resolve a meaningful display name from the live node data.
      // Only cache non-hex names (longName/shortName set by the user
      // or firmware, not the fallback "!AABBCCDD" format).
      final String? liveName = _resolveCacheableName(node);

      if (existing == null) {
        // New discovery: create a fresh NodeDex entry.
        final sigil = SigilGenerator.generate(nodeNum);
        final newEntry = NodeDexEntry.discovered(
          nodeNum: nodeNum,
          timestamp: node.firstHeard ?? now,
          distance: isOwnNode ? null : node.distance,
          snr: isOwnNode ? null : node.snr,
          rssi: isOwnNode ? null : node.rssi,
          latitude: node.hasPosition ? node.latitude : null,
          longitude: node.hasPosition ? node.longitude : null,
          sigil: sigil,
          lastKnownName: liveName,
          lastKnownHardware: node.hardwareModel,
          lastKnownRole: node.role,
          lastKnownFirmware: node.firmwareVersion,
        );

        // Add region if we can determine one.
        final withRegion = _addRegionFromNode(newEntry, node);
        updated[nodeNum] = withRegion;

        // Only track encounters and co-seen for other nodes.
        if (!isOwnNode) {
          _lastEncounterTime[nodeNum] = now;
          _sessionSeenNodes.add(nodeNum);
        }
        changed = true;

        final hexId =
            '!${nodeNum.toRadixString(16).toUpperCase().padLeft(4, '0')}';
        AppLogging.nodeDex(
          '${isOwnNode ? "Own device added" : "New discovery"}: '
          '$hexId (${node.displayName}), '
          'SNR: ${node.snr ?? "n/a"}, '
          'distance: ${node.distance != null ? "${node.distance!.round()}m" : "n/a"}',
        );
      } else if (isOwnNode) {
        // Own node already exists — update position/region and name,
        // skip encounter counting entirely.
        var updatedEntry = existing;

        // Ensure sigil is generated if missing (e.g., from older data).
        if (updatedEntry.sigil == null) {
          updatedEntry = updatedEntry.copyWith(
            sigil: SigilGenerator.generate(nodeNum),
          );
        }

        // Update cached name if the live node has a better one.
        if (liveName != null && liveName != updatedEntry.lastKnownName) {
          updatedEntry = updatedEntry.copyWith(lastKnownName: liveName);
        }

        // Cache device info from live node data.
        updatedEntry = _updateDeviceInfo(updatedEntry, node);

        // Update region data (own device can change location).
        final withRegion = _addRegionFromNode(updatedEntry, node);
        if (withRegion != existing) {
          updated[nodeNum] = withRegion;
          changed = true;
        }
      } else {
        // Existing node: check if we should record a new encounter.
        final lastEncounter = _lastEncounterTime[nodeNum];
        final shouldRecord =
            lastEncounter == null ||
            now.difference(lastEncounter) >= _encounterCooldown;

        if (shouldRecord) {
          var updatedEntry = existing.recordEncounter(
            timestamp: now,
            distance: node.distance,
            snr: node.snr,
            rssi: node.rssi,
            latitude: node.hasPosition ? node.latitude : null,
            longitude: node.hasPosition ? node.longitude : null,
          );

          // Ensure sigil is generated if missing (e.g., from older data).
          if (updatedEntry.sigil == null) {
            updatedEntry = updatedEntry.copyWith(
              sigil: SigilGenerator.generate(nodeNum),
            );
          }

          // Update cached name if the live node has a better one.
          if (liveName != null && liveName != updatedEntry.lastKnownName) {
            updatedEntry = updatedEntry.copyWith(lastKnownName: liveName);
          }

          // Cache device info from live node data.
          updatedEntry = _updateDeviceInfo(updatedEntry, node);

          // Update region data.
          updatedEntry = _addRegionFromNode(updatedEntry, node);

          updated[nodeNum] = updatedEntry;
          _lastEncounterTime[nodeNum] = now;
          _sessionSeenNodes.add(nodeNum);
          changed = true;

          final hexId =
              '!${nodeNum.toRadixString(16).toUpperCase().padLeft(4, '0')}';
          AppLogging.nodeDex(
            'Encounter recorded: $hexId, '
            'total encounters: ${updatedEntry.encounterCount}, '
            'SNR: ${node.snr ?? "n/a"}, RSSI: ${node.rssi ?? "n/a"}',
          );
        }
      }
    }

    if (changed) {
      state = updated;
      _lastKnownState = updated;
      // Persist changed entries.
      final changedEntries = <NodeDexEntry>[];
      for (final nodeNum in current.keys) {
        final entry = updated[nodeNum];
        if (entry != null) {
          changedEntries.add(entry);
        }
      }
      if (changedEntries.isNotEmpty) {
        _store!.saveEntries(changedEntries);
        AppLogging.nodeDex(
          'Nodes update persisted: ${changedEntries.length} entries saved, '
          'total in state: ${updated.length}, '
          'session seen: ${_sessionSeenNodes.length}',
        );
      }
    }
  }

  /// Resolve a cacheable display name from a live MeshNode.
  /// Update cached device info (hardware model, role, firmware) from
  /// the live [MeshNode] data. Only overwrites existing values when
  /// the live node provides non-null data.
  NodeDexEntry _updateDeviceInfo(NodeDexEntry entry, MeshNode node) {
    final hw = node.hardwareModel;
    final role = node.role;
    final fw = node.firmwareVersion;

    // Only copyWith when there's actually new data to cache.
    final needsHw = hw != null && hw != entry.lastKnownHardware;
    final needsRole = role != null && role != entry.lastKnownRole;
    final needsFw = fw != null && fw != entry.lastKnownFirmware;

    if (!needsHw && !needsRole && !needsFw) return entry;

    return entry.copyWith(
      lastKnownHardware: needsHw ? hw : null,
      lastKnownRole: needsRole ? role : null,
      lastKnownFirmware: needsFw ? fw : null,
    );
  }

  ///
  /// Returns null if the node only has a placeholder name (hex ID,
  /// firmware default like "Meshtastic 2d94", or BLE advertising
  /// name) which is derivable from the nodeNum and not worth caching.
  /// Returns the longName or shortName only when it is a genuine
  /// user-configured or firmware-assigned name.
  String? _resolveCacheableName(MeshNode node) {
    // Use the centralized resolver to filter out all placeholder
    // patterns (hex IDs, firmware defaults, BLE names, etc.).
    final sanitizedLong = NodeDisplayNameResolver.sanitizeName(node.longName);
    if (sanitizedLong != null) return sanitizedLong;
    final sanitizedShort = NodeDisplayNameResolver.sanitizeName(node.shortName);
    if (sanitizedShort != null) return sanitizedShort;
    return null;
  }

  /// Add region information to an entry based on node data.
  ///
  /// Uses position-derived geohash prefix when available, or falls
  /// back to the LoRa region code from device configuration.
  NodeDexEntry _addRegionFromNode(NodeDexEntry entry, MeshNode node) {
    if (node.hasPosition && node.latitude != null && node.longitude != null) {
      // Use a coarse geohash (3-char precision = ~78km cells) as region ID.
      final regionId = _coarseGeohash(node.latitude!, node.longitude!);
      final label = _regionLabel(node.latitude!, node.longitude!);
      return entry.addRegion(regionId, label);
    }
    return entry;
  }

  /// Generate a coarse geohash-like region identifier.
  ///
  /// Uses a simple grid-based approach rather than full geohash
  /// to keep the implementation lightweight. Each cell is roughly
  /// 1 degree x 1 degree (~111km at the equator).
  String _coarseGeohash(double lat, double lon) {
    // Round to 1-degree grid.
    final latGrid = lat.floor();
    final lonGrid = lon.floor();
    return 'g${latGrid}_$lonGrid';
  }

  /// Generate a human-readable region label from coordinates.
  ///
  /// Uses cardinal direction and degree range for now.
  /// A future version could use reverse geocoding.
  String _regionLabel(double lat, double lon) {
    final ns = lat >= 0 ? 'N' : 'S';
    final ew = lon >= 0 ? 'E' : 'W';
    final latDeg = lat.abs().floor();
    final lonDeg = lon.abs().floor();
    return '$latDeg\u00B0$ns $lonDeg\u00B0$ew';
  }

  /// Flush co-seen relationships for all nodes seen this session.
  ///
  /// For each pair of nodes seen in this session, increments their
  /// co-seen counter. This powers the constellation visualization.
  /// Flush co-seen relationships to state and storage.
  ///
  /// When [persistOnly] is true (e.g. during dispose), the method writes
  /// directly to the store without setting [state], which would violate
  /// Riverpod's lifecycle rules. During normal periodic flushes,
  /// [persistOnly] is false and both state and storage are updated.
  void _flushCoSeenRelationships({bool persistOnly = false}) {
    if (_sessionSeenNodes.length < 2) return;

    AppLogging.nodeDex(
      'Flushing co-seen relationships for ${_sessionSeenNodes.length} nodes '
      '(persistOnly: $persistOnly)',
    );

    // During dispose (persistOnly), reading `state` is forbidden by Riverpod.
    // Use the store's last-known cache instead so we can still persist
    // relationships that were accumulated during this session.
    final Map<int, NodeDexEntry> source;
    if (persistOnly) {
      // _lastKnownState is snapshotted whenever state is set normally.
      if (_lastKnownState == null || _lastKnownState!.isEmpty) {
        _sessionSeenNodes.clear();
        return;
      }
      source = _lastKnownState!;
    } else {
      source = state;
    }

    final nodeList = _sessionSeenNodes.toList();
    final updated = Map<int, NodeDexEntry>.from(source);
    var changed = false;

    for (int i = 0; i < nodeList.length; i++) {
      for (int j = i + 1; j < nodeList.length; j++) {
        final a = nodeList[i];
        final b = nodeList[j];

        final entryA = updated[a];
        final entryB = updated[b];

        if (entryA != null) {
          updated[a] = entryA.addCoSeen(b);
          changed = true;
        }
        if (entryB != null) {
          updated[b] = entryB.addCoSeen(a);
          changed = true;
        }
      }
    }

    if (changed) {
      final pairCount = (nodeList.length * (nodeList.length - 1)) ~/ 2;
      AppLogging.nodeDex(
        'Co-seen flush complete: $pairCount pairs processed '
        'across ${nodeList.length} nodes',
      );
      if (!persistOnly) {
        state = updated;
        _lastKnownState = updated;
      }
      _store?.saveEntries(updated.values.toList());
    }

    // Clear session tracking for the next interval.
    _sessionSeenNodes.clear();
  }

  // ---------------------------------------------------------------------------
  // Public mutation methods
  // ---------------------------------------------------------------------------

  /// Set the social tag for a node.
  void setSocialTag(int nodeNum, NodeSocialTag? tag) {
    final entry = state[nodeNum];
    if (entry == null) {
      AppLogging.nodeDex(
        'setSocialTag failed — node $nodeNum not found in state',
      );
      return;
    }

    final previousTag = entry.socialTag?.name ?? 'none';
    final newTag = tag?.name ?? 'cleared';

    final updated = tag != null
        ? entry.copyWith(socialTag: tag)
        : entry.copyWith(clearSocialTag: true);

    final newState = {...state, nodeNum: updated};
    state = newState;
    _lastKnownState = newState;
    _store?.saveEntry(updated);

    final hexId = '!${nodeNum.toRadixString(16).toUpperCase().padLeft(4, '0')}';
    AppLogging.nodeDex('Social tag updated for $hexId: $previousTag → $newTag');

    // Push to cloud immediately so user mutations are not lost if the
    // app is closed or the user signs out before the periodic cycle.
    _triggerImmediateSync();
  }

  /// Set the user note for a node.
  void setUserNote(int nodeNum, String? note) {
    final entry = state[nodeNum];
    if (entry == null) {
      AppLogging.nodeDex(
        'setUserNote failed — node $nodeNum not found in state',
      );
      return;
    }

    final trimmed = note?.trim();
    final updated = (trimmed == null || trimmed.isEmpty)
        ? entry.copyWith(clearUserNote: true)
        : entry.copyWith(
            userNote: trimmed.length > 280
                ? trimmed.substring(0, 280)
                : trimmed,
          );

    final newState = {...state, nodeNum: updated};
    state = newState;
    _lastKnownState = newState;
    _store?.saveEntry(updated);

    final hexId = '!${nodeNum.toRadixString(16).toUpperCase().padLeft(4, '0')}';
    AppLogging.nodeDex(
      'User note updated for $hexId: '
      '${(trimmed == null || trimmed.isEmpty) ? "(cleared)" : "${trimmed.length} chars"}',
    );

    // Push to cloud immediately so user mutations are not lost if the
    // app is closed or the user signs out before the periodic cycle.
    _triggerImmediateSync();
  }

  /// Set a local nickname for a node.
  ///
  /// The nickname overrides all other name resolution sources (live mesh
  /// name, cached name, hex fallback). Pass null or empty to clear.
  /// Capped at 40 characters.
  void setLocalNickname(int nodeNum, String? nickname) {
    final entry = state[nodeNum];
    if (entry == null) {
      AppLogging.nodeDex(
        'setLocalNickname failed — node $nodeNum not found in state',
      );
      return;
    }

    final trimmed = nickname?.trim();
    final updated = (trimmed == null || trimmed.isEmpty)
        ? entry.copyWith(clearLocalNickname: true)
        : entry.copyWith(
            localNickname: trimmed.length > 40
                ? trimmed.substring(0, 40)
                : trimmed,
          );

    final newState = {...state, nodeNum: updated};
    state = newState;
    _lastKnownState = newState;
    _store?.saveEntry(updated);

    final hexId = '!${nodeNum.toRadixString(16).toUpperCase().padLeft(4, '0')}';
    AppLogging.nodeDex(
      'Local nickname updated for $hexId: '
      '${(trimmed == null || trimmed.isEmpty) ? "(cleared)" : '"$trimmed"'}',
    );

    _triggerImmediateSync();
  }

  // ---------------------------------------------------------------------------
  // Cloud sync helpers
  // ---------------------------------------------------------------------------

  /// Reload the notifier's in-memory state from the SQLite store.
  ///
  /// Called after the sync service pulls remote changes so the UI
  /// reflects data that was merged into SQLite by [applySyncPull].
  Future<void> _reloadFromStore() async {
    if (_store == null) return;

    try {
      final entries = await _store!.loadAllAsMap();
      if (!ref.mounted) return;

      state = entries;
      _lastKnownState = entries;
      AppLogging.nodeDex(
        'Reloaded ${entries.length} entries from store after sync pull',
      );
    } catch (e) {
      AppLogging.nodeDex('Error reloading from store after sync pull: $e');
    }
  }

  /// Flush pending saves to SQLite and drain the outbox immediately.
  ///
  /// This ensures user-initiated mutations (social tag, notes) reach
  /// Firestore promptly rather than waiting for the 2-minute periodic
  /// sync cycle. Without this, data is silently lost if the user signs
  /// out or closes the app before the next cycle.
  void _triggerImmediateSync() {
    if (_store == null) return;

    // Read the sync service once — do not watch (this is a callback,
    // not a build method).
    final syncService = ref.read(nodeDexSyncServiceProvider);
    if (syncService == null || !syncService.isEnabled) return;

    // Fire-and-forget: flush debounced saves then drain outbox.
    unawaited(_doImmediateSync(syncService));
  }

  Future<void> _doImmediateSync(NodeDexSyncService syncService) async {
    try {
      // Flush ensures the outbox entry exists in SQLite.
      await _store!.flush();
      // Drain pushes it to Firestore.
      await syncService.drainOutboxNow();
    } catch (e) {
      AppLogging.nodeDex('Immediate sync after mutation failed: $e');
    }
  }

  /// Increment the message count for a node and its co-seen edges.
  ///
  /// In addition to incrementing the node's own message count, this
  /// also increments [CoSeenRelationship.messageCount] for every
  /// co-seen relationship between this node and other nodes that are
  /// currently active in the session. This ensures per-edge message
  /// counts accumulate naturally as messages flow between nodes that
  /// are co-present on the mesh.
  void recordMessage(int nodeNum, {int count = 1}) {
    final entry = state[nodeNum];
    if (entry == null) return;

    AppLogging.nodeDex(
      'Recording $count message(s) for node $nodeNum, '
      'previous total: ${entry.messageCount}',
    );

    var updated = entry.incrementMessages(by: count);

    // Increment per-edge message counts for all session peers that
    // have an existing co-seen relationship with this node.
    if (_sessionSeenNodes.contains(nodeNum)) {
      for (final peerNum in _sessionSeenNodes) {
        if (peerNum == nodeNum) continue;
        // Only increment if the relationship already exists — we do not
        // create new co-seen relationships from message activity alone.
        if (updated.coSeenNodes.containsKey(peerNum)) {
          updated = updated.incrementCoSeenMessages(peerNum, by: count);
        }
      }
    }

    final newState = {...state, nodeNum: updated};
    state = newState;
    _lastKnownState = newState;
    _store?.saveEntry(updated);

    final hexId = '!${nodeNum.toRadixString(16).toUpperCase().padLeft(4, '0')}';
    AppLogging.nodeDex(
      'Message count updated for $hexId: ${updated.messageCount} total',
    );
  }

  /// Force a refresh from storage.
  Future<void> refresh() async {
    if (_store == null) return;

    AppLogging.nodeDex('Refreshing entries from storage');

    try {
      final entries = await _store!.loadAllAsMap();
      if (!ref.mounted) return;
      state = entries;
      _lastKnownState = entries;

      AppLogging.nodeDex('Refresh complete — ${entries.length} entries loaded');
    } catch (e) {
      AppLogging.nodeDex('Error refreshing: $e');
      AppLogging.storage('NodeDex: Error refreshing: $e');
    }
  }

  /// Clear all NodeDex data.
  Future<void> clearAll() async {
    AppLogging.nodeDex('Clearing all NodeDex data (${state.length} entries)');
    state = {};
    _lastKnownState = {};
    _sessionSeenNodes.clear();
    _lastEncounterTime.clear();
    await _store?.clearAll();
    AppLogging.nodeDex('All NodeDex data cleared');
  }

  /// Export all entries as JSON.
  Future<String?> exportJson() async {
    AppLogging.nodeDex('Exporting ${state.length} entries as JSON');
    final json = await _store?.exportJson();
    AppLogging.nodeDex(
      'Export complete: ${json != null ? "${json.length} chars" : "failed"}',
    );
    return json;
  }

  /// Import entries from JSON.
  Future<int> importJson(String jsonString) async {
    AppLogging.nodeDex(
      'Importing entries from JSON (${jsonString.length} chars)',
    );
    final count = await _store?.importJson(jsonString) ?? 0;
    if (count > 0) {
      await refresh();
    }
    AppLogging.nodeDex('Import complete — $count entries imported');
    return count;
  }

  /// Parse a JSON import string without modifying state.
  ///
  /// Returns an empty list on invalid input.
  List<NodeDexEntry> parseImportJson(String jsonString) {
    return _store?.parseImportJson(jsonString) ?? [];
  }

  /// Build an [ImportPreview] by analyzing the given entries against
  /// the current local state.
  ///
  /// Uses live [nodesProvider] data to resolve display names.
  /// Does not modify any state.
  Future<ImportPreview> previewImport(List<NodeDexEntry> entries) async {
    if (_store == null) {
      return const ImportPreview(entries: [], totalImported: 0);
    }

    final nodes = ref.read(nodesProvider);
    String nameResolver(int nodeNum) {
      final node = nodes[nodeNum];
      if (node != null) return node.displayName;
      // Fall back to cached name from NodeDex entry.
      final entry = state[nodeNum];
      if (entry?.lastKnownName != null) return entry!.lastKnownName!;
      return NodeDisplayNameResolver.defaultName(nodeNum);
    }

    return _store!.previewImport(entries, displayNameResolver: nameResolver);
  }

  /// Apply an import using a specific [MergeStrategy] and optional
  /// per-entry [ConflictResolution] overrides.
  ///
  /// Returns the number of entries that were added or updated.
  Future<int> importWithStrategy({
    required ImportPreview preview,
    required MergeStrategy strategy,
    Map<int, ConflictResolution> resolutions = const {},
  }) async {
    if (_store == null) return 0;

    AppLogging.nodeDex(
      'Importing with strategy: ${strategy.name}, '
      '${preview.entries.length} entries to process, '
      '${resolutions.length} custom resolutions',
    );

    final count = await _store!.importWithMerge(
      preview: preview,
      strategy: strategy,
      resolutions: resolutions,
    );

    if (count > 0) {
      await refresh();
    }

    AppLogging.nodeDex(
      'Strategy import complete — $count entries added/updated',
    );
    return count;
  }
}

final nodeDexProvider =
    NotifierProvider<NodeDexNotifier, Map<int, NodeDexEntry>>(
      NodeDexNotifier.new,
    );

// =============================================================================
// Derived Providers
// =============================================================================

/// Provider for a single NodeDex entry by node number.
///
/// Returns null if the node has not been discovered yet.
final nodeDexEntryProvider = Provider.family<NodeDexEntry?, int>((
  ref,
  nodeNum,
) {
  final entries = ref.watch(nodeDexProvider);
  return entries[nodeNum];
});

/// Provider for the computed trait of a specific node.
///
/// Combines NodeDex encounter history with live MeshNode telemetry
/// to produce a trait classification.
final nodeDexTraitProvider = Provider.family<TraitResult, int>((ref, nodeNum) {
  final entry = ref.watch(nodeDexEntryProvider(nodeNum));
  if (entry == null) {
    return const TraitResult(primary: NodeTrait.unknown, confidence: 1.0);
  }

  // Get live telemetry from the nodes provider for richer inference.
  final nodes = ref.watch(nodesProvider);
  final node = nodes[nodeNum];

  return TraitEngine.infer(
    entry: entry,
    role: node?.role,
    uptimeSeconds: node?.uptimeSeconds,
    channelUtilization: node?.channelUtilization,
    airUtilTx: node?.airUtilTx,
  );
});

/// Provider for the full ranked trait list with evidence for a node.
///
/// Returns 3–7 [ScoredTrait] entries sorted by descending confidence,
/// each with evidence lines explaining the score. Used by the field
/// journal detail view to show "why this trait" information.
final nodeDexScoredTraitsProvider = Provider.family<List<ScoredTrait>, int>((
  ref,
  nodeNum,
) {
  final entry = ref.watch(nodeDexEntryProvider(nodeNum));
  if (entry == null) {
    return const [
      ScoredTrait(
        trait: NodeTrait.unknown,
        confidence: 1.0,
        evidence: [
          TraitEvidence(observation: 'Node not found in NodeDex', weight: 1.0),
        ],
      ),
    ];
  }

  final nodes = ref.watch(nodesProvider);
  final node = nodes[nodeNum];

  return TraitEngine.inferAll(
    entry: entry,
    role: node?.role,
    uptimeSeconds: node?.uptimeSeconds,
    channelUtilization: node?.channelUtilization,
    airUtilTx: node?.airUtilTx,
  );
});

/// Provider for the patina score of a specific node.
///
/// Computes the 0–100 digital history score from six orthogonal
/// axes: tenure, encounters, reach, signal depth, social, and recency.
final nodeDexPatinaProvider = Provider.family<PatinaResult, int>((
  ref,
  nodeNum,
) {
  final entry = ref.watch(nodeDexEntryProvider(nodeNum));
  if (entry == null) {
    return const PatinaResult(
      score: 0,
      tenure: 0,
      encounters: 0,
      reach: 0,
      signalDepth: 0,
      social: 0,
      recency: 0,
      stampLabel: 'Trace',
    );
  }
  return PatinaScore.compute(entry);
});

/// Provider for the computed trust level of a specific node.
///
/// Combines encounter frequency, node age, message count, relay role,
/// and recency into a single trust classification. Only meaningful
/// at disclosure tier 1+ (>= 2 encounters, >= 1 hour age).
final nodeDexTrustProvider = Provider.family<TrustResult, int>((ref, nodeNum) {
  final entry = ref.watch(nodeDexEntryProvider(nodeNum));
  if (entry == null) {
    return const TrustResult(
      score: 0,
      level: TrustLevel.unknown,
      frequentlySeen: 0,
      longLived: 0,
      directContact: 0,
      relayUsefulness: 0,
      networkPresence: 0,
    );
  }

  // Use live role from mesh node when available.
  final nodes = ref.watch(nodesProvider);
  final node = nodes[nodeNum];

  return TrustScore.compute(entry, role: node?.role);
});

/// Provider for the progressive disclosure state of a specific node.
///
/// Determines which field journal elements are visible based on
/// the node's accumulated history. Controls overlay density,
/// trait evidence visibility, field note display, and more.
final nodeDexDisclosureProvider = Provider.family<DisclosureState, int>((
  ref,
  nodeNum,
) {
  final entry = ref.watch(nodeDexEntryProvider(nodeNum));
  if (entry == null) {
    return const DisclosureState(
      showSigil: true,
      showPrimaryTrait: false,
      showTraitEvidence: false,
      showFieldNote: false,
      showAllTraits: false,
      showPatinaStamp: false,
      showTimeline: false,
      showOverlay: false,
      overlayDensity: 0,
      tier: DisclosureTier.trace,
    );
  }
  return ProgressiveDisclosure.compute(entry);
});

/// Provider for the deterministic field note of a specific node.
///
/// Returns the auto-generated field journal observation text.
/// The note is deterministic: same node + same trait = same note.
final nodeDexFieldNoteProvider = Provider.family<String, int>((ref, nodeNum) {
  final entry = ref.watch(nodeDexEntryProvider(nodeNum));
  if (entry == null) return '';

  final trait = ref.watch(nodeDexTraitProvider(nodeNum));
  return FieldNoteGenerator.generate(entry: entry, trait: trait.primary);
});

// =============================================================================
// Node Summary Provider
// =============================================================================

/// Computed summary insights for a specific node.
///
/// Returns a deterministic [NodeSummary] derived from the node's
/// encounter history. Same entry always produces the same summary.
final nodeSummaryProvider = Provider.family<NodeSummary, int>((ref, nodeNum) {
  final entry = ref.watch(nodeDexEntryProvider(nodeNum));
  if (entry == null) {
    return NodeSummary(
      timeDistribution: {for (final b in TimeOfDayBucket.values) b: 0},
      currentStreak: 0,
      totalEncounters: 0,
      summaryText: 'Keep observing to build a profile',
      activeDaysLast14: 0,
    );
  }
  return NodeSummaryEngine.compute(entry);
});

// =============================================================================
// Node Activity Timeline Provider
// =============================================================================

/// Aggregates all observable events for a single node into a unified
/// chronological feed sorted by timestamp descending.
///
/// Data sources:
///   - Encounter records (SQLite via NodeDexEntry)
///   - Messages to/from the node (in-memory via messagesProvider)
///   - Presence transitions (SQLite via presence_transitions table)
///   - Signals from the node (in-memory via signalsFromNodeProvider)
///   - First-seen milestone (NodeDexEntry.firstSeen)
///
/// Returns the complete event list. Pagination (how many events to
/// reveal at once) is handled on the widget side via display count.
final nodeActivityTimelineProvider =
    FutureProvider.family<List<NodeActivityEvent>, int>((ref, nodeNum) async {
      return _buildTimeline(ref, nodeNum);
    });

/// Maximum gap between consecutive encounters before a new session starts.
const Duration _kSessionGap = Duration(minutes: 30);

/// Groups consecutive [EncounterRecord]s into session-level events.
///
/// Encounters separated by less than [_kSessionGap] are merged into a
/// single [EncounterActivityEvent] whose [timestamp] is the newest
/// encounter, [sessionStart] is the oldest, and metric fields hold the
/// best values from the session.
List<EncounterActivityEvent> _groupEncounters(List<EncounterRecord> records) {
  if (records.isEmpty) return const [];

  // Sort ascending (oldest first) so we can iterate forward.
  final sorted = records.toList()
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

  final sessions = <EncounterActivityEvent>[];
  var sessionRecords = <EncounterRecord>[sorted.first];

  for (int i = 1; i < sorted.length; i++) {
    final gap = sorted[i].timestamp.difference(sessionRecords.last.timestamp);
    if (gap <= _kSessionGap) {
      sessionRecords.add(sorted[i]);
    } else {
      sessions.add(_collapseSession(sessionRecords));
      sessionRecords = [sorted[i]];
    }
  }
  sessions.add(_collapseSession(sessionRecords));
  return sessions;
}

EncounterActivityEvent _collapseSession(List<EncounterRecord> records) {
  assert(records.isNotEmpty);

  // Latest encounter = timestamp (sorts newest-first in the timeline).
  final newest = records.last;
  final oldest = records.first;

  // Best metrics across the session.
  double? bestDistance;
  int? bestSnr;
  int? bestRssi;

  for (final r in records) {
    if (r.distanceMeters != null) {
      if (bestDistance == null || r.distanceMeters! < bestDistance) {
        bestDistance = r.distanceMeters;
      }
    }
    if (r.snr != null) {
      if (bestSnr == null || r.snr! > bestSnr) {
        bestSnr = r.snr;
      }
    }
    if (r.rssi != null) {
      if (bestRssi == null || r.rssi! > bestRssi) {
        bestRssi = r.rssi;
      }
    }
  }

  return EncounterActivityEvent(
    timestamp: newest.timestamp,
    sessionStart: oldest.timestamp,
    count: records.length,
    distanceMeters: bestDistance,
    snr: bestSnr,
    rssi: bestRssi,
    latitude: newest.latitude,
    longitude: newest.longitude,
  );
}

Future<List<NodeActivityEvent>> _buildTimeline(Ref ref, int nodeNum) async {
  final events = <NodeActivityEvent>[];

  // Watch all reactive in-memory sources before the async gap so that
  // the provider recomputes when underlying data changes.
  final entry = ref.watch(nodeDexEntryProvider(nodeNum));
  final myNodeNum = ref.watch(myNodeNumProvider);
  final messages = ref.watch(messagesProvider);
  final signals = ref.watch(signalsFromNodeProvider(nodeNum));
  final storeAsync = ref.watch(nodeDexStoreProvider);

  // 1. Encounters from the NodeDex entry — grouped into sessions.
  if (entry != null) {
    events.addAll(_groupEncounters(entry.encounters));

    // 2. First-seen milestone.
    events.add(
      MilestoneActivityEvent(
        timestamp: entry.firstSeen,
        kind: MilestoneKind.firstSeen,
        label: 'First discovered',
      ),
    );

    // Encounter count milestones.
    for (final m in [10, 25, 50, 100, 250, 500, 1000]) {
      if (entry.encounterCount >= m && entry.encounters.length >= m) {
        final milestone = entry.encounters[m - 1];
        events.add(
          MilestoneActivityEvent(
            timestamp: milestone.timestamp,
            kind: MilestoneKind.encounterMilestone,
            label: 'Encounter #$m',
          ),
        );
      }
    }
  }

  // 3. Messages to/from this node.
  for (final msg in messages) {
    if (msg.from == nodeNum || msg.to == nodeNum) {
      events.add(
        MessageActivityEvent(
          timestamp: msg.timestamp,
          text: msg.text,
          outgoing: msg.from == myNodeNum,
          channel: msg.channel,
        ),
      );
    }
  }

  // 4. Signals from this node.
  for (final signal in signals) {
    events.add(
      SignalActivityEvent(
        timestamp: signal.createdAt,
        content: signal.content,
        signalId: signal.id,
      ),
    );
  }

  // 5. Presence transitions from SQLite.
  final store = storeAsync.asData?.value;
  if (store != null) {
    final rows = await store.loadPresenceTransitions(nodeNum: nodeNum);
    for (final row in rows) {
      final fromName = row[NodeDexTables.colPtFromState] as String;
      final toName = row[NodeDexTables.colPtToState] as String;
      final tsMs = row[NodeDexTables.colPtTsMs] as int;

      final from = PresenceConfidence.values.firstWhere(
        (e) => e.name == fromName,
        orElse: () => PresenceConfidence.unknown,
      );
      final to = PresenceConfidence.values.firstWhere(
        (e) => e.name == toName,
        orElse: () => PresenceConfidence.unknown,
      );

      events.add(
        PresenceChangeActivityEvent(
          timestamp: DateTime.fromMillisecondsSinceEpoch(tsMs),
          fromState: from,
          toState: to,
        ),
      );
    }
  }

  // Sort descending by timestamp.
  events.sort();
  return events;
}

/// Aggregate statistics across all NodeDex entries.
///
/// Recomputed whenever entries change. Used for the stats header
/// on the main NodeDex screen and for explorer title derivation.
final nodeDexStatsProvider = Provider<NodeDexStats>((ref) {
  final entries = ref.watch(nodeDexProvider);
  if (entries.isEmpty) {
    return const NodeDexStats();
  }

  final allEntries = entries.values.toList();

  // Compute aggregate stats.
  double? longestDistance;
  int totalEncounters = 0;
  DateTime? oldest;
  DateTime? newest;
  int? bestSnr;
  int? bestRssi;
  final allRegionIds = <String>{};
  final traitCounts = <NodeTrait, int>{};
  final tagCounts = <NodeSocialTag, int>{};

  for (final entry in allEntries) {
    // Distance.
    if (entry.maxDistanceSeen != null) {
      if (longestDistance == null || entry.maxDistanceSeen! > longestDistance) {
        longestDistance = entry.maxDistanceSeen;
      }
    }

    // Encounters.
    totalEncounters += entry.encounterCount;

    // Date range.
    if (oldest == null || entry.firstSeen.isBefore(oldest)) {
      oldest = entry.firstSeen;
    }
    if (newest == null || entry.firstSeen.isAfter(newest)) {
      newest = entry.firstSeen;
    }

    // Best signals.
    if (entry.bestSnr != null) {
      if (bestSnr == null || entry.bestSnr! > bestSnr) {
        bestSnr = entry.bestSnr;
      }
    }
    if (entry.bestRssi != null) {
      if (bestRssi == null || entry.bestRssi! > bestRssi) {
        bestRssi = entry.bestRssi;
      }
    }

    // Regions.
    for (final region in entry.seenRegions) {
      allRegionIds.add(region.regionId);
    }

    // Traits (computed per node).
    final trait = ref.read(nodeDexTraitProvider(entry.nodeNum));
    traitCounts[trait.primary] = (traitCounts[trait.primary] ?? 0) + 1;

    // Social tags.
    if (entry.socialTag != null) {
      tagCounts[entry.socialTag!] = (tagCounts[entry.socialTag!] ?? 0) + 1;
    }
  }

  return NodeDexStats(
    totalNodes: allEntries.length,
    totalRegions: allRegionIds.length,
    longestDistance: longestDistance,
    totalEncounters: totalEncounters,
    oldestDiscovery: oldest,
    newestDiscovery: newest,
    traitDistribution: traitCounts,
    socialTagDistribution: tagCounts,
    bestSnrOverall: bestSnr,
    bestRssiOverall: bestRssi,
  );
});

/// Sorting options for the NodeDex entry list.
enum NodeDexSortOrder {
  /// Most recently seen first.
  lastSeen,

  /// Most recently discovered first.
  firstSeen,

  /// Most encounters first.
  encounters,

  /// Longest distance first.
  distance,

  /// Alphabetical by display name.
  name,
}

/// Filter options for the NodeDex entry list.
enum NodeDexFilter {
  /// Show all entries.
  all,

  /// Only entries with a social tag (any tag).
  tagged,

  /// Only entries classified as Contact.
  tagContact,

  /// Only entries classified as Trusted Node.
  tagTrustedNode,

  /// Only entries classified as Known Relay.
  tagKnownRelay,

  /// Only entries classified as Frequent Peer.
  tagFrequentPeer,

  /// Only recently discovered (last 24h).
  recent,

  /// Only entries with the Wanderer trait.
  wanderers,

  /// Only entries with the Beacon trait.
  beacons,

  /// Only entries with the Ghost trait.
  ghosts,

  /// Only entries with the Sentinel trait.
  sentinels,

  /// Only entries with the Relay trait.
  relays,
}

/// Notifier for the current sort order.
class NodeDexSortNotifier extends Notifier<NodeDexSortOrder> {
  @override
  NodeDexSortOrder build() => NodeDexSortOrder.lastSeen;

  void setOrder(NodeDexSortOrder order) => state = order;
}

final nodeDexSortProvider =
    NotifierProvider<NodeDexSortNotifier, NodeDexSortOrder>(
      NodeDexSortNotifier.new,
    );

/// Notifier for the current filter.
class NodeDexFilterNotifier extends Notifier<NodeDexFilter> {
  @override
  NodeDexFilter build() => NodeDexFilter.all;

  void setFilter(NodeDexFilter filter) => state = filter;
}

final nodeDexFilterProvider =
    NotifierProvider<NodeDexFilterNotifier, NodeDexFilter>(
      NodeDexFilterNotifier.new,
    );

/// Search query for the NodeDex list.
class NodeDexSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
  void clear() => state = '';
}

final nodeDexSearchProvider = NotifierProvider<NodeDexSearchNotifier, String>(
  NodeDexSearchNotifier.new,
);

/// Sorted and filtered list of NodeDex entries for the main screen.
///
/// Combines the entries from nodeDexProvider with the current sort order,
/// filter, and search query. Returns a list of (NodeDexEntry, MeshNode?)
/// pairs so the UI has access to both enriched and live data.
final nodeDexSortedEntriesProvider = Provider<List<(NodeDexEntry, MeshNode?)>>((
  ref,
) {
  final entries = ref.watch(nodeDexProvider);
  final nodes = ref.watch(nodesProvider);
  final sort = ref.watch(nodeDexSortProvider);
  final filter = ref.watch(nodeDexFilterProvider);
  final search = ref.watch(nodeDexSearchProvider).toLowerCase();

  if (entries.isEmpty) return [];

  // Build paired list.
  var paired = entries.values.map((entry) {
    final node = nodes[entry.nodeNum];
    return (entry, node);
  }).toList();

  // Apply filter.
  paired = _applyFilter(paired, filter, ref);

  // Apply search.
  if (search.isNotEmpty) {
    paired = paired.where((pair) {
      final (entry, node) = pair;
      final name = node?.displayName.toLowerCase() ?? '';
      final hexId = entry.nodeNum.toRadixString(16).toLowerCase();
      final note = entry.userNote?.toLowerCase() ?? '';
      final tag = entry.socialTag?.displayLabel.toLowerCase() ?? '';
      return name.contains(search) ||
          hexId.contains(search) ||
          note.contains(search) ||
          tag.contains(search);
    }).toList();
  }

  // Apply sort.
  paired.sort((a, b) {
    final (entryA, nodeA) = a;
    final (entryB, nodeB) = b;

    return switch (sort) {
      NodeDexSortOrder.lastSeen => entryB.lastSeen.compareTo(entryA.lastSeen),
      NodeDexSortOrder.firstSeen => entryB.firstSeen.compareTo(
        entryA.firstSeen,
      ),
      NodeDexSortOrder.encounters => entryB.encounterCount.compareTo(
        entryA.encounterCount,
      ),
      NodeDexSortOrder.distance => _compareDistance(entryA, entryB),
      NodeDexSortOrder.name =>
        (entryA.localNickname ??
                nodeA?.displayName ??
                entryA.lastKnownName ??
                '')
            .compareTo(
              entryB.localNickname ??
                  nodeB?.displayName ??
                  entryB.lastKnownName ??
                  '',
            ),
    };
  });

  return paired;
});

/// Compare two entries by max distance (descending, nulls last).
int _compareDistance(NodeDexEntry a, NodeDexEntry b) {
  if (a.maxDistanceSeen == null && b.maxDistanceSeen == null) return 0;
  if (a.maxDistanceSeen == null) return 1;
  if (b.maxDistanceSeen == null) return -1;
  return b.maxDistanceSeen!.compareTo(a.maxDistanceSeen!);
}

/// Apply the current filter to the entry list.
List<(NodeDexEntry, MeshNode?)> _applyFilter(
  List<(NodeDexEntry, MeshNode?)> entries,
  NodeDexFilter filter,
  Ref ref,
) {
  if (filter == NodeDexFilter.all) return entries;

  return entries.where((pair) {
    final (entry, _) = pair;
    return switch (filter) {
      NodeDexFilter.all => true,
      NodeDexFilter.tagged => entry.socialTag != null,
      NodeDexFilter.tagContact => entry.socialTag == NodeSocialTag.contact,
      NodeDexFilter.tagTrustedNode =>
        entry.socialTag == NodeSocialTag.trustedNode,
      NodeDexFilter.tagKnownRelay =>
        entry.socialTag == NodeSocialTag.knownRelay,
      NodeDexFilter.tagFrequentPeer =>
        entry.socialTag == NodeSocialTag.frequentPeer,
      NodeDexFilter.recent => entry.isRecentlyDiscovered,
      NodeDexFilter.wanderers =>
        ref.read(nodeDexTraitProvider(entry.nodeNum)).primary ==
            NodeTrait.wanderer,
      NodeDexFilter.beacons =>
        ref.read(nodeDexTraitProvider(entry.nodeNum)).primary ==
            NodeTrait.beacon,
      NodeDexFilter.ghosts =>
        ref.read(nodeDexTraitProvider(entry.nodeNum)).primary ==
            NodeTrait.ghost,
      NodeDexFilter.sentinels =>
        ref.read(nodeDexTraitProvider(entry.nodeNum)).primary ==
            NodeTrait.sentinel,
      NodeDexFilter.relays =>
        ref.read(nodeDexTraitProvider(entry.nodeNum)).primary ==
            NodeTrait.relay,
    };
  }).toList();
}

// =============================================================================
// Constellation Provider
// =============================================================================

/// A node in the constellation graph.
class ConstellationNode {
  /// The node number.
  final int nodeNum;

  /// Display name for the node.
  final String displayName;

  /// The sigil data for visual rendering.
  final SigilData? sigil;

  /// The primary trait.
  final NodeTrait trait;

  /// Number of total connections (co-seen relationships).
  final int connectionCount;

  /// X position in the constellation (0.0 to 1.0, deterministic).
  final double x;

  /// Y position in the constellation (0.0 to 1.0, deterministic).
  final double y;

  const ConstellationNode({
    required this.nodeNum,
    required this.displayName,
    this.sigil,
    required this.trait,
    required this.connectionCount,
    required this.x,
    required this.y,
  });
}

/// An edge in the constellation graph.
class ConstellationEdge {
  /// Source node number.
  final int from;

  /// Target node number.
  final int to;

  /// Weight (co-seen count) — higher means stronger connection.
  final int weight;

  /// When this co-seen relationship was first recorded.
  final DateTime? firstSeen;

  /// When this co-seen relationship was most recently recorded.
  final DateTime? lastSeen;

  /// Number of messages exchanged while both nodes were co-seen.
  final int messageCount;

  const ConstellationEdge({
    required this.from,
    required this.to,
    required this.weight,
    this.firstSeen,
    this.lastSeen,
    this.messageCount = 0,
  });

  /// Duration of the relationship from first to last sighting.
  Duration? get relationshipAge {
    if (firstSeen == null || lastSeen == null) return null;
    return lastSeen!.difference(firstSeen!);
  }

  /// Time since the last co-sighting.
  Duration? get timeSinceLastSeen {
    if (lastSeen == null) return null;
    return DateTime.now().difference(lastSeen!);
  }
}

/// The complete constellation graph data.
class ConstellationData {
  /// All nodes in the constellation.
  final List<ConstellationNode> nodes;

  /// All edges (connections) between nodes.
  final List<ConstellationEdge> edges;

  /// Maximum edge weight for normalization.
  final int maxWeight;

  /// Sorted edge weights for percentile lookups.
  final List<int> _sortedWeights;

  ConstellationData({
    this.nodes = const [],
    this.edges = const [],
    this.maxWeight = 1,
  }) : _sortedWeights = edges.map((e) => e.weight).toList()..sort();

  bool get isEmpty => nodes.isEmpty;
  int get nodeCount => nodes.length;
  int get edgeCount => edges.length;

  /// Returns the edge weight at the given percentile (0.0–1.0).
  ///
  /// For example, `weightAtPercentile(0.75)` returns the weight value
  /// below which 75% of edges fall. Used for edge density filtering.
  int weightAtPercentile(double percentile) {
    if (_sortedWeights.isEmpty) return 0;
    final index = (percentile * (_sortedWeights.length - 1)).round();
    return _sortedWeights[index.clamp(0, _sortedWeights.length - 1)];
  }

  /// Median edge weight — the natural threshold for "significant" edges.
  int get medianWeight => weightAtPercentile(0.5);
}

/// Provider for the constellation graph data.
///
/// Builds a force-directed layout where strongly-connected nodes cluster
/// together. The layout is deterministic — seeded from node number hashes
/// and then refined through force simulation. Edge weight statistics are
/// computed for UI-side density filtering.
final nodeDexConstellationProvider = Provider<ConstellationData>((ref) {
  final entries = ref.watch(nodeDexProvider);
  final nodes = ref.watch(nodesProvider);

  if (entries.isEmpty) {
    return ConstellationData();
  }

  final allEntries = entries.values.toList();

  // Build edges from co-seen relationships.
  final edgeSet = <String, ConstellationEdge>{};
  int maxWeight = 1;

  for (final entry in allEntries) {
    for (final coSeen in entry.coSeenNodes.entries) {
      final other = coSeen.key;
      final relationship = coSeen.value;
      final weight = relationship.count;

      // Only include edges where both nodes exist in the dex.
      if (!entries.containsKey(other)) continue;

      // Create a canonical edge key to avoid duplicates.
      final a = entry.nodeNum < other ? entry.nodeNum : other;
      final b = entry.nodeNum < other ? other : entry.nodeNum;
      final key = '${a}_$b';

      if (!edgeSet.containsKey(key) || edgeSet[key]!.weight < weight) {
        edgeSet[key] = ConstellationEdge(
          from: a,
          to: b,
          weight: weight,
          firstSeen: relationship.firstSeen,
          lastSeen: relationship.lastSeen,
          messageCount: relationship.messageCount,
        );
        if (weight > maxWeight) maxWeight = weight;
      }
    }
  }

  final edgeList = edgeSet.values.toList();

  // --- Force-directed layout ---
  //
  // 1. Seed positions deterministically from node number hashes.
  // 2. Run force simulation: repulsion between all nodes, attraction
  //    along edges (weighted by strength).
  // 3. Gravity pulls all nodes gently toward center to prevent outliers.
  // 4. Normalize final positions to [0.08, 0.92] with aspect-ratio awareness.
  //
  // Key design: strong repulsion + weak attraction + gravity produces
  // a well-spread organic constellation rather than a collapsed hairball.
  // The "ideal edge length" concept from Fruchterman-Reingold ensures
  // connected nodes are close but not on top of each other.

  final nodeCount = allEntries.length;
  final posX = List<double>.filled(nodeCount, 0);
  final posY = List<double>.filled(nodeCount, 0);
  final nodeNumToIndex = <int, int>{};

  // Compute degree (connection count) for each node to inform layout.
  final degree = List<int>.filled(nodeCount, 0);

  // Seed initial positions from hash — spread in a wider circle.
  for (int i = 0; i < nodeCount; i++) {
    final hash = _positionHash(allEntries[i].nodeNum);
    final angle = (hash & 0xFFFF) / 65535.0 * 2.0 * 3.14159265358979;
    // Start with a wider spread (0.2..0.5 radius from center).
    final radius = 0.20 + ((hash >> 16) & 0xFFFF) / 65535.0 * 0.30;
    posX[i] = 0.5 + radius * _fastCos(angle);
    posY[i] = 0.5 + radius * _fastSin(angle);
    nodeNumToIndex[allEntries[i].nodeNum] = i;
  }

  // Compute median weight for attraction weighting.
  final sortedWeights = edgeList.map((e) => e.weight).toList()..sort();
  final medianWeight = sortedWeights.isEmpty
      ? 1
      : sortedWeights[sortedWeights.length ~/ 2];

  // Build edge index for simulation. ALL edges participate in attraction,
  // but weak edges attract much less than strong ones.
  final attractionEdges = <(int, int, double)>[];
  for (final edge in edgeList) {
    final fromIdx = nodeNumToIndex[edge.from];
    final toIdx = nodeNumToIndex[edge.to];
    if (fromIdx == null || toIdx == null) continue;

    degree[fromIdx]++;
    degree[toIdx]++;

    // Normalize weight: weak edges get very little pull.
    // Strong edges (above median) get more, but still bounded.
    final rawWeight = edge.weight / maxWeight;
    // Sigmoid-like scaling: suppresses weak edges, boosts strong ones.
    final effectiveWeight = edge.weight >= medianWeight
        ? 0.3 + rawWeight * 0.7
        : rawWeight * 0.2;
    attractionEdges.add((fromIdx, toIdx, effectiveWeight));
  }

  // Fruchterman-Reingold inspired parameters.
  // The ideal edge length scales with the number of nodes so that
  // larger graphs naturally spread further.
  final area = 1.0; // Unit square.
  final idealLength = _sqrt(area / nodeCount) * 1.8;
  final idealLengthSq = idealLength * idealLength;

  // Force simulation parameters — tuned for spread, not collapse.
  const iterations = 350;
  // Strong repulsion prevents hairball formation.
  final repulsionStrength = idealLengthSq * 0.8;
  // Weak attraction keeps connected nodes loosely grouped.
  const attractionStrength = 0.015;
  // Gentle gravity prevents disconnected nodes from flying to infinity.
  const gravityStrength = 0.002;
  const gravityCenter = 0.5;
  // Temperature schedule (simulated annealing).
  final tempStart = idealLength * 0.5;
  const tempEnd = 0.001;

  for (int iter = 0; iter < iterations; iter++) {
    final t = iter / iterations;
    // Exponential cooling for smooth convergence.
    final temp = tempStart * _pow(tempEnd / tempStart, t);

    final forceX = List<double>.filled(nodeCount, 0);
    final forceY = List<double>.filled(nodeCount, 0);

    // 1) Repulsion: all pairs push apart (Coulomb's law).
    // O(n^2) but fine for hundreds of nodes on mobile.
    for (int i = 0; i < nodeCount; i++) {
      for (int j = i + 1; j < nodeCount; j++) {
        var dx = posX[i] - posX[j];
        var dy = posY[i] - posY[j];
        var distSq = dx * dx + dy * dy;
        if (distSq < 1e-8) {
          // Deterministic jitter to break exact overlaps.
          dx = ((_positionHash(i * 31 + j) & 0xFFFF) / 65535.0 - 0.5) * 0.01;
          dy = ((_positionHash(j * 31 + i) & 0xFFFF) / 65535.0 - 0.5) * 0.01;
          distSq = dx * dx + dy * dy;
        }
        final dist = _sqrt(distSq);
        // Repulsion force: F = k^2 / d (FR model).
        final force = repulsionStrength / (dist * distSq.clamp(0.001, 1e6));
        final fx = dx / dist * force;
        final fy = dy / dist * force;
        forceX[i] += fx;
        forceY[i] += fy;
        forceX[j] -= fx;
        forceY[j] -= fy;
      }
    }

    // 2) Attraction: edges pull endpoints together (Hooke's law).
    // Force is proportional to distance, weighted by edge strength.
    for (final (fromIdx, toIdx, weight) in attractionEdges) {
      final dx = posX[toIdx] - posX[fromIdx];
      final dy = posY[toIdx] - posY[fromIdx];
      final distSq = dx * dx + dy * dy;
      if (distSq < 1e-8) continue;
      final dist = _sqrt(distSq);

      // Attraction force: F = d^2 / k (FR model), scaled by weight.
      // High-degree nodes have weaker per-edge attraction to prevent
      // them from collapsing all their neighbors onto themselves.
      final degreeScale =
          1.0 / (1.0 + 0.15 * (degree[fromIdx] + degree[toIdx]));
      final force =
          dist * dist / idealLength * attractionStrength * weight * degreeScale;
      final fx = dx / dist * force;
      final fy = dy / dist * force;
      forceX[fromIdx] += fx;
      forceY[fromIdx] += fy;
      forceX[toIdx] -= fx;
      forceY[toIdx] -= fy;
    }

    // 3) Gravity: gentle pull toward center prevents drift.
    for (int i = 0; i < nodeCount; i++) {
      final dx = gravityCenter - posX[i];
      final dy = gravityCenter - posY[i];
      forceX[i] += dx * gravityStrength;
      forceY[i] += dy * gravityStrength;
    }

    // 4) Apply forces, clamped by temperature.
    for (int i = 0; i < nodeCount; i++) {
      final fx = forceX[i];
      final fy = forceY[i];
      final forceMag = _sqrt(fx * fx + fy * fy);
      if (forceMag < 1e-8) continue;

      // Clamp displacement by temperature.
      final scale = (forceMag < temp) ? 1.0 : temp / forceMag;
      posX[i] += fx * scale;
      posY[i] += fy * scale;
    }
  }

  // Normalize positions to [0.08, 0.92] with aspect-ratio preservation.
  // Use independent X and Y ranges to fill the available space better,
  // while maintaining the relative shape of the layout.
  double minX = double.infinity, maxXPos = double.negativeInfinity;
  double minY = double.infinity, maxYPos = double.negativeInfinity;
  for (int i = 0; i < nodeCount; i++) {
    if (posX[i] < minX) minX = posX[i];
    if (posX[i] > maxXPos) maxXPos = posX[i];
    if (posY[i] < minY) minY = posY[i];
    if (posY[i] > maxYPos) maxYPos = posY[i];
  }
  final rangeX = maxXPos - minX;
  final rangeY = maxYPos - minY;
  // Use the larger range to preserve aspect ratio, but ensure both
  // axes use at least 70% of available space for better spread.
  final maxRange = rangeX > rangeY ? rangeX : rangeY;
  final effectiveRangeX = maxRange > 1e-6
      ? rangeX.clamp(maxRange * 0.7, maxRange)
      : 1.0;
  final effectiveRangeY = maxRange > 1e-6
      ? rangeY.clamp(maxRange * 0.7, maxRange)
      : 1.0;

  if (maxRange > 1e-6) {
    final cxLayout = (minX + maxXPos) / 2.0;
    final cyLayout = (minY + maxYPos) / 2.0;
    const spread = 0.82; // Use 82% of the [0,1] space.
    for (int i = 0; i < nodeCount; i++) {
      posX[i] = 0.5 + (posX[i] - cxLayout) / effectiveRangeX * spread;
      posY[i] = 0.5 + (posY[i] - cyLayout) / effectiveRangeY * spread;
      posX[i] = posX[i].clamp(0.08, 0.92);
      posY[i] = posY[i].clamp(0.08, 0.92);
    }
  }

  // Build constellation nodes.
  final constellationNodes = <ConstellationNode>[];
  for (int i = 0; i < nodeCount; i++) {
    final entry = allEntries[i];
    final node = nodes[entry.nodeNum];
    final trait = ref.read(nodeDexTraitProvider(entry.nodeNum));

    constellationNodes.add(
      ConstellationNode(
        nodeNum: entry.nodeNum,
        displayName:
            entry.localNickname ??
            node?.displayName ??
            entry.lastKnownName ??
            NodeDisplayNameResolver.defaultName(entry.nodeNum),
        sigil: entry.sigil,
        trait: trait.primary,
        connectionCount: entry.coSeenCount,
        x: posX[i],
        y: posY[i],
      ),
    );
  }

  // Sort by connection count ascending so high-degree nodes render on top.
  constellationNodes.sort(
    (a, b) => a.connectionCount.compareTo(b.connectionCount),
  );

  return ConstellationData(
    nodes: constellationNodes,
    edges: edgeList,
    maxWeight: maxWeight,
  );
});

/// Hash function for deterministic constellation positioning.
int _positionHash(int nodeNum) {
  int h = nodeNum & 0xFFFFFFFF;
  h ^= h >> 16;
  h = (h * 0x45d9f3b) & 0xFFFFFFFF;
  h ^= h >> 16;
  h = (h * 0x45d9f3b) & 0xFFFFFFFF;
  h ^= h >> 16;
  return h;
}

/// Fast sine approximation for constellation layout.
double _fastSin(double x) {
  const pi = 3.14159265358979;
  const twoPi = pi * 2.0;
  x = x % twoPi;
  if (x > pi) x -= twoPi;
  if (x < -pi) x += twoPi;
  final num = 16.0 * x * (pi - x);
  final den = 5.0 * pi * pi - 4.0 * x * (pi - x);
  if (den.abs() < 1e-10) return 0.0;
  return num / den;
}

/// Fast cosine approximation for constellation layout.
double _fastCos(double x) {
  return _fastSin(x + 3.14159265358979 / 2.0);
}

/// Fast square root (dart:math is fine but this avoids the import).
double _sqrt(double x) {
  if (x <= 0) return 0;
  double guess = x / 2;
  for (int i = 0; i < 8; i++) {
    guess = (guess + x / guess) / 2;
  }
  return guess;
}

/// Fast power approximation for exponential temperature cooling.
/// Uses exp(exponent * ln(base)) via a simple Taylor-ish approach.
double _pow(double base, double exponent) {
  if (base <= 0) return 0;
  if (exponent == 0) return 1;
  if (exponent == 1) return base;
  // Use dart:math for correctness — this is called once per iteration,
  // not per-node, so performance is not critical.
  // ln(base) * exponent, then exp().
  // Approximation: repeated squaring for integer-ish exponents,
  // but for fractional exponents we need the real thing.
  // Since we avoid importing dart:math in this file, use a series
  // approximation of exp(y * ln(x)).
  double lnBase = _ln(base);
  double y = lnBase * exponent;
  return _exp(y);
}

/// Natural logarithm approximation using the series expansion.
/// Accurate enough for layout temperature scheduling.
double _ln(double x) {
  if (x <= 0) return -1e10;
  // Reduce x to [0.5, 2) range, then use series.
  int k = 0;
  double v = x;
  while (v > 2.0) {
    v /= 2.718281828459045;
    k++;
  }
  while (v < 0.5) {
    v *= 2.718281828459045;
    k--;
  }
  // Now v is near 1. Use ln(1+u) series where u = v - 1.
  final u = v - 1.0;
  double sum = 0;
  double term = u;
  for (int n = 1; n <= 20; n++) {
    sum += term / n;
    term *= -u;
  }
  return sum + k;
}

/// Exponential function approximation using Taylor series.
double _exp(double x) {
  // Clamp to avoid overflow.
  if (x > 20) return 4.85165195e8;
  if (x < -20) return 0;
  double sum = 1.0;
  double term = 1.0;
  for (int n = 1; n <= 25; n++) {
    term *= x / n;
    sum += term;
  }
  return sum;
}
