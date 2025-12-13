import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/logging.dart';
import '../core/widgets/animated_mesh_node.dart';
import '../core/widgets/secret_gesture_detector.dart';
import '../services/config/mesh_firestore_config_service.dart';

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
  final MeshPhysicsMode physicsMode;
  final bool enableTouch;
  final bool enablePullToStretch;
  final double touchIntensity;
  final double stretchIntensity;

  const SplashMeshConfig({
    this.size = 600,
    this.animationType = MeshNodeAnimationType.tumble,
    this.glowIntensity = 0.5,
    this.lineThickness = 0.5,
    this.nodeSize = 0.8,
    this.gradientColors = const [
      Color(0xFFFF6B4A),
      Color(0xFFE91E8C),
      Color(0xFF4F6AF6),
    ],
    this.useAccelerometer = true,
    this.accelerometerSensitivity = 0.5,
    this.accelerometerFriction = 0.97,
    this.physicsMode = MeshPhysicsMode.momentum,
    this.enableTouch = true,
    this.enablePullToStretch = false,
    this.touchIntensity = 0.5,
    this.stretchIntensity = 0.3,
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

/// Provider that loads splash mesh config
/// Priority: Firestore (with timeout) -> Local SharedPreferences -> Defaults
final splashMeshConfigProvider = FutureProvider<SplashMeshConfig>((ref) async {
  final prefs = await SharedPreferences.getInstance();

  // Try to fetch from Firestore first (with 3 second timeout)
  MeshConfigData? remoteConfig;
  try {
    await MeshFirestoreConfigService.instance.initialize();
    remoteConfig = await MeshFirestoreConfigService.instance
        .getRemoteConfig()
        .timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            AppLogging.settings(
              '⏱️ Firestore config fetch timed out, using local',
            );
            return null;
          },
        );

    if (remoteConfig != null) {
      AppLogging.settings('✅ Loaded mesh config from Firestore');
      // Save to local for offline use
      await _saveConfigToPrefs(prefs, remoteConfig);
    }
  } catch (e) {
    AppLogging.settings('⚠️ Firestore config fetch failed: $e');
  }

  // If we got remote config, use it
  if (remoteConfig != null) {
    return _configFromMeshConfigData(remoteConfig);
  }

  // Fall back to local SharedPreferences
  AppLogging.settings('📱 Using local mesh config');
  return _loadConfigFromPrefs(prefs);
});

/// Save MeshConfigData to SharedPreferences for offline use
Future<void> _saveConfigToPrefs(
  SharedPreferences prefs,
  MeshConfigData config,
) async {
  await prefs.setDouble('splash_mesh_size', config.size);
  await prefs.setString('splash_mesh_animation_type', config.animationType);
  await prefs.setDouble('splash_mesh_glow_intensity', config.glowIntensity);
  await prefs.setDouble('splash_mesh_line_thickness', config.lineThickness);
  await prefs.setDouble('splash_mesh_node_size', config.nodeSize);
  await prefs.setInt('splash_mesh_color_preset', config.colorPreset);
  await prefs.setBool('splash_mesh_use_accelerometer', config.useAccelerometer);
  await prefs.setDouble(
    'splash_mesh_accel_sensitivity',
    config.accelerometerSensitivity,
  );
  await prefs.setDouble(
    'splash_mesh_accel_friction',
    config.accelerometerFriction,
  );
  await prefs.setString('splash_mesh_physics_mode', config.physicsMode);
  await prefs.setBool('splash_mesh_enable_touch', config.enableTouch);
  await prefs.setBool(
    'splash_mesh_enable_pull_to_stretch',
    config.enablePullToStretch,
  );
  await prefs.setDouble('splash_mesh_touch_intensity', config.touchIntensity);
  await prefs.setDouble(
    'splash_mesh_stretch_intensity',
    config.stretchIntensity,
  );
  // Also save secret gesture config
  await prefs.setString(
    'secret_gesture_pattern',
    config.secretGesturePattern,
  );
  await prefs.setInt(
    'secret_gesture_time_window',
    config.secretGestureTimeWindowMs,
  );
  await prefs.setBool(
    'secret_gesture_show_feedback',
    config.secretGestureShowFeedback,
  );
  await prefs.setBool(
    'secret_gesture_enable_haptics',
    config.secretGestureEnableHaptics,
  );
}

/// Convert MeshConfigData to SplashMeshConfig
SplashMeshConfig _configFromMeshConfigData(MeshConfigData data) {
  final colorPreset = data.colorPreset.clamp(
    0,
    splashMeshColorPresets.length - 1,
  );

  return SplashMeshConfig(
    size: data.size,
    animationType: data.animationTypeEnum,
    glowIntensity: data.glowIntensity,
    lineThickness: data.lineThickness,
    nodeSize: data.nodeSize,
    gradientColors: splashMeshColorPresets[colorPreset],
    useAccelerometer: data.useAccelerometer,
    accelerometerSensitivity: data.accelerometerSensitivity,
    accelerometerFriction: data.accelerometerFriction,
    physicsMode: data.physicsModeEnum,
    enableTouch: data.enableTouch,
    enablePullToStretch: data.enablePullToStretch,
    touchIntensity: data.touchIntensity,
    stretchIntensity: data.stretchIntensity,
  );
}

