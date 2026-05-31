// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// JSON envelope validation for the Watch companion bridge.
//
// The bridge ferries dictionaries between Flutter (Dart-side codecs
// in `lib/services/watch_companion/models/`) and the paired Watch
// (WatchConnectivity). Swift never deserializes the inner payload
// shape — it only validates the wire-version envelope so a malformed
// or version-mismatched payload from either side is rejected before
// it reaches Dart, and so the bridge can synthesise a well-formed
// rejection result without needing the Dart engine alive.

import Foundation

enum WatchCompanionWire {
  /// Current wire version. Mirrors the Dart constants on
  /// `WatchCompanionSnapshot`, `WatchCompanionIntent`, and
  /// `WatchCompanionIntentResult`. v2 added reply fields
  /// (`replyToMessageId` on intents, `packetId` on inbox rows).
  static let version: Int = 2

  /// Oldest wire version the bridge still accepts. New fields are optional,
  /// so a v1 payload validates and decodes cleanly under v2.
  static let minVersion: Int = 1

  /// MethodChannel name shared with Dart. Must match
  /// `lib/services/watch_companion/watch_companion_channel_bridge.dart`
  /// exactly; the channel name is a public API between Dart and Swift.
  static let channelName: String = "com.socialmesh/watch_companion"

  /// Stable diagnostic reasons emitted when the Swift bridge cannot
  /// reach the Dart handler. The Dart-side send facade owns its own
  /// vocabulary for application-level rejections (see
  /// `lib/services/watch_companion/_internal/watch_send_facade.dart`).
  enum DiagnosticReason {
    static let bridgeNotReady = "bridge_not_ready"
    static let invalidIntentPayload = "invalid_intent_payload"
    static let unsupportedWireVersion = "unsupported_wire_version"
    static let flutterError = "flutter_error"
  }
}

enum WatchCompanionCodec {
  /// Validate a payload dictionary's `version` key. Returns nil on
  /// success or a stable diagnostic-reason string on failure.
  static func validateVersion(_ dict: [String: Any]) -> String? {
    guard let v = dict["version"] as? Int else {
      return WatchCompanionWire.DiagnosticReason.invalidIntentPayload
    }
    if v < WatchCompanionWire.minVersion || v > WatchCompanionWire.version {
      return WatchCompanionWire.DiagnosticReason.unsupportedWireVersion
    }
    return nil
  }

  /// Build a `WatchCompanionIntentResult`-shaped dictionary for cases
  /// where the bridge cannot or must not forward the intent to Dart.
  /// Mirrors the Dart-side `WatchCompanionIntentResult.toJson()` shape
  /// (version 1) so the Watch decodes it with the same model class.
  ///
  /// Optional fields are omitted (not set to NSNull) because WCSession
  /// reply payloads must be plist-compatible — NSNull is rejected and
  /// triggers the sender's errorHandler with payloadUnsupportedTypes,
  /// surfacing on the Watch as `watch_send_error`. The Watch decoder
  /// uses `decodeIfPresent`, so absent keys decode as nil.
  static func buildRejection(
    requestId: String,
    diagnosticReason: String,
    userVisibleReason: String? = nil
  ) -> [String: Any] {
    var dict: [String: Any] = [
      "version": WatchCompanionWire.version,
      "requestId": requestId,
      "accepted": false,
      "diagnosticReason": diagnosticReason,
      "timestampMs": Int(Date().timeIntervalSince1970 * 1000),
    ]
    if let reason = userVisibleReason {
      dict["userVisibleReason"] = reason
    }
    return dict
  }

  /// Best-effort extraction of the intent's `requestId` for use in
  /// synthesised rejection results. Falls back to a fixed string if
  /// the payload omits the field entirely.
  static func extractRequestId(_ dict: [String: Any]) -> String {
    return (dict["requestId"] as? String) ?? "unknown"
  }
}
