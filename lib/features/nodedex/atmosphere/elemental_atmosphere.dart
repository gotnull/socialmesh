// SPDX-License-Identifier: GPL-3.0-or-later

// Elemental Atmosphere — barrel export.
//
// The Elemental Atmosphere is an optional ambient visual system that
// renders data-driven particle effects behind NodeDex and map views.
// Effects are purely cosmetic, non-interactive, and never obstruct
// content. The system respects reduce-motion preferences and
// auto-throttles on low-end devices.
//
// Four effect types:
//   Rain      — vertical streaks tied to packet activity / node count
//   Embers    — rising sparks tied to patina scores / relay contribution
//   Mist      — drifting fog tied to sparse data regions
//   Starlight — ambient twinkling background particles
//
// Quick start:
//
// 1. Enable the system:
//    ref.read(atmosphereEnabledProvider.notifier).setEnabled(true);
//
// 2. Add an overlay to your screen:
//    Stack(
//      children: [
//        const ConstellationAtmosphere(), // or DetailAtmosphere(), MapAtmosphere()
//        // your content here
//      ],
//    )
//
// 3. Effects are automatically data-driven from NodeDex providers.
//    No manual intensity configuration is needed.

// Configuration constants
export 'atmosphere_config.dart';

// Core particle engine
export 'particle_system.dart';

// Data adapter (mesh metrics -> intensity values)
export 'atmosphere_data_adapter.dart';

// Riverpod providers
export 'atmosphere_provider.dart';

// Composable overlay widget
export 'atmosphere_overlay.dart';

// Individual effect types
export 'effects/rain_effect.dart';
export 'effects/ember_effect.dart';
export 'effects/mist_effect.dart';
export 'effects/starlight_effect.dart';
