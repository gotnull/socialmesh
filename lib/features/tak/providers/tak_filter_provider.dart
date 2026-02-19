// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging.dart';
import '../models/tak_event.dart';
import '../utils/cot_affiliation.dart';
import 'tak_providers.dart';

/// How stale events are shown.
enum TakStaleMode {
  /// Show both active and stale events.
  all,

  /// Show only active (non-stale) events.
  activeOnly,

  /// Show only stale events.
  staleOnly,
}

/// Immutable filter state for TAK entities.
class TakFilterState {
  /// Active affiliation filters. Empty means show all.
  final Set<CotAffiliation> affiliations;

  /// Stale mode filter.
  final TakStaleMode staleMode;

  /// Free-text search query (case-insensitive substring match on callsign/UID).
  final String searchQuery;

  const TakFilterState({
    this.affiliations = const {},
    this.staleMode = TakStaleMode.all,
    this.searchQuery = '',
  });

  TakFilterState copyWith({
    Set<CotAffiliation>? affiliations,
    TakStaleMode? staleMode,
    String? searchQuery,
  }) {
    return TakFilterState(
      affiliations: affiliations ?? this.affiliations,
      staleMode: staleMode ?? this.staleMode,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  /// Whether any filter is active.
  bool get isActive =>
      affiliations.isNotEmpty ||
      staleMode != TakStaleMode.all ||
      searchQuery.isNotEmpty;
}

/// Manages TAK entity filter state.
///
/// Shared between TakScreen and TakMapScreen so filters persist across
/// navigation.
class TakFilterNotifier extends Notifier<TakFilterState> {
  @override
  TakFilterState build() => const TakFilterState();

  /// Toggle an affiliation in the filter set.
  void toggleAffiliation(CotAffiliation affiliation) {
    final current = Set<CotAffiliation>.of(state.affiliations);
    if (current.contains(affiliation)) {
      current.remove(affiliation);
    } else {
      current.add(affiliation);
    }
    state = state.copyWith(affiliations: current);
    _logFilterState();
  }

  /// Cycle stale mode: all -> activeOnly -> staleOnly -> all.
  void cycleStaleMode() {
    final next = switch (state.staleMode) {
      TakStaleMode.all => TakStaleMode.activeOnly,
      TakStaleMode.activeOnly => TakStaleMode.staleOnly,
      TakStaleMode.staleOnly => TakStaleMode.all,
    };
    state = state.copyWith(staleMode: next);
    _logFilterState();
  }

  /// Set stale mode directly.
  void setStaleMode(TakStaleMode mode) {
    state = state.copyWith(staleMode: mode);
    _logFilterState();
  }

  /// Update the search query.
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    _logFilterState();
  }

  /// Clear all filters.
  void clearAll() {
    state = const TakFilterState();
    AppLogging.tak('Filter cleared');
  }

  void _logFilterState() {
    final affNames = state.affiliations.map((a) => a.name).join(', ');
    AppLogging.tak(
      'Filter updated: affiliations={$affNames}, '
      'staleMode=${state.staleMode.name}, '
      'search="${state.searchQuery}"',
    );
  }
}

/// Filter state provider shared across TAK screens.
final takFilterProvider = NotifierProvider<TakFilterNotifier, TakFilterState>(
  TakFilterNotifier.new,
);

/// Filtered TAK events applying all active filters to [takActiveEventsProvider].
///
/// Used by both TakScreen and TakMapScreen.
final filteredTakEventsProvider = Provider<List<TakEvent>>((ref) {
  final events = ref.watch(takActiveEventsProvider);
  final filter = ref.watch(takFilterProvider);

  var filtered = events;

  // Affiliation filter
  if (filter.affiliations.isNotEmpty) {
    filtered = filtered.where((e) {
      final aff = parseAffiliation(e.type);
      return filter.affiliations.contains(aff);
    }).toList();
  }

  // Stale mode filter
  switch (filter.staleMode) {
    case TakStaleMode.all:
      break;
    case TakStaleMode.activeOnly:
      filtered = filtered.where((e) => !e.isStale).toList();
    case TakStaleMode.staleOnly:
      filtered = filtered.where((e) => e.isStale).toList();
  }

  // Search query filter
  if (filter.searchQuery.isNotEmpty) {
    final query = filter.searchQuery.toLowerCase();
    filtered = filtered.where((e) {
      final callsign = (e.callsign ?? '').toLowerCase();
      final uid = e.uid.toLowerCase();
      return callsign.contains(query) || uid.contains(query);
    }).toList();
  }

  AppLogging.tak(
    'filteredEventsProvider: ${filtered.length} of ${events.length} '
    'events match filters',
  );
  return filtered;
});
