// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';

/// Font mode selection for the app
/// Controls which font family and style is used throughout the UI
enum FontMode {
  /// Use the branded JetBrainsMono font (default)
  branded('Branded', 'JetBrainsMono - Our signature monospace font'),

  /// Use the system default font for maximum compatibility
  system('System', 'Your device\'s default font'),

  /// Use a highly readable font optimized for accessibility
  accessibility('Accessibility', 'Inter - Optimized for readability');

  final String displayName;
  final String description;
  const FontMode(this.displayName, this.description);

  /// Get the font family for this mode
  String get fontFamily {
    switch (this) {
      case FontMode.branded:
        return 'JetBrainsMono';
      case FontMode.system:
        return ''; // Empty string uses system default
      case FontMode.accessibility:
        return 'Inter';
    }
  }
}

/// Text scale presets with safe, tested values
/// These are applied as multipliers to the base font sizes
enum TextScaleMode {
  /// Follow system accessibility settings (respects device font size)
  systemDefault(
    'System Default',
    'Follows your device accessibility settings',
    null,
  ),

  /// Socialmesh default - fixed base scale, ignores system settings
  socialmeshDefault('Default', 'Fixed size, ignores device settings', 1.0),

  /// Large text for better readability
  large('Large', '15% larger than default', 1.15),

  /// Extra large for maximum readability
  extraLarge('Extra Large', '30% larger than default', 1.3);

  final String displayName;
  final String description;

  /// The scale factor, or null to use system
  final double? scaleFactor;

  const TextScaleMode(this.displayName, this.description, this.scaleFactor);

  /// Maximum safe scale factor to prevent layout breakage
  static const double maxSafeScale = 1.5;

  /// Minimum scale factor
  static const double minScale = 0.8;

  /// Get the effective scale factor, clamped to safe bounds
  double getEffectiveScale(double systemScale) {
    if (scaleFactor == null) {
      // Use system scale but clamp to safe bounds
      return systemScale.clamp(minScale, maxSafeScale);
    }
    return scaleFactor!;
  }
}

/// Density mode for UI elements
/// Affects spacing, padding, and touch target sizes
enum DensityMode {
  /// Compact UI with smaller spacing
  compact('Compact', 'Denser UI, more content visible', -1),

  /// Default comfortable spacing
  comfortable('Comfortable', 'Balanced spacing (default)', 0),

  /// Large touch targets and generous spacing
  largeTouch('Large Touch', 'Bigger tap targets, easier to use', 1);

  final String displayName;
  final String description;

  /// Maps to Flutter's VisualDensity values (-4 to 4)
  final int densityValue;

  const DensityMode(this.displayName, this.description, this.densityValue);

  /// Get the VisualDensity for this mode
  double get visualDensity => densityValue.toDouble();

  /// Minimum tap target size for this mode (in logical pixels)
  double get minTapTargetSize {
    switch (this) {
      case DensityMode.compact:
        return 44.0; // iOS minimum
      case DensityMode.comfortable:
        return 48.0; // Material default
      case DensityMode.largeTouch:
        return 56.0; // Enhanced accessibility
    }
  }

  /// Spacing multiplier for this mode
  double get spacingMultiplier {
    switch (this) {
      case DensityMode.compact:
        return 0.85;
      case DensityMode.comfortable:
        return 1.0;
      case DensityMode.largeTouch:
        return 1.25;
    }
  }
}

/// Contrast mode for accessibility
enum ContrastMode {
  /// Normal contrast (default)
  normal('Normal', 'Standard color contrast'),

  /// High contrast for better visibility
  high('High Contrast', 'Enhanced visibility for text and UI');

  final String displayName;
  final String description;

  const ContrastMode(this.displayName, this.description);

  /// Whether high contrast adjustments should be applied
  bool get isHighContrast => this == ContrastMode.high;
}

/// Reduce motion preference
enum ReduceMotionMode {
  /// Normal animations
  off('Normal', 'All animations enabled'),

  /// Reduced motion for accessibility
  on('Reduced', 'Minimal animations for accessibility');

  final String displayName;
  final String description;

  const ReduceMotionMode(this.displayName, this.description);

  /// Whether motion should be reduced
  bool get shouldReduceMotion => this == ReduceMotionMode.on;

  /// Animation duration multiplier (0.0 for instant, 1.0 for normal)
  double get durationMultiplier {
    switch (this) {
      case ReduceMotionMode.off:
        return 1.0;
      case ReduceMotionMode.on:
        return 0.0; // Instant transitions
    }
  }
}

