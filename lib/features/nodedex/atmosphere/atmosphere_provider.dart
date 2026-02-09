// SPDX-License-Identifier: GPL-3.0-or-later

// Atmosphere Provider — Riverpod state management for the Elemental Atmosphere.
//
// Provider hierarchy:
//
// atmosphereEnabledProvider (NotifierProvider)
//   ├── Persisted to SharedPreferences as 'atmosphere_enabled'
//   ├── Auto-disabled when reduce-motion is active
//   └── Read by all atmosphere overlay widgets
//
// atmosphereIntensitiesProvider (Provider)
//   ├── Reads nodeDexStatsProvider for mesh metrics
//   ├── Reads nodeDexProvider for per-node patina averages
//   ├── Computes via AtmosphereDataAdapter.compute()
//   └── Returns AtmosphereIntensities.zero when disabled
//
// atmosphereMetricsProvider (Provider)
//   ├── Collects raw metrics from NodeDex stats
//   └── Feeds into atmosphereIntensitiesProvider
//
// The atmosphere system is opt-in. Users must explicitly enable it
// via the appearance settings toggle. Once enabled, effects are
// data-driven and require no further user interaction.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/logging.dart';
import '../../../providers/accessibility_providers.dart';
import '../providers/nodedex_providers.dart';
import '../services/patina_score.dart';
import 'atmosphere_data_adapter.dart';

// =============================================================================
// SharedPreferences key
// =============================================================================

/// Key used to persist the atmosphere enabled state.
const String _atmosphereEnabledKey = 'atmosphere_enabled';

// =============================================================================
// Enabled state provider
// =============================================================================

/// Notifier that manages the atmosphere enabled/disabled state.
///
/// The state is persisted to SharedPreferences so it survives app restarts.
/// When reduce-motion is active, the effective state is always false
/// regardless of the stored preference.
///
/// Usage:
/// ```dart
/// // Read current state
/// final enabled = ref.watch(atmosphereEnabledProvider);
///
/// // Toggle
/// ref.read(atmosphereEnabledProvider.notifier).toggle();
///
/// // Set explicitly
/// ref.read(atmosphereEnabledProvider.notifier).setEnabled(true);
/// ```
class AtmosphereEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    // Load persisted preference synchronously.
    // SharedPreferences should be pre-initialized by this point.
    _loadFromPrefs();
    return false; // Default: disabled (opt-in)
  }

  /// Load the saved preference. Called once during build.
  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(_atmosphereEnabledKey);
      if (saved != null && saved != state) {
        state = saved;
        AppLogging.nodeDex(
          'Atmosphere: loaded saved preference — ${saved ? "enabled" : "disabled"}',
        );
      }
    } catch (e) {
      AppLogging.nodeDex('Atmosphere: failed to load preference — $e');
    }
  }

  /// Enable or disable the atmosphere system.
  ///
  /// Persists the preference to SharedPreferences.
  Future<void> setEnabled(bool enabled) async {
    if (state == enabled) return;
    state = enabled;
    AppLogging.nodeDex(
      'Atmosphere: ${enabled ? "enabled" : "disabled"} by user',
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_atmosphereEnabledKey, enabled);
    } catch (e) {
      AppLogging.nodeDex('Atmosphere: failed to persist preference — $e');
    }
  }

  /// Toggle the atmosphere on/off.
  Future<void> toggle() async {
    await setEnabled(!state);
  }
}

/// Provider for the atmosphere enabled state.
///
/// Returns true when the user has opted in to atmospheric effects
/// AND reduce-motion is not active. Both conditions must be met
/// for effects to render.
final atmosphereEnabledProvider =
    NotifierProvider<AtmosphereEnabledNotifier, bool>(
      AtmosphereEnabledNotifier.new,
    );

/// Provider for the effective atmosphere state.
///
/// Combines the user preference with reduce-motion and returns
/// the final boolean that overlay widgets should use. This is
/// the single source of truth for "should effects render?"
///
/// When reduce-motion is enabled at the OS or app level, this
/// provider returns false regardless of the user's atmosphere
/// preference. The stored preference is preserved so that
/// disabling reduce-motion restores the previous atmosphere state.
final atmosphereEffectivelyEnabledProvider = Provider<bool>((ref) {
  final userEnabled = ref.watch(atmosphereEnabledProvider);
  final reduceMotion = ref.watch(reduceMotionEnabledProvider);

  if (reduceMotion) return false;
  return userEnabled;
});

