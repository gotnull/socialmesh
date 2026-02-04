// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Result type for async operations - enables safe error handling without exceptions.
/// Named with 'Safe' prefix to avoid conflict with Riverpod's AsyncError.
sealed class SafeAsyncResult<T> {
  const SafeAsyncResult();

  /// Execute [onSuccess] if this is a success, [onError] if this is an error
  R when<R>({
    required R Function(T data) success,
    required R Function(Object error, StackTrace? stackTrace) error,
  });

  /// Returns true if this is a success
  bool get isSuccess => this is SafeAsyncSuccess<T>;

  /// Returns true if this is an error
  bool get isError => this is SafeAsyncError<T>;

  /// Returns the data if success, null otherwise
  T? get dataOrNull => switch (this) {
    SafeAsyncSuccess<T>(:final data) => data,
    SafeAsyncError<T>() => null,
  };

  /// Returns the error if error, null otherwise
  Object? get errorOrNull => switch (this) {
    SafeAsyncSuccess<T>() => null,
    SafeAsyncError<T>(:final error) => error,
  };
}

/// Represents a successful async result
final class SafeAsyncSuccess<T> extends SafeAsyncResult<T> {
  const SafeAsyncSuccess(this.data);
  final T data;

  @override
  R when<R>({
    required R Function(T data) success,
    required R Function(Object error, StackTrace? stackTrace) error,
  }) => success(data);
}

/// Represents an error async result
final class SafeAsyncError<T> extends SafeAsyncResult<T> {
  const SafeAsyncError(this.error, [this.stackTrace]);
  final Object error;
  final StackTrace? stackTrace;

  @override
  R when<R>({
    required R Function(T data) success,
    required R Function(Object error, StackTrace? stackTrace) error,
  }) => error(this.error, stackTrace);
}

/// Extension to convert Future to SafeAsyncResult
extension FutureSafeAsyncResult<T> on Future<T> {
  /// Converts a Future to a SafeAsyncResult, catching any errors
  Future<SafeAsyncResult<T>> toResult() async {
    try {
      return SafeAsyncSuccess(await this);
    } catch (e, st) {
      return SafeAsyncError(e, st);
    }
  }
}

