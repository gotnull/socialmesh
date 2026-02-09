// SPDX-License-Identifier: GPL-3.0-or-later

// Atmosphere Configuration — constants for the Elemental Atmosphere system.
//
// Defines particle limits, timing, colors, and performance thresholds
// for all ambient atmospheric effects. Values are calibrated to be
// visually subtle and performant on low-end devices.
//
// The atmosphere system renders four effect types:
//   1. Rain    — vertical streaks tied to packet activity / node count
//   2. Embers  — rising sparks tied to patina scores / relay contribution
//   3. Mist    — drifting fog tied to sparse data regions
//   4. Starlight — ambient twinkling background particles
//
// All effects are background-layer, non-interactive, and purely cosmetic.
// They never obstruct text, sigils, or interactive elements.

import 'dart:ui';

/// Global particle budget and performance constants.
///
/// The system enforces a hard cap on total particles across all
/// active effects. On each tick, if the frame budget is exceeded,
/// particle spawn rates are throttled automatically.
class AtmosphereLimits {
  AtmosphereLimits._();

  /// Maximum particles per individual effect layer.
  static const int maxParticlesPerEffect = 80;

  /// Absolute ceiling across all active effects combined.
  /// If the total exceeds this, the least-visible effect is throttled.
  static const int maxParticlesGlobal = 200;

  /// Target frame time in milliseconds. If a paint cycle exceeds
  /// this, the system reduces particle counts on the next frame.
  static const double targetFrameMs = 12.0;

  /// Number of consecutive slow frames before auto-throttle kicks in.
  static const int slowFrameThreshold = 5;

  /// Minimum interval between particle spawns (milliseconds).
  /// Prevents burst-spawning that could cause frame drops.
  static const double minSpawnIntervalMs = 16.0;

  /// Particle pool pre-allocation size. Particles are recycled
  /// from this pool to avoid GC pressure during animation.
  static const int particlePoolSize = 250;
}

/// Timing constants for particle lifecycle and animation.
class AtmosphereTiming {
  AtmosphereTiming._();

  // ---------------------------------------------------------------------------
  // Rain
  // ---------------------------------------------------------------------------

  /// Minimum lifetime of a rain particle (seconds).
  static const double rainLifetimeMin = 0.4;

  /// Maximum lifetime of a rain particle (seconds).
  static const double rainLifetimeMax = 1.2;

  /// Rain fall speed range (logical pixels per second).
  static const double rainSpeedMin = 120.0;
  static const double rainSpeedMax = 280.0;

  /// Slight horizontal drift range for rain (pixels per second).
  static const double rainDriftMin = -8.0;
  static const double rainDriftMax = 8.0;

  /// Rain streak length range (logical pixels).
  static const double rainLengthMin = 6.0;
  static const double rainLengthMax = 18.0;

  // ---------------------------------------------------------------------------
  // Embers
  // ---------------------------------------------------------------------------

  /// Minimum lifetime of an ember particle (seconds).
  static const double emberLifetimeMin = 1.5;

  /// Maximum lifetime of an ember particle (seconds).
  static const double emberLifetimeMax = 3.5;

  /// Ember rise speed range (logical pixels per second, negative = upward).
  static const double emberSpeedMin = 15.0;
  static const double emberSpeedMax = 45.0;

  /// Horizontal wander amplitude for embers (pixels).
  static const double emberWanderAmplitude = 20.0;

  /// Horizontal wander frequency for embers (Hz).
  static const double emberWanderFrequency = 0.8;

  /// Ember glow pulse frequency (Hz).
  static const double emberPulseFrequency = 1.2;

  // ---------------------------------------------------------------------------
  // Mist
  // ---------------------------------------------------------------------------

  /// Minimum lifetime of a mist particle (seconds).
  static const double mistLifetimeMin = 3.0;

  /// Maximum lifetime of a mist particle (seconds).
  static const double mistLifetimeMax = 7.0;

  /// Mist drift speed range (logical pixels per second).
  static const double mistSpeedMin = 4.0;
  static const double mistSpeedMax = 12.0;

  /// Mist blob radius range (logical pixels).
  static const double mistRadiusMin = 30.0;
  static const double mistRadiusMax = 80.0;

  // ---------------------------------------------------------------------------
  // Starlight
  // ---------------------------------------------------------------------------

  /// Minimum lifetime of a starlight particle (seconds).
  static const double starlightLifetimeMin = 2.0;

  /// Maximum lifetime of a starlight particle (seconds).
  static const double starlightLifetimeMax = 5.0;

  /// Starlight twinkle frequency (Hz).
  static const double starlightTwinkleFrequency = 0.6;

  /// Starlight radius range (logical pixels).
  static const double starlightRadiusMin = 0.5;
  static const double starlightRadiusMax = 2.0;
}

/// Color palettes for each atmospheric effect.
///
/// Colors are intentionally muted and low-alpha to sit behind
/// content without drawing attention. Each effect has separate
/// palettes for dark and light themes.
class AtmosphereColors {
  AtmosphereColors._();

  // ---------------------------------------------------------------------------
  // Rain — cool blue-grey tones
  // ---------------------------------------------------------------------------

  /// Rain particle colors for dark theme.
  static const List<Color> rainDark = [
    Color(0x0D6B8FA3), // very faint blue-grey
    Color(0x0A7BA4B8), // pale steel blue
    Color(0x08809BB0), // muted cyan-grey
  ];

