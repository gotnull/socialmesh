// SPDX-License-Identifier: GPL-3.0-or-later
/// Core safety utilities for lifecycle-safe async operations and error handling.
///
/// This module provides:
/// - [LifecycleSafeMixin] - Mixin for safe async operations in ConsumerStatefulWidget
/// - [StatefulLifecycleSafeMixin] - Mixin for safe async operations in StatefulWidget
/// - [SafeImage] - Image widget that never crashes on load/decode errors
/// - [AppErrorHandler] - Centralized error handling and Crashlytics integration
/// - [AsyncResult] - Result type for async operations
///
/// Example usage:
/// ```dart
/// class _MyWidgetState extends ConsumerState<MyWidget> with LifecycleSafeMixin {
///   Future<void> _save() async {
///     // Capture dependencies before await
///     final notifier = ref.read(myProvider.notifier);
///
///     // Perform async work
///     await notifier.save();
///
///     // Safe UI updates
///     safeSetState(() => _loading = false);
///     safeNavigatorPop(true);
///   }
/// }
/// ```
library;

export 'lifecycle_mixin.dart';
export 'safe_image.dart';
export 'error_handler.dart';
