// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';

/// Haptic feedback intensity levels
enum HapticIntensity {
  light(0, 'Light'),
  medium(1, 'Medium'),
  heavy(2, 'Heavy');

  final int value;
  final String label;
  const HapticIntensity(this.value, this.label);

  static HapticIntensity fromValue(int value) {
    return HapticIntensity.values.firstWhere(
      (e) => e.value == value,
      orElse: () => HapticIntensity.medium,
    );
  }
}

/// Haptic feedback types for different interactions
enum HapticType {
  /// Light tap - for selections, toggles
  selection,

  /// Light impact - for subtle confirmations
  light,

  /// Medium impact - for standard actions (buttons, navigation)
  medium,

  /// Heavy impact - for important actions (send message, delete, purchase)
  heavy,

  /// Success vibration pattern
  success,

  /// Warning vibration pattern
  warning,

  /// Error vibration pattern
  error,
}

/// Service for managing haptic feedback throughout the app
class HapticService {
  final Ref _ref;

  HapticService(this._ref);

  /// Trigger haptic feedback based on type and user settings
  Future<void> trigger(HapticType type) async {
    final settingsAsync = _ref.read(settingsServiceProvider);
    final settings = settingsAsync.value;
    if (settings == null) return;

    // Check if haptics are enabled
    if (!settings.hapticFeedbackEnabled) return;

    final intensity = HapticIntensity.fromValue(settings.hapticIntensity);

    switch (type) {
      case HapticType.selection:
        await _triggerSelection(intensity);
      case HapticType.light:
        await _triggerLight(intensity);
      case HapticType.medium:
        await _triggerMedium(intensity);
      case HapticType.heavy:
        await _triggerHeavy(intensity);
      case HapticType.success:
        await _triggerSuccess(intensity);
      case HapticType.warning:
        await _triggerWarning(intensity);
      case HapticType.error:
        await _triggerError(intensity);
    }
  }

  /// Selection click - adjusted by intensity
  Future<void> _triggerSelection(HapticIntensity intensity) async {
    switch (intensity) {
      case HapticIntensity.light:
        await HapticFeedback.selectionClick();
      case HapticIntensity.medium:
        await HapticFeedback.selectionClick();
      case HapticIntensity.heavy:
        await HapticFeedback.lightImpact();
    }
  }

  /// Light feedback - adjusted by intensity
  Future<void> _triggerLight(HapticIntensity intensity) async {
    switch (intensity) {
      case HapticIntensity.light:
        await HapticFeedback.selectionClick();
      case HapticIntensity.medium:
        await HapticFeedback.lightImpact();
      case HapticIntensity.heavy:
        await HapticFeedback.mediumImpact();
    }
  }

  /// Medium feedback - adjusted by intensity
  Future<void> _triggerMedium(HapticIntensity intensity) async {
    switch (intensity) {
      case HapticIntensity.light:
        await HapticFeedback.lightImpact();
      case HapticIntensity.medium:
        await HapticFeedback.mediumImpact();
      case HapticIntensity.heavy:
        await HapticFeedback.heavyImpact();
    }
  }

  /// Heavy feedback - adjusted by intensity
  Future<void> _triggerHeavy(HapticIntensity intensity) async {
    switch (intensity) {
      case HapticIntensity.light:
        await HapticFeedback.mediumImpact();
      case HapticIntensity.medium:
        await HapticFeedback.heavyImpact();
      case HapticIntensity.heavy:
        // Double tap for extra heavy
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 100));
        await HapticFeedback.heavyImpact();
    }
  }

  /// Success pattern
  Future<void> _triggerSuccess(HapticIntensity intensity) async {
    switch (intensity) {
      case HapticIntensity.light:
        await HapticFeedback.lightImpact();
      case HapticIntensity.medium:
        await HapticFeedback.mediumImpact();
        await Future.delayed(const Duration(milliseconds: 100));
        await HapticFeedback.lightImpact();
      case HapticIntensity.heavy:
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 100));
        await HapticFeedback.mediumImpact();
    }
  }

  /// Warning pattern
  Future<void> _triggerWarning(HapticIntensity intensity) async {
    switch (intensity) {
      case HapticIntensity.light:
        await HapticFeedback.lightImpact();
        await Future.delayed(const Duration(milliseconds: 150));
        await HapticFeedback.lightImpact();
      case HapticIntensity.medium:
        await HapticFeedback.mediumImpact();
        await Future.delayed(const Duration(milliseconds: 150));
        await HapticFeedback.mediumImpact();
      case HapticIntensity.heavy:
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 150));
        await HapticFeedback.heavyImpact();
    }
  }

  /// Error pattern - triple pulse
  Future<void> _triggerError(HapticIntensity intensity) async {
    switch (intensity) {
      case HapticIntensity.light:
        for (int i = 0; i < 3; i++) {
          await HapticFeedback.lightImpact();
          if (i < 2) await Future.delayed(const Duration(milliseconds: 100));
        }
      case HapticIntensity.medium:
        for (int i = 0; i < 3; i++) {
          await HapticFeedback.mediumImpact();
          if (i < 2) await Future.delayed(const Duration(milliseconds: 100));
        }
      case HapticIntensity.heavy:
        for (int i = 0; i < 3; i++) {
          await HapticFeedback.heavyImpact();
          if (i < 2) await Future.delayed(const Duration(milliseconds: 100));
        }
    }
  }

  // Convenience methods for common actions

  /// For button taps
  Future<void> buttonTap() => trigger(HapticType.medium);

  /// For navigation tab changes
  Future<void> tabChange() => trigger(HapticType.selection);

  /// For toggle switches
  Future<void> toggle() => trigger(HapticType.light);

  /// For sending messages
  Future<void> messageSent() => trigger(HapticType.medium);

  /// For receiving messages
  Future<void> messageReceived() => trigger(HapticType.light);

  /// For successful actions (purchase complete, save, etc.)
  Future<void> success() => trigger(HapticType.success);

  /// For warnings
  Future<void> warning() => trigger(HapticType.warning);

  /// For errors
  Future<void> error() => trigger(HapticType.error);

  /// For list item selection
  Future<void> itemSelect() => trigger(HapticType.selection);

  /// For long press actions
  Future<void> longPress() => trigger(HapticType.heavy);

  /// For slider/picker changes
  Future<void> sliderTick() => trigger(HapticType.selection);

  /// For pull-to-refresh
  Future<void> pullToRefresh() => trigger(HapticType.medium);

  /// For delete/destructive actions
  Future<void> destructive() => trigger(HapticType.heavy);
}

/// Provider for HapticService
final hapticServiceProvider = Provider<HapticService>((ref) {
  return HapticService(ref);
});

/// Extension for easy access from WidgetRef
extension HapticRefExtension on WidgetRef {
  HapticService get haptics => read(hapticServiceProvider);
}
