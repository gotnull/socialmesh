// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import '../logging.dart';

/// Centralized error handling that prevents recoverable errors from crashing the app.
///
/// This class configures Flutter's error handling to:
/// 1. Log all errors for debugging
/// 2. Report errors to Crashlytics with context
/// 3. Distinguish between fatal and recoverable errors
/// 4. Prevent UI errors (like image loading failures) from crashing the app
///
/// Usage:
/// Call [AppErrorHandler.initialize] early in main() before runApp().
class AppErrorHandler {
  static bool _initialized = false;
  static final List<String> _breadcrumbs = [];
  static const int _maxBreadcrumbs = 50;

  /// Initialize the error handler. Should be called once at app startup.
  static void initialize() {
    if (_initialized) return;
    _initialized = true;

    // Handle Flutter framework errors (widget build errors, layout errors, etc.)
    FlutterError.onError = _handleFlutterError;

    // Handle async errors that aren't caught by Flutter framework
    ui.PlatformDispatcher.instance.onError = _handlePlatformError;
  }

  /// Handle Flutter framework errors.
  static void _handleFlutterError(FlutterErrorDetails details) {
    final isFatal = _isErrorFatal(details);

    // Log locally
    AppLogging.debug(
      'FlutterError [${isFatal ? "FATAL" : "NON-FATAL"}]: ${details.exception}',
    );
    if (details.stack != null) {
      AppLogging.debug('Stack: ${details.stack}');
    }

    // Report to Crashlytics
    _reportToCrashlytics(
      details.exception,
      details.stack,
      reason: details.context?.toString(),
      isFatal: isFatal,
    );

    // For non-fatal errors, we don't want to crash the app
    // but we do want to show something went wrong in debug mode
    if (isFatal) {
      // Let the default handler show the red error screen in debug
      FlutterError.presentError(details);
    } else if (kDebugMode) {
      // In debug, log full details so layout overflows are diagnosable.
      // FlutterErrorDetails.context contains the widget path (e.g.
      // "The relevant error-causing widget was: Row file:///…:123").
      debugPrint('Recovered from error: ${details.exception}');
      if (details.context != null) {
        debugPrint('  Context: ${details.context}');
      }
      if (details.informationCollector != null) {
        final info = details.informationCollector!()
            .map((d) => d.toString())
            .join('\n  ');
        debugPrint('  Info:\n  $info');
      }
      if (details.stack != null) {
        debugPrint('  Stack: ${details.stack}');
      }
    }
  }

  /// Handle platform/isolate errors.
  static bool _handlePlatformError(Object error, StackTrace stack) {
    AppLogging.debug('PlatformError [HANDLED]: $error');

    // Platform errors are always reported as non-fatal to Crashlytics.
    // We return true below which means we've handled the error and
    // prevented an app crash. Reporting fatal: true here would cause
    // the Crashlytics native SDK to invoke its crash recording path
    // (FIRCLSExceptionRecordOnDemand) which can itself crash — creating
    // a crash-in-crash loop.
    _reportToCrashlytics(
      error,
      stack,
      reason: 'Platform error',
      isFatal: false,
    );

    // Return true to indicate the error was handled
    // This prevents the error from propagating and crashing the app
    return true;
  }

  /// Determine if a Flutter error should be treated as fatal.
  static bool _isErrorFatal(FlutterErrorDetails details) {
    final exception = details.exception;
    final library = details.library;

    // Image errors are never fatal - they should show a fallback
    if (_isImageError(exception, library)) {
      return false;
    }

    // Widget lifecycle errors (disposed widget access) - usually recoverable
    if (_isLifecycleError(exception)) {
      return false;
    }

    // Layout errors during transitions - usually recoverable
    if (_isLayoutError(exception, library)) {
      return false;
    }

    // Render errors - sometimes recoverable
    if (library == 'rendering library') {
      // Specific render errors that are recoverable
      final msg = exception.toString().toLowerCase();
      if (msg.contains('renderbox was not laid out') ||
          msg.contains('needs compositing') ||
          msg.contains('size.isfinite')) {
        return false;
      }
    }

    // Gesture errors are usually recoverable
    if (library == 'gesture library') {
      return false;
    }

    // Default: treat as potentially fatal
    return true;
  }

  /// Check if error is image-related.
  static bool _isImageError(Object exception, String? library) {
    if (library == 'image resource service') return true;

    final msg = exception.toString().toLowerCase();
    return msg.contains('image') &&
        (msg.contains('codec') ||
            msg.contains('decode') ||
            msg.contains('load') ||
            msg.contains('network') ||
            msg.contains('failed'));
  }

  /// Check if error is widget lifecycle related.
  static bool _isLifecycleError(Object exception) {
    final msg = exception.toString().toLowerCase();
    return msg.contains('disposed') ||
        msg.contains('mounted') ||
        msg.contains('defunct') ||
        msg.contains('_assertnotdisposed');
  }

  /// Check if error is layout related.
  static bool _isLayoutError(Object exception, String? library) {
    if (library == 'rendering library') return true;

    final msg = exception.toString().toLowerCase();
    return msg.contains('layout') ||
        msg.contains('constraints') ||
        msg.contains('size') ||
        msg.contains('overflow');
  }

