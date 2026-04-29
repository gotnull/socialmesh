// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Riverpod providers for the NodeDex Map view.
//
// All state here is derived: the adapter does the projection, this
// file only owns the filter and the cached marker list. Read-only —
// the map never mutates NodeDex state.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging.dart';
import '../../../providers/app_providers.dart';
import '../providers/nodedex_providers.dart';
import 'nodedex_map_adapter.dart';

class NodeDexMapFilterNotifier extends Notifier<NodeDexMapFilter> {
  @override
  NodeDexMapFilter build() => const NodeDexMapFilter();

  void setTimeWindow(NodeDexMapTimeWindow window) {
    if (state.timeWindow == window) return;
    state = state.copyWith(timeWindow: window);
    AppLogging.nodeDex('Map filter — timeWindow=${window.name}');
  }

  void toggleFavouritesOnly() {
    final next = !state.favouritesOnly;
    state = state.copyWith(favouritesOnly: next);
    AppLogging.nodeDex('Map filter — favouritesOnly=$next');
  }
}

final nodeDexMapFilterProvider =
    NotifierProvider<NodeDexMapFilterNotifier, NodeDexMapFilter>(
      NodeDexMapFilterNotifier.new,
    );

/// Unfiltered, position-resolved markers for every NodeDex entry.
///
/// Re-derives only when [nodeDexSortedEntriesProvider] or
/// [myNodeNumProvider] change — the filter does NOT participate, so
/// toggling time windows does not re-walk all entries.
final nodeDexMapAllMarkersProvider = Provider<NodeDexMapProjection>((ref) {
  final pairs = ref.watch(nodeDexSortedEntriesProvider);
  final myNodeNum = ref.watch(myNodeNumProvider);
  final projection = NodeDexMapAdapter.project(
    pairs: pairs,
    myNodeNum: myNodeNum,
    now: DateTime.now(),
  );
  AppLogging.nodeDex(
    'Map projection — ${projection.markers.length} markers, '
    'excluded ${projection.excludedNoPosition} (no position)',
  );
  return projection;
});

/// Markers after applying the active filter. This is what the screen
/// watches — re-derives on filter change but reuses the cached
/// projection underneath.
final nodeDexMapFilteredMarkersProvider = Provider<List<NodeDexMapMarker>>((
  ref,
) {
  final projection = ref.watch(nodeDexMapAllMarkersProvider);
  final filter = ref.watch(nodeDexMapFilterProvider);
  final filtered = NodeDexMapAdapter.applyFilter(
    markers: projection.markers,
    filter: filter,
    now: DateTime.now(),
  );
  AppLogging.nodeDex(
    'Map filtered — ${filtered.length}/${projection.markers.length} '
    '(window=${filter.timeWindow.name}, '
    'favouritesOnly=${filter.favouritesOnly})',
  );
  return filtered;
});
