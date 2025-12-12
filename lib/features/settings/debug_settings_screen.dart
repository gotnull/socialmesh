import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging.dart';
import '../../core/theme.dart';
import '../../core/widgets/animated_mesh_node.dart';
import '../../core/widgets/animations.dart';
import '../../services/notifications/notification_service.dart';
import '../../services/storage/storage_service.dart';
import '../../utils/snackbar.dart';

/// Debug settings screen with developer tools and the mesh node playground.
/// Only accessible when ADMIN_DEBUG_MODE=true in .env
class DebugSettingsScreen extends ConsumerStatefulWidget {
  const DebugSettingsScreen({super.key});

  @override
  ConsumerState<DebugSettingsScreen> createState() =>
      _DebugSettingsScreenState();
}

class _DebugSettingsScreenState extends ConsumerState<DebugSettingsScreen> {
  // Mesh node playground state
  MeshNodeAnimationType _animationType = MeshNodeAnimationType.pulse;
  double _size = 96;
  double _glowIntensity = 0.6;
  double _lineThickness = 1.0;
  double _nodeSize = 1.0;
  bool _animate = true;
  int _selectedColorPreset = 0;
  bool _useAccelerometer = false;
  double _accelerometerSensitivity = 1.0;
  double _accelerometerFriction = 0.985;
  MeshPhysicsMode _physicsMode = MeshPhysicsMode.momentum;
  bool _enableTouch = true;
  bool _enablePullToStretch = true;
  double _touchIntensity = 1.0;

  SettingsService? _settingsService;
  bool _hasUnsavedChanges = false;

  // Color presets
  static const List<List<Color>> _colorPresets = [
    // Brand gradient (orange → magenta → blue)
    [Color(0xFFFF6B4A), Color(0xFFE91E8C), Color(0xFF4F6AF6)],
    // Cyan-Teal
    [Color(0xFF06B6D4), Color(0xFF14B8A6), Color(0xFF10B981)],
    // Sunset
    [Color(0xFFFF6B6B), Color(0xFFFF8E53), Color(0xFFFECA57)],
    // Ocean
    [Color(0xFF667EEA), Color(0xFF764BA2), Color(0xFF6B8DD6)],
    // Emerald
    [Color(0xFF059669), Color(0xFF10B981), Color(0xFF34D399)],
    // Fire
    [Color(0xFFDC2626), Color(0xFFF97316), Color(0xFFEAB308)],
    // Neon
    [Color(0xFFFF00FF), Color(0xFF00FFFF), Color(0xFF00FF00)],
    // Monochrome
    [Color(0xFFFFFFFF), Color(0xFFAAAAAA), Color(0xFF666666)],
  ];

  static const List<String> _colorPresetNames = [
    'Brand',
    'Cyan-Teal',
    'Sunset',
    'Ocean',
    'Emerald',
    'Fire',
    'Neon',
    'Mono',
  ];

  @override
  void initState() {
    super.initState();
    _loadSavedConfig();
  }

  Future<void> _loadSavedConfig() async {
    _settingsService = SettingsService();
    await _settingsService!.init();

    setState(() {
      _size = _settingsService!.splashMeshSize;
      _animationType = MeshNodeAnimationType.values.firstWhere(
        (t) => t.name == _settingsService!.splashMeshAnimationType,
        orElse: () => MeshNodeAnimationType.tumble,
      );
      _glowIntensity = _settingsService!.splashMeshGlowIntensity;
      _lineThickness = _settingsService!.splashMeshLineThickness;
      _nodeSize = _settingsService!.splashMeshNodeSize;
      _selectedColorPreset = _settingsService!.splashMeshColorPreset.clamp(
        0,
        _colorPresets.length - 1,
      );
      _useAccelerometer = _settingsService!.splashMeshUseAccelerometer;
      _accelerometerSensitivity = _settingsService!.splashMeshAccelSensitivity;
      _accelerometerFriction = _settingsService!.splashMeshAccelFriction;
      _physicsMode = MeshPhysicsMode.values.firstWhere(
        (m) => m.name == _settingsService!.splashMeshPhysicsMode,
        orElse: () => MeshPhysicsMode.momentum,
      );
      _enableTouch = _settingsService!.splashMeshEnableTouch;
      _enablePullToStretch = _settingsService!.splashMeshEnablePullToStretch;
      _touchIntensity = _settingsService!.splashMeshTouchIntensity;
      _hasUnsavedChanges = false;
    });
  }