  /// Rain particle colors for light theme.
  static const List<Color> rainLight = [
    Color(0x0A4A6A7A), // dark blue-grey, very low alpha
    Color(0x085A7A8A), // steel blue
    Color(0x06506878), // muted teal-grey
  ];

  /// Maximum alpha for rain streaks. Kept very low so rain
  /// reads as atmospheric texture, not UI noise.
  static const double rainMaxAlpha = 0.08;

  // ---------------------------------------------------------------------------
  // Embers — warm amber-orange tones
  // ---------------------------------------------------------------------------

  /// Ember particle colors for dark theme.
  static const List<Color> emberDark = [
    Color(0x1AE8913A), // warm amber
    Color(0x18D4782E), // burnt orange
    Color(0x14C06030), // deep copper
    Color(0x10F0A050), // soft gold
  ];

  /// Ember particle colors for light theme.
  static const List<Color> emberLight = [
    Color(0x12C07030), // muted amber
    Color(0x10B06028), // terracotta
    Color(0x0EA05020), // brick red
    Color(0x0CD09040), // golden
  ];

  /// Maximum alpha for ember glow halo.
  static const double emberGlowMaxAlpha = 0.12;

  /// Ember core brightness multiplier relative to base color.
  static const double emberCoreBrightness = 1.4;

  // ---------------------------------------------------------------------------
  // Mist — translucent grey-white
  // ---------------------------------------------------------------------------

  /// Mist particle colors for dark theme.
  static const List<Color> mistDark = [
    Color(0x06A0B0C0), // pale blue-grey fog
    Color(0x05909CA8), // steel mist
    Color(0x04B0BCC8), // light haze
  ];

  /// Mist particle colors for light theme.
  static const List<Color> mistLight = [
    Color(0x06607080), // medium grey fog
    Color(0x05506070), // darker haze
    Color(0x04708090), // blue-grey mist
  ];

  /// Maximum alpha for mist blobs.
  static const double mistMaxAlpha = 0.05;

  // ---------------------------------------------------------------------------
  // Starlight — pale white-blue points
  // ---------------------------------------------------------------------------

  /// Starlight particle colors for dark theme.
  static const List<Color> starlightDark = [
    Color(0x14D0D8E8), // pale blue-white
    Color(0x10C8D0E0), // cool white
    Color(0x0CE0E8F0), // warm white
    Color(0x08B0C0D8), // faint blue
  ];

  /// Starlight particle colors for light theme.
  /// Much more subtle on light backgrounds.
  static const List<Color> starlightLight = [
    Color(0x08606878), // dark grey point
    Color(0x06505868), // muted blue-grey
    Color(0x04707880), // subtle grey
  ];

  /// Maximum alpha for starlight twinkle peak.
  static const double starlightMaxAlpha = 0.10;
}

/// Intensity mapping constants.
///
/// These define how mesh metrics map to atmospheric effect intensity.
/// Each effect has a floor (minimum visible intensity when enabled)
/// and a ceiling (maximum intensity even at extreme metric values).
class AtmosphereIntensity {
  AtmosphereIntensity._();

  // ---------------------------------------------------------------------------
  // Rain intensity (driven by packet activity / node count)
  // ---------------------------------------------------------------------------

  /// Minimum rain intensity when the effect is active (0.0-1.0).
  static const double rainFloor = 0.1;

  /// Maximum rain intensity even at peak activity.
  static const double rainCeiling = 0.7;

  /// Node count at which rain reaches full intensity.
  static const int rainNodeCountSaturation = 50;

  // ---------------------------------------------------------------------------
  // Ember intensity (driven by patina scores / relay contribution)
  // ---------------------------------------------------------------------------

  /// Minimum ember intensity when the effect is active.
  static const double emberFloor = 0.05;

  /// Maximum ember intensity.
  static const double emberCeiling = 0.6;

  /// Average patina score at which embers reach full intensity.
  static const double emberPatinaSaturation = 70.0;

  /// Relay node fraction (0.0-1.0) at which embers reach full intensity.
  static const double emberRelayFractionSaturation = 0.3;

  // ---------------------------------------------------------------------------
  // Mist intensity (driven by sparse data regions)
  // ---------------------------------------------------------------------------

  /// Minimum mist intensity when the effect is active.
  static const double mistFloor = 0.1;

  /// Maximum mist intensity.
  static const double mistCeiling = 0.5;

  /// Fraction of nodes with trait "ghost" or "unknown" at which
  /// mist reaches full intensity.
  static const double mistSparseFractionSaturation = 0.5;

  // ---------------------------------------------------------------------------
  // Starlight intensity (ambient — always gently present when enabled)
  // ---------------------------------------------------------------------------

  /// Minimum starlight intensity. Starlight is always at least this
  /// visible when the atmosphere system is enabled.
  static const double starlightFloor = 0.15;

  /// Maximum starlight intensity.
  static const double starlightCeiling = 0.4;

  // ---------------------------------------------------------------------------
  // Context-specific multipliers
  // ---------------------------------------------------------------------------

  /// Intensity multiplier for constellation screen (full effect).
  static const double constellationMultiplier = 1.0;

  /// Intensity multiplier for node detail screen (very subtle).
  static const double detailScreenMultiplier = 0.25;

  /// Intensity multiplier for map overlays (subtle, must not
  /// interfere with map readability).
  static const double mapOverlayMultiplier = 0.3;
}
