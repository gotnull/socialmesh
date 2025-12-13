import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging.dart';
import '../../core/theme.dart';
import '../../core/widgets/animated_mesh_node.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/secret_gesture_detector.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../services/config/mesh_firestore_config_service.dart';
import '../../services/notifications/notification_service.dart';
import '../../services/storage/storage_service.dart';
import '../../utils/snackbar.dart';

/// Debug settings screen with developer tools and the mesh node playground.
/// Accessible via secret 7-tap gesture on the Socialmesh tile in About section.
class DebugSettingsScreen extends ConsumerStatefulWidget {
  const DebugSettingsScreen({super.key});

  @override
  ConsumerState<DebugSettingsScreen> createState() =>
      _DebugSettingsScreenState();
}

class _DebugSettingsScreenState extends ConsumerState<DebugSettingsScreen> {
  // Mesh node playground state - defaults match user requirements
  MeshNodeAnimationType _animationType = MeshNodeAnimationType.tumble;
  double _size = 600;
  double _glowIntensity = 0.5;
  double _lineThickness = 0.5;
  double _nodeSize = 0.8;
  bool _animate = true;
  int _selectedColorPreset = 0; // Brand
  bool _useAccelerometer = true;
  double _accelerometerSensitivity = 0.5;
  double _accelerometerFriction = 0.97; // Low friction
  MeshPhysicsMode _physicsMode = MeshPhysicsMode.momentum;
  bool _enableTouch = true;
  bool _enablePullToStretch = false;
  double _touchIntensity = 0.5; // Subtle
  double _stretchIntensity = 0.3;

  // Secret gesture configuration
  SecretGesturePattern _secretPattern = SecretGesturePattern.sevenTaps;
  Duration _secretTimeWindow = const Duration(seconds: 3);
  bool _secretShowFeedback = true;
  bool _secretEnableHaptics = true;

  // Save location preference
  MeshConfigSaveLocation _saveLocation = MeshConfigSaveLocation.localDevice;
  bool _globalPinVerified = false;
  static const String _globalSavePin = '4511932';

