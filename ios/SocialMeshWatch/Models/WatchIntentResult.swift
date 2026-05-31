// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Swift mirror of the Dart `WatchCompanionIntentResult` wire model.
// Decoded from the reply dictionary passed back via
// `WCSession.sendMessage(_:replyHandler:errorHandler:)`. Version pinned
// to 1; see `docs/watch_companion_v1.md` §3.3.

import Foundation

struct WatchIntentResult: Decodable, Equatable {
  static let wireVersion: Int = 2
  static let minWireVersion: Int = 1

  let version: Int
  let requestId: String
  let accepted: Bool
  let userVisibleReason: String?
  let diagnosticReason: String?
  let timestampMs: Int

  enum CodingKeys: String, CodingKey {
    case version
    case requestId
    case accepted
    case userVisibleReason
    case diagnosticReason
    case timestampMs
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let v = try c.decode(Int.self, forKey: .version)
    if v < WatchIntentResult.minWireVersion || v > WatchIntentResult.wireVersion {
      throw WatchWireError.unsupportedVersion(
        got: v, expected: WatchIntentResult.wireVersion)
    }
    self.version = v
    self.requestId = try c.decode(String.self, forKey: .requestId)
    self.accepted = try c.decode(Bool.self, forKey: .accepted)
    self.userVisibleReason = try c.decodeIfPresent(
      String.self, forKey: .userVisibleReason)
    self.diagnosticReason = try c.decodeIfPresent(
      String.self, forKey: .diagnosticReason)
    self.timestampMs = try c.decode(Int.self, forKey: .timestampMs)
  }

  /// Construct directly from values. Used by the connectivity manager
  /// when it has to synthesise a local rejection (e.g. session not
  /// reachable) so callers always see a well-formed result.
  init(
    requestId: String,
    accepted: Bool,
    userVisibleReason: String?,
    diagnosticReason: String?,
    timestampMs: Int
  ) {
    self.version = WatchIntentResult.wireVersion
    self.requestId = requestId
    self.accepted = accepted
    self.userVisibleReason = userVisibleReason
    self.diagnosticReason = diagnosticReason
    self.timestampMs = timestampMs
  }

  /// Decode from a [String: Any] dictionary delivered by the reply
  /// handler. Same JSON-serialise-then-decode trick as
  /// `WatchSnapshot.decode(from:)`.
  static func decode(from dictionary: [String: Any]) throws -> WatchIntentResult {
    let data = try JSONSerialization.data(
      withJSONObject: dictionary, options: [])
    return try JSONDecoder().decode(WatchIntentResult.self, from: data)
  }
}
