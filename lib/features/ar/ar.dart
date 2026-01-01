// AR Node Radar - Augmented Reality mesh node visualization
//
// This module provides AR visualization of mesh nodes at their real-world
// GPS positions using the device camera and sensors.
//
// ## Architecture
//
// ```
// ┌─────────────────────────────────────────────────────────────┐
// │                      AR RADAR SCREEN                         │
// │  ┌─────────────────────────────────────────────────────┐    │
// │  │                 Camera Preview                       │    │
// │  │  ┌─────────────────────────────────────────────┐    │    │
// │  │  │             AR Overlay Painter               │    │    │
// │  │  │  • Node markers at 3D positions             │    │    │
// │  │  │  • Off-screen indicators                    │    │    │
// │  │  │  • Compass & horizon line                   │    │    │
// │  │  │  • Distance & signal labels                 │    │    │
// │  │  └─────────────────────────────────────────────┘    │    │
// │  └─────────────────────────────────────────────────────┘    │
// └─────────────────────────────────────────────────────────────┘
//                              │
//                              ▼
// ┌─────────────────────────────────────────────────────────────┐
// │                     AR PROVIDERS                             │
// │  • arViewProvider - State management                        │
// │  • arServiceProvider - Sensor service                       │
// │  • sortedARNodesProvider - Sorted node list                │
// │  • arStatsProvider - Statistics                             │
// └─────────────────────────────────────────────────────────────┘
//                              │
//                              ▼
// ┌─────────────────────────────────────────────────────────────┐
// │                      AR SERVICE                              │
// │  ┌───────────┐  ┌───────────┐  ┌───────────┐               │
// │  │Accelero-  │  │Magneto-   │  │Gyroscope  │               │
// │  │meter      │  │meter      │  │           │               │
// │  └─────┬─────┘  └─────┬─────┘  └─────┬─────┘               │
// │        │              │              │                      │
// │        └──────────────┼──────────────┘                      │
// │                       ▼                                     │
// │              Sensor Fusion                                  │
// │              (Low-pass filter)                              │
// │                       │                                     │
// │                       ▼                                     │
// │           ARDeviceOrientation                               │
// │           (heading, pitch, roll)                            │
// └─────────────────────────────────────────────────────────────┘
//                              │
//                              ▼
// ┌─────────────────────────────────────────────────────────────┐
// │                      AR MODELS                               │
// │  • ARNode - Node position in AR space                       │
// │  • ARScreenPosition - Screen coordinates                    │
// │  • ARDeviceOrientation - Sensor data                        │
// │  • ARConfig - View configuration                            │
// │  • calculateBearing/Distance/Elevation - Geo math          │
// └─────────────────────────────────────────────────────────────┘
// ```
//
// ## Usage
//
// ```dart
// // Navigate to AR view
// Navigator.push(
//   context,
//   MaterialPageRoute(builder: (_) => const ARRadarScreen()),
// );
//
// // Access AR state from anywhere
// final arState = ref.watch(arViewProvider);
// final visibleNodes = ref.watch(visibleARNodesProvider);
// ```
//
// ## Extending the Framework
//
// ### Adding new AR elements
//
// 1. Add element type to `ARElementType` enum in ar_models.dart
// 2. Create painter method in `AROverlayPainter`
// 3. Add configuration options to `ARConfig`
//
// ### Adding new sensors
//
// 1. Add subscription in `ARService.start()`
// 2. Create callback handler
// 3. Integrate into sensor fusion in `_updateOrientation()`
//
// ### Adding new overlays
//
// 1. Create new CustomPainter or Widget
// 2. Stack on top of AROverlay in ARRadarScreen
// 3. Use arViewProvider for orientation/position data

export 'ar_models.dart';
export 'ar_mini_radar.dart';
export 'ar_overlay_painter.dart';
export 'ar_providers.dart';
export 'ar_radar_screen.dart';
export 'ar_service.dart';
