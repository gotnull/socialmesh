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
    HStack(alignment: .top, spacing: 10) {
      _Avatar(
        text: _avatarText,
        color: _avatarColor
      )
      VStack(alignment: .leading, spacing: 3) {
        // Sender gets the full content width so common names
        // ("socialmesh.app") render without an ellipsis.
        HStack(spacing: 5) {
          Text(message.sender)
            .font(.system(size: 15, weight: .semibold))
            .lineLimit(1)
            // Shrink to fit rather than ellipsising long names like
            // "socialmesh.app"; only truncates past the floor.
            .minimumScaleFactor(0.7)
            .truncationMode(.tail)
          if message.unread {
            Circle()
              .fill(Color.blue)
              .frame(width: 6, height: 6)
          }
          Spacer(minLength: 0)
        }
        // Snippet takes the room; timestamp sits compact at the trailing edge.
        HStack(alignment: .firstTextBaseline, spacing: 6) {
          Text(message.snippet)
            .font(.system(size: 14))
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
          Spacer(minLength: 6)
          Text(_timeLabel(for: message.timestampMs))
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
        }
      }
    }
    .padding(.vertical, 8)
    .padding(.horizontal, 4)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  // Up-to-4-char label: explicit short-name, else initials from the sender.
  private var _avatarText: String {
    if let short = message.senderShortName, !short.isEmpty {
      return String(short.prefix(4)).uppercased()
    }
    let words = message.sender
      .split(separator: " ")
      .filter { !$0.isEmpty }
    if words.count >= 2 {
      return (words[0].prefix(1) + words[1].prefix(1)).uppercased()
    }
    return String(message.sender.prefix(2)).uppercased()
  }

  // ARGB int from the snapshot, else a stable colour derived from the sender.
  private var _avatarColor: Color {
    if let argb = message.avatarColor {
      return Color(
        red: Double((argb >> 16) & 0xFF) / 255.0,
        green: Double((argb >> 8) & 0xFF) / 255.0,
        blue: Double(argb & 0xFF) / 255.0
      )
    }
    let palette: [Color] = [
      .blue, .green, .orange, .purple, .pink, .teal, .indigo, .red,
    ]
    return palette[abs(message.sender.hashValue) % palette.count]
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

// Circular sender avatar: colour-filled disc with a short-name / initials.
private struct _Avatar: View {
  let text: String
  let color: Color

  var body: some View {
    ZStack {
      Circle().fill(color.gradient)
      Text(text)
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .padding(2)
    }
    .frame(width: 36, height: 36)
  }
}
