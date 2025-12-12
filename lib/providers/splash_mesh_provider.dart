import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/widgets/animated_mesh_node.dart';

/// Configuration for the splash/connecting screen mesh node
class SplashMeshConfig {
  final double size;
  final MeshNodeAnimationType animationType;
  final double glowIntensity;
  final double lineThickness;
  final double nodeSize;
  final List<Color> gradientColors;
  final bool useAccelerometer;
  final double accelerometerSensitivity;
  final double accelerometerFriction;

  const SplashMeshConfig({
    this.size = 300,
    this.animationType = MeshNodeAnimationType.none,
    this.glowIntensity = 0.5,
    this.lineThickness = 0.5,
    this.nodeSize = 0.8,
    this.gradientColors = const [
      Color(0xFFFF6B4A),
      Color(0xFFE91E8C),
      Color(0xFF4F6AF6),
    ],
    this.useAccelerometer = true,
    this.accelerometerSensitivity = 1.0,
    this.accelerometerFriction = 0.985,
  });

  /// Default configuration
  static const SplashMeshConfig defaultConfig = SplashMeshConfig();
}

/// Color presets matching the debug settings screen
const List<List<Color>> splashMeshColorPresets = [
  [Color(0xFFFF6B4A), Color(0xFFE91E8C), Color(0xFF4F6AF6)], // Brand
  [Color(0xFF06B6D4), Color(0xFF14B8A6), Color(0xFF10B981)], // Cyan-Teal
  [Color(0xFFFF6B6B), Color(0xFFFF8E53), Color(0xFFFECA57)], // Sunset
  [Color(0xFF667EEA), Color(0xFF764BA2), Color(0xFF6B8DD6)], // Ocean
  [Color(0xFF059669), Color(0xFF10B981), Color(0xFF34D399)], // Emerald
  [Color(0xFFDC2626), Color(0xFFF97316), Color(0xFFEAB308)], // Fire
  [Color(0xFFFF00FF), Color(0xFF00FFFF), Color(0xFF00FF00)], // Neon
  [Color(0xFFFFFFFF), Color(0xFFAAAAAA), Color(0xFF666666)], // Mono
];

/// Provider that loads splash mesh config from SharedPreferences
final splashMeshConfigProvider = FutureProvider<SplashMeshConfig>((ref) async {
  final prefs = await SharedPreferences.getInstance();

  final size = prefs.getDouble('splash_mesh_size') ?? 300;
  final animationTypeName =
      prefs.getString('splash_mesh_animation_type') ?? 'none';
  final glowIntensity = prefs.getDouble('splash_mesh_glow_intensity') ?? 0.5;
  final lineThickness = prefs.getDouble('splash_mesh_line_thickness') ?? 0.5;
  final nodeSize = prefs.getDouble('splash_mesh_node_size') ?? 0.8;
  final colorPreset = (prefs.getInt('splash_mesh_color_preset') ?? 0).clamp(
    0,
    splashMeshColorPresets.length - 1,
  );
  final useAccelerometer =
      prefs.getBool('splash_mesh_use_accelerometer') ?? true;
  final accelSensitivity =
      prefs.getDouble('splash_mesh_accel_sensitivity') ?? 1.0;
  final accelFriction = prefs.getDouble('splash_mesh_accel_friction') ?? 0.985;

  final animationType = MeshNodeAnimationType.values.firstWhere(
    (t) => t.name == animationTypeName,
    orElse: () => MeshNodeAnimationType.none,
  );

  return SplashMeshConfig(
    size: size,
    animationType: animationType,
    glowIntensity: glowIntensity,
    lineThickness: lineThickness,
    nodeSize: nodeSize,
    gradientColors: splashMeshColorPresets[colorPreset],
    useAccelerometer: useAccelerometer,
    accelerometerSensitivity: accelSensitivity,
    accelerometerFriction: accelFriction,
  );
});

/// Widget that displays the configured splash mesh node
class ConfiguredSplashMeshNode extends ConsumerWidget {
  const ConfiguredSplashMeshNode({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(splashMeshConfigProvider);

    return configAsync.when(
      data: (config) => _buildMeshNode(config),
      loading: () => _buildMeshNode(SplashMeshConfig.defaultConfig),
      error: (_, _) => _buildMeshNode(SplashMeshConfig.defaultConfig),
    );
  }

  Widget _buildMeshNode(SplashMeshConfig config) {
    if (config.useAccelerometer) {
      return AccelerometerMeshNode(
        size: config.size,
        animationType: config.animationType,
        glowIntensity: config.glowIntensity,
        lineThickness: config.lineThickness,
        nodeSize: config.nodeSize,
        gradientColors: config.gradientColors,
        accelerometerSensitivity: config.accelerometerSensitivity,
        friction: config.accelerometerFriction,
      );
    } else {
      return AnimatedMeshNode(
        size: config.size,
        animationType: config.animationType,
        glowIntensity: config.glowIntensity,
        lineThickness: config.lineThickness,
        nodeSize: config.nodeSize,
        gradientColors: config.gradientColors,
      );
    }
  }
}
