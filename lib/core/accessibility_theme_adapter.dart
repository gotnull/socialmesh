// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../models/accessibility_preferences.dart';

/// Adapts ThemeData based on accessibility preferences
///
/// This adapter takes the base Socialmesh theme and modifies it according
/// to user accessibility preferences, including:
/// - Font family changes
/// - Text scaling with safe bounds
/// - Visual density adjustments
/// - High contrast mode
/// - Minimum tap target enforcement
class AccessibilityThemeAdapter {
  const AccessibilityThemeAdapter._();

  /// Apply accessibility preferences to a ThemeData
  ///
  /// [baseTheme] - The original theme from AppTheme.darkTheme or lightTheme
  /// [preferences] - User's accessibility preferences
  /// [systemTextScale] - The system's text scale factor from MediaQuery
  static ThemeData applyPreferences({
    required ThemeData baseTheme,
    required AccessibilityPreferences preferences,
    double systemTextScale = 1.0,
  }) {
    ThemeData theme = baseTheme;

    // Apply text scaling FIRST (before font family, so font changes apply to scaled sizes)
    theme = _applyTextScaling(
      theme,
      preferences.textScaleMode,
      systemTextScale,
    );

    // Apply font family changes to all text styles
    theme = _applyFontFamily(theme, preferences.fontMode);

    // Apply visual density
    theme = _applyVisualDensity(theme, preferences.densityMode);

    // Apply high contrast if enabled
    if (preferences.contrastMode.isHighContrast) {
      theme = _applyHighContrast(theme);
    }

    // Apply minimum tap target sizing via MaterialTapTargetSize
    theme = _applyTapTargetSize(theme, preferences.densityMode);

    return theme;
  }

  /// Apply font family changes to the theme
  /// Updates textTheme, appBarTheme, and other components with text styles
  static ThemeData _applyFontFamily(ThemeData theme, FontMode fontMode) {
    final fontFamily = fontMode.fontFamily;

    // Determine the effective font family
    final effectiveFont = fontFamily.isEmpty ? _systemFontFamily : fontFamily;

    // Apply font to all text theme styles
    final updatedTextTheme = _applyTextThemeFontFamily(
      theme.textTheme,
      effectiveFont,
    );

    // Update appBarTheme titleTextStyle if it exists
    final currentAppBarTheme = theme.appBarTheme;
    final updatedAppBarTheme = currentAppBarTheme.copyWith(
      titleTextStyle: currentAppBarTheme.titleTextStyle?.copyWith(
        fontFamily: effectiveFont,
      ),
    );

    // Update dialog title and content text styles
    final currentDialogTheme = theme.dialogTheme;
    final updatedDialogTheme = currentDialogTheme.copyWith(
      titleTextStyle: currentDialogTheme.titleTextStyle?.copyWith(
        fontFamily: effectiveFont,
      ),
      contentTextStyle: currentDialogTheme.contentTextStyle?.copyWith(
        fontFamily: effectiveFont,
      ),
    );

    // Update button text styles
    final currentElevatedButtonTheme = theme.elevatedButtonTheme;
    final updatedElevatedButtonTheme = ElevatedButtonThemeData(
      style: currentElevatedButtonTheme.style?.copyWith(
        textStyle: WidgetStatePropertyAll(
          currentElevatedButtonTheme.style?.textStyle
                  ?.resolve({})
                  ?.copyWith(fontFamily: effectiveFont) ??
              TextStyle(fontFamily: effectiveFont),
        ),
      ),
    );

    final currentFilledButtonTheme = theme.filledButtonTheme;
    final updatedFilledButtonTheme = FilledButtonThemeData(
      style: currentFilledButtonTheme.style?.copyWith(
        textStyle: WidgetStatePropertyAll(
          currentFilledButtonTheme.style?.textStyle
                  ?.resolve({})
                  ?.copyWith(fontFamily: effectiveFont) ??
              TextStyle(fontFamily: effectiveFont),
        ),
      ),
    );

    final currentOutlinedButtonTheme = theme.outlinedButtonTheme;
    final updatedOutlinedButtonTheme = OutlinedButtonThemeData(
      style: currentOutlinedButtonTheme.style?.copyWith(
        textStyle: WidgetStatePropertyAll(
          currentOutlinedButtonTheme.style?.textStyle
                  ?.resolve({})
                  ?.copyWith(fontFamily: effectiveFont) ??
              TextStyle(fontFamily: effectiveFont),
        ),
      ),
    );

    final currentTextButtonTheme = theme.textButtonTheme;
    final updatedTextButtonTheme = TextButtonThemeData(
      style: currentTextButtonTheme.style?.copyWith(
        textStyle: WidgetStatePropertyAll(
          currentTextButtonTheme.style?.textStyle
                  ?.resolve({})
                  ?.copyWith(fontFamily: effectiveFont) ??
              TextStyle(fontFamily: effectiveFont),
        ),
      ),
    );

    // Update snackbar text style
    final currentSnackBarTheme = theme.snackBarTheme;
    final updatedSnackBarTheme = currentSnackBarTheme.copyWith(
      contentTextStyle: currentSnackBarTheme.contentTextStyle?.copyWith(
        fontFamily: effectiveFont,
      ),
    );

    return theme.copyWith(
      textTheme: updatedTextTheme,
      appBarTheme: updatedAppBarTheme,
      dialogTheme: updatedDialogTheme,
      elevatedButtonTheme: updatedElevatedButtonTheme,
      filledButtonTheme: updatedFilledButtonTheme,
      outlinedButtonTheme: updatedOutlinedButtonTheme,
      textButtonTheme: updatedTextButtonTheme,
      snackBarTheme: updatedSnackBarTheme,
    );
  }

