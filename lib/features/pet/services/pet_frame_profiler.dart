// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Dev-gated frame-timing profiler for the NodePet hero screen. Active
// only when AppLogging.petLoggingEnabled is true (toggled via
// PET_LOGGING_ENABLED=true in .env). Aggregates frame build + raster
// durations from SchedulerBinding.addTimingsCallback and logs to
// AppLogging.pet every few seconds while the pet hero is mounted.
//
// Scope caveat: Flutter's timings callback is application-scoped — we
// can't isolate "just the pet subtree". Starting/stopping alongside
// the pet screen's lifecycle means the logged data covers the user's
// time on the pet screen, which is the relevant window.

import 'dart:async';

import 'package:flutter/scheduler.dart';

import '../../../core/logging.dart';

class PetFrameProfiler {
  PetFrameProfiler._();

  static TimingsCallback? _callback;
  static Timer? _flushTimer;
  static final List<FrameTiming> _buffer = [];

  /// 60fps budget per frame (16.67 ms build + raster combined).
  static const double _frameBudgetMs = 16.67;

  /// Flush cadence. Kept at 2s so the log isn't noisy but still
  /// responsive enough to spot regressions while tapping around.
  static const Duration _flushInterval = Duration(seconds: 2);

  static bool get isActive => _callback != null;

  /// Start collecting frame timings. No-op when pet logging is off
  /// or the profiler is already running.
  static void start() {
    if (!AppLogging.petLoggingEnabled) return;
    if (_callback != null) return;
    _buffer.clear();
    _callback = _onTimings;
    SchedulerBinding.instance.addTimingsCallback(_callback!);
    _flushTimer = Timer.periodic(_flushInterval, (_) => _flush());
    AppLogging.pet('FrameProfiler: started');
  }

  /// Stop collecting and flush any remaining samples.
  static void stop() {
    final cb = _callback;
    if (cb == null) return;
    SchedulerBinding.instance.removeTimingsCallback(cb);
    _callback = null;
    _flushTimer?.cancel();
    _flushTimer = null;
    if (_buffer.isNotEmpty) _flush();
    AppLogging.pet('FrameProfiler: stopped');
  }

  static void _onTimings(List<FrameTiming> timings) {
    _buffer.addAll(timings);
  }

  static void _flush() {
    if (_buffer.isEmpty) return;
    final count = _buffer.length;
    double sumBuild = 0;
    double sumRaster = 0;
    double maxBuild = 0;
    double maxRaster = 0;
    int slowFrames = 0;
    for (final t in _buffer) {
      final buildMs = t.buildDuration.inMicroseconds / 1000.0;
      final rasterMs = t.rasterDuration.inMicroseconds / 1000.0;
      sumBuild += buildMs;
      sumRaster += rasterMs;
      if (buildMs > maxBuild) maxBuild = buildMs;
      if (rasterMs > maxRaster) maxRaster = rasterMs;
      if (buildMs + rasterMs > _frameBudgetMs) slowFrames++;
    }
    final avgBuild = sumBuild / count;
    final avgRaster = sumRaster / count;
    AppLogging.pet(
      'FrameProfiler: frames=$count '
      'avgBuild=${avgBuild.toStringAsFixed(2)}ms '
      'avgRaster=${avgRaster.toStringAsFixed(2)}ms '
      'maxBuild=${maxBuild.toStringAsFixed(2)}ms '
      'maxRaster=${maxRaster.toStringAsFixed(2)}ms '
      'slowFrames=$slowFrames/$count',
    );
    _buffer.clear();
  }
}
