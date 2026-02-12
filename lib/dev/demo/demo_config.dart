// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/foundation.dart';

/// Demo mode configuration.
///
/// Demo mode is enabled via compile-time flag:
///   flutter run --dart-define=SOCIALMESH_DEMO=1
///
/// When enabled, the app runs with sample data and no backend dependencies.
/// Demo mode is only available in debug builds.
class DemoConfig {
  DemoConfig._();

  /// Whether demo mode is enabled via dart-define flag.
  /// Only evaluates to true in debug builds with SOCIALMESH_DEMO=1.
  static const bool isEnabled =
      kDebugMode &&
      bool.fromEnvironment('SOCIALMESH_DEMO', defaultValue: false);

  /// Demo mode identifier for logging.
  static const String modeLabel = isEnabled ? '[DEMO]' : '';

  /// Force empty states to show for testing animated empty state widgets.
  /// Enable via: flutter run --dart-define=DEBUG_EMPTY_STATES=true
  static const bool debugEmptyStates =
      kDebugMode &&
      bool.fromEnvironment('DEBUG_EMPTY_STATES', defaultValue: false);
}
