import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/logging.dart';
import '../core/widgets/animated_mesh_node.dart';
import '../core/widgets/node_names_mesh.dart';
import '../core/widgets/secret_gesture_detector.dart';
import '../features/onboarding/widgets/mesh_node_brain.dart';
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
  await prefs.setString('secret_gesture_pattern', config.secretGesturePattern);
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
/// Bounces in from size 0 once config is loaded - no blip!
class ConfiguredSplashMeshNode extends ConsumerStatefulWidget {
  /// Optional override for layout size (default 200)
  final double? layoutSize;

  /// Whether to use bounce-in animation (default true)
  final bool animateIn;

  /// Duration of bounce-in animation
  final Duration animationDuration;

  /// Whether to show node names on the mesh vertices during initialization
  final bool showNodeNames;

  const ConfiguredSplashMeshNode({
    super.key,
    this.layoutSize,
    this.animateIn = true,
    this.animationDuration = const Duration(milliseconds: 800),
    this.showNodeNames = false,
  });

  @override
  ConsumerState<ConfiguredSplashMeshNode> createState() =>
      _ConfiguredSplashMeshNodeState();
}

class _ConfiguredSplashMeshNodeState
    extends ConsumerState<ConfiguredSplashMeshNode>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _hasAnimated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );

    // Bouncy overshoot curve for that "mascot" feel
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(splashMeshConfigProvider);

    return configAsync.when(
      data: (config) {
        // Start animation when config loads (only once)
        if (!_hasAnimated && widget.animateIn) {
          _hasAnimated = true;
          // Small delay to ensure widget is mounted
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _controller.forward();
            }
          });
        }
        return _buildAnimatedMeshNode(config);
      },
      // While loading, show nothing (size 0) - no default config blip!
      loading: () => SizedBox(
        width: widget.layoutSize ?? 200,
        height: widget.layoutSize ?? 200,
      ),
      error: (_, _) {
        // On error, still animate in with defaults
        if (!_hasAnimated && widget.animateIn) {
          _hasAnimated = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _controller.forward();
            }
          });
        }
        return _buildAnimatedMeshNode(SplashMeshConfig.defaultConfig);
      },
    );
  }

  Widget _buildAnimatedMeshNode(SplashMeshConfig config) {
    final layoutSize = widget.layoutSize ?? 200.0;
    final meshSize = config.size;

    // Use NodeNamesMeshNode when showNodeNames is enabled
    final meshWidget = widget.showNodeNames
        ? NodeNamesMeshNode(
            size: meshSize,
            animationType: config.animationType,
            glowIntensity: config.glowIntensity,
            lineThickness: config.lineThickness,
            nodeSize: config.nodeSize,
            gradientColors: config.gradientColors,
            showNodeNames: true,
            namesOrbitWithMesh: true,
          )
        : AccelerometerMeshNode(
            size: meshSize,
            animationType: config.animationType,
            glowIntensity: config.glowIntensity,
            lineThickness: config.lineThickness,
            nodeSize: config.nodeSize,
            gradientColors: config.gradientColors,
            accelerometerSensitivity: config.accelerometerSensitivity,
            friction: config.accelerometerFriction,
            physicsMode: config.useAccelerometer
                ? config.physicsMode
                : MeshPhysicsMode.touchOnly,
            enableTouch: config.enableTouch,
            enablePullToStretch: config.enablePullToStretch,
            touchIntensity: config.touchIntensity,
            stretchIntensity: config.stretchIntensity,
          );

    return SizedBox(
      width: layoutSize,
      height: layoutSize,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          final scale = widget.animateIn ? _scaleAnimation.value : 1.0;
          return Transform.scale(scale: scale, child: child);
        },
        child: OverflowBox(
          maxWidth: meshSize,
          maxHeight: meshSize,
          child: meshWidget,
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
final secretGestureConfigProvider = FutureProvider<SecretGestureConfig>((
  ref,
) async {
  final prefs = await SharedPreferences.getInstance();

  // Try to fetch from Firestore first (with 3 second timeout)
  MeshConfigData? remoteConfig;
  try {
    await MeshFirestoreConfigService.instance.initialize();
    remoteConfig = await MeshFirestoreConfigService.instance
        .getRemoteConfig()
        .timeout(const Duration(seconds: 3), onTimeout: () => null);

    if (remoteConfig != null) {
      // Save to local for offline use
      await prefs.setString(
        'secret_gesture_pattern',
        remoteConfig.secretGesturePattern,
      );
      await prefs.setInt(
        'secret_gesture_time_window',
        remoteConfig.secretGestureTimeWindowMs,
      );
      await prefs.setBool(
        'secret_gesture_show_feedback',
        remoteConfig.secretGestureShowFeedback,
      );
      await prefs.setBool(
        'secret_gesture_enable_haptics',
        remoteConfig.secretGestureEnableHaptics,
      );

      return SecretGestureConfig(
        pattern: SecretGesturePattern.values.firstWhere(
          (p) => p.name == remoteConfig!.secretGesturePattern,
          orElse: () => SecretGesturePattern.sevenTaps,
        ),
        timeWindow: Duration(
          milliseconds: remoteConfig.secretGestureTimeWindowMs,
        ),
        showFeedback: remoteConfig.secretGestureShowFeedback,
        enableHaptics: remoteConfig.secretGestureEnableHaptics,
      );
    }
  } catch (e) {
    AppLogging.settings('⚠️ Secret gesture config fetch failed: $e');
  }

  // Fall back to local SharedPreferences
  final patternName = prefs.getString('secret_gesture_pattern') ?? 'sevenTaps';
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

/// A mini mesh node that replaces CircularProgressIndicator
/// The app's mascot/brain - used for all loading states
/// Bounces in when loading starts, bounces out when loading finishes
class MeshLoadingIndicator extends StatefulWidget {
  /// Size of the loading indicator (default 24 for icon-like usage)
  final double size;

  /// Custom colors (uses brand gradient by default)
  final List<Color>? colors;

  /// Animation type (defaults to tumble for loading feel)
  final MeshNodeAnimationType animationType;

  /// Glow intensity (default 0.6 for visibility)
  final double glowIntensity;

  /// Whether currently loading - when false, bounces out to 0
  final bool isLoading;

  const MeshLoadingIndicator({
    super.key,
    this.size = 24,
    this.colors,
    this.animationType = MeshNodeAnimationType.tumble,
    this.glowIntensity = 0.6,
    this.isLoading = true,
  });

  /// Convenience constructor that wraps a child and shows/hides based on loading
  static Widget withChild({
    Key? key,
    required bool isLoading,
    required Widget child,
    double size = 48,
    List<Color>? colors,
    MeshNodeAnimationType animationType = MeshNodeAnimationType.tumble,
    double glowIntensity = 0.6,
  }) {
    return _MeshLoadingWithChild(
      key: key,
      isLoading: isLoading,
      size: size,
      colors: colors,
      animationType: animationType,
      glowIntensity: glowIntensity,
      child: child,
    );
  }

  @override
  State<MeshLoadingIndicator> createState() => _MeshLoadingIndicatorState();
}

class _MeshLoadingIndicatorState extends State<MeshLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _hasCompletedOut = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
      reverseCurve: Curves.easeInBack,
    );

    // Bounce in on mount if loading
    if (widget.isLoading) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(MeshLoadingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isLoading != oldWidget.isLoading) {
      if (widget.isLoading) {
        // Bounce in
        _hasCompletedOut = false;
        _controller.forward();
      } else {
        // Bounce out
        _controller.reverse().then((_) {
          if (mounted) {
            setState(() => _hasCompletedOut = true);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // After bounce-out completes, render nothing to free up space
    if (_hasCompletedOut) {
      return const SizedBox.shrink();
    }

    final colors =
        widget.colors ??
        const [Color(0xFFFF6B4A), Color(0xFFE91E8C), Color(0xFF4F6AF6)];

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(scale: _scaleAnimation.value, child: child);
      },
      child: AccelerometerMeshNode(
        size: widget.size,
        animationType: widget.animationType,
        glowIntensity: widget.glowIntensity,
        lineThickness: 0.6,
        nodeSize: 1.0,
        gradientColors: colors,
        accelerometerSensitivity: 0.3,
        friction: 0.95,
        physicsMode: MeshPhysicsMode.momentum,
        enableTouch: false, // Loading indicator shouldn't be interactive
        enablePullToStretch: false,
      ),
    );
  }
}

/// Helper widget that shows MeshLoadingIndicator while loading, then bounces out and shows child
class _MeshLoadingWithChild extends StatefulWidget {
  final bool isLoading;
  final Widget child;
  final double size;
  final List<Color>? colors;
  final MeshNodeAnimationType animationType;
  final double glowIntensity;

  const _MeshLoadingWithChild({
    super.key,
    required this.isLoading,
    required this.child,
    this.size = 48,
    this.colors,
    this.animationType = MeshNodeAnimationType.tumble,
    this.glowIntensity = 0.6,
  });

  @override
  State<_MeshLoadingWithChild> createState() => _MeshLoadingWithChildState();
}

class _MeshLoadingWithChildState extends State<_MeshLoadingWithChild>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _loaderScale;
  late Animation<double> _childScale;
  late Animation<double> _childOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _loaderScale = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeInBack),
      ),
    );

    _childScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.elasticOut),
      ),
    );

    _childOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.7, curve: Curves.easeOut),
      ),
    );

    if (!widget.isLoading) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(_MeshLoadingWithChild oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading != oldWidget.isLoading) {
      if (widget.isLoading) {
        _controller.reverse();
      } else {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors =
        widget.colors ??
        const [Color(0xFFFF6B4A), Color(0xFFE91E8C), Color(0xFF4F6AF6)];

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // Show loader while loading (or transitioning out)
        if (_controller.value < 0.5) {
          return Transform.scale(
            scale: _loaderScale.value,
            child: AccelerometerMeshNode(
              size: widget.size,
              animationType: widget.animationType,
              glowIntensity: widget.glowIntensity,
              lineThickness: 0.6,
              nodeSize: 1.0,
              gradientColors: colors,
              accelerometerSensitivity: 0.3,
              friction: 0.95,
              physicsMode: MeshPhysicsMode.momentum,
              enableTouch: false,
              enablePullToStretch: false,
            ),
          );
        }

        // Show child bouncing in
        return Opacity(
          opacity: _childOpacity.value,
          child: Transform.scale(scale: _childScale.value, child: widget.child),
        );
      },
    );
  }
}

