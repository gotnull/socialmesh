// SPDX-License-Identifier: GPL-3.0-or-later

// Atmosphere Overlay — composable widget that stacks all effect layers.
//
// This is the primary integration point for the Elemental Atmosphere
// system. Screens that want atmospheric effects place an AtmosphereOverlay
// behind their content in a Stack. The overlay reads from Riverpod
// providers to determine which effects are active and at what intensity.
//
// Usage:
//
// 1. Constellation screen (full intensity):
//    Stack(
//      children: [
//        const AtmosphereOverlay(context: AtmosphereContext.constellation),
//        // ... constellation canvas ...
//      ],
//    )
//
// 2. Node detail screen (very subtle):
//    Stack(
//      children: [
//        const AtmosphereOverlay(context: AtmosphereContext.detail),
//        // ... detail content ...
//      ],
//    )
//
// 3. Map overlay (subtle):
//    Stack(
//      children: [
//        const AtmosphereOverlay(context: AtmosphereContext.map),
//        // ... map tiles and markers ...
//      ],
//    )
//
// The overlay is wrapped in IgnorePointer so it never intercepts
// touch events. Each effect layer runs independently with its own
// Ticker and particle pool. Layers that have zero intensity are not
// mounted at all (no wasted resources).
//
// Performance:
//   - Layers with zero intensity return SizedBox.shrink (zero cost)
//   - Each layer is wrapped in RepaintBoundary (isolated repaints)
//   - Auto-throttle reduces particles on slow devices
//   - Reduce-motion disables everything at the widget level
//   - AtmosphereOverlay itself is a lightweight Consumer widget

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'atmosphere_config.dart';
import 'atmosphere_provider.dart';
import 'effects/ember_effect.dart';
import 'effects/mist_effect.dart';
import 'effects/rain_effect.dart';
import 'effects/starlight_effect.dart';
import 'particle_system.dart';

// =============================================================================
// Context enum
// =============================================================================

/// The screen context where the atmosphere overlay is displayed.
///
/// Each context applies a different intensity multiplier to all effects.
/// This ensures that the constellation screen gets full atmospheric
/// presence while detail and map screens get only a subtle hint.
enum AtmosphereContext {
  /// Constellation view — full effect intensity.
  constellation,

  /// Node detail screen — very subtle, background ambiance only.
  detail,

  /// Map overlay — subtle, must not interfere with map readability.
  map,
}

extension _AtmosphereContextMultiplier on AtmosphereContext {
  /// The intensity multiplier for this context.
  double get multiplier {
    return switch (this) {
      AtmosphereContext.constellation =>
        AtmosphereIntensity.constellationMultiplier,
      AtmosphereContext.detail => AtmosphereIntensity.detailScreenMultiplier,
      AtmosphereContext.map => AtmosphereIntensity.mapOverlayMultiplier,
    };
  }
}

// =============================================================================
// Atmosphere overlay widget
// =============================================================================

/// Composable overlay that renders all active atmospheric effect layers.
///
/// Place this widget behind your content in a [Stack]. It reads from
/// Riverpod providers to determine which effects are active and at
/// what intensity, then mounts only the layers that have non-zero
/// intensity for the given [context].
///
/// The overlay is completely non-interactive — it wraps everything in
/// [IgnorePointer] and never captures touch events.
///
/// When the atmosphere system is disabled (via user toggle, reduce-motion,
/// or battery saver), this widget returns [SizedBox.shrink] and has
/// zero rendering cost.
///
/// ```dart
/// // In a screen's build method:
/// Stack(
///   children: [
///     const AtmosphereOverlay(context: AtmosphereContext.constellation),
///     // Your main content here
///   ],
/// )
/// ```
class AtmosphereOverlay extends ConsumerWidget {
  /// The screen context, which determines the intensity multiplier.
  final AtmosphereContext context;

  /// Optional override for individual effect enablement.
  /// When null, all effects are enabled based on their computed intensity.
  /// When provided, only the specified effects are rendered.
  final Set<AtmosphereEffectType>? enabledEffects;

  const AtmosphereOverlay({
    super.key,
    required this.context,
    this.enabledEffects,
  });