  /// Apply text scaling to the theme's text styles
  static ThemeData _applyTextScaling(
    ThemeData theme,
    TextScaleMode mode,
    double systemTextScale,
  ) {
    // For systemDefault, don't modify theme - let Flutter's MediaQuery handle it
    if (mode == TextScaleMode.systemDefault) {
      return theme;
    }

    // For socialmeshDefault (1.0), no scaling needed
    if (mode == TextScaleMode.socialmeshDefault) {
      return theme;
    }

    // Get the explicit scale factor for large/extraLarge modes
    final scaleFactor = mode.scaleFactor;
    if (scaleFactor == null || scaleFactor == 1.0) {
      return theme;
    }

    // Scale all text styles in the theme
    final scaledTextTheme = _scaleTextTheme(theme.textTheme, scaleFactor);

    // Also scale appBarTheme title
    final currentAppBarTheme = theme.appBarTheme;
    final scaledAppBarTheme = currentAppBarTheme.copyWith(
      titleTextStyle: _scaleTextStyle(
        currentAppBarTheme.titleTextStyle,
        scaleFactor,
      ),
    );

    // Scale dialog text styles
    final currentDialogTheme = theme.dialogTheme;
    final scaledDialogTheme = currentDialogTheme.copyWith(
      titleTextStyle: _scaleTextStyle(
        currentDialogTheme.titleTextStyle,
        scaleFactor,
      ),
      contentTextStyle: _scaleTextStyle(
        currentDialogTheme.contentTextStyle,
        scaleFactor,
      ),
    );

    // Scale snackbar text style
    final currentSnackBarTheme = theme.snackBarTheme;
    final scaledSnackBarTheme = currentSnackBarTheme.copyWith(
      contentTextStyle: _scaleTextStyle(
        currentSnackBarTheme.contentTextStyle,
        scaleFactor,
      ),
    );

    return theme.copyWith(
      textTheme: scaledTextTheme,
      appBarTheme: scaledAppBarTheme,
      dialogTheme: scaledDialogTheme,
      snackBarTheme: scaledSnackBarTheme,
    );
  }

  /// Scale all font sizes in a TextTheme by a factor
  static TextTheme _scaleTextTheme(TextTheme textTheme, double factor) {
    return TextTheme(
      displayLarge: _scaleTextStyle(textTheme.displayLarge, factor),
      displayMedium: _scaleTextStyle(textTheme.displayMedium, factor),
      displaySmall: _scaleTextStyle(textTheme.displaySmall, factor),
      headlineLarge: _scaleTextStyle(textTheme.headlineLarge, factor),
      headlineMedium: _scaleTextStyle(textTheme.headlineMedium, factor),
      headlineSmall: _scaleTextStyle(textTheme.headlineSmall, factor),
      titleLarge: _scaleTextStyle(textTheme.titleLarge, factor),
      titleMedium: _scaleTextStyle(textTheme.titleMedium, factor),
      titleSmall: _scaleTextStyle(textTheme.titleSmall, factor),
      bodyLarge: _scaleTextStyle(textTheme.bodyLarge, factor),
      bodyMedium: _scaleTextStyle(textTheme.bodyMedium, factor),
      bodySmall: _scaleTextStyle(textTheme.bodySmall, factor),
      labelLarge: _scaleTextStyle(textTheme.labelLarge, factor),
      labelMedium: _scaleTextStyle(textTheme.labelMedium, factor),
      labelSmall: _scaleTextStyle(textTheme.labelSmall, factor),
    );
  }

