// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Inbox preview tab. Lists the latest 5 messages from the snapshot.
// If `capabilities.canShowInbox` is false OR the preview is empty,
// renders UnavailableView.

import SwiftUI

struct InboxView: View {
  @EnvironmentObject private var store: WatchSnapshotStore
  @EnvironmentObject private var connectivity: WatchConnectivityManager

  var body: some View {
    NavigationStack {
      Group {
        if let snap = store.latestSnapshot,
           snap.capabilities.canShowInbox,
           !snap.inbox.previews.isEmpty {
          List {
            if snap.inbox.unreadCount > 0 {
              Text("\(snap.inbox.unreadCount) unread")
                .font(.caption)
                .foregroundStyle(.secondary)
                .listRowBackground(Color.clear)
            }
            ForEach(snap.inbox.previews) { message in
              // Tap a row to reply with a canned message. Replies thread
              // under the original when it carries a packet id (Meshtastic);
              // otherwise the composer notes it sends as a new message.
              Button {
                store.selectReplyTarget(message)
              } label: {
                _InboxRow(message: message)
              }
              .buttonStyle(.plain)
            }
          }
          .listStyle(.carousel)
          .opacity(store.isStale ? 0.6 : 1.0)
        } else {
          UnavailableView(
            icon: "tray",
            title: "No messages",
            detail: store.latestSnapshot == nil ? "Waiting for phone" : nil
          )
        }
      }
      .navigationTitle("Inbox")
      .navigationBarTitleDisplayMode(.inline)
      .sheet(item: $store.selectedReplyTarget) { target in
        QuickMessageView(replyTarget: target)
          .environmentObject(store)
          .environmentObject(connectivity)
      }
    }
  }
}

private struct _InboxRow: View {
  let message: WatchInboxMessage

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack {
        Text(message.sender)
          .font(.caption.bold())
          .lineLimit(1)
        Spacer(minLength: 4)
        if message.unread {
          Image(systemName: "circle.fill")
            .font(.system(size: 6))
            .foregroundStyle(.blue)
        }
      }
      Text(message.snippet)
        .font(.caption)
        .foregroundStyle(.primary)
        .lineLimit(3)
      Text(_timeLabel(for: message.timestampMs))
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .padding(.vertical, 2)
  }

  private func _timeLabel(for ms: Int) -> String {
    let date = Date(timeIntervalSince1970: TimeInterval(ms) / 1000)
    let seconds = Int(Date().timeIntervalSince(date))
    if seconds < 60 { return "now" }
    if seconds < 3600 { return "\(seconds / 60)m" }
    if seconds < 86400 { return "\(seconds / 3600)h" }
    return "\(seconds / 86400)d"
  }
}
