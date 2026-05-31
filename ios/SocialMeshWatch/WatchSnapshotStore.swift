// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Observable store for the latest WatchSnapshot decoded by the
// connectivity manager. Splits state from transport so views observe
// the store and the manager owns WCSession lifecycle.
//
// Staleness rule (see `docs/watch_companion_v1.md` §3.1):
//   A snapshot is "stale" when more than 30 s have passed since the
//   last receipt. Stale snapshots stay visible (the user can still
//   read cached state) but the Send button is disabled in
//   QuickMessageView until a fresh snapshot lands.

import Foundation
import os

@MainActor
final class WatchSnapshotStore: ObservableObject {
  /// How long a snapshot stays "fresh". Matches the WatchConnectivity
  /// push debounce on the phone side (1.5 s typical), with comfortable
  /// headroom for normal cadence.
  static let stalenessThreshold: TimeInterval = 30

  @Published private(set) var latestSnapshot: WatchSnapshot?
  @Published private(set) var lastReceivedAt: Date?

  /// Most recent intent-result, surfaced by views (e.g. the post-send
  /// confirmation banner in QuickMessageView). Cleared whenever the
  /// view that consumed it tells us to.
  @Published var lastIntentResult: WatchIntentResult?

  /// The inbox message the user tapped to reply to, bridging the Inbox tab
  /// and the reply composer sheet. Nil when not replying.
  @Published var selectedReplyTarget: WatchInboxMessage?

  /// Select an inbox message as the reply target (opens the reply composer).
  func selectReplyTarget(_ message: WatchInboxMessage) {
    self.selectedReplyTarget = message
  }

  /// Clear the reply target (composer dismissed or send completed).
  func clearReplyTarget() {
    self.selectedReplyTarget = nil
  }

  private let log = Logger(
    subsystem: "com.gotnull.socialmesh", category: "watch")

  /// Inject a fresh snapshot. Bumps [lastReceivedAt] so the staleness
  /// timer resets. Safe to call from any thread; the @MainActor
  /// annotation funnels mutations onto main.
  func update(_ snapshot: WatchSnapshot) {
    self.latestSnapshot = snapshot
    self.lastReceivedAt = Date()
    // Drop a stale reply target if it aged out of the latest inbox so the
    // composer never points at a message the phone can no longer resolve.
    if let target = selectedReplyTarget,
      !snapshot.inbox.previews.contains(where: { $0.id == target.id })
    {
      self.selectedReplyTarget = nil
    }
    log.log(level: .info, """
      snapshot received: gen=\(snapshot.generatedAt, privacy: .public) \
      status=\(snapshot.connection.status.rawValue, privacy: .public) \
      inbox=\(snapshot.inbox.previews.count, privacy: .public) \
      nodes=\(snapshot.nodes.count, privacy: .public)
      """)
  }

  /// Record an intent result so the view that issued the intent can
  /// react. Convenience for the connectivity manager; views can read
  /// [lastIntentResult] directly.
  func recordIntentResult(_ result: WatchIntentResult) {
    self.lastIntentResult = result
    log.log(level: .info, """
      intent result: req=\(result.requestId, privacy: .public) \
      accepted=\(result.accepted, privacy: .public) \
      diag=\(result.diagnosticReason ?? "", privacy: .public)
      """)
  }

  /// True when the cached snapshot is older than [stalenessThreshold].
  /// False when there is no snapshot yet (the UI shows an empty state
  /// in that case, distinct from stale).
  var isStale: Bool {
    guard let lastReceivedAt = lastReceivedAt else { return false }
    return Date().timeIntervalSince(lastReceivedAt) > Self.stalenessThreshold
  }

  /// Human-readable approximation of "received N seconds/minutes ago"
  /// for the stale-state caption. Returns nil when there is no
  /// snapshot yet.
  var lastReceivedDescription: String? {
    guard let lastReceivedAt = lastReceivedAt else { return nil }
    let seconds = Int(Date().timeIntervalSince(lastReceivedAt))
    if seconds < 5 { return "just now" }
    if seconds < 60 { return "\(seconds)s ago" }
    let minutes = seconds / 60
    if minutes < 60 { return "\(minutes)m ago" }
    let hours = minutes / 60
    return "\(hours)h ago"
  }
}
