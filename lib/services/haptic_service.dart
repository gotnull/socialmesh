// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
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

/// Platform haptic primitives a feedback sequence is built from, ordered
/// weakest to strongest as rendered by the OS.
enum HapticPrimitive { selectionClick, lightImpact, mediumImpact, heavyImpact }

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
    final pulses = pulsesFor(type, intensity);
    final gap = pulseGapFor(type);
    for (var i = 0; i < pulses.length; i++) {
      if (i > 0) await Future.delayed(gap);
      await _play(pulses[i]);
    }
  }

  /// The pulse sequence for a semantic event at a given intensity setting.
  ///
  /// The three settings are deliberately spread wide, because on much of the
  /// hardware in the field adjacent impact styles render nearly identically:
  /// Light tops out at [HapticPrimitive.lightImpact], Medium is the balanced
  /// default, and Heavy leans on [HapticPrimitive.heavyImpact] - doubled for
  /// the strongest events - so each setting feels clearly different from its
  /// neighbours.
  static List<HapticPrimitive> pulsesFor(
    HapticType type,
    HapticIntensity intensity,
  ) {
    return switch (type) {
      HapticType.selection => switch (intensity) {
        HapticIntensity.light => const [HapticPrimitive.selectionClick],
        HapticIntensity.medium => const [HapticPrimitive.selectionClick],
        HapticIntensity.heavy => const [HapticPrimitive.mediumImpact],
      },
      HapticType.light => switch (intensity) {
        HapticIntensity.light => const [HapticPrimitive.selectionClick],
        HapticIntensity.medium => const [HapticPrimitive.lightImpact],
        HapticIntensity.heavy => const [HapticPrimitive.heavyImpact],
      },
      HapticType.medium => switch (intensity) {
        HapticIntensity.light => const [HapticPrimitive.selectionClick],
        HapticIntensity.medium => const [HapticPrimitive.mediumImpact],
        HapticIntensity.heavy => const [HapticPrimitive.heavyImpact],
      },
      HapticType.heavy => switch (intensity) {
        HapticIntensity.light => const [HapticPrimitive.lightImpact],
        HapticIntensity.medium => const [HapticPrimitive.heavyImpact],
        HapticIntensity.heavy => const [
          HapticPrimitive.heavyImpact,
          HapticPrimitive.heavyImpact,
        ],
      },
      HapticType.success => switch (intensity) {
        HapticIntensity.light => const [HapticPrimitive.lightImpact],
        HapticIntensity.medium => const [
          HapticPrimitive.mediumImpact,
          HapticPrimitive.lightImpact,
        ],
        HapticIntensity.heavy => const [
          HapticPrimitive.heavyImpact,
          HapticPrimitive.heavyImpact,
        ],
      },
      HapticType.warning => switch (intensity) {
        HapticIntensity.light => const [
          HapticPrimitive.lightImpact,
          HapticPrimitive.lightImpact,
        ],
        HapticIntensity.medium => const [
          HapticPrimitive.mediumImpact,
          HapticPrimitive.mediumImpact,
        ],
        HapticIntensity.heavy => const [
          HapticPrimitive.heavyImpact,
          HapticPrimitive.heavyImpact,
        ],
      },
      HapticType.error => switch (intensity) {
        HapticIntensity.light => const [
          HapticPrimitive.lightImpact,
          HapticPrimitive.lightImpact,
          HapticPrimitive.lightImpact,
        ],
        HapticIntensity.medium => const [
          HapticPrimitive.mediumImpact,
          HapticPrimitive.mediumImpact,
          HapticPrimitive.mediumImpact,
        ],
        HapticIntensity.heavy => const [
          HapticPrimitive.heavyImpact,
          HapticPrimitive.heavyImpact,
          HapticPrimitive.heavyImpact,
        ],
      },
    };
  }

  /// Gap between pulses when [pulsesFor] returns more than one.
  static Duration pulseGapFor(HapticType type) {
    return switch (type) {
      HapticType.warning => const Duration(milliseconds: 150),
      _ => const Duration(milliseconds: 100),
    };
  }

  static Future<void> _play(HapticPrimitive primitive) {
    switch (primitive) {
      case HapticPrimitive.selectionClick:
        return HapticFeedback.selectionClick();
      case HapticPrimitive.lightImpact:
        return HapticFeedback.lightImpact();
      case HapticPrimitive.mediumImpact:
        return HapticFeedback.mediumImpact();
      case HapticPrimitive.heavyImpact:
        return HapticFeedback.heavyImpact();
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
