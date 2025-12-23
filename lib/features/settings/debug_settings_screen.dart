import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging.dart';
import '../../core/theme.dart';
import '../../core/widgets/animated_mesh_node.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/secret_gesture_detector.dart';
import '../../models/user_profile.dart';
import '../../providers/profile_providers.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../services/config/mesh_firestore_config_service.dart';
import '../../services/notifications/notification_service.dart';
import '../../services/storage/storage_service.dart';
import '../../utils/snackbar.dart';
import '../intro/intro_animation_preview_screen.dart';
import '../widget_builder/marketplace/widget_approval_screen.dart';

/// Debug settings screen with developer tools and the mesh node playground.
/// Accessible via secret 7-tap gesture on the Socialmesh tile in About section.
class DebugSettingsScreen extends ConsumerStatefulWidget {
  const DebugSettingsScreen({super.key});

  @override
  ConsumerState<DebugSettingsScreen> createState() =>
      _DebugSettingsScreenState();
}

class _DebugSettingsScreenState extends ConsumerState<DebugSettingsScreen> {
  // Section expansion states
  bool _meshNodeExpanded = true;
  bool _introAnimationsExpanded = false;
  bool _notificationExpanded = false;
  bool _quickTestsExpanded = false;
  bool _secretGestureExpanded = false;
  bool _adminToolsExpanded = false;

  // Mesh node playground state - defaults match user requirements
  MeshNodeAnimationType _animationType = MeshNodeAnimationType.tumble;
  double _size = 600;
  double _glowIntensity = 0.5;
  double _lineThickness = 0.5;
  double _nodeSize = 0.8;
  bool _animate = true;
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

  SettingsService? _settingsService;
  bool _hasUnsavedChanges = false;
  bool _isLoadingRemote = false;

  @override
  void initState() {
    super.initState();
    _loadSavedConfig();
  }

