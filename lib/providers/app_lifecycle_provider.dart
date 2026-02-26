// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging.dart';

/// Whether the app is currently in the foreground (true) or background (false).
///
/// This is the single source of truth for app lifecycle state. All timer-based
/// providers and services should watch or listen to this provider to pause
/// unnecessary work when the app is backgrounded, preventing battery drain.
///
/// Updated by [_SocialmeshAppState.didChangeAppLifecycleState] in main.dart.
///
/// Consumers should use [ref.listen] or [ref.watch] to react:
///
/// ```dart
/// ref.listen<bool>(appLifecycleProvider, (prev, isForeground) {
///   if (isForeground) {
///     _startTimer();
///   } else {
///     _pauseTimer();
///   }
/// });
/// ```
class AppLifecycleNotifier extends Notifier<bool> {
  @override
  bool build() {
    // App starts in the foreground.
    return true;
  }

  /// Called from main.dart when [AppLifecycleState] changes.
  ///
  /// Only [AppLifecycleState.resumed] counts as foreground.
  /// [AppLifecycleState.paused], [AppLifecycleState.inactive], and
  /// [AppLifecycleState.detached] all count as background.
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    final isForeground = lifecycleState == AppLifecycleState.resumed;

    if (state == isForeground) return; // No change, skip.

    state = isForeground;
    AppLogging.debug(
      '🔋 AppLifecycle: ${isForeground ? "FOREGROUND" : "BACKGROUND"} '
      '(state=$lifecycleState)',
    );
  }

  /// Whether the app is currently in the foreground.
  bool get isForeground => state;

  /// Whether the app is currently in the background.
  bool get isBackground => !state;
}

final appLifecycleProvider = NotifierProvider<AppLifecycleNotifier, bool>(
  AppLifecycleNotifier.new,
);

// ---------------------------------------------------------------------------
// Convenience read-only aliases
// ---------------------------------------------------------------------------

/// True when the app is in the foreground. Prefer [appLifecycleProvider]
/// directly when you need to listen for transitions.
final isAppForegroundProvider = Provider<bool>((ref) {
  return ref.watch(appLifecycleProvider);
});

// ---------------------------------------------------------------------------
// Lifecycle-aware timer helper
// ---------------------------------------------------------------------------

/// Mixin for [Notifier] / [AsyncNotifier] subclasses that own periodic timers
/// which should be suspended while the app is backgrounded.
///
/// Usage:
/// ```dart
/// class MyNotifier extends Notifier<SomeState> with LifecycleAwareTimerMixin {
///   @override
///   SomeState build() {
///     installLifecycleListener(ref);
///     _startTimer();
///     return SomeState();
///   }
///
///   @override
///   void onForeground() => _startTimer();
///
///   @override
///   void onBackground() => _pauseTimer();
/// }
/// ```
mixin LifecycleAwareTimerMixin {
  /// Override to perform work when the app returns to the foreground.
  /// Called after the lifecycle provider transitions to `true`.
  void onForeground();

  /// Override to pause/cancel timers when the app goes to the background.
  /// Called after the lifecycle provider transitions to `false`.
  void onBackground();

  /// Call this once in [build] to wire up the lifecycle listener.
  ///
  /// Pass the notifier's own [Ref] so it can listen to [appLifecycleProvider].
  void installLifecycleListener(Ref ref) {
    ref.listen<bool>(appLifecycleProvider, (bool? previous, bool isForeground) {
      if (isForeground) {
        onForeground();
      } else {
        onBackground();
      }
    });
  }
}

/// Standalone helper that creates a [Timer.periodic] which automatically
/// pauses when the app is backgrounded and resumes when foregrounded.
///
/// Returns a [LifecycleAwareTimer] handle that the caller must dispose.
///
/// This is useful for services that are not Riverpod notifiers but still need
/// lifecycle-aware timers (e.g. [ProtocolService], [LocationService]).
class LifecycleAwareTimer {
  Timer? _timer;
  final Duration period;
  final void Function(Timer) callback;
  bool _disposed = false;

  LifecycleAwareTimer._({required this.period, required this.callback});

  /// Create and start a lifecycle-aware periodic timer.
  factory LifecycleAwareTimer.periodic({
    required Duration period,
    required void Function(Timer) callback,
    bool startImmediately = true,
  }) {
    final lat = LifecycleAwareTimer._(period: period, callback: callback);
    if (startImmediately) {
      lat.resume();
    }
    return lat;
  }

  /// Resume the periodic timer. No-op if already running or disposed.
  void resume() {
    if (_disposed) return;
    if (_timer != null && _timer!.isActive) return;
    _timer = Timer.periodic(period, callback);
  }

  /// Pause (cancel) the periodic timer. No-op if not running.
  void pause() {
    _timer?.cancel();
    _timer = null;
  }

  /// Whether the timer is currently active.
  bool get isActive => _timer?.isActive ?? false;

  /// Permanently cancel the timer. Cannot be resumed after this.
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
  }
}