/// A bouncy mesh node that can be used as a button or interactive element
class MeshMascot extends StatefulWidget {
  /// Size of the mascot
  final double size;

  /// Custom colors
  final List<Color>? colors;

  /// Animation type
  final MeshNodeAnimationType animationType;

  /// Called when tapped
  final VoidCallback? onTap;

  /// Whether to bounce in
  final bool bounceIn;

  /// Whether to pulse gently
  final bool pulse;

  const MeshMascot({
    super.key,
    this.size = 80,
    this.colors,
    this.animationType = MeshNodeAnimationType.breathe,
    this.onTap,
    this.bounceIn = true,
    this.pulse = false,
  });

  @override
  State<MeshMascot> createState() => _MeshMascotState();
}

class _MeshMascotState extends State<MeshMascot> with TickerProviderStateMixin {
  late AnimationController _bounceController;
  late AnimationController _pulseController;
  late Animation<double> _bounceAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Bounce-in animation
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _bounceAnimation = CurvedAnimation(
      parent: _bounceController,
      curve: Curves.elasticOut,
    );

    // Subtle pulse animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.bounceIn) {
      _bounceController.forward();
    } else {
      _bounceController.value = 1.0;
    }

    if (widget.pulse) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.onTap != null) {
      // Quick bounce effect on tap
      _bounceController.forward(from: 0.8);
      widget.onTap!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors =
        widget.colors ??
        const [Color(0xFFFF6B4A), Color(0xFFE91E8C), Color(0xFF4F6AF6)];

    Widget mesh = AccelerometerMeshNode(
      size: widget.size,
      animationType: widget.animationType,
      glowIntensity: 0.5,
      lineThickness: 0.5,
      nodeSize: 0.8,
      gradientColors: colors,
      accelerometerSensitivity: 0.5,
      friction: 0.97,
      physicsMode: MeshPhysicsMode.momentum,
      enableTouch: true,
      enablePullToStretch: false,
      touchIntensity: 0.5,
    );

    // Apply pulse animation
    if (widget.pulse) {
      mesh = AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(scale: _pulseAnimation.value, child: child);
        },
        child: mesh,
      );
    }

    // Apply bounce-in animation
    mesh = AnimatedBuilder(
      animation: _bounceAnimation,
      builder: (context, child) {
        return Transform.scale(scale: _bounceAnimation.value, child: child);
      },
      child: mesh,
    );

    if (widget.onTap != null) {
      return GestureDetector(onTap: _handleTap, child: mesh);
    }

    return mesh;
  }
}

/// Full-screen loading indicator using Ico (MeshNodeBrain) with loading mood.
/// Use this for centered loading states on screens (larger, more prominent).
class ScreenLoadingIndicator extends ConsumerWidget {
  /// Size of Ico (default 100 for screen-level loading)
  final double size;

  /// Optional message to show below Ico
  final String? message;

  /// Custom colors for Ico
  final List<Color>? colors;

  const ScreenLoadingIndicator({
    super.key,
    this.size = 100,
    this.message,
    this.colors,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meshConfigAsync = ref.watch(splashMeshConfigProvider);
    final meshConfig = meshConfigAsync.value ?? const SplashMeshConfig();

    // Use SizedBox.expand + Center to ensure true centering in available space
    return SizedBox.expand(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MeshNodeBrain(
              size: size,
              mood: MeshBrainMood.loading,
              colors: colors,
              glowIntensity: 0.8,
              lineThickness: meshConfig.lineThickness,
              nodeSize: meshConfig.nodeSize,
              interactive: false,
              showThoughtParticles: true,
              showExpression: true,
            ),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message!,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