  /// Scale a single TextStyle's fontSize
  static TextStyle? _scaleTextStyle(TextStyle? style, double factor) {
    if (style == null) return null;
    final fontSize = style.fontSize;
    if (fontSize == null) return style;
    return style.copyWith(fontSize: fontSize * factor);
  }

  /// Get the platform's default system font family name
  static String get _systemFontFamily {
    if (kIsWeb) {
      return 'Roboto'; // Web default
    }
    try {
      if (Platform.isIOS || Platform.isMacOS) {
        return '.AppleSystemUIFont'; // System font on Apple platforms
      } else if (Platform.isAndroid) {
        return 'Roboto';
      } else if (Platform.isWindows) {
        return 'Segoe UI';
      } else if (Platform.isLinux) {
        return 'Roboto'; // Common on Linux
      }
    } catch (_) {
      // Platform not available, use safe default
    }
    return 'Roboto';
  }

  /// Apply a specific font family to all text styles
  static TextTheme _applyTextThemeFontFamily(
    TextTheme textTheme,
    String fontFamily,
  ) {
    return TextTheme(
      displayLarge: textTheme.displayLarge?.copyWith(fontFamily: fontFamily),
      displayMedium: textTheme.displayMedium?.copyWith(fontFamily: fontFamily),
      displaySmall: textTheme.displaySmall?.copyWith(fontFamily: fontFamily),
      headlineLarge: textTheme.headlineLarge?.copyWith(fontFamily: fontFamily),
      headlineMedium: textTheme.headlineMedium?.copyWith(
        fontFamily: fontFamily,
      ),
      headlineSmall: textTheme.headlineSmall?.copyWith(fontFamily: fontFamily),
      titleLarge: textTheme.titleLarge?.copyWith(fontFamily: fontFamily),
      titleMedium: textTheme.titleMedium?.copyWith(fontFamily: fontFamily),
      titleSmall: textTheme.titleSmall?.copyWith(fontFamily: fontFamily),
      bodyLarge: textTheme.bodyLarge?.copyWith(fontFamily: fontFamily),
      bodyMedium: textTheme.bodyMedium?.copyWith(fontFamily: fontFamily),
      bodySmall: textTheme.bodySmall?.copyWith(fontFamily: fontFamily),
      labelLarge: textTheme.labelLarge?.copyWith(fontFamily: fontFamily),
      labelMedium: textTheme.labelMedium?.copyWith(fontFamily: fontFamily),
      labelSmall: textTheme.labelSmall?.copyWith(fontFamily: fontFamily),
    );
  }

  /// Apply visual density based on density mode
  static ThemeData _applyVisualDensity(ThemeData theme, DensityMode mode) {
    final density = mode.visualDensity;
    return theme.copyWith(
      visualDensity: VisualDensity(horizontal: density, vertical: density),
    );
  }