/// Mixin that provides lifecycle-safe async operations for ConsumerStatefulWidget.
///
/// This mixin solves the common crash pattern where async operations complete
/// after a widget is disposed, leading to "ConsumerStatefulElement._assertNotDisposed"
/// errors when trying to access ref.read, context, or setState.
///
/// Usage:
/// ```dart
/// class _MyWidgetState extends ConsumerState<MyWidget> with LifecycleSafeMixin {
///   Future<void> _handleSave() async {
///     // Capture dependencies BEFORE await
///     final notifier = ref.read(myProvider.notifier);
///
///     // Perform async work
///     final result = await notifier.save(data);
///
///     // Safe UI update - automatically checks mounted
///     safeSetState(() {
///       _isLoading = false;
///     });
///
///     // Safe navigation - automatically checks mounted
///     safeNavigatorPop(result);
///
///     // Safe snackbar - automatically checks mounted
///     safeShowSnackBar('Saved successfully');
///   }
/// }
/// ```
mixin LifecycleSafeMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  /// Whether async operations should proceed with UI updates.
  /// Returns false if the widget is no longer mounted.
  bool get canUpdateUI => mounted;

  /// Safely calls setState only if the widget is still mounted.
  /// Returns true if setState was called, false if skipped.
  bool safeSetState(VoidCallback fn) {
    if (!mounted) return false;
    setState(fn);
    return true;
  }

  /// Safely pops the navigator only if mounted.
  /// Returns true if navigation occurred, false if skipped.
  bool safeNavigatorPop<R>([R? result]) {
    if (!mounted) return false;
    Navigator.of(context).pop(result);
    return true;
  }

  /// Safely pushes a route only if mounted.
  /// Returns the result of the navigation, or null if skipped.
  Future<R?> safeNavigatorPush<R>(Route<R> route) async {
    if (!mounted) return null;
    return Navigator.of(context).push(route);
  }

  /// Safely pushes a named route only if mounted.
  Future<R?> safeNavigatorPushNamed<R>(
    String routeName, {
    Object? arguments,
  }) async {
    if (!mounted) return null;
    return Navigator.of(context).pushNamed(routeName, arguments: arguments);
  }

  /// Safely shows a SnackBar only if mounted.
  /// Returns the ScaffoldFeatureController or null if skipped.
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? safeShowSnackBar(
    String message, {
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
    Color? backgroundColor,
  }) {
    if (!mounted) return null;
    final snackBar = SnackBar(
      content: Text(message),
      duration: duration,
      action: action,
      backgroundColor: backgroundColor,
    );
    return ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  /// Safely shows a dialog only if mounted.
  /// Returns the dialog result or null if skipped.
  Future<R?> safeShowDialog<R>({
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) async {
    if (!mounted) return null;
    return showDialog<R>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: builder,
    );
  }

  /// Safely shows a bottom sheet only if mounted.
  /// Returns the result or null if skipped.
  Future<R?> safeShowModalBottomSheet<R>({
    required WidgetBuilder builder,
    bool isScrollControlled = false,
    bool isDismissible = true,
    bool enableDrag = true,
    Color? backgroundColor,
    ShapeBorder? shape,
  }) async {
    if (!mounted) return null;
    return showModalBottomSheet<R>(
      context: context,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: backgroundColor,
      shape: shape,
      builder: builder,
    );
  }

  /// Executes an async operation with automatic lifecycle checking.
  ///
  /// This is the recommended pattern for async work in widgets:
  /// 1. Captures provider/context dependencies before await
  /// 2. Executes the async work
  /// 3. Only calls UI callbacks if still mounted
  ///
  /// Usage:
  /// ```dart
  /// await safeAsync(
  ///   work: () async {
  ///     final notifier = ref.read(myProvider.notifier);
  ///     await notifier.save(data);
  ///   },
  ///   onSuccess: () {
  ///     safeSetState(() => _isLoading = false);
  ///     safeNavigatorPop(true);
  ///   },
  ///   onError: (e, st) {
  ///     safeShowSnackBar('Error: $e');
  ///   },
  /// );
  /// ```
  Future<SafeAsyncResult<R>> safeAsync<R>({
    required Future<R> Function() work,
    void Function(R result)? onSuccess,
    void Function(Object error, StackTrace? stackTrace)? onError,
    void Function()? onComplete,
  }) async {
    try {
      final result = await work();
      if (mounted && onSuccess != null) {
        onSuccess(result);
      }
      return SafeAsyncSuccess(result);
    } catch (e, st) {
      if (mounted && onError != null) {
        onError(e, st);
      }
      return SafeAsyncError(e, st);
    } finally {
      if (mounted && onComplete != null) {
        onComplete();
      }
    }
  }

  /// Runs a callback on a timer, automatically cancelling if disposed.
  /// Returns the timer so it can be cancelled manually if needed.
  Timer safeTimer(Duration duration, VoidCallback callback) {
    return Timer(duration, () {
      if (mounted) callback();
    });
  }

  /// Runs a periodic timer, automatically respecting mounted state.
  Timer safePeriodicTimer(
    Duration period,
    void Function(Timer timer) callback,
  ) {
    return Timer.periodic(period, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      callback(timer);
    });
  }

  /// Schedules a callback for the next frame, only if still mounted.
  void safePostFrame(VoidCallback callback) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) callback();
    });
  }
}

/// Mixin for standard StatefulWidget (non-Consumer) lifecycle safety.
mixin StatefulLifecycleSafeMixin<T extends StatefulWidget> on State<T> {
  /// Whether async operations should proceed with UI updates.
  bool get canUpdateUI => mounted;

  /// Safely calls setState only if the widget is still mounted.
  bool safeSetState(VoidCallback fn) {
    if (!mounted) return false;
    setState(fn);
    return true;
  }

  /// Safely pops the navigator only if mounted.
  bool safeNavigatorPop<R>([R? result]) {
    if (!mounted) return false;
    Navigator.of(context).pop(result);
    return true;
  }

  /// Safely shows a SnackBar only if mounted.
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? safeShowSnackBar(
    String message, {
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
    Color? backgroundColor,
  }) {
    if (!mounted) return null;
    final snackBar = SnackBar(
      content: Text(message),
      duration: duration,
      action: action,
      backgroundColor: backgroundColor,
    );
    return ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  /// Safely shows a dialog only if mounted.
  Future<R?> safeShowDialog<R>({
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) async {
    if (!mounted) return null;
    return showDialog<R>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: builder,
    );
  }

  /// Schedules a callback for the next frame, only if still mounted.
  void safePostFrame(VoidCallback callback) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) callback();
    });
  }

  /// Runs a callback on a timer, automatically cancelling if disposed.
  Timer safeTimer(Duration duration, VoidCallback callback) {
    return Timer(duration, () {
      if (mounted) callback();
    });
  }
}
