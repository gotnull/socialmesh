// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/foundation.dart';

/// Debug flags controlled via environment variables.
///
/// These flags are only active in debug builds and are set via dart-define:
///   flutter run --dart-define=DEBUG_EMPTY_STATES=true
///
/// For convenience, you can also add to your .env or launch configuration.
class DebugFlags {
  DebugFlags._();

  /// Force empty states to show for testing animated empty state widgets.
  ///
  /// Usage: flutter run --dart-define=DEBUG_EMPTY_STATES=true
  ///
  /// When enabled, screens like Presence, NodeDex, Activity, and Aether
  /// will display their animated empty states regardless of actual data.
  static const bool forceEmptyStates =
      kDebugMode &&
      bool.fromEnvironment('DEBUG_EMPTY_STATES', defaultValue: false);
}