/// Load config from SharedPreferences
SplashMeshConfig _loadConfigFromPrefs(SharedPreferences prefs) {
  final size = prefs.getDouble('splash_mesh_size') ?? 600;
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
      prefs.getDouble('splash_mesh_accel_sensitivity') ?? 0.5;
  final accelFriction = prefs.getDouble('splash_mesh_accel_friction') ?? 0.97;
  final physicsModeName =
      prefs.getString('splash_mesh_physics_mode') ?? 'momentum';
  final enableTouch = prefs.getBool('splash_mesh_enable_touch') ?? true;
  final enablePullToStretch =
      prefs.getBool('splash_mesh_enable_pull_to_stretch') ?? false;
  final touchIntensity = prefs.getDouble('splash_mesh_touch_intensity') ?? 0.5;
  final stretchIntensity =
      prefs.getDouble('splash_mesh_stretch_intensity') ?? 0.3;

  final animationType = MeshNodeAnimationType.values.firstWhere(
    (t) => t.name == animationTypeName,
    orElse: () => MeshNodeAnimationType.none,
  );

  final physicsMode = MeshPhysicsMode.values.firstWhere(
    (m) => m.name == physicsModeName,
    orElse: () => MeshPhysicsMode.momentum,
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
    physicsMode: physicsMode,
    enableTouch: enableTouch,
    enablePullToStretch: enablePullToStretch,
    touchIntensity: touchIntensity,
    stretchIntensity: stretchIntensity,
  );
}

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
    // ALWAYS use AccelerometerMeshNode for touch support
    // When accelerometer is disabled, use touchOnly physics mode
    //
    // Use OverflowBox to allow the mesh to render at full size
    // while only taking up limited layout space. This prevents
    // large mesh sizes from pushing down the text below.
    const maxLayoutSize = 200.0;
    final meshSize = config.size;

    return SizedBox(
      width: maxLayoutSize,
      height: maxLayoutSize,
      child: OverflowBox(
        maxWidth: meshSize,
        maxHeight: meshSize,
        child: AccelerometerMeshNode(
          size: meshSize,
          animationType: config.animationType,
          glowIntensity: config.glowIntensity,
          lineThickness: config.lineThickness,
          nodeSize: config.nodeSize,
          gradientColors: config.gradientColors,
          accelerometerSensitivity: config.accelerometerSensitivity,
          friction: config.accelerometerFriction,
          // When accelerometer disabled, use touchOnly mode (no sensor input)
          physicsMode: config.useAccelerometer
              ? config.physicsMode
              : MeshPhysicsMode.touchOnly,
          enableTouch: config.enableTouch,
          enablePullToStretch: config.enablePullToStretch,
          touchIntensity: config.touchIntensity,
          stretchIntensity: config.stretchIntensity,
        ),
      ),
    );
  }
}

/// Configuration for secret gesture
class SecretGestureConfig {
  final SecretGesturePattern pattern;
  final Duration timeWindow;
  final bool showFeedback;
  final bool enableHaptics;

  const SecretGestureConfig({
    this.pattern = SecretGesturePattern.sevenTaps,
    this.timeWindow = const Duration(seconds: 3),
    this.showFeedback = true,
    this.enableHaptics = true,
  });

  static const SecretGestureConfig defaultConfig = SecretGestureConfig();
}

/// Provider that loads secret gesture config
/// Priority: Firestore (with timeout) -> Local SharedPreferences -> Defaults
final secretGestureConfigProvider =
    FutureProvider<SecretGestureConfig>((ref) async {
  final prefs = await SharedPreferences.getInstance();

  // Try to fetch from Firestore first (with 3 second timeout)
  MeshConfigData? remoteConfig;
  try {
    await MeshFirestoreConfigService.instance.initialize();
    remoteConfig = await MeshFirestoreConfigService.instance
        .getRemoteConfig()
        .timeout(
          const Duration(seconds: 3),
          onTimeout: () => null,
        );

    if (remoteConfig != null) {
      // Save to local for offline use
      await prefs.setString(
          'secret_gesture_pattern', remoteConfig.secretGesturePattern);
      await prefs.setInt(
          'secret_gesture_time_window', remoteConfig.secretGestureTimeWindowMs);
      await prefs.setBool(
          'secret_gesture_show_feedback', remoteConfig.secretGestureShowFeedback);
      await prefs.setBool(
          'secret_gesture_enable_haptics', remoteConfig.secretGestureEnableHaptics);

      return SecretGestureConfig(
        pattern: SecretGesturePattern.values.firstWhere(
          (p) => p.name == remoteConfig!.secretGesturePattern,
          orElse: () => SecretGesturePattern.sevenTaps,
        ),
        timeWindow:
            Duration(milliseconds: remoteConfig.secretGestureTimeWindowMs),
        showFeedback: remoteConfig.secretGestureShowFeedback,
        enableHaptics: remoteConfig.secretGestureEnableHaptics,
      );
    }
  } catch (e) {
    AppLogging.settings('⚠️ Secret gesture config fetch failed: $e');
  }

  // Fall back to local SharedPreferences
  final patternName =
      prefs.getString('secret_gesture_pattern') ?? 'sevenTaps';
  final timeWindowMs = prefs.getInt('secret_gesture_time_window') ?? 3000;
  final showFeedback = prefs.getBool('secret_gesture_show_feedback') ?? true;
  final enableHaptics = prefs.getBool('secret_gesture_enable_haptics') ?? true;

  final pattern = SecretGesturePattern.values.firstWhere(
    (p) => p.name == patternName,
    orElse: () => SecretGesturePattern.sevenTaps,
  );

  return SecretGestureConfig(
    pattern: pattern,
    timeWindow: Duration(milliseconds: timeWindowMs),
    showFeedback: showFeedback,
    enableHaptics: enableHaptics,
  );
});