  SettingsService? _settingsService;
  bool _hasUnsavedChanges = false;
  bool _isLoadingRemote = false;

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
      _stretchIntensity = _settingsService!.splashMeshStretchIntensity;
      // Load secret gesture config
      _secretPattern = SecretGesturePattern.values.firstWhere(
        (p) => p.name == _settingsService!.secretGesturePattern,
        orElse: () => SecretGesturePattern.sevenTaps,
      );
      _secretTimeWindow = Duration(
        milliseconds: _settingsService!.secretGestureTimeWindowMs,
      );
      _secretShowFeedback = _settingsService!.secretGestureShowFeedback;
      _secretEnableHaptics = _settingsService!.secretGestureEnableHaptics;
      _hasUnsavedChanges = false;
    });
  }

  Future<void> _saveConfig() async {
    if (_settingsService == null) return;

    // Require PIN for global saves
    if (_saveLocation == MeshConfigSaveLocation.global && !_globalPinVerified) {
      final verified = await _showPinDialog();
      if (!verified) return;
      setState(() => _globalPinVerified = true);
    }

    // Always save to local storage
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
      stretchIntensity: _stretchIntensity,
    );

    // Also save secret gesture config to local
    await _settingsService!.setSecretGestureConfig(
      pattern: _secretPattern.name,
      timeWindowMs: _secretTimeWindow.inMilliseconds,
      showFeedback: _secretShowFeedback,
      enableHaptics: _secretEnableHaptics,
    );

    // If global, also save to Firestore
    if (_saveLocation == MeshConfigSaveLocation.global) {
      final config = MeshConfigData(
        size: _size,
        animationType: _animationType.name,
        animate: _animate,
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
        stretchIntensity: _stretchIntensity,
        secretGesturePattern: _secretPattern.name,
        secretGestureTimeWindowMs: _secretTimeWindow.inMilliseconds,
        secretGestureShowFeedback: _secretShowFeedback,
        secretGestureEnableHaptics: _secretEnableHaptics,
      );

      await MeshFirestoreConfigService.instance.initialize();
      final success = await MeshFirestoreConfigService.instance.saveConfig(
        config,
      );

      if (!success && mounted) {
        showErrorSnackBar(context, 'Failed to save to Firestore');
        return;
      }
    }

    setState(() => _hasUnsavedChanges = false);

    final locationText = _saveLocation == MeshConfigSaveLocation.localDevice
        ? 'this device'
        : 'all devices (Firestore)';

    if (mounted) {
      showSuccessSnackBar(
        context,
        'Mesh config saved to $locationText! Restart app to apply.',
      );
    }
  }

  Future<void> _loadFromFirestore() async {
    setState(() => _isLoadingRemote = true);

    try {
      await MeshFirestoreConfigService.instance.initialize();
      final remoteConfig = await MeshFirestoreConfigService.instance
          .getRemoteConfig();

      if (remoteConfig != null) {
        setState(() {
          _size = remoteConfig.size;
          _animationType = remoteConfig.animationTypeEnum;
          _animate = remoteConfig.animate;
          _glowIntensity = remoteConfig.glowIntensity;
          _lineThickness = remoteConfig.lineThickness;
          _nodeSize = remoteConfig.nodeSize;
          _selectedColorPreset = remoteConfig.colorPreset.clamp(
            0,
            _colorPresets.length - 1,
          );
          _useAccelerometer = remoteConfig.useAccelerometer;
          _accelerometerSensitivity = remoteConfig.accelerometerSensitivity;
          _accelerometerFriction = remoteConfig.accelerometerFriction;
          _physicsMode = remoteConfig.physicsModeEnum;
          _enableTouch = remoteConfig.enableTouch;
          _enablePullToStretch = remoteConfig.enablePullToStretch;
          _touchIntensity = remoteConfig.touchIntensity;
          _stretchIntensity = remoteConfig.stretchIntensity;
          // Load secret gesture config
          _secretPattern = SecretGesturePattern.values.firstWhere(
            (p) => p.name == remoteConfig.secretGesturePattern,
            orElse: () => SecretGesturePattern.sevenTaps,
          );
          _secretTimeWindow = Duration(
            milliseconds: remoteConfig.secretGestureTimeWindowMs,
          );
          _secretShowFeedback = remoteConfig.secretGestureShowFeedback;
          _secretEnableHaptics = remoteConfig.secretGestureEnableHaptics;
          _hasUnsavedChanges = true;
        });

        if (mounted) {
          showSuccessSnackBar(context, '✅ Loaded config from Firestore');
        }
      } else {
        if (mounted) {
          showInfoSnackBar(context, 'No config found in Firestore');
        }
      }
    } catch (e) {
      AppLogging.settings('Failed to load from Firestore: $e');
      if (mounted) {
        showErrorSnackBar(context, 'Failed to load from Firestore');
      }
    } finally {
      setState(() => _isLoadingRemote = false);
    }
  }

  Future<bool> _showPinDialog() async {
    var enteredPin = '';
    var attempts = 0;
    const maxAttempts = 3;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          void onKeyPress(String key) {
            if (key == 'del') {
              if (enteredPin.isNotEmpty) {
                setDialogState(() {
                  enteredPin = enteredPin.substring(0, enteredPin.length - 1);
                });
              }
            } else if (key == 'ok') {
              if (enteredPin == _globalSavePin) {
                Navigator.of(dialogContext).pop(true);
              } else {
                attempts++;
                if (attempts >= maxAttempts) {
                  Navigator.of(dialogContext).pop(false);
                  showErrorSnackBar(
                    this.context,
                    'Too many incorrect attempts',
                  );
                } else {
                  setDialogState(() => enteredPin = '');
                  showErrorSnackBar(
                    this.context,
                    'Incorrect PIN (${maxAttempts - attempts} attempts left)',
                  );
                }
              }
            } else if (enteredPin.length < 10) {
              setDialogState(() => enteredPin += key);
            }
          }

          Widget buildKey(String label, {double flex = 1, Color? color}) {
            final isSpecial = label == 'DEL' || label == 'OK';
            final keyColor = color ?? const Color(0xFF8B7BA8);

            return Expanded(
              flex: flex.toInt(),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: GestureDetector(
                  onTap: () => onKeyPress(label.toLowerCase()),
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          keyColor.withAlpha(200),
                          keyColor.withAlpha(150),
                          keyColor.withAlpha(100),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border(
                        top: BorderSide(
                          color: keyColor.withAlpha(255),
                          width: 2,
                        ),
                        left: BorderSide(
                          color: keyColor.withAlpha(230),
                          width: 2,
                        ),
                        right: BorderSide(
                          color: keyColor.withAlpha(80),
                          width: 2,
                        ),
                        bottom: BorderSide(
                          color: keyColor.withAlpha(60),
                          width: 3,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(80),
                          offset: const Offset(2, 3),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: isSpecial ? 14 : 22,
                          fontWeight: FontWeight.w600,
                          color: keyColor.withAlpha(180),
                          shadows: [
                            Shadow(
                              color: Colors.black.withAlpha(100),
                              offset: const Offset(1, 1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }

          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              width: 280,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF1A1A2E), Color(0xFF0F0F1A)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF8B7BA8).withAlpha(60),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(150),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        color: const Color(0xFF8B7BA8),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'GLOBAL SAVE PIN',
                        style: TextStyle(
                          color: Color(0xFF8B7BA8),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // PIN Display
                  Container(
                    width: double.infinity,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A0A12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF8B7BA8).withAlpha(40),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        enteredPin.isEmpty
                            ? '• • • • • • •'
                            : '•' * enteredPin.length,
                        style: TextStyle(
                          fontSize: 24,
                          letterSpacing: 8,
                          color: enteredPin.isEmpty
                              ? const Color(0xFF8B7BA8).withAlpha(60)
                              : const Color(0xFF8B7BA8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Keypad
                  Row(children: [buildKey('7'), buildKey('8'), buildKey('9')]),
                  Row(children: [buildKey('4'), buildKey('5'), buildKey('6')]),
                  Row(children: [buildKey('1'), buildKey('2'), buildKey('3')]),
                  Row(
                    children: [
                      buildKey('DEL', color: const Color(0xFF6B5B7A)),
                      buildKey('0'),
                      buildKey('OK', color: const Color(0xFF5B8B6B)),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Attempts remaining
                  if (attempts > 0)
                    Text(
                      '${maxAttempts - attempts} attempts remaining',
                      style: TextStyle(
                        color: AppTheme.errorRed.withAlpha(200),
                        fontSize: 12,
                      ),
                    ),

                  const SizedBox(height: 8),

                  // Cancel button
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: Text(
                      'CANCEL',
                      style: TextStyle(
                        color: const Color(0xFF8B7BA8).withAlpha(150),
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    return result ?? false;
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
      body: Column(
        children: [
          // Scrollable content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildMeshNodePlayground(),
                const SizedBox(height: 24),
                _buildNotificationTest(),
                const SizedBox(height: 24),
                _buildQuickTests(),
                const SizedBox(height: 24),
                _buildSecretGestureConfig(),
                const SizedBox(height: 16),
              ],
            ),
          ),
          // Fixed bottom action bar
          _buildFixedBottomBar(),
        ],
      ),
    );
  }

  Widget _buildFixedBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        border: Border(
          top: BorderSide(color: AppTheme.darkBorder.withAlpha(150)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(60),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Save Location Toggle
            Row(
              children: [
                const Text(
                  'Save to:',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: AppTheme.darkBackground,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.darkBorder.withAlpha(100),
                      ),
                    ),
                    child: Row(
                      children: MeshConfigSaveLocation.values.map((location) {
                        final isSelected = location == _saveLocation;
                        return Expanded(
                          child: BouncyTap(
                            onTap: () {
                              setState(() => _saveLocation = location);
                              _markChanged();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? context.accentColor.withAlpha(40)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    location.icon,
                                    size: 14,
                                    color: isSelected
                                        ? context.accentColor
                                        : AppTheme.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    location ==
                                            MeshConfigSaveLocation.localDevice
                                        ? 'Local'
                                        : 'Global',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: isSelected
                                          ? context.accentColor
                                          : AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Load from Firestore mini button
                BouncyTap(
                  onTap: _isLoadingRemote ? null : _loadFromFirestore,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.primaryBlue.withAlpha(60),
                      ),
                    ),
                    child: _isLoadingRemote
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: MeshLoadingIndicator(
                              size: 18,
                              colors: [
                                AppTheme.primaryBlue,
                                Colors.cyan,
                                Colors.lightBlue,
                              ],
                            ),
                          )
                        : const Icon(
                            Icons.cloud_download_rounded,
                            size: 18,
                            color: AppTheme.primaryBlue,
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Save/Reset buttons
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: BouncyTap(
                    onTap: _saveConfig,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        gradient: _hasUnsavedChanges
                            ? LinearGradient(
                                colors: [
                                  context.accentColor.withAlpha(60),
                                  context.accentColor.withAlpha(40),
                                ],
                              )
                            : null,
                        color: _hasUnsavedChanges
                            ? null
                            : AppTheme.darkBackground,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _hasUnsavedChanges
                              ? context.accentColor
                              : AppTheme.darkBorder,
                          width: _hasUnsavedChanges ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _saveLocation == MeshConfigSaveLocation.global
                                ? Icons.cloud_upload_rounded
                                : Icons.save_rounded,
                            size: 18,
                            color: _hasUnsavedChanges
                                ? context.accentColor
                                : AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _hasUnsavedChanges
                                ? (_saveLocation ==
                                          MeshConfigSaveLocation.global
                                      ? 'Save to Cloud'
                                      : 'Save Local')
                                : 'Saved',
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
                const SizedBox(width: 10),
                Expanded(
                  child: BouncyTap(
                    onTap: _resetConfig,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
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
                          SizedBox(width: 6),
                          Text(
                            'Reset',
                            style: TextStyle(
                              fontSize: 13,
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
              const SizedBox(height: 6),
              Text(
                'Restart app to apply splash screen changes',
                style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.textTertiary.withAlpha(180),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
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

          // Preview area - wrapped to prevent scroll interference
          GestureDetector(
            // Absorb vertical drags so scrollview doesn't scroll when interacting with mesh
            onVerticalDragStart: (_) {},
            onVerticalDragUpdate: (_) {},
            onVerticalDragEnd: (_) {},
            child: Container(
              height: (_size + 40).clamp(200, 500),
              decoration: BoxDecoration(
                color: AppTheme.darkBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.darkBorder.withAlpha(100)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // ALWAYS use AccelerometerMeshNode - physicsMode.touchOnly disables accelerometer
                  AccelerometerMeshNode(
                    size: _size,
                    animationType: _animationType,
                    animate: _animate,
                    glowIntensity: _glowIntensity,
                    lineThickness: _lineThickness,
                    nodeSize: _nodeSize,
                    gradientColors: _colorPresets[_selectedColorPreset],
                    accelerometerSensitivity: _accelerometerSensitivity,
                    friction: _accelerometerFriction,
                    // When accelerometer disabled, use touchOnly mode
                    physicsMode: _useAccelerometer
                        ? _physicsMode
                        : MeshPhysicsMode.touchOnly,
                    enableTouch: _enableTouch,
                    enablePullToStretch: _enablePullToStretch,
                    touchIntensity: _touchIntensity,
                    stretchIntensity: _stretchIntensity,
                  ),
                  // Size indicator overlay
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${_size.toInt()}px (1:1)',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white70,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ],
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
            divisions: 144, // steps of 4px
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
            divisions: 20, // steps of 5%
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
            divisions: 15, // steps of 0.1
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
            divisions: 15, // steps of 0.1
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

          // Accelerometer-specific controls (only when enabled)
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
              divisions: 29, // steps of 0.1
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
              divisions: 49, // steps of 0.002
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
          ],

          // Touch Interaction - ALWAYS visible (works with or without accelerometer)
          _buildSectionLabel('Touch Interaction (Mario 64 Style)'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Enable Touch Rotation',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Enable Pull-to-Stretch',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
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
            divisions: 19, // steps of 0.1
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
          const SizedBox(height: 16),
          // Only show stretch intensity when pull-to-stretch is enabled
          if (_enablePullToStretch)
            _buildSliderRow(
              label: 'Stretch Intensity',
              value: _stretchIntensity,
              min: 0.1,
              max: 1.0,
              divisions: 9, // steps of 0.1
              displayValue: _stretchIntensity >= 0.7
                  ? 'Extreme'
                  : _stretchIntensity >= 0.4
                  ? 'Normal'
                  : 'Subtle',
              onChanged: (v) {
                setState(() => _stretchIntensity = v);
                _markChanged();
              },
            ),
          const SizedBox(height: 20),

          // JSON Config Display
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
                      Icons.data_object,
                      size: 14,
                      color: AppTheme.textTertiary,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'JSON Config',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    BouncyTap(
                      onTap: () {
                        Clipboard.setData(
                          ClipboardData(text: _generateJsonConfig()),
                        );
                        showInfoSnackBar(context, 'JSON config copied!');
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
                  _generateJsonConfig(),
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

  Widget _buildSecretGestureConfig() {
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
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryPurple.withAlpha(60),
                      AppTheme.primaryBlue.withAlpha(40),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.gesture,
                  color: AppTheme.primaryPurple,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Secret Gesture Config',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Configure hidden access patterns',
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
          const SizedBox(height: 20),

          // Pattern selector
          _buildSectionLabel('GESTURE PATTERN'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppTheme.darkBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<SecretGesturePattern>(
                value: _secretPattern,
                isExpanded: true,
                dropdownColor: AppTheme.darkCard,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  color: AppTheme.textSecondary,
                ),
                items: SecretGesturePattern.values.map((pattern) {
                  return DropdownMenuItem(
                    value: pattern,
                    child: Row(
                      children: [
                        Icon(
                          _getPatternIcon(pattern),
                          size: 18,
                          color: AppTheme.primaryPurple,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              pattern.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              _getPatternDescription(pattern),
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppTheme.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _secretPattern = value;
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Time window slider
          _buildSliderRow(
            label: 'Time Window',
            value: _secretTimeWindow.inMilliseconds.toDouble(),
            min: 1000,
            max: 10000,
            divisions: 18,
            displayValue:
                '${(_secretTimeWindow.inMilliseconds / 1000).toStringAsFixed(1)}s',
            onChanged: (v) => setState(() {
              _secretTimeWindow = Duration(milliseconds: v.toInt());
            }),
          ),
          const SizedBox(height: 16),

          // Toggle options
          _buildToggle(
            label: 'Show Feedback',
            value: _secretShowFeedback,
            onChanged: (v) => setState(() => _secretShowFeedback = v),
          ),
          const SizedBox(height: 8),
          _buildToggle(
            label: 'Enable Haptics',
            value: _secretEnableHaptics,
            onChanged: (v) => setState(() => _secretEnableHaptics = v),
          ),
          const SizedBox(height: 20),

          // Test area
          _buildSectionLabel('TEST GESTURE'),
          const SizedBox(height: 8),
          SecretGestureDetector(
            pattern: _secretPattern,
            timeWindow: _secretTimeWindow,
            showFeedback: _secretShowFeedback,
            enableHaptics: _secretEnableHaptics,
            onSecretUnlocked: () {
              showSuccessSnackBar(
                context,
                '✨ Secret gesture triggered! Pattern: ${_secretPattern.name}',
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryPurple.withAlpha(20),
                    AppTheme.primaryBlue.withAlpha(20),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryPurple.withAlpha(60)),
              ),
              child: Column(
                children: [
                  Icon(
                    _getPatternIcon(_secretPattern),
                    size: 32,
                    color: AppTheme.primaryPurple.withAlpha(180),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Test ${_secretPattern.name} here',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getPatternInstructions(_secretPattern),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textTertiary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Generated code snippet
          _buildSectionLabel('CODE SNIPPET'),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2E),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.darkBorder.withAlpha(100)),
            ),
            child: SelectableText(
              _generateGestureCodeSnippet(),
              style: const TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: Color(0xFFA6E3A1),
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
          BouncyTap(
            onTap: () {
              Clipboard.setData(
                ClipboardData(text: _generateGestureCodeSnippet()),
              );
              showSuccessSnackBar(context, 'Code copied to clipboard');
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.primaryPurple.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.primaryPurple.withAlpha(60)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.copy, size: 16, color: AppTheme.primaryPurple),
                  SizedBox(width: 8),
                  Text(
                    'Copy Code Snippet',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryPurple,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getPatternIcon(SecretGesturePattern pattern) {
    return switch (pattern) {
      SecretGesturePattern.sevenTaps => Icons.touch_app,
      SecretGesturePattern.triforce => Icons.change_history,
      SecretGesturePattern.konami => Icons.gamepad,
      SecretGesturePattern.holdAndTap => Icons.pan_tool,
      SecretGesturePattern.spiral => Icons.rotate_right,
    };
  }

  String _getPatternDescription(SecretGesturePattern pattern) {
    return switch (pattern) {
      SecretGesturePattern.sevenTaps => 'Tap multiple times rapidly',
      SecretGesturePattern.triforce => 'Draw a triangle pattern',
      SecretGesturePattern.konami => '↑↑↓↓←→←→ swipe sequence',
      SecretGesturePattern.holdAndTap => 'Hold + tap with another finger',
      SecretGesturePattern.spiral => 'Draw a spiral gesture',
    };
  }

  String _getPatternInstructions(SecretGesturePattern pattern) {
    return switch (pattern) {
      SecretGesturePattern.sevenTaps =>
        'Tap 7 times within ${(_secretTimeWindow.inMilliseconds / 1000).toStringAsFixed(1)}s',
      SecretGesturePattern.triforce =>
        'Draw a triangle: tap 3 corners in order',
      SecretGesturePattern.konami => 'Swipe: ↑ ↑ ↓ ↓ ← → ← → (like the code!)',
      SecretGesturePattern.holdAndTap =>
        'Hold with one finger, tap with another',
      SecretGesturePattern.spiral => 'Draw a clockwise spiral from center',
    };
  }

  String _generateGestureCodeSnippet() {
    final buffer = StringBuffer();
    buffer.writeln('SecretGestureDetector(');
    buffer.writeln('  pattern: SecretGesturePattern.${_secretPattern.name},');
    buffer.writeln(
      '  timeWindow: Duration(milliseconds: ${_secretTimeWindow.inMilliseconds}),',
    );
    buffer.writeln('  showFeedback: $_secretShowFeedback,');
    buffer.writeln('  enableHaptics: $_secretEnableHaptics,');
    buffer.writeln('  onSecretUnlocked: () {');
    buffer.writeln('    // Your secret action here');
    buffer.writeln('  },');
    buffer.writeln('  child: YourWidget(),');
    buffer.writeln(')');
    return buffer.toString();
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

  String _generateJsonConfig() {
    final config = {
      'size': _size.round(),
      'animationType': _animationType.name,
      'animate': _animate,
      'glowIntensity': double.parse(_glowIntensity.toStringAsFixed(2)),
      'lineThickness': double.parse(_lineThickness.toStringAsFixed(2)),
      'nodeSize': double.parse(_nodeSize.toStringAsFixed(2)),
      'colorPreset': _colorPresetNames[_selectedColorPreset],
      'useAccelerometer': _useAccelerometer,
      'accelerometerSensitivity': double.parse(
        _accelerometerSensitivity.toStringAsFixed(2),
      ),
      'friction': double.parse(_accelerometerFriction.toStringAsFixed(3)),
      'physicsMode': _physicsMode.name,
      'enableTouch': _enableTouch,
      'enablePullToStretch': _enablePullToStretch,
      'touchIntensity': double.parse(_touchIntensity.toStringAsFixed(2)),
      'stretchIntensity': double.parse(_stretchIntensity.toStringAsFixed(2)),
    };

    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(config);
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
