import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/logging.dart';
import '../../core/widgets/animated_mesh_node.dart';
import '../storage/storage_service.dart';

/// Collection and document names for Firestore
class MeshFirestoreKeys {
  static const String collection = 'app_config';
  static const String document = 'splash_mesh';
}

/// Service for managing mesh node configuration via Firestore.
/// Allows global config sync across all devices with read AND write.
class MeshFirestoreConfigService {
  static final MeshFirestoreConfigService _instance =
      MeshFirestoreConfigService._internal();
  static MeshFirestoreConfigService get instance => _instance;

  MeshFirestoreConfigService._internal();

  FirebaseFirestore? _firestore;
  bool _initialized = false;

  /// Initialize the Firestore config service
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _firestore = FirebaseFirestore.instance;
      _initialized = true;
      AppLogging.settings('✅ MeshFirestoreConfigService initialized');
    } catch (e) {
      AppLogging.settings('⚠️ MeshFirestoreConfigService init failed: $e');
    }
  }

  /// Get the document reference for mesh config
  DocumentReference<Map<String, dynamic>> get _configDoc {
    return _firestore!
        .collection(MeshFirestoreKeys.collection)
        .doc(MeshFirestoreKeys.document);
  }

  /// Get the remote mesh config (if available)
  /// Always fetches from server to ensure latest config
  Future<MeshConfigData?> getRemoteConfig() async {
    if (_firestore == null) return null;

    try {
      // Force fetch from server, not cache
      final doc = await _configDoc.get(const GetOptions(source: Source.server));
      if (!doc.exists || doc.data() == null) return null;

      AppLogging.settings('📡 Fetched mesh config from Firestore server');
      return MeshConfigData.fromJson(doc.data()!);
    } catch (e) {
      AppLogging.settings('⚠️ Failed to fetch mesh config from Firestore: $e');
      // Try cache as fallback
      try {
        final cachedDoc = await _configDoc.get(
          const GetOptions(source: Source.cache),
        );
        if (cachedDoc.exists && cachedDoc.data() != null) {
          AppLogging.settings('📦 Using cached mesh config');
          return MeshConfigData.fromJson(cachedDoc.data()!);
        }
      } catch (_) {}
      return null;
    }
  }

  /// Save config to Firestore (global)
  Future<bool> saveConfig(MeshConfigData config) async {
    if (_firestore == null) return false;

    try {
      await _configDoc.set({
        ...config.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      AppLogging.settings('✅ Mesh config saved to Firestore');
      return true;
    } catch (e) {
      AppLogging.settings('⚠️ Failed to save mesh config to Firestore: $e');
      return false;
    }
  }

  /// Force refresh (re-fetch from Firestore)
  Future<MeshConfigData?> forceRefresh() async {
    return getRemoteConfig();
  }

  /// Check if Firestore is available
  bool get isAvailable => _initialized && _firestore != null;
}

/// Data class for mesh configuration
class MeshConfigData {
  final double size;
  final String animationType;
  final bool animate;
  final double glowIntensity;
  final double lineThickness;
  final double nodeSize;
  final int colorPreset;
  final bool useAccelerometer;
  final double accelerometerSensitivity;
  final double accelerometerFriction;
  final String physicsMode;
  final bool enableTouch;
  final bool enablePullToStretch;
  final double touchIntensity;
  final double stretchIntensity;
  // Secret gesture config
  final String secretGesturePattern;
  final int secretGestureTimeWindowMs;
  final bool secretGestureShowFeedback;
  final bool secretGestureEnableHaptics;

  const MeshConfigData({
    this.size = 600,
    this.animationType = 'tumble',
    this.animate = true,
    this.glowIntensity = 0.5,
    this.lineThickness = 0.5,
    this.nodeSize = 0.8,
    this.colorPreset = 0,
    this.useAccelerometer = true,
    this.accelerometerSensitivity = 0.5,
    this.accelerometerFriction = 0.97,
    this.physicsMode = 'momentum',
    this.enableTouch = true,
    this.enablePullToStretch = false,
    this.touchIntensity = 0.5,
    this.stretchIntensity = 0.3,
    this.secretGesturePattern = 'sevenTaps',
    this.secretGestureTimeWindowMs = 3000,
    this.secretGestureShowFeedback = true,
    this.secretGestureEnableHaptics = true,
  });

  factory MeshConfigData.fromJson(Map<String, dynamic> json) {
    return MeshConfigData(
      size: (json['size'] as num?)?.toDouble() ?? 600,
      animationType: json['animationType'] as String? ?? 'tumble',
      animate: json['animate'] as bool? ?? true,
      glowIntensity: (json['glowIntensity'] as num?)?.toDouble() ?? 0.5,
      lineThickness: (json['lineThickness'] as num?)?.toDouble() ?? 0.5,
      nodeSize: (json['nodeSize'] as num?)?.toDouble() ?? 0.8,
      colorPreset: json['colorPreset'] as int? ?? 0,
      useAccelerometer: json['useAccelerometer'] as bool? ?? true,
      accelerometerSensitivity:
          (json['accelerometerSensitivity'] as num?)?.toDouble() ?? 0.5,
      accelerometerFriction:
          (json['accelerometerFriction'] as num?)?.toDouble() ?? 0.97,
      physicsMode: json['physicsMode'] as String? ?? 'momentum',
      enableTouch: json['enableTouch'] as bool? ?? true,
      enablePullToStretch: json['enablePullToStretch'] as bool? ?? false,
      touchIntensity: (json['touchIntensity'] as num?)?.toDouble() ?? 0.5,
      stretchIntensity: (json['stretchIntensity'] as num?)?.toDouble() ?? 0.3,
      secretGesturePattern:
          json['secretGesturePattern'] as String? ?? 'sevenTaps',
      secretGestureTimeWindowMs:
          json['secretGestureTimeWindowMs'] as int? ?? 3000,
      secretGestureShowFeedback:
          json['secretGestureShowFeedback'] as bool? ?? true,
      secretGestureEnableHaptics:
          json['secretGestureEnableHaptics'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'size': size,
      'animationType': animationType,
      'animate': animate,
      'glowIntensity': glowIntensity,
      'lineThickness': lineThickness,
      'nodeSize': nodeSize,
      'colorPreset': colorPreset,
      'useAccelerometer': useAccelerometer,
      'accelerometerSensitivity': accelerometerSensitivity,
      'accelerometerFriction': accelerometerFriction,
      'physicsMode': physicsMode,
      'enableTouch': enableTouch,
      'enablePullToStretch': enablePullToStretch,
      'touchIntensity': touchIntensity,
      'stretchIntensity': stretchIntensity,
      'secretGesturePattern': secretGesturePattern,
      'secretGestureTimeWindowMs': secretGestureTimeWindowMs,
      'secretGestureShowFeedback': secretGestureShowFeedback,
      'secretGestureEnableHaptics': secretGestureEnableHaptics,
    };
  }

  /// Apply this config to local storage
  Future<void> applyToLocalStorage(SettingsService settingsService) async {
    await settingsService.setSplashMeshConfig(
      size: size,
      animationType: animationType,
      glowIntensity: glowIntensity,
      lineThickness: lineThickness,
      nodeSize: nodeSize,
      colorPreset: colorPreset,
      useAccelerometer: useAccelerometer,
      accelerometerSensitivity: accelerometerSensitivity,
      accelerometerFriction: accelerometerFriction,
      physicsMode: physicsMode,
      enableTouch: enableTouch,
      enablePullToStretch: enablePullToStretch,
      touchIntensity: touchIntensity,
      stretchIntensity: stretchIntensity,
    );
    await settingsService.setSecretGestureConfig(
      pattern: secretGesturePattern,
      timeWindowMs: secretGestureTimeWindowMs,
      showFeedback: secretGestureShowFeedback,
      enableHaptics: secretGestureEnableHaptics,
    );
  }

  MeshNodeAnimationType get animationTypeEnum {
    return MeshNodeAnimationType.values.firstWhere(
      (t) => t.name == animationType,
      orElse: () => MeshNodeAnimationType.tumble,
    );
  }

  MeshPhysicsMode get physicsModeEnum {
    return MeshPhysicsMode.values.firstWhere(
      (m) => m.name == physicsMode,
      orElse: () => MeshPhysicsMode.momentum,
    );
  }
}

/// Enum for save location preference
enum MeshConfigSaveLocation {
  /// Save to this device only (SharedPreferences)
  localDevice,

  /// Save globally via Firestore
  global,
}

/// Extension for save location
extension MeshConfigSaveLocationX on MeshConfigSaveLocation {
  String get displayName {
    switch (this) {
      case MeshConfigSaveLocation.localDevice:
        return 'This Device Only';
      case MeshConfigSaveLocation.global:
        return 'All Devices (Global)';
    }
  }

  IconData get icon {
    switch (this) {
      case MeshConfigSaveLocation.localDevice:
        return Icons.phone_android;
      case MeshConfigSaveLocation.global:
        return Icons.cloud_upload;
    }
  }

  String get description {
    switch (this) {
      case MeshConfigSaveLocation.localDevice:
        return 'Settings are saved to this device only';
      case MeshConfigSaveLocation.global:
        return 'Settings sync across all devices via Firestore';
    }
  }
}