  Future<void> _loadSavedConfig() async {
    _settingsService = SettingsService();
    await _settingsService!.init();

    // Try to load from global Firestore first (this is what users see)
    try {
      await MeshFirestoreConfigService.instance.initialize();
      final remoteConfig = await MeshFirestoreConfigService.instance
          .getRemoteConfig();

      if (remoteConfig != null) {
        AppLogging.settings(
          '📡 Debug settings: Loaded global config from Firestore',
        );
        setState(() {
          _size = remoteConfig.size;
          _animationType = remoteConfig.animationTypeEnum;
          _animate = remoteConfig.animate;
          _glowIntensity = remoteConfig.glowIntensity;
          _lineThickness = remoteConfig.lineThickness;
          _nodeSize = remoteConfig.nodeSize;
          // Color is now controlled by accent color in Theme settings
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
          _hasUnsavedChanges = false;
          _saveLocation = MeshConfigSaveLocation.global;
        });
        return;
      }
    } catch (e) {
      AppLogging.settings(
        '⚠️ Debug settings: Failed to load global config: $e',
      );
    }

    // Fallback to local settings
    setState(() {
      _size = _settingsService!.splashMeshSize;
      _animationType = MeshNodeAnimationType.values.firstWhere(
        (t) => t.name == _settingsService!.splashMeshAnimationType,
        orElse: () => MeshNodeAnimationType.tumble,
      );
      _glowIntensity = _settingsService!.splashMeshGlowIntensity;
      _lineThickness = _settingsService!.splashMeshLineThickness;
      _nodeSize = _settingsService!.splashMeshNodeSize;
      // Color is now controlled by accent color in Theme settings
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

    // Always save to local storage
    await _settingsService!.setSplashMeshConfig(
      size: _size,
      animationType: _animationType.name,
      glowIntensity: _glowIntensity,
      lineThickness: _lineThickness,
      nodeSize: _nodeSize,
      useAccelerometer: _useAccelerometer,
      accelerometerSensitivity: _accelerometerSensitivity,
      accelerometerFriction: _accelerometerFriction,
      physicsMode: _physicsMode.name,
      enableTouch: _enableTouch,
      enablePullToStretch: _enablePullToStretch,
      touchIntensity: _touchIntensity,
      stretchIntensity: _stretchIntensity,
    );

    // Sync splash mesh config to cloud profile
    ref
        .read(userProfileProvider.notifier)
        .updatePreferences(
          UserPreferences(
            splashMeshSize: _size,
            splashMeshAnimationType: _animationType.name,
            splashMeshGlowIntensity: _glowIntensity,
            splashMeshLineThickness: _lineThickness,
            splashMeshNodeSize: _nodeSize,
            splashMeshUseAccelerometer: _useAccelerometer,
            splashMeshAccelSensitivity: _accelerometerSensitivity,
            splashMeshAccelFriction: _accelerometerFriction,
            splashMeshPhysicsMode: _physicsMode.name,
            splashMeshEnableTouch: _enableTouch,
            splashMeshEnablePullToStretch: _enablePullToStretch,
            splashMeshTouchIntensity: _touchIntensity,
            splashMeshStretchIntensity: _stretchIntensity,
          ),
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

    // Invalidate providers so changes take effect immediately
    ref.invalidate(splashMeshConfigProvider);
    ref.invalidate(secretGestureConfigProvider);

    final locationText = _saveLocation == MeshConfigSaveLocation.localDevice
        ? 'this device'
        : 'all devices (Firestore)';

    if (mounted) {
      showSuccessSnackBar(context, 'Mesh config saved to $locationText!');
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

  Future<void> _resetConfig() async {
    if (_settingsService == null) return;

    await _settingsService!.resetSplashMeshConfig();
    await _loadSavedConfig();

    // Invalidate the splash mesh provider so changes take effect immediately
    ref.invalidate(splashMeshConfigProvider);

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
        actions: [
          // Quick expand/collapse all
          IconButton(
            onPressed: () {
              final allExpanded =
                  _meshNodeExpanded &&
                  _introAnimationsExpanded &&
                  _notificationExpanded &&
                  _quickTestsExpanded &&
                  _secretGestureExpanded;
              setState(() {
                _meshNodeExpanded = !allExpanded;
                _introAnimationsExpanded = !allExpanded;
                _notificationExpanded = !allExpanded;
                _quickTestsExpanded = !allExpanded;
                _secretGestureExpanded = !allExpanded;
              });
            },
            icon: Icon(
              _meshNodeExpanded &&
                      _introAnimationsExpanded &&
                      _notificationExpanded &&
                      _quickTestsExpanded &&
                      _secretGestureExpanded
                  ? Icons.unfold_less_rounded
                  : Icons.unfold_more_rounded,
              color: AppTheme.textSecondary,
            ),
            tooltip: 'Expand/Collapse all',
          ),
        ],
      ),
      body: Column(
        children: [
          // Scrollable content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildCollapsibleSection(
                  title: 'Mesh Node Playground',
                  subtitle: 'Test animated mesh configurations',
                  icon: Icons.hub_rounded,
                  iconColor: AppTheme.primaryMagenta,
                  isExpanded: _meshNodeExpanded,
                  onToggle: () =>
                      setState(() => _meshNodeExpanded = !_meshNodeExpanded),
                  child: _buildMeshNodeContent(),
                ),
                const SizedBox(height: 12),
                _buildCollapsibleSection(
                  title: 'Intro Animations',
                  subtitle: 'Preview splash screen animations',
                  icon: Icons.movie_filter_rounded,
                  iconColor: const Color(0xFF00E5FF),
                  isExpanded: _introAnimationsExpanded,
                  onToggle: () => setState(
                    () => _introAnimationsExpanded = !_introAnimationsExpanded,
                  ),
                  child: _buildIntroAnimationsContent(),
                ),
                const SizedBox(height: 12),
                _buildCollapsibleSection(
                  title: 'Push Notifications',
                  subtitle: 'Test notification delivery',
                  icon: Icons.notifications_rounded,
                  iconColor: AppTheme.accentOrange,
                  isExpanded: _notificationExpanded,
                  onToggle: () => setState(
                    () => _notificationExpanded = !_notificationExpanded,
                  ),
                  child: _buildNotificationContent(),
                ),
                const SizedBox(height: 12),
                _buildCollapsibleSection(
                  title: 'Quick Tests',
                  subtitle: 'Debug utilities',
                  icon: Icons.bug_report_rounded,
                  iconColor: AppTheme.primaryBlue,
                  isExpanded: _quickTestsExpanded,
                  onToggle: () => setState(
                    () => _quickTestsExpanded = !_quickTestsExpanded,
                  ),
                  child: _buildQuickTestsContent(),
                ),
                const SizedBox(height: 12),
                _buildCollapsibleSection(
                  title: 'Secret Gesture Config',
                  subtitle: 'Configure unlock gesture',
                  icon: Icons.gesture_rounded,
                  iconColor: AppTheme.primaryPurple,
                  isExpanded: _secretGestureExpanded,
                  onToggle: () => setState(
                    () => _secretGestureExpanded = !_secretGestureExpanded,
                  ),
                  child: _buildSecretGestureContent(),
                ),
                const SizedBox(height: 12),
                _buildCollapsibleSection(
                  title: 'Admin Tools',
                  subtitle: 'Marketplace moderation',
                  icon: Icons.admin_panel_settings_rounded,
                  iconColor: AppTheme.accentOrange,
                  isExpanded: _adminToolsExpanded,
                  onToggle: () => setState(
                    () => _adminToolsExpanded = !_adminToolsExpanded,
                  ),
                  child: _buildAdminToolsContent(),
                ),
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

  Widget _buildCollapsibleSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool isExpanded,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded ? iconColor.withAlpha(60) : AppTheme.darkBorder,
        ),
      ),
      child: Column(
        children: [
          // Header - always visible
          BouncyTap(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: iconColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: isExpanded ? iconColor : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Content - collapsible
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: child,
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
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

  Widget _buildIntroAnimationsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          height: 1,
          color: AppTheme.darkBorder.withAlpha(60),
        ),
        // Description
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            'Browse through all splash screen intro animations including '
            'classic demoscene and cracktro effects.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ),
        // Launch preview button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const IntroAnimationPreviewScreen(),
                ),
              );
            },
            icon: const Icon(Icons.play_circle_filled_rounded),
            label: const Text('Preview All Animations'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF).withAlpha(30),
              foregroundColor: const Color(0xFF00E5FF),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFF00E5FF), width: 1),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Info chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.darkSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.darkBorder.withAlpha(60)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                size: 16,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Swipe left/right or tap arrows to browse. Tap screen to toggle controls.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMeshNodeContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Divider
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          height: 1,
          color: AppTheme.darkBorder.withAlpha(60),
        ),

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
                  gradientColors: gradientColorsFromAccent(context.accentColor),
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
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? context.accentColor : Colors.white,
                  ),
                ),
              ),
            );
          }).toList(),
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
            const Expanded(
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
            const Expanded(
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
    );
  }

  Widget _buildNotificationContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Divider
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          height: 1,
          color: AppTheme.darkBorder.withAlpha(60),
        ),
        SizedBox(
          width: double.infinity,
          child: BouncyTap(
            onTap: () => _sendTestNotification(),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.accentOrange.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.accentOrange.withAlpha(60)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.send_rounded,
                    size: 18,
                    color: AppTheme.accentOrange,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Send Test Notification',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.accentOrange,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickTestsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Divider
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 1,
          color: AppTheme.darkBorder.withAlpha(60),
        ),
        _buildQuickTestButton(
          icon: Icons.bug_report_rounded,
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
          icon: Icons.error_outline_rounded,
          label: 'Test Error Snackbar',
          onTap: () => showErrorSnackBar(context, 'This is a test error!'),
        ),
        const SizedBox(height: 8),
        _buildQuickTestButton(
          icon: Icons.check_circle_outline_rounded,
          label: 'Test Success Snackbar',
          onTap: () => showSuccessSnackBar(context, 'This is a test success!'),
        ),
        const SizedBox(height: 8),
        _buildQuickTestButton(
          icon: Icons.info_outline_rounded,
          label: 'Test Info Snackbar',
          onTap: () => showInfoSnackBar(context, 'This is a test info!'),
        ),
        const SizedBox(height: 8),
        _buildQuickTestButton(
          icon: Icons.psychology_rounded,
          label: 'Mesh Brain Emotions',
          onTap: () => Navigator.pushNamed(context, '/emotion-test'),
        ),
      ],
    );
  }

  Widget _buildSecretGestureContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Divider
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          height: 1,
          color: AppTheme.darkBorder.withAlpha(60),
        ),

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
                            style: const TextStyle(fontWeight: FontWeight.w500),
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
                Icon(
                  Icons.copy_rounded,
                  size: 16,
                  color: AppTheme.primaryPurple,
                ),
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
    );
  }

  Widget _buildAdminToolsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Divider
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          height: 1,
          color: AppTheme.darkBorder.withAlpha(60),
        ),

        // Widget Approval
        _buildSectionLabel('MARKETPLACE MODERATION'),
        const SizedBox(height: 12),

        BouncyTap(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const WidgetApprovalScreen(),
              ),
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.darkBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.accentOrange.withAlpha(60)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentOrange.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.widgets_rounded,
                    color: AppTheme.accentOrange,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Widget Approvals',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Review pending marketplace submissions',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ],
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
      'colorSource': 'accent color (Theme settings)',
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