  /// Apply high contrast adjustments
  static ThemeData _applyHighContrast(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    // Increase text contrast
    final highContrastTextPrimary = isDark
        ? Colors.white
        : const Color(0xFF000000);
    final highContrastTextSecondary = isDark
        ? const Color(0xFFE0E0E0)
        : const Color(0xFF212121);

    // Enhance border visibility
    final highContrastBorder = isDark
        ? const Color(0xFF808080)
        : const Color(0xFF424242);

    // Enhance surface contrast
    final highContrastSurface = isDark
        ? const Color(0xFF1A1A1A)
        : const Color(0xFFFFFFFF);

    return theme.copyWith(
      colorScheme: colorScheme.copyWith(
        onSurface: highContrastTextPrimary,
        onSurfaceVariant: highContrastTextSecondary,
        outline: highContrastBorder,
        surface: highContrastSurface,
      ),
      textTheme: _applyHighContrastToTextTheme(
        theme.textTheme,
        highContrastTextPrimary,
        highContrastTextSecondary,
      ),
      dividerTheme: theme.dividerTheme.copyWith(color: highContrastBorder),
      cardTheme: theme.cardTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: highContrastBorder, width: 1),
        ),
      ),
    );
  }

  /// Apply high contrast colors to text theme
  static TextTheme _applyHighContrastToTextTheme(
    TextTheme textTheme,
    Color primary,
    Color secondary,
  ) {
    return TextTheme(
      displayLarge: textTheme.displayLarge?.copyWith(color: primary),
      displayMedium: textTheme.displayMedium?.copyWith(color: primary),
      displaySmall: textTheme.displaySmall?.copyWith(color: primary),
      headlineLarge: textTheme.headlineLarge?.copyWith(color: primary),
      headlineMedium: textTheme.headlineMedium?.copyWith(color: primary),
      headlineSmall: textTheme.headlineSmall?.copyWith(color: primary),
      titleLarge: textTheme.titleLarge?.copyWith(color: primary),
      titleMedium: textTheme.titleMedium?.copyWith(color: primary),
      titleSmall: textTheme.titleSmall?.copyWith(color: primary),
      bodyLarge: textTheme.bodyLarge?.copyWith(color: primary),
      bodyMedium: textTheme.bodyMedium?.copyWith(color: secondary),
      bodySmall: textTheme.bodySmall?.copyWith(color: secondary),
      labelLarge: textTheme.labelLarge?.copyWith(color: primary),
      labelMedium: textTheme.labelMedium?.copyWith(color: secondary),
      labelSmall: textTheme.labelSmall?.copyWith(color: secondary),
    );
  }

  /// Apply tap target size based on density mode
  static ThemeData _applyTapTargetSize(ThemeData theme, DensityMode mode) {
    // Use padded targets for large touch mode, shrinkWrap for compact
    final tapTargetSize = switch (mode) {
      DensityMode.compact => MaterialTapTargetSize.shrinkWrap,
      DensityMode.comfortable => MaterialTapTargetSize.padded,
      DensityMode.largeTouch => MaterialTapTargetSize.padded,
    };

    return theme.copyWith(materialTapTargetSize: tapTargetSize);
  }

  /// Calculate the effective text scaler based on preferences
  ///
  /// Returns a TextScaler that respects both user preferences and safe bounds.
  /// Use this to wrap content that needs text scaling.
  static TextScaler effectiveTextScaler({
    required AccessibilityPreferences preferences,
    required double systemTextScale,
  }) {
    final mode = preferences.textScaleMode;
    final effectiveScale = mode.getEffectiveScale(systemTextScale);

    // Clamp to safe bounds to prevent layout breakage
    final clampedScale = effectiveScale.clamp(
      TextScaleMode.minScale,
      TextScaleMode.maxSafeScale,
    );

    return TextScaler.linear(clampedScale);
  }

  /// Get animation duration adjusted for reduce motion preference
  static Duration animationDuration(
    Duration baseDuration,
    AccessibilityPreferences preferences,
  ) {
    if (preferences.reduceMotionMode.shouldReduceMotion) {
      // Return near-instant duration for reduced motion
      return const Duration(milliseconds: 1);
    }
    return baseDuration;
  }

  /// Get animation curve adjusted for reduce motion preference
  static Curve animationCurve(
    Curve baseCurve,
    AccessibilityPreferences preferences,
  ) {
    if (preferences.reduceMotionMode.shouldReduceMotion) {
      // Use linear for reduced motion
      return Curves.linear;
    }
    return baseCurve;
  }

  /// Check if a text scale would potentially break layouts
  static bool isTextScaleSafe(double scale) {
    return scale >= TextScaleMode.minScale &&
        scale <= TextScaleMode.maxSafeScale;
  }

  /// Get minimum tap target size for current preferences
  static double getMinTapTargetSize(AccessibilityPreferences preferences) {
    return preferences.densityMode.minTapTargetSize;
  }

  /// Get spacing scaled by density preference
  static double scaledSpacing(
    double baseSpacing,
    AccessibilityPreferences preferences,
  ) {
    return baseSpacing * preferences.densityMode.spacingMultiplier;
  }
}

/// Extension for easy access to scaled durations
extension AccessibilityDurationExtension on Duration {
  /// Get duration adjusted for reduce motion preference
  Duration withAccessibility(AccessibilityPreferences preferences) {
    return AccessibilityThemeAdapter.animationDuration(this, preferences);
  }
}

/// Extension for easy access to scaled spacing
extension AccessibilitySpacingExtension on double {
  /// Get spacing scaled by density preference
  double withDensity(AccessibilityPreferences preferences) {
    return AccessibilityThemeAdapter.scaledSpacing(this, preferences);
  }
}
