// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Thin os.Logger wrapper for the Apple Watch companion bridge.
//
// Every log line lands under subsystem `com.gotnull.socialmesh`,
// category `watch`. Stream it during development with:
//
//   xcrun simctl spawn booted log stream \
//     --predicate 'subsystem == "com.gotnull.socialmesh" AND category == "watch"'
//
// Mirrors the convention the Dart→os_log bridge in AppDelegate uses
// for category `dart`. Keep the subsystem + category strings stable;
// log-capture tooling depends on them.

import Foundation
import os

enum WatchCompanionLog {
  static let logger = Logger(subsystem: "com.gotnull.socialmesh", category: "watch")

  static func info(_ message: String) {
    logger.log(level: .info, "\(message, privacy: .public)")
  }

  static func warn(_ message: String) {
    logger.log(level: .error, "[warn] \(message, privacy: .public)")
  }

  static func error(_ message: String) {
    logger.log(level: .fault, "[err] \(message, privacy: .public)")
  }
}
