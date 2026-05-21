// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Swift mirror of the Dart `WatchCompanionIntent` wire model.
// Encoder-only on the watchOS side: the Watch builds an intent, sends
// it via WCSession, and decodes only the WatchIntentResult that
// replies. Wire version pinned to 1 to match the Dart contract; see
// `docs/watch_companion_v1.md` §3.2.

import Foundation

enum WatchIntentType: String, Encodable {
  case quickMessage
  case sendImOk
  case refreshSnapshot
}

struct WatchIntentTarget: Encodable, Equatable {
  let channelIndex: Int?

  init(channelIndex: Int?) {
    self.channelIndex = channelIndex
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    // Encode channelIndex even when nil so the Dart side observes the
    // key and routes the fallback-to-default branch deterministically.
    try c.encode(channelIndex, forKey: .channelIndex)
  }

  enum CodingKeys: String, CodingKey {
    case channelIndex
  }
}

struct WatchIntentPayload: Encodable, Equatable {
  let cannedKey: String?

  init(cannedKey: String?) {
    self.cannedKey = cannedKey
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(cannedKey, forKey: .cannedKey)
  }

  enum CodingKeys: String, CodingKey {
    case cannedKey
  }
}

struct WatchIntent: Encodable, Equatable {
  static let wireVersion: Int = 1

  let requestId: String
  let type: WatchIntentType
  let target: WatchIntentTarget
  let payload: WatchIntentPayload
  let createdAtMs: Int

  init(
    requestId: String,
    type: WatchIntentType,
    target: WatchIntentTarget,
    payload: WatchIntentPayload,
    createdAtMs: Int
  ) {
    self.requestId = requestId
    self.type = type
    self.target = target
    self.payload = payload
    self.createdAtMs = createdAtMs
  }

  /// Convenience: build a `quickMessage` intent for a frozen canned key
  /// targeted at a specific channel. Used by `QuickMessageView` on the
  /// confirm-and-send path; v1 is the ONLY supported send shape.
  static func quickMessage(
    cannedKey: String,
    channelIndex: Int
  ) -> WatchIntent {
    return WatchIntent(
      requestId: UUID().uuidString,
      type: .quickMessage,
      target: WatchIntentTarget(channelIndex: channelIndex),
      payload: WatchIntentPayload(cannedKey: cannedKey),
      createdAtMs: Int(Date().timeIntervalSince1970 * 1000)
    )
  }

  /// Convenience: refresh-snapshot intent. Carries no target or
  /// payload; the phone acks and the next composer rebuild flows back
  /// over the bridge.
  static func refreshSnapshot() -> WatchIntent {
    return WatchIntent(
      requestId: UUID().uuidString,
      type: .refreshSnapshot,
      target: WatchIntentTarget(channelIndex: nil),
      payload: WatchIntentPayload(cannedKey: nil),
      createdAtMs: Int(Date().timeIntervalSince1970 * 1000)
    )
  }

  enum CodingKeys: String, CodingKey {
    case version
    case requestId
    case type
    case target
    case payload
    case createdAtMs
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(WatchIntent.wireVersion, forKey: .version)
    try c.encode(requestId, forKey: .requestId)
    try c.encode(type, forKey: .type)
    try c.encode(target, forKey: .target)
    try c.encode(payload, forKey: .payload)
    try c.encode(createdAtMs, forKey: .createdAtMs)
  }

  /// Encode the intent as a [String: Any] dictionary suitable for
  /// `WCSession.sendMessage(_:replyHandler:errorHandler:)`. Round-trips
  /// through JSONSerialization so nested encodings (target / payload /
  /// type enum) all materialise as plain dictionary values.
  func toMessage() throws -> [String: Any] {
    let data = try JSONEncoder().encode(self)
    guard
      let dict = try JSONSerialization.jsonObject(with: data, options: [])
        as? [String: Any]
    else {
      throw WatchWireError.unsupportedVersion(
        got: -1, expected: WatchIntent.wireVersion)
    }
    return dict
  }
}
