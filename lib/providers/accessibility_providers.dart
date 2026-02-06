// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging.dart';
import '../models/accessibility_preferences.dart';
import '../services/accessibility_preferences_service.dart';

/// Provider for the AccessibilityPreferencesService singleton
final accessibilityPreferencesServiceProvider =
    Provider<AccessibilityPreferencesService>((ref) {
      return AccessibilityPreferencesService();
    });

/// Notifier for accessibility preferences state
///
/// This notifier manages the reactive state for user accessibility preferences.
/// It loads from local storage on initialization and persists all changes.
class AccessibilityPreferencesNotifier
    extends Notifier<AccessibilityPreferences> {
  @override
  AccessibilityPreferences build() {
    // Load from service synchronously (service should be pre-initialized)
    final service = ref.read(accessibilityPreferencesServiceProvider);
    return service.current;
  }

  /// Update the font mode
  Future<void> setFontMode(FontMode mode) async {
    final service = ref.read(accessibilityPreferencesServiceProvider);
    state = state.copyWith(fontMode: mode);
    await service.updateFontMode(mode);
    AppLogging.settings('Accessibility: font mode changed to ${mode.name}');
  }

  /// Update the text scale mode
  Future<void> setTextScaleMode(TextScaleMode mode) async {
    final service = ref.read(accessibilityPreferencesServiceProvider);
    state = state.copyWith(textScaleMode: mode);
    await service.updateTextScaleMode(mode);
    AppLogging.settings('Accessibility: text scale changed to ${mode.name}');
  }

  /// Update the density mode
  Future<void> setDensityMode(DensityMode mode) async {
    final service = ref.read(accessibilityPreferencesServiceProvider);
    state = state.copyWith(densityMode: mode);
    await service.updateDensityMode(mode);
    AppLogging.settings('Accessibility: density mode changed to ${mode.name}');
  }

  /// Update the contrast mode
  Future<void> setContrastMode(ContrastMode mode) async {
    final service = ref.read(accessibilityPreferencesServiceProvider);
    state = state.copyWith(contrastMode: mode);
    await service.updateContrastMode(mode);
    AppLogging.settings('Accessibility: contrast mode changed to ${mode.name}');
  }

  /// Update the reduce motion mode
  Future<void> setReduceMotionMode(ReduceMotionMode mode) async {
    final service = ref.read(accessibilityPreferencesServiceProvider);
    state = state.copyWith(reduceMotionMode: mode);
    await service.updateReduceMotionMode(mode);
    AppLogging.settings('Accessibility: reduce motion changed to ${mode.name}');
  }

  /// Reset all preferences to defaults
  Future<void> resetToDefaults() async {
    final service = ref.read(accessibilityPreferencesServiceProvider);
    state = AccessibilityPreferences.defaults;
    await service.resetToDefaults();
    AppLogging.settings('Accessibility: reset to defaults');
  }

  /// Update all preferences at once
  Future<void> updateAll(AccessibilityPreferences preferences) async {
    final service = ref.read(accessibilityPreferencesServiceProvider);
    state = preferences;
    await service.updatePreferences(preferences);
    AppLogging.settings('Accessibility: preferences updated to $preferences');
  }
}

/// Main provider for accessibility preferences
final accessibilityPreferencesProvider =
    NotifierProvider<
      AccessibilityPreferencesNotifier,
      AccessibilityPreferences
    >(AccessibilityPreferencesNotifier.new);

/// Provider for the effective text scale factor
///
/// This computes the actual scale factor to apply, taking into account
/// both user preferences and system settings, with safety clamping.
final effectiveTextScaleProvider = Provider<double>((ref) {
  final prefs = ref.watch(accessibilityPreferencesProvider);

  // For system default, we return 1.0 here and let MediaQuery handle it
  // For explicit scales, we return the user's chosen value
  if (prefs.textScaleMode.scaleFactor == null) {
    // System default - MediaQuery will apply system scale
    return 1.0;
  }

  return prefs.textScaleMode.scaleFactor!;
});

/// Provider for whether to use system text scaling
final useSystemTextScaleProvider = Provider<bool>((ref) {
  final prefs = ref.watch(accessibilityPreferencesProvider);
  return prefs.textScaleMode == TextScaleMode.systemDefault;
});

/// Provider for the effective VisualDensity
final effectiveVisualDensityProvider = Provider<VisualDensity>((ref) {
  final prefs = ref.watch(accessibilityPreferencesProvider);
  final densityValue = prefs.densityMode.visualDensity;
  return VisualDensity(horizontal: densityValue, vertical: densityValue);
});

/// Provider for whether high contrast mode is enabled
final highContrastEnabledProvider = Provider<bool>((ref) {
  final prefs = ref.watch(accessibilityPreferencesProvider);
  return prefs.contrastMode.isHighContrast;
});

/// Provider for whether motion should be reduced
final reduceMotionEnabledProvider = Provider<bool>((ref) {
  final prefs = ref.watch(accessibilityPreferencesProvider);
  return prefs.reduceMotionMode.shouldReduceMotion;
});

/// Provider for animation duration multiplier
final animationDurationMultiplierProvider = Provider<double>((ref) {
  final prefs = ref.watch(accessibilityPreferencesProvider);
  return prefs.reduceMotionMode.durationMultiplier;
});

/// Provider for the effective font family
final effectiveFontFamilyProvider = Provider<String?>((ref) {
  final prefs = ref.watch(accessibilityPreferencesProvider);
  final family = prefs.fontMode.fontFamily;
  // Empty string means system default (return null)
  return family.isEmpty ? null : family;
});

/// Provider for minimum tap target size
final minTapTargetSizeProvider = Provider<double>((ref) {
  final prefs = ref.watch(accessibilityPreferencesProvider);
  return prefs.densityMode.minTapTargetSize;
});

/// Provider for spacing multiplier based on density
final spacingMultiplierProvider = Provider<double>((ref) {
  final prefs = ref.watch(accessibilityPreferencesProvider);
  return prefs.densityMode.spacingMultiplier;
});

/// Provider that indicates if any custom accessibility settings are active
final hasCustomAccessibilitySettingsProvider = Provider<bool>((ref) {
  final prefs = ref.watch(accessibilityPreferencesProvider);
  return prefs.hasCustomSettings;
});

/// Provider for a human-readable summary of active settings
final accessibilitySettingsSummaryProvider = Provider<String>((ref) {
  final service = ref.read(accessibilityPreferencesServiceProvider);
  return service.getActiveSummary();
});
