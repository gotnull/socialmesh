// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Mirrors every `debugPrint` call into iOS `os_log` so Dart logs are
/// visible via `xcrun simctl log stream` and the xcodebuild MCP log
/// capture tool. Without this bridge, Flutter's stdout is unreachable
/// from outside a `flutter run` / `flutter attach` session.
///
/// iOS debug builds only — no-op everywhere else. All log lines are
/// tagged with subsystem `com.gotnull.socialmesh`, category `dart`.
/// Filter from a log-stream capture with:
///
///   start_sim_log_cap(subsystemFilter=["com.gotnull.socialmesh"])
class OsLogBridge {
  static const _channel = MethodChannel('socialmesh/os_log');
  static bool _installed = false;

  static void setup() {
    if (_installed) return;
    if (!kDebugMode) return;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    _installed = true;

    final originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      originalDebugPrint(message, wrapWidth: wrapWidth);
      if (message == null || message.isEmpty) return;
      unawaited(_forward(message));
    };
  }

  static Future<void> _forward(String message) async {
    try {
      await _channel.invokeMethod<void>('log', {'msg': message});
    } catch (_) {
      // Channel not available yet (very early startup) or iOS side not
      // registered — swallow silently; debugPrint still went to stdout.
    }
  }
}