/// Complete user accessibility preferences state
class AccessibilityPreferences {
  final FontMode fontMode;
  final TextScaleMode textScaleMode;
  final DensityMode densityMode;
  final ContrastMode contrastMode;
  final ReduceMotionMode reduceMotionMode;

  const AccessibilityPreferences({
    this.fontMode = FontMode.branded,
    this.textScaleMode = TextScaleMode.socialmeshDefault,
    this.densityMode = DensityMode.comfortable,
    this.contrastMode = ContrastMode.normal,
    this.reduceMotionMode = ReduceMotionMode.off,
  });

  /// Default preferences (safe, branded defaults)
  static const AccessibilityPreferences defaults = AccessibilityPreferences();

  /// Create a copy with updated values
  AccessibilityPreferences copyWith({
    FontMode? fontMode,
    TextScaleMode? textScaleMode,
    DensityMode? densityMode,
    ContrastMode? contrastMode,
    ReduceMotionMode? reduceMotionMode,
  }) {
    return AccessibilityPreferences(
      fontMode: fontMode ?? this.fontMode,
      textScaleMode: textScaleMode ?? this.textScaleMode,
      densityMode: densityMode ?? this.densityMode,
      contrastMode: contrastMode ?? this.contrastMode,
      reduceMotionMode: reduceMotionMode ?? this.reduceMotionMode,
    );
  }

  /// Whether any non-default settings are active
  bool get hasCustomSettings =>
      fontMode != FontMode.branded ||
      textScaleMode != TextScaleMode.socialmeshDefault ||
      densityMode != DensityMode.comfortable ||
      contrastMode != ContrastMode.normal ||
      reduceMotionMode != ReduceMotionMode.off;

  /// Serialize to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'fontMode': fontMode.name,
      'textScaleMode': textScaleMode.name,
      'densityMode': densityMode.name,
      'contrastMode': contrastMode.name,
      'reduceMotionMode': reduceMotionMode.name,
      'version': 1, // For future migrations
    };
  }

  /// Serialize to JSON string
  String toJsonString() => jsonEncode(toJson());

  /// Deserialize from JSON with safe defaults for missing/invalid values
  factory AccessibilityPreferences.fromJson(Map<String, dynamic> json) {
    return AccessibilityPreferences(
      fontMode: _parseEnum(
        json['fontMode'] as String?,
        FontMode.values,
        FontMode.branded,
      ),
      textScaleMode: _parseEnum(
        json['textScaleMode'] as String?,
        TextScaleMode.values,
        TextScaleMode.socialmeshDefault,
      ),
      densityMode: _parseEnum(
        json['densityMode'] as String?,
        DensityMode.values,
        DensityMode.comfortable,
      ),
      contrastMode: _parseEnum(
        json['contrastMode'] as String?,
        ContrastMode.values,
        ContrastMode.normal,
      ),
      reduceMotionMode: _parseEnum(
        json['reduceMotionMode'] as String?,
        ReduceMotionMode.values,
        ReduceMotionMode.off,
      ),
    );
  }

  /// Deserialize from JSON string with fallback to defaults
  factory AccessibilityPreferences.fromJsonString(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) {
      return AccessibilityPreferences.defaults;
    }
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return AccessibilityPreferences.fromJson(json);
    } catch (_) {
      return AccessibilityPreferences.defaults;
    }
  }

  /// Parse an enum value safely with fallback
  static T _parseEnum<T extends Enum>(
    String? value,
    List<T> values,
    T defaultValue,
  ) {
    if (value == null) return defaultValue;
    try {
      return values.firstWhere(
        (e) => e.name == value,
        orElse: () => defaultValue,
      );
    } catch (_) {
      return defaultValue;
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AccessibilityPreferences &&
        other.fontMode == fontMode &&
        other.textScaleMode == textScaleMode &&
        other.densityMode == densityMode &&
        other.contrastMode == contrastMode &&
        other.reduceMotionMode == reduceMotionMode;
  }

  @override
  int get hashCode {
    return Object.hash(
      fontMode,
      textScaleMode,
      densityMode,
      contrastMode,
      reduceMotionMode,
    );
  }

  @override
  String toString() {
    return 'AccessibilityPreferences('
        'fontMode: $fontMode, '
        'textScaleMode: $textScaleMode, '
        'densityMode: $densityMode, '
        'contrastMode: $contrastMode, '
        'reduceMotionMode: $reduceMotionMode)';
  }
}