  /// Public API to report a non-fatal error to Crashlytics with context.
  ///
  /// Sanitizes PII and adds breadcrumb context before recording. Use this
  /// instead of calling `FirebaseCrashlytics.instance.recordError()` directly.
  static void reportError(Object error, StackTrace? stack, {String? context}) {
    _reportToCrashlytics(error, stack, reason: context);
  }

  /// Report error to Crashlytics with context.
  static void _reportToCrashlytics(
    Object error,
    StackTrace? stack, {
    String? reason,
    bool isFatal = false,
  }) {
    try {
      // Sanitize error message to remove sensitive data
      final sanitizedError = _sanitizeError(error);
      final sanitizedReason = reason != null ? _sanitizeString(reason) : null;

      // Add breadcrumbs as custom keys
      FirebaseCrashlytics.instance.setCustomKey(
        'breadcrumbs',
        _breadcrumbs.join(' -> '),
      );

      if (sanitizedReason != null) {
        FirebaseCrashlytics.instance.setCustomKey('reason', sanitizedReason);
      }

      FirebaseCrashlytics.instance.recordError(
        sanitizedError,
        stack,
        reason: sanitizedReason,
        fatal: isFatal,
      );
    } catch (e) {
      // Crashlytics itself failed - just log locally
      debugPrint('Failed to report to Crashlytics: $e');
    }
  }

  /// Sanitize error message to remove sensitive data.
  static Object _sanitizeError(Object error) {
    final errorStr = error.toString();
    return _sanitizeString(errorStr);
  }

  /// Remove sensitive data from strings before logging/reporting.
  static String _sanitizeString(String input) {
    var result = input;

    // Remove potential tokens/keys (anything that looks like a long alphanumeric string)
    result = result.replaceAll(
      RegExp(r'[A-Za-z0-9_-]{32,}'),
      '[REDACTED_TOKEN]',
    );

    // Remove email addresses
    result = result.replaceAll(
      RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'),
      '[REDACTED_EMAIL]',
    );

    // Remove phone numbers (basic pattern)
    result = result.replaceAll(RegExp(r'\+?[0-9]{10,15}'), '[REDACTED_PHONE]');

    // Remove URLs with query parameters (might contain tokens)
    result = result.replaceAll(
      RegExp(r'https?://[^\s]+\?[^\s]+'),
      '[REDACTED_URL]',
    );

    // Remove base64-like strings (potential encoded data)
    result = result.replaceAll(
      RegExp(
        r'(?:[A-Za-z0-9+/]{4}){10,}(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?',
      ),
      '[REDACTED_BASE64]',
    );

    return result;
  }

  /// Add a breadcrumb for debugging crash context.
  /// Breadcrumbs help understand what the user was doing before a crash.
  static void addBreadcrumb(String action) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    _breadcrumbs.add('[$timestamp] $action');

    // Keep only the most recent breadcrumbs
    while (_breadcrumbs.length > _maxBreadcrumbs) {
      _breadcrumbs.removeAt(0);
    }

    // Also set on Crashlytics for crash reports
    try {
      FirebaseCrashlytics.instance.log(action);
    } catch (_) {
      // Crashlytics not initialized - ignore
    }
  }

  /// Set user context for crash reports (sanitized).
  static void setUserContext({String? userId, String? email, String? name}) {
    try {
      if (userId != null) {
        // SHA-256 hash truncated to 16 hex chars — non-reversible, sufficient entropy.
        final hash = sha256
            .convert(utf8.encode(userId))
            .toString()
            .substring(0, 16);
        FirebaseCrashlytics.instance.setUserIdentifier(hash);
      }
      // Don't set email or name to avoid PII in crash reports
    } catch (_) {
      // Crashlytics not initialized - ignore
    }
  }

  /// Clear user context (on logout).
  static void clearUserContext() {
    try {
      FirebaseCrashlytics.instance.setUserIdentifier('');
    } catch (_) {}
  }

  /// Run a function with error protection - never throws, returns result or null.
  static Future<T?> runProtected<T>(
    Future<T> Function() work, {
    String? context,
    T? fallback,
  }) async {
    try {
      return await work();
    } catch (e, st) {
      if (context != null) {
        addBreadcrumb('Error in $context');
      }
      _reportToCrashlytics(e, st, reason: context, isFatal: false);
      return fallback;
    }
  }

  /// Run a synchronous function with error protection.
  static T? runProtectedSync<T>(
    T Function() work, {
    String? context,
    T? fallback,
  }) {
    try {
      return work();
    } catch (e, st) {
      if (context != null) {
        addBreadcrumb('Error in $context');
      }
      _reportToCrashlytics(e, st, reason: context, isFatal: false);
      return fallback;
    }
  }
}

/// Extension for Zone-based error handling.
extension ErrorZone on Zone {
  /// Run code in a zone that catches all errors.
  static R runGuarded<R>(
    R Function() body, {
    void Function(Object error, StackTrace stack)? onError,
  }) {
    return runZonedGuarded(body, (error, stack) {
          AppErrorHandler.addBreadcrumb('Zone error caught');
          if (onError != null) {
            onError(error, stack);
          } else {
            AppErrorHandler._reportToCrashlytics(
              error,
              stack,
              reason: 'Uncaught zone error',
              isFatal: false,
            );
          }
        })
        as R;
  }
}