// =============================================================================
// Metrics collection provider
// =============================================================================

/// Provider that collects raw mesh metrics for the atmosphere system.
///
/// Reads from nodeDexStatsProvider and nodeDexProvider to extract
/// the values needed by [AtmosphereDataAdapter.compute]. This
/// provider only computes when the atmosphere is effectively enabled,
/// returning [MeshAtmosphereMetrics.empty] otherwise to avoid
/// unnecessary computation.
final atmosphereMetricsProvider = Provider<MeshAtmosphereMetrics>((ref) {
  final enabled = ref.watch(atmosphereEffectivelyEnabledProvider);
  if (!enabled) return MeshAtmosphereMetrics.empty;

  final stats = ref.watch(nodeDexStatsProvider);
  final entries = ref.watch(nodeDexProvider);

  if (stats.totalNodes == 0) return MeshAtmosphereMetrics.empty;

  // Compute average patina score across all entries.
  // This is potentially expensive for very large NodeDex collections,
  // but patina computation is pure and fast (no I/O, no async).
  double totalPatina = 0.0;
  int patinaCount = 0;

  for (final entry in entries.values) {
    final result = PatinaScore.compute(entry);
    totalPatina += result.score;
    patinaCount++;
  }

  final averagePatina = patinaCount > 0 ? totalPatina / patinaCount : 0.0;

  return AtmosphereDataAdapter.metricsFromStats(
    totalNodes: stats.totalNodes,
    totalEncounters: stats.totalEncounters,
    totalRegions: stats.totalRegions,
    traitDistribution: stats.traitDistribution,
    averagePatinaScore: averagePatina,
  );
});

// =============================================================================
// Computed intensities provider
// =============================================================================

/// Provider that computes atmosphere effect intensities from mesh metrics.
///
/// Returns [AtmosphereIntensities.zero] when the atmosphere system is
/// disabled. When enabled, returns intensities computed by
/// [AtmosphereDataAdapter] from current mesh data.
///
/// Overlay widgets consume this provider and apply context-specific
/// multipliers (constellation: 1.0, detail: 0.25, map: 0.3) before
/// passing values to the particle layers.
///
/// Usage:
/// ```dart
/// final intensities = ref.watch(atmosphereIntensitiesProvider);
/// final scaled = intensities.scaled(AtmosphereIntensity.constellationMultiplier);
/// ```
final atmosphereIntensitiesProvider = Provider<AtmosphereIntensities>((ref) {
  final enabled = ref.watch(atmosphereEffectivelyEnabledProvider);
  if (!enabled) return AtmosphereIntensities.zero;

  final metrics = ref.watch(atmosphereMetricsProvider);
  if (metrics.totalNodes == 0) return AtmosphereIntensities.zero;

  return AtmosphereDataAdapter.compute(metrics);
});

// =============================================================================
// Convenience providers for individual effects
// =============================================================================

/// Provider for rain effect intensity at full scale (constellation).
///
/// Returns 0.0 when the atmosphere is disabled.
final atmosphereRainIntensityProvider = Provider<double>((ref) {
  return ref.watch(atmosphereIntensitiesProvider).rain;
});

/// Provider for ember effect intensity at full scale (constellation).
///
/// Returns 0.0 when the atmosphere is disabled.
final atmosphereEmberIntensityProvider = Provider<double>((ref) {
  return ref.watch(atmosphereIntensitiesProvider).ember;
});

/// Provider for mist effect intensity at full scale (constellation).
///
/// Returns 0.0 when the atmosphere is disabled.
final atmosphereMistIntensityProvider = Provider<double>((ref) {
  return ref.watch(atmosphereIntensitiesProvider).mist;
});

/// Provider for starlight effect intensity at full scale (constellation).
///
/// Returns 0.0 when the atmosphere is disabled.
final atmosphereStarlightIntensityProvider = Provider<double>((ref) {
  return ref.watch(atmosphereIntensitiesProvider).starlight;
});