  @override
  Widget build(BuildContext buildContext, WidgetRef ref) {
    final effectivelyEnabled = ref.watch(atmosphereEffectivelyEnabledProvider);

    // Early exit: atmosphere system is off.
    if (!effectivelyEnabled) return const SizedBox.shrink();

    final baseIntensities = ref.watch(atmosphereIntensitiesProvider);

    // Early exit: no effects have intensity.
    if (!baseIntensities.hasAnyEffect) return const SizedBox.shrink();

    // Apply context-specific multiplier.
    final scaled = baseIntensities.scaled(context.multiplier);

    // Determine which effects to render.
    final showRain = _shouldShow(AtmosphereEffectType.rain, scaled.rain);
    final showEmber = _shouldShow(AtmosphereEffectType.ember, scaled.ember);
    final showMist = _shouldShow(AtmosphereEffectType.mist, scaled.mist);
    final showStarlight = _shouldShow(
      AtmosphereEffectType.starlight,
      scaled.starlight,
    );

    // Early exit: no visible effects after scaling and filtering.
    if (!showRain && !showEmber && !showMist && !showStarlight) {
      return const SizedBox.shrink();
    }

    // Build the layer stack. Order matters — back to front:
    // 1. Mist (largest, most diffuse — sits deepest)
    // 2. Starlight (small static points — behind moving particles)
    // 3. Rain (directional streaks — mid layer)
    // 4. Embers (glowing sparks — foreground of atmosphere)
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (showMist)
            MistLayer(
              key: const ValueKey('atmosphere_mist'),
              intensity: scaled.mist,
              enabled: true,
            ),
          if (showStarlight)
            StarlightLayer(
              key: const ValueKey('atmosphere_starlight'),
              intensity: scaled.starlight,
              enabled: true,
            ),
          if (showRain)
            AtmosphereLayer(
              key: const ValueKey('atmosphere_rain'),
              strategy: RainSpawnStrategy(),
              intensity: scaled.rain,
              enabled: true,
            ),
          if (showEmber)
            EmberLayer(
              key: const ValueKey('atmosphere_ember'),
              intensity: scaled.ember,
              enabled: true,
            ),
        ],
      ),
    );
  }

  /// Whether a specific effect type should be shown.
  ///
  /// Returns true if:
  ///   1. The effect has non-zero intensity (after scaling), AND
  ///   2. The effect is in the [enabledEffects] set (or the set is null,
  ///      meaning all effects are allowed)
  bool _shouldShow(AtmosphereEffectType type, double intensity) {
    if (intensity <= 0.001) return false;
    if (enabledEffects != null && !enabledEffects!.contains(type)) return false;
    return true;
  }
}

// =============================================================================
// Effect type enum
// =============================================================================

/// The four atmospheric effect types.
///
/// Used by [AtmosphereOverlay.enabledEffects] to selectively enable
/// or disable specific effects for a given context.
enum AtmosphereEffectType {
  /// Vertical streak particles tied to packet activity.
  rain,

  /// Rising spark particles tied to patina and relay contribution.
  ember,

  /// Drifting fog blobs tied to sparse data regions.
  mist,

  /// Ambient twinkling background particles.
  starlight,
}

// =============================================================================
// Convenience wrappers for common contexts
// =============================================================================

/// Pre-configured atmosphere overlay for the constellation screen.
///
/// Uses full intensity multiplier (1.0) with all effects enabled.
/// This is the primary showcase for the atmosphere system.
class ConstellationAtmosphere extends StatelessWidget {
  const ConstellationAtmosphere({super.key});

  @override
  Widget build(BuildContext context) {
    return const AtmosphereOverlay(context: AtmosphereContext.constellation);
  }
}

/// Pre-configured atmosphere overlay for the node detail screen.
///
/// Uses reduced intensity multiplier (0.25) with only starlight
/// and embers enabled. Rain and mist are too visually busy for
/// a detail screen that contains dense text and data.
class DetailAtmosphere extends StatelessWidget {
  const DetailAtmosphere({super.key});

  @override
  Widget build(BuildContext context) {
    return const AtmosphereOverlay(
      context: AtmosphereContext.detail,
      enabledEffects: {
        AtmosphereEffectType.starlight,
        AtmosphereEffectType.ember,
      },
    );
  }
}

/// Pre-configured atmosphere overlay for the map screen.
///
/// Uses reduced intensity multiplier (0.3) with only mist and
/// starlight enabled. Rain and embers would interfere with map
/// marker visibility and tile readability.
class MapAtmosphere extends StatelessWidget {
  const MapAtmosphere({super.key});

  @override
  Widget build(BuildContext context) {
    return const AtmosphereOverlay(
      context: AtmosphereContext.map,
      enabledEffects: {
        AtmosphereEffectType.starlight,
        AtmosphereEffectType.mist,
      },
    );
  }
}
