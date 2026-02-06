// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:shared_preferences/shared_preferences.dart';

import '../core/logging.dart';
import '../models/accessibility_preferences.dart';

/// Storage key for accessibility preferences
const String _preferencesKey = 'accessibility_preferences';

/// Service for persisting accessibility preferences locally
///
/// This service provides atomic read/write operations for user accessibility
/// settings. It works fully offline using SharedPreferences and is designed
/// to be available before any user authentication.
class AccessibilityPreferencesService {
  SharedPreferences? _prefs;
  AccessibilityPreferences _cachedPreferences =
      AccessibilityPreferences.defaults;
  bool _isInitialized = false;

  /// Singleton instance
  static final AccessibilityPreferencesService _instance =
      AccessibilityPreferencesService._internal();

  factory AccessibilityPreferencesService() => _instance;

  AccessibilityPreferencesService._internal();

  /// Whether the service has been initialized
  bool get isInitialized => _isInitialized;

  /// Get the current cached preferences (synchronous)
  /// Falls back to defaults if not yet initialized
  AccessibilityPreferences get current => _cachedPreferences;

  /// Initialize the service and load persisted preferences
  /// This should be called early in app startup, before UI renders
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadPreferences();
      _isInitialized = true;
      AppLogging.settings('AccessibilityPreferencesService initialized');
    } catch (e) {
      // If SharedPreferences fails, continue with defaults
      // This ensures the app remains functional
      AppLogging.settings(
        'Failed to initialize accessibility preferences: $e - using defaults',
      );
      _cachedPreferences = AccessibilityPreferences.defaults;
      _isInitialized = true;
    }
  }

  /// Load preferences from storage
  Future<void> _loadPreferences() async {
    try {
      final jsonString = _prefs?.getString(_preferencesKey);
      _cachedPreferences = AccessibilityPreferences.fromJsonString(jsonString);
      AppLogging.settings(
        'Loaded accessibility preferences: $_cachedPreferences',
      );
    } catch (e) {
      AppLogging.settings('Failed to load accessibility preferences: $e');
      _cachedPreferences = AccessibilityPreferences.defaults;
    }
  }

  /// Save preferences to storage
  Future<bool> _savePreferences() async {
    try {
      final jsonString = _cachedPreferences.toJsonString();
      final result = await _prefs?.setString(_preferencesKey, jsonString);
      AppLogging.settings(
        'Saved accessibility preferences: $_cachedPreferences',
      );
      return result ?? false;
    } catch (e) {
      AppLogging.settings('Failed to save accessibility preferences: $e');
      return false;
    }
  }

  /// Update preferences atomically
  /// Returns true if save was successful
  Future<bool> updatePreferences(AccessibilityPreferences preferences) async {
    _cachedPreferences = preferences;
    return await _savePreferences();
  }

  /// Update a single preference field
  Future<bool> updateFontMode(FontMode mode) async {
    return await updatePreferences(_cachedPreferences.copyWith(fontMode: mode));
  }

  /// Update text scale mode
  Future<bool> updateTextScaleMode(TextScaleMode mode) async {
    return await updatePreferences(
      _cachedPreferences.copyWith(textScaleMode: mode),
    );
  }

  /// Update density mode
  Future<bool> updateDensityMode(DensityMode mode) async {
    return await updatePreferences(
      _cachedPreferences.copyWith(densityMode: mode),
    );
  }

  /// Update contrast mode
  Future<bool> updateContrastMode(ContrastMode mode) async {
    return await updatePreferences(
      _cachedPreferences.copyWith(contrastMode: mode),
    );
  }

  /// Update reduce motion mode
  Future<bool> updateReduceMotionMode(ReduceMotionMode mode) async {
    return await updatePreferences(
      _cachedPreferences.copyWith(reduceMotionMode: mode),
    );
  }

  /// Reset all preferences to defaults
  Future<bool> resetToDefaults() async {
    return await updatePreferences(AccessibilityPreferences.defaults);
  }

  /// Check if any custom settings are active
  bool get hasCustomSettings => _cachedPreferences.hasCustomSettings;

  /// Get a summary of active customizations for display
  String getActiveSummary() {
    if (!_cachedPreferences.hasCustomSettings) {
      return 'Using recommended settings';
    }

    final active = <String>[];

    if (_cachedPreferences.fontMode != FontMode.branded) {
      active.add(_cachedPreferences.fontMode.displayName);
    }
    if (_cachedPreferences.textScaleMode != TextScaleMode.socialmeshDefault) {
      active.add('${_cachedPreferences.textScaleMode.displayName} text');
    }
    if (_cachedPreferences.densityMode != DensityMode.comfortable) {
      active.add(_cachedPreferences.densityMode.displayName);
    }
    if (_cachedPreferences.contrastMode != ContrastMode.normal) {
      active.add('High contrast');
    }
    if (_cachedPreferences.reduceMotionMode != ReduceMotionMode.off) {
      active.add('Reduced motion');
    }

    return active.join(', ');
  }
}
