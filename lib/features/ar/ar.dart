// SPDX-License-Identifier: GPL-3.0-or-later
// AR Node Radar - Production Augmented Reality mesh node visualization
//
// This module provides AR visualization of mesh nodes at their real-world
// GPS positions using the device camera, sensors, and Kalman-filtered fusion.
//
// ## Architecture
//
// ```
// ┌─────────────────────────────────────────────────────────────┐
// │                      AR RADAR SCREEN                         │
// │  ┌─────────────────────────────────────────────────────┐    │
// │  │                 Camera Preview                       │    │
// │  │  ┌─────────────────────────────────────────────┐    │    │
// │  │  │              AR HUD Painter                  │    │    │
// │  │  │  • Node markers with threat levels          │    │    │
// │  │  │  • Compass tape & horizon line              │    │    │
// │  │  │  • Altimeter & crosshair                    │    │    │
// │  │  │  • Cluster visualization                    │    │    │
// │  │  │  • Alert panels & scan effects              │    │    │
// │  │  └─────────────────────────────────────────────┘    │    │
// │  └─────────────────────────────────────────────────────┘    │
// └─────────────────────────────────────────────────────────────┘
//                              │
//                              ▼
// ┌─────────────────────────────────────────────────────────────┐
// │                       AR STATE                               │
// │  • arStateProvider - Riverpod 3.x state management          │
// │  • arEngineProvider - Sensor fusion engine                  │
// │  • visibleARNodesProvider - Filtered node list              │
// │  • arStatsProvider - Statistics                             │
// └─────────────────────────────────────────────────────────────┘
//                              │
//                              ▼
// ┌─────────────────────────────────────────────────────────────┐
// │                      AR ENGINE                               │
// │  ┌───────────┐  ┌───────────┐  ┌───────────┐               │
// │  │Accelero-  │  │Magneto-   │  │Gyroscope  │               │
// │  │meter      │  │meter      │  │           │               │
// │  └─────┬─────┘  └─────┬─────┘  └─────┬─────┘               │
// │        │              │              │                      │
// │        └──────────────┼──────────────┘                      │
// │                       ▼                                     │
// │           Kalman Filter + Complementary Filter              │
// │           (98% gyro / 2% accel-mag blending)                │
// │                       │                                     │
// │                       ▼                                     │
// │              AROrientation                                  │
// │              (heading, pitch, roll)                         │
// └─────────────────────────────────────────────────────────────┘
// ```
//
// ## Usage
//
// ```dart
// Navigator.push(
//   context,
//   MaterialPageRoute(builder: (_) => const ARRadarScreen()),
// );
//
// final arState = ref.watch(arStateProvider);
// final visibleNodes = ref.watch(visibleARNodesProvider);
// ```

export 'ar_calibration.dart';
export 'ar_engine.dart';
export 'ar_hud_painter.dart';
export 'ar_radar_screen.dart';
export 'ar_state.dart';
export 'widgets/ar_calibration_screen.dart';
export 'widgets/ar_mini_radar.dart';
export 'widgets/ar_node_detail_card.dart';
export 'widgets/ar_settings_panel.dart';
export 'widgets/ar_view_mode_selector.dart';