  Future<void> _saveConfig() async {
    if (_settingsService == null) return;

    await _settingsService!.setSplashMeshConfig(
      size: _size,
      animationType: _animationType.name,
      glowIntensity: _glowIntensity,
      lineThickness: _lineThickness,
      nodeSize: _nodeSize,
      colorPreset: _selectedColorPreset,
      useAccelerometer: _useAccelerometer,
      accelerometerSensitivity: _accelerometerSensitivity,
      accelerometerFriction: _accelerometerFriction,
      physicsMode: _physicsMode.name,
      enableTouch: _enableTouch,
      enablePullToStretch: _enablePullToStretch,
      touchIntensity: _touchIntensity,
    );

    setState(() => _hasUnsavedChanges = false);
    if (mounted) {
      showSuccessSnackBar(
        context,
        'Splash mesh config saved! Restart app to apply.',
      );
    }
  }

  Future<void> _resetConfig() async {
    if (_settingsService == null) return;

    await _settingsService!.resetSplashMeshConfig();
    await _loadSavedConfig();

    if (mounted) {
      showInfoSnackBar(context, 'Splash mesh config reset to defaults');
    }
  }

  void _markChanged() {
    if (!_hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Debug Settings'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildMeshNodePlayground(),
          const SizedBox(height: 24),
          _buildNotificationTest(),
          const SizedBox(height: 24),
          _buildQuickTests(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildMeshNodePlayground() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryMagenta.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.hub,
                  color: AppTheme.primaryMagenta,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mesh Node Playground',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Test animated mesh node configurations',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Preview area
          Container(
            height: 340,
            decoration: BoxDecoration(
              color: AppTheme.darkBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.darkBorder.withAlpha(100)),
            ),
            child: Center(
              child: _useAccelerometer
                  ? AccelerometerMeshNode(
                      size: _size,
                      animationType: _animationType,
                      animate: _animate,
                      glowIntensity: _glowIntensity,
                      lineThickness: _lineThickness,
                      nodeSize: _nodeSize,
                      gradientColors: _colorPresets[_selectedColorPreset],
                      accelerometerSensitivity: _accelerometerSensitivity,
                      friction: _accelerometerFriction,
                      physicsMode: _physicsMode,
                      enableTouch: _enableTouch,
                      touchIntensity: _touchIntensity,
                    )
                  : AnimatedMeshNode(
                      size: _size,
                      animationType: _animationType,
                      animate: _animate,
                      glowIntensity: _glowIntensity,
                      lineThickness: _lineThickness,
                      nodeSize: _nodeSize,
                      gradientColors: _colorPresets[_selectedColorPreset],
                    ),
            ),
          ),
          const SizedBox(height: 20),

          // Animation Type
          _buildSectionLabel('Animation Type'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: MeshNodeAnimationType.values.map((type) {
              final isSelected = type == _animationType;
              return BouncyTap(
                onTap: () => setState(() => _animationType = type),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? context.accentColor.withAlpha(40)
                        : AppTheme.darkBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? context.accentColor
                          : AppTheme.darkBorder,
                    ),
                  ),
                  child: Text(
                    type.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: isSelected ? context.accentColor : Colors.white,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Color Preset
          _buildSectionLabel('Color Preset'),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _colorPresets.length,
              itemBuilder: (context, index) {
                final isSelected = index == _selectedColorPreset;
                final colors = _colorPresets[index];
                return Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: BouncyTap(
                    onTap: () {
                      setState(() => _selectedColorPreset = index);
                      _markChanged();
                    },
                    child: Container(
                      width: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: colors),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _colorPresetNames[index],
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            shadows: const [
                              Shadow(color: Colors.black54, blurRadius: 4),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // Size Slider
          _buildSliderRow(
            label: 'Size',
            value: _size,
            min: 24,
            max: 600,
            displayValue: '${_size.round()}px',
            onChanged: (v) {
              setState(() => _size = v);
              _markChanged();
            },
          ),
          const SizedBox(height: 16),

          // Glow Intensity Slider
          _buildSliderRow(
            label: 'Glow Intensity',
            value: _glowIntensity,
            min: 0,
            max: 1,
            displayValue: '${(_glowIntensity * 100).round()}%',
            onChanged: (v) {
              setState(() => _glowIntensity = v);
              _markChanged();
            },
          ),
          const SizedBox(height: 16),

          // Line Thickness Slider
          _buildSliderRow(
            label: 'Line Thickness',
            value: _lineThickness,
            min: 0.5,
            max: 2.0,
            displayValue: '${_lineThickness.toStringAsFixed(1)}x',
            onChanged: (v) {
              setState(() => _lineThickness = v);
              _markChanged();
            },
          ),
          const SizedBox(height: 16),

          // Node Size Slider
          _buildSliderRow(
            label: 'Node Size',
            value: _nodeSize,
            min: 0.5,
            max: 2.0,
            displayValue: '${_nodeSize.toStringAsFixed(1)}x',
            onChanged: (v) {
              setState(() => _nodeSize = v);
              _markChanged();
            },
          ),
          const SizedBox(height: 20),

          // Toggles
          Row(
            children: [
              Expanded(
                child: _buildToggle(
                  label: 'Animate',
                  value: _animate,
                  onChanged: (v) {
                    setState(() => _animate = v);
                    _markChanged();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildToggle(
                  label: 'Accelerometer',
                  value: _useAccelerometer,
                  onChanged: (v) {
                    setState(() => _useAccelerometer = v);
                    _markChanged();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Accelerometer controls (only visible when enabled)
          if (_useAccelerometer) ...[
            _buildSectionLabel('Physics Mode'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: MeshPhysicsMode.values.map((mode) {
                final isSelected = mode == _physicsMode;
                final label = switch (mode) {
                  MeshPhysicsMode.momentum => '🏀 Momentum',
                  MeshPhysicsMode.tilt => '📱 Tilt',
                  MeshPhysicsMode.gyroscope => '🎯 Gyro',
                  MeshPhysicsMode.chaos => '🌀 Chaos',
                  MeshPhysicsMode.touchOnly => '👆 Touch Only',
                };
                return BouncyTap(
                  onTap: () {
                    setState(() => _physicsMode = mode);
                    _markChanged();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? context.accentColor.withAlpha(40)
                          : AppTheme.darkBackground,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? context.accentColor
                            : AppTheme.darkBorder.withAlpha(100),
                      ),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected
                            ? context.accentColor
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            _buildSliderRow(
              label: 'Accel Sensitivity',
              value: _accelerometerSensitivity,
              min: 0.1,
              max: 3.0,
              displayValue: '${_accelerometerSensitivity.toStringAsFixed(1)}x',
              onChanged: (v) {
                setState(() => _accelerometerSensitivity = v);
                _markChanged();
              },
            ),
            const SizedBox(height: 16),
            _buildSliderRow(
              label: 'Momentum (Friction)',
              value: _accelerometerFriction,
              min: 0.9,
              max: 0.998,
              displayValue: _accelerometerFriction >= 0.99
                  ? 'High'
                  : _accelerometerFriction >= 0.97
                  ? 'Medium'
                  : 'Low',
              onChanged: (v) {
                setState(() => _accelerometerFriction = v);
                _markChanged();
              },
            ),
            const SizedBox(height: 20),

            // Touch Interaction
            _buildSectionLabel('Touch Interaction (Mario 64 Style)'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Enable Touch Rotation',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                SizedBox(
                  height: 24,
                  child: Switch.adaptive(
                    value: _enableTouch,
                    activeTrackColor: context.accentColor,
                    onChanged: (v) {
                      setState(() => _enableTouch = v);
                      _markChanged();
                    },
                  ),
                ),
              ],
            ),
            if (_enableTouch) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Enable Pull-to-Stretch',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 24,
                    child: Switch.adaptive(
                      value: _enablePullToStretch,
                      activeTrackColor: context.accentColor,
                      onChanged: (v) {
                        setState(() => _enablePullToStretch = v);
                        _markChanged();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSliderRow(
                label: 'Touch Intensity',
                value: _touchIntensity,
                min: 0.1,
                max: 2.0,
                displayValue: _touchIntensity >= 1.5
                    ? 'Wild'
                    : _touchIntensity >= 1.0
                    ? 'Normal'
                    : 'Subtle',
                onChanged: (v) {
                  setState(() => _touchIntensity = v);
                  _markChanged();
                },
              ),
            ],
            const SizedBox(height: 20),
          ],

          // Preset Buttons
          _buildSectionLabel('Quick Presets'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildPresetButton(
                  'Loading',
                  () => setState(() {
                    _animationType = MeshNodeAnimationType.pulseRotate;
                    _size = 48;
                    _glowIntensity = 0.8;
                    _selectedColorPreset = 0;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPresetButton(
                  'Hero',
                  () => setState(() {
                    _animationType = MeshNodeAnimationType.breathe;
                    _size = 128;
                    _glowIntensity = 0.7;
                    _selectedColorPreset = 0;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPresetButton(
                  'Subtle',
                  () => setState(() {
                    _animationType = MeshNodeAnimationType.pulse;
                    _size = 32;
                    _glowIntensity = 0.4;
                    _selectedColorPreset = 7;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPresetButton(
                  'Tumble',
                  () => setState(() {
                    _animationType = MeshNodeAnimationType.tumble;
                    _size = 96;
                    _glowIntensity = 1.0;
                    _selectedColorPreset = 6;
                    _useAccelerometer = false;
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildPresetButton(
                  'Splash',
                  () => setState(() {
                    _animationType = MeshNodeAnimationType.none;
                    _size = 300;
                    _glowIntensity = 0.5;
                    _lineThickness = 0.5;
                    _nodeSize = 0.8;
                    _selectedColorPreset = 0;
                    _useAccelerometer = true;
                    _accelerometerSensitivity = 1.0;
                    _accelerometerFriction = 0.985;
                    _physicsMode = MeshPhysicsMode.momentum;
                    _enableTouch = true;
                    _touchIntensity = 1.0;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPresetButton(
                  'Flick Fast',
                  () => setState(() {
                    _animationType = MeshNodeAnimationType.none;
                    _size = 200;
                    _glowIntensity = 0.8;
                    _selectedColorPreset = 0;
                    _useAccelerometer = true;
                    _accelerometerSensitivity = 2.0;
                    _accelerometerFriction = 0.96;
                    _physicsMode = MeshPhysicsMode.momentum;
                    _enableTouch = true;
                    _touchIntensity = 1.5;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPresetButton(
                  'Floaty',
                  () => setState(() {
                    _animationType = MeshNodeAnimationType.none;
                    _size = 200;
                    _glowIntensity = 0.6;
                    _selectedColorPreset = 4;
                    _useAccelerometer = true;
                    _accelerometerSensitivity = 0.8;
                    _accelerometerFriction = 0.995;
                    _physicsMode = MeshPhysicsMode.momentum;
                    _enableTouch = true;
                    _touchIntensity = 0.5;
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Additional physics presets row
          Row(
            children: [
              Expanded(
                child: _buildPresetButton(
                  'Chaos',
                  () => setState(() {
                    _animationType = MeshNodeAnimationType.none;
                    _size = 200;
                    _glowIntensity = 1.0;
                    _selectedColorPreset = 6;
                    _useAccelerometer = true;
                    _accelerometerSensitivity = 1.5;
                    _accelerometerFriction = 0.98;
                    _physicsMode = MeshPhysicsMode.chaos;
                    _enableTouch = true;
                    _touchIntensity = 2.0;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPresetButton(
                  'Tilt',
                  () => setState(() {
                    _animationType = MeshNodeAnimationType.none;
                    _size = 200;
                    _glowIntensity = 0.6;
                    _selectedColorPreset = 3;
                    _useAccelerometer = true;
                    _accelerometerSensitivity = 1.0;
                    _physicsMode = MeshPhysicsMode.tilt;
                    _enableTouch = false;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPresetButton(
                  'Mario 64',
                  () => setState(() {
                    _animationType = MeshNodeAnimationType.none;
                    _size = 250;
                    _glowIntensity = 0.7;
                    _selectedColorPreset = 0;
                    _useAccelerometer = true;
                    _accelerometerSensitivity = 0.5;
                    _accelerometerFriction = 0.99;
                    _physicsMode = MeshPhysicsMode.touchOnly;
                    _enableTouch = true;
                    _touchIntensity = 1.5;
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Code snippet
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.darkBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.darkBorder.withAlpha(100)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.code,
                      size: 14,
                      color: AppTheme.textTertiary,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Code',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    BouncyTap(
                      onTap: () {
                        // Copy to clipboard would go here
                        showInfoSnackBar(context, 'Code snippet copied!');
                      },
                      child: const Icon(
                        Icons.copy,
                        size: 14,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SelectableText(
                  _generateCodeSnippet(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Save/Reset buttons for splash screen config
          _buildSectionLabel('Splash Screen Config'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: BouncyTap(
                  onTap: _saveConfig,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _hasUnsavedChanges
                          ? context.accentColor.withAlpha(40)
                          : AppTheme.darkBackground,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _hasUnsavedChanges
                            ? context.accentColor
                            : AppTheme.darkBorder,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.save_rounded,
                          size: 18,
                          color: _hasUnsavedChanges
                              ? context.accentColor
                              : AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _hasUnsavedChanges ? 'Save Config' : 'Saved',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _hasUnsavedChanges
                                ? context.accentColor
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BouncyTap(
                  onTap: _resetConfig,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.darkBackground,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.darkBorder),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.restore_rounded,
                          size: 18,
                          color: AppTheme.textSecondary,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Reset Defaults',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_hasUnsavedChanges) ...[
            const SizedBox(height: 8),
            const Text(
              '• Changes will apply to splash/connecting screens on next app restart',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textTertiary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotificationTest() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.notifications_active,
                  color: AppTheme.primaryBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Push Notification Test',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Send a test notification to verify setup',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: BouncyTap(
              onTap: () => _sendTestNotification(),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.primaryBlue.withAlpha(60)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.send, size: 18, color: AppTheme.primaryBlue),
                    SizedBox(width: 8),
                    Text(
                      'Send Test Notification',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickTests() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.successGreen.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.science,
                  color: AppTheme.successGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Tests',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Common debug actions',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildQuickTestButton(
            icon: Icons.bug_report,
            label: 'Log Debug Info',
            onTap: () {
              AppLogging.settings('=== DEBUG INFO ===');
              AppLogging.settings('Time: ${DateTime.now()}');
              AppLogging.settings('==================');
              showInfoSnackBar(context, 'Debug info logged');
            },
          ),
          const SizedBox(height: 8),
          _buildQuickTestButton(
            icon: Icons.error_outline,
            label: 'Test Error Snackbar',
            onTap: () => showErrorSnackBar(context, 'This is a test error!'),
          ),
          const SizedBox(height: 8),
          _buildQuickTestButton(
            icon: Icons.check_circle_outline,
            label: 'Test Success Snackbar',
            onTap: () =>
                showSuccessSnackBar(context, 'This is a test success!'),
          ),
          const SizedBox(height: 8),
          _buildQuickTestButton(
            icon: Icons.info_outline,
            label: 'Test Info Snackbar',
            onTap: () => showInfoSnackBar(context, 'This is a test info!'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickTestButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return BouncyTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.darkBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.darkBorder.withAlpha(100)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppTheme.textSecondary),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(fontSize: 14, color: Colors.white),
            ),
            const Spacer(),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppTheme.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppTheme.textTertiary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required String displayValue,
    required ValueChanged<double> onChanged,
    int? divisions,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.white),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: context.accentColor,
              inactiveTrackColor: AppTheme.darkBorder,
              thumbColor: context.accentColor,
              overlayColor: context.accentColor.withAlpha(40),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 50,
          child: Text(
            displayValue,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToggle({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return BouncyTap(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: value
              ? context.accentColor.withAlpha(30)
              : AppTheme.darkBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: value ? context.accentColor : AppTheme.darkBorder,
          ),
        ),
        child: Row(
          children: [
            Icon(
              value ? Icons.check_box : Icons.check_box_outline_blank,
              size: 18,
              color: value ? context.accentColor : AppTheme.textTertiary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: value ? context.accentColor : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetButton(String label, VoidCallback onTap) {
    return BouncyTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.darkBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.darkBorder),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  String _generateCodeSnippet() {
    final colorPreset = _colorPresetNames[_selectedColorPreset];
    final hasCustomColors = _selectedColorPreset != 0;

    final widgetName = _useAccelerometer
        ? 'AccelerometerMeshNode'
        : 'AnimatedMeshNode';
    var snippet = '$widgetName(\n';
    snippet += '  size: ${_size.round()},\n';
    snippet +=
        '  animationType: MeshNodeAnimationType.${_animationType.name},\n';

    if (!_animate) {
      snippet += '  animate: false,\n';
    }
    if (_glowIntensity != 0.6) {
      snippet += '  glowIntensity: ${_glowIntensity.toStringAsFixed(2)},\n';
    }
    if (_lineThickness != 1.0) {
      snippet += '  lineThickness: ${_lineThickness.toStringAsFixed(1)},\n';
    }
    if (_nodeSize != 1.0) {
      snippet += '  nodeSize: ${_nodeSize.toStringAsFixed(1)},\n';
    }
    if (hasCustomColors) {
      snippet += '  // $colorPreset preset\n';
      snippet += '  gradientColors: [...],\n';
    }
    if (_useAccelerometer) {
      if (_accelerometerSensitivity != 1.0) {
        snippet +=
            '  accelerometerSensitivity: ${_accelerometerSensitivity.toStringAsFixed(1)},\n';
      }
      if (_accelerometerFriction != 0.985) {
        snippet +=
            '  friction: ${_accelerometerFriction.toStringAsFixed(3)},\n';
      }
    }

    snippet += ')';
    return snippet;
  }

  Future<void> _sendTestNotification() async {
    AppLogging.settings('🔔 Test notification button tapped');
    final notificationService = NotificationService();

    AppLogging.settings('🔔 Initializing notification service...');
    await notificationService.initialize();
    AppLogging.settings('🔔 Notification service initialized');

    AppLogging.settings('🔔 Showing test notification...');
    try {
      await notificationService.showNewMessageNotification(
        senderName: 'Debug Test',
        senderShortName: 'DBG',
        message: 'This is a test notification from Debug Settings.',
        fromNodeNum: 999999,
        playSound: true,
        vibrate: true,
      );
      AppLogging.settings('🔔 Test notification show() completed');
    } catch (e) {
      AppLogging.settings('🔔 Test notification error: $e');
      if (mounted) {
        showErrorSnackBar(context, 'Notification error: $e');
      }
      return;
    }

    if (mounted) {
      showInfoSnackBar(
        context,
        'Test notification sent - check notification center',
      );
    }
  }
}
