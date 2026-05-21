// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Swift mirror of the Dart `WatchCompanionSnapshot` wire model.
// Field names + types track the JSON contract documented in
// `docs/watch_companion_v1.md` §3.1 exactly. Both sides freeze on
// wire-version 1; init(from:) rejects any other value with a
// FormatError so a future bump is loud, not silent.

import Foundation

enum WatchWireError: Error, LocalizedError {
  case unsupportedVersion(got: Int, expected: Int)

  var errorDescription: String? {
    switch self {
    case .unsupportedVersion(let got, let expected):
      return "Watch wire-version \(got) does not match expected \(expected)."
    }
  }
}

enum WatchConnectionStatus: String, Decodable, CaseIterable, Equatable {
  case disconnected
  case connecting
  case ready
  case degraded
  case unsupported
}

struct WatchConnectionState: Decodable, Equatable {
  let status: WatchConnectionStatus
  let activeProtocolDisplayName: String?
  let activeDeviceName: String?
  let readinessReason: String?
}

struct WatchInboxMessage: Decodable, Equatable, Identifiable {
  let id: String
  let sender: String
  let snippet: String
  let timestampMs: Int
  let unread: Bool
  let channelIndex: Int?
}

struct WatchInbox: Decodable, Equatable {
  let unreadCount: Int
  let previews: [WatchInboxMessage]
}

struct WatchNodePreview: Decodable, Equatable, Identifiable {
  let nodeId: String
  let shortName: String?
  let longName: String?
  let lastHeardMs: Int
  let rssi: Int?
  let hops: Int?

  var id: String { nodeId }
}

struct WatchChannelPreview: Decodable, Equatable, Identifiable {
  let index: Int
  let name: String
  let isDefault: Bool

  var id: Int { index }
}

struct WatchCannedMessage: Decodable, Equatable, Identifiable {
  let key: String
  let label: String

  var id: String { key }
}

struct WatchCapabilities: Decodable, Equatable {
  let canQuickReply: Bool
  let canSendImOk: Bool
  let canSendLocationIntent: Bool
  let canShowNodes: Bool
  let canShowInbox: Bool
}

struct WatchSnapshot: Decodable, Equatable {
  /// Wire-version constant. Mirrors Dart's
  /// `WatchCompanionSnapshot.wireVersion`. Bump in lock-step with the
  /// Dart side when changing any field shape; init(from:) below rejects
  /// every other value.
  static let wireVersion: Int = 1

  let version: Int
  let generatedAt: Int
  let connection: WatchConnectionState
  let inbox: WatchInbox
  let nodes: [WatchNodePreview]
  let channels: [WatchChannelPreview]
  let cannedMessages: [WatchCannedMessage]
  let capabilities: WatchCapabilities

  enum CodingKeys: String, CodingKey {
    case version
    case generatedAt
    case connection
    case inbox
    case nodes
    case channels
    case cannedMessages
    case capabilities
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let v = try c.decode(Int.self, forKey: .version)
    if v != WatchSnapshot.wireVersion {
      throw WatchWireError.unsupportedVersion(
        got: v, expected: WatchSnapshot.wireVersion)
    }
    self.version = v
    self.generatedAt = try c.decode(Int.self, forKey: .generatedAt)
    self.connection = try c.decode(WatchConnectionState.self, forKey: .connection)
    self.inbox = try c.decode(WatchInbox.self, forKey: .inbox)
    self.nodes = try c.decode([WatchNodePreview].self, forKey: .nodes)
    self.channels = try c.decode([WatchChannelPreview].self, forKey: .channels)
    self.cannedMessages = try c.decode(
      [WatchCannedMessage].self, forKey: .cannedMessages)
    self.capabilities = try c.decode(WatchCapabilities.self, forKey: .capabilities)
  }

  /// Decode a snapshot from the [String: Any] dictionary delivered by
  /// `WCSessionDelegate.session(_:didReceiveApplicationContext:)`. The
  /// dictionary is JSON-serialised through JSONSerialization to round-
  /// trip into a strongly-typed value.
  static func decode(from dictionary: [String: Any]) throws -> WatchSnapshot {
    let data = try JSONSerialization.data(
      withJSONObject: dictionary, options: [])
    return try JSONDecoder().decode(WatchSnapshot.self, from: data)
  }
}
